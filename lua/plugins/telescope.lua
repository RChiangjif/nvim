-- live_grep hard-requires ripgrep; find_files is much faster with fd.
-- macOS:   brew install ripgrep fd
-- Windows: winget install BurntSushi.ripgrep.MSVC sharkdp.fd
local function need(exe, fn)
  return function()
    if vim.fn.executable(exe) == 0 then
      local hint = vim.fn.has("win32") == 1 and "winget install BurntSushi.ripgrep.MSVC"
        or "brew install ripgrep"
      return vim.notify(("`%s` not found on PATH. Install it: %s"):format(exe, hint), vim.log.levels.ERROR)
    end
    require("telescope.builtin")[fn]()
  end
end

local function builtin(fn)
  return function()
    require("telescope.builtin")[fn]()
  end
end

return {
  "nvim-telescope/telescope.nvim",
  tag = "0.1.8",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = "Telescope",
  keys = {
    { "<leader>ff", builtin("find_files"), desc = "Telescope find files" },
    { "<leader>fg", need("rg", "live_grep"), desc = "Telescope live grep" },
    { "<leader>fb", builtin("buffers"), desc = "Telescope buffers" },
    { "<leader>fh", builtin("help_tags"), desc = "Telescope help tags" },
  },
  opts = {},
}
