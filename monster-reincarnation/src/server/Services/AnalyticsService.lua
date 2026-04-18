--!strict
-- Tracks anonymous metrics for tuning and retention analysis. Buffers events
-- and ships them via HttpService to an external ingest URL every minute.

local HttpService = game:GetService("HttpService")
local RunService  = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util: any = require(Shared:WaitForChild("Util"))

local AnalyticsService = {}

local INGEST_URL = ""   -- set to your endpoint, leave blank to disable
local BATCH_MAX  = 100
local FLUSH_SEC  = 60

local queue: { any } = {}

function AnalyticsService.track(eventName: string, data: any?)
	if typeof(eventName) ~= "string" then return end
	local payload = Util.sanitize(data) or {}
	payload.event = eventName
	payload.ts = os.time()
	payload.placeId = game.PlaceId
	payload.jobId = game.JobId
	table.insert(queue, payload)
	if #queue > BATCH_MAX * 2 then
		while #queue > BATCH_MAX do table.remove(queue, 1) end
	end
end

local function flush()
	if #queue == 0 or INGEST_URL == "" then return end
	local batch = {}
	for i = 1, math.min(BATCH_MAX, #queue) do
		table.insert(batch, queue[i])
	end
	local ok, err = pcall(function()
		HttpService:PostAsync(INGEST_URL, HttpService:JSONEncode(batch), Enum.HttpContentType.ApplicationJson)
	end)
	if ok then
		for _ = 1, #batch do table.remove(queue, 1) end
	else
		warn("[Analytics] flush failed: " .. tostring(err))
	end
end

function AnalyticsService.start()
	if not RunService:IsServer() then return end
	task.spawn(function()
		while true do
			task.wait(FLUSH_SEC)
			flush()
		end
	end)
end

return AnalyticsService
