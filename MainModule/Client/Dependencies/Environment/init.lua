local env = {}

function env.create()
	local scriptEnv = require(script.ScriptEnv:Clone())
	
	local envTable = {
		vars = {};
	}
	
	local lockedEnv = setmetatable({},{
		__index = function(self, ind)
			local existingVar = envTable.vars[ind]
			
			if not rawequal(existingVar, nil) then
				return existingVar
			end
			
			return scriptEnv[ind]
		end;
		
		__tostring = function() return "Environment" end;
		__metatable = "The metatable is locked";
	})
	
	for i,v in pairs(env) do
		envTable[i] = v
	end
	
	envTable.env = lockedEnv
	envTable.environment = lockedEnv
	envTable.create = nil
	
	return lockedEnv,envTable
end

function env:set(ind, val)
	self.vars[ind] = val
end

function env:remove(ind)
	self.vars[ind] = nil
end

function env:get(ind)
	return self.vars[ind]
end

return env
