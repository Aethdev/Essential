message = nil

local policies = {}
policies._clientPolicies = setmetatable({}, {
	__index = function(self, index)
		return {
			type = "MANDATORY";
			value = nil;
		}
	end;
})
policies._policyChangeEvents = {}

local client, service
local Signal

local function trimString(str: string): string|nil
	return string.match(str, "^%s*(.-)%s*$")
end

--[[
	DEFAULT CLIENT POLICIES
]]

function policies:setup()
	policies.setup = nil
	
	-- Connecting to PolicyManager session
	local policySessionId = client.Network:get("FindSession", "PolicyManager")
	local policySession = client.Remote.makeSession(policySessionId)
	
	local policyChanged = policySession:connectEvent(`PolicyChanged`)
	policyChanged:connect(function(sentOs: number, policyName: string, policyValue: string|number|boolean|{[number]: any}|nil, policyType: string)
		if policyName == "_BULK_" then
			for policyName, policyInfo: {type: string, value: string|number|boolean|{[number]: any}} in policyValue do
				policies._clientPolicies[policyName] = {
					type = policyInfo.type;
					value = policyInfo.value;
				}
				policies:_firePolicyChangeEvent(policyName, policyInfo.type, policyInfo.value)
				warn("BULK POLICY CHANGE EVENT FIRED:", policyName, policyType, `->`, policyValue)
			end
			
			return
		end
		
		warn("POLICY CHANGE EVENT FIRED:", policyName, policyType, `->`, policyValue)
		
		policies._clientPolicies[policyName] = {
			type = policyType;
			value = policyValue;
		}
		policies:_firePolicyChangeEvent(policyName, policyValue, policyType)
	end)
	
	local currentlySetPolicies: {[string]: {type: string, value: string|number|boolean|{[number]: any}}} = policySession:runCommand("GetPolicies", true)
	for policyName, policyInfo: {type: string, value: string|number|boolean|{[number]: any}} in currentlySetPolicies do
		policies._clientPolicies[policyName] = policyInfo
		policies:_firePolicyChangeEvent(policyName, policyInfo.value, policyInfo.type)
	end
	
	return policies
end

function policies:get(policyName: string)
	return policies._clientPolicies[policyName]
end

function policies:set(policyName: string, value: string|number|boolean|{[number]: any}|nil)
	assert(type(policyName) == "string" or trimString(policyName:upper()) ~= policyName, `Policy name is not valid`)
	assert(type(value) == "string" or type(value) == "boolean" or type(value) == "table" or type(value) == "nil", `Policy value must be a string/boolean/table/nil`)

	policyName = trimString(policyName:upper())
	if type(value) == "table" then
		assert(service.isTableCircular(value), `Policy value is circular`)
		value = service.cloneTable(value)
	end
	
	policies._clientPolicies[policyName] = {
		type = `CLIENT`;
		value = value;
	}
	policies:_firePolicyChangeEvent(policyName, value, `CLIENT`)
end

function policies:_getPolicyChangeEvent(policyName: string)
	local policyChangeEvent = policies._policyChangeEvents[policyName]
	if not policyChangeEvent then
		policyChangeEvent = Signal.new()
		policies._policyChangeEvents[policyName] = policyChangeEvent
	end
	
	return policyChangeEvent
end

function policies:_firePolicyChangeEvent(policyName: string, ...)
	local policyChangeEvent = policies:_getPolicyChangeEvent(policyName)
	
	policyChangeEvent:fire(...)
	policies.changed:fire(policyName, ...)
	
	return policies
end

function policies:connectPolicyChangeEvent(policyName: string, executeFunc: (...any) -> any)
	return policies:_getPolicyChangeEvent(policyName):connect(executeFunc)
end

function policies.Init(env)
	client = env.client
	service = env.service
	Signal = client.Signal
	
	policies.changed = Signal.new()
end

return policies