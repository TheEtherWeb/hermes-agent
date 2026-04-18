--!strict
-- Small shared helpers. No side effects.

local HttpService = game:GetService("HttpService")

local Util = {}

function Util.uuid(): string
	return HttpService:GenerateGUID(false)
end

function Util.now(): number
	return os.time()
end

function Util.clamp(x: number, a: number, b: number): number
	if x < a then return a end
	if x > b then return b end
	return x
end

function Util.deepCopy<T>(t: T): T
	if typeof(t) ~= "table" then return t end
	local out: any = {}
	for k, v in pairs(t :: any) do
		out[k] = Util.deepCopy(v)
	end
	return out :: any
end

function Util.weightedPick<T>(options: { { weight: number, value: T } }): T
	local total = 0
	for _, o in ipairs(options) do total += o.weight end
	local roll = math.random() * total
	local acc = 0
	for _, o in ipairs(options) do
		acc += o.weight
		if roll <= acc then return o.value end
	end
	return options[#options].value
end

function Util.throttle(fn: (...any) -> (), intervalSec: number)
	local last = 0
	return function(...)
		local t = os.clock()
		if t - last >= intervalSec then
			last = t
			fn(...)
		end
	end
end

-- For RemoteEvent/Function inputs: reject tables-in-tables deeper than depth,
-- strip Instances/userdata. Prevents the "malicious Instance in remote" class
-- of exploit described in DataStore vulnerability write-ups.
function Util.sanitize(value: any, depth: number?): any
	depth = depth or 0
	if depth > 4 then return nil end
	local t = typeof(value)
	if t == "string" then
		if #value > 512 then return string.sub(value, 1, 512) end
		return value
	elseif t == "number" or t == "boolean" then
		return value
	elseif t == "table" then
		local out = {}
		local n = 0
		for k, v in pairs(value) do
			n += 1
			if n > 64 then break end
			if typeof(k) == "string" or typeof(k) == "number" then
				out[k] = Util.sanitize(v, (depth :: number) + 1)
			end
		end
		return out
	end
	return nil  -- Instance, userdata, function -> dropped
end

function Util.tableLen(t: { [any]: any }): number
	local n = 0
	for _ in pairs(t) do n += 1 end
	return n
end

return Util
