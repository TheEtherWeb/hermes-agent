--!strict
-- Minimal in-memory signal. Avoids depending on Roblox BindableEvent wrappers.

local Signal = {}
Signal.__index = Signal

export type Connection = { disconnect: (Connection) -> () }

function Signal.new()
	return setmetatable({ _slots = {} }, Signal)
end

function Signal:connect(fn: (...any) -> ())
	local slot = { fn = fn, alive = true }
	table.insert(self._slots, slot)
	local conn = {}
	function conn.disconnect()
		slot.alive = false
	end
	return conn
end

function Signal:fire(...)
	local toRemove: { number } = {}
	for i, slot in ipairs(self._slots) do
		if slot.alive then
			local ok, err = pcall(slot.fn, ...)
			if not ok then
				warn("[Signal] handler errored: " .. tostring(err))
			end
		else
			table.insert(toRemove, i)
		end
	end
	for j = #toRemove, 1, -1 do
		table.remove(self._slots, toRemove[j])
	end
end

function Signal:destroy()
	self._slots = {}
end

return Signal
