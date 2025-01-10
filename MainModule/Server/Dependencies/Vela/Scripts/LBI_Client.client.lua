local func = script:FindFirstChild "Function"
local fiOne = script:FindFirstChild "FiOne"
local type = type
local coroutine = coroutine

fiOne = (fiOne and fiOne:Clone()) or nil

if fiOne and func then
	local source = func:InvokeServer()

	if type(source) == "string" then
		local suc, func =
			coroutine.resume(coroutine.create(function() coroutine.yield(require(fiOne)(source, getfenv(0))) end))

		if type(func) == "function" then
			local ran, error = coroutine.resume(coroutine.create(setfenv(func, getfenv(0))))

			if not ran and type(error) == "string" then warn("LBI ERROR: " .. error) end

			return
		end
	end
end
