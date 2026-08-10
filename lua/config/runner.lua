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
  for _, line in ipairs(vim.split(stderr, "\n", { trimempty = true })) do
    lines[#lines + 1] = (line:gsub("^" .. vim.pesc(basename) .. ":", abspath .. ":"))
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
  vim.system(rule.run, {
    cwd = dir,
    stdin = stdin,
    text = true,
    timeout = M.timeout_ms,
  }, function(res)
    vim.schedule(function()
      -- A timeout kills the process with a signal rather than a clean exit.
      if res.signal ~= 0 then
        notify(("Killed after %ds - infinite loop?"):format(M.timeout_ms / 1000), vim.log.levels.WARN)
      end

      vim.fn.writefile(vim.split(res.stdout or "", "\n"), M.outp_path())
      vim.cmd("silent! checktime")

      if res.code ~= 0 and res.signal == 0 then
        notify(("Exited with code %d\n%s"):format(res.code, res.stderr or ""), vim.log.levels.WARN)
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
  vim.cmd("silent! write")

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

return M
