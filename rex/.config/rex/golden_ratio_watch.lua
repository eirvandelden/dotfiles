-- Golden ratio watcher: run as `rex do golden_ratio_watch.lua --all`.
-- Resizes a session once per focus change. Acts only when the focused block id differs from the
-- last one handled in that session, so its own resizes (same focused id) never loop.
local apply = require("golden_ratio_apply")
local config = require("golden_ratio_config")

local last_handled = {}
local pending = {}

local function schedule(session_id)
	if pending[session_id] then
		pending[session_id]:cancel()
	end
	pending[session_id] = rex.after(config.debounce, function()
		pending[session_id] = nil
		local ok, err = pcall(apply.apply, session_id)
		if not ok then
			rex.log("golden_ratio_watch: " .. tostring(err))
		end
	end)
end

rex.on("session_view_changed", function(ctx)
	local session_id = ctx.session_id
	local ok, focused = pcall(apply.focused_block_id, session_id)
	if not ok or not focused or focused == last_handled[session_id] then
		return
	end
	last_handled[session_id] = focused
	schedule(session_id)
end)
