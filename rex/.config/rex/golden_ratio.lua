-- Golden ratio planner: pure, never touches the `rex` global.
-- plan() turns a tiled layout and a focused block into the resize steps that give that block
-- config.ratio of the layout on each axis.
local GoldenRatio = {}

local MIN_RATIO = 0.05
local MAX_RATIO = 0.95

local function check_ratio(ratio)
	if type(ratio) ~= "number" or ratio < MIN_RATIO or ratio > MAX_RATIO then
		error("golden ratio: config.ratio must be between " .. MIN_RATIO .. " and " .. MAX_RATIO)
	end
end

local function first_leaf(node)
	while node.split do
		node = node.split.before
	end
	return node.block_id
end

-- Returns the splits from the root down to the focused block, each with the side holding it.
local function path_to(node, block_id)
	if node.block_id then
		if node.block_id == block_id then
			return {}
		end
		return nil
	end
	for _, side in ipairs({ "before", "after" }) do
		local rest = path_to(node.split[side], block_id)
		if rest then
			table.insert(rest, 1, { split = node.split, side = side })
			return rest
		end
	end
	return nil
end

local function count_by_direction(path)
	local counts = {}
	for _, hop in ipairs(path) do
		counts[hop.split.direction] = (counts[hop.split.direction] or 0) + 1
	end
	return counts
end

local function step_for(hop, focused_block_id, share)
	local split = hop.split
	if hop.side == "before" then
		return {
			direction = split.direction,
			before_block_id = focused_block_id,
			after_block_id = first_leaf(split.after),
			ratio = share,
		}
	end
	return {
		direction = split.direction,
		before_block_id = first_leaf(split.before),
		after_block_id = focused_block_id,
		ratio = 1 - share,
	}
end

---@alias ResizeStep { direction: "horizontal"|"vertical", before_block_id: string, after_block_id: string, ratio: number }

--- Plans the resizes that give the focused block the golden share of the layout, outermost split first.
--- Returns {} when the block is absent, the layout is one leaf, or every split is within config.min_delta.
---@param layout table  a tiled layer layout: { rect, block_id } or { rect, split = { direction, ratio, before, after } }
---@param focused_block_id string
---@param config { ratio: number, min_delta: number }
---@return ResizeStep[]
function GoldenRatio.plan(layout, focused_block_id, config)
	check_ratio(config.ratio)
	local path = path_to(layout, focused_block_id)
	if not path then
		return {}
	end
	local counts = count_by_direction(path)
	local steps = {}
	for _, hop in ipairs(path) do
		local share = config.ratio ^ (1 / counts[hop.split.direction])
		local step = step_for(hop, focused_block_id, share)
		if math.abs(hop.split.ratio - step.ratio) > config.min_delta then
			steps[#steps + 1] = step
		end
	end
	return steps
end

return GoldenRatio
