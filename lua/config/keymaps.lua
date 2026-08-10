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
  vim.cmd("split " .. vim.fn.fnameescape(P.config_dir))
end, { desc = "Open nvim config directory" })

-- File explorers
map("n", "<leader>n", "<CMD>NvimTreeToggle<CR>", { desc = "Toggle nvim-tree" })
map("n", "<leader>m", "<CMD>Oil --float<CR>", { desc = "Open parent directory (Oil)" })

-- Competitive programming
map("n", "<leader>e", runner.open_io_panes, { desc = "Open inp.txt / outp.txt panes" })
map("n", "<leader>c", runner.run, { desc = "Compile and run current file" })

-- GitHub Copilot toggle
map("n", "<leader>o", function()
  local ok, enabled = pcall(vim.fn["copilot#Enabled"])
  if not ok then
    return vim.notify("Copilot is not loaded", vim.log.levels.WARN)
  end
  if enabled == 1 then
    vim.cmd("Copilot disable")
    vim.notify("Copilot disabled")
  else
    vim.cmd("Copilot enable")
    vim.notify("Copilot enabled")
  end
end, { desc = "Toggle GitHub Copilot" })
