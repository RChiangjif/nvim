-- Compile + run the current file with inp.txt as stdin and outp.txt as stdout.
--
-- Everything goes through vim.system() with an argv array, so no shell is
-- involved at any point. That is what makes this identical on macOS (/bin/sh)
-- and Windows (cmd.exe): no `<`/`>` redirection, no quoting rules, no `./`.

local P = require("config.platform")

local M = {}

-- Wall-clock limit for an ordinary run. M.run({ untimed = true }) lifts it for
-- the problems that legitimately take minutes.
M.timeout_ms = 10000

-- Columns given to each of the inp.txt / outp.txt panes.
M.pane_width = 30

-- The stdin/stdout pair, named once. Every path below is derived from these,
-- so the two files cannot drift apart the way they did when each call site
-- spelled them out for itself.
local INP = "inp.txt"
local OUTP = "outp.txt"

-- Handle of the run currently in flight, so that an untimed one - which has
-- nothing else to stop it - can still be killed. Nil when nothing is running.
local running = nil

-- Set while a kill is deliberate, to tell M.stop() apart from a real crash:
-- both arrive at the callback as death by SIGTERM.
local stopping = false

-- State behind the statusline component, plus the timer that keeps it ticking.
-- lualine polls roughly once a second on its own, too coarse and too uneven to
-- read as a clock, so this forces a redraw while - and only while - something
-- is in flight. The clock spans the whole of <leader>c, compilation included:
-- a heavy C++ build is exactly when you want to see that nvim is still busy.
local run_started = nil
local run_phase = nil -- "compiling" | "running"
local run_untimed = false
local redraw_timer = nil

---@param phase string
---@param untimed boolean
local function start_ticking(phase, untimed)
  run_started = vim.uv.hrtime()
  run_phase = phase
  run_untimed = untimed
  redraw_timer = vim.uv.new_timer()
  -- Zero initial delay: the clock should be on screen from the keypress, not
  -- one tick later.
  redraw_timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      -- Fails harmlessly if nvim is mid-command-line; nothing to recover.
      pcall(vim.cmd, "redrawstatus")
    end)
  )
end

---Move from compiling to running without resetting the clock.
local function set_phase(phase)
  run_phase = phase
end

local function stop_ticking()
  run_started = nil
  run_phase = nil
  if redraw_timer then
    redraw_timer:stop()
    redraw_timer:close()
    redraw_timer = nil
  end
end

---What is in flight and for how long, for the statusline component in
---lua/plugins/ui.lua. Nil when nothing is running.
---@return number|nil elapsed_ms, string|nil phase, boolean untimed
function M.progress()
  if not run_started then
    return nil, nil, false
  end
  return (vim.uv.hrtime() - run_started) / 1e6, run_phase, run_untimed
end

---Directory the inp.txt/outp.txt pair lives in: the current file's own folder.
---@return string
local function io_dir()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then
    dir = vim.fn.getcwd()
  end
  return (dir:gsub("\\", "/"))
end

local function inp_path()
  return io_dir() .. "/" .. INP
end

local function outp_path()
  return io_dir() .. "/" .. OUTP
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "runner" })
end

---Milliseconds stop being readable once a run lasts minutes.
local function duration(ms)
  if ms < 10000 then
    return ("%d ms"):format(ms)
  end
  return ("%.1f s"):format(ms / 1000)
end

---Read inp.txt as a single string. Missing file is fine - programs that read
---nothing still run.
local function read_stdin()
  local path = inp_path()
  if vim.fn.filereadable(path) == 0 then
    return ""
  end
  return table.concat(vim.fn.readfile(path), "\n") .. "\n"
end

