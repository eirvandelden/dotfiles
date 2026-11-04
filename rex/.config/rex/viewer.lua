-- Changed-files viewer glue: opens the viewer layer on the focused pane's directory.
-- This is the only viewer file that uses the `rex` global.
local rows = require("switcher_rows")

local TERMINAL = "com.superlogical.terminal"

local function cwd_of(ctx)
	if not (ctx and ctx.block_id) then
		return ""
	end
	local ids = { block_id = ctx.block_id, session_id = ctx.session_id }
	local ok, result = pcall(rex.block.call, TERMINAL, "pwd", ids)
	if not ok or type(result) ~= "table" or not result.pwd or result.pwd == "" then
		return ""
	end
	return rows.path(result.pwd)
end

local function open_viewer(cwd)
	rex.session.new_layer({
		bounds = { 0.05, 0.05, 0.9, 0.9 },
		layout = rex.layout.block({
			flavor = "com.superlogical.terminal.shell",
			options = { command = { os.getenv("HOME") .. "/.config/rex/viewer/pick.sh", cwd } },
		}),
		focus = true,
	})
end

rex.action({
	name = "file_viewer",
	title = "Changed files",
	keywords = "files diff changes review",
	run = function(ctx)
		open_viewer(cwd_of(ctx))
	end,
})
