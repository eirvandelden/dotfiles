-- Project picker glue: opens a floating layer that runs project/pick.sh.
-- This is the only file in this feature that uses the `rex` global.
local TERMINAL = "com.superlogical.terminal"

local function block_call(method, ids)
	local ok, result = pcall(rex.block.call, TERMINAL, method, ids)
	if not ok then
		return {}
	end
	return result or {}
end

local function cwd_of(ctx)
	local ids = { block_id = ctx and ctx.block_id }
	local pwd = block_call("pwd", ids).pwd
	if pwd and pwd ~= "" then
		return (pwd:gsub("^file://[^/]*", ""))
	end
	local process = block_call("process", ids)
	return process.foreground and process.foreground.cwd or nil
end

local function client_id_of(ctx)
	if ctx and ctx.client_id then
		return ctx.client_id
	end
	for _, client in ipairs((rex.session.list_clients({}) or {}).clients or {}) do
		if client.info and client.info.kind == "app" then
			return client.client_id
		end
	end
	return ""
end

local function open_picker(ctx)
	rex.session.new_layer({
		bounds = { 0.25, 0.2, 0.5, 0.5 },
		layout = rex.layout.block({
			flavor = "com.superlogical.terminal.shell",
			options = {
				command = { os.getenv("HOME") .. "/.config/rex/project/pick.sh", client_id_of(ctx) },
				cwd = cwd_of(ctx),
			},
		}),
		focus = true,
	})
end

rex.action({
	name = "open_project",
	title = "Open project",
	keywords = "project repo open session",
	run = open_picker,
})
