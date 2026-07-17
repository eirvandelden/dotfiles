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

    vim.api.nvim_create_user_command("Notifications", function()
      for _, record in ipairs(notify.history()) do
        vim.notify(table.concat(record.message, "\n"), record.level)
      end
    end, { desc = "Show notification history" })
  end,
}
