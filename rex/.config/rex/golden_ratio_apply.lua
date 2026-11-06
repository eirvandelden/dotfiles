-- Golden ratio glue: reads the session view, asks golden_ratio for steps, resizes panes.
-- This is the only golden-ratio module besides the watcher that uses the `rex` global.
local golden_ratio = require("golden_ratio")
local config = require("golden_ratio_config")

local GoldenRatioApply = {}

local function window_of(view)
	for _, window in ipairs(view.windows or {}) do
		if window.window_id == view.active_window_id then
			return window
		end
	end
	return (view.windows or {})[1]
end

local function tiled_layer(window)
	for _, layer in ipairs(window.layers or {}) do
		if layer.kind == "tiled" then
			return layer
		end
	end
	return nil
end

local function view_of(session_id)
	local view, err = rex.session.view({ session_id = session_id })
	if not view then
		error("golden_ratio: view failed: " .. tostring(err))
	end
	return view
end

--- The focused block id of the session's active window, or nil.
function GoldenRatioApply.focused_block_id(session_id)
	local window = window_of(view_of(session_id))
	return window and window.focused_block_id
end

local function resize(session_id, step)
	local params = {
		session_id = session_id,
		direction = step.direction,
		before_block_id = step.before_block_id,
		after_block_id = step.after_block_id,
		ratio = step.ratio,
	}
	local _, err = rex.session.resize_pane(params)
	if err then
		error("golden_ratio: resize_pane failed: " .. tostring(err))
	end
end

--- Resizes the focused pane of the focused window's tiled layer in one session. Returns the number of resize calls.
--- Does nothing for a zoomed window or a window with no tiled layer.
--- Every Rex call inside carries session_id, because a timer's calls do not default to the event's session.
---@param session_id string|nil  the session to act on; nil means the script's own session
---@return integer
function GoldenRatioApply.apply(session_id)
	local window = window_of(view_of(session_id))
	if not window or window.zoomed_block_id then
		return 0
	end
	local layer = tiled_layer(window)
	if not layer then
		return 0
	end
	local steps = golden_ratio.plan(layer.layout, window.focused_block_id, config)
	for _, step in ipairs(steps) do
		resize(session_id, step)
	end
	return #steps
end

return GoldenRatioApply
