return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = { style = "night" }, -- "storm" | "moon" | "night" | "day"
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      options = { theme = "tokyonight" },
      sections = {
        -- Restates lualine's own default for this section ({ "filename" }) so
        -- that adding to it does not silently drop it.
        lualine_c = {
          "filename",
          {
            -- Live clock for <leader>c / <leader>C, plus the way out. The
            -- runner drives the redraws; see start_ticking there.
            function()
              local ms, phase, untimed = require("config.runner").progress()
              return ("%s %.1fs%s  <leader>s stops"):format(
                phase,
                ms / 1000,
                untimed and " (no timeout)" or ""
              )
            end,
            cond = function()
              return require("config.runner").progress() ~= nil
            end,
          },
        },
      },
    },
  },
}
