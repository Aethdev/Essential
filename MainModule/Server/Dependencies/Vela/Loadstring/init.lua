--[[
		Interested in improving your skills as a Developer? Needing help publishing and marketing your game?
		Join Bleu Pigs! The self improvement community built around you
		https://devforum.roblox.com/u/bleupigs/summary
		
		Join our Minecraft server: https://discord.gg/msXKffKWEt
		
		Support my future projects on Patreon: https://www.patreon.com/reinitialized
		---------------
		vLua 5.1 - Lua written in Lua Virtual Machine
		---------------
		vLua is a virtual machine and compiler for dynamically compiling and executing Lua.
		It'll work on both client and server, regardless of LoadStringEnabled. This module is
		designed to be a drop in replacement for loadstring, meaning you can do the following:
		
		Example:
			local loadstring = require(workspace.Loadstring)
			local executable, compileFailReason = loadstring("print('hello from vLua!')")
			executable()
		
		Please note, vLua IS SLOWER COMPARED TO vanilla Lua, although Luau does improve performance.
		Do not attemptp to run performance intensive tasks without testing first, otherwise you
		may have a bad time.
		
		Changelog:
			[1/18/2022]
				- updated FiOne to latest release - https://github.com/Rerumu/FiOne/commit/900413a8491a44daa7770d799c85ad6df8610eea
				- added link to Minecraft server Discord
			[1/1/2022]
				- fixed environment not being properly set for compiled function
			[11/12/2021]
				- removed previous changelogs
				- updated FiOne to latest release - https://github.com/Rerumu/FiOne/blob/f443116e947e5bb3fe8bb7e6abca78214a245145/source.lua
				- fixed attempt to call a nil value error
		
		Credits:
			- FiOne LBI (created by same author as Rerubi) - https://github.com/Rerumu/FiOne
			- Yueliang 5 (Lua compiler in Lua) - http://yueliang.luaforge.net/
			- Moonshine (improved version of Yeuliang) - https://github.com/gamesys/moonshine
]]
local compile = require(script:WaitForChild "Yueliang")
local createExecutable = require(script:WaitForChild "FiOne")
getfenv().script = nil

return function(source, env)
	local executable
	local env = env or getfenv(2)
	local name = (env.script and env.script:GetFullName())
	local compiledBytecode = nil
	local ran, failureReason = pcall(function()
		compiledBytecode = compile(source, name)
		executable = createExecutable(compiledBytecode, env)
	end)

	if ran then return setfenv(executable, env), compiledBytecode end
	return nil, failureReason
end
