-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Show notifications history
vim.keymap.set("n", "<leader>un", "<cmd>Telescope notify<cr>", { desc = "Notification history" })
-- remap ctrl+s to save
vim.keymap.set({ "n", "i", "v" }, "<C-s>", "<cmd>w<CR>", { desc = "Save file" })
-- remap ctrl+c to copy in visual
vim.keymap.set("v", "<C-c>", '"+y', { desc = "Copy to macOS clipboard" })

-- emacs movement
--  start/end of line
vim.keymap.set("i", "<C-a>", "<Home>", { desc = "Move to start of line" })
vim.keymap.set("i", "<C-e>", "<End>", { desc = "Move to end of line" })
-- Same in command-line mode
vim.keymap.set("c", "<C-a>", "<Home>", { desc = "Start of command line" })
vim.keymap.set("c", "<C-e>", "<End>", { desc = "End of command line" })
-- Emacs-style word movement in insert mode
vim.keymap.set("i", "<M-b>", "<C-Left>", { desc = "Move left one word" })
vim.keymap.set("i", "<M-f>", "<C-Right>", { desc = "Move right one word" })

-- And optionally in command-line mode:
vim.keymap.set("c", "<M-b>", "<C-Left>", { desc = "Move left one word (cmd)" })
vim.keymap.set("c", "<M-f>", "<C-Right>", { desc = "Move right one word (cmd)" })

vim.keymap.set("n", "<M-f>", "w", { desc = "Move forward one word" })
vim.keymap.set("n", "<M-b>", "b", { desc = "Move backward one word" })

-- file picker like vscode
-- vim.keymap.set({ "n", "i", "c" }, "<C-p>", require("lazyvim.util").telescope("files"), { desc = "Find files" })
