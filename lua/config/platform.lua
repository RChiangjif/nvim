-- Single source of truth for every OS difference in this config.
-- Nothing else in the config should branch on the operating system.

local M = {}

M.is_win = vim.fn.has("win32") == 1
M.is_mac = vim.fn.has("mac") == 1
M.is_linux = not M.is_win and not M.is_mac

-- Compiled binaries need a .exe suffix on Windows.
M.exe_suffix = M.is_win and ".exe" or ""

M.config_dir = vim.fn.stdpath("config")

---Return the first candidate that exists on PATH.
---@param cands string[]
---@return string|nil
local function first_exe(cands)
  for _, c in ipairs(cands) do
    if vim.fn.executable(c) == 1 then
      return c
    end
  end
  return nil
end

M.first_exe = first_exe

-- Probed rather than hardcoded, so a Homebrew GCC bump (g++-16 -> g++-17)
-- or a brand new machine needs no edit here.
M.cxx = first_exe({ "g++-16", "g++-15", "g++-14", "g++", "clang++" })
M.cc = first_exe({ "gcc-16", "gcc-15", "gcc-14", "gcc", "clang" })

-- Order matters on Windows: python3.exe there is a 0-byte Microsoft Store
-- stub. executable() returns 1 for it, but running it opens the Store and
-- hangs. Always prefer plain `python` on Windows, and never fall back to
-- python3 there - hence picking the candidate list first, rather than an
-- `is_win and first_exe(...) or first_exe(...)` chain, which would slip into
-- the right-hand branch whenever the Windows probe came up empty.
M.py = first_exe(M.is_win and { "python", "py" } or { "python3", "python" })

return M
