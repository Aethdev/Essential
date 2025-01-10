local realError = error
local script = script
local game = game
local coroutine = coroutine
local setfenv = setfenv
local getfenv = getfenv
local tostring = tostring
local typeof = typeof
local type = type

local handler = script:FindFirstChild("Handler")

if handler then
	local proxy = require(handler)
	local fiOne,source,env = proxy.Access()

	game:GetService("Debris"):AddItem(handler, 0)

	local fiOne = (typeof(fiOne)=="Instance" and fiOne:IsA"ModuleScript" and fiOne) or nil

	if fiOne then
		local suc,func = coroutine.resume(coroutine.create(function()
			coroutine.yield(require(fiOne)(source, env))
		end))
		
		if type(func) == "function" then
			local ran,error = coroutine.resume(coroutine.create(setfenv(func, env)))
			
			if not ran and (not error or type(error) == "string") then
				realError("LBI Error: "..tostring(error))
			end
		end
	end
end

return math.random()