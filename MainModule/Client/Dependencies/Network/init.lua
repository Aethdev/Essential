--!nocheck

return function(env)
	local client = env.client
	local service = env.service

	local luaParser = client.LuaParser
	local base64 = client.Base64
	local tulirAES = client.TulirAES
	local hashLib = client.HashLib
	local compression = client.Compression

	local base64Encode = base64.encode
	local base64Decode = base64.decode
	
	local safeFunc = service.safeFunction
	local trackTask = service.trackTask
	local encryptStr = service.encryptStr
	local decryptStr = service.decryptStr
	local getRandom = service.getRandom

	local Signal = client.Signal
	local Queue = client.Queue

	local network = {}	
	local Utility;
	
	local function Init()
		Utility = client.Utility		
	end
	
	network.Init = Init
	
	
	local subNetworks = {}

	local endToEndEncryption = false
	local remoteEv, remoteFunc = nil
	local rE_secure, rF_secure = nil
	local remoteEv_Id, remoteFunc_Id = nil	
	local remoteEv_Con = nil
	local remoteFunc_Ev = nil
	local remoteRateLimit = nil
	local subNetTrustChecker_Id = ""
	local clientToServerRemoteKey, serverToClientRemoteKey = "", ""

	local networkReady = false

	local networkConnected = Signal.new()
	local networkAbandoned = Signal.new()
	local networkVerified = Signal.new()
	local subNetworkConnectReady = Signal.new()

	local curEncryptIteration = -1
	local maxEncryptIteration = 0
	local remEncryptKeys = {}
	local mainEncryptKey = ""

	local directory = service.JointsService or service.ReplicatedStorage
	
	local remoteEncryptCompressionConfig = {
		level = 1;
		strategy = "dynamic";
	}
	
	local function encryptRemoteArguments(encryptKey: string, arguments: {[any]: any})
		local encodedString = luaParser.Encode({ arguments })
		encodedString = compression.Deflate.Compress(encodedString, remoteEncryptCompressionConfig)
		local aesEncrypted = tulirAES.encrypt(encryptKey, encodedString, nil, 5)
		return aesEncrypted
	end

	local function decryptRemoteArguments(encryptKey: string, encryptedArgs: string)
		local decryptValue2 = tulirAES.decrypt(encryptKey, encryptedArgs, nil, 5)
		decryptValue2 = compression.Deflate.Decompress(decryptValue2, remoteEncryptCompressionConfig)
		local decryptValue3 = decryptValue2 and luaParser.Decode(decryptValue2)[1]
		return decryptValue3
	end

	local function sortArgumentsWithInstances(arguments: {[any]: any}, instanceList: {[string]: Instance})
		local function getInstanceSignature(str: string)
			return string.match(str, "^\28Instance" .. 0x1E .. "%-(%w+)$")
		end

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

				newClonedTable[i] = if clonedValue then clonedValue else tabValue
			end

			return newClonedTable
		end

		return reverseCloneTableValue(arguments)
	end

	local function convertListToArgumentsAndInstances(...)
		local instanceList, checkedInstances = {}, {}
		local function getNewInstanceId()
			local uuidLen = 14
			local uuid
			repeat
				uuid = getRandom(uuidLen)
			until
			not instanceList[uuid]
			return uuid
		end
		local function createInstanceSignature(instanceId: string)
			return "\28Instance" .. 0x1E.."-"..instanceId
		end
		local function assignInstanceAnId(inst: Instance): string
			if not checkedInstances[inst] then
				local instanceId: string = getNewInstanceId()
				instanceList[instanceId] = inst
				checkedInstances[inst] = instanceId
				return instanceId
			else
				return checkedInstances[inst]
			end
		end
		local function isTableSequential(tab: {[any]: any}) -- Check if the table is sequential from 1 to inf
			--local _didIterate, highestIndex = false, 0
			for index, _ in pairs(tab) do
				--_didIterate = true
				if type(index) ~= "number" or math.floor(index) ~= index or index <= 0 then
					return false
				--elseif index > highestIndex then
				--	highestIndex = index
				end
			end
			
			--for i = 1, #highestIndex, 1 do
			--	if type(tab[i]) == "nil" then
			--		return false
			--	end
			--end

			return true
		end

		local function fillInNilArray(array: {[number]: any})
			local nilSignature = "\28NilValue" .. 0x1E
			local maxIndex = 0

			for index, val in pairs(array) do
				if index > maxIndex then
					maxIndex = index
				end
			end

			local newArray = {}

			if maxIndex > 0 then
				for i = maxIndex, 1, -1 do
					local value = array[i]
					if rawequal(value, nil) then
						newArray[i] = nilSignature
					else
						newArray[i] = value
					end
				end
			end

			return newArray
		end

		local mainTable = fillInNilArray(service.cloneTable({...}))
		local checkedTabValues = {}

		local function cloneTableValue(clonedTable)
			local newClonedTable = {}
			checkedTabValues[clonedTable] = newClonedTable

			for i, tabValue in pairs(clonedTable) do
				local clonedValue = checkedTabValues[tabValue]
				if not clonedValue then
					if type(tabValue) == "table" then
						local oldTabValue = tabValue
						tabValue = cloneTableValue(if isTableSequential(tabValue) then fillInNilArray(tabValue) else tabValue)
						checkedTabValues[oldTabValue] = tabValue
						newClonedTable[i] = tabValue
						continue
					elseif typeof(tabValue) == "Instance" then
						local instanceSignatureId = createInstanceSignature(assignInstanceAnId(tabValue))
						newClonedTable[i] = instanceSignatureId
						continue
					end
				end

				newClonedTable[i] = if clonedValue then clonedValue else tabValue
			end

			return newClonedTable
		end

		return cloneTableValue(mainTable), instanceList
	end

	local function killConnections()
		if rE_secure then
			safeFunc(function() rE_secure:Disconnect() end)()
			rE_secure = nil
		end

		if rF_secure then
			safeFunc(function() rF_secure:Disconnect() end)()
			rF_secure = nil
		end

		if remoteFunc then
			safeFunc(function() remoteFunc.OnClientInvoke = nil end)()
			remoteFunc = nil
		end

		if remoteEv_Con then
			safeFunc(function() remoteEv_Con:Disconnect() end)()
			remoteEv_Con = nil
		end
	end
	
	local function checkIfNetworksAccessible()
		return (remoteEv and remoteEv.Parent == directory) and (remoteFunc and remoteFunc.Parent == directory)
	end

	local function secureNetwork()		
		rE_secure = remoteEv:GetPropertyChangedSignal"Parent":Connect(function()
			local parent = remoteEv.Parent

			if rawequal(parent, nil) then
				killConnections()
				network:search()
			end
		end)

		rF_secure = remoteFunc:GetPropertyChangedSignal"Parent":Connect(function()
			local parent = remoteFunc.Parent

			if rawequal(parent, nil) then
				killConnections()
				network:search()
			end
		end)

		local savedRemoteEv = remoteEv
		local remoteE_Func = function(...)
			if rawequal(savedRemoteEv, remoteEv) and networkReady then
				local remoteArguments = {...}
				if endToEndEncryption then
					local _, encryptedArgs, instanceList = ...
					--warn("Encrypted args:", encryptedArgs)
					if type(encryptedArgs) ~= "string" then return end
					encryptedArgs = decryptRemoteArguments(serverToClientRemoteKey, encryptedArgs)
					--warn("Decrypted args:", encryptedArgs)
					--warn("Instance list:", instanceList)

					if type(encryptedArgs) ~= "table" then return end
					local assortedArguments = sortArgumentsWithInstances(encryptedArgs, instanceList)
					--warn("Assorted arguments:", assortedArguments)
					remoteArguments = {_, unpack(assortedArguments)}
				end
				
				local rets = {service.trackTask("CLIENTNETWORK-NONINVOKED-"..service.getRandom(), false, client.Process.remoteCall, false, unpack(remoteArguments))}

				if not rets[1] then
					warn("Client network encountered an error: "..tostring(rets[2]))
				end
			end
		end

		remoteEv_Con = savedRemoteEv.OnClientEvent:Connect(remoteE_Func)

		local savedRemoteFunc = remoteFunc
		local remoteF_Func = function(...)
			if rawequal(savedRemoteFunc, remoteFunc) and networkReady then
				local remoteArguments = {...}
				if endToEndEncryption then
					local _, encryptedArgs, instanceList = ...
					--warn("Encrypted args:", encryptedArgs)
					if type(encryptedArgs) ~= "string" then return end
					encryptedArgs = decryptRemoteArguments(serverToClientRemoteKey, encryptedArgs)
					--warn("Decrypted args:", encryptedArgs)
					--warn("Instance list:", instanceList)

					if type(encryptedArgs) ~= "table" then return end
					local assortedArguments = sortArgumentsWithInstances(encryptedArgs, instanceList)
					--warn("Assorted arguments:", assortedArguments)
					remoteArguments = {_, unpack(assortedArguments)}
				end
				
				local rets = {service.trackTask("CLIENTNETWORK-INVOKED-"..service.getRandom(), false, client.Process.remoteCall, true, unpack(remoteArguments))}

				if not rets[1] then
					warn("Client network encountered an error: "..tostring(rets[2]))
				else
					return unpack(rets, 2)
				end
			end
		end

		savedRemoteFunc.OnClientInvoke = remoteF_Func

		local remoteCheckName = "REMCHECK-"..service.getRandom()
		service.startLoop(remoteCheckName, true, .5, function()
			if not (rawequal(savedRemoteEv, remoteEv) and rawequal(savedRemoteFunc, remoteFunc)) then
				service.stopLoop(remoteCheckName)
			else
				savedRemoteFunc.OnClientInvoke = remoteF_Func
			end
		end)
	end

	function network:search()
		local ready = Signal.new()

		remoteEv = nil
		remoteFunc = nil

		killConnections()

		if networkReady then
			networkAbandoned:fire(true)
		end

		networkReady = false

		local function canTrust(remoteObject, lookingForRemoteFunc)
			if typeof(remoteObject) == "Instance" then
				local isA = service.objIsA
				local isNetwork = service.getAttribute(remoteObject, "ESSNetwork")

				if isNetwork then
					local isEvent = isA(remoteObject, "RemoteEvent")
					local isFunc = isA(remoteObject, "RemoteFunction")

					if isEvent and not lookingForRemoteFunc then
						return true
					end

					if isFunc and lookingForRemoteFunc then
						return true
					end
				end
			end

			return false
		end

		local function locateRemotes(eventId, funcId)
			local found_remoteEv = false
			local found_remoteFunc = false

			for i,ins in pairs(directory:GetChildren()) do
				local anInstance = typeof(ins)=="Instance"

				if anInstance then
					local attributeId = service.getAttribute(ins, "PublicId")
					attributeId = (type(attributeId)=="string" and attributeId) or nil

					if attributeId then						
						if attributeId == eventId and canTrust(ins, false) then
							remoteEv = ins
							found_remoteEv = true
						end

						if attributeId == funcId and canTrust(ins, true) then
							remoteFunc = ins
							found_remoteFunc = true
						end
					end
				end
			end

			return (found_remoteEv and found_remoteFunc) or false
		end

		local started = os.time()

		repeat
			local success = locateRemotes(remoteEv_Id, remoteFunc_Id)
			if success then
				secureNetwork()
				if network._verified then
					networkReady = true
				end
				network:verify()
				networkConnected:fire()
				break
			else
				wait(2)
			end
		until
		(os.time()-started) > 60
	end

	function network:trustCheck()
		networkReady = false
		killConnections()

		local ready = Signal.new()
		local found = nil

		local function canTrust(remoteObject, lookingForRemoteFunc)
			if typeof(remoteObject) == "Instance" then
				local isA = service.objIsA
				local isNetwork = service.getAttribute(remoteObject, "ESSNetwork")

				if isNetwork then
					local isEvent = isA(remoteObject, "RemoteEvent")
					local isFunc = isA(remoteObject, "RemoteFunction")

					if isEvent and not lookingForRemoteFunc then
						return true
					end

					if isFunc and lookingForRemoteFunc then
						return true
					end
				end
			end

			return false
		end

		local function search()
			local results = {}

			for i,ins in pairs(directory:GetChildren()) do
				local anInstance = typeof(ins) == "Instance"

				if canTrust(ins, false) then
					service.selfEvent(ins.OnClientEvent, function(self, typ, arg)
						if type(typ) == "string" then
							if typ == "TrustCheck" then
								self:Disconnect()

								if type(arg) == "table" and not found then
									local data_remoteEv = rawget(arg, 1)
									local data_remoteFunc = rawget(arg, 2)
									local data_serverRemoteKey = rawget(arg, 3)
									local data_subNetworkTrustCheckerPublicId = rawget(arg, 4)
									local data_endToEndEncryption = rawget(arg, 5)
									local data_remoteRateLimit = rawget(arg, 6)
									
									if type(data_remoteEv) == "string" and type(data_remoteFunc) == "string"
										and type(data_serverRemoteKey) == "string" and type(data_subNetworkTrustCheckerPublicId) == "string"
										and type(data_endToEndEncryption) == "boolean"
										and type(data_remoteRateLimit) == "table" and type(data_remoteRateLimit.Reset) == "number" and data_remoteRateLimit.Reset > 0
										and type(data_remoteRateLimit.Rates) == "number" and data_remoteRateLimit.Rates > 0
									then
										remoteEv_Id = data_remoteEv
										remoteFunc_Id = data_remoteFunc
										subNetTrustChecker_Id = data_subNetworkTrustCheckerPublicId
										endToEndEncryption = data_endToEndEncryption
										remoteRateLimit = data_remoteRateLimit
										
										clientToServerRemoteKey = data_serverRemoteKey
										network.clientToServerRemoteKey = data_serverRemoteKey
										
										found = true

										ready:fire(true)
										network.Joined:fire(true)
										--warn("Found network?")
									end
								end
							end
						end
					end)

					service.fireServer(ins, client.LoadData.VerifyId)
				end
			end
		end

		local started = os.time()

		repeat
			search()

			local success = ready:wait(nil, 30)

			if success then
				network:search()
				break
			end
		until
			found or (os.time()-started) > 300
	end

	function network:getPing(idleTimeout)
		local callStarted = tick()

		local ping = network:customGet(idleTimeout or 300, "Ping")
		if not rawequal(ping, "Pong") then return 400000 end
		local callEnded = tick()
		local pingOs = (callEnded-callStarted)/2
		local ms = service.roundNumber(pingOs*1000, 0.001)
		return ms
	end

	function network:verify()
		if network._verifying or network._verified then return end
		if not checkIfNetworksAccessible() then return network:search() end
		
		network._verifying = true
		serverToClientRemoteKey = service.getRandom(20)
		network.serverToClientRemoteKey = serverToClientRemoteKey 
		--// Create 
		
		local verifyId, newServerRemoteKey = network:_get(nil, "Verify", serverToClientRemoteKey, {
			Rates = client.Process.remoteCall_RateLimit.Rates,
			Reset = client.Process.remoteCall_RateLimit.Reset
		})
		
		if verifyId ~= hashLib.sha1(clientToServerRemoteKey) then
			client.Kill("Main Network did not return the valid verification id. Tamper issue?")
			return
		elseif type(newServerRemoteKey) ~= "string" or #newServerRemoteKey == 0 then
			client.Kill("Main Network did not return a new server remote key. Tamper issue?")
			return
		end
		
		clientToServerRemoteKey = newServerRemoteKey
		
		network._verifying = false
		network._verified = true
		network.Verified:fire(true)
		
		if checkIfNetworksAccessible() then
			networkReady = true
		end
	end

	function network:get(...)
		return network:customGet(600, ...)
		--if not networkReady then
		--	repeat
		--		service.RunService.Stepped:wait()
		--	until
		--		networkReady
		--end

		--local remoteRateLimitData = { Utility:checkRate(remoteRateLimit, "Remote") }
		--local remoteRatePass, remoteRateResetOs = remoteRateLimitData[1], remoteRateLimitData[7]

		--if not remoteRatePass then
		--	wait(remoteRatePass-os.time())
		--	return network:fire(...)
		--end

		--local idleTimeout = 300
		--local retSignal = Signal.new()
		--local arguments = service.unWrap{...}

		--trackTask("_NETWORK-GET", true, function()
		--	local remoteArguments = arguments
		--	if endToEndEncryption then
		--		local filteredArguments, instanceList = convertListToArgumentsAndInstances(arguments)
		--		remoteArguments = {
		--			encryptRemoteArguments(clientToServerRemoteKey, arguments),
		--			instanceList
		--		}
		--	end
			
		--	local rets = {service.invokeServer(remoteFunc, clientToServerRemoteKey, unpack(remoteArguments))}
			
		--	retSignal:fire(unpack(rets))
		--end)
		

		--local stuff = {retSignal:wait(nil, idleTimeout)}
		
		--return unpack(stuff)
	end
	network.Get = network.get

	function network:customGet(idleTimeout, ...)
		if not networkReady then
			repeat
				service.RunService.Stepped:wait()
			until
				networkReady
		end

		local remoteRateLimitData = { Utility:checkRate(remoteRateLimit, "Remote") }
		local remoteRatePass, remoteRateResetOs = remoteRateLimitData[1], remoteRateLimitData[7]

		if not remoteRatePass then
			warn(`CLIENT NETWORK HAS REACHED THE RATE LIMIT OF THE MAIN NETWORK. WAITING {remoteRateResetOs-tick()} SECONDS TO GET DATA.`)
			wait(remoteRateResetOs-tick())
			return network:customGet(...)
		end

		return network:_get(idleTimeout, ...)
	end
	
	function network:_get(idleTimeout: number?, ...)
		local idleTimeout = math.clamp(tonumber(idleTimeout) or 300, 10, 600)
		local retSignal = Signal.new()
		local arguments = service.unWrap{...}

		trackTask("_NETWORK-CUSTOMGET", true, function()
			local remoteArguments = arguments
			if endToEndEncryption then
				local filteredArguments, instanceList = convertListToArgumentsAndInstances(arguments)
				remoteArguments = {
					encryptRemoteArguments(clientToServerRemoteKey, arguments),
					instanceList
				}
			end
			
			local rets = {service.invokeServer(
				remoteFunc,
				if endToEndEncryption then hashLib.sha1(clientToServerRemoteKey) else clientToServerRemoteKey,
				unpack(remoteArguments)
			)}
			retSignal:fire(unpack(rets))
		end)

		return retSignal:wait(nil, idleTimeout)
	end
	
	
	function network:fire(...)
		if not networkReady then
			repeat
				service.RunService.Stepped:wait()
			until
				networkReady
		end
		
		local remoteRateLimitData = { Utility:checkRate(remoteRateLimit, "Remote") }
		local remoteRatePass, remoteRateResetOs = remoteRateLimitData[1], remoteRateLimitData[7]
		
		if not remoteRatePass then
			warn(`CLIENT NETWORK HAS REACHED THE RATE LIMIT OF THE MAIN NETWORK. WAITING {remoteRateResetOs-tick()} SECONDS TO FIRE DATA.`)
			wait(remoteRateResetOs-tick())
			return network:fire(...)
		end
		
		return network:_fire(...)
	end
	network.Fire = network.fire
	
	function network:_fire(...)
		local arguments = service.unWrap{...}

		trackTask("_NETWORK-FIRE", false, function()
			local remoteArguments = arguments
			if endToEndEncryption then
				local filteredArguments, instanceList = convertListToArgumentsAndInstances(arguments)
				remoteArguments = {
					encryptRemoteArguments(clientToServerRemoteKey, arguments),
					instanceList
				}
			end

			service.fireServer(
				remoteEv,
				if endToEndEncryption then hashLib.sha1(clientToServerRemoteKey) else clientToServerRemoteKey,
				unpack(remoteArguments)
			)
		end)
	end
	
	--// Sub networks
	local subNetworkConnectQueue = Queue.new()
	subNetworkConnectQueue.processCooldown = 2
	subNetworkConnectQueue.processFunc = function(ind, que, subNetworkName, subNetworkId)
		local subNetworkEntryKey, subNetworkTrustKey = network:get("RegisterToNetwork", subNetworkId)
		
		if not (subNetworkEntryKey and subNetworkTrustKey) then
			return -2
		else
			local checkRegistry = network:get("CheckNetworkKey", subNetworkId, subNetworkEntryKey)
			
			if not checkRegistry then
				return -3
			else
				local networkInfo = network:get("GetNetworkInfo", subNetworkId, subNetworkEntryKey)
				
				if type(networkInfo) ~= 'table' then
					return -4
				end

				local subNetwork = {}
				subNetwork.active = true
				subNetwork.ready = false
				subNetwork.verified = false
				subNetwork.id = subNetworkId
				subNetwork.entryKey = subNetworkEntryKey
				subNetwork.trustKey = subNetworkTrustKey
				subNetwork.accessKey = service.getRandom(30)
				subNetwork.remoteCall_Allowed = (networkInfo.remoteCall_Allowed and true)
				subNetwork.endToEndEncrypted = (networkInfo.endToEndEncrypted and true)
				subNetwork._invokeObject = nil
				subNetwork._fireObject = nil

				subNetwork.remoteSessions = {}

				subNetwork.triggerError = Signal.new()
				subNetwork.connectError = Signal.new()
				subNetwork.connected = Signal.new()

				subNetwork.processRLEnabled = networkInfo.remoteCall_RLEnabled or false
				subNetwork.processRateLimit = networkInfo.remoteCall_RL or {
					Rates = 300;
					Reset = 120;
				}
				
				subNetwork.serverProcessRLEnabled = networkInfo.processRLEnabled
				subNetwork.serverProcessRateLimit = networkInfo.processRateLimit or {
					Rates = 300;
					Reset = 30;
				}

				subNetwork.networkCommands = {
					FirePlayerEvent = {
						Disabled = false;

						RL_Enabled 	= true;
						RL_Rates 	= 500;
						RL_Reset 	= 10;
						RL_Error	= nil;

						Lockdown_Allowed = false;

						Can_Invoke	= false;
						Can_Fire	= true;

						Function = function(args)
							local eventName = (type(args[1])=="string" and args[1]) or nil
							local existingEvent = eventName and client.Events[eventName]

							if existingEvent and existingEvent.remoteFire and existingEvent.networkId and existingEvent.networkId == subNetworkId then
								existingEvent:fire(unpack(args, 2))
							end
						end;
					};

					TestFunction = {
						Disabled = false;

						RL_Enabled 	= false;
						RL_Rates 	= 500;
						RL_Reset 	= 10;
						RL_Error	= nil;

						Lockdown_Allowed = false;

						Can_Invoke	= true;
						Can_Fire	= true;

						Function = function(args)
							return "test"
						end;
					};
				}

				subNetworks[subNetworkName] = subNetwork

				function subNetwork:fire(...)
					if self.active then
						if not (networkReady and self.ready) then
							repeat
								wait(1)
							until
							not self.active or (networkReady and self.ready)

							if not self.active then
								return
							end
						end
						
						if self.serverProcessRLEnabled then
							local remoteRateLimitData = { Utility:checkRate(self.serverProcessRateLimit, "Remote") }
							local remoteRatePass, remoteRateResetOs = remoteRateLimitData[1], remoteRateLimitData[7]

							if not remoteRatePass then
								warn(`CLIENT SUB NETWORK {self.id} HAS REACHED THE RATE LIMIT OF THE MAIN NETWORK. WAITING {remoteRateResetOs-tick()} SECONDS TO CUSTOM GET DATA.`)
								wait(remoteRateResetOs-tick())
								return self:fire(...)
							end
						end
						
						return self:_fire(...)
					end
				end
				
				function subNetwork:_fire(...)
					if self.active then
						local retSignal = Signal.new()
						local arguments = service.unWrap{...}

						trackTask("_SUBNETWORK-"..tostring(subNetworkId).."-FIRE", true, function()
							local remoteArguments = arguments
							local isETEE = subNetwork.endToEndEncrypted

							if isETEE then
								local filteredArguments, instanceList = convertListToArgumentsAndInstances(arguments)
								remoteArguments = {
									encryptRemoteArguments(subNetwork.entryKey, arguments),
									instanceList
								}
							end
							
							service.fireServer(subNetwork._fireObject,
								if isETEE then hashLib.sha1(subNetwork.entryKey) else subNetwork.entryKey,
								unpack(remoteArguments)
							)
						end)
					end
				end
				
				function subNetwork:get(...)
					return self:customGet(600, ...)
				end

				function subNetwork:_get(idleTimeout: number, ...)
					if self.active then
						local idleTimeout = math.clamp(tonumber(idleTimeout) or 300, 10, 600)
						local retSignal = Signal.new()
						local arguments = service.unWrap{...}

						trackTask("_SUBNETWORK-"..tostring(subNetworkId).."-GET", true, function()
							local remoteArguments = arguments
							local isETEE = subNetwork.endToEndEncrypted
							
							if isETEE then
								local filteredArguments, instanceList = convertListToArgumentsAndInstances(arguments)
								remoteArguments = {
									encryptRemoteArguments(subNetwork.entryKey, arguments),
									instanceList
								}
							end
							
							local ranRets = {service.nonThreadTask(service.invokeServer, subNetwork._invokeObject,
								if isETEE then hashLib.sha1(subNetwork.entryKey) else subNetwork.entryKey,
								unpack(remoteArguments)
							)}
							
							if not ranRets[1] then
								warn("SUB NETWORK "..tostring(subNetworkId).." encountered an error:", ranRets[2])
								retSignal:fire(nil)
							end
							--local rets = {service.invokeServer(subNetwork._invokeObject, subNetwork.entryKey, unpack(arguments))}
							retSignal:fire(unpack(ranRets, 2))
						end)

						return retSignal:wait(nil, idleTimeout)
					end
				end

				function subNetwork:customGet(idleTimeout, ...)
					if self.active then
						if not (networkReady and self.ready) then
							repeat
								wait(1)
							until
								not self.active or (networkReady and self.ready)

							if not self.active then
								return
							end
						end
						
						if self.serverProcessRLEnabled then
							local remoteRateLimitData = { Utility:checkRate(self.serverProcessRateLimit, "Remote") }
							local remoteRatePass, remoteRateResetOs = remoteRateLimitData[1], remoteRateLimitData[7]

							if not remoteRatePass then
								warn(`CLIENT SUB NETWORK {self.id} HAS REACHED THE RATE LIMIT OF THE MAIN NETWORK. WAITING {remoteRateResetOs-tick()} SECONDS TO GET DATA.`)
								wait(remoteRateResetOs-tick())
								return self:customGet(idleTimeout, ...)
							end
						end
						
						return self:_get(idleTimeout, ...)
					end
				end

				function subNetwork:yield(...)
					self:get(...)
				end

				function subNetwork:killSecurity()
					if self._security2 then
						self._security2[1].active = false
						self._security2[2].active = false

						if self._security2[2].Disconnect then
							self._security2[2]:Disconnect()
						end

						self._security2 = nil
					end

					if self._security1 then
						for i, eventData in pairs(self._security1) do
							eventData.active = false

							local connection = eventData.connection

							if connection.Disconnect then
								connection:Disconnect()
							end
						end

						self._security1 = nil
					end
				end

				function subNetwork:makeSecurity()
					self:killSecurity()

					local function makeSecureEvent(rbxEvent, func)
						local eventData; eventData = {
							active = true;
							connection = rbxEvent:Connect(function(...)
								if eventData.active then
									return func(...)
								end
							end)
						}

						return eventData
					end

					local function makeSecureFunc(rbxObject, func)
						local secureLoopId = "SUBNETWORK-"..subNetworkId.."-"..service.getRandom(20)
						local funcData; funcData = {
							active = true;
							rbxFunction = function(...)
								if funcData.active then
									return func(...)
								end
							end;
						}

						rbxObject.OnClientInvoke = funcData.rbxFunction

						service.startLoop(secureLoopId, true, .5, function()
							if not funcData.active then
								service.stopLoop(secureLoopId)
							else
								rbxObject.OnClientInvoke = funcData.rbxFunction
							end
						end)

						return funcData
					end

					local security1 = {}
					local security2 = {}
					local subNetRemoteEv = self._fireObject
					local subNetRemoteFunc = self._invokeObject

					table.insert(security1, makeSecureEvent(subNetRemoteEv:GetPropertyChangedSignal"Parent", function()
						local newParent = subNetRemoteEv.Parent

						if rawequal(newParent, directory) then
							self:killSecurity()
						end
					end))

					table.insert(security1, makeSecureEvent(subNetRemoteFunc:GetPropertyChangedSignal"Parent", function()
						local newParent = subNetRemoteEv.Parent

						if rawequal(newParent, directory) then
							self:killSecurity()
						end
					end))

					local remoteFuncSecure = makeSecureFunc(subNetRemoteFunc, function(accKey, ...)
						if subNetwork.active then
							local expectedAccessKey = if subNetwork.endToEndEncrypted then hashLib.sha1(subNetwork.accessKey) else subNetwork.accessKey
							
							if not rawequal(expectedAccessKey, accKey) then return end
							
							local remoteArguments = {...}
							if subNetwork.endToEndEncrypted then
								local _, encryptedArgs, instanceList = ...
								if type(encryptedArgs) ~= "string" then return end
								encryptedArgs = decryptRemoteArguments(expectedAccessKey, encryptedArgs)

								if type(encryptedArgs) ~= "table" then return end
								local assortedArguments = sortArgumentsWithInstances(encryptedArgs, instanceList)
								remoteArguments = {_, unpack(assortedArguments)}
							end
							
							local taskRets = {service.trackTask("SUBNETWORK_"..subNetworkId.."_INVOKE", false, subNetwork.processRemoteCall, true, unpack(remoteArguments))}
							local success, errMessage = unpack(taskRets)

							if not success then
								warn("SubNetwork "..tostring(subNetworkId).." encountered an error: "..tostring(errMessage))
							end
						end
					end)

					table.insert(security2, remoteFuncSecure)
					table.insert(security2, makeSecureEvent(subNetRemoteEv.OnClientEvent, function(accKey, ...)
						if subNetwork.active then
							local expectedAccessKey = if subNetwork.endToEndEncrypted then hashLib.sha1(subNetwork.accessKey) else subNetwork.accessKey

							if not rawequal(expectedAccessKey, accKey) then return end

							local remoteArguments = {...}
							if subNetwork.endToEndEncrypted then
								local _, encryptedArgs, instanceList = ...
								if type(encryptedArgs) ~= "string" then return end
								encryptedArgs = decryptRemoteArguments(expectedAccessKey, encryptedArgs)

								if type(encryptedArgs) ~= "table" then return end
								local assortedArguments = sortArgumentsWithInstances(encryptedArgs, instanceList)
								remoteArguments = {_, unpack(assortedArguments)}
							end
							
							local taskRets = {service.trackTask("SUBNETWORK_"..subNetworkId.."_NONINVOKE", false, subNetwork.processRemoteCall, false, unpack(remoteArguments))}
							local success, errMessage = unpack(taskRets)

							if not success then
								warn("SubNetwork "..tostring(subNetworkId).." encountered an error: "..tostring(errMessage))
							end
						end
					end))

					self.security1 = security1
					self.security2 = security2
				end

				function subNetwork:trustCheck()
					if self.active and not self.trustChecked then
						local ready = Signal.new()
						local found = nil

						local function findTrustChecker()
							for i,ins in pairs(directory:GetChildren()) do
								local anInstance = typeof(ins)=="Instance"

								if anInstance and ins:IsA"RemoteFunction" then
									local attributeId = service.getAttribute(ins, "PublicId")
									attributeId = (type(attributeId)=="string" and attributeId) or nil

									if attributeId and #attributeId > 0 then						
										if attributeId == subNetTrustChecker_Id then
											return ins
										end
									end
								end
							end
						end

						local function canTrust(remoteObject, lookingForRemoteFunc)
							if typeof(remoteObject) == "Instance" then
								local isA = service.objIsA
								local isNetwork = service.getAttribute(remoteObject, "ESSNetwork")

								if isNetwork then
									local isEvent = isA(remoteObject, "RemoteEvent")
									local isFunc = isA(remoteObject, "RemoteFunction")

									if isEvent and not lookingForRemoteFunc then
										return true
									end

									if isFunc and lookingForRemoteFunc then
										return true
									end
								end
							end

							return false
						end

						local function search()
							local results = {}
							local searchEvents = {}
							local searchStat = "waiting"

							local function killEvents()
								if #searchEvents > 0 then
									for i, event in pairs(searchEvents) do
										if type(event) == "userdata" and event.Connected then
											event:Disconnect()
										end
									end
								end
							end

							local trustCheckerObj: RemoteFunction = findTrustChecker()
							if trustCheckerObj then
								local success, didRegister, data_remoteEv, data_remoteFunc, data_disconnectId = service.nonThreadTask(
									trustCheckerObj.InvokeServer, trustCheckerObj, "TrustCheck", subNetworkId, subNetworkTrustKey
								)

								if success and subNetwork.active then 
									if type(data_remoteEv) == "string" and type(data_remoteFunc) == "string" and type(data_disconnectId) == "string" then
										found = true
										searchStat = "done"
										--killEvents()

										subNetwork.remoteEv_Id = data_remoteEv
										subNetwork.remoteFunc_Id = data_remoteFunc
										subNetwork.disconnectId = data_disconnectId
										subNetwork.trustChecked = true

										--ready:fire(true)
										return true
									end
								end

								return false
							end

							--task.delay(20, function()
							--	if searchStat == "waiting" then
							--		searchStat = "not"

							--		killEvents()
							--	end
							--end)
						end

						local started = os.time()

						repeat
							local success = search()

							if success then
								subNetwork:search()
								break
							else
								wait(30)
							end
						until
						found or not self.active or (os.time()-started) > 300

						if found == nil then
							found = false
						end
					end
				end

				function subNetwork:search()
					if self.active and self.trustChecked then
						local ready = Signal.new()
						local remoteEv_Id = self.remoteEv_Id
						local remoteFunc_Id = self.remoteFunc_Id

						self:killSecurity()
						self.ready = false

						local function canTrust(remoteObject, lookingForRemoteFunc)
							if typeof(remoteObject) == "Instance" then
								local isA = service.objIsA
								local isNetwork = service.getAttribute(remoteObject, "ESSNetwork")

								if isNetwork then

									local isEvent = isA(remoteObject, "RemoteEvent")
									local isFunc = isA(remoteObject, "RemoteFunction")

									if isEvent and not lookingForRemoteFunc then
										return true
									end

									if isFunc and lookingForRemoteFunc then
										return true
									end
								end
							end

							return false
						end

						local function locateRemotes(eventId, funcId)
							local found_remoteEv = false
							local found_remoteFunc = false

							for i,ins in pairs(directory:GetChildren()) do
								local anInstance = typeof(ins)=="Instance"

								if anInstance then
									local attributeId = service.getAttribute(ins, "PublicId")
									attributeId = (type(attributeId)=="string" and attributeId) or nil

									if attributeId then						
										if attributeId == eventId and canTrust(ins, false) then
											subNetwork._fireObject = ins
											found_remoteEv = true
										end

										if attributeId == funcId and canTrust(ins, true) then
											subNetwork._invokeObject = ins
											found_remoteFunc = true
										end
									end
								end
							end

							return (found_remoteEv and found_remoteFunc) or false
						end

						local started = os.time()

						repeat
							local success = locateRemotes(remoteEv_Id, remoteFunc_Id)
							if success then
								self:makeSecurity()
								if subNetwork._verified then
									self.ready = true
									self.connected:fire()
								end
								break
							else
								wait(2)
							end
						until
						not self.active or (os.time()-started) > 60

						if not subNetwork._verified and not self.ready then
							self.connectError:fire()
						end
					end
				end

				function subNetwork:verify()
					if self._verifying or self._verified then return end
					if not self:isAccessible() then return self:search() end
					self._verifying = true
					
					local isETEE = subNetwork.endToEndEncrypted
					local hashedOldEntryKey = hashLib.sha1(self.entryKey)
					
					if not self:isAccessible() then self._verifying = false return self:search() end
					
					local didVerify, hashedOldKey, newPersonalKey = self:_get(300, "Verify", self.accessKey)
					if type(didVerify) ~= "boolean" or not didVerify then
						warn(`SUB NETWORK {subNetwork.id} FAILED TO VERIFY. VERIFY STATUS IS EITHER FALSE OR UNKNOWN TYPE.`)
						return
					elseif isETEE and hashedOldKey ~= hashedOldEntryKey then
						warn(`SUB NETWORK {subNetwork.id} FAILED TO VERIFY. HASHED OLD ENTRY KEY WAS NOT VERIFIED PROPERLY WITH THE RETURNED HASH.`)
						return
					elseif isETEE and (type(newPersonalKey) ~= "string" or #newPersonalKey == 0) then
						warn(`SUB NETWORK {subNetwork.id} FAILED TO VERIFY. NEW PERSONAL KEY WAS NOT RETURNED PROPERLY.`)
						return
					end
					
					self._verifying = false
					self._verified = true
					
					if self:isAccessible() then
						self.ready = true
						self.connected:fire()
					else
						return self:search()
					end
				end
				
				function subNetwork:isAccessible()
					return (self._invokeObject and self._invokeObject.Parent == directory) and
						(self._fireObject and self._fireObject.Parent == directory)
				end

				function subNetwork:canDisconnect(): boolean
					return self:get("CanDisconnect") or false
				end

				function subNetwork:disconnect(sendRequest: boolean?): boolean
					if sendRequest then
						local canDisconnect = self:canDisconnect()

						if not canDisconnect then
							return false
						else
							local didSuccess = self:get("Disconnect", self.disconnectId)
							if not rawequal(didSuccess, true) then
								return false
							end
						end
					end

					if self.active then
						if sendRequest then
							local didSuccess = self:get("Disconnect", self.disconnectId)
							if not rawequal(didSuccess, true) then
								return false
							end
						end
						self.active = false
						self.ready = false
						self:killSecurity()
						subNetworks["."..subNetworkName] = nil
						subNetworks["_"..subNetworkId] = nil
						return true
					else
						return false
					end
				end

				subNetwork.processRemoteCall = function(invoke, ...) 
					if subNetwork.active and subNetwork.ready then
						local rateKey = "Server"
						local remoteArgs = {...}

						local didPassRL = not subNetwork.processRLEnabled or Utility:checkRate(subNetwork.processRateLimit, rateKey)

						if not didPassRL then
							return -202,"Rate_Limit_Exceeded"
						else
							if type(remoteArgs[1]) == "string" then
								local cmdName = remoteArgs[1]
								local remoteCmd = subNetwork.networkCommands[cmdName]

								if remoteCmd and not remoteCmd.Disabled then
									local lockdown = client.lockdown

									if (not lockdown or (lockdown and remoteCmd.Lockdown_Allowed)) then
										local cmdFunction = remoteCmd.Function or remoteCmd.Run or remoteCmd.Execute or remoteCmd.Call
										cmdFunction = (type(cmdFunction)=="function" and cmdFunction) or nil

										if not (remoteCmd.Can_Invoke or remoteCmd.Can_Fire) then
											remoteCmd.Can_Fire = true
										end

										local rL_Enabled 	= remoteCmd.RL_Enabled
										local rL_Rates		= remoteCmd.RL_Rates or 1
										local rL_Reset		= remoteCmd.RL_Reset or 0.01
										local rL_Error		= remoteCmd.RL_Error
										local rL_Data		= remoteCmd.RL_Data or (function()
											local data = {}

											rL_Rates = math.floor(math.abs(rL_Rates))
											rL_Reset = math.abs(rL_Reset)

											rL_Rates = (rL_Rates<1 and 1) or rL_Rates

											remoteCmd.RL_Rates = rL_Rates
											remoteCmd.RL_Reset = rL_Reset

											data.Rates = rL_Rates
											data.Rest = rL_Reset

											remoteCmd.RL_Data = data
											return data
										end)()

										local canUseCommand = (invoke and remoteCmd.Can_Invoke) or (not invoke and remoteCmd.Can_Fire) or false

										if canUseCommand and cmdFunction then
											if rL_Enabled then
												local passCmdRateCheck,curRemoteRate,maxRemoteRate = Utility:checkRate(rL_Data, rateKey)

												if not passCmdRateCheck then
													return (type(rL_Error)=="string" and rL_Error) or nil;
												end
											end

											local rets = {service.trackTask("_REMCOMMAND-"..cmdName.."-Invoke:"..tostring(invoke).."-"..service.getRandom(), false, cmdFunction, {unpack(remoteArgs, 2)})}

											if not rets[1] then
												warn("SubNetwork "..subNetworkId.." Remote command "..cmdName.." encountered an error while running: "..tostring(rets[2]))
												subNetwork.triggerError:fire(remoteCmd, {unpack(remoteArgs, 2)}, rets[2], rets[3])
											else
												if invoke then
													return unpack(rets, 2)
												end
											end
										elseif canUseCommand and not cmdFunction then
											error("Unable to call a remote command without a function", 0)
										end
									end
								end
							end
						end
					end
				end

				subNetwork:trustCheck()
				subNetwork:verify()
				subNetworks["."..subNetworkName] = subNetwork
				subNetworks["_"..subNetworkId] = subNetwork

				return subNetwork
			end
		end
	end

	function network:connectSubNetwork(subNetworkName, subNetworkId)
		local existingNet = network:getSubNetwork(subNetworkName, subNetworkId)

		if existingNet then
			return existingNet
		end
		
		local subNetworkId = subNetworkId or network:get("FindNetwork", subNetworkName)
		
		if not subNetworkId then
			return -1
		else
			local subNetworkQue = subNetworkConnectQueue:add(subNetworkName, subNetworkId)

			local readySignal = Signal.new()
			local processCon; processCon = subNetworkQue.processed:connect(function(didRun, ...)
				if didRun then
					processCon:disconnect()
					readySignal:fire(...)
				end
			end)

			return unpack({readySignal:wait()})
		end
	end

	function network:getSubNetwork(subNetworkName, subNetworkId)
		if subNetworkName and subNetworks["."..subNetworkName] then
			return subNetworks["."..subNetworkName]
		elseif subNetworkId and subNetworks["_"..subNetworkId] then
			return subNetworks["_"..subNetworkId]
		end
	end

	function network:isReady()
		return networkReady
	end
	
	function network:isEndToEndEncrypted()
		return endToEndEncryption
	end
	
	network.Abandoned = networkAbandoned:wrap()
	network.Joined = networkConnected:wrap()
	network.Verified = networkVerified:wrap()

	client.Network = network
end