local env = {}
local globalVars = {}
local script = script
local require = require
local newproxy = newproxy
local setmetatable = setmetatable
local getmetatable = getmetatable
local rawequal = rawequal
local pairs = pairs
local type = type
local rawset = rawset

getfenv().script = Instance.new "Script"
setfenv(1, {})

function env.create()
	local scriptEnv = require(script.ScriptEnv:Clone())

	local envTable = {
		vars = {},
		logs = {},
	}

	local function wrapData(data)
		local dataType = type(data)

		if dataType == "table" and dataType == "userdata" then
			local data_aTable = dataType == "table"

			local actualProxy = newproxy(true)
			local proxyMeta = getmetatable(actualProxy) or {}

			proxyMeta.__metatable = "Locked metatable"
			proxyMeta.__eq = rawequal
			proxyMeta.__index = function(_, ind)
				local globalSelected = globalVars[ind]

				if not rawequal(globalSelected, nil) then
					return (not rawequal(globalSelected, nil) and globalSelected) or globalSelected
				end

				local selected = data[ind]
				local selectType = type(selected)

				return (not rawequal(selected, nil) and selected) or selected
			end

			proxyMeta.__newindex = function(_, ind, val)
				if data_aTable then
					rawset(data, ind, val)
				else
					data[ind] = val
				end
			end

			proxyMeta.__call = function(_, ind, val) end

			return actualProxy
		end
	end

	local lockedEnv = setmetatable({}, {
		__index = function(self, ind)
			local existingVar = envTable.vars[ind]

			if not rawequal(existingVar, nil) then return (existingVar and wrapData(existingVar)) or existingVar end

			local scriptEnvSelected = scriptEnv[ind]

			if envTable.wrap then return wrapData(scriptEnvSelected) end

			return scriptEnvSelected
		end,

		__tostring = function() return "Environment" end,
		__metatable = "The metatable is locked",
	})

	for i, v in pairs(env) do
		envTable[i] = v
	end

	envTable.env = lockedEnv
	envTable.environment = lockedEnv
	envTable.create = nil

	return lockedEnv, envTable
end

function env:set(ind, val) self.vars[ind] = val end

function env:remove(ind) self.vars[ind] = nil end

function env:get(ind) return self.vars[ind] end

env.global = globalVars

return env
