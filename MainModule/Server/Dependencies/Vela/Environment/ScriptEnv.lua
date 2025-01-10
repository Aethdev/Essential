local realEnv = getfenv(0)
local type = type
local newproxy = newproxy
local setfenv = setfenv
local getfenv = getfenv
local getmetatable = getmetatable

local metaFunc = function(func)
	local newprox = newproxy(true)
	local meta = getmetatable(newprox)
	meta.__metatable = "Sandbox function"
	meta.__tostring = function() return "function" end
	meta.__call = function(self, ...) return func(...) end

	return newprox
end

return setmetatable({}, {
	__index = function(self, ind)
		local selected = realEnv[ind]
		local selectType = type(selected)

		if selectType == "function" then
			return metaFunc(selected)
		else
			return selected
		end
	end,

	__metatable = "Env",
})
