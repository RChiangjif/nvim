-- Cross-platform Neovim config (macOS + Windows). See lua/config/platform.lua
-- for every OS-specific decision; nothing else branches on the OS.
-- Requires Neovim 0.10+ (vim.system, vim.uv, vim.fs.joinpath).

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")

-- Machine-specific overrides. Gitignored, and absent by default.
pcall(require, "config.local")
