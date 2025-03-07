--!nocheck
return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service
	local variables = envArgs.variables
	local settings = server.Settings

	local base64Encode = service.base64Encode
	local base64Decode = service.base64Decode
	local getRandom = service.getRandom
	local tulirAES = server.TulirAES
	local luaParser = server.LuaParser
	local hashLib = server.HashLib
	local compression = server.Compression

	local DS_PlayerData
	local cloneTable = service.cloneTable
	local loopTask = service.loopTask
	local stopLoop = service.stopLoop
	local getRandom = service.getRandom
	local checkEquality = service.checkEquality
	local metaFunc = service.metaFunc
	local metaRead = service.metaRead

	local Signal = server.Signal
	local Queue = server.Queue
	local Promise = server.Promise

	local Filter = server.Filter
	local Network = server.Network
	local Parser = server.Parser
	local Roles = server.Roles
	local Utility = server.Utility
	local Vela = server.Vela

	local hashLib
	local datastore_Allow, datastore_ProtectIndex, datastore_EncryptKeys, datastoreUseCompression, playerData_EncryptData, playerDataStoreEnabled
	local defaultPlayerData
	local endToEndEncryption = settings.endToEndEncryption or settings.remoteClientToServerEncryption
	local maxActivityLogs = settings.playerData_MaxActivityLogs
	
	local remoteEncryptCompressionConfig = {
		level = 1,
		strategy = "dynamic",
	}

	local function decryptRemoteArguments(encryptKey: string, encryptedArgs: string)
		local decryptValue2 = tulirAES.decrypt(encryptKey, encryptedArgs, nil, 5)
		decryptValue2 = compression.Deflate.Decompress(decryptValue2, remoteEncryptCompressionConfig)
		local decryptValue3 = decryptValue2 and luaParser.Decode(decryptValue2)[1]
		return decryptValue3
	end

	local function sortArgumentsWithInstances(arguments: { [any]: any }, instanceList: { [string]: Instance })
		local function getInstanceSignature(str: string) return string.match(str, "^\28Instance" .. 0x1E .. "%-(%w+)$") end

		local checkedTabValues = {}

		local function reverseCloneTableValue(clonedTable)
			local newClonedTable = {}
			checkedTabValues[clonedTable] = newClonedTable

			for i, tabValue in pairs(clonedTable) do
				local clonedValue = checkedTabValues[tabValue]
				if not clonedValue then
					if type(tabValue) == "table" then
						newClonedTable[i] = reverseCloneTableValue(tabValue)
						continue
					elseif type(tabValue) == "string" then
						if tabValue == "\28NilValue" .. 0x1E then --// Nil value
							newClonedTable[i] = nil
							continue
						end

						local instSignature = getInstanceSignature(tabValue)
						local assignedInstance = instSignature and instanceList[instSignature]
						newClonedTable[i] = assignedInstance or tabValue
						continue
					else
						newClonedTable[i] = tabValue
					end
				end

				newClonedTable[i] = if not not clonedValue then clonedValue else tabValue
			end

			return newClonedTable
		end

		return reverseCloneTableValue(arguments)
	end

	local Commands, Core, Cross, Datastore, Identity, Logs, Moderation, Process, Remote
	local function Init()
		Core = server.Core
		Cross = server.Cross
		Commands = server.Commands
		Datastore = server.Datastore
		Identity = server.Identity
		Logs = server.Logs
		Moderation = server.Moderation
		Network = server.Network
		Process = server.Process
		Remote = server.Remote

		hashLib = server.HashLib
		defaultPlayerData = Core.defaultPlayerData

		datastore_Allow = settings.Datastore_Allow
		datastore_ProtectIndex = settings.Datastore_ProtectIndex
		datastore_EncryptKeys = settings.Datastore_EncryptKeys
		datastoreUseCompression = settings.Datastore_Compression or false

		DS_PlayerData = settings.Datastore_PlayerData:sub(1, 50)

		playerDataStoreEnabled = settings.playerData_Datastore
		playerData_EncryptData = settings.playerData_EncryptData

		if #DS_PlayerData == 0 then
			DS_PlayerData = "Default"
			warn "[DATASTORE DISABLED] DATASTORE PLAYERDATA SCOPE MUST HAVE AT LEAST ONE CHARACTER."
			settings.playerData_Datastore = false
			datastore_Allow = false
			playerDataStoreEnabled = false
		end

		if datastore_Allow and game.PlaceId <= 0 then datastore_Allow = false end
	end

	local playerDataCache = {}

	server.Core = {
		Init = Init,

		playerData = {},
		clients = {},

		createRemote = function() -- Establishes client connections
			local remoteNetwork1 = {}
			local remoteNetwork2 = {}

			local remoteExploitCheckRL = {
				Rates = 8,
				Reset = 120,
			}

			local function logRemoteExploit(plr: ParsedPlayer, text: string)
				Logs.addLog("Remote", text)
				local passExploit = Utility:deferCheckRate(remoteExploitCheckRL, plr.UserId)
				if not passExploit then
					plr:setVar("NetworkBan", true)
					Moderation.addBan(plr.Name, "Server", "Too many exploited attempts to remote")
				end
			end

			-- Creates 20 remote events
			for i = 1, 30, 1 do
				local clientNetwork
				clientNetwork = Network.newCreate("Main1", {
					invokable = false,
					--firewallEnabled = true;
					--firewallType = "high";
					firewallCheckIndex = true,
					firewallRequireAccessKey = true,
					firewallAllowRemoteKeyForAccess = true,
					networkCommands = Remote.Commands,
					networkFunc = function(plr, ...)
						local clientData = Core.clients[plr]
						local cli_Remote = (clientData and clientData.remoteEv) or nil
						local parsedPlr = server.Parser:apifyPlayer(plr)

						--warn("Player called:", {...})

						if clientData and clientData.trustChecked and cli_Remote == clientNetwork then
							if clientData.tamperedFolder then
								plr:Kick(
									"Essential:\nUnable to access network due to tampered folder:\n"
										.. tostring(clientData.tamperedFolderReason)
								)
								return -1
							end

							-- Remote client to server encryption
							local remoteArguments = { ... }
							if endToEndEncryption then
								local _, encryptedArgs, instanceList = ...
								--warn("Encrypted args:", encryptedArgs)
								if type(encryptedArgs) ~= "string" then return end
								encryptedArgs = decryptRemoteArguments(clientData.remoteServerKey, encryptedArgs)
								--warn("Decrypted args:", encryptedArgs)
								--warn("Instance list:", instanceList)

								if type(encryptedArgs) ~= "table" then return end
								local assortedArguments = sortArgumentsWithInstances(encryptedArgs, instanceList)
								--warn("Assorted arguments:", assortedArguments)
								remoteArguments = { _, unpack(assortedArguments) }
							end

							local rets = {
								service.trackTask(
									"MAIN1-CLIENTNETWORK-" .. plr.UserId,
									false,
									Process.remoteCall,
									plr,
									false,
									false,
									unpack(remoteArguments)
								),
							}

							if not rets[1] then
								warn(
									"Server client-shared network (1) encountered an error: " .. tostring(rets[2]),
									rets[3]
								)
							end
							--elseif clientData and clientData.trustChecked then
							--	warn("Unauthorized remote called from "..plr.Name.."?")
							--	server.Events.securityCheck:fire("UnauthorizedRemote", plr, clientNetwork)
							--	parsedPlr:Kick("Unauthorized to call remote ("..tostring(clientNetwork.Id)..")")
						end
					end,
				})

				--local clientNetwork; clientNetwork = Network.create("Main1", Network.MainDirectory, false, false, function(plr, ...)
				--	local clientData = Core.clients[plr]
				--	local cli_Remote = (clientData and clientData.remoteEv) or nil
				--	local parsedPlr = server.Parser:apifyPlayer(plr)

				--	if clientData and clientData.trustChecked and cli_Remote == clientNetwork then
				--		if clientData.tamperedFolder then
				--			plr:Kick("Essential:\nUnable to access network due to tampered folder:\n"..tostring(clientData.tamperedFolderReason))
				--			return -1
				--		end

				--		local rets = {service.trackTask("MAIN1-CLIENTNETWORK-"..plr.UserId, false, Process.remoteCall, plr, false, false, ...)}

				--		if not rets[1] then
				--			warn("Server client-shared network encountered an error: "..tostring(rets[2]), rets[3])
				--		end
				--		--elseif clientData and clientData.trustChecked then
				--		--	warn("Unauthorized remote called from "..plr.Name.."?")
				--		--	server.Events.securityCheck:fire("UnauthorizedRemote", plr, clientNetwork)
				--		--	parsedPlr:Kick("Unauthorized to call remote ("..tostring(clientNetwork.Id)..")")
				--	end
				--end)

				table.insert(remoteNetwork1, clientNetwork)
			end

			for i = 1, 30, 1 do
				-- Creates 20 remote functions
				local clientNetwork
				clientNetwork = Network.newCreate("Main2", {
					invokable = true,
					--firewallEnabled = true;
					--firewallType = "high";
					firewallCheckIndex = true,
					firewallRequireAccessKey = true,
					firewallAllowRemoteKeyForAccess = true,
					networkCommands = Remote.Commands,
					networkFunc = function(plr, ...)
						local clientData = Core.clients[plr]
						local cli_Remote = (clientData and clientData.remoteFunc) or nil
						local parsedPlr = server.Parser:apifyPlayer(plr)

						--warn("Player called:", {...})

						if clientData and clientData.trustChecked and cli_Remote == clientNetwork then
							if clientData.tamperedFolder then
								plr:Kick(
									"Essential:\nUnable to access network due to tampered folder:\n"
										.. tostring(clientData.tamperedFolderReason)
								)
								return -1
							end

							local remoteArguments = { ... }
							if endToEndEncryption then
								local _, encryptedArgs, instanceList = ...
								--warn("Encrypted args:", encryptedArgs)
								if type(encryptedArgs) ~= "string" then return end
								encryptedArgs = decryptRemoteArguments(clientData.remoteServerKey, encryptedArgs)
								--warn("Decrypted args:", encryptedArgs)
								--warn("Instance list:", instanceList)

								if type(encryptedArgs) ~= "table" then return end
								local assortedArguments = sortArgumentsWithInstances(encryptedArgs, instanceList)
								--warn("Assorted arguments:", assortedArguments)
								remoteArguments = { _, unpack(assortedArguments) }
							end

							local rets = {
								service.trackTask(
									"MAIN2-CLIENTNETWORK-" .. plr.UserId,
									false,
									Process.remoteCall,
									plr,
									false,
									true,
									unpack(remoteArguments)
								),
							}

							if not rets[1] then
								warn(
									"Server client-shared network (2) encountered an error: " .. tostring(rets[2]),
									rets[3]
								)
							else
								return unpack(rets, 2)
							end
							--elseif clientData and clientData.trustChecked then
							--	warn("Unauthorized remote called from "..plr.Name.."?")
							--	server.Events.securityCheck:fire("UnauthorizedRemote", plr, clientNetwork)
							--	parsedPlr:Kick("Unauthorized to call remote ("..tostring(clientNetwork.Id)..")")
						end
					end,
				})

				--local clientNetwork; clientNetwork = Network.create("Main2", Network.MainDirectory, true, false, function(plr, ...)
				--	local clientData = Core.clients[plr]
				--	local cli_Remote = (clientData and clientData.remoteFunc) or nil
				--	local parsedPlr = server.Parser:apifyPlayer(plr)

				--	if clientData and clientData.trustChecked and cli_Remote == clientNetwork then
				--		if clientData.tamperedFolder then
				--			plr:Kick("Essential:\nUnable to access network due to tampered folder:\n"..tostring(clientData.tamperedFolderReason))
				--			return -1
				--		end

				--		local rets = {service.trackTask("MAIN2-CLIENTNETWORK-"..plr.UserId, false, Process.remoteCall, plr, false, true, ...)}

				--		if not rets[1] then
				--			warn("Server client-shared network (2) encountered an error: "..tostring(rets[2]), rets[3])
				--		else
				--			return unpack(rets, 2)
				--		end
				--		--elseif clientData and clientData.trustChecked then
				--		--	warn("Unauthorized remote called from "..plr.Name.."?")
				--		--	server.Events.securityCheck:fire("UnauthorizedRemote", plr, clientNetwork)
				--		--	parsedPlr:Kick("Unauthorized to call remote ("..tostring(clientNetwork.Id)..")")
				--	end
				--end)

				table.insert(remoteNetwork2, clientNetwork)
			end

			--for i = 1,10,1 do
			--	Network.newDecoy("_CLIENTREMOTE_DECOY", {
			--		invokable = false;
			--	})
			--end

			--for i = 1,10,1 do
			--	Network.newDecoy("_CLIENTREMOTE2_DECOY", {
			--		invokable = true;
			--	})
			--end

			-- Create trust network
			local subNetworkTrustChecker
			subNetworkTrustChecker = Network.newCreate("TrustChecker", {
				invokable = true,
				firewallEnabled = true,
				firewallType = "high",
				networkFunc = function(plr: Player, actionType: string, subNetworkId: string, trustKey: string)
					local parsedPlr = Parser:apifyPlayer(plr)
					--		local cliData = parsedPlr:getClientData()
					--		local personalKey = subNetwork.networkKeys[parsedPlr.playerId]
					--		local didPassRetrievalCount = personalKey and personalKey.trustKeyRetrieveAttempts+1 <= subNetwork.securitySettings.maxTrustKeyRetrievals

					--		if subNetwork.active and cliData and personalKey and personalKey:isActive() and didPassRetrievalCount and keyId == personalKey.trustKey then
					--			personalKey.trustChecked = true
					--			personalKey.trustKeyRetrieveAttempts = personalKey.trustKeyRetrieveAttempts+1

					--			subNetwork._trustChecker:runToPlayers({plr}, "TrustCheck", {
					--				subNetwork._network1.publicId,
					--				subNetwork._network2.publicId,
					--				personalKey.disconnectId,
					--			})
					--		end

					--warn("Player called on sub network trust checker:", actionType, subNetworkId, trustKey)
					if type(actionType) == "string" and actionType == "TrustCheck" then
						local clientData = Core.clients[plr]

						if
							clientData
							and clientData.trustChecked
							and type(subNetworkId) == "string"
							and type(trustKey) == "string"
						then
							local subNetwork = Remote.getSubNetwork(subNetworkId)

							if subNetwork then
								local keyData = subNetwork:getPlayerKey(parsedPlr)
								if
									keyData
									and keyData:isActive()
									and not keyData.trustChecked
									and keyData.trustKey == trustKey
								then
									keyData.trustChecked = true

									--warn("Signed sub network trust check for sub network "..subNetwork.name)

									subNetwork._network1:addPlayerToTrustCheck(parsedPlr, 300)
									subNetwork._network1:createPlayerKey(parsedPlr)
									subNetwork._network2:createPlayerKey(parsedPlr)

									subNetwork.connecting:fire(parsedPlr)

									return true,
										subNetwork._network1.publicId,
										subNetwork._network2.publicId,
										keyData.disconnectId
								end
							end

							return false
						end
					end
				end,
			})

			local trustChecker
			trustChecker = Network.newCreate("TrustChecker", {
				invokable = false,
				firewallEnabled = true,
				firewallType = "high",
				networkFunc = function(plr: Player, trustId: string)
					local clientData = Core.clients[plr]
					local parsedPlr = Parser:apifyPlayer(plr)

					if
						clientData
						and not clientData.trustChecked
						and (not clientData.verifyId or clientData.verifyId == trustId)
					then
						if clientData.tamperedFolder then
							plr:Kick(
								"Essential:\nFailed to trust check due to tampered folder:\n"
									.. tostring(clientData.tamperedFolderReason)
							)
							return {}
						end

						clientData.trustChecked = true
						clientData.trustCheckOs = tick()
						--warn("Did trust check?")

						local idleSearchTimeout = 300 -- Wait seconds of trust check
						local remoteEv_networks = Network.get "Main1"
						local remoteFunc_networks = Network.get "Main2"

						local remoteEv = remoteEv_networks[math.random(1, #remoteEv_networks)]
						local remoteFunc = remoteFunc_networks[math.random(1, #remoteFunc_networks)]

						local evPlayerKey = remoteEv:createPlayerKey(parsedPlr)
						remoteEv:addPlayerToTrustCheck(parsedPlr, idleSearchTimeout)
						local funcPlayerKey = remoteFunc:createPlayerKey(parsedPlr)
						remoteFunc:addPlayerToTrustCheck(parsedPlr, idleSearchTimeout)

						subNetworkTrustChecker:createPlayerKey(parsedPlr)

						clientData.remoteEv = remoteEv
						clientData.remoteFunc = remoteFunc
						clientData.remoteServerKey = service.getRandom(math.random(15, 20))

						trustChecker:runToPlayers({ plr }, "TrustCheck", {
							remoteEv.publicId,
							remoteFunc.publicId,
							clientData.remoteServerKey,
							subNetworkTrustChecker.publicId,
							(endToEndEncryption and true) or false,
							{
								Rates = Process.remoteCall_RateLimit.Rates,
								Reset = Process.remoteCall_RateLimit.Reset,
							},
							--evPlayerKey,
							--funcPlayerKey,
						})
					end
				end,
			})
			
			Core.remoteNetwork1 = remoteNetwork1
			Core.remoteNetwork2 = remoteNetwork2
			Core.remoteTrustChecker = trustChecker
		end,

		createGlobal = function()
			local proxData = service.newProxy
			local metaTable = service.metaTable
			local globalAllowed = settings.G_API_Allow
			local tokenAuth = settings.G_API_TokenAuth
			local tokens = {}
			local checkedTokens = {}
			local globals
			globals = {}
			local openGlobal = {}

			local function generateToken(tokenName, expiredOs)
				local tokenInfo = setmetatable({
					id = service.getRandom(),
					name = tokenName or service.getRandom(),
					expiredOs = expiredOs,
					accessPerms = {},
					openTable = {},

					enabled = true,
				}, {})

				local tokenMeta = getmetatable(tokenInfo)
				tokenMeta.__tostring = function() return "EssGToken-" .. tokenInfo.id .. "-MetaTable" end
				tokenMeta.__metatable = "EssGToken-" .. tostring(tokenInfo.id or "[unknown]") .. "-MetaTable"

				local prevToken
				tokens[tokenInfo.name] = tokenInfo

				return tokenInfo
			end

			Core.generateGlobalToken = generateToken

			local function accessIndex(ind, accessPerms, tokenInfo)
				local validIndexes = { "Cores", "Dependencies", "Assets", "Settings" }

				if not tokenInfo.enabled then
					error("Token is not enabled", 0)
					return
				end

				if type(ind) ~= "string" then
					error("Invalid index type (expected string)", 0)
					return
				end

				local openTableData = (tokenInfo.openTable or {})[ind]

				if tokenInfo then
					Logs.addLog("Global", {
						title = "Token "
							.. tokenInfo.name
							.. " ("
							.. tokenInfo.id
							.. ") attempted to index "
							.. tostring(ind),
						desc = "Id: " .. tokenInfo.id .. " | Name: " .. tokenInfo.name,
						data = {
							token = tokenInfo,
							invoker = debug.info(3, "f"),
						},
					})
				end

				if globals[ind] ~= nil and tokenInfo.canAccessPrivateTable then
					return globals[ind]
				elseif openTableData ~= nil then
					if not rawequal(openTableData, nil) then
						local dataType = type(openTableData)

						if dataType == "function" then
							return metaFunc(openTableData)
						elseif dataType == "table" then
							local dataName = tostring(openTableData)

							if dataName:sub(1, 3) == "RO-" then
								return metaRead(openTableData)
							elseif dataName:sub(1, 4) == "CRO-" then
								return metaRead(cloneTable(openTableData))
							elseif dataName:sub(1, 3) == "CT-" then
								return cloneTable(openTableData)
							else
								return openTableData
							end
						else
							return openTableData
						end
					end
				elseif table.find(validIndexes, ind) then
					local indAccessData = accessPerms[ind]

					if not indAccessData then
						error("Indexing " .. tostring(ind) .. " isn't allowed in _G", 2)
					else
						if ind == "Assets" then
							local retType = indAccessData.RetrieveType

							return service.newProxy {
								__index = function(_, assetName)
									assert(type(assetName) == "string", "Argument 1 (asset name) must be a string")

									local canAccess = indAccessData.Access

									if not canAccess then
										error("Access denied. Insufficient permissions", 2)
									else
										local fullAccess = indAccessData.FullAccess
										local assetItem = server.Assets[assetName]
										local canRetrieve = fullAccess or table.find(indAccessData.List, assetName)

										if canRetrieve and assetItem then
											if retType == "Clone" or retType == "clone" then
												if tokenInfo then
													Logs.addLog("Global", {
														title = "Token "
															.. tokenInfo.name
															.. " ("
															.. tokenInfo.id
															.. ") invoked for the cloned item "
															.. tostring(assetName),
														desc = "Id: " .. tokenInfo.id .. " | Name: " .. tokenInfo.name,
														data = {
															token = tokenInfo,
															invoker = debug.info(3, "f"),
														},
													})
												end

												return assetItem:Clone()
											elseif retType == "Original" or retType == "original" then
												if tokenInfo then
													Logs.addLog("Global", {
														title = "Token "
															.. tokenInfo.name
															.. " ("
															.. tokenInfo.id
															.. ") invoked for the original item "
															.. tostring(assetName),
														desc = "Id: " .. tokenInfo.id .. " | Name: " .. tokenInfo.name,
														data = {
															token = tokenInfo,
															invoker = debug.info(3, "f"),
														},
													})
												end

												return assetItem
											end
										end

										error("Unable to retrieve asset " .. assetName, 2)
									end
								end,

								__metatable = "Assets",
								__tostring = function() return "E.Assets" end,
							}
						elseif ind == "Settings" then
							return service.newProxy {
								__index = function(self, settingName)
									assert(
										type(settingName) == "string",
										"Setting name must be a string, not a " .. type(settingName)
									)

									local canAccess = indAccessData.Access

									if not canAccess then
										error("Access denied. Insufficient permissions", 2)
									else
										local fullAccess = indAccessData.FullAccess
										local canRetrieve = fullAccess or table.find(indAccessData.List, settingName)

										if canRetrieve then
											local accessType = indAccessData.AccessType

											local indSetting = settings[settingName]
											local settingType = type(indSetting)

											if tokenInfo then
												Logs.addLog("Global", {
													title = "Token "
														.. tokenInfo.name
														.. " ("
														.. tokenInfo.id
														.. ") acquired "
														.. settingName,
													desc = "Setting type: "
														.. settingType
														.. " | Setting val: "
														.. tostring(settingType),
													data = {
														token = tokenInfo,
														invoker = debug.info(3, "f"),
													},
												})
											end

											if settingType == "table" then
												return metaRead(cloneTable(indSetting))
											else
												return indSetting
											end
										else
											error(
												"Cannot index "
													.. tostring(settingName)
													.. " due to insufficient permissions",
												2
											)
										end
									end
								end,

								__newindex = function(self, settingName, settingVal)
									local canAccess = indAccessData.Access

									if not canAccess then
										error("Access denied. Insufficient permissions", 2)
									else
										local accessType = indAccessData.AccessType
										local canWrite = accessType == "write"
											or accessType == "Write"
											or accessType == "readOrWrite"

										if not canWrite then
											error(
												"Cannot overwrite "
													.. tostring(settingName)
													.. " to "
													.. tostring(settingVal)
											)
										else
											if tokenInfo then
												Logs.addLog("Global", {
													title = "Token "
														.. tokenInfo.name
														.. " ("
														.. tokenInfo.id
														.. ") overwritten setting "
														.. settingName
														.. " to "
														.. tostring(settingVal),
													desc = "Setting val: "
														.. tostring(settingVal)
														.. " | Val type: "
														.. type(settingVal),
													data = {
														token = tokenInfo,
														invoker = debug.info(3, "f"),
													},
												})
											end

											settings[settingName] = settingVal
										end
									end
								end,

								__tostring = function() return "E.Settings" end,
							}
						elseif openGlobal[ind] ~= nil then
							local openInd = openGlobal[ind]
							local indType = type(openInd)
							local indTypeof = typeof(openInd)

							if indType == "function" then
								return metaFunc(openInd)
							elseif indType == "table" then
								local tabStr = tostring(tostring(openInd))

								if tabStr:sub(1, 3) == "CC-" then -- Clone table
									return cloneTable(openInd)
								elseif tabStr:sub(1, 4) == "CL-" then -- Clone table with read only access
									return metaRead(cloneTable(openInd))
								elseif tabStr:sub(1, 3) == "LT-" then -- Latest table
									return openInd
								else -- Read only table
									return metaRead(openInd)
								end
							elseif indType == "userdata" and indTypeof ~= "Instance" then
								return service.specialWrap(openInd)
							else
								return openInd
							end
						else
							local indValue = server[ind]
							local indValType = type(indValue)

							if indValType == "table" and not rawequal(ind, "openGlobalTable") then
								local valAccessData = accessPerms[ind]

								if not valAccessData then
									error("Cannot access " .. ind .. " due to insufficient permissions.", 2)
								else
									return service.newProxy {
										__index = function(self, coreOrDepInd)
											local coreOrDepValData = valAccessData[coreOrDepInd]

											if not coreOrDepValData then
												error(
													"Unable to retrieve "
														.. tostring(coreOrDepInd)
														.. " from "
														.. tostring(ind),
													2
												)
											else
												local canAccess = indValue[coreOrDepInd]
													and (coreOrDepValData.FullAccess or #coreOrDepValData.List > 0)
													and true

												if canAccess then
													return service.newProxy {
														__index = function(_, indFromDepOrCore)
															local coreOrDepVal = indValue[coreOrDepInd]

															if type(coreOrDepVal) ~= "table" then
																error(
																	"Failed to index "
																		.. tostring(indFromDepOrCore)
																		.. " from a "
																		.. type(coreOrDepVal),
																	2
																)
															else
																local selectedIndex = coreOrDepVal[indFromDepOrCore]
																local selectType = type(selectedIndex)
																local valAccess = coreOrDepValData.Access
																local fullAccess = coreOrDepValData.FullAccess

																if
																	fullAccess
																	or table.find(
																		coreOrDepValData.List,
																		indFromDepOrCore
																	)
																then
																	if tokenInfo then
																		Logs.addLog("Global", {
																			title = "Token "
																				.. tokenInfo.name
																				.. " ("
																				.. tokenInfo.id
																				.. ") indexed "
																				.. tostring(indFromDepOrCore)
																				.. " from "
																				.. tostring(coreOrDepInd),
																			desc = "Index value type: "
																				.. selectType
																				.. " | Index value: "
																				.. tostring(selectedIndex),
																			data = {
																				token = tokenInfo,
																				invoker = debug.info(3, "f"),
																			},
																		})
																	end

																	if selectType == "table" then
																		if
																			valAccess == "Read"
																			or valAccess == "read"
																		then
																			return metaRead(selectedIndex)
																		elseif
																			valAccess == "Write"
																			or valAccess == "write"
																			or valAccess == "readOrWrite"
																		then
																			return selectedIndex
																		else
																			error("Unknown access", 2)
																		end
																	elseif selectType == "function" then
																		return metaFunc(selectedIndex)
																	else
																		return selectedIndex
																	end
																else
																	error(
																		"Cannot index "
																			.. tostring(indFromDepOrCore)
																			.. ". Insufficient permissions.",
																		2
																	)
																end
															end
														end,

														__newindex = function(_, indFromDepOrCore, val)
															local valAccess = coreOrDepValData.Access

															if
																valAccess == "Write"
																or valAccess == "write"
																or valAccess == "readOrWrite"
															then
																if tokenInfo then
																	local oldVal = indValue[indFromDepOrCore]
																	Logs.addLog("Global", {
																		title = "Token "
																			.. tokenInfo.name
																			.. " ("
																			.. tokenInfo.id
																			.. ") overwritten index sub-index value "
																			.. tostring(indFromDepOrCore)
																			.. " from index "
																			.. tostring(coreOrDepInd),
																		desc = "Changed index value to " .. tostring(
																			val
																		) .. " (" .. type(val) .. ") from " .. tostring(
																			oldVal
																		) .. " (" .. type(oldVal) .. ")",
																		data = {
																			token = tokenInfo,
																			invoker = debug.info(3, "f"),
																		},
																	})
																end

																indValue[indFromDepOrCore] = val
															else
																error(
																	"Attempted to overwrite value from index "
																		.. tostring(indFromDepOrCore)
																		.. " to "
																		.. type(val),
																	2
																)
															end
														end,

														__tostring = function()
															return "E."
																.. tostring(ind)
																.. "-"
																.. tostring(coreOrDepInd)
														end,
													}
												else
													error(
														"Unable to access "
															.. tostring(coreOrDepInd)
															.. " due to no available permissions or it doesn't exist",
														2
													)
												end
											end
										end,

										__tostring = function() return "E." .. tostring(ind) end,
									}
								end
							else
								error("Indexing " .. tostring(ind) .. " is not accessible", 2)
							end
						end
					end
				else
					error("Unable to index " .. tostring(ind), 2)
				end
			end

			local proxy = service.newProxy {
				__call = function(self, tokenName)
					-- Ignore if the console or this proxy called itself
					local callerEnv = getfenv(2)
					if rawequal(callerEnv, getfenv()) then return end

					local tokenInfo = tokens[tokenName]

					if not tokenInfo then
						error("Token " .. tostring(tokenName) .. " doesn't exist", 2)
					else
						local function checkExpired()
							return tokens[tokenName] ~= tokenInfo
								or (tokenInfo.expiredOs and os.time() - tokenInfo.expiredOs > 0)
						end

						if checkExpired() then
							error("Token " .. tokenName .. " is expired and cannot be used")
						else
							Logs.addLog("Global", {
								title = "Acquired a sync G table with token auth " .. tokenInfo.id,
								desc = "A synchronous Essential G table was created with token auth " .. tokenInfo.id,
								data = {
									token = tokenInfo,
									invoker = debug.info(3, "f"),
								},
							})

							return service.newProxy {
								__index = function(_, ind)
									if not checkExpired() then
										return accessIndex(ind, tokenInfo.accessPerms or {}, tokenInfo)
									end
								end,

								__tostring = function() return "SharedEssentialG_TokenAuth_" .. tostring(tokenName) end,
							}
						end
					end
				end,

				__index = function(self, ind)
					-- Ignore if the console or this proxy called itself
					local callerEnv = getfenv(2)
					if rawequal(callerEnv, getfenv()) then return end

					local indType = type(ind)
					local tokenAuth = settings.globalApi_TokenAuth

					if not tokenAuth then
						if indType == "string" or indType == "number" then
							return accessIndex(ind, settings.globalApi_Perms, {
								name = "-[Global]-",
								id = service.getRandom(),
								canAccessPrivateTable = (
									settings.globalApi_Perms.Default and settings.globalApi_Perms.Default.Access
								),
								enabled = true,
							})
						end
					else
						error("Token authentication is enabled. Public access is not available.", 2)
					end
				end,

				__newindex = function(self, ind, val)
					-- Ignore if the console or this proxy called itself
					local callerEnv = getfenv(2)
					if rawequal(callerEnv, getfenv()) then return end

					local indName = ""
					local indType = type(ind)

					if indType == "table" or indType == "userdata" then
						indName = "userdata/table"
					elseif indType == "string" or indType == "number" then
						indName = tostring(ind)
					else
						indName = indType
					end

					local valName = ""
					local valType = type(val)

					if valType == "table" or valType == "userdata" then
						valName = "userdata/table"
					elseif valType == "string" or valType == "number" then
						valName = tostring(val)
					else
						valName = valType
					end

					error("Attempting to overwrite " .. indName .. " to " .. valName, 2)
				end,

				__tostring = function() return "EssentialGlobal" end,
				__metatable = "EssentialG",
			}

			if not table.isfrozen(_G) then
				loopTask("Global lock", 0.1, function()
					if not table.isfrozen(_G) then
						rawset(_G, "Essential", proxy)
					else
						warn "Global table was frozen. Stopping global lock.."
						service.stopLoop "Global lock"
						Logs.addLog("Script", "Global table failed to insert in _G due to frozen table.")
					end
				end)
			else
				if not table.isfrozen(shared) then
					loopTask("Global lock", 0.1, function()
						if not table.isfrozen(shared) then
							rawset(shared, "Essential", proxy)
						else
							warn "Shared table was frozen. Stopping global lock.."
							service.stopLoop "Global lock"
							Logs.addLog("Script", "Global table failed to insert in shared due to frozen table.")
						end
					end)
				else
					warn "_G and shared tables are frozen. UNABLE TO INSERT ESSENTIAL GLOBAL."
					Logs.addLog("Script", "Global table failed to insert in _G and shared due to frozen tables.")
				end
			end

			server.globalInitialized = true
			server.openGlobalTable = openGlobal

			server.Events.globalInitialized:fire(proxy)
		end,

		defaultServerData = function()
			return {
				keybindsToggled = {},
			}
		end,

		defaultPlayerData = function()
			return {
				aliases = {},
				customCmdAliases = {},
				customKeybinds = {},
				cmdKeybinds = {},
				messages = {},
				shortcuts = {},
				warnings = {},

				clientSettings = {
					KeybindsEnabled = true,
					IncognitoMode = false,
				},

				activityLogs = {},
				savedRoles = {},

				encryptKey = getRandom(18),
				incognitoName = "",
			}, { -- Meta index settings
				messages = {
					maxEntries = 4,
				},
				activityLogs = {
					maxEntries = math.clamp(math.floor(maxActivityLogs or 30), 1, 90),
				},
			}
		end,

		getPlayerData = function(userId, ignoreLoading: boolean?)
			if type(userId) == "number" then
				-- DATA KEY MUST BE USED TO CHECK WITH THE SYSTEM DATASTORE FUNCTIONS
				-- HOWEVER, HASHED DATA KEY IS USED FOR SAVING DATA THROUGH ROBLOX DATASTORE INSTEAD OF SYSTEM
				local originalDataKey = tostring(userId)
				local hashedDataKey = originalDataKey
				local dataAccessKey = "PData_" .. DS_PlayerData:sub(1, 44)
				local encryptKey = playerData_EncryptData and "PlayerData-" .. userId
				local defaultData, metaIndexSettings = Core.defaultPlayerData()

				-- Datastore encryption
				if datastore_Allow and (datastore_ProtectIndex or datastore_EncryptKeys) then
					hashedDataKey = hashLib.md5(originalDataKey)
				end

				local dataCache = playerDataCache[userId]

				if not dataCache then
					local bannedIndexes =
						{ "_dataCache", "_changed", "_updated", "_lastUpdated", "_dataUpdate", "_dataCorrupted" }

					dataCache = {
						_dataChanged = false,
						_autoUpdate = true,
						_dataUpdate = true,

						_dataCorrupted = false,

						_updated = Signal.new(),
						_saveError = Signal.new(),
						_saveSuccess = Signal.new(),
						_indexUpdated = Signal.new(),
						--_changed = Signal.new();

						created = os.time(),
						lastUpdated = os.time(),

						serverData = setmetatable(Core.defaultServerData(), {
							__metatable = "ServerData-" .. userId,
						}),

						specialProxy = service.newProxy {
							__index = function(self, ind)
								if rawequal(ind, "serverData") then return dataCache.serverData end

								if rawequal(ind, "_dataCache") and server.Studio then return dataCache end

								if rawequal(ind, "_updated") then return metaRead(dataCache._updated:wrapConnect()) end

								if rawequal(ind, "_saveError") then
									return metaRead(dataCache._saveError:wrapConnect())
								end

								if rawequal(ind, "_saveSuccess") then
									return metaRead(dataCache._saveSuccess:wrapConnect())
								end

								if rawequal(ind, "_indexUpdated") then
									return metaRead(dataCache._indexUpdated:wrapConnect())
								end

								if rawequal(ind, "_encryptionEnabled") then
									return (playerData_EncryptData and true) or false
								end

								--if rawequal(ind, "_changed") then
								--	return metaRead(dataCache._changed:wrapConnect())
								--end

								if rawequal(ind, "_lastUpdated") then return dataCache.lastUpdated end

								if rawequal(ind, "_autoUpdate") then return dataCache._autoUpdate end

								if rawequal(ind, "_dataUpdate") then return dataCache._dataUpdate end

								if rawequal(ind, "_dataChanged") then return dataCache._dataChanged end

								if rawequal(ind, "_dataCorrupted") then return dataCache._dataCorrupted end

								if rawequal(ind, "_tableAdd") then -- TODO: Fix this with many entries
									return metaFunc(function(ind, val)
										assert(
											type(ind) == "string" or type(ind) == "number",
											"Index must be a string or number"
										)

										if
											not table.find({ "nil", "string", "number", "table", "boolean" }, type(val))
										then
											error("Value must be compatible (nil/string/number/table/boolean)", 0)
											return
										end

										local dataTab = rawget(dataCache.specialTable, ind)

										if type(dataTab) == "table" then
											local canDataReadAndWrite = dataCache._dataUpdate

											if canDataReadAndWrite then
												table.insert(dataCache._pendingTableAddChanges, {
													tab = ind,
													--ind = #dataTab+1;
													value = val,
												})
												--table.insert(dataTab, val)
												dataCache._dataChanged = true
											else
												table.insert(dataTab, val)

												if dataCache._metaTables[ind] then
													local metaTableForIndexedData = dataCache._metaTables[ind]
													table.insert(metaTableForIndexedData._table, val)
												end

												dataCache._indexUpdated:fire(ind)
											end
										else
											warn("can't update data tab?", ind, dataTab)
										end
									end, true)
								end

								if rawequal(ind, "_tableAddToSet") then
									return metaFunc(function(ind, val)
										assert(
											type(ind) == "string" or type(ind) == "number",
											"Index must be a string or number"
										)

										if
											not table.find({ "nil", "string", "number", "table", "boolean" }, type(val))
										then
											error("Value must be compatible (nil/string/number/table/boolean)", 0)
											return
										end

										local dataTab = rawget(dataCache.specialTable, ind)

										if type(dataTab) == "table" then
											local canDataReadAndWrite = dataCache._dataUpdate

											if canDataReadAndWrite then
												table.insert(dataCache._pendingTableAddChanges, {
													tab = ind,
													--ind = #dataTab+1;
													value = val,
													onlyIfItNotExists = true,
												})
												--table.insert(dataTab, val)
												dataCache._dataChanged = true
											else
												local filterList
												filterList = function()
													for i, v in ipairs(dataTab) do
														if checkEquality(v, val) then
															table.remove(dataTab, i)
															filterList()
														end
													end
												end

												filterList()
												table.insert(dataTab, val)

												if dataCache._metaTables[ind] then
													local metaTableForIndexedData = dataCache._metaTables[ind]
													table.insert(metaTableForIndexedData._table, val)
												end

												dataCache._indexUpdated:fire(ind)
											end
										end
									end, true)
								end

								if rawequal(ind, "_tableRemove") then
									return metaFunc(function(ind, val)
										assert(
											type(ind) == "string" or type(ind) == "number",
											"Index must be a string or number"
										)

										if
											not table.find({ "nil", "string", "number", "table", "boolean" }, type(val))
										then
											error("Value must be compatible (nil/string/number/table/boolean)", 0)
											return
										end

										local dataTab = rawget(dataCache.specialTable, ind)

										if type(dataTab) == "table" then
											local canDataReadAndWrite = dataCache._dataUpdate

											if canDataReadAndWrite then
												table.insert(dataCache._pendingTableRemoveChanges, {
													tab = ind,
													value = val,
												})

												--for i,v in pairs(dataTab) do
												--	if checkEquality(v, val) then
												--		rawset(dataTab, i, nil)
												--	end
												--end

												dataCache._dataChanged = true
											else
												for ind, indVal in pairs(dataTab) do
													if checkEquality(indVal, val) then rawset(dataTab, ind, nil) end
												end

												if dataCache._metaTables[ind] then
													local metaTableForIndexedData = dataCache._metaTables[ind]
													for ind, indVal in pairs(metaTableForIndexedData._table) do
														if checkEquality(indVal, val) then
															rawset(metaTableForIndexedData._table, ind, nil)
														end
													end
												end

												dataCache._indexUpdated:fire(ind)
											end
										end
									end, true)
								end

								if rawequal(ind, "_listenIndexChangedEvent") then
									return metaFunc(function(focusedIndex: string | number, callback: FunctionalTest)
										assert(
											type(focusedIndex) == "string" or type(focusedIndex) == "number",
											"Index must be a string or number"
										)
										assert(type(callback) == "function", "Callback must be a function")

										local listenSignal = Signal.new()
										local listenLink = listenSignal:connect(callback)
										listenLink.debugError = true
										local dataCacheLink
										local oDisconnect = listenLink.disconnect
										function listenLink:disconnect(...)
											dataCacheLink:disconnect()
											return oDisconnect(self, ...)
										end
										listenLink.Disconnect = listenLink.disconnect

										dataCacheLink = dataCache._indexUpdated:connect(function(changedIndex)
											if changedIndex == focusedIndex then
												local indexValue = rawget(dataCache.specialTable, focusedIndex)
												if type(indexValue) == "table" then
													indexValue = cloneTable(indexValue)
												end

												listenSignal:fire(indexValue)
											end
										end)

										return listenLink
									end, true)
								end

								if rawequal(ind, "_updateIfDead") then
									return metaFunc(function()
										if dataCache._dataUpdate and not dataCache._autoUpdate then
											dataCache._autoUpdate = true
											dataCache.update()
										end
									end, true)
								end

								if rawequal(ind, "_forceUpdate") then
									return metaFunc(function()
										if dataCache._dataUpdate then dataCache.update(true) end
									end, true)
								end

								--if rawequal(ind, "_toggleAutoUpdate") then
								--	return metaFunc(function(bool)
								--		assert(type(bool)=="boolean", "Argument 1 must be a boolean value")

								--		if dataCache._dataUpdate then
								--			dataCache._autoUpdate = bool
								--		end
								--	end, true)
								--end

								if rawequal(ind, "_table") then return dataCache.specialTable end

								local useMetaTable = tostring(ind):sub(1, 2) == "__" and ind ~= "__"

								if useMetaTable then ind = ind:sub(3) end

								local itemSelect = rawget(dataCache.specialTable, ind)

								if type(itemSelect) == "table" then
									if not useMetaTable then
										return cloneTable(itemSelect)
									else
										if dataCache._metaTables[ind] then
											return dataCache._metaTables[ind]._specialProxy
										end

										local blacklistedInds = { "_reviveIfDead", "_recognize", "_updated" }
										local tableFunctions =
											{ "find", "insert", "remove", "concat", "sort", "isfrozen" }
										local metaTabInfo
										metaTabInfo = {
											loopId = "PlayerData_" .. userId .. "_Table-" .. getRandom(),
											alive = false,
											lastAlive = nil,
											lastModified = tick(),
											_didModify = false,
											_reviving = false,

											_specialProxy = service.newProxy {
												__index = function(self, targetInd)
													if
														type(targetInd) == "string"
														and targetInd:sub(1, 1) == "_"
														and table.find(tableFunctions, targetInd:sub(2))
													then
														return metaFunc(function(...)
															local tableIndex = targetInd:sub(2)
															local results =
																table.pack(table[tableIndex](metaTabInfo._table, ...))

															return unpack(results)
														end, true)
													end

													if rawequal(targetInd, "_push") then
														return metaFunc(function(...)
															local tableAdd = dataCache.specialProxy._tableAdd
															for i, arg in { ... } do
																tableAdd(ind, arg)
															end
														end, true)
													end

													if rawequal(targetInd, "_pushToSet") then
														return metaFunc(function(...)
															local tableAdd = dataCache.specialProxy._tableAddToSet
															for i, arg in { ... } do
																tableAdd(ind, arg)
															end
														end, true)
													end

													if rawequal(targetInd, "_pull") then
														return metaFunc(function(...)
															local tableRemove = dataCache.specialProxy._tableRemove
															for i, arg in ipairs(table.pack(...)) do
																tableRemove(ind, arg)
															end
														end, true)
													end

													if rawequal(targetInd, "_table") then return metaTabInfo._table end

													if rawequal(targetInd, "_updated") then
														return metaRead(metaTabInfo._updated:wrapConnect())
													end

													if rawequal(targetInd, "_reviveIfDead") then
														return metaFunc(function()
															if not metaTabInfo._reviving then
																metaTabInfo._reviving = true

																if not metaTabInfo.alive then
																	metaTabInfo:startAlive()
																end

																if not dataCache._autoUpdate then
																	dataCache._autoUpdate = true
																	dataCache.update()
																end

																metaTabInfo._reviving = false
															end
														end, true)
													end

													if rawequal(targetInd, "_recognize") then
														return metaFunc(function()
															if not metaTabInfo._didModify then
																local realItem = rawget(dataCache.specialTable, ind)

																if type(realItem) == "table" then
																	local isDifferent =
																		not checkEquality(realItem, metaTabInfo._table)

																	if isDifferent then
																		metaTabInfo.lastModified = tick()

																		if dataCache._dataUpdate then
																			metaTabInfo._didModify = true
																			dataCache._dataChanged = true

																			for realItemInd, realItemVal in
																				pairs(realItem)
																			do
																				local metaTabVal =
																					metaTabInfo._table[realItemInd]
																				if
																					not checkEquality(
																						metaTabVal,
																						realItemVal
																					)
																				then
																					if rawequal(metaTabVal, nil) then
																						if
																							not dataCache._pendingTableIndexRemovalChanges[ind]
																						then
																							dataCache._pendingTableIndexRemovalChanges[ind] =
																								{}
																						end

																						dataCache._pendingTableIndexRemovalChanges[ind][realItemInd] =
																							true
																					else
																						if
																							not dataCache._pendingTableIndexOverwriteChanges[ind]
																						then
																							dataCache._pendingTableIndexOverwriteChanges[ind] =
																								{}
																						end

																						dataCache._pendingTableIndexOverwriteChanges[ind][realItemInd] =
																							metaTabVal
																					end
																				end
																			end
																		end
																	end
																end
															end
														end, true)
													end

													return metaTabInfo._table[targetInd]
												end,

												__newindex = function(self, targetInd, targetVal)
													if not table.find({ "string", "number" }, type(targetInd)) then
														error("Invalid index (string/number expected)", 0)
													end

													local strIndex = tostring(targetInd)
													if
														table.find(blacklistedInds, strIndex)
														or (
															strIndex:sub(1, 1) == "_"
															and table.find(tableFunctions, strIndex:sub(2))
														)
													then
														error("Blacklisted index.", 0)
													end

													local oldVal = rawget(metaTabInfo._table, targetInd)
													if checkEquality(oldVal, targetVal) then return end

													--warn("PData", userId, "metaTable", ind, "modified", targetInd, "->", targetVal, "<-", oldVal)
													metaTabInfo.lastModified = tick()

													if dataCache._dataUpdate then
														metaTabInfo._didModify = true
														if rawequal(targetVal, nil) then
															if not dataCache._pendingTableIndexRemovalChanges[ind] then
																dataCache._pendingTableIndexRemovalChanges[ind] = {}
															end
															dataCache._pendingTableIndexRemovalChanges[ind][targetInd] =
																true
														else
															if
																not dataCache._pendingTableIndexOverwriteChanges[ind]
															then
																dataCache._pendingTableIndexOverwriteChanges[ind] = {}
															end

															dataCache._pendingTableIndexOverwriteChanges[ind][targetInd] =
																targetVal
														end
													end

													rawset(metaTabInfo._table, targetInd, targetVal)
													--warn("Overwritten value:", metaTabInfo._table[targetInd])
												end,

												__iter = function(self) return pairs, metaTabInfo._table end,

												__len = function(self) return #metaTabInfo._table end,

												__tostring = function()
													return "ProxyDataTable_"
														.. tostring(ind)
														.. "-PlayerData_"
														.. userId
												end,
												__metatable = "ProxyDataTable_"
													.. tostring(ind)
													.. "-PlayerData_"
													.. userId,
											},

											_table = setmetatable(cloneTable(itemSelect), {
												__index = function(self, ind)
													local realTableIndex = rawget(dataCache.specialTable, ind)
													if type(realTableIndex) == "table" then
														return realTableIndex[ind]
													end

													return nil
												end,

												__tostring = function()
													return "DataTable_" .. tostring(ind) .. "-PlayerData_" .. userId
												end,
												__metatable = "DataTable_" .. tostring(ind) .. "-PlayerData_" .. userId,
											}),

											startAlive = function(self)
												if not self.alive and not table.isfrozen(self._table) then
													self.alive = true
													self.lastAlive = os.time()
													--warn("Table "..ind.." is now alive")

													stopLoop(self.loopId)

													local idleTimeout = 60
													loopTask(metaTabInfo.loopId, idleTimeout, function()
														if
															(tick() - metaTabInfo.lastModified >= idleTimeout)
															and not metaTabInfo._didModify
														then
															metaTabInfo:stopAlive()
															--warn("Table "..ind.." dead after not finding any new overwrites")
														end
													end)

													self.updateEvent = dataCache._indexUpdated:connect(
														function(updIndex)
															if updIndex == ind then
																self._didModify = false

																local updTable = rawget(dataCache.specialTable, ind)
																if type(updTable) == "table" then
																	if not next(updTable) then
																		for i, v in pairs(self._table) do
																			rawset(self._table, i, nil)
																		end
																	else
																		for i, v in pairs(updTable) do
																			if
																				not table.find(blacklistedInds, i)
																				and not checkEquality(v, self._table[i])
																			then
																				rawset(self._table, i, v)
																			end
																		end
																	end
																end

																self._updated:fire(true)
															end
														end
													)
												end
											end,

											stopAlive = function(self)
												if self.alive then
													self.alive = false
													stopLoop(self.loopId)

													if self.updateEvent then
														self.updateEvent:disconnect()
														self.updateEvent = nil
													end
												end
											end,

											_updated = Signal.new(),
										}

										dataCache._metaTables[ind] = metaTabInfo
										metaTabInfo:startAlive()

										return metaTabInfo._specialProxy
									end
								else
									return itemSelect
								end
							end,

							__newindex = function(self, ind, val)
								if not table.find({ "string", "number" }, type(ind)) then
									error("Not allowed to overwrite with an incompatible index", 0)
									return
								end

								if not table.find({ "nil", "string", "number", "table", "boolean" }, type(val)) then
									error("Not allowed to overwrite with an incompatible value", 0)
									return
								end

								if table.find(bannedIndexes, ind) then
									error("Not allowed to overWrite index " .. tostring(ind) .. " in player data", 0)
									return
								end

								if dataCache._dataUpdate then
									if type(val) == "table" then val = cloneTable(val) end

									if rawequal(val, nil) then
										dataCache._removingChanges[ind] = true
										rawset(dataCache.specialTable, ind, nil)
									else
										if dataCache._removingChanges[ind] then
											dataCache._removingChanges[ind] = nil
										end

										dataCache._waitingChanges[ind] = val
										rawset(dataCache.specialTable, ind, val)
									end
									dataCache._dataChanged = true
								else
									rawset(dataCache.specialTable, ind, val)

									if dataCache._metaTables[ind] and (type(val) == "table" or type(val) == "nil") then
										local metaTableForIndexedData = dataCache._metaTables[ind]
										table.clear(metaTableForIndexedData._table)

										if type(val) == "table" then
											for subIndex, subValue in val do
												metaTableForIndexedData._table[subIndex] = subValue
											end
										end
									end

									dataCache._indexUpdated:fire(ind)
								end
							end,

							__tostring = function() return "PData_" .. userId end,
							__metatable = "PlayerData_" .. userId,
						},

						specialTable = setmetatable(service.cloneTable(defaultData), {
							__tostring = function() return "PData_" .. userId end,
							__metatable = "PlayerData_" .. userId,
						}),

						_removingChanges = {},
						_waitingChanges = {},
						_pendingTableAddChanges = {},
						_pendingTableRemoveChanges = {},
						_pendingTableIndexOverwriteChanges = {},
						_pendingTableIndexRemovalChanges = {},
						_oldTable = {},
						_metaTables = {},

						_dataLoadState = false,
						_dataLoaded = Signal.new(),
					}

					playerDataCache[userId] = dataCache

					local function updateData(override)
						local canOverwrite = false

						if dataCache._dataChanged or override then
							for waitChanInd, waitChanVal in pairs(dataCache._waitingChanges) do
								canOverwrite = true
								break
							end

							for waitChanInd, _ in pairs(dataCache._removingChanges) do
								canOverwrite = true
								break
							end

							for i, waitChan in pairs(dataCache._pendingTableAddChanges) do
								canOverwrite = true
								break
							end

							for i, waitChan in pairs(dataCache._pendingTableRemoveChanges) do
								canOverwrite = true
								break
							end

							for i, waitChan in pairs(dataCache._pendingTableIndexOverwriteChanges) do
								canOverwrite = true
								break
							end

							for i, waitChan in pairs(dataCache._pendingTableIndexRemovalChanges) do
								canOverwrite = true
								break
							end

							if not checkEquality(dataCache._oldTable, dataCache.specialTable) then
								canOverwrite = true
							end
						end

						if (not dataCache._updating and canOverwrite) or override then
							dataCache._updating = true
							local curProcessId = getRandom()
							dataCache._updateProcessId = curProcessId
							dataCache._dataChanged = false

							local writeDatastore = Datastore.getDatastore(dataAccessKey)
							local received = Signal.new()

							service.threadTask(function()
								if not override then wait(Datastore.getRequestDelay "update") end

								local updateId
								local updateIndexChecklist = {
									_removingChanges = {},
									_waitingChanges = {},
								}
								local updateTableInsertCheckList = {
									_pendingTableAddChanges = {},
									_pendingTableRemoveChanges = {},
								}
								local updateTableIndexCheckList = {
									_pendingTableIndexOverwriteChanges = {},
									_pendingTableIndexRemovalChanges = {},
								}

								local function pushToTable(tab: { [any]: any }, value: any): nil
									if not table.find(tab, value) then table.insert(tab, value) end
								end

								local function resetUpdateTables()
									-- Data index checklist is a list of indexes valued with the value they overwrote the data
									-- The data cache update table contents are compared with the checklist contents and automatically remove
									-- the values that were already written from the changes table
									for tableCheck, checkList in pairs(updateIndexChecklist) do
										local updateIndexes: { [string]: { [string]: any } } = dataCache[tableCheck] -- List of indexes

										for index, val in pairs(updateIndexes) do
											local expectedVal = checkList[index]
											if index == "_removingChanges" then expectedVal = nil end

											if checkList[index] == expectedVal then updateIndexes[index] = nil end
										end
									end

									for tableCheck, checkList in pairs(updateTableInsertCheckList) do
										local updateIndexes: { [number]: {} } = dataCache[tableCheck] -- List of indexes

										local didFinishIterating
										repeat
											didFinishIterating = true

											for index, updateChange in ipairs(updateIndexes) do
												if updateId and updateChange.dataUpdateId == updateId then
													table.remove(updateIndexes, index)
													didFinishIterating = false
													break
												end
											end
										until didFinishIterating
									end

									-- Table index checklist is a list of tables with the overwritten indexes
									-- To ensure that the indexes were overwritten from these tables, they are compared to the data cache contents
									for tableCheck, checkList in pairs(updateTableIndexCheckList) do
										local dataCacheUpdateTable: { [string]: { [string]: any } } =
											dataCache[tableCheck] -- List of tables with overwritten indexes

										for dataIndex, existingVal in pairs(dataCacheUpdateTable) do
											local didCheck = false
											local checkVal = checkList[dataIndex]
											if tableCheck == "_pendingTableIndexRemovalChanges" then checkVal = nil end

											if checkEquality(existingVal, checkVal) then
												didCheck = true
												dataCacheUpdateTable[dataIndex] = nil
												--warn("Successfully compared data index")
											else
												--warn("Failed to compare data index")
												--warn("Existing val:", existingVal)
												--warn("Check val:", checkVal)
											end

											--if not next(subIndexesWithVals) then
											--	dataCacheUpdateTable[dataIndex] = nil
											--end
										end
									end

									--local mergedChecklist = service.mergeTables(false, updateIndexChecklist, updateTableInsertCheckList, updateTableIndexCheckList)
									--warn("Checklist:", mergedChecklist)
									--local mockDataCache = {}
									--for i, v in pairs(mergedChecklist) do
									--	mockDataCache[i] = dataCache[i]
									--end
									--warn("Data cache:", mockDataCache)
								end

								local function updateCallback(oldData)
									local realOldData = oldData
									local canCompress = datastoreUseCompression and not playerData_EncryptData

									if canCompress then
										if type(oldData) == "string" then
											oldData = base64Decode(oldData)
											oldData = compression.Deflate.Decompress(oldData, Datastore.compressConfig)
											oldData = luaParser.Decode(oldData)[1]
										else
											oldData = nil
										end
										realOldData = oldData
									end

									if type(realOldData) == "table" then realOldData = cloneTable(realOldData) end

									updateId = getRandom()

									--if playerData_EncryptData then
									--	if type(oldData) ~= "string" then
									--		oldData = defaultPlayerData()
									--	else
									--		local decryptValue1 = base64Decode(oldData)
									--		local decryptValue2 = tulirAES.decrypt(encryptKey, decryptValue1)
									--		local decryptValue3 = decryptValue2 and luaParser.Decode(decryptValue2)

									--		if type(decryptValue3) ~= "table" then
									--			oldData = defaultPlayerData()
									--		else
									--			oldData = decryptValue3
									--		end
									--	end
									--else
									if type(oldData) ~= "table" then
										oldData = defaultPlayerData()
									else
										local defData = defaultPlayerData()
										for i, v in pairs(defData) do
											if type(oldData[i]) ~= type(v) then oldData[i] = v end
										end
									end
									--end

									local indexUpdateCheckList = {}

									if canOverwrite or override then
										for waitChanInd, waitChanVal in pairs(dataCache._waitingChanges) do
											oldData[waitChanInd] = waitChanVal
											updateIndexChecklist._waitingChanges[waitChanInd] = waitChanVal
											--dataCache._waitingChanges[waitChanInd] = nil
										end

										for waitChanInd, _ in pairs(dataCache._removingChanges) do
											oldData[waitChanInd] = nil
											updateIndexChecklist._removingChanges[waitChanInd] = true
											--dataCache._removingChanges[waitChanInd] = nil
										end

										-- TABLE REMOVE GOES FIRST THEN TABLE ADD
										for i, waitChan in pairs(dataCache._pendingTableRemoveChanges) do
											local tab, val = waitChan.tab, waitChan.value

											local oldTabVal = oldData[tab]
											if type(oldTabVal) == "table" then
												local didUpdate = false

												for oldTabValInd, oldTabValVal in pairs(oldTabVal) do
													if checkEquality(oldTabValVal, val) then
														didUpdate = true
														oldTabVal[oldTabValInd] = nil
													end
												end

												local specTabVal = rawget(dataCache.specialTable, tab)
												if type(specTabVal) == "table" then
													for specTabValInd, specTabValVal in pairs(specTabVal) do
														if checkEquality(specTabValVal, val) then
															didUpdate = true
															rawset(specTabVal, specTabValInd, nil)
														end
													end
												end

												if didUpdate then
													indexUpdateCheckList[tab] = true
													pushToTable(
														updateTableInsertCheckList._pendingTableRemoveChanges,
														waitChan
													)
												end

												waitChan.dataUpdateId = updateId
											end

											--warn("Datastore TableRemove applied in player data "..userId)

											--dataCache._pendingTableRemoveChanges[i] = nil
										end

										for i, waitChan in pairs(dataCache._pendingTableAddChanges) do
											local tab, addInd, val, onlyIfItNotExists =
												waitChan.tab, waitChan.ind, waitChan.value, waitChan.onlyIfItNotExists

											local oldTabVal = oldData[tab]
											if type(oldTabVal) ~= "table" then
												oldTabVal = {}
												rawset(oldData, tab, oldTabVal)
											end

											--warn(`TABLE ADD CHANGE FOUND`, waitChan)

											--if not checkEquality(addInd, oldTabVal[addInd]) then
											--	oldTabVal[addInd] = val
											--end

											--rawset(dataCache.specialTable, #oldTabVal+1, val)
											if not onlyIfItNotExists then
												table.insert(oldTabVal, val)
												pushToTable(
													updateTableInsertCheckList._pendingTableAddChanges,
													waitChan
												)
											else
												local canPushToTable = (function()
													for tabInd, tabVal in pairs(oldTabVal) do
														if checkEquality(tabVal, val) then return false end
													end

													return true
												end)()

												--warn("Checking push allow for table "..tab)
												--warn("Can push to table:", canPushToTable)
												--warn("Value:", val)
												--warn("Table:", oldTabVal)
												if canPushToTable then
													table.insert(oldTabVal, val)
													pushToTable(
														updateTableInsertCheckList._pendingTableAddChanges,
														waitChan
													)
												end
												--warn("Now table:", oldTabVal)
											end

											indexUpdateCheckList[tab] = true
											--warn("Datastore TableAdd applied in player data "..userId)

											waitChan.dataUpdateId = updateId
											--dataCache._pendingTableAddChanges[i] = nil
										end

										for tabInd, indList in pairs(dataCache._pendingTableIndexRemovalChanges) do
											if type(oldData[tabInd]) == "table" then
												local checkIndList =
													updateTableIndexCheckList._pendingTableIndexRemovalChanges[tabInd]
												if not checkIndList then
													checkIndList = {}
													updateTableIndexCheckList._pendingTableIndexRemovalChanges[tabInd] =
														checkIndList
												end

												for ind, val in pairs(indList) do
													checkIndList[ind] = true
													oldData[tabInd][ind] = nil
												end

												indexUpdateCheckList[tabInd] = true
											end

											dataCache._pendingTableIndexRemovalChanges[tabInd] = nil
										end

										for tabInd, indList in pairs(dataCache._pendingTableIndexOverwriteChanges) do
											if type(oldData[tabInd]) == "table" then
												local checkIndList =
													updateTableIndexCheckList._pendingTableIndexOverwriteChanges[tabInd]
												if not checkIndList then
													checkIndList = {}
													updateTableIndexCheckList._pendingTableIndexOverwriteChanges[tabInd] =
														checkIndList
												end

												for ind, val in pairs(indList) do
													checkIndList[ind] = val
													oldData[tabInd][ind] = val
												end

												indexUpdateCheckList[tabInd] = true
											end

											--updateTableIndexCheckList._pendingTableIndexOverwriteChanges[tabInd] = indList
											--dataCache._pendingTableIndexOverwriteChanges[tabInd] = nil
										end

										Logs.addLog("Process", "Applied overwrite changes for pData " .. userId)
									end

									for ind, val in pairs(oldData) do
										local specTabVal = rawget(dataCache.specialTable, ind)
										local equality = checkEquality(specTabVal, val)

										if not table.find(bannedIndexes, ind) and not equality then
											rawset(dataCache.specialTable, ind, val)
											indexUpdateCheckList[ind] = true

											if type(val) == "table" then
												local metaTabSets = metaIndexSettings[ind] or {}
												local metaTabMaxEntries = metaTabSets.maxEntries or 0

												local isTableInNumericOrder = #val == service.tableCount(val)

												if isTableInNumericOrder then
													if
														metaTabMaxEntries > 0
														and #val > 0
														and #val > metaTabMaxEntries
													then
														repeat
															table.remove(val, 1)
														until #val <= metaTabMaxEntries
													end
												end
											end
										end
									end

									for index, stat in pairs(indexUpdateCheckList) do
										if dataCache._metaTables[index] and type(oldData[index]) == "table" then
											local dataMetaTable = dataCache._metaTables[index]
											local dataMetaSpecTable = dataMetaTable._table
											task.defer(dataMetaTable.startAlive, dataMetaTable)

											for i, v in pairs(dataMetaSpecTable) do
												rawset(dataMetaSpecTable, i, nil)
											end

											for i, v in pairs(oldData[index]) do
												rawset(dataMetaSpecTable, i, v)
											end
										end

										dataCache._indexUpdated:fire(index)
									end

									for _, banIndex in pairs(bannedIndexes) do
										rawset(dataCache.specialTable, banIndex, nil)
									end

									dataCache._oldTable = cloneTable(dataCache.specialTable)
									dataCache._updated:fire()

									dataCache.lastUpdated = os.time()

									--if playerData_EncryptData then
									--	local encryptedValue1 = luaParser.Encode(oldData)
									--	local encryptedValue2 = tulirAES.encrypt(encryptKey, encryptedValue1)
									--	local encryptedValue3 = base64Encode(encryptedValue2)
									--	oldData = encryptedValue3
									--end

									--Logs.addLog("Process", "Updated pData "..userId)

									--warn("Updated data "..userId)
									--warn("Previous data:", realOldData)
									--warn("Current data:", oldData)

									if canCompress then
										oldData = luaParser.Encode { oldData }
										oldData = compression.Deflate.Compress(oldData, Datastore.compressConfig)
										oldData = base64Encode(oldData)
									end

									received:fire(true)
									resetUpdateTables()

									return oldData
								end

								if playerData_EncryptData then
									Datastore.encryptUpdate(dataAccessKey, originalDataKey, encryptKey, updateCallback)
								else
									for i = 1, 3 do
										local suc, err = pcall(
											writeDatastore.UpdateAsync,
											writeDatastore,
											hashedDataKey,
											updateCallback
										)
										if not suc and err and string.match(err, "Callbacks cannot yield") then
											warn(
												"Failed to save player data "
													.. userId
													.. " due to update callback yielding"
											)
											break
										elseif not suc then
											if server.Studio then
												warn("FAILED TO UPDATE PLAYER DATA DUE TO ERROR:", err)
											end
											wait(10)
										elseif suc then
											break
										end
									end
								end
							end)

							local didReceive = received:wait(nil, 90 + (playerData_EncryptData and 20 or 0))

							if not didReceive then
								dataCache._saveError:fire()
								dataCache._dataCorrupted = true
								server.Events.playerDataSaveError:fire(userId, dataCache.specialProxy)
							else
								-- SUCCESS STATEMENT
								if dataCache._dataCorrupted then
									dataCache._dataCorrupted = false
									dataCache._saveSuccess:fire()
								end

								-- Update player data policies
								do
									local ingamePlayer = service.getPlayer(userId)

									if ingamePlayer then
										local parsedPlayer = Parser:apifyPlayer(ingamePlayer)
										if parsedPlayer then
											task.defer(
												server.PolicyManager._updatePlayerDataClientPolicies,
												server.PolicyManager,
												parsedPlayer
											)
										end
									end
								end
							end

							if dataCache._updateProcessId == curProcessId then
								dataCache._updating = false
								dataCache._dataChanged = false
							end
						end
					end
					dataCache.update = updateData
					-- dataCache.startAutoLoop = function()
					-- 	if dataCache.autoLooped then return end
					-- 	dataCache.autoLooped = true
					-- end

					local updateTaskId = service.getRandom() .. "_UPDATE-DATA_" .. userId
					local checkLoopSeconds = 30

					--warn(`DATASTORE CANREAD: {Datastore.canRead()} | DATASTORE CANWRITE: {Datastore.canWrite()} | PDATASTORE ENABLED: {playerDataStoreEnabled}`)
					if
						datastore_Allow
						and playerDataStoreEnabled
						and (Datastore.canRead() and Datastore.canWrite())
						and userId > 0
					then
						loopTask(updateTaskId, checkLoopSeconds, function()
							if os.time() - dataCache.created < 5 or not server.Running then return end

							if dataCache._dataUpdate and dataCache._autoUpdate then
								local ingamePlayer = service.getPlayer(userId)

								if not ingamePlayer then dataCache._autoUpdate = false end

								--warn("Updating pData "..userId)
								local canCheckNewData = os.time() - dataCache.lastUpdated >= 60
								updateData(canCheckNewData)
							end
						end)

						server.Closing:connectOnce(function()
							service.stopLoop(updateTaskId)
							if dataCache._dataChanged then updateData(true) end
						end)
					else
						dataCache._dataUpdate = false
						dataCache._autoUpdate = false
					end

					-- Load in the existing data
					dataCache._loadingExistingData = Promise.promisify(function()
						local savedPData

						if userId > 0 then
							if playerData_EncryptData then
								savedPData = Datastore.encryptRead(dataAccessKey, originalDataKey, false, encryptKey)
									or defaultData
							else
								savedPData = Datastore.read(dataAccessKey, originalDataKey) or defaultData
							end
						end

						if type(savedPData) ~= "table" then savedPData = defaultData end

						for ind, val in pairs(defaultData) do
							if type(savedPData[ind]) ~= type(val) then
								savedPData[ind] = val
								dataCache.specialProxy[ind] = val
							end
						end

						for i, v in pairs(savedPData) do
							rawset(dataCache.specialTable, i, v)
						end

						dataCache._dataLoadState = true
						dataCache._dataLoaded:fire(true)
						dataCache._oldTable = cloneTable(dataCache.specialTable)
					end)()

					if not ignoreLoading then dataCache._loadingExistingData:await() end
				else
					if not dataCache._dataLoadState and not ignoreLoading then dataCache._dataLoaded:wait() end
				end

				return dataCache.specialProxy
			end
		end,

		savePlayerData = function(userId, pData)
			if type(userId) ~= "number" then return "Invalid_UserId" end

			if type(pData) ~= "table" then pData = Core.defaultPlayerData() end

			Datastore.overWrite(DS_PlayerData, tostring(userId), pData)
		end,

		loadSavedSettings = function(savedSets)
			local ignoreSettings = {
				Datastore_Allow = true,
				Datastore_Key = true,
				Datastore_PlayerData = true,

				BanList = true,
				allowSavedSettings = true,
			}

			for i, set in pairs(savedSets) do
				if type(set) == "table" then
					local typ = set.type

					if typ == "TableAdd" then
						local tab = set.Table or ""
						local value = set.Value
						local setting = (not ignoreSettings[tab] and settings[tab]) or nil
						local canAdd = (type(setting) == "table" and value) or false

						if canAdd then table.insert(setting, value) end
					end

					if typ == "TableRemove" then
						local tab = set.Table or ""
						local value = set.Value
						local setting = (not ignoreSettings[tab] and settings[tab]) or nil
						local canRemove = (type(setting) == "table") or false

						if canRemove then
							local index = table.find(setting, value)

							if index then table.remove(setting, index) end
						end
					end

					if typ == "TableSet" then
						local tab = set.Table or ""
						local index = set.Index
						local value = set.Value
						local setting = (not ignoreSettings[tab] and settings[tab]) or nil
						local canSet = (type(setting) == "table" and index and value) or false

						if canSet then setting[index] = value end
					end

					if typ == "TableClear" then
						local tab = set.Table or ""
						local setting = (not ignoreSettings[tab] and settings[tab]) or nil
						local canClear = (type(setting) == "table") or false

						if canClear then
							for i, v in pairs(setting) do
								rawset(setting, i, nil)
							end
						end
					end

					if typ == "Set" then
						local set = set.Setting
						local value = set.Value

						settings[set] = value
					end

					if typ == "Remove" then
						local set = set.Setting

						settings[set] = nil
					end
				end
			end
		end,

		resetPlayerData = function(userId)
			local defaultData = Core.defaultPlayerData()

			if DS_PlayerData then
				local key = tostring(userId)
				Datastore.write(DS_PlayerData, key, defaultData)
				Core.playerData[key] = defaultData
			end
		end,

		resetSavedSettings = function() end,

		resetSave = function() end,

		checkCommandUsability = function(player, cmd, ignoreCooldown, processData, ignorePermCheck)
			processData = processData or {}

			local disabled = cmd.Disabled
			local playerCooldown = tonumber(cmd.PlayerCooldown)
			local serverCooldown = tonumber(cmd.ServerCooldown)
			local crossCooldown = tonumber(cmd.CrossCooldown)
			local cmdPermissions = cmd.Permissions or {}
			local listedRoles = cmd.Roles or {}
			local whitelist = cmd.Whitelist or {}
			local blacklist = cmd.Blacklist or {}
			local conditionals = cmd.Conditionals or {}
			local socialMediaPolicies = cmd.SocialMediaPolicies or {}
			local playerDebounceEnabled = cmd.PlayerDebounce or cmd.Debounce or false
			local serverDebounceEnabled = cmd.ServerDebounce or false
			local crossCmdDisabled = cmd.CrossDisabled or cmd.CrossServerDenied
			local noPermissionsBypass = cmd.NoPermissionsBypass
			local noRepeatedUseInBatch = cmd.NoRepeatedUseInBatch
			local noRepeatedUseInLoop = cmd.NoRepeatedUseInLoop

			local canIgnoreNoPermissionsBypass = noPermissionsBypass and Roles:checkMemberInRoles(player, { "creator" })
			local globalBlacklist = variables.commandBlacklist or {}

			local cmdFullName = cmd._fullName
				or (function()
					local aliases = cmd.Aliases or cmd.Commands or {}
					cmd._fullName = cmd.Prefix .. (aliases[1] or service.getRandom() .. "-RANDOM_COMMAND")
					return cmd._fullName
				end)()

			local pCooldown_Cache = cmd._playerCooldownCache
				or (function()
					local tab = {}
					cmd._playerCooldownCache = tab
					return tab
				end)()

			local sCooldown_Cache = cmd._serverCooldownCache
				or (function()
					local tab = {}
					cmd._serverCooldownCache = tab
					return tab
				end)()

			local crossCooldown_Cache = cmd._crossCooldownCache
				or (function()
					local tab = {}
					cmd._crossCooldownCache = tab
					return tab
				end)()

			local playerDebounceCache = cmd._playerDebounceCache
				or (function()
					local cache = {}
					cmd._playerDebounceCache = cache
					return cache
				end)()

			local serverDebounceCache = cmd._serverDebounceCache
				or (function()
					local cache = {}
					cmd._serverDebounceCache = cache
					return cache
				end)()

			if disabled then
				return false, "Disabled"
			else
				if player then
					local serverAdmin = Moderation.checkAdmin(player)

					-- Command blacklist
					if Identity.checkTable(player, blacklist) and not serverAdmin then
						return false, "CommandBlacklist"
					end

					if Identity.checkTable(player, globalBlacklist) and not serverAdmin then
						return false, "GlobalBlacklist"
					end

					-- Global blacklist
					local playerData = Core.getPlayerData(player.UserId)
					if playerData and playerData.systemBlacklist then return false, "GlobalBlacklist" end

					-- Do the check validations
					local didPass, passType, passMissingRet = (function()
						if ignorePermCheck then return true, "IgnorePermCheck" end

						if serverAdmin and not noPermissionsBypass then return true, "Admin" end

						if whitelist and #whitelist > 0 and Identity.checkTable(player, whitelist) then
							return true, "Whitelist"
						end

						local rolesMatch, missingRoles = server.Roles:checkMemberInRoles(player, listedRoles, true)

						if rolesMatch then return true, "Roles" end

						local permsCheck, missingPerms = server.Roles:hasPermissionFromMember(player, cmdPermissions)

						if permsCheck then
							return true, "Permissions"
						elseif not permsCheck and #missingPerms > 0 then
							return false, "MissingPerms", missingPerms
						end

						if not rolesMatch and #missingPerms > 0 then return false, "MissingRoles", missingPerms end
					end)()

					if didPass then
						local cooldownIndex = tostring(player.UserId)
						local pCooldown_playerCache = pCooldown_Cache[cooldownIndex]
						local sCooldown_playerCache = sCooldown_Cache[cooldownIndex]

						if
							not ignoreCooldown
							and ((noPermissionsBypass and not canIgnoreNoPermissionsBypass) or not serverAdmin)
						then
							if playerCooldown and pCooldown_playerCache then
								local secsTillPass = os.clock() - pCooldown_playerCache
								local passCooldown = secsTillPass >= playerCooldown

								if not passCooldown then
									return false, "PlayerCooldown", math.floor(playerCooldown - secsTillPass)
								end
							end

							if serverCooldown and sCooldown_playerCache then
								local secsTillPass = os.clock() - sCooldown_playerCache
								local passCooldown = secsTillPass >= serverCooldown

								if not passCooldown then
									return false, "ServerCooldown", math.floor(serverCooldown - secsTillPass)
								end
							end

							if crossCooldown and player:isReal() then
								local playerData = Core.getPlayerData(player.UserId)
								local crossCooldown_Cache = playerData._crossCooldownCache
									or (function()
										local tab = {}
										playerData._crossCooldownCache = tab
										return tab
									end)()
								local crossCooldown_playerCache = crossCooldown_Cache[cmdFullName]

								if crossCooldown_playerCache then
									local secsTillPass = os.clock() - crossCooldown_playerCache
									local passCooldown = secsTillPass >= crossCooldown

									if not passCooldown then
										return false, "CrossCooldown", math.floor(crossCooldown - secsTillPass)
									end
								end
							end
						end

						if playerDebounceEnabled and playerDebounceCache[player.UserId] then
							return false, "PlayerDebounce"
						end

						if serverDebounceEnabled and serverDebounceCache[player.UserId] then
							return false, "ServerDebounce"
						end

						if
							(processData.chatted or processData.Chat)
							and (cmd.Chattable == false or cmd.NotChat or cmd.DisabledOnChat)
						then
							return false, "Chat"
						end

						if (processData.ranCross or processData.CrossServer) and crossCmdDisabled then
							return false, "Cross"
						end

						if socialMediaPolicies and #socialMediaPolicies > 0 then
							if processData.ranCross or processData.CrossServer then return false, "Cross" end

							if player:isReal() then
								local disallowedPolicies = {}

								for i, policy in socialMediaPolicies do
									if
										not player:isAllowedToUseSocialMedia(policy)
										and not table.find(disallowedPolicies, policy)
									then
										table.insert(disallowedPolicies, policy)
									end
								end

								if #disallowedPolicies > 0 then
									return false, "SocialMediaPoliciesDisallowed", disallowedPolicies
								end
							end
						end

						if noRepeatedUseInBatch then
							local ranPlayerCommands = processData._ranPlayerCommands
							if ranPlayerCommands and table.find(ranPlayerCommands, cmd.Id) then
								return false, "RanTwice"
							end
						end

						if noRepeatedUseInLoop and processData.loop then return false, "LoopDisallowed" end

						return didPass, passType
					else
						return didPass, passType, passMissingRet
					end
				else
					return true, "System"
				end
			end
		end,

		manageCommandUsability = function(player, cmd, usableType, usableValue)
			local playerCooldown = tonumber(cmd.PlayerCooldown)
			local serverCooldown = tonumber(cmd.ServerCooldown)
			local cmdPermissions = cmd.Permissions or {}
			local listedRoles = cmd.Roles or {}
			local blacklist = cmd.Blacklist or {}
			local playerDebounceEnabled = cmd.PlayerDebounce or cmd.Debounce or false
			local serverDebounceEnabled = cmd.ServerDebounce or false
			local executions = cmd.Executions or 0

			local cmdFullName = cmd._fullName
				or (function()
					local aliases = cmd.Aliases or cmd.Commands or {}
					cmd._fullName = cmd.Prefix .. (aliases[1] or service.getRandom() .. "-RANDOM_COMMAND")
					return cmd._fullName
				end)()

			local pCooldown_Cache = cmd._playerCooldownCache
				or (function()
					local tab = {}
					cmd._playerCooldownCache = tab
					return tab
				end)()

			local sCooldown_Cache = cmd._serverCooldownCache
				or (function()
					local tab = {}
					cmd._serverCooldownCache = tab
					return tab
				end)()

			local playerDebounceCache = cmd._playerDebounceCache
				or (function()
					local cache = {}
					cmd._playerDebounceCache = cache
					return cache
				end)()

			local serverDebounceCache = cmd._serverDebounceCache
				or (function()
					local cache = {}
					cmd._serverDebounceCache = cache
					return cache
				end)()

			local cooldownIndex = tostring(player.UserId)

			if usableType == "ResetPlayerCooldown" then
				pCooldown_Cache[cooldownIndex] = nil

				local playerData = Core.getPlayerData(player.UserId)
				local crossCooldown_Cache = playerData._crossCooldownCache
					or (function()
						local tab = {}
						playerData._crossCooldownCache = tab
						return tab
					end)()
				local crossCooldown_playerCache = crossCooldown_Cache[cmdFullName]

				if crossCooldown_playerCache then crossCooldown_Cache[cmdFullName] = nil end
			elseif usableType == "ResetServerCooldown" then
				sCooldown_Cache[cooldownIndex] = nil
			elseif usableType == "ResetCooldown" then
				pCooldown_Cache[cooldownIndex] = nil
				sCooldown_Cache[cooldownIndex] = nil
			end
		end,

		trackCommandStartUsability = function(player, cmd, data)
			local disabled = cmd.Disabled
			local playerCooldown = tonumber(cmd.PlayerCooldown)
			local serverCooldown = tonumber(cmd.ServerCooldown)
			local crossCooldown = tonumber(cmd.CrossCooldown)
			local cmdPermissions = cmd.Permissions or {}
			local listedRoles = cmd.Roles or {}
			local blacklist = cmd.Blacklist or {}
			local playerDebounceEnabled = cmd.PlayerDebounce or cmd.Debounce or false
			local serverDebounceEnabled = cmd.ServerDebounce or false
			local executions = cmd.Executions or 0

			local cmdFullName = cmd._fullName
				or (function()
					local aliases = cmd.Aliases or cmd.Commands or {}
					cmd._fullName = cmd.Prefix .. (aliases[1] or service.getRandom() .. "-RANDOM_COMMAND")
					return cmd._fullName
				end)()

			local pCooldown_Cache = cmd._playerCooldownCache
				or (function()
					local tab = {}
					cmd._playerCooldownCache = tab
					return tab
				end)()

			local sCooldown_Cache = cmd._serverCooldownCache
				or (function()
					local tab = {}
					cmd._serverCooldownCache = tab
					return tab
				end)()

			local playerDebounceCache = cmd._playerDebounceCache
				or (function()
					local cache = {}
					cmd._playerDebounceCache = cache
					return cache
				end)()

			local serverDebounceCache = cmd._serverDebounceCache
				or (function()
					local cache = {}
					cmd._serverDebounceCache = cache
					return cache
				end)()

			-- If the player is a a server administrator or blacklisted, don't track usability
			--if server.Moderation.checkAdmin(player) then
			--	return false
			--end

			-- Cache when the user last used
			local cacheIndex = tostring(player.UserId)
			local lastUsed = os.clock()

			if playerCooldown then pCooldown_Cache[cacheIndex] = lastUsed end

			if serverCooldown then sCooldown_Cache[cacheIndex] = lastUsed end

			if player:isReal() then
				local playerData = Core.getPlayerData(player.UserId)
				local crossCooldown_Cache = playerData._crossCooldownCache or {}
				local crossCooldown_playerCache = crossCooldown_Cache[cmdFullName]

				if not crossCooldown and crossCooldown_playerCache then
					crossCooldown_playerCache[cmdFullName] = nil
				elseif crossCooldown then
					crossCooldown_Cache[cmdFullName] = lastUsed
				end
			end

			if playerDebounceEnabled and player:isReal() then playerDebounceCache[player.UserId] = true end

			if serverDebounceEnabled and player:isReal() then serverDebounceCache[player.UserId] = true end

			executions += 1
			cmd.Executions = executions

			if data._ranPlayerCommands then table.insert(data._ranPlayerCommands, cmd.Id) end
		end,

		trackCommandEndUsability = function(player, cmd, data)
			local disabled = cmd.Disabled
			local playerCooldown = tonumber(cmd.PlayerCooldown)
			local serverCooldown = tonumber(cmd.ServerCooldown)
			local crossCooldown = tonumber(cmd.CrossCooldown)
			local playerDebounceEnabled = cmd.PlayerDebounce or cmd.Debounce or false
			local serverDebounceEnabled = cmd.ServerDebounce or false

			local cmdFullName = cmd._fullName
				or (function()
					local aliases = cmd.Aliases or cmd.Commands or {}
					cmd._fullName = cmd.Prefix .. (aliases[1] or service.getRandom() .. "-RANDOM_COMMAND")
					return cmd._fullName
				end)()

			local pCooldown_Cache = cmd._playerCooldownCache
				or (function()
					local tab = {}
					cmd._playerCooldownCache = tab
					return tab
				end)()

			local sCooldown_Cache = cmd._serverCooldownCache
				or (function()
					local tab = {}
					cmd._serverCooldownCache = tab
					return tab
				end)()

			local playerDebounceCache = cmd._playerDebounceCache
				or (function()
					local cache = {}
					cmd._playerDebounceCache = cache
					return cache
				end)()

			local serverDebounceCache = cmd._serverDebounceCache
				or (function()
					local cache = {}
					cmd._serverDebounceCache = cache
					return cache
				end)()

			-- If the player is a a server administrator or blacklisted, don't track usability
			--if server.Moderation.checkAdmin(player) then
			--	return false
			--end

			-- Cache when the user last used
			local cacheIndex = tostring(player.UserId)
			local lastUsed = os.clock()

			if (playerDebounceEnabled or serverDebounceEnabled) and player:isReal() then
				playerDebounceCache[player.UserId] = nil
				serverDebounceCache[player.UserId] = nil

				if playerCooldown then pCooldown_Cache[cacheIndex] = lastUsed end

				if serverCooldown then sCooldown_Cache[cacheIndex] = lastUsed end

				if crossCooldown and player:isReal() then
					local playerData = Core.getPlayerData(player.UserId)
					local crossCooldown_Cache = playerData._crossCooldownCache
						or (function()
							local tab = {}
							playerData._crossCooldownCache = tab
							return tab
						end)()

					crossCooldown_Cache[cmdFullName] = lastUsed
				end
			end

			return true
		end,

		executeCommand = function(plr, command, suppliedArgs)
			local cmdMatch
			local cmdType = type(command)

			if cmdType == "table" then
				cmdMatch = command.Prefix .. tostring(command.Aliases[1])
			elseif cmdType == "string" then
				command, cmdMatch = Commands.get(command)
			end

			plr = (
				type(plr) == "string"
				and Parser:apifyPlayer({
					Name = plr,
					UserId = service.playerIdFromName(plr) or 0,
				}, true)
			)
				or (typeof(plr) == "Instance" and plr:IsA "Player" and Parser:apifyPlayer(plr))
				or plr

			suppliedArgs = (type(suppliedArgs) == "string" and Parser:getArguments(suppliedArgs, settings.delimiter))
				or (type(suppliedArgs) == "table" and suppliedArgs)
				or suppliedArgs

			if command then
				local cmdName = server.Commands.getName(command) or tostring(command)
				local cmdArgs = command.Args or command.Arguments or {}
				local parsedArgs, missingArg, missingArgType =
					Parser:filterArguments(suppliedArgs, cmdArgs, settings.delimiter or " ", plr)
				local runData = {
					forceExecute = true,
				}

				if parsedArgs then
					local cmdFunction = command.Run or command.Function or command.Load

					if cmdFunction then
						server.Events.commandRan:fire((not plr and "System") or "Player", plr, {
							command = command,
							forceExecute = true,
							data = cloneTable(runData),
							arguments = cloneTable(parsedArgs),
							messageArgs = cloneTable(suppliedArgs),
							didHideFromLogs = true,
						})

						local success, error = service.trackTask(
							"_EXECUTE_COMMAND_" .. cmdName:upper(),
							false,
							cmdFunction,
							plr,
							parsedArgs
						)

						if not success then
							return false, error
						else
							return true
						end
					end
				else
					return false, "Missing argument " .. tostring(missingArg) .. ": " .. tostring(missingArgType)
				end
			end
		end,

		getCmdAliasFromBatch = function(plr, messageBatch)
			local pData = Core.getPlayerData(plr.UserId) or {}
			local cmdAliases = pData.aliases or {}

			local trimMessage = Parser:trimString(messageBatch)

			for aliasName, commandLine in pairs(cmdAliases) do
				local commandFromAliasName = Commands.get(aliasName)
				if commandFromAliasName then continue end

				if aliasName:lower() == trimMessage:lower() then return commandLine, aliasName end
			end
		end,

		getCommandFromBatch = function(plr, messageBatch)
			local pData = Core.getPlayerData(plr.UserId) or {}
			local customCmdNames = (pData.__customCmdAliases and pData.__customCmdAliases._table) or {}

			local trimMessage = Parser:trimString(messageBatch)

			for aliasName, cmdName in pairs(customCmdNames) do
				local command, cmdMatch = Commands.get(aliasName)
				if command then continue end

				if aliasName:lower() == trimMessage:sub(1, #aliasName):lower() then
					return Commands.get(cmdName), cmdName, aliasName
				end
			end
		end,

		loadstring = function(source, env)
			local loadFunc, bytecode = server.Loadstring(source, env or getfenv(2))
			return loadFunc, bytecode
		end,

		bytecode = function(source, env)
			local func, byte = Core.loadstring(source, env or {})

			if type(func) == "function" then return byte end
		end,

		getGameServers = function()
			local canUpdateCache = not Core.lastGSRetrieved or os.time() - Core.lastGSRetrieved > 60

			if canUpdateCache then
				if not Core.retrievingGameServers then
					Core.retrievingGameServers = true

					local crossEvent = Signal.new()
					local eventId = "GetGS-" .. service.getRandom()
					variables.crossEvents[eventId] = crossEvent

					local gameServers = {}
					crossEvent:connect(function(jobId, serverInfo) table.insert(gameServers, serverInfo) end)
					Cross.send("RetrieveServerInfo", eventId)

					-- Wait up to 15 seconds
					if server.Studio then
						wait(5)
					else
						wait(15)
					end
					crossEvent:disconnect()

					Core.retrievingGameServers = false
					Core.lastGSRetrieved = os.time()
					Core.latestGSCache = cloneTable(gameServers)

					return gameServers
				else
					repeat
						wait(1)
					until not Core.retrievingGameServers
					return cloneTable(Core.latestGSCache or {})
				end
			end

			return cloneTable(Core.latestGSCache)
		end,
	}
end
