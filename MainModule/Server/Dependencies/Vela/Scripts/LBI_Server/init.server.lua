local handler = script:FindFirstChild("Handler")
local realError = error
local warn = warn
local script = script
local tostring = tostring
local coroutine = coroutine
local require = require
local type = type

if handler then
	local proxy = require(handler)
	local fiOne,source,env = proxy.Access()
	
	handler:Destroy()
	
	if fiOne and source and env then
		local suc,func = coroutine.resume(coroutine.create(function()
			coroutine.yield(require(fiOne)(source, env))
		end))
	
		if type(func) == "function" then
			func()
			
			return
		end
	
		if not suc then
			realError("LBI encountered an error: "..tostring(error), 0)
		end
	end
end