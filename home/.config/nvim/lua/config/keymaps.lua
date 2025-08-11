-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Show notifications history
vim.keymap.set("n", "<leader>un", "<cmd>Telescope notify<cr>", { desc = "Notification history" })
