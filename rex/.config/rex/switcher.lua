-- Agent switcher glue: collects every pane, writes the snapshot, opens the switcher.
-- This is the only file that uses the `rex` global.
local rows = require("switcher_rows")

local TERMINAL = "com.superlogical.terminal"

local function call(method, params)
	local ok, result = pcall(rex.call, method, params or {})
	if not ok then
		error("agent_switcher: " .. method .. " failed: " .. tostring(result))
	end
	return result
end

local function block_call(method, ids)
	local ok, result = pcall(rex.block.call, TERMINAL, method, ids)
	if not ok then
		return {}
	end
	return result or {}
end

local function cwd_of(ids)
	local pwd = block_call("pwd", ids).pwd
	if pwd and pwd ~= "" then
		return rows.path(pwd)
	end
	local process = block_call("process", ids)
	return process.foreground and process.foreground.cwd or ""
end

-- Only a pane without records needs its process name. A pane with records gets its program from
-- the winning record, which switcher_rows picks.
local function program_of(records, ids)
	if #records > 0 then
		return ""
	end
	local process = block_call("process", ids)
	return process.foreground and process.foreground.name or ""
end

local function labels_by_id(items, key)
	local labels = {}
	for _, item in ipairs(items or {}) do
		labels[item[key]] = item.label
	end
	return labels
end

local function pane_for(session, tabs, block)
	local ids = { block_id = block.block_id, session_id = session.session_id }
	local records = block_call("program_status", ids).records or {}
	return {
		session_id = session.session_id,
		session = session.label,
		window_id = block.window_id,
		tab = tabs[block.window_id] or block.label or "",
		block_id = block.block_id,
		program = program_of(records, ids),
		cwd = cwd_of(ids),
		records = records,
	}
end

local function panes_of(session)
	local ids = { session_id = session.session_id }
	local blocks = call("session.list_blocks", ids).blocks or {}
	local tabs = labels_by_id(call("session.view", ids).windows, "window_id")
	local panes = {}
	for _, block in ipairs(blocks) do
		panes[#panes + 1] = pane_for(session, tabs, block)
	end
	return panes
end

local function collect()
	call("session.attach_all", { event_scope = "session" })
	local panes = {}
	for _, session in ipairs(call("session.list").sessions or {}) do
		for _, pane in ipairs(panes_of(session)) do
			panes[#panes + 1] = pane
		end
	end
	return panes
end

local function write_snapshot(lines)
	local path = os.tmpname()
	local file = assert(io.open(path, "w"))
	file:write(table.concat(lines, "\n"), "\n")
	file:close()
	return path
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

local function open_switcher(snapshot, client_id)
	rex.session.new_layer({
		bounds = { 0.15, 0.15, 0.7, 0.7 },
		layout = rex.layout.block({
			flavor = "com.superlogical.terminal.shell",
			options = { command = { os.getenv("HOME") .. "/.config/rex/switcher/pick.sh", snapshot, client_id } },
		}),
		focus = true,
	})
end

rex.action({
	name = "agent_switcher",
	title = "Agent switcher",
	keywords = "agents panes switch jump",
	run = function(ctx)
		local snapshot = write_snapshot(rows.lines(collect()))
		open_switcher(snapshot, client_id_of(ctx))
	end,
})
