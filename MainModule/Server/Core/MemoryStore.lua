return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service
	local settings = envArgs.settings

	local realWait = envArgs.realWait
	local base64Encode = server.Base64.encode
	local base64Decode = server.Base64.decode
	local getRandom = service.getRandom
	local cloneTable = service.cloneTable

	local tulirAES = server.TulirAES
	local luaParser = server.LuaParser
	local hashLib = server.HashLib
	local compression = server.Compression
	local studioServer = server.Studio

	local compressConfig = {
		level = 5,
		strategy = "dynamic",
	}

	local canWrite = false
	local canRead = false
	local didLoad = false
	local readyEv = server.Signal.new()

	local memoryStoreRetryAttempts = 3
	local memoryStoreRetryWait = 7

	local memoryStoreKey, memoryStorePlayerData, memoryStoreProtectIndex, memoryStoreQueuePlayerDataSaves

	--[[
			COMING SOON
	--]]
end
