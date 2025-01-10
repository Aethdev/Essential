
return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service
	local message = envArgs.message
	local warn = envArgs.warn
	local wrap = service.Wrap
	
	local Signal = server.Signal
	
	local createdNetworks = {}
	local createdDecoys = {}
	local serverReplicators = {}
	local indexCheckProcesses = {}
	local breachViolatorAttempts = {}
	
	local mainDirectory = service.JointsService or service.ReplicatedStorage
	
	local formatLog
	local getRandom, getRandomV3 = service.getRandom, service.getRandomV3
	
	local Core, Cross, Cmds, Datastore, Identity, Logs, Moderation, Network, Parser, Process, Remote, Roles, Utility
	local function Init()
		Core = server.Core
		Cross = server.Cross
		Cmds = server.Commands
		Datastore = server.Datastore
		Logs = server.Logs
		Identity = server.Identity
		Moderation = server.Moderation
		Network = server.Network
		Parser = server.Parser
		Process = server.Process
		Remote = server.Remote
		Roles = server.Roles
		Utility = server.Utility
		
		formatLog = Logs.formatLog
		
		local networkServer = service.NetworkServer
		
		if networkServer then
			Network.cacheClients()
			
			service.rbxEvent(networkServer.ChildAdded, function(child)
				if child:IsA"ServerReplicator" then
					Network.registerReplicator(child)
				end
			end)
			
			service.rbxEvent(networkServer.ChildRemoved, function(child)
				if child:IsA"ServerReplicator" then
					wait(not server.Running and 10 or 6)
					Network.deregisterReplicator(child)
				end
			end)
			
			service.loopTask("_networkData UPDATE NAMES", 1, function()
				for i, networkData in pairs(createdNetworks) do
					if networkData.active then
						local netInstance = networkData._instance
						
						--warn("updated?")
						if networkData.decoyInfo.randomName then
							local newDecoyName = getRandomV3(networkData.decoyInfo.nameLength)
							
							networkData.decoyInfo.name = newDecoyName
							netInstance.Name = newDecoyName
						else
							netInstance.Name = networkData.decoyInfo.name
						end
						
						netInstance.Archivable = false
					end
				end
				
			end)
		end
	end
	
	local maxNetworkViolationAttempts = 3
	local function logViolationAttempt(plr: ParsedPlayer, network: Network, reason: string?)
		if not breachViolatorAttempts[plr.UserId] then
			breachViolatorAttempts[plr.UserId] = 0
		end

		local attemptsCommitted = breachViolatorAttempts[plr.UserId]+1
		breachViolatorAttempts[plr.UserId] = attemptsCommitted

		if attemptsCommitted % maxNetworkViolationAttempts == 0 then
			task.defer(function()
				if plr:getVar"NetworkBan" then return end
				plr:setVar("NetworkBan", true)
				Moderation.addBan(
					plr.Name,
					"Server",
					`Violator committed several unauthorized acts of network access. (Ban stack level: {attemptsCommitted/maxNetworkViolationAttempts})`,
					nil,
					nil,
					os.time()+(300*2^(attemptsCommitted/maxNetworkViolationAttempts))
				)
			end)
		end
		
		Logs.addLog("Remote", {
			title = `{plr.Name} attempted to access an unauthorized network {network.Id}`;
			desc = `He/she is currently at violation attempt {attemptsCommitted}.\nReason: {reason or "No reason specified"}`
		})
	end
	
	local globalNetFirewall = {
		suspiciousAccess = {
			Rates = 8;
			Reset = 600*1; -- 10 minutes

			ThrottleEnabled = true;
			ThrottleReset = 600*2; -- 20 minutes
			ThrottleMax = 15;
		};
		invalidIndexes = {
			Rates = 12;
			Reset = 600*2; -- 20 minutes

			ThrottleEnabled = true;
			ThrottleReset = 600*6; -- 1 hour
			ThrottleMax = 2;
		};
	}
	
	server.Network = {
		Init = Init;
		
		mainDirectory = mainDirectory;
		MainDirectory = mainDirectory;
		
		newCreate = function(networkName: string, creationData: {[any]: any}): {[any]: any}
			local creationData: {[any]: any} = creationData or {}
			
			local netFunction: any = creationData.networkFunc or creationData.run
			local netInvokable: boolean = creationData.invokable or creationData.invoke
			local netServer: boolean = creationData.serverRun
			local netParent: Instance|nil = creationData.parent or creationData.directory or mainDirectory
			local netPublicId: string = creationData.publicId
			local netDecoyName: string? = creationData.decoyName or creationData.customName
			
			--[[ Firewall types (only client-server networks)
				
					strict
						- kicks the player after malicious attempts (10+ tries within 20 minutes)
					
					high
						- kicks the player after malicious attempts (4+ tries within 20 minutes)
						- bans the player if the amount of past offenses was 2 times or more
			--]]
			local netFirewallType: string = creationData.firewallType or "strict"	
			local netFirewallEnabled: boolean = creationData.firewallEnabled
			local netFirewallCheckIndex: boolean = creationData.firewallCheckIndex or false
			local netFirewallRequireAccessKey: boolean = creationData.firewallRequireAccessKey or false
			local netFirewallAllowRemoteKeyForAccess: boolean = creationData.firewallAllowRemoteKeyForAccess or false

			--local netSecurityRequireKey: boolean = creationData.securityRequireKey
			
			--[[ Firewall info
			
					Setting up firewall sets up the network as PRIVATE. Any player accessing the network must have a PLAYER KEY. Firewall
					flags their access as suspicious if they don't have a registered player key.
			
			]]
			
			local netInstance: Instance = (netInvokable and (netServer and service.New("BindableFunction") or service.New("RemoteFunction"))) or
				(not netInvokable and (netServer and service.New("BindableEvent") or service.New("RemoteEvent")))
			
			local networkData: {[any]: any} = {
				active = true;
				name = networkName or "_";
				id = getRandom(30);
				runFunc = netFunction;
				invokable = netInvokable;
				serverRun = netServer;
				parent = netParent;
				created = tick();
				_instance = netInstance;
				_object = netInstance;
				_objClassName = netInstance.ClassName;
				Instance = netInstance;
				
				decoyInfo = {
					name = (netDecoyName and tostring(netDecoyName)) or getRandomV3(15);
					nameLength = (netDecoyName and #netDecoyName) or 15;
					randomName = not netDecoyName;
				};
				
				warnError = true;
				
				errorLogs = {};
				
				firewallEnabled = netFirewallEnabled;
				firewallType = netFirewallType;
				firewallCheckingIndex = netFirewallCheckIndex;
				firewallRequireAccessKey = netFirewallRequireAccessKey;
				firewallAllowRemoteKeyForAccess = netFirewallAllowRemoteKeyForAccess;
				firewallLogs = {};
				firewallModRecords = { -- Rate limit tick stuff
					suspiciousAccess = {
						Rates = 8;
						Reset = 600*2; -- 20 minutes
						
						ThrottleEnabled = true;
						ThrottleReset = 600*6; -- 1 hour
						ThrottleMax = 2;
					};
					invalidIndexes = {
						Rates = 12;
						Reset = 600*2; -- 20 minutes
						
						ThrottleEnabled = true;
						ThrottleReset = 600*6; -- 1 hour
						ThrottleMax = 2;
					};
				};
				
				waitingForTrustCheck = {};
				networkKeys = {};
				networkCommands = creationData.networkCommands or {};
				
				securityEvents = {};
				securityRunId = "";
				securityRunActive = false;
				reConstructing = false;
				
				changedParent = Signal.new();
				remoteFired = Signal.new();
				remoteErrored = Signal.new();
				
				firewallTriggered = Signal.new();
				--[[ Firewall trigger events
				
					[action_type] [player] [action_taken?] [...]
					
					action_type - Firewall mod action
					
					player - Player (parsed player)
					action_taken - Action the firewall taken place (kick/ban/warn/none)
					
				]]
			}
			
			function networkData:disconnect(): nil
				if self.active then
					self:unLinkFunction()
					self:killSecurity()
					
					if netInstance.Parent ~= nil then
						netInstance:SetAttribute("ESSNetwork", nil)

						if not netServer then
							netInstance:SetAttribute("PublicId", nil)
						else
							netInstance:SetAttribute("Id", nil)
						end
						
						service.Debris:AddItem(netInstance, 0)
					end
					
					self.active = false
				end
			end
			
			function networkData:killSecurity()
				if self.active then
					self.securityRunActive = false
					for i, event in pairs(self.securityEvents) do
						event:Disconnect()
						self.securityEvents[i] = nil
					end
					
					service.stopLoop(self.securityRunId.."_NETWORKCHECK")
				end
			end
			
			function networkData:setupSecurity()
				if self.active then
					self:killSecurity()
					
					local securityRunId = getRandom(14)
					self.securityRunId = securityRunId
					self.securityRunActive = true
					
					table.insert(self.securityEvents, wrap(netInstance:GetPropertyChangedSignal"Name":Connect(function()
						if self.securityRunActive and self.securityRunId == securityRunId then
							local newName = netInstance.Name

							if newName ~= self.decoyInfo.name then
								netInstance.Name = self.decoyInfo.name
							end
						end
					end)))

					table.insert(self.securityEvents, wrap(netInstance:GetPropertyChangedSignal"Parent":Connect(function()
						if self.securityRunActive and self.securityRunId == securityRunId then
							local curParent = netInstance.Parent
							local lastParented = self.parented

							if lastParented then
								if (os.time()-lastParented) < .5 then
									return -- Ignore because the network was just created in the main directory
								elseif self.active and curParent ~= self.parent then
									self:reConstruct(service.roundNumber(Random.new():NextNumber(0.2, 0.5), 0.01))
								end
							end
						end
					end)))

					table.insert(self.securityEvents, wrap(netInstance.AttributeChanged:Connect(function(attribute)
						if self.securityRunActive and self.securityRunId == securityRunId then
							local newValue = netInstance:GetAttribute(attribute)

							if attribute == "ESSNetwork" and not rawequal(newValue, true) then
								netInstance:SetAttribute(attribute, true)
							end
							
							if attribute == "PublicId" then
								local publicId = (not netServer and self.publicId) or nil

								if publicId and publicId~=newValue then
									netInstance:SetAttribute(attribute, publicId)
								end
							end
							
							if attribute == "Id" and netServer then
								if self.id ~= newValue then
									netInstance:SetAttribute(attribute, self.id)
								end
							end
						end
					end)))
					
					service.loopTask(securityRunId.."_NETWORKCHECK", 1, function() -- Check activity
						if self.securityRunActive and self.securityRunId == securityRunId then
							if netInvokable and netFunction then
								if netServer then
									netInstance.OnInvoke = self.remoteFunction
								else
									netInstance.OnServerInvoke = self.remoteFunction
								end
							end
						end
					end)
					
					-- Firewall setup
					if not netServer and netFirewallEnabled then
						local firewallType = table.find({
							"strict", "high"
						}, netFirewallType)
						
						if not firewallType then
							warn("NETWORK "..self.id.." ("..self.name..") couldn't create a firewall with an invalid type. (strict/high types expected)")
						end
					end
				end
			end
			
			function networkData:processFirewall(player: Player, modAction: string, ...)
				local parsedPlayer = Parser:apifyPlayer(player)
				
				local ignoreArgs = {
					GET_KEY = "Adonis",
					--BadMemes = "Adonis"
				}
				local ignoreArgRL = {
					Rates = 3;
					Reset = 600;
				}
				
				if modAction == "suspicious_access" then
					local trustKey = tostring(({...})[1])
					
					local clientData = parsedPlayer:getClientData()
					local cliTrustChecked = clientData and clientData.trustChecked
					local cliVerifyId = clientData and clientData.verifyId
					
					if (not cliTrustChecked or tick()-clientData.trustCheckOs < 20) and cliVerifyId == trustKey then
						return
					end
					
					local isPlayerOnTrustCheck = self:isPlayerOnTrustCheck(parsedPlayer)
					local isPlayerOnTCWithOtherNets = Network.isPlayerOnTrustCheckWithAnyNetwork(parsedPlayer)
					
					if isPlayerOnTrustCheck then
						warn("[SECURITY ISSUE] Uh, oh! "..tostring(parsedPlayer).." has an active trust check status without valid access. Make sure to remove their trust key data before revoking their access.")
						warn("Network name:", networkData.name)
						self:remPlayerFromTrustCheck(parsedPlayer)
						return
					elseif isPlayerOnTCWithOtherNets then
						local keyData = Network:findTrustKeyInNetworks(trustKey)
						
						if keyData then
							return
						end
					end		
					
					table.insert(self.firewallLogs, formatLog({
						title = tostring(parsedPlayer).." tried calling network without whitelist"
					}))
					
					local globalAttemptRatePass, globalAttemptThrottle = Utility:checkRate(globalNetFirewall.suspiciousAccess, parsedPlayer.playerId)
					if not globalAttemptRatePass then
						if globalAttemptThrottle then
							parsedPlayer:Kick("Several security attempts to access a private network globally")
						else
							if not parsedPlayer:getVar("NetworkBan") then
								parsedPlayer:setVar("NetworkBan", true)
								Moderation.addBan(
									parsedPlayer.Name,
									"Server",
									"Maliciously attempted to access random private networks without whitelist"	
								)
							end
						end
						
						return
					end
					
					local attemptRatePass, attemptThrottle = Utility:checkRate(self.firewallModRecords.suspiciousAccess, parsedPlayer.playerId)
					if not attemptRatePass then
						self.firewallTriggered:fire(modAction, player, "kick")
						parsedPlayer:Kick("Several security attempts to access a private network")
						
						if netFirewallType == "high" then
							if not attemptThrottle then
								if not parsedPlayer:getVar("NetworkBan") then
									parsedPlayer:setVar("NetworkBan", true)
									Moderation.addBan(
										parsedPlayer.Name,
										"Server",
										"Maliciously attempted to access a private network without whitelist"	
									)
								end
								self.firewallTriggered:fire(modAction, player, "ban")
								Logs.addLog("Exploit", "[🔨 Ban] "..tostring(parsedPlayer).." attempts several times to access a private network")
							else
								Logs.addLog("Exploit", "[🦵 Kick] "..tostring(parsedPlayer).." attempts a few times to access a private network")
							end
						else
							Logs.addLog("Exploit", "[🦵 Kick] "..tostring(parsedPlayer).." attempts a few/several times to access a private network")
						end
						
						return false
					else
						self.firewallTriggered:fire(modAction, player, "warn")
					end
				end
				
				if modAction == "invalid_index" then
					local indexCheckStat = ({...})[1]
					local firstArg = tostring(({...})[2])
					
					local clientData = parsedPlayer:getClientData()
					local cliTrustChecked = clientData and clientData.trustChecked
					local cliVerifyId = clientData and clientData.verifyId

					if (not cliTrustChecked or tick()-clientData.trustCheckOs < 10) and cliVerifyId == firstArg then
						return
					end

					local isPlayerOnTrustCheck = self:isPlayerOnTrustCheck(parsedPlayer)
					local isPlayerOnTCWithOtherNets = Network.isPlayerOnTrustCheckWithAnyNetwork(parsedPlayer)
					
					if isPlayerOnTrustCheck then
						warn("[SECURITY ISSUE] Uh, oh! "..tostring(parsedPlayer).." has an active trust check status without valid access. Make sure to remove their trust key data before revoking their access.")
						warn("Network name:", networkData.name)
						self:remPlayerFromTrustCheck(parsedPlayer)
						return
					elseif isPlayerOnTCWithOtherNets then
						local keyData = Network:findTrustKeyInNetworks(firstArg)

						if keyData then
							return
						end
					end
					
					--warn("Invoked index:", firstArg)
					local canIgnoreIndex = Network.canIgnoreIndex(parsedPlayer, firstArg)
					if canIgnoreIndex then
						return
					end
					
					--if not ignoreArgs[firstArg] then
					if indexCheckStat == -1 then
						self.firewallTriggered:fire(modAction, player, "log", "invalid_type")
						table.insert(self.firewallLogs, formatLog({
							title = tostring(parsedPlayer).." tried invoking/firing with an invalid index type "..tostring(firstArg).." ("..type(firstArg)..")"
						}))
					elseif indexCheckStat == -2 then
						self.firewallTriggered:fire(modAction, player, "log", "invalid_command")
						table.insert(self.firewallLogs, formatLog({
							title = tostring(parsedPlayer).." tried invoking/firing with a non-existent index "..tostring(firstArg)
						}))
					elseif indexCheckStat == -3 then
						self.firewallTriggered:fire(modAction, player, "log", "invalid_command_call")
						table.insert(self.firewallLogs, formatLog({
							title = tostring(parsedPlayer).." tried invoking/firing with index "..tostring(firstArg).." with an invalid call type"
						}))
					elseif indexCheckStat == -4 then
						self.firewallTriggered:fire(modAction, player, "log", "invalid_access")
						table.insert(self.firewallLogs, formatLog({
							title = tostring(parsedPlayer).." tried invoking/firing with index "..tostring(firstArg).." with insufficient permissions"
						}))
					end
						
						local attemptRatePass, attemptThrottle = Utility:checkRate(self.firewallModRecords.invalidIndexes, parsedPlayer.playerId)
						if not attemptRatePass then
							parsedPlayer:Kick("Several security attempts to access a private index on a private network")
							self.firewallTriggered:fire(modAction, player, "kick")
							
							if netFirewallType == "high" then
								if not attemptThrottle then
									if not parsedPlayer:getVar("NetworkBan") then
										parsedPlayer:setVar("NetworkBan", true)
										Moderation.addBan(
											parsedPlayer.Name,
											"Server",
											"Maliciously attempted to access a private index in a network without whitelist"	
										)
									end
									Logs.addLog("Exploit", "[🔨 Ban] "..tostring(parsedPlayer).." attempts to access a private index on a private network")
									self.firewallTriggered:fire(modAction, player, "ban")
								end
							end

							return false
						end
					--end
				end
			end
			
			function networkData:canRunIndex(player: Player, index: string|number, invoke: boolean)
				local parsedPlayer = Parser:apifyPlayer(player)
				
				local failToCheck = false
				local isValidIndex = table.find({"string", "number"}, type(index))
				if not isValidIndex then
					failToCheck = true
				end
				
				if failToCheck then
					return -1
				else
					-- Remote command template is used for network commands
					local networkCommands = self.networkCommands
					local networkCmd = networkCommands[index]
					
					if not networkCmd or type(networkCmd) ~= "table" then
						return -2
					else
						if not (networkCmd.Can_Invoke or networkCmd.Can_Fire) then
							networkCmd.Can_Fire = true
						end
						
						local canInvokeOrFireCmd = (invoke and networkCmd.Can_Invoke) or (not invoke and networkCmd.Can_Fire) or false
						if not canInvokeOrFireCmd then
							return -3
						end
						
						local lockdown = Core.lockdown
						local whitelist = networkCmd.Whitelist or {}
						local blacklist = networkCmd.Blacklist or {}
						local permissions = networkCmd.Permissions
						local publicUse = networkCmd.Public

						local userWhitelisted = (whitelist and Identity.checkTable(parsedPlayer, whitelist)) or false
						local userBlacklisted = (whitelist and Identity.checkTable(parsedPlayer, blacklist)) or false
						local userHasPermissions = (permissions and Roles:hasPermissionFromMember(parsedPlayer, permissions)) or false

						local userAdmin = not networkCmd.adminIgnore and Moderation.checkAdmin(parsedPlayer)
						local canAccess = userAdmin or ((publicUse or userHasPermissions or userWhitelisted) and not userBlacklisted)
						
						if not canAccess then
							return -4
						else
							return 0
						end
					end
				end
			end
			
			function networkData:addPlayerToTrustCheck(player: ParsedPlayer, timeout: number)
				local searchTimeout = timeout and math.clamp(timeout, 10, 1200) -- 20 minutes is the maximum wait timeout
				
				local checkStarted: number = tick()
				local checkExpireMs: number = searchTimeout and checkStarted+(searchTimeout*1000)
				local checkData: {[any]: any} = table.freeze{
					expireMs = checkExpireMs,
					started = checkStarted
				}
				
				local existingCheckData: {[any]: any}? = self.waitingForTrustCheck[player.playerId]
				if (existingCheckData and (not checkExpireMs or checkExpireMs-checkStarted < 0)) then
					return false
				else
					self.waitingForTrustCheck[player.playerId] = checkData
					
					if searchTimeout and searchTimeout > 0 then
						task.delay(searchTimeout, function()
							if rawequal(self.waitingForTrustCheck[player.playerId], checkData) then
								self.waitingForTrustCheck[player.playerId] = nil
							end
						end)
					end
					
					return true
				end
			end
			
			function networkData:remPlayerFromTrustCheck(player: ParsedPlayer)
				self.waitingForTrustCheck[player.playerId] = nil
			end
			
			function networkData:isPlayerOnTrustCheck(player: ParsedPlayer)
				local existingCheckData: {[any]: any}? = self.waitingForTrustCheck[player.playerId]
				if not existingCheckData or (existingCheckData.expireMs and tick()-existingCheckData.expireMs > 0) then
					if existingCheckData then
						self.waitingForTrustCheck[player.playerId] = nil
					end
					return false
				else
					return true
				end
			end
			
			function networkData:createPlayerKey(player, expireOs)
				local playerKey = getRandom(30)
				local trustKey = getRandom(40)
				local disconnectKey = getRandom(30)
				local keyInfo; keyInfo = {
					active = true;
					destroyed = false;
					verifyStatus = false;
					verifiedSince = nil; -- (os time) Given by the system after verifying
					id = playerKey;
					trustKey = trustKey;
					--clientAccessKey = nil; -- Given by the client
					expireOs = expireOs;
					disconnectId = disconnectKey;

					--// Events
					disconnected = Signal.new();
					verified = Signal.new();
				}

				function keyInfo:isActive()
					return self.active and (not self.expireOs or os.time()-self.expireOs<0)
				end

				function keyInfo:isVerified()
					return self.verifyStatus
				end

				function keyInfo:isReadyToUse()
					return self:isActive() and self:isVerified()
				end

				function keyInfo:destroy()
					if not self.destroyed then
						self.destroyed = true
						self.active = false
						self.disconnected:fire(true)

						if self.playerLeftEvent then
							self.playerLeftEvent:disconnect()
						end

						self.verified:disconnect()

						networkData.networkKeys[player.playerId] = nil
					end
				end

				keyInfo.playerLeftEvent = player.disconnected:connectOnce(function()
					keyInfo:destroy()
				end)
				
				self.networkKeys[player.playerId] = keyInfo
				
				return playerKey,keyInfo
			end
			
			function networkData:revokePlayerKeys()
				for i, keyInfo in pairs(self.networkKeys) do
					keyInfo.active = false
					keyInfo.expireOs = os.time()
					self.networkKeys[i] = nil
				end
			end

			function networkData:getPlayerKey(player): {[any]: any}?
				return self.networkKeys[player.playerId]
			end
			
			function networkData:revokePlayerKey(player)
				local personalKey = self:getPlayerKey(player)
				if personalKey then
					personalKey:destroy()
				end
			end
			
			function networkData:reConstruct(delayTime: number)
				local delayTime = math.max(delayTime or 0, 0.2)
				
				if self.active and not self.reConstructing then
					self.reConstructing = true
					
					self:unLinkFunction()
					self:killSecurity()
					
					if netInstance.Parent ~= nil then
						netInstance:SetAttribute("ESSNetwork", nil)

						if not netServer then
							netInstance:SetAttribute("PublicId", nil)
						else
							netInstance:SetAttribute("Id", nil)
						end
						
						service.Debris:AddItem(netInstance, 0)
					end
					
					task.delay(delayTime, function()
						if self.active then
							netInstance = service.New(self._objClassName, {
								Parent = self.parent;
							})

							self.parented = tick()
							self:linkFunction()
							self:setupSecurity()
							self:setupInstance()
						end
						self.reConstructing = false
					end)
				end
			end
			
			function networkData:linkFunction()
				if self.active then
					local remoteFunc = function(...)
						if self.active then
							self.lastActive = os.time()

							-- Firewall check
							if not netServer and netFirewallEnabled then
								local player: Player = ({...})[1]
								local parsedPlr = Parser:apifyPlayer(player)
								local clientData = parsedPlr:getClientData()

								local playerKey = self:getPlayerKey(parsedPlr)
								local plrKeyId = playerKey and playerKey.id
								local globalPlayerKey = if clientData then clientData.remoteServerKey else plrKeyId
								local hasAccess = playerKey and playerKey:isActive()
								local restArgs = {unpack({...}, 2)}
								
								if not hasAccess then
									self:processFirewall(player, "suspicious_access", unpack(restArgs))
									return
								else
									if netFirewallRequireAccessKey then
										local givenAccessKey = restArgs[1]
										if (type(givenAccessKey)=="string") then
											local isUsingTheRightKey = (netFirewallAllowRemoteKeyForAccess and globalPlayerKey and givenAccessKey==globalPlayerKey) or
												(plrKeyId and givenAccessKey == plrKeyId)
											
											
											if not isUsingTheRightKey then
												self:processFirewall(player, "suspicious_access", unpack(restArgs))
												return
											end
										else
											self:processFirewall(player, "suspicious_access", unpack(restArgs))
											return
										end
										
										restArgs = {unpack(restArgs, 2)}
									end
									
									if netFirewallCheckIndex then
										local passIndexCheckStat = self:canRunIndex(player, restArgs[1], netInvokable)
										--warn("Network "..networkName.." |  Index: "..tostring(restArgs[1]).." | Check stat: "..tostring(passIndexCheckStat))
										if passIndexCheckStat < 0 then
											self:processFirewall(player, "invalid_index", passIndexCheckStat, unpack(restArgs))
											return
										end
									end
								end
							end

							self.remoteFired:fire(...)

							local rets = {service.trackTask("_NETWORKFUNCTION-"..networkName, not netInvokable, netFunction, ...)}
							local suc = rets[1]

							if not suc then
								local errorData = {
									created = tick();
									error = rets[2];
								}
								table.insert(self.errorLogs, errorData)
								self.remoteErrored:fire(errorData.created, rets[2])

								if self.warnError then
									warn("Network "..networkName.." encountered an error: "..tostring(rets[2]), "\n", rets[3])
									--message("Network "..networkName.." encountered an error: "..tostring(rets[2]))
								end
							else
								if netInvokable then
									return unpack(rets, 2)
								end
							end
						else
							if netInvokable then
								return "Network_Inactive"
							end
						end
					end
					
					if netInvokable and netFunction then
						self.remoteFunction = remoteFunc
						
						if netServer then
							netInstance.OnInvoke = remoteFunc
						else
							netInstance.OnServerInvoke = remoteFunc
						end
					elseif not netInvokable and netFunction then
						self.remoteFunction = remoteFunc
						
						if netServer then
							self.connection = netInstance.Event:Connect(remoteFunc)
						else
							self.connection = netInstance.OnServerEvent:Connect(remoteFunc)
						end
					end
				end
			end
			
			function networkData:unLinkFunction()
				if self.active then
					if self.remoteFunction then
						if netServer and netInvokable then
							netInstance.OnInvoke = nil
						elseif not netServer and netInvokable then
							netInstance.OnServerInvoke = nil
						elseif not netInvokable then
							self.connection:Disconnect()
						end
					end
				end
			end
			
			function networkData:setupInstance()
				if self.active then
					if not self.parented then
						if netInstance.Parent ~= self.parent then
							netInstance.Parent = self.parent
						end
						
						self.parented = tick()
					end
					
					netInstance.Name = networkData.decoyInfo.name
					netInstance.Archivable = false

					netInstance:SetAttribute("ESSNetwork", true)

					if not netServer then
						netInstance:SetAttribute("PublicId", networkData.publicId)
					else
						netInstance:SetAttribute("Id", networkData.id)
					end

					netInstance.Parent = netParent
				end
			end
			
			function networkData:changeParent(newParent: Instance)
				if self.active and self.parent ~= newParent then
					local oldParent = self.parent
					self.parent = newParent
					self.changedParent:fire(newParent, oldParent)
					
					local changeWaitTime = (not self.parented and 0) or 0.5-math.min(self.parented, 0.5)
					task.delay(changeWaitTime, function()
						if netInstance.Parent ~= newParent then
							netInstance.Parent = newParent
						end
					end)
					
					self.parented = tick()
				end
			end
			
			function networkData:runToPlayers(players: {[any]: any}, ...: any)
				if self.active and not netServer then
					local results = {}
					
					for i,plr in pairs(players) do
						service.Routine(function(...)
							if netInvokable then
								results[plr] = self.Instance:InvokeClient(plr, ...)
							else
								self.Instance:FireClient(plr, ...)
							end
						end, ...)
					end

					return results
				end
			end
			
			function networkData:runToPlayer(player: player, ...: any)
				if self.active and not netServer then
					if netInvokable then
						return self.Instance:InvokeClient(player, ...)
					else
						self.Instance:FireClient(player, ...)
					end
				end
			end
			
			function networkData:run(...: any)
				if self.active and netServer then
					if netInvokable then
						return self.Instance:Invoke(...)
					else
						self.Instance:Fire(...)
					end
				end
			end
			
			if not netServer then
				networkData.publicId = netPublicId or getRandom(40)
			end
			
			networkData:setupInstance()
			networkData:linkFunction()
			networkData:setupSecurity()
			
			setmetatable(networkData, {
				__index = function(self, ind)
					if type(ind) == "string" then
						return rawget(networkData, ind:sub(1,1):lower()..ind:sub(2))
					else
						return rawget(networkData, ind)
					end
				end,
				__metatable = "_LOCKED";
			})
			
			table.insert(createdNetworks, networkData)
			
			return networkData
		end,
		
		newDecoy = function(decoyName: string, creationData: {[any]: any})
			local creationData: {[any]: any} = creationData or {}

			local netInvokable: boolean = creationData.invokable or creationData.invoke
			local netServer: boolean = creationData.serverRun
			local netParent: Instance|nil = creationData.parent or creationData.directory or mainDirectory
			local netPublicId: string = creationData.publicId
			
			local decoyName = decoyName or "_"
			local networkData = Network.newCreate("DECOY_"..tostring(decoyName), {
				invokable = netInvokable;
				serverRun = netServer;
				parent = netParent;
				publicId = netPublicId;
				networkFunc = function(plr)
					local randoms = {
						"_RESPONSE_DONE";
						"_REMOTE_SUCCESS";
						"_%s_RESPONDED";
						"_REMOTE_%s_SENT";
						"_REMOTE_CALLED_FROM_%s";
						"_REMOTE_"..getRandom():upper();
					}
					
					if not(plr and typeof(plr) == "Instance" and plr:IsA"Player") then
						plr = nil
					end
					
					return string.format(randoms[math.random(1,#randoms)], (plr and plr.Name:upper()) or "SYSTEM")
				end,
			})
			
			return networkData
		end,
		
		create = function(networkName, parent, invoke, serverNetwork, func, publicId)
			networkName = networkName or getRandom(math.random(10,20))
			parent = parent or mainDirectory
			
			local remoteObject = (function()
				if invoke then
					return (serverNetwork and service.New("BindableFunction")) or service.New("RemoteFunction")
				else
					return (serverNetwork and service.New("BindableEvent")) or service.New("RemoteEvent")
				end		
			end)()
			
			remoteObject.Name = getRandom()
			remoteObject.Archivable = false
			
			local networkInfo; networkInfo = {
				Name = networkName;
				Index = getRandom(50);
				Id = networkName..getRandom();
				Function = func;
				Active = true;
				LastActive = nil;
				Invoke = invoke or false;
				Server = serverNetwork or false;
				Parent = parent;
				ErrorLogs = {};
				Created = os.time();
				Instance = remoteObject;
				Running = false;
				DecoyName = remoteObject.Name;
				
				ChangedParent = service.New("BindableEvent");
				Fired = service.New("BindableEvent");
				
				Disconnect = function(self)
					if networkInfo.Active then
						networkInfo.Active = false
						
						if invoke then
							remoteObject.OnServerInvoke = nil
						else
							local con = networkInfo.Connection
							
							if con and con.Disconnect then
								con:Disconnect()
							end
						end
						
						networkInfo.Security3:Disconnect()
						networkInfo.Security2:Disconnect()
						networkInfo.Security1:Disconnect()
						
						-- Check whether the network was created too early
						local timeSinceLP = os.time()-networkInfo.Parented
						
						if timeSinceLP < 0.5 then
							service.Debris:AddItem(remoteObject, 0.5-timeSinceLP)
						else
							service.Debris:AddItem(remoteObject, 0)
						end
						
						networkInfo.Stopped = os.time()
					end
				end;
				
				Reload = function(self, timeOut, override)
					if not override and networkInfo.Reloading then return end
					if override or (networkInfo.Active and not override) then
						if not override then
							if timeOut then
								networkInfo.Reloading = true
								
								local start = os.time()
								repeat wait() until (os.time()-start > timeOut)
							else
								networkInfo.Reloading = true
							end
						end
						
						networkInfo:Disconnect()
						
						--warn("Reloading network "..networkInfo.Id)
						local newNetwork = Network.create(networkName, networkInfo.Parent, invoke, serverNetwork, func, publicId or networkInfo.publicId)
						local oldNetwork = networkInfo
						
						setmetatable(newNetwork, {
							__newindex = function(self, ind, val)
								rawset(networkInfo, ind, val)
								rawset(newNetwork, ind, val)
							end;
						})
						
						for i,v in pairs(oldNetwork) do
							oldNetwork[i] = nil
						end
						
						for i,v in pairs(newNetwork) do
							oldNetwork[i] = v
						end
						
						--warn("New network for "..networkInfo.Id..":", newNetwork)
						networkInfo = newNetwork
						
						return newNetwork
					end
				end;
				
				ChangeParent = function(self, newParent)
					if newParent and networkInfo.Parent ~= newParent then
						if networkInfo.ChangingParent then
							networkInfo.ChangedParent.Event:Wait()
						end
						
						local anInstance = typeof(newParent) == "Instance"
						
						if anInstance then
							local lastParented = networkInfo.Parented
							local nowParented = os.time()
							
							networkInfo.ChangingParent = true
							networkInfo.Parent = newParent
							
							local didParent;
							for i = 1,3,1 do
								if not networkInfo.Active or remoteObject.Parent == newParent then
									break
								else
									local suc,ers = pcall(function()
										remoteObject.Parent = newParent
									end)
									
									if suc then
										didParent = true
										networkInfo.ChangedParent:Fire(newParent, os.time())
										break
									end
								end
								
								if not didParent then
									wait(.5)
									if not networkInfo.Active then
										return
									end
								end
							end
							
							if not didParent then -- If it can't parent to the new one, just reload the network
								networkInfo:Reload()
							end
							
							networkInfo.ChangingParent = false
						end
					end
				end;
				
				FireToPlayers = function(self, players, ...)
					if not serverNetwork then
						local results = {}
						
						for i,plr in pairs(players) do
							service.Routine(function(...)
								if invoke then
									results[plr] = networkInfo.Instance:InvokeClient(plr, ...)
								else
									networkInfo.Instance:FireClient(plr, ...)
								end
							end, ...)
						end
						
						return results
					end
				end,
			}
			
			-- Create a client network public id (not the network id) visible in the server & client
			if not serverNetwork then
				networkInfo.publicId = publicId or getRandom(40)
			end
			
			if invoke and func then
				local remoteFunc = function(...)
					if networkInfo.Active then
						networkInfo.LastActive = os.time()
						networkInfo.Running = true
						
						local rets = {service.trackTask("_NETWORKFUNCTION-"..networkName, false, func, ...)}
						local suc = rets[1]
						
						networkInfo.Running = false
						
						if not suc then
							table.insert(networkInfo.ErrorLogs, {
								Created = os.time();
								Error = rets[2];
							})
							
							message("Network "..networkName.." encountered an error: "..tostring(rets[2]))
						else
							return unpack(rets, 2)
						end
					else
						return "Network_Inactive_"..tostring(networkInfo.Stopped)
					end
				end
				
				networkInfo.RemoteFunction = remoteFunc
				
				if serverNetwork then
					remoteObject.OnInvoke = remoteFunc
				else
					remoteObject.OnServerInvoke = remoteFunc
				end
			elseif not invoke and func then
				local remoteFunc = function(...)
					if networkInfo.Active then
						networkInfo.Running = true

						local rets = {service.trackTask("_NETWORKFUNCTION-"..networkName, false, func, ...)}
						local suc = rets[1]

						networkInfo.Running = false
						
						if not suc then
							table.insert(networkInfo.ErrorLogs, {
								Created = os.time();
								Error = rets[2];
							})
							
							message("Network "..networkName.." encountered an error: "..tostring(rets[2]))
						else
							return unpack(rets, 2)
						end
					else
						return "Network_Inactive_"..tostring(networkInfo.Stopped)
					end
				end
				
				networkInfo.RemoteFunction = remoteFunc
				
				if serverNetwork then
					networkInfo.Connection = remoteObject.Event:Connect(remoteFunc)
				else
					networkInfo.Connection = remoteObject.OnServerEvent:Connect(remoteFunc)
				end
			end
			
			networkInfo.Security1 = wrap(remoteObject:GetPropertyChangedSignal"Name":Connect(function()
				local newName = remoteObject.Name
				
				if newName ~= networkInfo.DecoyName then
					remoteObject.Name = networkInfo.DecoyName
				end
			end))
			
			networkInfo.Security2 = wrap(remoteObject:GetPropertyChangedSignal"Parent":Connect(function()
				local curParent = remoteObject.Parent
				local lastParented = networkInfo.Parented
				
				if lastParented then
					if (os.time()-lastParented) < .5 then
						return -- Ignore because the network was just created in the main directory
					elseif networkInfo.Active and curParent ~= networkInfo.Parent then
						--networkInfo:Reload()
					end
				end
			end))
			
			networkInfo.Security3 = wrap(remoteObject.AttributeChanged:Connect(function(attribute)
				local newValue = remoteObject:GetAttribute(attribute)
				
				if attribute == "ESSNetwork" and not rawequal(newValue, true) then
					remoteObject:SetAttribute(attribute, true)
				end
				
				if attribute == "PublicId" then
					local publicId = (not serverNetwork and networkInfo.publicId) or nil
					
					if publicId and publicId~=newValue then
						remoteObject:SetAttribute(attribute, publicId)
					end
				end
			end))
			
			remoteObject:SetAttribute("ESSNetwork", true)
			
			if not serverNetwork then
				remoteObject:SetAttribute("PublicId", networkInfo.publicId)
			end
			
			local trackLoopName = "_NETWORK-"..networkName.."-ACTIVECHECK"
			service.loopTask(trackLoopName, 15, function() -- Check activity
				if networkInfo.Active then
					local newDecoyName = getRandom()
					
					networkInfo.DecoyName = newDecoyName
					remoteObject.Name = newDecoyName
					remoteObject.Archivable = false
					
					if invoke then
						if serverNetwork then
							remoteObject.OnInvoke = networkInfo.RemoteFunction
						else
							remoteObject.OnServerInvoke = networkInfo.RemoteFunction
						end
					end
					
				else
					local start = os.time()
					repeat wait() until not server.Running or networkInfo.Active or (os.time()-start > 120) -- Check two minutes of inactivity
					
					if not networkInfo.Active or not server.Running then
						service.stopLoop(trackLoopName)
						
						if not networkInfo.Stopped then
							networkInfo:Disconnect()
						end
					end
				end
			end)
			
			remoteObject.Parent = parent
			networkInfo.Parented = os.time()
			
			
			task.delay(5, function()
				if networkInfo.Active then
					--warn("Check network", remoteObject:GetFullName())
					remoteObject.Parent = parent
				end
			end)
			
			table.insert(createdNetworks, networkInfo)
			return networkInfo
		end;
		
		createDecoy = function(name, invoke, parent)
			name = name or "_RANDOM"
			
			local decoyInstance = (invoke and service.New("RemoteFunction")) or service.New("RemoteEvent")
			local decoyName = getRandom(math.random(12,14))
			
			decoyInstance.Name = decoyName
			
			local decoyInfo; decoyInfo = {
				Name = name;
				Index = getRandom(50);
				Id = name..getRandom();
				
				Created = os.time();
				Instance = decoyInstance;
				
				Disconnect = function(self)
					if decoyInfo.Active then
						decoyInfo.Active = false

						if invoke then
							decoyInstance.OnServerInvoke = nil
						else
							local con = decoyInfo.Connection

							if con and con.Disconnect then
								con:Disconnect()
							end
						end

						decoyInfo.Security2:Disconnect()
						decoyInfo.Security1:Disconnect()

						-- Check whether the network was created too early
						local timeSinceLP = os.time()-decoyInfo.Parented

						if timeSinceLP < .5 then
							service.Debris:AddItem(decoyInstance, 0.5-timeSinceLP)
						else
							service.Debris:AddItem(decoyInstance, 0)
						end

						decoyInfo.Stopped = os.time()
					end
				end;

				Reload = function(self, timeOut, override)
					if not override and decoyInfo.Reloading then return end
					if not override then
						if timeOut then
							decoyInfo.Reloading = true

							local start = os.time()
							repeat wait() until (os.time()-start > timeOut)
						else
							decoyInfo.Reloading = true
						end
					end

					decoyInfo:Disconnect()

					local newDecoy = Network.createDecoy(name, invoke, parent)
					local oldDecoy = decoyInfo

					setmetatable(newDecoy, {
						__newindex = function(self, ind, val)
							rawset(decoyInfo, ind, val)
							rawset(oldDecoy, ind, val)
						end;
					})

					setmetatable(oldDecoy, {
						__index = function(self, ind)
							return newDecoy[ind]
						end,
					})

					decoyInfo = newDecoy

					return newDecoy
				end;
				
				ChangeParent = function(self, newParent)
					if newParent and decoyInfo.Parent ~= newParent then
						if decoyInfo.ChangingParent then
							decoyInfo.ChangedParent.Event:Wait()
						end

						local anInstance = typeof(newParent) == "Instance"

						if anInstance then
							local lastParented = decoyInfo.Parented
							local nowParented = os.time()

							decoyInfo.ChangingParent = true
							decoyInfo.Parent = newParent

							local didParent;
							for i = 1,3,1 do
								if not decoyInfo.Active or decoyInstance.Parent == newParent then
									break
								else
									local suc,ers = pcall(function()
										decoyInstance.Parent = newParent
									end)

									if suc then
										didParent = true
										decoyInfo.ChangedParent:Fire(newParent, os.time())
										break
									end
								end

								if not didParent then
									wait(.5)
									if not decoyInfo.Active then
										return
									end
								end
							end

							if not didParent then -- If it can't parent to the new one, just reload the network
								decoyInfo:Reload()
							end

							decoyInfo.ChangingParent = false
						end
					end
				end;
			}
			
			if invoke then
				local randoms = {
					"_RESPONSE_DONE";
					"_REMOTE_SUCCESS";
					"_%s_RESPONDED";
					"_REMOTE_%s_SENT";
					"_REMOTE_CALLED_FROM_%s";
					"_REMOTE_"..getRandom():upper();
				}
				
				local decoyFunc = function(plr, ...)
					if decoyInfo.Active then
						return string.format(randoms[math.random(1,#randoms)], plr.Name:upper())
					end
				end
				
				decoyInfo.RemoteFunction = decoyFunc
				decoyInstance.OnServerInvoke = decoyFunc
			end
			
			decoyInfo.Security1 = wrap(decoyInstance:GetPropertyChangedSignal"Name":Connect(function()
				local newName = decoyInstance.Name
				
				if newName ~= decoyName then
					decoyInstance.Name = decoyName
				end
			end))

			decoyInfo.Security2 = wrap(decoyInstance:GetPropertyChangedSignal"Parent":Connect(function()
				local parent = decoyInstance.Parent
				local lastParented = decoyInfo.Parented
				
				if lastParented then
					if (os.time()-lastParented) < .5 then
						return -- Ignore because the network was just created in the main directory
					else
						decoyInfo:Reload()
					end
				end
			end))
			
			local trackLoopName = "_DECOY-"..decoyName.."-ACTIVECHECK"
			service.loopTask(trackLoopName, math.random(200,400), function() -- Check activity
				if decoyInfo.Active then
					local newDecoyName = getRandomV3()

					decoyInfo.DecoyName = newDecoyName
					decoyInstance.Name = newDecoyName
					decoyInstance.Archivable = false

					if invoke then
						decoyInstance.OnServerInvoke = decoyInfo.RemoteFunction
					end
				else
					service.stopLoop(trackLoopName)
				end
			end)
			
			decoyInstance.Parent = parent or mainDirectory
			decoyInfo.Parented = os.time()
			
			table.insert(createdDecoys, decoyInfo)			
			
			return decoyInfo
		end,
		
		Create = function(...) return Network.create(...) end;
		
		get = function(name)
			local list = {}
			
			for i,network in pairs(createdNetworks) do
				if (network.Name == name or network.name == name) or network.Index == name then
					table.insert(list, network)
				end
			end
			
			return list
		end;
		getInfo = function(name) return createdNetworks[name] end;
		getDecoys = function(name)
			local list = {}
			
			for i,info in pairs(createdDecoys) do
				if info.Name == name or info.Index == name then
					table.insert(list, info)
				end
			end
			
			return list
		end,
		
		getNetworks = function()
			local dupTable = {}
			
			for i,v in pairs(createdNetworks) do
				dupTable[i] = v
			end
			
			return dupTable
		end,
		
		getClient = function(userIdOrName)
			local justName = type(userIdOrName)=="string"
			local justId = type(userIdOrName)=="number"
			
			if justName then
				for i,cli in pairs(service.NetworkServer:children()) do
					if cli:IsA"ServerReplicator" then
						local plr = cli:GetPlayer()
						
						if plr and plr.Name:lower() == userIdOrName:lower() then
							return cli,plr
						end
					end
				end
			elseif justId then
				for i,cli in pairs(service.NetworkServer:children()) do
					if cli:IsA"ServerReplicator" then
						local plr = cli:GetPlayer()

						if plr and plr.UserId == userIdOrName then
							return cli,plr
						end
					end
				end
			end
		end;
		
		cacheClients = function()
			for i,cli in pairs(service.NetworkServer:children()) do
				if cli:IsA"ServerReplicator" then
					Network.registerReplicator(cli)
				end
			end
		end;
		
		registerReplicator = function(rep)
			local existCache = (function()
				for i,repli in pairs(serverReplicators) do
					if repli.instance == rep then
						return repli
					end
				end
			end)()
			
			if existCache then
				existCache.player = rep:GetPlayer()
				existCache.updated = os.time()
			else
				local cacheInfo; cacheInfo = {
					instance = rep;
					player = rep:GetPlayer();
					updated = os.time();
					id = getRandom();
				}
				
				table.insert(serverReplicators, cacheInfo)
				
				if not cacheInfo.player then
					service.startLoop("ServerReplicatorCheck-"..cacheInfo.id, 2, function()
						if not table.find(serverReplicators, cacheInfo) or cacheInfo.player then
							service.stopLoop("ServerReplicatorCheck-"..cacheInfo.id)
						else
							Network.registerReplicator(rep)
						end
					end)
				end
			end
		end;
		
		deregisterReplicator = function(rep)
			local existCache = (function()
				for i,repli in pairs(serverReplicators) do
					if repli.instance == rep then
						return i
					end
				end
			end)()
			
			if existCache then
				table.remove(serverReplicators, existCache)
			end
		end;
		
		getAll = function()
			local list = {}
			
			for i,v in pairs(createdNetworks) do
				table.insert(list, service.cloneTable(v))
			end
			
			for i,v in pairs(createdDecoys) do
				table.insert(list, service.cloneTable(v))
			end
			
			return list
		end;
		
		stopAll = function()
			--for i,net in pairs(createdNetworks) do
			--	local suc,ers = service.trackTask("_STOPPING_NETWORK-"..(net.Name or net.name):upper(), true, net.Disconnect, net)
				
			--	if not suc then
			--		warn("Stopping network encountered an error: "..tostring(ers))
			--	end
			--end

			--for i,decoy in pairs(createdDecoys) do
			--	local suc,ers = service.trackTask("_STOPPING_NETWORK-"..decoy.Name:upper(), true, decoy.Disconnect, decoy)
				
			--	if not suc then
			--		warn("Stopping decoy encountered an error: "..tostring(ers))
			--	end
			--end
		end;
		
		getReplicators = function()
			return service.cloneTable(serverReplicators)
		end;
		
		--// Trust check functions
		isPlayerOnTrustCheckWithAnyNetwork = function(player: ParsedPlayer|Player): (boolean, network?)
			local parsedPlayer = (Parser:isParsedPlayer(player) and player) or Parser:apifyPlayer(player)
			
			for i,network in pairs(createdNetworks) do
				if network.active and network:isPlayerOnTrustCheck(parsedPlayer) then
					return true, network
				end
			end
			
			return false
		end,
		
		findTrustKeyInNetworks = function(trustKey: string): (keyData?, network?)
			for i,regNetwork in pairs(createdNetworks) do
				if regNetwork.active then
					for playerId, keyData in pairs(regNetwork.networkKeys) do
						if keyData.id == trustKey and keyData:isActive() then
							return keyData, regNetwork
						end
					end
				end
			end
		end,
		
		addCheckIndexProcess = function(indexProcess)
			assert(type(indexProcess)=='function', "Index process must be a function")
			if not table.find(indexCheckProcesses, indexProcess) then
				table.insert(indexCheckProcesses, indexProcess)
			end
		end,
		
		remCheckIndexProcess = function(indexProcess)
			assert(type(indexProcess)=='function', "Index process must be a function")
			if table.find(indexCheckProcesses, indexProcess) then
				table.remove(indexCheckProcesses, table.find(indexCheckProcesses, indexProcess))
			end
		end;
		
		canIgnoreIndex = function(player: ParsedPlayer, index: string|number): boolean
			local stat = false
			for i, indexProcess in ipairs(indexCheckProcesses) do
				local suc,retStat = service.nonThreadTask(indexProcess, player, index)
				if not suc then
					warn("Index processor "..tostring(indexProcess).." encountered an error while checking index "..tostring(index)..":", retStat)
				else
					if retStat == -1 then
						stat = true
						break
					end
				end
			end
			
			return stat
		end;
	}
end