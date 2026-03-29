-- Dream Delinquent: SharedRegistry
-- Shared server-side table of active player sessions.
-- Both GameManager and CombatManager reference this.

local SharedRegistry = {}

local _sessions = {}  -- [userId] = session

function SharedRegistry.set(userId, session)
	_sessions[userId] = session
end

function SharedRegistry.get(userId)
	return _sessions[userId]
end

function SharedRegistry.remove(userId)
	_sessions[userId] = nil
end

function SharedRegistry.getAll()
	return _sessions
end

return SharedRegistry
