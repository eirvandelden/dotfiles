return {
  "rcarriga/nvim-notify",
  opts = {
    stages = "fade",
    timeout = 3000,
    background_colour = "#000000",
    render = "default",
    fps = 60,
    top_down = true,
  },
  config = function(_, opts)
    local notify = require("notify")
    notify.setup(opts)
    vim.notify = notify

    -- Defer loading the Telescope extension until Telescope is available
    vim.api.nvim_create_autocmd("User", {
      pattern = "TelescopeLoaded",
      callback = function()
        pcall(function()
          require("telescope").load_extension("notify")
        end)
      end,
    })
  end,
}
