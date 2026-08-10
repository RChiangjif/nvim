local P = require("config.platform")
local runner = require("config.runner")

local map = vim.keymap.set

-- Free <Space> so it can act purely as <leader>.
map({ "n", "v" }, "<Space>", "<Nop>", { desc = "leader placeholder" })

-- System clipboard
map({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste from system clipboard" })
map("v", "<leader>y", '"+y', { desc = "Yank to system clipboard" })

-- Config. stdpath("config") resolves to ~/.config/nvim on macOS and
-- %LOCALAPPDATA%\nvim on Windows, so this one mapping works on both.
map("n", "<leader>h", function()
  vim.cmd("tabedit " .. vim.fn.fnameescape(P.config_dir))
end, { desc = "Open nvim config directory in a new tab" })

-- File explorers
map("n", "<leader>n", "<CMD>NvimTreeToggle<CR>", { desc = "Toggle nvim-tree" })
map("n", "<leader>m", "<CMD>Oil --float<CR>", { desc = "Open parent directory (Oil)" })

-- Competitive programming
-- Both keys toggle; <C-e> is the quick one, <leader>e the mnemonic. Toggling
-- rather than opening also stops a second press from stacking duplicate panes.
-- <C-e> normally scrolls the view down one line; the toggle takes it over.
map("n", "<leader>e", runner.toggle_io_panes, { desc = "Toggle inp.txt / outp.txt panes" })
map("n", "<C-e>", runner.toggle_io_panes, { desc = "Toggle inp.txt / outp.txt panes" })
map("n", "<leader>c", runner.run, { desc = "Compile and run current file" })

-- GitHub Copilot toggle.
-- Reads and writes g:copilot_enabled directly, which is all `:Copilot
-- enable`/`disable` do. Two reasons not to go through them:
--   * the command only exists after the plugin lazy-loads on InsertEnter,
--     so <leader>o in a fresh session would error;
--   * copilot#Enabled() folds in per-buffer and per-filetype state, so it
--     reads 0 in a buffer Copilot skips even when it is globally on - the
--     toggle would then only ever say "enabled".
map("n", "<leader>o", function()
  -- Unset means on: that is copilot.vim's own default for this variable.
  local on = vim.g.copilot_enabled
  if on == nil then
    on = 1
  end
  vim.g.copilot_enabled = on == 1 and 0 or 1
  vim.notify("Copilot " .. (vim.g.copilot_enabled == 1 and "enabled" or "disabled"))
end, { desc = "Toggle GitHub Copilot" })
