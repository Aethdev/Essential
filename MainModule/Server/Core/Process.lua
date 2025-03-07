local ServerStorage = game:GetService("ServerStorage")
return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service
	local settings = server.Settings
	local variables = envArgs.vars

	local HashLib = server.HashLib
	local Promise = server.Promise

	local Signal = server.Signal
	local Filter = server.Filter
	local Network = server.Network
	local Parser = server.Parser
	local Roles = server.Roles
	local Utility = server.Utility
	local Vela = server.Vela
	local PolicyManager = server.PolicyManager

	local changelog = require(server.Assets.Changelog)
	local endToEndEncryption = settings.endToEndEncryption or settings.remoteClientToServerEncryption

	local Cmds, Core, Cross, Datastore, Identity, Logs, Moderation, Process, Remote
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
	end

	server.Process = {
		Init = Init,

		remoteCall_RateLimit = {
			Rates = 240,
			Reset = 120,
			DebugLogRates = true,

			Exceeded = Signal.new(),
			Passed = Signal.new(),

			ThrottleEnabled = true,
			ThrottleReset = 30,
			ThrottleMax = 10,
		},

		remoteCall_WarnBlockRateLimit = {
			Rates = 3,
			Reset = 60,

			ThrottleEnabled = true,
			ThrottleReset = 180,
			ThrottleMax = 10,
		},

		chatProcessCommand_RateLimit = {
			Rates = 5,
			Reset = 5,
		},

		shortcutProcessCommand_RateLimit = {
			Rates = 40,
			Reset = 25,
		},

		keybindProcessCommand_RateLimit = {
			Rates = 40,
			Reset = 25,
		},

		toggleIncognito_RateLimit = {
			Global = { Rates = math.clamp(service.Players.MaxPlayers, 1, 30), Reset = 80 },
			Player = { Rates = 1, Reset = 120 },
		},

		playerSettingsLimits = {
			MaxAliasCreation = 30,
			MaxShortcutCreation = 20,
			MaxCustomCmdNameCreation = 40,
			MaxKeybindCreations = 20,

			KeybindSaveIdCharLimit = 8,
			CustomCmdNameAliasCharLimit = 30,
			AliasNameCharLimit = 40,
			ShortcutNameCharLimit = 40,
			KeybindNameCharLimit = 30,
			AliasAndShortcutCmdLineCharLimit = 500,
			KeybindMaxHoldDuration = 60,
		},

		playerAdded = function(plr: Player, isExisting: boolean?)
			if Core.clients[plr] then
				warn("Failed to initiate player added event for player " .. plr.Name)
			else
				local placeOwner = Identity.checkPlaceOwner(plr)
				local ignoreBan = placeOwner or false
				local parsedPlayer = Parser:apifyPlayer(plr)
				local clientData
				clientData = {
					id = tostring(plr.UserId) .. "-" .. service.getRandom(50),
					replicator = Network.getClient(plr.UserId),
					player = plr,
					joined = tick(),
					ready = Signal.new(),
					active = true,

					trustChecked = false,
					processVerified = false,
					verified = false,
					deviceType = "[unknown]",
					parsedPlayer = parsedPlayer,
				}

				if not clientData.replicator then
					warn(`Unable to setup client data replicator for the player {tostring(parsedPlayer)}`)
					pcall(plr.Kick, plr, "Network replicator unavailable")
					return
				end
				Network.registerReplicator(clientData.replicator)

				-- Registers data to the system
				Core.clients[plr] = clientData

				clientData._processTask = Promise.promisify(function()
					local canJoin, denyType, denyInfo = Moderation.checkServerEntry(plr)

					if not canJoin then
						if denyType == "Ban" then
							local banInfo: {
								isPermanent: boolean,
								caseId: string,
								moderatorId: number,
								reason: string,

								startedOn: number,
								expiresOn: number,
							} =
								denyInfo

							server.Events.playerKicked:fire(plr, denyType)
							parsedPlayer:_kick(Parser:filterStringWithSpecialMarkdown(settings.banMessage, nil, {
								customReplacements = {
									["statusCode"] = if banInfo.caseId:sub(1, 2) ~= "S-"
										then (banInfo.expiresOn ~= nil and 11002) or 11001
										elseif banInfo.caseId:sub(1, 2) == "L-" then 11003
										else 11004,
									["moderator"] = if banInfo.moderatorId > 0
										then service.playerNameFromId(banInfo.moderatorId) .. ` ({banInfo.moderatorId})`
										elseif banInfo.moderatorId == -1 then `AutoModerator`
										else `System`,
									["mod_id"] = banInfo.moderatorId,
									["moderatorId"] = banInfo.moderatorId,
									["id"] = banInfo.caseId,
									["caseId"] = banInfo.caseId,
									["reason"] = banInfo.reason,
									["startDate"] = Parser:osDate(
										math.floor(banInfo.startedOn / 1000),
										nil,
										"longdatetime"
									) .. " UTC",
									["dueDate"] = if banInfo.isPermanent
										then `Unknown`
										else Parser:osDate(
											math.floor(banInfo.expiresOn / 1000),
											nil,
											"longdatetime"
										) .. " UTC",
									["relativeStartTime"] = Parser:relativeTimestamp(
										math.floor(banInfo.startedOn / 1000)
									),
									["relativeEndTime"] = Parser:relativeTimestamp(
										math.floor(banInfo.expiresOn / 1000)
									),
								},
							}))
						end

						if denyType == "EssPrivate-InvalidTpData" then
							server.Events.playerKicked:fire(plr, denyType)
							parsedPlayer:_kick "\n[ESS PRIVATE] The server you are joining requires a signed teleport data."
						end

						if denyType == "EssPrivate-Invite" then
							local originJobId = denyInfo
							if originJobId then
								parsedPlayer:setVar("MuteChat", true)
								local tpOptions = service.New("TeleportOptions", {
									ServerInstanceId = originJobId,
								})
								local tpInitFailed = Signal.new()
								tpInitFailed:linkRbxEvent(service.TeleportService.TeleportInitFailed)
								tpInitFailed:connect(
									function(failedPlr, tpResult, tpErrMessage, tpPlaceId, usedTpOptions)
										if failedPlr == plr then
											tpInitFailed:disconnect()
											server.Events.playerKicked:fire(plr, denyType)
											parsedPlayer:_kick "\n[ESS PRIVATE] Failed to teleport back to origin. The server you joined requires an invite."
										end
									end
								)
								tpInitFailed:disconnect(60)
								service.TeleportService:TeleportAsync(game.PlaceId, { plr }, tpOptions)
							else
								server.Events.playerKicked:fire(plr, denyType)
								parsedPlayer:_kick "\n[ESS PRIVATE] The server you are joining requires an invite."
							end
						end

						if denyType == "EssPrivate-AdminOnly" then
							local originJobId = denyInfo
							if originJobId then
								parsedPlayer:setVar("MuteChat", true)
								local tpOptions = service.New("TeleportOptions", {
									ServerInstanceId = originJobId,
								})
								local tpInitFailed = Signal.new()
								tpInitFailed:linkRbxEvent(service.TeleportService.TeleportInitFailed)
								tpInitFailed:connect(
									function(failedPlr, tpResult, tpErrMessage, tpPlaceId, usedTpOptions)
										if failedPlr == plr then
											tpInitFailed:disconnect()
											server.Events.playerKicked:fire(plr, denyType)
											parsedPlayer:_kick "\n[ESS PRIVATE] Failed to teleport back to origin. This server requires you to have server administrator in order to join."
										end
									end
								)
								tpInitFailed:disconnect(60)
								service.TeleportService:TeleportAsync(game.PlaceId, { plr }, tpOptions)
							else
								server.Events.playerKicked:fire(plr, denyType)
								parsedPlayer:_kick "\n[ESS PRIVATE] The server requires you to have server administrator in order to join."
							end
						end

						if denyType == "DeadLock" then
							server.Events.playerKicked:fire(plr, "DeadLock")
							parsedPlayer:_kick "\nThe server you're joining is already closing."
						end

						if denyType == "Shutdown" then
							local shutdownMessage = settings.shutdownMessage
							local shutdownDate = Parser:osDate(Utility.shutdownBeganOs)

							local moderatorId = Utility.shutdownModeratorId

							shutdownMessage = Parser:replaceStringWithDictionary(shutdownMessage, {
								["{user}"] = (moderatorId and service.playerNameFromId(moderatorId)) or "[SYSTEM]",
								["{userid}"] = tostring(moderatorId or "-1"),
								["{reason}"] = tostring(Utility.shutdownReason),
								["{startTime}"] = shutdownDate,
							})

							server.Events.playerKicked:fire(plr, "Shutdown")
							parsedPlayer:_kick("\n" .. shutdownMessage)
						end

						if denyType == "Whitelist" then
							local whitelistData = variables.whitelistData
							parsedPlayer:_kick(
								Parser:replaceStringWithDictionary("\n" .. tostring(settings.lockMessage), {
									["{user}"] = plr.Name .. " #" .. plr.UserId,
									["{name}"] = plr.Name,
									["{displayname}"] = plr.DisplayName,
									["{userid}"] = plr.UserId,
									["{moderator}"] = (
										whitelistData.moderator.name
										.. " #"
										.. whitelistData.moderator.userid
									) or "SYSTEM",
									["{mod}"] = (
										whitelistData.moderator.name
										.. " #"
										.. whitelistData.moderator.userid
									) or "SYSTEM",
									["{mod_name}"] = whitelistData.moderator.name or "-1",
									["{mod_id}"] = whitelistData.moderator.userid or "-1",
									["{adminsonly}"] = whitelistData.admins or "false",
									["{reason}"] = whitelistData.reason or "Undefined",
									["{startTime}"] = Parser:osDate(whitelistData.started) or "n/a",
								})
							)
						end

						return
					end

					local didProcessBan = Moderation.processBan(plr)
					if didProcessBan then return end
				end)():catch(
					function(err)
						parsedPlayer:_kick(
							`[Essential Process Error] An issue occurred while verifying your join request to the game:\n{tostring(
								err
							)}`
						)
					end
				)

				clientData._loadingPData = Promise.promisify(Core.getPlayerData)(plr.UserId)
					:andThen(function(playerData)
						if playerData._dataUpdate then playerData._updateIfDead() end

						-- Track activity log
						do
							local activityLogs = playerData.__activityLogs

							local serverId = (server.Studio and "[studio server]") or game.JobId
							local serverType = (game.PrivateServerOwnerId > 0 and "[personal]")
								or (#game.PrivateServerId > 0 and "[private]")
								or (server.Studio and "[studio]")
								or "[public]"

							playerData.serverData.lastJoinedLog = activityLogs[#activityLogs]

							if not server.Studio then
								activityLogs._pushToSet(
									Logs.formatLog("Joined server " .. serverType .. " " .. serverId)
								)
								activityLogs._recognize()
							end
						end

						if not playerData.serverData.firstJoined then
							playerData.serverData.firstJoined = clientData.joined
						end

						playerData.serverData.joined = clientData.joined

						return playerData
					end)
					:andThen(function(playerData)
						clientData.pData = playerData
						return playerData
					end)
					:andThen(function(playerData)
						local banCheck
						banCheck = playerData._updated:connect(function()
							local banData = playerData.Banned

							if banData then
								local banAlive, banInfo = Moderation.checkBan(plr, banData)

								if banAlive then
									banCheck:disconnect()

									local banMessage = settings.BanMessage
									banMessage = (type(banMessage) == "string" and banMessage)
										or "The server is prohibiting you from joining"
									banMessage = Parser:replaceStringWithDictionary(banMessage, {
										["{user}"] = plr.Name .. " #" .. plr.UserId,
										["{name}"] = plr.Name,
										["{displayname}"] = plr.DisplayName,
										["{userid}"] = plr.UserId,
										["{moderator}"] = (
											banInfo and banInfo.moderator.name .. " #" .. banInfo.moderator.userid
										) or "SYSTEM",
										["{mod}"] = (
											banInfo and banInfo.moderator.name .. " #" .. banInfo.moderator.userid
										) or "SYSTEM",
										["{mod_name}"] = (banInfo and banInfo.moderator.name) or "SYSTEM",
										["{mod_id}"] = (banInfo and banInfo.moderator.userid) or "-1",
										["{id}"] = (banInfo and banInfo.id) or "N/A",
										["{type}"] = (banInfo and banInfo.type) or "Settings/GlobalData",
										["{reason}"] = (banInfo and banInfo.reason) or "Undefined",
										["{dueDate}"] = (banInfo and Parser:osDate(banInfo.expireTime)) or "N/A",
										["{expireTime}"] = (banInfo and banInfo.expireTime and tostring(
											math.max(banInfo.expireTime - os.time(), 0)
										)) or "INFINITE",
										["{startTime}"] = (banInfo and Parser:osDate(banInfo.registered)) or "N/A",
										["{relativeStartTime}"] = (banInfo and Parser:relativeTimestamp(
											banInfo.registered
										)) or "now",
										["{relativeEndTime}"] = (
											banInfo
											and banInfo.expireTime
											and Parser:relativeTimestamp(banInfo.expireTime)
										) or "N/A",
									})

									server.Events.playerKicked:fire(plr, "Banned", banInfo or "SYSTEM")
									plr:Kick("\n" .. banMessage)
									return
								end
							end
						end)

						local pDataSaveError = playerData._saveError:connect(function()
							service.debounce("PData" .. parsedPlayer.UserId .. "_SaveErrorWarn", function()
								parsedPlayer:makeUI("NotificationV2", {
									title = "Player Data Save error",
									desc = "Player data failed to save. The next attempt will take 60-90 seconds (immediate if you leave, NOT RECOMMENDED). Do not leave the server until your pData successfully saved."
										.. " Leaving the server without returning will only allow one attempt to update your data.",
									time = 60,
								})
								wait(10)
							end)
						end)

						local pDataSaveSuccess = playerData._saveSuccess:connect(function()
							service.debounce("PData" .. parsedPlayer.UserId .. "_SaveSuccessWarn", function()
								parsedPlayer:makeUI("NotificationV2", {
									title = "Player Data Save success",
									desc = "Player data saved successfully after corruption. Thank you for your patience!",
									time = 60,
								})
								wait(30)
							end)
						end)

						parsedPlayer.disconnected:connectOnce(function()
							banCheck:disconnect()
							pDataSaveError:disconnect()
							pDataSaveSuccess:disconnect()
						end)

						local serverPData = playerData.serverData

						if not serverPData.joined then serverPData.joined = os.time() end

						return playerData
					end)
					:andThenCall(server.PolicyManager._updateClientPolicies, server.PolicyManager, parsedPlayer)
					:andThen(function()
						if parsedPlayer:isPrivate() then task.spawn(Moderation.updateIncognitoPlayersDynamicPolicy) end
					end)

				-- Fires the playerAdded event
				server.Events.playerAdded:fire(parsedPlayer)
				Logs.addLogForPlayer(parsedPlayer, "PlayerActivity", {
					desc = "{{$target}} joined",
				})

				-- Setup player keys for network
				Core.remoteTrustChecker:createPlayerKey(parsedPlayer)

				-- Idle verification check
				do
					local timeoutSecs = 300+30 -- 5 minutes + 30 seconds
					Signal:processAfterSingleEvent({parsedPlayer.verified, parsedPlayer.left}, timeoutSecs, function(didVerify)
						if not didVerify and parsedPlayer:isInGame() then
							parsedPlayer:Kick("Failed to verify client init within the time period")
						end
					end)
				end

				-- Retrieve social policies for the player
				task.spawn(function() parsedPlayer:retrieveSocialPolicies() end)

				if parsedPlayer:isInGame() then
					Roles:dynamicUpdateChatTagsForPlayer(plr)

					task.spawn(Utility.setupClient, Utility, plr, {
						loadingType = if isExisting then "PlayerGui" else nil;
					})

					if parsedPlayer.disguiseUserId > 0 then
						parsedPlayer:applyDisguise()
					end
					
					Logs.addLogForPlayer(
						parsedPlayer,
						`Process`,
						`Loaded player \{\{$target\}\} player data and client`
					)
				end
			end
		end,

		playerRemoving = function(plr)
			local clientData = Core.clients[plr]
			local parsed = Parser:apifyPlayer(plr)

			if clientData then
				clientData.active = false

				if clientData._loadingPData and clientData._loadingPData:getStatus() ~= Promise.Status.Resolved then
					clientData._loadingPData:cancel()
				end
				
				local playerData = clientData.pData

				if playerData then
					-- Remove server details
					if not server.Studio and playerData.serverDetails then
						playerData.serverDetails = nil
						playerData.lastServerJobId = game.JobId
					end

					-- Track activity log
					local activityLogs = playerData.__activityLogs

					local serverId = (server.Studio and "[studio server]") or game.JobId
					local serverType = (game.PrivateServerOwnerId > 0 and "[personal]")
						or (#game.PrivateServerId > 0 and "[private]")
						or (server.Studio and "[studio]")
						or "[public]"

					if not server.Studio then
						activityLogs._pushToSet(Logs.formatLog {
							title = "Abandoned server " .. serverType .. " " .. serverId,
							desc = "Duration: " .. Parser:formatTime(os.time() - clientData.joined),
						})
						activityLogs._recognize()
					end

					for i, role in pairs(Roles:getAll()) do
						if role:checkTempMember(plr) then role:tempUnAssignWithMemberId(plr.UserId) end
					end
				end

				server.Events.playerRemoved:fire(parsed)

				Logs.addLogForPlayer(parsed, `PlayerActivity`, {
					title = `\{\{$target\}\} left`,
					desc = "Duration: " .. Parser:relativeTime(os.time() - clientData.joined),
				})
				Core.clients[plr] = nil

				-- Check for incognito
				if parsed:isPrivate() then Moderation.updateIncognitoPlayersDynamicPolicy() end

				if
					playerData
					and playerData._dataUpdate
					and (
						Utility.shutdownState
						or (server.Studio and playerData._dataChanged)
						or (not server.Studio and server.Running)
					)
				then
					playerData._forceUpdate()
				end
			end
		end,

		remoteCall = function(plr, ignoreIndexCheck, invoke, key, ...)
			local clientData = Core.clients[plr]
			local rateData = Process.remoteCall_RateLimit
			local rateKey = plr.UserId
			local ratePass, didThrottle, canThrottle, curRate, maxRate, throttleResetOs =
				Utility:deferCheckRate(rateData, rateKey)

			if clientData and (ratePass or not ratePass and didThrottle) then
				if not ratePass and didThrottle then
					warn(
						"Player "
							.. plr.Name
							.. " throttled remote call (+"
							.. curRate - maxRate
							.. "). Try sending less remote calls to prevent throttling !!"
					)
					
					local warnRatePass, warnDidThrottle, warnCanThrottle =
						Utility:deferCheckRate(Process.remoteCall_WarnBlockRateLimit, rateKey)

					if warnRatePass then
						for i, target in pairs(service.getPlayers(true)) do
							if Moderation.checkAdmin(target) then
								target:sendData(
									"SendMessage",
									"<u>" .. plr.Name .. "</u> is sending remote requests too quickly.",
									nil,
									5,
									"Context"
								)
							end
						end
					end

					wait(math.max(0.1*(curRate-maxRate)^2, 0))
				end

				--do
				--	local rateAverage = 0
				--	local debugRateLogsCount = #rateData.DebugRateLogs
				--	for i, rate: number in rateData.DebugRateLogs do
				--		rateAverage += rate
				--	end
				--	rateAverage = rateAverage/debugRateLogsCount

				--	warn(`Process RemoteCall fired | avg: {rateAverage}/s`)
				--end

				local keyType = type(key)
				local isKeyValidType = keyType == "string"
				--local curEncryptIteration = (clientData.curRemEncryptIteration+1)%100
				--local remEncryptKey = clientData.remEncryptionKeys[2+curEncryptIteration]
				--local decryptedKey = service.decryptStr(key, remEncryptKey)
				--warn("REMOTE CALL WAS CALLED:")
				local realRemoteServerKey = if endToEndEncryption
					then HashLib.sha1(clientData.remoteServerKey)
					else clientData.remoteServerKey
				--warn("REAL KEY:", realRemoteServerKey)
				--warn("GIVEN KEY:", key)
				--warn("KEY PAIR:", isKeyValidType and realRemoteServerKey==key)

				if isKeyValidType and realRemoteServerKey == key then
					local params = { ... }
					local cmdName = params[1]

					--clientData.curRemEncryptIteration = curEncryptIteration

					-- Ensures the first parameter is a string or number
					cmdName = (table.find({ "number", "string" }, type(cmdName)) and cmdName) or nil

					if cmdName then
						local cmd = Remote.Commands[cmdName]

						if cmd and not cmd.Disabled then
							Logs.addLog("Remote", {
								title = plr.Name
									.. ": Indexed command "
									.. tostring(cmdName)
									.. " ("
									.. type(cmdName)
									.. ")",
								desc = "Index: "
									.. tostring(cmdName)
									.. " | Index type: "
									.. type(cmdName)
									.. " | Invoke: "
									.. tostring(invoke),
							})

							local lockdown = Core.lockdown
							local whitelist = cmd.Whitelist or {}
							local blacklist = cmd.Blacklist or {}
							local permissions = cmd.Permissions
							local publicUse = cmd.Public

							local userWhitelisted = ignoreIndexCheck
								or (whitelist and Identity.checkTable(plr, whitelist))
								or false
							local userBlacklisted = not ignoreIndexCheck
									and (whitelist and Identity.checkTable(plr, blacklist))
								or false
							local userHasPermissions = ignoreIndexCheck
								or (permissions and Roles:hasPermissionFromMember(plr, permissions))
								or false

							local userAdmin = ignoreIndexCheck or Moderation.checkAdmin(plr)
							local canAccess = ignoreIndexCheck
								or userAdmin
								or ((publicUse or userHasPermissions or userWhitelisted) and not userBlacklisted)

							-- Ensure lockdown is not enabled or remote command is allowed during lockdown, then make sure if the player can access it
							if (not lockdown or (lockdown and cmd.Lockdown_Allowed)) and canAccess then
								Logs.addLog("Remote", {
									title = plr.Name
										.. ": Granted access to command "
										.. tostring(cmdName)
										.. " ("
										.. type(cmdName)
										.. ")",
									desc = "Index: "
										.. tostring(cmdName)
										.. " | Index type: "
										.. type(cmdName)
										.. " | Invoke: "
										.. tostring(invoke),
								})

								local cmdFunction = cmd.Function or cmd.Run or cmd.Execute or cmd.Call
								cmdFunction = (type(cmdFunction) == "function" and cmdFunction) or nil

								-- Ensure Can_Fire is enabled by default if neither Can_Invoke and Can_Fire are enabled
								if not (cmd.Can_Invoke or cmd.Can_Fire) then cmd.Can_Fire = true end

								local rL_Enabled = cmd.RL_Enabled
								local rL_Rates = cmd.RL_Rates or 1
								local rL_Reset = cmd.RL_Reset or 0.01
								local rL_Error = cmd.RL_Error
								local rL_Data = cmd.RL_Data
									or (function()
										local data = {}

										rL_Rates = math.floor(math.abs(rL_Rates))
										rL_Reset = math.abs(rL_Reset)

										rL_Rates = (rL_Rates < 1 and 1) or rL_Rates

										cmd.RL_Rates = rL_Rates
										cmd.RL_Reset = rL_Reset

										data.Rates = rL_Rates
										data.Rest = rL_Reset

										cmd.RL_Data = data
										return data
									end)()

								local remoteData = {
									invoked = invoke,
									fired = not invoke,
									sentTick = os.clock(),
									sentOs = os.time(),
								}

								local canUseCommand = (invoke and cmd.Can_Invoke)
									or (not invoke and cmd.Can_Fire)
									or false

								if canUseCommand and cmdFunction then
									-- Command rate limit check
									if rL_Enabled then
										local passCmdRateCheck, curRemoteRate, maxRemoteRate =
											Utility:deferCheckRate(rL_Data, rateKey)

										if not passCmdRateCheck then
											Logs.addLog("Remote", {
												title = plr.Name
													.. ": Failed command "
													.. tostring(cmdName)
													.. " ("
													.. type(cmdName)
													.. ")'s rate limit.",
												desc = "Current rate: "
													.. tostring(curRemoteRate)
													.. " | Max rate: "
													.. tostring(maxRemoteRate),
											})

											warn(
												"Player "
													.. plr.Name
													.. " is sending too many requests to "
													.. cmdName
													.. " (Threshold: "
													.. curRemoteRate - maxRemoteRate
													.. ")"
											)
											return (type(rL_Error) == "string" and rL_Error) or nil
										end
									end

									Logs.addLog("Remote", {
										title = plr.Name
											.. ": Accessing command "
											.. tostring(cmdName)
											.. " ("
											.. type(cmdName)
											.. ")",
										desc = "Index: "
											.. tostring(cmdName)
											.. " | Index type: "
											.. type(cmdName)
											.. " | Invoke: "
											.. tostring(invoke),
									})

									local parsed = Parser:apifyPlayer(plr)
									local rets = {
										service.trackTask(
											"_REMCOMMAND-"
												.. cmdName
												.. "-Invoke:"
												.. tostring(invoke)
												.. "-"
												.. plr.UserId,
											false,
											cmdFunction,
											parsed,
											{ unpack(params, 2) },
											remoteData
										),
									}

									if not rets[1] then
										Logs.addLog("Remote", {
											title = plr.Name
												.. ": Encountered an error while running command "
												.. tostring(cmdName)
												.. " ("
												.. type(cmdName)
												.. ") successfully",
											desc = "Returned arguments count: " .. tostring(#{ unpack(rets, 2) }),
										})

										warn(
											"Player "
												.. plr.Name
												.. " encountered an error while running remote "
												.. cmdName
												.. ": "
												.. tostring(rets[2])
										)
										
										return nil
										-- Don't return the error ret to the client. It's never a good thing for them to see the error
									else
										Logs.addLog("Remote", {
											title = plr.Name
												.. ": Required command "
												.. tostring(cmdName)
												.. " ("
												.. type(cmdName)
												.. ") successfully",
											desc = "Returned arguments count: " .. tostring(#{ unpack(rets, 2) }),
										})

										-- Return the function rets from the function if this call was invoked by RemoteFunction
										if invoke then
											-- First parameter of the rets is the success whether the function ran successfully or not
											-- We never doubt on returning the success status with the function rets
											return unpack(rets, 2)
										end

										return nil
									end
								elseif canUseCommand and not cmdFunction then
									warn(
										"Player "
											.. plr.Name
											.. " is sending a request to "
											.. cmdName
											.. " with a missing function"
									)

									return nil
								end
							end
						elseif not cmd then
							Logs.addLog("Remote", {
								title = plr.Name .. ": Attempted to access an non-existent command " .. tostring(
									cmdName
								) .. " (" .. type(cmdName) .. ")",
								desc = "Suspicious activity was noted by system.",
							})

							error("Remote command " .. tostring(cmdName) .. " doesn't exist", 0)
						end
					else
						Logs.addLog("Remote", {
							title = plr.Name
								.. ": Attempted to invoke/fire remote call "
								.. tostring(params[1])
								.. " ("
								.. type(params[1])
								.. ")",
							desc = "Suspicious activity was noted by system.",
						})
					end
				end
			elseif not ratePass then
				Moderation.addBan(
					plr.Name,
					"Time",
					"Spammed remote network",
					os.time(),
					{ name = "SYSTEM", userid = -1 },
					os.time() + 1200,
					false
				)
			end
		end,

		playerCommand = function(plr, msg, data)
			data = (type(data) == "table" and data) or {}

			if msg and msg:find(settings.batchSeperator) then
				if not (data.noBatch or settings.NoCommandsInBatch) then
					local maxCommandsInABatch =
						math.floor(math.clamp(tonumber(data.maxCommands or settings.MaxBatchCommands), 1, 50))
					-- Minimum amount of commands in a batch: 1 (Lowering this will revoke commands running in a batch)
					-- Maximum amount of commands in a batch: 50
					--> Increasing the amount to more than 50 may increase a risk of admin abuse

					if not data._ranPlayerCommands then data._ranPlayerCommands = {} end

					local batches = {}
					for i in string.gmatch(msg, "[^" .. settings.batchSeperator .. "]+") do
						table.insert(batches, i)
					end

					local ranCount = 0

					for i = 1, maxCommandsInABatch, 1 do
						local batch = batches[i]

						if batch then
							local aliasCmdLineFromBatch = if PolicyManager:getPolicyFromPlayer(plr, "ALIASES_ALLOWED").value
									~= false
								then Core.getCmdAliasFromBatch(plr, batch)
								else nil
							local ran = Process.playerCommand(
								plr,
								aliasCmdLineFromBatch or batch,
								(
									aliasCmdLineFromBatch
									and setmetatable(
										{ aliasRan = true, _ranPlayerCommands = data._ranPlayerCommands },
										{ __index = data }
									)
								) or data
							)

							if ran == false then
								return ran
							elseif ran == "Return" then
								ranCount += 1
								return true
							else
								if ran then
									ranCount += 1
								end
								wait(0.1)
							end
						else
							break
						end
					end

					if ranCount > 0 then return true end
				end
			else
				-- Trim the message for extra spaces
				msg = if msg then Parser:trimString(msg) else nil

				-- Alias check
				local aliasCmdLineFromMsg = if msg
						and PolicyManager:getPolicyFromPlayer(plr, "ALIASES_ALLOWED").value ~= false
					then Core.getCmdAliasFromBatch(plr, msg)
					else nil
				if aliasCmdLineFromMsg then
					return Process.playerCommand(
						plr,
						aliasCmdLineFromMsg,
						setmetatable(
							{ aliasRan = true, _ranPlayerCommands = data._ranPlayerCommands },
							{ __index = data }
						)
					)
				end

				local commandProcessed = false
				local delimiter = (#settings.delimiter > 0 and settings.delimiter) or " "
				local noPrefixCheck = data.noPrefixCheck
				local returnOutput = data.returnOutput
				local customAliasRan = data.aliasRan
				local customButtonRan = data.button
				local customKeybindRan = data.keybind
				local command, cmdMatch

				-- Check if the command processed from core commands
				-- CORE COMMANDS FUNCTION RETURN
				--
				--		1		| break

				if msg then
					for coreName, coreCmd in pairs(Cmds.CoreCommands) do
						local match
						local doStrMatch = coreCmd.StringMatch

						if doStrMatch and string.match(msg, coreCmd.Match) then
							match = { string.match(msg, coreCmd.Match) }
						elseif not doStrMatch and coreCmd.Match == msg then
							match = { msg }
						end

						if match and #match > 0 then
							-- Check permissions to use this core command
							local canAccess = not plr
								or coreCmd.Public
								or Roles:hasPermissionFromMember(plr, coreCmd.Roles)
								or (function()
									local checkedRoles = {}
									for i, role in pairs(Roles:getRolesFromMember(plr)) do
										checkedRoles[role.name:lower()] = true
									end

									for i, neededRole in pairs(coreCmd.Roles) do
										if not checkedRoles[neededRole:lower()] then return false end
									end

									return true
								end)()

							if canAccess then
								local coreCmdFunc = coreCmd.Function

								if not coreCmdFunc then
									warn(
										"Unable to execute core command "
											.. coreName
											.. " from player "
											.. tostring(plr)
											.. ". Missing function?"
									)
								else
									if coreCmd.KeybindAndShortcutOnly and not (customButtonRan or customKeybindRan) then
										continue
									end
									--local executeCoreCmdProm = Promise.promisify(coreCmdFunc)(plr, match, data)

									--executeCoreCmdProm:catch(function(...)
									--	warn("promise Error:", {...})
									--	--warn("Core command "..coreName.." ["..tostring(plr and plr.UserId).."] encountered an error: "..tostring(errMessage))
									--end)

									--if executeCoreCmdProm.Status == Promise.Status.Rejected then
									--	return "Return"
									--end

									local coreCmdFuncRets = {
										service.trackTask(
											"_CORECOMMAND_" .. coreName:upper() .. "_" .. plr.UserId,
											false,
											coreCmdFunc,
											plr,
											match,
											data
										),
									}
									local success, error = coreCmdFuncRets[1], coreCmdFuncRets[2]

									if not success then
										warn(
											"Core command "
												.. coreName
												.. " ["
												.. tostring(plr and plr.UserId)
												.. "] encountered an error: "
												.. tostring(error)
										)
									else
										if error == 0 then return "Return" end
									end
								end
							end

							commandProcessed = true
						end
					end
				end

				if not commandProcessed then
					local aliasMatch

					if data.commandId then
						command, cmdMatch = Cmds.getFromId(data.commandId)
					elseif data.terminal then
						command, cmdMatch = Remote.Terminal.getCommand(msg, nil, noPrefixCheck)
					else
						command, cmdMatch, aliasMatch = Core.getCommandFromBatch(plr, msg)
						if not command then
							command, cmdMatch = Cmds.get(msg, nil, noPrefixCheck)
						end
					end

					if command then
						local cmdArgs = command.Args or command.Arguments or {}
						local cmdFilterArgs = command.FilterArguments or command.FilterArgs or command.Filter
						local cmdRequireArgs = command.RequireArgs or command.RequireArguments

						local messageArgs = data.commandInputArgs
							or Parser:getArguments(
								msg:sub(utf8.len((aliasMatch or cmdMatch) .. delimiter) + 1),
								delimiter,
								{
									maxArguments = math.max(#cmdArgs, 1),
								}
							)

						local canIgnoreCooldown = Roles:hasPermissionFromMember(plr, { "Ignore_Command_Cooldown" })
						local parsedArgs, missingArg, missingArgType, missingArgReason =
							Parser:filterArguments(messageArgs, cmdArgs, delimiter, plr)
						local canUse, checkError, checkErrorArg1 =
							Core.checkCommandUsability(plr, command, canIgnoreCooldown, data)

						if canUse then
							if not parsedArgs then
								if returnOutput then
									return false,
										cmdMatch,
										"Args_NotParsed",
										missingArg,
										missingArgType,
										missingArgReason,
										cmdArgs[missingArg]
								end

								local argumentName = tostring(
									(type(cmdArgs[missingArg]) == "table" and cmdArgs[missingArg].argument) or "unknown"
								)
								local argumentType = missingArgType or (cmdArgs[missingArg].type or "text")
								local missingArgNameAndType = '"' .. argumentName .. '"' .. ' "' .. argumentType .. '"'

								plr:sendData(
									"SendMessage",
									"Command <u>"
										.. Parser:removeRichTextTags(
											if command.Hidden then "[hidden]" else tostring(cmdMatch)
										)
										.. "</u> requires a valid argument: "
										.. Parser:removeRichTextTags(
											(missingArgReason or "Expected " .. missingArgNameAndType)
										),
									"Command "
										.. (if command.Hidden then "[hidden]" else tostring(cmdMatch))
										.. " requires a valid argument: "
										.. (missingArgReason or "Expected " .. missingArgNameAndType),
									5,
									"Context"
								)

								--plr:sendData("SendMessage", "Command "..cmdMatch..": Invalid argument "..argumentName.." ("..argumentType..")", (missingArgReason or "Expected "..missingArgNameAndType), 5, "Hint")
								--warn("Player command "..cmdMatch.." ["..plr.UserId.."] is missing a valid argument "..tostring(missingArg).." "..tostring(missingArgType))

								return false, cmdMatch
							end

							if cmdRequireArgs and #parsedArgs < #cmdArgs then
								if returnOutput then return false, cmdMatch, "Args_NotFilled" end

								plr:sendData(
									"SendMessage",
									"Command <u>"
										.. Parser:filterForRichText(
											if command.Hidden then "[hidden]" else tostring(cmdMatch)
										)
										.. "</u> requires all arguments filled in",
									"Command "
										.. (if command.Hidden then "[hidden]" else tostring(cmdMatch))
										.. " requires all arguments filled in",
									5,
									"Context"
								)

								return false, cmdMatch
							end

							if cmdFilterArgs then
								for i, parsedArgument in pairs(parsedArgs) do
									local argType = type(parsedArgument)

									if argType == "string" then
										parsedArgs[i] =
											select(2, Filter:safeString(parsedArgument, plr.UserId, plr.UserId))
									end
								end
							end

							Core.trackCommandStartUsability(plr, command, data)

							local cmdFunction = command.Run or command.Function or command.Load

							if cmdFunction then
								local hiddenFromLogs = true

								-- Add log
								if
									not (data.NoLog or data.noLog or data.DontLog or data.dontLog)
									and not (command.DontLog or command.Loggable == false or command.NoLog)
								then
									local concatArguments = {}
									local wholeArgumentsHidden = if data.hideCommandArguments then true else false
									local commandLogPrefix = if customAliasRan
										then "[Action Alias] "
										elseif aliasMatch then "[CC Alias] "
										elseif customButtonRan then "[Shortcut Alias] "
										elseif customKeybindRan then "[Keybind] "
										else ""

									for i, arg in ipairs(messageArgs) do
										local isArgumentHidden = wholeArgumentsHidden
											or if type(cmdArgs[i]) == "table" and cmdArgs[i].private
												then true
												else false

										table.insert(
											concatArguments,
											if isArgumentHidden
												then string.rep("*", math.clamp(utf8.len(arg), 1, 15))
												else arg
										)
									end

									Logs.addLogForPlayer(
										plr,
										`Commands`,
										`\{\{$targetusername\}\} {cmdMatch}{delimiter}{Parser:filterForSpecialMarkdownTags(
											table.concat(concatArguments, delimiter)
										)}`
									)

									hiddenFromLogs = false
								end

								server.Events.commandRan:fire("Player", plr, {
									command = command,
									match = cmdMatch,
									cmdInput = if not msg then "" else msg:sub(#(cmdMatch .. delimiter) + 1),
									data = service.tableRead(data),
									arguments = service.tableRead(parsedArgs),
									messageArgs = service.tableRead(messageArgs),
									didHideFromLogs = hiddenFromLogs,
								})

								--local executeCmdProm = Promise.promisify(cmdFunction)(plr, parsedArgs, data)

								--executeCmdProm:catch(function(...)
								--	warn("promise Error:", {...})
								--	--plr:sendData("SendMessage", "Command "..cmdMatch.." Error", "\""..tostring(error).."\" (developer code error)", 10, "Hint")
								--	--warn("Player command "..cmdMatch.." ["..plr.UserId.."] encountered an error: "..tostring(error))
								--end)

								--if executeCmdProm.Status == Promise.Status.Rejected then
								--	return "Return"
								--end

								local cmdFuncRets = {
									service.trackTask(
										"_COMMAND_" .. cmdMatch:upper() .. "_" .. plr.UserId,
										false,
										cmdFunction,
										plr,
										parsedArgs,
										data
									),
								}
								local success, error = cmdFuncRets[1], cmdFuncRets[2]
								local errorTrace = not success and cmdFuncRets[3]

								if success and Promise.is(error) then
									--warn("promise recognized")
									error:finally(function() Core.trackCommandEndUsability(plr, command, data) end)
								else
									Core.trackCommandEndUsability(plr, command, data)
								end

								if not success then
									if returnOutput then return false, cmdMatch, "CmdError", error end

									plr:sendData("MakeUI", "NotificationV2", {
										title = `Command {cmdMatch} encountered an error`,
										desc = `Please report this error to the game developer or Essential maintenance team`
											.. `\n\n<font color='#ff5c5c'>{Parser:filterForSpecialMarkdownAndRichText(
												tostring(error)
											)}</font>`
											.. `\n<font color='#ed7b39'>{Parser:filterForSpecialMarkdownAndRichText(
												tostring(errorTrace)
											)}</font>`,
										highPriority = true,
										priorityLevel = 5,
									})

									--warn("Player command "..cmdMatch.." ["..plr.UserId.."] encountered an error: "..tostring(error))
									server.Events.commandError:fire(cmdMatch, command, plr, error, errorTrace)
									Logs.addLogForPlayer(plr, "Process", {
										title = "{{$target}} encountered an error while running command " .. tostring(
											cmdMatch
										) .. ": " .. tostring(error):sub(1, 400),
										desc = "Error: "
											.. Parser:filterForSpecialMarkdownTags(tostring(error):sub(1, 200)),
									})

									if server.Studio or server.debugProcess then
										warn(
											"Player command "
												.. cmdMatch
												.. " ["
												.. plr.UserId
												.. "] encountered an error: "
												.. tostring(error),
											errorTrace
										)
									end

									return false, cmdMatch
								else
									local retType = cmdFuncRets[3]
									local manageType = cmdFuncRets[4]

									if retType == -1 then Core.manageCommandUsability(plr, command, manageType) end

									return if command.Hidden then -1 else true, cmdMatch, unpack(cmdFuncRets, 3)
								end
							else
								return false, cmdMatch
							end
						else
							local failFunc = command.Fail

							if type(failFunc) == "function" then
								local failFuncRets = {
									service.trackTask(
										"_COMMAND_FAIL_" .. cmdMatch:upper() .. "_" .. plr.UserId,
										false,
										failFunc,
										plr,
										data
									),
								}
								local failFuncRan = failFuncRets[1]

								if not failFuncRan then
									server.Events.commandFailError:fire(cmdMatch, command, plr, failFuncRets[2])
								else
									if rawequal(failFuncRets[2], true) then return false, cmdMatch end
								end
							end

							if not command.Silent then
								if returnOutput then
									return false,
										cmdMatch,
										"CmdInaccessible",
										checkError,
										checkErrorArg1,
										command.Hidden
								else
									local isCmdHidden = command.Hidden
									if not data.noReturn then
										if
											(
												checkError == "ServerCooldown"
												or checkError == "PlayerCooldown"
												or checkError == "CrossCooldown"
											) and plr
										then
											plr:sendData(
												"SendMessage",
												"Command <u>"
													.. Parser:filterForRichText(tostring(cmdMatch))
													.. "</u>: You're on the cooldown for  "
													.. tostring(checkErrorArg1)
													.. " seconds.",
												"Command "
													.. tostring(cmdMatch)
													.. ": You're on the cooldown for  "
													.. tostring(checkErrorArg1)
													.. " seconds.",
												5,
												"Context"
											)
										elseif (checkError == "PlayerDebounce") and plr then
											plr:sendData(
												"SendMessage",
												"Command <u>"
													.. Parser:filterForRichText(tostring(cmdMatch))
													.. "</u>: This command is already in process previously. You must wait for its execution done before running this command again.",
												"Command "
													.. tostring(cmdMatch)
													.. ": This command is already in process previously. You must wait for its execution done before running this command again.",
												5,
												"Context"
											)
										elseif (checkError == "ServerDebounce") and plr then
											plr:sendData(
												"SendMessage",
												"Command <u>"
													.. Parser:filterForRichText(tostring(cmdMatch))
													.. "</u>: This command is already being used in the server. You must wait for its execution done before running this command again.",
												"Command "
													.. tostring(cmdMatch)
													.. ": This command is already being used in the server. You must wait for its execution done before running this command again.",
												5,
												"Context"
											)
										elseif (checkError == "Chat") and plr and not isCmdHidden then
											plr:sendData(
												"SendMessage",
												"Command <u>"
													.. Parser:filterForRichText(tostring(cmdMatch))
													.. "</u>: You cannot use this in chat.",
												"Command " .. tostring(cmdMatch) .. ": You cannot use this in chat.",
												5,
												"Context"
											)
										elseif (checkError == "MissingPerms") and plr and not isCmdHidden then
											plr:sendData(
												"SendMessage",
												"Command <u>"
													.. Parser:filterForRichText(tostring(cmdMatch))
													.. "</u>: You must have these permissions <b>"
													.. Parser:filterForRichText(table.concat(checkErrorArg1, ", "))
													.. "</b> to run.",
												"Command "
													.. tostring(cmdMatch)
													.. ": You must have these permissions <b>"
													.. table.concat(checkErrorArg1, ", ")
													.. " to run.",
												5,
												"Context"
											)
										elseif (checkError == "MissingRoles") and plr and not isCmdHidden then
											plr:sendData(
												"SendMessage",
												"Command <u>"
													.. Parser:filterForRichText(tostring(cmdMatch))
													.. "</u>: You must have one of these roles <b>"
													.. Parser:filterForRichText(table.concat(checkErrorArg1, ", "))
													.. "</b> to run.",
												"Command "
													.. tostring(cmdMatch)
													.. ": You must have one of these roles <b>"
													.. table.concat(checkErrorArg1, ", ")
													.. " to run.",
												5,
												"Context"
											)
										elseif (checkError == "CommandBlacklist") and plr and not isCmdHidden then
											plr:sendData(
												"SendMessage",
												"Command <u>"
													.. Parser:filterForRichText(tostring(cmdMatch))
													.. "</u>: You're blacklisted from using this command.",
												"Command "
													.. tostring(cmdMatch)
													.. ": You're blacklisted from using this command.",
												5,
												"Context"
											)
										elseif (checkError == "Disabled") and not isCmdHidden then
											plr:sendData(
												"SendMessage",
												"Command <u>"
													.. Parser:filterForRichText(tostring(cmdMatch))
													.. "</u>: This command is disabled via setting.",
												"Command "
													.. tostring(cmdMatch)
													.. ": This command is disabled via setting.",
												5,
												"Context"
											)
										elseif (checkError == "GlobalBlacklist") and plr then
											plr:sendData(
												"SendMessage",
												"<font color='#e65545'><b>You are not permitted to run commands</b></font>",
												nil,
												5,
												"Context"
											)
										elseif (checkError == "RanTwice") and plr then
											plr:sendData(
												"SendMessage",
												`<font color='#e65545'><b>You are not permitted to run the command <u>{Parser:filterForRichText(
													cmdMatch
												)}</u> twice </b></font>`,
												nil,
												5,
												"Context"
											)
										elseif (checkError == "SocialMediaPoliciesDisallowed") and plr then
											plr:sendData(
												"SendMessage",
												`<font color='#e65545'>Your current social media policies are prohibiting you from running the command <u>{Parser:filterForRichText(
													cmdMatch
												)}</u>.</font> Required policies: {table.concat(
													checkErrorArg1,
													", "
												)}`,
												nil,
												5,
												"Context"
											)
										else
											if plr then
												if command.Error then
													local suc, res = pcall(command.Error, plr, data)

													if not suc then
														warn(
															"Command "
																.. cmdMatch
																.. " error function encountered an error: "
																.. tostring(res),
															10,
															"Hint"
														)
													end
												else
													if command.Hidden and msg then
														plr:sendData(
															"SendMessage",
															"Unable to execute <b>"
																.. Parser:filterForRichText(msg)
																.. "</b>",
															"Unable to execute " .. msg,
															5,
															"Context"
														)
														return
													end

													plr:sendData(
														"SendMessage",
														"Command <u>"
															.. Parser:filterForRichText(tostring(cmdMatch))
															.. "</u>: You have insufficient permissions to use this.",
														"Command "
															.. tostring(cmdMatch)
															.. ": You have insufficient permissions to use this.",
														5,
														"Context"
													)
												end
											end
										end
									end

									return false, cmdMatch, (command.Hidden and "Hidden" or nil)
								end
							else
								return false, "SilentError"
							end
						end
					else
						if returnOutput then
							return false, cmdMatch, "InvalidCommand"
						else
							if not data.noReturn and plr and msg then
								plr:sendData(
									"SendMessage",
									"Unable to execute <b>" .. Parser:filterForRichText(msg) .. "</b>",
									"Unable to execute " .. msg,
									5,
									"Context"
								)
							end
						end
					end
				end
			end
		end,

		playerVerified = function(player: ParsedPlayer)
			local playerObj = player._object

			playerObj.Chatted:connect(function(msg)
				Logs.addLogForPlayer(
					player,
					`Chat`,
					`\{\{$targetusername\}\}: {select(2, Filter:safeString(msg, player.UserId, player.UserId))}`
				)

				server.Events.playerChatted:fire(player, msg)

				-- if Utility:isMuted(player.Name) then
				-- 	player:Kick "Attempted to speak in chat while muted"
				-- else
					if msg:sub(1, 3) == "/e " then
						msg = msg:sub(4)
					elseif msg:sub(1, 1) == "/" and settings.slashCommands then
						return
					end

					if #msg > 0 then
						local chatCommands = settings.chatCommands

						if
							chatCommands and Utility:deferCheckRate(Process.chatProcessCommand_RateLimit, player.UserId)
						then
							Process.playerCommand(player, msg, {
								noReturn = true,
								chatted = true,
								robloxChat = true,
								maxCommands = settings.chatMaxCommands,
							})
						end
					end
				-- end
			end)

			playerObj.CharacterAdded:connect(function(char) server.Events.characterAdded:fire(player, char) end)

			if playerObj.Character then server.Events.characterAdded:fire(player, playerObj.Character) end

			local lastJoinedLog = player:getPData().serverData.lastJoinedLog
			local isPlayerAnAdmin = Moderation.checkAdmin(playerObj)

			local expectedWelcomeMessage = if isPlayerAnAdmin
				then settings.welcomeMessages.admins
				else settings.welcomeMessages.nonAdmins

			if settings.welcome_Allow and #expectedWelcomeMessage > 0 then
				player:sendData("MakeUI", "NotificationV2", {
					title = "Welcome, <b>" .. player.DisplayName .. "</b>!",
					desc = Parser:filterStringWithSpecialMarkdown(settings.welcomeMessages.admins, nil, {
						customReplacements = {
							["displayname"] = player.DisplayName,
							["user"] = player:toStringDisplay(),
							["userid"] = player.UserId,
							["membership"] = if isPlayerAnAdmin
								then `administrator`
								elseif Identity.checkDonor(player) then `donator`
								else `non-administrator`,
						},
					}) .. (if not lastJoinedLog
						then ``
						else ` You last joined the game on \{\{t:{lastJoinedLog.sentOs}:ldt\}\}.`),
					richText = true,
					hideTimeDuration = true,

					highPriority = true,
					priorityLevel = math.huge,
					time = 20,
				})
			end

			local deafened = Utility:isDeafened(player.Name)
			local muted = Utility:isMuted(player.Name)

			if deafened then
				player:sendData("SetCoreGuiEnabled", Enum.CoreGuiType.Chat, false)
			elseif muted then
				player:sendData("SetCore", "ChatBarDisabled", true)
			end

			if deafened or muted then
				local mainChannel = (server.chatService and server.chatService:GetChannel "All")

				if mainChannel then mainChannel:MuteSpeaker(player.Name) end
			end

			if
				variables.jailedPlayers[tostring(player.UserId)]
				and variables.jailedPlayers[tostring(player.UserId)].active
			then
				player:sendData("SetCoreGuiEnabled", Enum.CoreGuiType.Backpack, false)
			end

			local playerData = player:getPData()

			-- Check if player data has encryption (warning notification)
			if playerData._encryptionEnabled and not playerData.seenEncryptMessage then
				local impPM = Remote.privateMessage {
					receiver = player,
					sender = nil,
					topic = "PData Encryption Notice",
					desc = "Important info about player data",
					message = table.concat({
						"Your player data is being encrypted under lightweight AES encryption.",
						"It is <b>NOT 100%</b> guaranteed that it saves upon server shutdown or the time you leave the game.",
						"",
						"Your game developer has enabled player data encryption under developer settings.",
					}, "\n"),
					notifyOpts = {
						title = "PData encryption",
						desc = "Read about what's happening with your player data",
						time = 30,
					},
					expireOs = os.time() + 60,
					noReply = true,
				}

				impPM.opened:connectOnce(function() playerData.seenEncryptMessage = true end)
			elseif not playerData._encryptionEnabled and playerData.seenEncryptMessage then
				playerData.seenEncryptMessage = nil
			end

			-- Check for latest Essential update
			local lastUpdated, updateDuration, updateVers, updateInfo =
				changelog.lastUpdated, changelog.updateDuration, changelog.updateVers, changelog.updateInformation

			local canShowUpdate = (lastUpdated + updateDuration) >= os.time()
			if canShowUpdate then
				local lastViewedVers = playerData.viewedUpdateVers
				--warn("Got last viewed:", lastViewedVers)
				--warn("Cur vers:", updateVers)
				if lastViewedVers ~= updateVers then
					playerData.viewedUpdateVers = updateVers

					Remote.privateMessage {
						receiver = player,
						sender = nil,
						topic = "Essential Changelogs",
						desc = "Latest information of Essential <i>(latest version: v" .. updateVers .. ")</i>",
						message = Parser:replaceStringWithDictionary(table.concat(updateInfo, "\n"), {
							["{$selfprefix}"] = settings.playerPrefix,
							["{$actionprefix}"] = settings.actionPrefix,
							["{$delimiter}"] = settings.delimiter,
							["{$batchSeperator}"] = settings.batchSeperator,
						}),
						notifyOpts = {
							title = "New update! ⬆️",
							desc = "Click to view the latest changes",
						},
						noReply = true,
					}
				end
			end

			-- Auto-update dynamic policies
			do
				PolicyManager:_updateDynamicClientPolicies(player)
				service.stopLoop(`AUTOUPDATE_DYNAMICPOLICIES-{player.UserId}`)
				service.loopTask(`AUTOUPDATE_DYNAMICPOLICIES-{player.UserId}`, 300, function()
					if not player:isInGame() then
						service.stopLoop(`AUTOUPDATE_DYNAMICPOLICIES-{player.UserId}`)
						return
					end
					server.PolicyManager:_updateDynamicClientPolicies(player)
				end)
			end

			-- Saved roles

			do
				local savedRoles = playerData.__savedRoles
				local assignedInSavedRoles = {}
				local function updateRoles()
					for i, role in pairs(Roles:getAll()) do
						if role.saveable then
							local didFindInSave = savedRoles._find(role.name)
							if didFindInSave and not role:checkTempMember(player) then
								role:tempAssignWithMemberId(player.UserId)
								assignedInSavedRoles[role] = true
							elseif not didFindInSave then
								if assignedInSavedRoles[role] then
									assignedInSavedRoles[role] = nil
									role:tempUnAssignWithMemberId(player.UserId)
								end
							end
						end
					end
				end
				savedRoles._updated:connect(updateRoles)
				updateRoles()
			end

			-- Messaging
			do
				local watchedMsgIds = {}
				local function checkMessages()
					if player:isInGame() then
						local messages = playerData.__messages

						for i, messageBody in ipairs(messages._table) do
							if not watchedMsgIds[messageBody.id] then
								watchedMsgIds[messageBody.id] = true
								task.defer(function()
									local senderUserId = messageBody.senderUserId
									local messageText = messageBody.text
									local senderName = senderUserId and service.playerNameFromId(senderUserId)
										or "[SYSTEM]"
									local privateMessage = Remote.privateMessage {
										receiver = player,
										topic = "Direct Message - "
											.. tostring(messageBody.title or "[no title]")
											.. (messageBody.isAReply and " [reply]" or ""),
										desc = "<i>This message was sent directly from your player data. Opening this has marked your dm on read.</i>",
										message = table.concat({
											messageText,
											"",
											"",
											"<i>Sent on "
												.. Parser:osDate(messageBody.sent)
												.. " UTC by player <b>"
												.. senderName
												.. "</b> </i>",
											"<i>-------</i>",
											"<i>Replied to:</i>",
											"<i>" .. tostring(messageBody.prevMessage or "none") .. "</i>",
										}, "\n"),
										notifyOpts = { title = "Direct message", desc = "From " .. senderName },
										noReply = not senderUserId or messageBody.noReply,
										openTime = messageBody.openTime,
									}

									privateMessage.opened:selfConnect(function(self, isSender)
										--warn("Did open?")
										if isSender then return end
										self:disconnect()
										messages._pull(messageBody)
									end)

									if not messageBody.noReply and senderUserId and senderUserId > 0 then
										privateMessage.replied:connectOnce(function(fromSender, replyData)
											if fromSender then return end
											local replyMsg = replyData[2]

											privateMessage:destroy()
											
											task.spawn(function()
												local canSendMessage = service.isPlayerUserIdValid(senderUserId)
												if not canSendMessage then
													player:sendData(
														"SendMessage",
														"Your private message for a player with user id <b>"
															.. senderUserId
															.. "</b> cannot send due to non-existent target",
														nil,
														8,
														"Context"
													)
												else
													local targetPlayer = Parser:apifyPlayer({
														Name = service.playerNameFromId(senderUserId),
														UserId = senderUserId,
													}, true)
													if targetPlayer then
														targetPlayer:directMessage {
															title = "From " .. tostring(targetPlayer),
															text = replyMsg,
															senderUserId = player.UserId,
															isAReply = true,
															prevMessage = messageText,
														}
														player:sendData(
															"SendMessage",
															"Successfully replied to your dm with player <b>"
																.. tostring(targetPlayer)
																.. "</b>",
															nil,
															4,
															"Context"
														)
													end
												end
											end)
										end)
									end
								end)
							end
						end
					end
				end

				local listenEvent = playerData._listenIndexChangedEvent("messages", checkMessages)
				player.disconnected:connectOnce(function() listenEvent:disconnect() end)

				checkMessages()
			end

			-- Server details
			do
				if not server.Studio then
					local joinedOs = os.time()

					local sessionUpdateloopIndex = `Auto-Update Player {player.UserId} Session Data`
					service.loopTask(sessionUpdateloopIndex, 180, function()
						if player:isInGame() then
							playerData.serverDetails = {
								serverJobId = game.JobId,
								serverAccessCode = variables.privateServerData
										and variables.privateServerData.serverAccessId
									or nil,
								privateServer = #game.PrivateServerId > 0,
								privateServerId = game.PrivateServerId,
								joined = joinedOs,
								lastUpdated = os.time(),
							}
						end
					end)

					player.disconnected:connectOnce(function() service.stopLoop(sessionUpdateloopIndex) end)
				end
			end

			-- Setup Incognito name
			do
				local incognitoName = playerData.incognitoName

				if not incognitoName or #incognitoName == 0 or playerData.incognitoNameRandom then
					playerData.incognitoNameRandom = false
					player:generateIncognitoName()
					player:sendData(
						"SendMessage",
						`Your incognito mode is <b>{playerData.incognitoName}</b>. This name will appear in logs and display names to people, although in-game administrators have full visibility to your name.`,
						nil,
						4,
						"Context"
					)
				end

				--warn(`Player {player.Name} incognito name: {playerData.incognitoName}`)
			end

			-- Show global notices
			do
				for i, noticeData in Utility.Notices._globalNotices do
					player:makeUI("NotificationV2", {
						title = noticeData.title,
						description = noticeData.description,
						timeDuration = noticeData.timeDuration,
						priorityLevel = noticeData.priorityLevel,

						richText = noticeData.richText,
						iconUrl = noticeData.iconUrl,
						showSoundUrl = noticeData.showSoundUrl,

						handlerId = noticeData._id,
					})
				end
			end

			-- Warn beta encrypted communication
			--if endToEndEncryption then
			--	player:sendData("SendMessage",
			--		"<b>[BETA]</b> Your communication to Essential network uses <u>end-to-end encryption</u> to obfuscate remote listeners. You may experience unexpected encryption issues.",
			--		nil,
			--		5, "Context")
			--end

			server.Events.playerVerified:fire(player)
			player.verified:fire(true)

			Logs.addLogForPlayer(player, "Process", {
				desc = "Player {{$target}} was verified",
			})
		end,

		playerCheckIn = function(player)
			local cliData = Core.clients[player]
			local parsed = Parser:apifyPlayer(player)

			if cliData and cliData.verified and not cliData.checkingIn then
				local lastCheckIn = cliData.lastCheckIn

				if not lastCheckIn or (os.time() - lastCheckIn > 10) then
					cliData.checkingIn = true

					parsed:sendData "CheckIn"
					local readyToMoveOn = false
					local link
					link = server.Events.playerCheckIn:connect(function(checkInPlr)
						if checkInPlr == player then
							link:Disconnect()
							readyToMoveOn = true
						end
					end)

					Signal:waitOnSingleEvents({link, parsed.disconnected}, nil, 120)
					
					link:Disconnect()

					cliData.checkingIn = false
					cliData.lastCheckIn = os.time()

					if not readyToMoveOn and not parsed:isInGame() then return end

					if not readyToMoveOn then
						cliData.verified = false
						--warn("Checking in with player "..player.Name.." failed")
						server.Events.securityCheck:fire("FailedCheckIn", player)

						Logs.addLogForPlayer(
							player,
							`Process`,
							`Player \{\{$targetusername\}\} didn't check in within 2 minutes`
						)

						parsed:Kick "Failed to check in within 2 minutes"
						return
					end

					Roles:dynamicUpdateChatTagsForPlayer(player)
				end
			end
		end,
	}
end
