return {
  {
    dir = "/home/ray/proj/neiltree",
    name = "neiltree.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
  },

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
}
