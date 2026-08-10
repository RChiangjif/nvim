return {
  {
    "stevearc/oil.nvim",
    -- Lazy loading is not recommended: it is very tricky to make it work
    -- correctly in all situations.
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      view_options = {
        show_hidden = true,
      },
    },
  },

  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "NvimTreeToggle", "NvimTreeOpen", "NvimTreeFocus" },
    opts = {
      sort = { sorter = "suffix" },
      view = { width = 30 },
      renderer = { group_empty = true },
      filters = { dotfiles = false },
    },
  },
}
