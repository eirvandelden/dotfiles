-- Pure row builder for the agent switcher. It needs no `rex` global.
local SwitcherRows = {}

-- Most urgent first. A pane without a record is a shell and sorts last.
local RANK = { blocked = 1, error = 2, done = 3, working = 4, idle = 5, shell = 6 }

local function clean(value)
	local text = tostring(value == nil and "" or value)
	return (text:gsub("[\t\r\n]", " "))
end

local function most_urgent(records)
	local best
	for _, record in ipairs(records or {}) do
		if not best or (RANK[record.state] or 5) < (RANK[best.state] or 5) then
			best = record
		end
	end
	return best
end

-- The program of the winning record, else the program the pane reported.
local function program_of(record, pane)
	return record and (record.effective_app or record.app) or pane.program
end

local function row_for(pane)
	local record = most_urgent(pane.records)
	local state = record and record.state or "shell"
	local fields = {
		state,
		clean(pane.session) .. " / " .. clean(pane.tab),
		clean(program_of(record, pane)),
		clean(pane.cwd),
		clean(record and record.msg),
		clean(pane.session_id),
		clean(pane.window_id),
		clean(pane.block_id),
	}
	return { rank = RANK[state] or 5, text = table.concat(fields, "\t") }
end

-- A file:// URL as a plain path, percent escapes decoded. Any other text is returned as it is.
function SwitcherRows.path(url)
	local path = url:gsub("^file://[^/]*", "")
	return (path:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

-- Turns collected panes into one snapshot line (8 tab-separated fields) per pane.
function SwitcherRows.lines(panes)
	local rows = {}
	for index, pane in ipairs(panes) do
		local row = row_for(pane)
		row.index = index
		rows[#rows + 1] = row
	end
	table.sort(rows, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.index < b.index
	end)
	local lines = {}
	for _, row in ipairs(rows) do
		lines[#lines + 1] = row.text
	end
	return lines
end

return SwitcherRows
