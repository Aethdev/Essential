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
		level = 3,
		strategy = "dynamic",
	}

	local canWrite, canRead = false, false
	local didLoad, useRealService = false, false
	local readyEv = server.Signal.new()

	local DataStoreService = service.DataStoreService

	local datastoreRetryAttempts = 3
	local datastoreRetryWait = 7

	local datastoreKey, datastoreDefaultScope, datastoreEncryptKeys, datastoreProtectIndex, datastoreEncryptMasterKey, datastoreUseCompression, datastoreUseLegacyHash

	local datastoreGetDS
	local datastoreWriteQueues = {}
	local datastoreTableWriteQueues = {}
	local datastoreTableRemoveQueues = {}
	local datastoreTableChangeQueues = {}
	local datastoreTableUpdateQueues = {}
	local datastoreReadCache = {}
	local datastoreProcess = {}
	local datastoreEncryptScopes = {}
	local globalDatastore

	local Filter = server.Filter
	local Logs = server.Logs
	local Network = server.Network
	local Parser = server.Parser
	local Roles = server.Roles
	local Utility = server.Utility
	local Vela = server.Vela
	local Queue = server.Queue
	local Signal = server.Signal
	local Compression = server.Compression

	local function createHashString(targetString: string, hashType: "key" | "scope"): string
		if datastoreUseLegacyHash then return hashLib.md5(targetString) end

		targetString = `:ES-DATASTORE:` .. (if hashType == "scope" then `S:` else `K:`) .. targetString
		targetString = hashLib.sha1(targetString)

		return targetString
	end

	local Datastore
	local function Init()
		Datastore = server.Datastore

		datastoreProtectIndex = settings.Datastore_ProtectIndex
		datastoreEncryptKeys = datastoreProtectIndex or settings.Datastore_EncryptKeys
		datastoreEncryptMasterKey = settings.Datastore_EncryptKey or "Essential"
		datastoreDefaultScope = settings.Datastore_Scope or hashLib.sha1(`DefaultScope-{datastoreEncryptMasterKey}`)
		datastoreUseCompression = settings.Datastore_Compression or false
		datastoreUseLegacyHash = settings.Datastore_UseLegacyHash or false

		datastoreKey = (datastoreProtectIndex and settings.Datastore_Key:sub(1, 100))
			or settings.Datastore_Key:sub(1, 50)
		datastoreDefaultScope = (datastoreProtectIndex and datastoreDefaultScope:sub(1, 100))
			or datastoreDefaultScope:sub(1, 50)

		datastoreGetDS = Datastore.getDatastore

		-- Hides important settings
		settings.Datastore_EncryptKey = "[annoymous]"
		settings.Datastore_Scope = "[annoymous]"
		settings.Datastore_Key = "[annoymous]"

		if not settings.Datastore_Allow or game.PlaceId <= 0 then
			didLoad = true
			canRead = true
			canWrite = true
			DataStoreService = server.MockDataStoreService
		else
			useRealService = true

			if datastoreEncryptKeys then
				warn "ENCRYPTED DATASTORE KEYS ENABLED"
				server.Logs.addLog(
					"Script",
					"Developer settings has enabled datastore encryption which protects the original scopes and keys exposed."
				)
			else
				server.Logs.addLog(
					"Script",
					"Developer settings doesn't have datastore encryption enabled. Scripts discovering all datastore keys could potentially have access to this system's Roblox datastore."
				)
			end

			if datastoreUseCompression then
				warn "DATASTORE COMPRESSION IS NOW ENABLED. 75% OF THE ORIGINAL DATA IS COMPRESSED THANKS TO ZLIB."
			else
				server.Logs.addLog(
					"Script",
					"Developer settings has setting 'Datastore_Compression' disabled which disallows saving very large data. It is RECOMMENDED to have this enabled always."
				)
				warn "DATASTORE COMPRESSION IS NOT ENABLED. LARGER CHUNKS OF DATA MAY NOT SAVE."
			end

			if datastoreProtectIndex then
				datastoreKey = createHashString(datastoreKey, "key")
				datastoreDefaultScope = createHashString(datastoreDefaultScope, "scope")
			end

			service.trackTask("Loading datastore", true, function()
				local datastoreOpts = service.New "DataStoreOptions"
				datastoreOpts:SetExperimentalFeatures { ["v2"] = true }

				globalDatastore = DataStoreService:GetDataStore(datastoreKey, datastoreDefaultScope, datastoreOpts)

				if globalDatastore then
					local suc, ers = pcall(function()
						globalDatastore:UpdateAsync("__WRITE", function(oldVal) return service.getRandom() end)
					end)

					if suc then
						canRead, canWrite = true, true
					else
						useRealService = false
						DataStoreService = server.MockDataStoreService

						server.Logs.addLog(
							"Script",
							"Developer settings enabled datastore but datastore fails to use UpdateAsync. Retreating to MockDataStoreService.."
						)
						warn "DATASTORE SETTING WAS ENABLED BUT CANNOT BE POSSIBLE DUE TO A FAILURE IN DATASTORE UPDATEASYNC."

						if settings.playerData_Datastore then
							Utility.Notices:createGlobalNotice {
								title = `Datastore Temporarily Unavailable`,
								description = `This game server's datastore services are unavailable at the moment. Your player data will only save and load from the server.`,
								timeDuration = 120,
							}
						end
					end

					didLoad = true
					readyEv:fire()
				end
			end)
		end
	end

	local function determineDataSize(dataValue, customDataSize: number?)
		local maxDataSize = customDataSize or 4_194_304
		local bytes_to_megabytes = 10 ^ -6

		if not dataValue then return 0 end
		return (
			(
				if type(dataValue) == "string"
					then #dataValue
					elseif type(dataValue) == "table" then #luaParser.Encode(dataValue)
					else #tostring(dataValue)
			) * bytes_to_megabytes
		)
			/ maxDataSize
			* 100
	end

	--[[  
	
		DATASTORE UPDATE OEPRATORS
			- Inspired from MongoDB
		
			Query:
			
				$eq - If both values are equal
				$gt - If both values are greater than the specified valuew
				
			Update:
				
				$
	]]

	local function createDatastoreProcess(datastore_scope: string, datastore_key: string, universe_id: boolean?)
		local queueName = (not datastore_scope and "" or datastore_scope) .. "_" .. datastore_key

		if datastoreProcess[queueName] then
			return datastoreProcess[queueName]
		else
			local processData = {
				currentValue = nil,
				valueKey = nil,
				valueUpdated = nil,
			}

			--[[
				WRITE QUE PRIORITY
				
				1 - tableAdd/tableRemove/addUserId/removeUserId
				2 - 
			]]

			local dataDatastore: GlobalDataStore = (not datastore_scope and globalDatastore)
				or datastoreGetDS(datastore_scope)

			local dataWriteQueue = Queue.new()
			dataWriteQueue.id = "DataWrite-[" .. queueName .. "]"
			dataWriteQueue.initialProcessDelay = 1
			--dataWriteQueue.processCooldown = 12
			dataWriteQueue.processCooldown = 10
			--dataWriteQueue.debug = true
			dataWriteQueue.processFunc = function(ind, que)
				if ind == #dataWriteQueue._queue then
					if server.Running then
						if
							processData.valueUpdated
							and tick() - processData.valueUpdated < dataWriteQueue.processCooldown
						then
							wait(math.max(dataWriteQueue.processCooldown - (tick() - processData.valueUpdated), 0))
						end
						wait(Datastore.getRequestDelay "write")
					end

					local function updateCallback(oldVal, dataKeyInfo)
						local realOldVal = oldVal

						if datastoreUseCompression then
							if type(oldVal) == "string" then
								oldVal = base64Decode(oldVal)
								oldVal = compression.Deflate.Decompress(oldVal, compressConfig)
								oldVal = if oldVal ~= nil then luaParser.Decode(oldVal)[1] else nil
							else
								if studioServer and oldVal ~= nil then
									warn "COMPRESSION IS ENABLED. GETASYNC DATA WASN'T A STRING. OOPS! [1]"
								end
								oldVal = nil
							end
						end

						local userIds = (dataKeyInfo and dataKeyInfo:GetUserIds()) or {}
						local metaData = (dataKeyInfo and dataKeyInfo:GetMetadata()) or {}

						for i, que in pairs(dataWriteQueue._queue) do
							local queArguments = que.arguments
							local processType = queArguments[1]

							if processType == "readAndWrite" then
								local listOfUpdateCallbacks = queArguments[2]

								for i, readAndWriteCallback in ipairs(listOfUpdateCallbacks) do
									local reachedEnd = false
									task.spawn(function()
										local success, newValue, newValueKeyInfo =
											service.nonThreadTask(readAndWriteCallback, oldVal, dataKeyInfo)
										if reachedEnd == false then
											reachedEnd = true
											if type(newValue) == "userdata" then
												warn "A DataRead&Write callback returned a user data value. Results were not replaced."
												return
											end
											if not dataKeyInfo and type(newValueKeyInfo) ~= "nil" then
												warn "A DataRead&Write callback returned a custom datastore key while the original datastore key was a nil value. Results were not replaced."
												return
											end
											if
												dataKeyInfo
												and not (
													type(newValueKeyInfo) == "nil"
													or typeof(newValueKeyInfo) == "Instance"
														and newValueKeyInfo:IsA "DataStoreKeyInfo"
												)
											then
												warn "A DataRead&Write callback returned an invalid datastore key info. Results were not replaced."
												return
											end
											if type(newValue) == "table" then
												if service.isTableCircular(newValue) then
													warn "A DataRead&Write callback returned a circular table. Results were not replaced."
													warn(newValue)
													return
												end
												newValue = cloneTable(newValue)
											end
											oldVal = newValue
											dataKeyInfo = newValueKeyInfo or dataKeyInfo
										end
									end)

									if not reachedEnd then
										reachedEnd = -1
										warn "A DataRead&Write callback yielded or didn't finish on time. Returned values were ignored."
									end
								end

								que.processed:fire(true, true)
							end

							if processType == "addUserId" then
								local userId = queArguments[2]

								if not table.find(userIds, userId) then table.insert(userIds, userId) end

								que.processed:fire(true, true)
							end

							if processType == "removeUserId" then
								local userId = queArguments[2]
								local didRemove = false

								local tabInd = table.find(userIds, userId)

								if tabInd then
									table.remove(userIds, tabInd)
									que.processed:fire(true, true)
								end
							end

							if processType == "clearUserIds" then
								table.clear(userIds)
								que.processed:fire(true, true)
							end

							if processType == "updateQuery" then
							end

							if processType == "write" then
								local newValue, newValueKey = queArguments[2], queArguments[3]

								oldVal = newValue
								if newValueKey then dataKeyInfo = newValueKey end
								que.processed:fire(true, true)
							end

							if processType == "tableAdd" then
								local entry, strictForm = queArguments[2], queArguments[3]

								if type(oldVal) == "table" then
									if strictForm then
										local entryId = service.getRandom(12)
										local function checkDuplicateId()
											for i, v in pairs(oldVal) do
												if type(v) == "table" then
													if v.id == entryId then return false end
												end
											end

											return true
										end

										repeat
											if not checkDuplicateId() then entryId = service.getRandom(24) end
										until checkDuplicateId()

										table.insert(oldVal, {
											value = entry,
											id = entryId,
											created = tick(),
										})

										que.processed:fire(true, entryId)
									else
										table.insert(oldVal, entry)
										que.processed:fire(true, true)
									end
								else
									que.processed:fire(true, false)
								end
							end

							if processType == "tableRemove" then
								local remType, remVal, remArg1 = queArguments[2], queArguments[3], queArguments[4]

								if type(oldVal) == "table" then
									if remType == "entryFromId" then
										local didRemove = false

										for ind, tab in pairs(oldVal) do
											if type(tab) == "table" then
												local tabId = tostring(tab.id)

												if tabId ~= "nil" and tabId == remVal then
													oldVal[ind] = nil
													didRemove = true
												end
											end
										end

										if didRemove then
											que.processed:fire(true, true)
										else
											que.processed:fire(true, -1)
										end
									end

									if remType == "singleEntry" then
										local didRemove = false

										for ind, tab in pairs(oldVal) do
											if type(tab) == "table" then
												local tabId = tostring(tab.id)
												local tabValue = tab.value

												if tabValue ~= nil and service.checkEquality(tabValue, remVal) then
													oldVal[ind] = nil
													didRemove = true
													break
												end
											end
										end

										if didRemove then
											que.processed:fire(true, true)
										else
											que.processed:fire(true, -1)
										end
									end

									if remType == "multipleEntry" then
										local didRemove = false

										for ind, tab in pairs(oldVal) do
											if type(tab) == "table" then
												local tabId = tostring(tab.id)
												local tabValue = tab.value

												if tabValue ~= nil and service.checkEquality(tabValue, remVal) then
													oldVal[ind] = nil
													didRemove = true
												end
											end
										end

										if didRemove then
											que.processed:fire(true, true)
										else
											que.processed:fire(true, -1)
										end
									end

									if remType == "singleEntryByMatchingIndexes" then
										local didRemove = false

										for ind, tab in pairs(oldVal) do
											if type(tab) == "table" then
												local tabValue = tab.value

												if type(tabValue) == "table" then
													local didMatch = true

													if next(remVal) then
														for remInd, remValInTab in pairs(remVal) do
															if tabValue[remInd] ~= remValInTab then
																didMatch = false
																break
															end
														end
													else
														didMatch = false
													end

													if didMatch then
														didRemove = true
														oldVal[ind] = nil
														break
													end
												end
											end
										end

										if didRemove then
											que.processed:fire(true, true)
										else
											que.processed:fire(true, -1)
										end
									end

									if remType == "multipleEntryByMatchingIndexes" then
										local didRemove = false

										for ind, tab in pairs(oldVal) do
											if type(tab) == "table" then
												local tabValue = tab.value

												if type(tabValue) == "table" then
													local didMatch = true

													if next(remVal) then
														for remInd, remValInTab in pairs(remVal) do
															if tabValue[remInd] ~= remValInTab then
																didMatch = false
																break
															end
														end
													else
														didMatch = false
													end

													if didMatch then
														didRemove = true
														oldVal[ind] = nil
													end
												end
											end
										end

										if didRemove then
											que.processed:fire(true, true)
										else
											que.processed:fire(true, -1)
										end
									end

									if remType == "value" and type(remVal) ~= "nil" then
										local didRemove = false

										for ind, tabVal in pairs(oldVal) do
											if service.checkEquality(tabVal, remVal) then
												oldVal[ind] = nil
												didRemove = true
											end
										end

										if didRemove then
											que.processed:fire(true, true)
										else
											que.processed:fire(true, -1)
										end
									end

									if
										remType == "valueFromIndex"
										and type(oldVal) == "table"
										and type(remVal) ~= "nil"
									then
										local indexTable = remVal and oldVal[remVal]
										local didRemove = false

										if type(indexTable) == "table" then
											for ind, tabVal in pairs(indexTable) do
												if service.checkEquality(tabVal, remArg1) then
													indexTable[ind] = nil
													didRemove = true
												end
											end
										end

										if didRemove then
											que.processed:fire(true, true)
										else
											que.processed:fire(true, -1)
										end
									end
								else
									que.processed:fire(true, -1)
								end
							end

							if processType == "tableUpdate" then
								local updateType = queArguments[2]

								if type(oldVal) == "table" then
									local didTableUpdate = false

									if updateType == "Index" then
										local updateIndex, updateVal = queArguments[3], queArguments[4]

										oldVal[updateIndex] = updateVal
										didTableUpdate = true
									end

									if updateType == "IndexFromTable" then
										local updTabIndFromData, updTabInd, updDataVal =
											queArguments[3], queArguments[4], queArguments[5]

										if not table.find({ "string", "number" }, type(updTabIndFromData)) then
											continue
										end

										if not table.find({ "string", "number" }, type(updTabInd)) then continue end

										if
											not table.find(
												{ "nil", "number", "boolean", "string", "table" },
												type(updDataVal)
											)
										then
											continue
										end

										local dataVal = oldVal[updTabIndFromData]

										if type(dataVal) == "table" then
											dataVal[updTabInd] = updDataVal
											didTableUpdate = true
										end
									end

									if updateType == "tableAdd" then
										local tabIndex, tabValue, addOverride =
											queArguments[3], queArguments[4], queArguments[5]

										if not table.find({ "string", "number" }, type(tabIndex)) then continue end

										if
											not table.find({ "number", "boolean", "string", "table" }, type(tabValue))
										then
											continue
										end

										local dataVal = oldVal[tabIndex]

										if type(dataVal) == "table" then
											table.insert(dataVal, tabValue)
											didTableUpdate = true
										else
											dataVal = {}
											oldVal[tabIndex] = dataVal
											if addOverride then
												table.insert(dataVal, tabValue)
												didTableUpdate = true
											end
										end
									end

									if not didTableUpdate then
										que.processed:fire(true, false)
									else
										que.processed:fire(true, true)
									end
								else
									que.processed:fire(true, -1)
								end
							end

							--if processType == "tableFind" then
							--	local findingValue, strictForm = queArguments[2], queArguments[3]

							--	if type(oldVal) == "table" then
							--		local didFind = false

							--		for oldValIndex, entry in pairs(oldVal) do
							--			if strictForm then
							--				if type(entry) == "table" then
							--					local entryId = tostring(entry.id)
							--					local entryVal = entry.value

							--					if entryId ~= "nil" and service.checkEquality(entryVal, findingValue) then
							--						didFind = true
							--						que.processed:fire(true, entryId)
							--						break
							--					end
							--				end
							--			else
							--				if service.checkEquality(entry, findingValue) then
							--					didFind = true
							--					que.processed:fire(true, oldValIndex)
							--				end
							--			end
							--		end

							--		if not didFind then
							--			que.processed:fire(true, false)
							--		end
							--	else
							--		que.processed:fire(true, -1)
							--	end
							--end
						end

						if datastoreUseCompression then
							oldVal = luaParser.Encode { oldVal }
							oldVal = compression.Deflate.Compress(oldVal, compressConfig)
							oldVal = base64Encode(oldVal)
						end

						if determineDataSize(oldVal) > 1 then
							oldVal = realOldVal
							dataWriteQueue:warn "Failed to overwrite due to the new data size exceeded 4m bytes."
						end

						processData.currentValue = oldVal

						return oldVal, userIds, metaData
					end

					local failToRetry = true
					for i = 1, datastoreRetryAttempts do
						local suc, newDataValue, dataKeyInfo =
							pcall(dataDatastore.UpdateAsync, dataDatastore, datastore_key, updateCallback)
						if not suc and newDataValue and string.match(newDataValue, "Callback cannot yield") then
							failToRetry = false
							break
						elseif not suc then
							if server.Running then wait(datastoreRetryWait) end
							continue
						end

						failToRetry = false
						processData.valueUpdated = tick()
						processData.valueReadUpdated = processData.valueUpdated
						processData.valueKey = dataKeyInfo
						processData.currentValue = newDataValue
						break
					end

					if failToRetry then
						dataWriteQueue:restart(true)
						return
					end
				else
					return "waitEnd"
				end
			end

			local dataOverWriteQueue = Queue.new()
			dataOverWriteQueue.initialProcessDelay = 1
			dataOverWriteQueue.processCooldown = 8
			--dataOverWriteQueue.processCooldown = 10
			dataOverWriteQueue.processFunc = function(ind, que, value)
				if ind == #dataOverWriteQueue._queue then
					local oldValue = value

					if datastoreUseCompression then
						value = luaParser.Encode { value }
						value = compression.Deflate.Compress(value, compressConfig)
						value = base64Encode(value)
					end

					if determineDataSize(value) > 1 then
						dataOverWriteQueue:warn "Failed to overwrite due to the new data size exceeded 4m bytes."

						for i, otherQue in pairs(dataOverWriteQueue._queue) do
							if i <= ind then otherQue.processed:fire(true, false) end
						end
					else
						for i = 1, datastoreRetryAttempts do
							local success, error = pcall(dataDatastore.SetAsync, dataDatastore, datastore_key, value)

							if success or (not success and i == datastoreRetryAttempts) then
								for i, otherQue in pairs(dataOverWriteQueue._queue) do
									if i <= ind then otherQue.processed:fire(true, (success and true)) end
								end

								break
							elseif not success then
								wait(datastoreRetryWait)
							end
						end
					end
				end
			end

			local dataReadQueue = Queue.new()
			dataReadQueue.id = "DataRead-[" .. queueName .. "]"
			dataReadQueue.initialProcessDelay = 1
			dataReadQueue.processCooldown = 8
			--dataReadQueue.processCooldown = 10
			dataReadQueue.processFunc = function(ind, que, noCache)
				local canUpdate = (noCache and server.Running)
					or not processData.valueUpdated
					or tick() - processData.valueUpdated >= 7
				local cacheData = processData.currentValue
				local cacheKeyInfo = processData.valueKey

				if not canUpdate then
					return cacheData, cacheKeyInfo
				else
					if server.Running then
						if
							processData.valueReadUpdated
							and tick() - processData.valueReadUpdated < dataReadQueue.processCooldown
						then
							task.wait(
								math.max(dataReadQueue.processCooldown - (tick() - processData.valueReadUpdated), 0)
							)
						end
						wait(Datastore.getRequestDelay "read")
					end

					local dtGetOptions: DataStoreGetOptions = service.New "DataStoreGetOptions"
					dtGetOptions.UseCache = false

					local success, dataOrError, keyInfo =
						pcall(dataDatastore.GetAsync, dataDatastore, datastore_key, dtGetOptions)

					if success then
						if datastoreUseCompression then
							if type(dataOrError) == "string" then
								dataOrError = base64Decode(dataOrError)
								dataOrError = compression.Deflate.Decompress(dataOrError, compressConfig)
								dataOrError = if dataOrError then luaParser.Decode(dataOrError)[1] else nil
							else
								if studioServer and dataOrError ~= nil then
									warn(
										"COMPRESSION IS ENABLED. GETASYNC DATA WASN'T A STRING, GOT "
											.. type(dataOrError)
											.. ". OOPS! ["
											.. queueName
											.. "]"
									)
								end
								--warn("Datakey:", datastore_key)
								dataOrError = nil
							end
						end

						if not noCache then
							processData.currentValue = dataOrError
							processData.valueKey = keyInfo
							processData.valueUpdated = tick()
							cacheData = dataOrError
						end
					else
						if not noCache then
							processData.currentValue = cacheData
							processData.valueKey = cacheKeyInfo
							processData.valueUpdated = tick()
						end
					end

					-- If que isn't the last one in the queue
					if
						not noCache
						or not processData.valueReadUpdated
						or (tick() - processData.valueReadUpdated > 7)
					then
						processData.valueReadUpdated = tick()
					end

					if success then
						return dataOrError, keyInfo
					else
						return cacheData, cacheKeyInfo
					end
				end
			end

			local dataReadAndWriteQueue = Queue.new()
			dataReadAndWriteQueue.id = "DataReadAndWrite-[" .. queueName .. "]"
			dataReadAndWriteQueue.initialProcessDelay = 1
			dataReadAndWriteQueue.processCooldown = 8
			dataReadAndWriteQueue.processFunc = function(ind, que)
				if ind == #dataReadAndWriteQueue._queue then
					local listOfUpdateCallbacks = {}
					for i, que in pairs(dataReadAndWriteQueue._queue) do
						table.insert(listOfUpdateCallbacks, que.arguments[1])
					end

					local writeQue = dataWriteQueue:add("readAndWrite", listOfUpdateCallbacks)
					local currentThread = coroutine.running()

					local processConnection
					processConnection = writeQue.processed:connect(function(_, didProcess)
						if didProcess then
							processConnection:disconnect()
							task.spawn(currentThread)
						end
					end)

					coroutine.yield()
				end
			end

			server.Closing:connectOnce(function()
				if #dataReadAndWriteQueue._queue > 0 then
					task.spawn(dataReadAndWriteQueue.process, dataReadAndWriteQueue, true)
				end

				if #dataReadQueue._queue > 0 then task.spawn(dataReadQueue.process, dataReadQueue, true) end

				if #dataWriteQueue._queue > 0 then task.spawn(dataWriteQueue.process, dataWriteQueue, true) end
			end)

			processData.dataWrite = dataWriteQueue
			processData.dataRead = dataReadQueue
			processData.dataOverwrite = dataOverWriteQueue
			processData.dataReadAndWrite = dataReadAndWriteQueue

			datastoreProcess[queueName] = processData
			return processData
		end
	end

	server.Datastore = {
		Init = Init,

		createHashString = createHashString;

		getDatastore = function(scope: string?, useMockService: boolean?)
			if didLoad and scope then
				scope = (datastoreProtectIndex and scope:sub(1, 100)) or scope:sub(1, 50)
				if datastoreProtectIndex then
					local beforeScp = scope
					if not datastoreEncryptScopes[scope] then
						local encrypted = createHashString(scope, "scope")
						datastoreEncryptScopes[scope] = encrypted
						scope = encrypted
					else
						scope = datastoreEncryptScopes[scope]
					end
				end

				local datastoreOpts = service.New "DataStoreOptions"
				datastoreOpts:SetExperimentalFeatures { ["v2"] = true }

				return (if useMockService then server.MockDataStoreService else DataStoreService):GetDataStore(
					datastoreKey,
					scope,
					datastoreOpts
				)
			end
		end,

		getRequestDelay = function(reqType)
			local playersCount = #service.getPlayers()
			local reqPerMin = 60 + playersCount * 10
			local reqBudget = 0

			if reqType == "write" or reqType == "update" then
				reqType = Enum.DataStoreRequestType.UpdateAsync
			elseif reqType == "overwrite" or reqType == "set" then
				reqType = Enum.DataStoreRequestType.SetIncrementAsync
			elseif reqType == "read" or reqType == "get" then
				reqType = Enum.DataStoreRequestType.GetAsync
			elseif reqType == "getSorted" or reqType == "getVersion" or reqType == "remove" then
				reqType = Enum.DataStoreRequestType.GetSortedAsync
				reqPerMin = 5 + playersCount * 2
			end

			local reqDelay = 60 / reqPerMin

			repeat
				reqBudget = DataStoreService:GetRequestBudgetForRequestType(reqType)
			until reqBudget > 0 and task.wait(1)

			return reqDelay + 0.5
		end,

		read = function(scope, key, noCache)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string value", 0)

			if scope then scope = scope:sub(1, 50) end

			key = key:sub(1, 50)
			key = (datastoreEncryptKeys and createHashString(key, "key")) or key

			if not didLoad then readyEv:wait() end

			if didLoad and canRead then
				local dataProcess = createDatastoreProcess(scope, key)

				local canUpdateCache = noCache or not dataProcess.valueUpdated or tick() - dataProcess.valueUpdated >= 7
				local retValue, retValueKey
				if canUpdateCache then
					local readySignal = Signal.new()
					local queData = dataProcess.dataRead:add(noCache)

					local value, valueKey = unpack({ queData.processed:wait(nil, 240) }, 2)

					if type(value) == "table" then value = service.cloneTable(value) end

					retValue, retValueKey = value, valueKey
				else
					retValue, retValueKey = dataProcess.currentValue, dataProcess.valueKey
				end

				--if datastoreUseCompression then
				--	if type(retValue) ~= "string" then
				--		retValue = nil
				--	else

				--	end
				--end

				return retValue, retValueKey
			end
		end,

		overWrite = function(scope, key, value, readyCallback)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string value", 0)

			if scope then scope = scope:sub(1, 50) end

			key = key:sub(1, 50)
			key = (datastoreEncryptKeys and createHashString(key, "key")) or key

			local validVal = table.find({ "number", "boolean", "string", "table" }, type(value))

			if not validVal then
				value = nil
				return Datastore.remove(scope, key)
			else
				value = value
			end

			if not didLoad then readyEv:wait() end

			if didLoad and canWrite and (key and validVal) then
				local writeProcess = createDatastoreProcess(scope, key)
				local writeQue = writeProcess.dataOverwrite:add(value)

				local readySignal = Signal.new()
				local processCon
				processCon = writeQue.processed:connect(function(didRun, stat)
					if didRun and stat == true then
						processCon:disconnect()
						readySignal:fire(true)
					end
				end)

				if readyCallback then readySignal:connectOnce(readyCallback) end
			end
		end,

		write = function(scope, key, value, readyCallback)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string value", 0)

			local validVal = table.find({ "number", "boolean", "string", "table" }, type(value))

			if not validVal then
				value = nil
				error("Value is not a number/boolean/string/table", 0)
			else
				value = value
			end

			if not didLoad then readyEv:wait() end

			if didLoad and canWrite and (key and validVal) then
				if scope then scope = scope:sub(1, 50) end

				key = key:sub(1, 50)
				key = (datastoreEncryptKeys and createHashString(key, "key")) or key

				local writeProcess = createDatastoreProcess(scope, key)
				local writeQue = writeProcess.dataWrite:add("write", value)

				local readySignal = Signal.new()
				local processCon
				processCon = writeQue.processed:connect(function(didRun, didWrite)
					if didRun and didWrite == true then
						processCon:disconnect()
						readySignal:fire(true)
					end
				end)

				if readyCallback then readySignal:connectOnce(readyCallback) end

				return true
			end
		end,

		readAndWrite = function(scope, key, updateCallback, successCallback)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string value", 0)

			updateCallback = (type(updateCallback) == "function" and updateCallback)
				or error("Update callback wasn't a function", 0)

			successCallback = if not successCallback
				then nil
				else (type(successCallback) == "function" and successCallback) or error(
					"Update callback wasn't a function",
					0
				)

			if not didLoad then readyEv:wait() end

			if didLoad and canWrite and key and updateCallback then
				if scope then scope = scope:sub(1, 50) end

				key = key:sub(1, 50)
				local originalKey = key
				key = (datastoreEncryptKeys and createHashString(key, "key")) or key

				local started = os.clock()
				local writeProcess = createDatastoreProcess(scope, key)

				writeProcess.dataReadAndWrite:add(updateCallback)

				return true
			end
		end,

		encryptWrite = function(scope, key, value, encryptKey, readyCallback)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string value", 0)

			local validVal = table.find({ "number", "boolean", "string", "table" }, type(value))

			if not validVal then
				value = nil
				error("Value is not a number/boolean/string/table", 0)
			else
				value = value
			end

			if not didLoad then readyEv:wait() end

			if didLoad and canWrite and (key and validVal) then
				local encryptKey = encryptKey or getRandom(20)

				if scope then scope = scope:sub(1, 50) end

				key = key:sub(1, 50)
				key = (datastoreEncryptKeys and createHashString(key, "key")) or key

				local encryptedValue1 = luaParser.Encode { value }
				local encryptedValue2 = tulirAES.encrypt(encryptKey, encryptedValue1)
				local compressedValue = (datastoreUseCompression and encryptedValue2)
					or compression.Deflate.Compress(encryptedValue2, compressConfig)
				local encryptedValue3 = (datastoreUseCompression and compressedValue) or base64Encode(compressedValue)

				local writeProcess = createDatastoreProcess(scope, key)
				local writeQue = writeProcess.dataWrite:add("write", encryptedValue3)

				local readySignal = Signal.new()
				local processCon
				processCon = writeQue.processed:connect(function(didRun, didWrite)
					if didRun and didWrite == true then
						processCon:disconnect()
						readySignal:fire(true)
					end
				end)

				if readyCallback then readySignal:connectOnce(readyCallback) end

				return true, encryptedValue3, encryptKey
			end
		end,

		encryptRead = function(scope, key, noCache, encryptKey)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string value", 0)

			if scope then scope = scope:sub(1, 50) end

			key = key:sub(1, 50)
			local originalKey = key
			key = (datastoreEncryptKeys and createHashString(key, "key")) or key

			encryptKey = (type(key) == "number" and tostring(encryptKey))
				or (type(encryptKey) == "string" and encryptKey)
				or error("Encrypt key is not a number/string value", 0)

			if not didLoad then readyEv:wait() end

			if didLoad and canRead then
				local dataProcess = createDatastoreProcess(scope, key)

				local canUpdateCache = noCache or not dataProcess.valueUpdated or tick() - dataProcess.valueUpdated >= 7

				if canUpdateCache then
					local readySignal = Signal.new()
					local queData = dataProcess.dataRead:add(noCache)

					local value, valueKey = unpack({ queData.processed:wait(nil, 240) }, 2)
					local valType = type(value)

					if valType ~= "string" then
						--error("Failed to decrypt current value from data key "..originalKey..". Value returned "..valType.." instead of string.", 0)
						return nil, valueKey
					else
						local decryptValue1 = (datastoreUseCompression and value) or base64Decode(value)
						local decompressedValue = (datastoreUseCompression and decryptValue1)
							or compression.Deflate.Decompress(decryptValue1, compressConfig)
						local decryptValue2 = tulirAES.decrypt(encryptKey, decompressedValue)
						local decryptValue3 = decryptValue2 and luaParser.Decode(decryptValue2)[1]
						value = decryptValue3
					end

					return value, valueKey
				else
					local valType, valueKey = type(dataProcess.currentValue), dataProcess.valueKey

					if valType ~= "string" then
						--error("Failed to decrypt this. Value returned "..valType.." instead of string.", 0)
						return nil, valueKey
					else
						local decryptValue1 = (datastoreUseCompression and tostring(dataProcess.currentValue))
							or base64Decode(tostring(dataProcess.currentValue))
						local decompressedValue = (datastoreUseCompression and decryptValue1)
							or compression.Deflate.Decompress(decryptValue1, compressConfig)
						local decryptValue2 = tulirAES.decrypt(encryptKey, decompressedValue)
						local decryptValue3 = decryptValue2 and luaParser.Decode(decryptValue2)[1]

						return decryptValue3, valueKey
					end
				end
			end
		end,

		encryptUpdate = function(scope, key, encryptKey, updateCallback)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope was a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key was not a number/string value", 0)

			updateCallback = (type(updateCallback) == "function" and updateCallback)
				or error("Update callback wasn't a function", 0)

			if not didLoad then readyEv:wait() end

			if didLoad and canWrite and key then
				local encryptKey = encryptKey or getRandom()

				if scope then scope = scope:sub(1, 50) end

				key = key:sub(1, 50)
				local originalKey = key
				key = (datastoreEncryptKeys and createHashString(key, "key")) or key

				local started = os.clock()
				local writeProcess = createDatastoreProcess(scope, key)

				do
					local readySignal = Signal.new()
					local queData = writeProcess.dataRead:add(true)

					local queEvent = queData.processed:connectOnce(function(_, value, valueKey)
						local valType = type(value)

						if valType ~= "string" then
							--error("Failed to decrypt data key "..originalKey..". Value returned "..valType.." instead of string.", 0)
							value = nil
						else
							if
								not pcall(function()
									local decryptValue1 = (datastoreUseCompression and value) or base64Decode(value)
									local decompressedValue = (datastoreUseCompression and decryptValue1)
										or compression.Deflate.Decompress(decryptValue1, compressConfig)
									local decryptValue2 = tulirAES.decrypt(encryptKey, decompressedValue)
									local decryptValue3 = decryptValue2 and luaParser.Decode(decryptValue2)[1]
									value = decryptValue3
								end)
							then
								value = nil
							end
						end

						local newValue, newValueKey = updateCallback(value, valueKey)
						if not table.find({ "number", "boolean", "string", "table", "nil" }, type(newValue)) then
							warn(
								"Datastore encryptUpdate updating key "
									.. originalKey
									.. " didn't return a valid value (expected number/boolean/string/table/nil)"
							)
							return
						end

						do
							local encryptedValue1 = luaParser.Encode { newValue }
							local encryptedValue2 = tulirAES.encrypt(encryptKey, encryptedValue1)
							local compressedValue = (datastoreUseCompression and encryptedValue2)
								or compression.Deflate.Compress(encryptedValue2, compressConfig)
							local encryptedValue3 = (datastoreUseCompression and compressedValue)
								or base64Encode(compressedValue)

							writeProcess.dataWrite:add("write", encryptedValue3, newValueKey)
						end
					end)
					queEvent.debugError = true
				end

				return true, encryptKey
			end
		end,

		remove = function(scope, key)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string value", 0)

			if not didLoad then readyEv:wait() end

			if didLoad and canWrite and key then
				local scopeAndKey = tostring(scope and "S:" .. scope .. "_" or ".") .. key
				local writeDatastore = (not scope and globalDatastore) or Datastore.getDatastore(scope)

				for i = 1, datastoreRetryAttempts do
					wait(Datastore.getRequestDelay "remove")

					local suc, error = pcall(function()
						writeDatastore:RemoveAsync(key)
						datastoreReadCache[scopeAndKey] = {
							lastUpdated = os.time(),
							results = { nil },
							success = true,
						}
					end)

					if not suc then
						wait(5)
					else
						return true
					end
				end
			end
		end,

		tableAdd = function(scope, key, value, strictForm, readyCallback, encryptData)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string value", 0)

			readyCallback = (type(readyCallback) == "function" and readyCallback) or nil

			local validVal = table.find({ "number", "boolean", "string", "table" }, type(value))

			if not validVal then
				value = nil
				error("Value is not a number/boolean/string/table", 0)
			else
				value = value
			end

			if not didLoad then readyEv:wait() end

			if didLoad and (canRead and canWrite) and (key and validVal) then
				if scope then scope = scope:sub(1, 50) end

				key = key:sub(1, 50)
				key = (datastoreEncryptKeys and createHashString(key, "key")) or key

				local writeProcess = createDatastoreProcess(scope, key)
				local writeQue = writeProcess.dataWrite:add("tableAdd", value, strictForm)

				local readySignal = Signal.new()
				local processCon
				processCon = writeQue.processed:connect(function(didRun, valueId)
					if didRun and (not strictForm or strictForm and type(valueId) == "string") then
						processCon:disconnect()
						readySignal:fire(valueId)
					end
				end)

				if readyCallback then readySignal:connectOnce(readyCallback) end

				return true
			end
		end,

		tableRemove = function(scope, key, removeType, removeValue, removeArg1, readyCallback, encryptData)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string", 0)

			readyCallback = (type(readyCallback) == "function" and readyCallback) or nil

			--local validVal = table.find({"number", "boolean", "string", "table"}, type(value))

			--if not validVal then
			--	value = nil
			--	error("Value is not a number/boolean/string/table value", 0)
			--else
			--	value = value
			--end

			if not didLoad then readyEv:wait() end

			if didLoad and (canRead and canWrite) then
				if scope then scope = scope:sub(1, 50) end

				key = key:sub(1, 50)
				key = (datastoreEncryptKeys and createHashString(key, "key")) or key

				local writeProcess = createDatastoreProcess(scope, key)
				local writeQue = writeProcess.dataWrite:add("tableRemove", removeType, removeValue, removeArg1)

				local readySignal = Signal.new()
				local processCon
				processCon = writeQue.processed:connect(function(didRun, didRemove)
					if didRun and didRemove == true then
						processCon:disconnect()
						readySignal:fire(true)
					end
				end)

				if readyCallback then readySignal:connectOnce(readyCallback) end

				return true
			end
		end,

		tableFind = function(scope, key, value, useEncrypt)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string value", 0)

			local validVal = table.find({ "number", "boolean", "string", "table" }, type(value))

			if not validVal then
				value = nil
				error("Value is not a number/boolean/string/table", 0)
			else
				value = value
			end

			if scope then scope = scope:sub(1,50) end

			if not didLoad then readyEv:wait() end

			if didLoad and canRead and (validVal and value) then
				local dataTable = if useEncrypt
					then Datastore.encryptRead(scope, key, false, datastoreEncryptMasterKey)
					else Datastore.read(scope, key)

				if type(dataTable) ~= "table" then dataTable = {} end

				for ind, entryTab in pairs(dataTable) do
					if type(entryTab) == "table" then
						local entryVal = entryTab.value

						if entryVal ~= nil and service.checkEquality(entryVal, value) then return entryTab.id end
					end
				end
			end
		end,

		tableUpdate = function(scope, key, updateType, updateArg1, updateArg2, updateArg3, readyCallback)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string", 0)

			readyCallback = (type(readyCallback) == "function" and readyCallback) or nil

			--local validVal = table.find({"number", "boolean", "string", "table"}, type(value))

			--if not validVal then
			--	value = nil
			--	error("Value is not a number/boolean/string/table value", 0)
			--else
			--	value = value
			--end

			if didLoad and (canRead and canWrite) then
				if scope then scope = scope:sub(1, 50) end

				key = key:sub(1, 50)
				key = (datastoreEncryptKeys and createHashString(key, "key")) or key

				local writeProcess = createDatastoreProcess(scope, key)
				local writeQue =
					writeProcess.dataWrite:add("tableUpdate", updateType, updateArg1, updateArg2, updateArg3)

				if not writeQue then return false end

				local readySignal = Signal.new()
				local processCon
				processCon = writeQue.processed:connect(function(didRun, runStat)
					if didRun and runStat == true then
						processCon:disconnect()
						readySignal:fire(true)
					elseif runStat == -1 then
						processCon:disconnect()
						readySignal:fire(false)
					end
				end)

				if readyCallback then readySignal:connectOnce(readyCallback) end

				return true
			end
		end,

		addUserIdToData = function(scope, key, userId, readyCallback)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string", 0)

			userId = (type(userId) == "number" and math.floor(userId) == userId and userId)
				or error "User id must be an integer"

			readyCallback = (type(readyCallback) == "function" and readyCallback) or nil

			--local validVal = table.find({"number", "boolean", "string", "table"}, type(value))

			--if not validVal then
			--	value = nil
			--	error("Value is not a number/boolean/string/table value", 0)
			--else
			--	value = value
			--end

			if not didLoad then readyEv:wait() end

			if didLoad and (canRead and canWrite) then
				if scope then scope = scope:sub(1, 50) end

				key = key:sub(1, 50)
				key = (datastoreEncryptKeys and createHashString(key, "key")) or key
				userId = math.floor(userId)

				local writeProcess = createDatastoreProcess(scope, key)
				local writeQue = writeProcess.dataWrite:add("addUserId", userId)

				local readySignal = Signal.new()
				local processCon
				processCon = writeQue.processed:connect(function(didRun, runStat)
					if didRun and runStat == true then
						processCon:disconnect()
						readySignal:fire(true)
					end
				end)

				if readyCallback then readySignal:connectOnce(readyCallback) end

				return true
			end
		end,

		remUserIdFromData = function(scope, key, userId, readyCallback)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string", 0)

			userId = (type(userId) == "number" and math.floor(userId) == userId and userId)
				or error "User id must be an integer"

			readyCallback = (type(readyCallback) == "function" and readyCallback) or nil

			--local validVal = table.find({"number", "boolean", "string", "table"}, type(value))

			--if not validVal then
			--	value = nil
			--	error("Value is not a number/boolean/string/table value", 0)
			--else
			--	value = value
			--end

			if not didLoad then readyEv:wait() end

			if didLoad and (canRead and canWrite) then
				if scope then scope = scope:sub(1, 50) end

				key = key:sub(1, 50)
				key = (datastoreEncryptKeys and createHashString(key, "key")) or key
				userId = math.floor(userId)

				local writeProcess = createDatastoreProcess(scope, key)
				local writeQue = writeProcess.dataWrite:add("removeUserId", userId)

				local readySignal = Signal.new()
				local processCon
				processCon = writeQue.processed:connect(function(didRun, runStat)
					if didRun and runStat == true then
						processCon:disconnect()
						readySignal:fire(true)
					end
				end)

				if readyCallback then readySignal:connectOnce(readyCallback) end

				return true
			end
		end,

		clearUserIdsFromData = function(scope, key, readyCallback)
			scope = (type(scope) == "number" and tostring(scope))
				or (type(scope) == "string" and scope)
				or (type(scope) == "userdata" and error("Scope is a userdata value", 0))
				or datastoreDefaultScope

			key = (type(key) == "number" and tostring(key))
				or (type(key) == "string" and key)
				or error("Key is not a number/string", 0)

			readyCallback = (type(readyCallback) == "function" and readyCallback) or nil

			--local validVal = table.find({"number", "boolean", "string", "table"}, type(value))

			--if not validVal then
			--	value = nil
			--	error("Value is not a number/boolean/string/table value", 0)
			--else
			--	value = value
			--end

			if not didLoad then readyEv:wait() end

			if didLoad and (canRead and canWrite) then
				if scope then scope = scope:sub(1, 50) end

				key = key:sub(1, 50)
				key = (datastoreEncryptKeys and createHashString(key, "key")) or key

				local writeProcess = createDatastoreProcess(scope, key)
				local writeQue = writeProcess.dataWrite:add "clearUserIds"

				local readySignal = Signal.new()
				local processCon
				processCon = writeQue.processed:connect(function(didRun, runStat)
					if didRun and runStat == true then
						processCon:disconnect()
						readySignal:fire(true)
					end
				end)

				if readyCallback then readySignal:connectOnce(readyCallback) end

				return true
			end
		end,

		isReady = function() return didLoad end,
		canWrite = function()
			if not didLoad then readyEv:wait() end
			return canWrite
		end,
		canRead = function()
			if not didLoad then readyEv:wait() end
			return canRead
		end,
		isReal = function() return useRealService end,

		readied = service.metaRead(readyEv:wrap()),

		compressConfig = table.freeze(cloneTable(compressConfig)),
	}
end
