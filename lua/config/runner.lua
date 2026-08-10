-- Compile + run the current file with inp.txt as stdin and outp.txt as stdout.
--
-- Everything goes through vim.system() with an argv array, so no shell is
-- involved at any point. That is what makes this identical on macOS (/bin/sh)
-- and Windows (cmd.exe): no `<`/`>` redirection, no quoting rules, no `./`.

local P = require("config.platform")

local M = {}

M.timeout_ms = 10000

---Directory the inp.txt/outp.txt pair lives in: the current file's own folder.
---@return string
function M.io_dir()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then
    dir = vim.fn.getcwd()
  end
  return (dir:gsub("\\", "/"))
end

function M.inp_path()
  return M.io_dir() .. "/inp.txt"
end

function M.outp_path()
  return M.io_dir() .. "/outp.txt"
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "runner" })
end

---Read inp.txt as a single string. Missing file is fine - programs that read
---nothing still run.
local function read_stdin()
  local path = M.inp_path()
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
      compile = { P.cc, "-Wall", "-DONPC", "-o", stem, basename },
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
local function execute(rule, dir, stdin)
  local started = (vim.uv or vim.loop).hrtime()

  vim.system(rule.run, {
    cwd = dir,
    stdin = stdin,
    text = true,
    timeout = M.timeout_ms,
  }, function(res)
    vim.schedule(function()
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
      vim.fn.writefile(out, dir .. "/outp.txt")
      vim.cmd("silent! checktime")

      local ms = ((vim.uv or vim.loop).hrtime() - started) / 1e6

      -- vim.system reports a timeout as code 124 (like GNU timeout), and
      -- signals it with SIGTERM. Any *other* signal is the program itself
      -- crashing - SIGSEGV on an out-of-bounds index being the classic one -
      -- and must not be described as a timeout.
      if res.code == 124 then
        notify(("Killed after %ds - infinite loop?"):format(M.timeout_ms / 1000), vim.log.levels.WARN)
      elseif res.signal ~= 0 then
        notify(("Crashed with signal %d\n%s"):format(res.signal, res.stderr or ""), vim.log.levels.ERROR)
      elseif res.code ~= 0 then
        notify(("Exited with code %d\n%s"):format(res.code, res.stderr or ""), vim.log.levels.WARN)
      else
        -- Success used to be completely silent, which is indistinguishable
        -- from the keymap never firing when no outp.txt pane is on screen.
        notify(("Done in %d ms"):format(ms))
      end
    end)
  end)
end

---Save, build if needed, then run. Bound to <leader>c.
function M.run()
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
  local dir = M.io_dir()

  local rule, err = build_rule(ext, basename, stem, dir)
  if not rule then
    return notify(err, vim.log.levels.ERROR)
  end

  local stdin = read_stdin()

  if not rule.compile then
    return execute(rule, dir, stdin)
  end

  vim.system(rule.compile, { cwd = dir, text = true }, function(cc)
    vim.schedule(function()
      if cc.code ~= 0 then
        to_quickfix(cc.stderr or "", basename, abspath)
        return notify("Compilation failed", vim.log.levels.ERROR)
      end
      vim.fn.setqflist({}, " ", { title = "compile", lines = {} })
      vim.cmd("cclose")
      execute(rule, dir, stdin)
    end)
  end)
end

---Open the inp.txt / outp.txt side panes. Bound to <leader>e.
function M.open_io_panes()
  vim.cmd(("30vsplit %s"):format(vim.fn.fnameescape(M.outp_path())))
  vim.cmd("wincmd l")
  vim.cmd(("30vsplit %s"):format(vim.fn.fnameescape(M.inp_path())))
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
    if base == "inp.txt" or base == "outp.txt" then
      wins[#wins + 1] = win
    end
  end
  return wins
end

---Show the panes if hidden, hide them if shown. Bound to <C-e>.
---Hiding only closes the windows - the buffers stay loaded, so unsaved test
---data survives, and `wall` in M.run() still flushes it before the next run.
function M.toggle_io_panes()
  local open = io_windows()
  if #open == 0 then
    return M.open_io_panes()
  end
  for _, win in ipairs(open) do
    -- pcall: closing the very last window of a tab is an error, so a layout
    -- that is nothing but I/O panes keeps whatever it cannot close.
    pcall(vim.api.nvim_win_close, win, false)
  end
end

return M