---Send compiler stderr to the quickfix list.
---Compilation uses relative filenames (see build_rule), so rewrite the leading
---`name.cpp:12:3:` back to an absolute path - otherwise quickfix resolves it
---against nvim's cwd, which is not necessarily the compile cwd.
local function to_quickfix(stderr, basename, abspath)
  local lines = {}
  -- Function replacement, not a string: a `%` anywhere in abspath would
  -- otherwise be read as a capture reference and silently eaten.
  local function absolute()
    return abspath .. ":"
  end
  for _, line in ipairs(vim.split(stderr, "\n", { trimempty = true })) do
    lines[#lines + 1] = (line:gsub("^" .. vim.pesc(basename) .. ":", absolute))
  end
  vim.fn.setqflist({}, " ", { title = "compile", lines = lines, efm = vim.o.errorformat })
  vim.cmd("copen")
end

---Describe how to build and run a given file.
---Compiler args use the *relative* basename with cwd set to the file's folder.
---That sidesteps Cygwin g++ mangling Windows backslash paths, and paths with
---spaces, in one move.
---`-w` on both compilers: warnings are noise here, the quickfix list is for
---errors that actually stopped the build.
---@return table|nil rule, string|nil err
local function build_rule(ext, basename, stem, dir)
  local exe = dir .. "/" .. stem .. P.exe_suffix

  if ext == "cpp" then
    if not P.cxx then
      return nil, "No C++ compiler found (tried g++-16..g++, clang++)"
    end
    return {
      compile = { P.cxx, "-std=c++17", "-DONPC", "-w", "-o", stem, basename },
      run = { exe },
    }
  elseif ext == "c" then
    if not P.cc then
      return nil, "No C compiler found (tried gcc-16..gcc, clang)"
    end
    return {
      compile = { P.cc, "-DONPC", "-w", "-o", stem, basename },
      run = { exe },
    }
  elseif ext == "py" then
    if not P.py then
      return nil, "No Python interpreter found"
    end
    return { run = { P.py, basename } }
  end

  return nil, "No compile rule for *." .. ext
end

---Execute the program and pipe stdout into outp.txt.
---@param timeout_ms integer|nil nil runs with no limit at all
local function execute(rule, dir, stdin, timeout_ms)
  local started = vim.uv.hrtime()
  set_phase("running")

  running = vim.system(rule.run, {
    cwd = dir,
    stdin = stdin,
    text = true,
    timeout = timeout_ms,
  }, function(res)
    vim.schedule(function()
      running = nil
      stop_ticking()

      -- Whatever the program managed to print before dying is still useful,
      -- so write the output first and diagnose afterwards.
      --
      -- Trailing "\n" on stdout splits into a final empty string, which
      -- writefile would turn into a spurious blank line in outp.txt.
      -- Note the explicit `dir`: recomputing the path from the current
      -- buffer here would land outp.txt in the wrong folder whenever the
      -- user switched buffers while the program was still running.
      local out = vim.split(res.stdout or "", "\n")
      if out[#out] == "" then
        out[#out] = nil
      end
      vim.fn.writefile(out, dir .. "/" .. OUTP)
      vim.cmd("silent! checktime")

      local ms = (vim.uv.hrtime() - started) / 1e6

      -- vim.system reports a timeout as code 124 (like GNU timeout), and
      -- signals it with SIGTERM. Any *other* signal is the program itself
      -- crashing - SIGSEGV on an out-of-bounds index being the classic one -
      -- and must not be described as a timeout.
      if stopping then
        stopping = false
        notify(("Stopped after %s"):format(duration(ms)), vim.log.levels.WARN)
      elseif res.code == 124 then
        notify(
          ("Killed after %s - infinite loop? <leader>C runs untimed"):format(duration(M.timeout_ms)),
          vim.log.levels.WARN
        )
      elseif res.signal ~= 0 then
        notify(("Crashed with signal %d\n%s"):format(res.signal, res.stderr or ""), vim.log.levels.ERROR)
      elseif res.code ~= 0 then
        notify(("Exited with code %d\n%s"):format(res.code, res.stderr or ""), vim.log.levels.WARN)
      else
        -- Success used to be completely silent, which is indistinguishable
        -- from the keymap never firing when no outp.txt pane is on screen.
        notify(("Done in %s"):format(duration(ms)))
      end
    end)
  end)
end

---Save, build if needed, then run.
---Bound to <leader>c; <leader>C passes `untimed` for a program expected to
---take longer than M.timeout_ms.
---@param opts? { untimed?: boolean }
function M.run(opts)
  opts = opts or {}

  if vim.bo.buftype ~= "" then
    return notify("Not a real file buffer", vim.log.levels.WARN)
  end

  -- The old `:!` path relied on 'autowrite' saving implicitly. Going async
  -- means we have to write explicitly, or we compile a stale file.
  -- `wall`, not `write`: stdin is read back off disk, so an inp.txt edited
  -- in the <leader>e pane and left unsaved would otherwise run against its
  -- previous contents.
  vim.cmd("silent! wall")

  local ext = vim.fn.expand("%:e")
  local basename = vim.fn.expand("%:t")
  local stem = vim.fn.expand("%:t:r")
  local abspath = (vim.fn.expand("%:p"):gsub("\\", "/"))
  local dir = io_dir()

  local rule, err = build_rule(ext, basename, stem, dir)
  if not rule then
    return notify(err, vim.log.levels.ERROR)
  end

  local timeout = not opts.untimed and M.timeout_ms or nil
  local stdin = read_stdin()

  -- One clock for the whole keypress. execute() moves it to "running"; the
  -- statusline is live from here on either path.
  start_ticking(rule.compile and "compiling" or "running", opts.untimed == true)

  if not rule.compile then
    return execute(rule, dir, stdin, timeout)
  end

  -- Assigned to `running` so that <leader>s can also abort a compile, which
  -- is what the statusline promises while the clock reads "compiling".
  running = vim.system(rule.compile, { cwd = dir, text = true }, function(cc)
    vim.schedule(function()
      running = nil

      if stopping then
        stopping = false
        stop_ticking()
        return notify("Stopped during compilation", vim.log.levels.WARN)
      end

      if cc.code ~= 0 then
        stop_ticking()
        to_quickfix(cc.stderr or "", basename, abspath)
        return notify("Compilation failed", vim.log.levels.ERROR)
      end

      vim.fn.setqflist({}, " ", { title = "compile", lines = {} })
      vim.cmd("cclose")
      execute(rule, dir, stdin, timeout)
    end)
  end)
end

---Kill the run in flight. Bound to <leader>s, and the only way out of an
---untimed run short of killing the process by hand.
function M.stop()
  if not running then
    return notify("Nothing is running")
  end
  stopping = true
  running:kill("sigterm")
end

---Open the inp.txt / outp.txt side panes.
---winfixwidth on both: 'equalalways' is already off, but neiltree resizes
---its neighbours on open and close under its own steam. Pinning the width is
---what actually holds these two at M.pane_width no matter what comes and goes
---beside them.
local function open_io_panes()
  vim.cmd(("%dvsplit %s"):format(M.pane_width, vim.fn.fnameescape(outp_path())))
  vim.wo.winfixwidth = true
  vim.cmd("wincmd l")
  vim.cmd(("%dvsplit %s"):format(M.pane_width, vim.fn.fnameescape(inp_path())))
  vim.wo.winfixwidth = true
  vim.cmd("wincmd l")
end

---Every window in the current tab showing an inp.txt / outp.txt buffer.
---Matched on basename rather than full path: the point of the toggle is to
---clear the panes off the screen, including ones left over from a problem in
---another directory.
local function io_windows()
  local wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local base = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)), ":t")
    if base == INP or base == OUTP then
      wins[#wins + 1] = win
    end
  end
  return wins
end

---Show the panes if hidden, hide them if shown. Bound to <leader>e and <C-e>.
---Hiding only closes the windows - the buffers stay loaded, so unsaved test
---data survives, and `wall` in M.run() still flushes it before the next run.
function M.toggle_io_panes()
  local open = io_windows()
  if #open == 0 then
    return open_io_panes()
  end
  for _, win in ipairs(open) do
    -- pcall: closing the very last window of a tab is an error, so a layout
    -- that is nothing but I/O panes keeps whatever it cannot close.
    pcall(vim.api.nvim_win_close, win, false)
  end
end

return M
