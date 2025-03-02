return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service
	local settings = server.Settings
	local variables = envArgs.variables

	local Filter = server.Filter
	local Network = server.Network
	local Parser = server.Parser
	local Roles = server.Roles
	local Utility = server.Utility
	local Vela = server.Vela

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

	local compressionConfig = { level = 3 }

	local Cmds, Core, Cross, Datastore, Identity, Logs, Moderation, Process, Remote

	local CrossReady
	local Subscription
	local CrossKey
	local CrossCommands
	CrossCommands = {
		ExecuteCommand = function(jobId, data)
			if type(data) == "table" then
				local player = server.Parser:apifyPlayer({
					Name = data.playerName,
					UserId = data.playerId,
				}, true)

				if data.input then
					Process.playerCommand(player, data.input, data.cmdData or {})
				else
					if data.command and data.arguments then
						local realCommand = Cmds.get(data.command)

						if realCommand then Core.executeCommand(player, realCommand, data.arguments or {}) end
					end
				end
			end
		end,

		PublishMessage = function(jobId, ...)
			for i, plr in pairs(service.getPlayers(true)) do
				plr:sendData("SendMessage", ...)
			end
		end,

		CrossChat = function(jobId, speakerName, message, extraTags, channelName)
			channelName = channelName or "all"

			local generalChannel = (server.chatService and server.chatService:GetChannel(channelName))

			if generalChannel then
				local tempSpeaker = false

				local speaker = server.chatService:GetSpeaker("_" .. speakerName)
					or (function()
						tempSpeaker = true
						return server.chatService:AddSpeaker("_" .. speakerName)
					end)()

				local tempInChannel = false
				if not speaker:IsInChannel(channelName) then
					tempInChannel = true
					speaker:JoinChannel(channelName)
				end

				speaker:SayMessage(message, channelName, {
					Tags = {
						{ TagText = "Cross", TagColor = Color3.fromRGB(255, 255, 255) },
					},
				})

				if tempInChannel then
					tempInChannel = true
					speaker:LeaveChannel(channelName)
				end

				if tempSpeaker then server.chatService:RemoveSpeaker("_" .. speakerName) end
			end
		end,

		PrivateMessage = function(jobId, topic, message, expireOs, scheduledOs, sender, targets, crossEventId)
			local players = {}
			local fakePlayer = targets
				and Parser:apifyPlayer({
					Name = sender and service.playerNameFromId(sender.UserId) or "[unknown]",
					UserId = sender and service.playerNameFromId(sender.UserId) or -1,
				}, true)

			if targets then
				for i, plr in pairs(Parser:getPlayers(targets, fakePlayer)) do
					table.insert(players, plr)
				end
			else
				players = service.getPlayers(true)
			end

			for i, plr in pairs(players) do
				local pmData = Remote.privateMessage {
					receiver = plr,
					sender = sender or { Name = "[Unknown]", UserId = -1 },
					topic = topic,
					message = message,
					expireOs = expireOs,
					scheduledOs = scheduledOs,
				}
				pmData.dontMessageSender = true

				if crossEventId then
					pmData.replied:connectOnce(
						function(reply)
							Cross.send("FireEvent", crossEventId, plr.UserId, reply:sub(1, 300), expireOs, scheduledOs)
						end
					)
				end
			end
		end,

		Shutdown = function(jobId, reason, secsTillShutdown, moderatorId)
			server.Utility:shutdown(reason, secsTillShutdown, moderatorId)
		end,

		CheckBans = function() server.Moderation.checkBans() end,

		KickPlayers = function(jobId, playerIds, message)
			for i, userId in pairs(playerIds) do
				local plr = service.getPlayer(userId)

				if plr then
					local parsedPlr = Parser:apifyPlayer(plr)
					parsedPlr:Kick(message)
				end
			end
		end,

		FireEvent = function(jobId, eventId, ...)
			if eventId and variables.crossEvents[eventId] then variables.crossEvents[eventId]:fire(jobId, ...) end
		end,

		RetrieveServerInfo = function(jobId, callbackEventId)
			local serverInfo = service.cloneTable(variables.serverInfo or {})
			serverInfo.playerCount = #service.getPlayers()

			Cross.send("FireEvent", callbackEventId, serverInfo)
		end,

		RequestBanModification = function(fromServerJobId, requesterUserId, numOfAffectedPlayers, reason)
			local requesterName: string = if requesterUserId == 0 then `SYSTEM` else
				service.playerNameFromId(requesterUserId)

			for i, player in service.getPlayers(true) do
				if not Moderation.checkAdmin(player) then continue end

				player:makeUI("Notification", {
					title = `Ban Request in server {fromServerJobId}`,
					desc = `{requesterName} is requesting to ban/unban {numOfAffectedPlayers} player(s)`,
					actionText = `Join server to review`,
					openFunc = `remotecommand://main:JoinServerWithId||{luaParser.Encode{fromServerJobId}}`
				})
			end
		end;
	}

	local CrossSend_RL = setmetatable({
		--Rates = 120;
		Reset = 60,
	}, {
		__index = function(self, ind)
			if ind == "Rates" then return (#service.getPlayers() * 80) + 300 end
			return nil
		end,
	})

	local function Init()
		Core = server.Core
		Cross = server.Cross
		Cmds = server.Commands
		Datastore = server.Datastore
		Identity = server.Identity
		Logs = server.Logs
		Moderation = server.Moderation
		Network = server.Network
		Process = server.Process
		Remote = server.Remote

		local settingsCrossKey = settings.CrossAPI_Key:sub(1, 50)

		if settings.CrossAPI_Allow then
			if #settingsCrossKey == 0 then
				warn "Cross API Key must have at least one character"
				return
			end

			service.trackTask("_CROSSCOM_LISTENER", true, function()
				CrossKey = hashLib.sha1(`ESCROSS-{settingsCrossKey}`):sub(1, 50)

				Subscription = service.MessagingService:SubscribeAsync(CrossKey, function(data)
					local actualData = data.Data
					local osSent = data.Sent or os.time()

					if type(actualData) == "string" then
						actualData = base64Decode(actualData)
						actualData = compression.Deflate.Decompress(actualData, compressionConfig)
						actualData = if actualData ~= nil then luaParser.Decode(actualData)[1] else nil

						if type(actualData) ~= "table" then return end

						local sender = actualData.Sender
						local dataArguments = actualData.Arguments
						local remoteSettings = actualData.Settings

						-- Just making sure..
						sender = (type(sender) == "string" and sender) or nil
						remoteSettings = (type(remoteSettings) == "table" and remoteSettings)
							or {
								NoLog = false, -- Whether this remote command should not log in cross com logs
								IgnoreCurrent = false, -- Whether this remote command should not process at the same server that sent this
								FromAdmin = false, -- Whether this was sent from a server administrator
								FromSystem = true, -- Whether this was sent from the server
								WhitelistedServers = { nil }, -- Only allow remote call to specified servers
							}
						dataArguments = (type(dataArguments) == "table" and service.cloneTable(dataArguments)) or {}

						local dataArgumentsLen = (function()
							local count = 0

							for i, v in pairs(dataArguments) do
								count = count + 1
							end

							return count
						end)()

						-- Return back if server sender doesn't exist
						if not sender then return end

						-- Return if the data arguments were not supplied
						if dataArgumentsLen == 0 then return end

						if remoteSettings.IgnoreCurrent and game.JobId == sender then
							return -- Return if the server who sent this is was the sender
						end

						if
							#remoteSettings.WhitelistedServers > 0
							and not table.find(
								remoteSettings.WhitelistedServers,
								(#game.PrivateServerId > 0 and game.PrivateServerId) or game.JobId
							)
						then
							return -- Return if the server isn't whitelisted to accept the remote call
						end

						-- Removing settings
						actualData.Settings = nil

						local cmdName = dataArguments[1]
						local crossCmd = CrossCommands[cmdName]
						local ratePass = crossCmd and Utility:checkRate(CrossSend_RL, "Server")

						if crossCmd then
							Logs.addLog("Script", "Received cross command " .. tostring(dataArguments[1]) .. ".")
							local suc, ers = service.trackTask(
								"_CROSSCMD_" .. tostring(cmdName),
								false,
								crossCmd,
								sender,
								unpack(dataArguments, 2)
							)
							Logs.addLog("Script", "Ran cross command " .. tostring(dataArguments[1]) .. ".")

							if not suc then
								Logs.addLog(
									"Script",
									"Failed to run cross command " .. tostring(cmdName) .. ": " .. tostring(ers)
								)
								warn(
									"Cross Command " .. tostring(cmdName) .. " encountered an error: " .. tostring(ers)
								)
							end
						end
					end
				end)

				CrossReady = true
				--warn("Cross Server ready")
			end)
		end
	end

	server.Cross = {
		Init = Init,

		commands = CrossCommands,

		send = function(...)
			if CrossReady and CrossKey then
				local ratePass = Utility:checkRate(CrossSend_RL, "Server")

				if ratePass then
					service.MessagingService:PublishAsync(
						CrossKey,
						base64Encode(
							compression.Deflate.Compress(
								luaParser.Encode { { Sender = game.JobId, Arguments = { ... } } },
								compressionConfig
							)
						)
					)
					--oldVal = compression.Deflate.Compress(oldVal, compressConfig)
					--oldVal = base64Encode(oldVal))
				end
			end
		end,

		sendToOtherServers = function(...)
			if CrossReady and CrossKey then
				local ratePass = Utility:checkRate(CrossSend_RL, "Server")

				if ratePass then
					--service.MessagingService:PublishAsync(CrossKey, {Sender = game.JobId, Settings = {IgnoreCurrent = true}, Arguments = {...}})
					service.MessagingService:PublishAsync(
						CrossKey,
						base64Encode(compression.Deflate.Compress(
							luaParser.Encode {
								{ Sender = game.JobId, Settings = { IgnoreCurrent = true }, Arguments = { ... } },
							},
							compressionConfig
						))
					)
				end
			end
		end,

		sendToSpecificServers = function(serverIds, ...)
			assert(type(serverIds) == "table", "Invalid argument 1, expected table")

			if CrossReady and CrossKey then
				local ratePass = Utility:checkRate(CrossSend_RL, "Server")

				if ratePass then
					--service.MessagingService:PublishAsync(CrossKey, {Sender = game.JobId, Settings = {WhitelistedServers = serverIds}, Arguments = {...}})
					service.MessagingService:PublishAsync(
						CrossKey,
						base64Encode(compression.Deflate.Compress(
							luaParser.Encode {
								{
									Sender = game.JobId,
									Settings = { WhitelistedServers = serverIds },
									Arguments = { ... },
								},
							},
							compressionConfig
						))
					)
				end
			end
		end,

		ready = function() return CrossReady end,
	}
end
