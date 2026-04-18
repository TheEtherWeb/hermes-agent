--!strict
-- Simple service locator. Services register themselves; other services look
-- them up by name. Avoids require-cycle hell and gives us one place to iterate.

local Services = {}

local registry: { [string]: any } = {}

function Services.register(name: string, service: any)
	if registry[name] then
		warn("[Services] duplicate registration: " .. name)
	end
	registry[name] = service
end

function Services.get(name: string): any
	local s = registry[name]
	if not s then
		error("[Services] not registered: " .. name, 2)
	end
	return s
end

function Services.optional(name: string): any?
	return registry[name]
end

function Services.all(): { [string]: any }
	return registry
end

return Services
