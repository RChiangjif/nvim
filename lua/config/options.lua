local P = require("config.platform")

vim.g.mapleader = " "

vim.opt.number = true
vim.opt.belloff = "all"
vim.opt.autowrite = true
vim.opt.cursorline = true
vim.opt.smartindent = true
vim.opt.undofile = true
vim.opt.termguicolors = true

-- The runner writes outp.txt behind nvim's back, then issues :checktime.
-- autoread is what turns that into an automatic buffer refresh.
vim.opt.autoread = true

-- Required by nvim-tree / oil: disable the built-in netrw explorer.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Opt-in: make :terminal and any remaining shell escapes use PowerShell on
-- Windows. Off by default because <leader>c no longer goes through a shell,
-- so nothing here needs it. Enable with `vim.g.use_pwsh_shell = true` in
-- lua/config/local.lua.
if P.is_win and vim.g.use_pwsh_shell then
  local pwsh = P.first_exe({ "pwsh", "powershell" })
  if pwsh then
    vim.o.shell = pwsh
    vim.o.shellcmdflag =
      "-NoLogo -NonInteractive -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;"
    vim.o.shellredir = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'
    vim.o.shellpipe = '2>&1 | %%{ "$_" } | Tee-Object %s; exit $LastExitCode'
    vim.o.shellquote = ""
    vim.o.shellxquote = ""
  end
end
