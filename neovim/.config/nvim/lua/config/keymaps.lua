-- Keymaps are automatically loaded on the VeryLazy event
-- Add any additional keymaps here
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
-- exit terminal mode with Escape
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Terminal: exit to Normal", silent = true })

-- window focus (LazyVim binds <C-hjkl> to these; on Dvorak those keys are
-- scattered, so arrow keys give an ergonomic alternative)
vim.keymap.set("n", "<C-Left>", "<C-w>h", { desc = "Go to left window" })
vim.keymap.set("n", "<C-Down>", "<C-w>j", { desc = "Go to lower window" })
vim.keymap.set("n", "<C-Up>", "<C-w>k", { desc = "Go to upper window" })
vim.keymap.set("n", "<C-Right>", "<C-w>l", { desc = "Go to right window" })

-- bufferline
vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- neotest
vim.keymap.set("n", "<leader>tr", function()
  require("neotest").run.run()
end, { desc = "Test: run nearest" })
vim.keymap.set("n", "<leader>tf", function()
  require("neotest").run.run(vim.fn.expand("%"))
end, { desc = "Test: run file" })
vim.keymap.set("n", "<leader>ts", function()
  require("neotest").summary.toggle()
end, { desc = "Test: summary" })
vim.keymap.set("n", "<leader>to", function()
  require("neotest").output.open({ enter = true })
end, { desc = "Test: output" })

-- dap
vim.keymap.set("n", "<leader>db", function()
  require("dap").toggle_breakpoint()
end, { desc = "Debug: toggle breakpoint" })
vim.keymap.set("n", "<leader>dc", function()
  require("dap").continue()
end, { desc = "Debug: continue" })
vim.keymap.set("n", "<leader>di", function()
  require("dap").step_into()
end, { desc = "Debug: step into" })
vim.keymap.set("n", "<leader>do", function()
  require("dap").step_out()
end, { desc = "Debug: step out" })
vim.keymap.set("n", "<leader>du", function()
  require("dapui").toggle()
end, { desc = "Debug: toggle UI" })

-- gitsigns
vim.keymap.set("n", "]h", function()
  require("gitsigns").next_hunk()
end, { desc = "Next hunk" })
vim.keymap.set("n", "[h", function()
  require("gitsigns").prev_hunk()
end, { desc = "Prev hunk" })
vim.keymap.set("n", "<leader>gp", function()
  require("gitsigns").preview_hunk()
end, { desc = "Preview hunk" })
vim.keymap.set("n", "<leader>gb", function()
  require("gitsigns").blame_line({ full = true })
end, { desc = "Blame line" })

vim.keymap.set("n", "<leader>l", "<cmd>Lazy<cr>", { desc = "Lazy" })
