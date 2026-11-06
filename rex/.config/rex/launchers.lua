-- Launcher actions: the file viewer (worktree-viewer) and lazygit, each in a split or a window.
-- The viewer runs inside a short-lived floating layer, because an action cannot run a shell command
-- itself: the layer runs worktree-viewer with the calling block's ids, which opens the viewer and
-- ends, and Rex closes the layer when its command ends. lazygit is placed directly, rooted at the
-- calling block's folder.
local rows = require("switcher_rows")

local TERMINAL = "com.superlogical.terminal"
local SHELL = TERMINAL .. ".shell"

local function terminal_block(command)
	return rex.layout.block({ flavor = SHELL, options = { command = command } })
end

local function cwd_of(ctx)
	local ok, answer = pcall(rex.block.call, TERMINAL, "pwd", { block_id = ctx.block_id, session_id = ctx.session_id })
	local pwd = ok and answer and answer.pwd or ""
	if pwd ~= "" then
		return rows.path(pwd)
	end
	return os.getenv("HOME")
end

local function viewer(program, mode)
	return function(ctx)
		local script = os.getenv("HOME") .. "/.config/git/worktree-tools/" .. program
		local command = { "env", "REX_SESSION=" .. ctx.session_id, "REX_BLOCK=" .. ctx.block_id, script, mode }
		rex.session.new_layer({ bounds = { 0.4, 0.4, 0.2, 0.2 }, layout = terminal_block(command), focus = false })
	end
end

local function lazygit_command(ctx)
	return { "sh", "-c", 'cd "$1" && exec lazygit', "lazygit", cwd_of(ctx) }
end

local function lazygit_split(ctx)
	rex.session.new_split({
		anchor_id = ctx.block_id,
		direction = "horizontal",
		side = "after",
		layout = terminal_block(lazygit_command(ctx)),
		focus = true,
	})
end

local function lazygit_tab(ctx)
	rex.session.new_window({ window_label = "lazygit", layout = terminal_block(lazygit_command(ctx)), focus = true })
end

local actions = {
	{ name = "file_viewer_split", title = "File viewer beside this block", run = viewer("worktree-viewer", "split") },
	{ name = "file_viewer_tab", title = "File viewer in a new window", run = viewer("worktree-viewer", "tab") },
	{ name = "lazygit_split", title = "lazygit beside this block", run = lazygit_split },
	{ name = "lazygit_tab", title = "lazygit in a new window", run = lazygit_tab },
}

for _, action in ipairs(actions) do
	action.keywords = "files git viewer lazygit"
	rex.action(action)
end
