return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service

	local settings = server.Settings
	local variables = envArgs.variables

	local hashLib = server.HashLib
	local luaParser = server.LuaParser
	local base64 = server.Base64
	local tulirAES = server.TulirAES
	local compression = server.Compression

	local Signal = server.Signal

	local Filter = server.Filter
	local Network = server.Network
	local Parser = server.Parser
	local Roles = server.Roles
	local Utility = server.Utility
	local Vela = server.Vela
	local PolicyManager = server.PolicyManager

	local addLog
	local getRandom, getRandomV3 = service.getRandom, service.getRandomV3

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

		addLog = Logs.addLog
	end

	local ConnectedSessions = {}
	local PlayerEvents = {}
	local SubNetworks = {}

	local cloneTable = service.cloneTable

	local remoteEncryptCompressionConfig = {
		level = 1,
		strategy = "dynamic",
	}

	local function encryptRemoteArguments(encryptKey: string, arguments: { [any]: any })
		local encodedString = luaParser.Encode { arguments }
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

	local function convertListToArgumentsAndInstances(...)
		local instanceList, checkedInstances = {}, {}
		local function getNewInstanceId()
			local uuidLen = 14
			local uuid
			repeat
				uuid = getRandom(uuidLen)
			until not instanceList[uuid]
			return uuid
		end
		local function createInstanceSignature(instanceId: string) return "\28Instance" .. 0x1E .. "-" .. instanceId end
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
		local function isTableSequential(tab: { [any]: any }) -- Check if the table is sequential from 1 to inf
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

		local function fillInNilArray(array: { [number]: any })
			local nilSignature = "\28NilValue" .. 0x1E
			local maxIndex = 0

			for index, val in pairs(array) do
				if index > maxIndex then maxIndex = index end
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

		local mainTable = fillInNilArray(service.cloneTable { ... })
		local checkedTabValues = {}

		local function cloneTableValue(clonedTable)
			local newClonedTable = {}
			checkedTabValues[clonedTable] = newClonedTable

			for i, tabValue in pairs(clonedTable) do
				local clonedValue = checkedTabValues[tabValue]
				if not clonedValue then
					if type(tabValue) == "table" then
						local oldTabValue = tabValue
						tabValue =
							cloneTableValue(if isTableSequential(tabValue) then fillInNilArray(tabValue) else tabValue)
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

	local function checkTableFormat(tab, formatTable)
		local function checkValue(value, givenType)
			local valueType = type(value)

			if type(givenType) == "table" then
				local isRequired = givenType.__required
				local canTableHaveAnyData = givenType.__any or givenType.__wildcard

				if isRequired and valueType ~= "table" then return false end

				if valueType == "table" then
					for i, subType in givenType do
						if type(i) == "string" and i:sub(1, 2):lower() == "__" then continue end
						if not checkValue(value[i], subType) and not isRequired then return false end
					end

					for i, value in tab do
						if checkValue(value, givenType[i]) == false and not isRequired then return false end
					end
				end

				if not isRequired and valueType ~= "table" and valueType ~= "nil" then return false end

				return true
			else
				if type(givenType) ~= "string" then return -1 end

				local possibleTypes = {}

				if string.find(givenType, "/") then
					possibleTypes = string.split(givenType, "/")
				else
					table.insert(possibleTypes, givenType)
				end

				for i, possibleType in possibleTypes do
					if valueType == possibleType:lower() then return true end
				end

				return false
			end
		end

		for index, indexedType in formatTable do
			if not checkValue(tab[index], indexedType) then return false end
		end

		return true
	end

	local function createLogLibraryFunction(libraryName: string)
		return function(plr)
			local tab = {}
			local playerHasAdmin = Moderation.checkAdmin(plr)

			for
				i,
				logData: {
				title: string,
				desc: string,
				data: { _original: { title: string, desc: string } }?,
			}
			in pairs(Logs.library[libraryName]) do
				local originalData = if logData.data and logData.data._original then logData.data._original else logData
				local belongsToPlayer = originalData.userId == plr.UserId

				table.insert(tab, {
					type = "Log",
					title = if playerHasAdmin or belongsToPlayer then originalData.title else logData.title,
					desc = if playerHasAdmin or belongsToPlayer then originalData.desc else logData.desc,
					sentOs = logData.sentOs,
					sent = logData.sent,
					richText = logData.richText,
				})
			end

			table.sort(tab, function(new, old) return new.sent > old.sent end)

			return tab
		end
	end

	-- REMOTE COMMAND TEMPLATE --
	--[[
		Server:
		
			Remote_Command = {
				Disabled = false; -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true; -- Allow this command to run publicly? This ignores whitelist and permissions.
				
				RL_Enabled 	= false; -- Rate limit enabled?
				RL_Rates 	= 10; -- (interval) (min: 1) Rate amount of requests
				RL_Reset 	= 30; -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error	= nil; -- (string) Error message returned after passing the rate limit
				
				Permissions = nil; -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist 	= {}; -- (table) List of users allowed to call this command
				Blacklist 	= {}; -- (table) List of users denied to call this command
				
				Lockdown_Allowed = false; -- (boolean) Allow this remote command to run during lockdown?
				
				Can_Invoke	= false; -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire	= false; -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT
				
				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					
				end;
			}
		
		Client:
		
			Remote_Command = {
				Disabled = false; -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				
				RL_Enabled 	= false; -- Rate limit enabled?
				RL_Rates 	= 10; -- (interval) (min: 1) Rate amount of requests
				RL_Reset 	= 30; -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error	= nil; -- (string) Error message returned after passing the rate limit
				
				Lockdown_Allowed = false; -- (boolean) Allow this remote command to run during lockdown?
				
				Can_Invoke	= false; -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire	= false; -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT
				
				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					
				end;
			}
	]]

	server.Remote = {
		Init = Init,

		ListData = {
			--[[
				Example = {
					Whitelist = {};
					Permissions = {};
					Function = function(plr)
						
					end;
				}
			]]
			TestData = {
				Whitelist = {},
				Permissions = { "Use_Utility" },
				--RateLimit = {
				--	Rates = 4;
				--	Reset = 30;
				--};

				Function = function(plr)
					return {
						{
							type = "Log",
							title = `what`,
							desc = `what`,
							sentOs = os.clock(),
							sent = 1708223467,
						},
					}
				end,
			},

			Commands = {
				Whitelist = {},
				Permissions = { "Use_Utility" },
				RateLimit = {
					Rates = 4,
					Reset = 30,
				},

				Function = function(plr)
					local availableCmds = {}
					local delimiter = settings.delimiter

					local playerPriority = Roles:getHighestPriority(plr)

					for i, cmd in pairs(Commands.Library) do
						if
							not (cmd.Disabled or (cmd.Hidden and not cmd.DontHideFromList))
							and Core.checkCommandUsability(plr, cmd, true)
						then
							if #cmd.Aliases == 0 then continue end

							local copiedCmd = service.cloneTable(cmd)
							local cmdPrefix = cmd.Prefix

							local concatArguments = {}
							for i, arg in pairs(cmd.Arguments) do
								if type(arg) == "table" then
									table.insert(
										concatArguments,
										Parser:filterForRichText("<" .. tostring(arg.argument or i) .. ">")
									)
								else
									table.insert(concatArguments, Parser:filterForRichText("<" .. tostring(arg) .. ">"))
								end
							end
							concatArguments = table.concat(concatArguments, settings.delimiter)

							copiedCmd.Function = nil

							local mainCommand = cmd.Aliases[1]
							local concatAliases = {}
							if #cmd.Aliases > 1 then
								for i = 2, #cmd.Aliases, 1 do
									local alias = cmd.Aliases[i]
									if not alias then continue end

									local cmdNameWithPrefix = (cmdPrefix .. alias):lower()
									table.insert(concatAliases, Parser:filterForRichText(cmdNameWithPrefix))
								end
							end

							concatAliases = table.concat(concatAliases, ", ")

							local concatRoles = {}
							for i, roleName in (cmd.Roles or {}) do
								local actualRole = Roles:get(roleName)
								if actualRole then
									local hiddenFromList = actualRole.hiddenfromlist
									local hiddenFromLowerRank = actualRole.hidelistfromlowranks

									table.insert(
										concatRoles,
										if not hiddenFromList
												and (not hiddenFromLowerRank or playerPriority >= actualRole.priority)
											then Parser:filterForRichText(roleName)
											else '<i><font color="#4E4D50">hidden</font></i>'
									)
								end
							end
							concatRoles = table.concat(concatRoles, ", ")

							table.insert(availableCmds, {
								type = "Detailed",
								label = `{Parser:filterForRichText(cmdPrefix .. mainCommand)} {concatArguments}`,
								description = table.concat({
									`{Parser:filterForRichText(tostring(cmd.Description))}`,
									`<b>Category</b>: {if cmd.Category
										then Parser:filterForRichText(cmd.Category)
										else "<i>none</i>"}`,
									`<b>Aliases ({#cmd.Aliases - 1})</b>: {if #concatAliases == 0
										then `<i>none</i>`
										else concatAliases}`,
									`<b>Permissions ({#cmd.Permissions})</b>: {table.concat(cmd.Permissions, ", ")}`,
									`<b>Roles ({#cmd.Roles})</b>: {concatRoles}`,
								}, "\n"),
								hideSymbol = false,
								richText = true,
								selectable = true,
							})
						end
					end

					return availableCmds
				end,
			},

			UsedCmds = {
				Whitelist = {},
				Permissions = { "View_Logs" },
				Function = createLogLibraryFunction "Commands",
			},

			Client = {
				Whitelist = {},
				Permissions = { "Manage_Game" },
				Function = createLogLibraryFunction "Client",
			},

			GlobalApi = {
				Whitelist = {},
				Permissions = { "View_Logs" },
				Function = createLogLibraryFunction "Global",
			},

			Remote = {
				Whitelist = {},
				Permissions = { "View_Logs" },
				Function = createLogLibraryFunction "Remote",
			},

			Chat = {
				Whitelist = {},
				Permissions = { "View_Logs" },
				Function = createLogLibraryFunction "Chat",
			},

			PlayerActivity = {
				Whitelist = {},
				Permissions = { "View_Logs" },
				Function = createLogLibraryFunction "PlayerActivity",
			},

			Exploit = {
				Whitelist = {},
				Permissions = { "View_Logs" },
				Function = createLogLibraryFunction "Exploit",
			},

			Admin = {
				Whitelist = {},
				Permissions = { "Manage_Game" },
				Function = createLogLibraryFunction "Admin",
			},

			Process = {
				Whitelist = {},
				Permissions = { "Manage_Game" },
				Function = createLogLibraryFunction "Process",
			},

			Script = {
				Whitelist = {},
				Permissions = { "View_Logs" },
				Function = createLogLibraryFunction "Script",
			},
		},

		Terminal = {
			getCommand = function(msg) end,

			canAccess = function(plr) end,

			commands = {},
		},

		Commands = {
			Disconnect = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 1, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 60, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = nil, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					local reason = tostring(args[1] or `No reason specified`)
					plr:Kick(`Client Request: {reason}`)
				end,
			},

			AddClientLog = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 60, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 60, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = nil, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					local logMessageOrData = args[1]
					local logType = type(logMessageOrData)
					local logTableFormat = {
						title = "string/nil",
						desc = "string/nil",
						group = "string/nil",
						richText = "boolean/nil",
						data = {
							__required = false,
							__any = true,
						},
					}

					if logType == "string" and #logMessageOrData > 0 then
						Logs.addLog("Client", `[{tostring(plr)}]: {logMessageOrData}`)
					elseif logType == "table" then
						Logs.addLog(`Client`, {
							title = if type(logMessageOrData.title) == "string"
									and #logMessageOrData.title > 0
								then `[{tostring(plr)}]: {logMessageOrData.title}`
								else nil,
							desc = if type(logMessageOrData.desc) == "string" and #logMessageOrData.desc > 0
								then logMessageOrData.desc
								else nil,
							group = if type(logMessageOrData.group) == "string"
									and #logMessageOrData.group > 0
								then logMessageOrData.group
								else nil,
							richText = logMessageOrData.richText and true or false,
							data = if type(logMessageOrData.data) == "table" then logMessageOrData.data else nil,
						})
					end
				end,
			},

			GetList = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 12 * 6, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 60, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = nil, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					if type(args[1]) == "string" then
						local listD = Remote.ListData[args[1]]

						if not listD.RateLimit then
							listD.RateLimit = {
								Rates = 10,
								Reset = 10,
							}
						end

						if listD and Utility:checkRate(listD.RateLimit, plr.UserId) then
							local hasPermissionToView = Roles:hasPermissionsFromMember(plr, listD.Permissions)
								or Identity.checkTable(plr, listD.Whitelist)

							if hasPermissionToView then return listD.Function(plr, unpack(args, 2)) end
						end
					end
				end,
			},

			Ping = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 10, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 30, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args) return "Pong" end,
			},

			AllSettings = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 10, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 30, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = { "Manage_Game" }, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					local blockSettings = variables.blockSettings
					local copy = cloneTable(settings)

					for setting, val in pairs(settings) do
						if blockSettings[setting] then settings[setting] = nil end
					end

					return copy
				end,
			},

			GetSettings = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 10, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					local blockSettings = variables.blockSettings
					local list = (type(args[1]) == "table" and args[1]) or {}
					local ret = {}

					for i, setting in pairs(list) do
						if settings[setting] ~= nil and not blockSettings[setting] then
							ret[setting] = settings[setting]
						end
					end

					return ret
				end,
			},

			HasPermissions = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 50, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 10, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					local checkTab = (type(args[1]) == "table" and args[1])
						or (type(args[1]) == "string" and { args[1] })
						or nil

					if checkTab then return Roles:hasPermissionsFromMember(plr, checkTab, args[3]) end
				end,
			},

			HasRoles = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 30, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 10, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					local checkTab: { [any]: any } = (type(args[1]) == "table" and args[1])
						or (type(args[1]) == "string" and { args[1] })
						or nil
					local onlyAcceptOne: boolean = (args[2] and true) or false

					if checkTab then return Roles:checkMemberInRoles(plr, checkTab, onlyAcceptOne) end
				end,
			},

			HasAdmin = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 5, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args) return Moderation.checkAdmin(plr) end,
			},

			Verify = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 5, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					local cliData = Core.clients[plr._object]

					if not cliData.verified then
						assert(type(args[1]) == "string" and #args[1] >= 5, "Client To Server remote key is not valid")
						assert(
							type(args[2]) == "table"
								and type(args[2].Reset) == "number"
								and type(args[2].Rates) == "number",
							"Client's remote rate limit is not valid"
						)

						cliData.clientRemoteKey = args[1]
						plr:setVar("clientRemoteRateLimit", args[2])

						if cliData.tamperedFolder then
							cliData.verified = true
							plr:Kick(
								"Essential:\nFailed to trust check due to tampered folder:\n"
									.. tostring(cliData.tamperedFolderReason)
							)
							return false
						end

						local oldRemoteServerKey = cliData.remoteServerKey

						--// Client receives a new remote server key after verifying
						cliData.remoteServerKey = getRandomV3(math.random(15, 20))

						cliData.verified = true
						cliData.verifiedAt = os.time()

						task.spawn(Process.playerVerified, plr)

						-- Confirm ready
						cliData.ready:fire(true)
						return hashLib.sha1(oldRemoteServerKey), cliData.remoteServerKey
					end
				end,
			},

			CheckIn = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 5, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					local cliData = Core.clients[plr._object]

					if cliData.verified then
						if cliData.checkingIn then
							server.Events.playerCheckIn:fire(plr._object)
						else
							server.Events.securityCheck:fire("VerifyFailed", plr, "without_server_permit")
							plr:Kick "ESSR Detection:\nChecking in without the request from the server"
						end
					end
				end,
			},

			PrivateMessage = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 30, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 10, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					local messageId = args[1]
					local replyMsg = args[2]

					if type(messageId) == "string" and type(replyMsg) == "string" then
						local msgData = variables.privateMessages[messageId]

						if msgData and msgData.receiverId == plr.UserId then
							if msgData.active and not msgData:isExpired() then
								msgData.active = false

								if not msgData.noReply then
									local receiver = msgData.senderId and service.getPlayer(msgData.senderId)

									msgData.replied:fire(replyMsg)
									msgData.replyMessage = replyMsg

									if not msgData.dontMessageSender and receiver then
										local parsedReceiver = server.Parser:apifyPlayer(receiver)
										local safeReply, filteredReply =
											server.Filter:safeString(replyMsg, plr.UserId, receiver.UserId)

										Remote.privateMessage {
											receiver = parsedReceiver,
											sender = plr,
											topic = "From " .. tostring(plr),
											message = Parser:filterForRichText(filteredReply),
											expireOs = msgData.expireOs,
										}
									end
								end
							end
						end
					else
						plr:Kick "Invalid PM arguments"
					end
				end,
			},

			GetAvailableCommands = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 3, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 1, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					local results = {}

					-- IF terminal commands only

					for i, cmd in pairs(Commands.Library) do
						if Core.checkCommandUsability(plr, cmd, true) then
							local copiedCmd = cloneTable(cmd)

							copiedCmd.Function = nil
							results[i] = copiedCmd
						end
					end

					return results
				end,
			},

			ExecuteConsoleCommand = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 12, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					local canExecute = settings.consoleEnabled
						and (settings.consolePublic or Roles:hasPermissionsFromMember(plr, { "Use_Console" }))

					if canExecute then
						if type(args[1]) == "string" and #args[1] > 0 then
							Process.playerCommand(plr, args[1], { console = true })
						end
					end
				end,
			},

			ExecuteConsoleCommandV2 = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 12, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					--to be used anywhere outside of console
					--local canExecute = settings.consoleEnabled and (settings.consolePublic or Roles:hasPermissionsFromMember(plr, {"Use_Console"}))

					--if canExecute then
					local commandId = args[1]
					local commandInputArgs = args[2]

					Process.playerCommand(
						plr,
						nil,
						{ console = true, commandId = commandId, commandInputArgs = commandInputArgs }
					)
					--end
				end,
			},

			GetPlayers = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 5, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 10, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					local isAdmin = args[1]

					if isAdmin and not Moderation.checkAdmin(plr) then return {} end

					local matchingPlayers = {}

					for i, target in service.getPlayers(true) do
						if (isAdmin and Moderation.checkAdmin(target)) or not isAdmin then
							table.insert(matchingPlayers, {
								User_Name = target.Name,
								User_DisplayName = target.DisplayName,
								User_Id = target.UserId,
								User_Object = target._object,
							})
						end
					end

					return matchingPlayers
				end,
			},

			FirePlayerEvent = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 3, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 0.6, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					if type(args[1]) == "string" then
						local foundEvent = (function()
							for i, event in pairs(PlayerEvents) do
								if event.active then
									if
										(event.noName and event.id == args[1])
										or (not event.noName and event.name == args[1])
									then
										return event
									end
								end
							end
						end)()

						-- Check existence and allowed to fire event
						if foundEvent and Identity.checkTable(plr, foundEvent.allowedTriggers) then
							-- Check if event expired
							if not foundEvent.expireOs or foundEvent.expireOs - os.time() > 0 then
								local rateLimit = foundEvent.rateLimit

								if not rateLimit or server.Utility:checkRate(rateLimit, plr.id) then
									foundEvent._event:fire(plr, unpack(args, 2))
								end
							end
						end
					end
				end,
			},

			ConnectPlayerEvent = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 3, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 0.6, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args)
					if type(args[1]) == "string" then
						local foundEvent = (function()
							for i, event in pairs(PlayerEvents) do
								if event.active then
									if
										(event.noName and event.id == args[1])
										or (not event.noName and event.name == args[1])
									then
										return event
									end
								end
							end
						end)()

						-- Check existence and allowed to fire event
						if foundEvent and Identity.checkTable(plr, foundEvent.allowedTriggers) then
						end
					end
				end,
			},

			CheckSession = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 50, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local sessionId = args[1]
					local remoteNetwork = remoteData.network

					if type(sessionId) == "string" then
						local existingSession = ConnectedSessions[sessionId]

						if existingSession and existingSession:isActive() then
							if existingSession.network and remoteNetwork ~= existingSession.network then return end

							if existingSession:hasPermission(plr) then return true end
						end
					end
				end,
			},

			ConnectSession = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 3, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 0.6, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local sessionId = args[1]
					local playerFireKey = args[2]
					local expireDuration = math.clamp(tonumber(args[3]) or 0, 0, 18000)
					local remoteNetwork = remoteData.network

					if
						type(sessionId) == "string"
						and type(playerFireKey) == "string"
						and (#playerFireKey <= 40 and #playerFireKey >= 20)
					then
						local existingSession = ConnectedSessions[sessionId]

						if existingSession and existingSession:isActive() then
							if existingSession.network and remoteNetwork ~= existingSession.network then return end

							local currentConnectData = existingSession.selfConnectedPlayers[plr]
							local canConnect = existingSession.canConnect
								and (
									not currentConnectData
									or (currentConnectData.expireOs and os.time() - currentConnectData.expireOs >= 0)
								)

							if canConnect then
								if currentConnectData then
									currentConnectData.active = false
									currentConnectData.playerLeftEvent:disconnect()
									existingSession.playerDisconnected:fire(plr, currentConnectData)
									plr:sendData("FirePlayerEvent", currentConnectData.fireId, "abandoned")
								end

								local currentOs = os.time()
								local selfConnectData
								selfConnectData = {
									active = true,
									player = plr,
									expireOs = (expireDuration > 0 and currentOs + expireDuration) or nil,
									fireId = playerFireKey,
									started = currentOs,
								}

								selfConnectData.playerLeftEvent = plr.disconnected:selfConnect(function(self)
									self:disconnect()
									selfConnectData.active = false
									existingSession.selfConnectedPlayers[plr] = nil
									existingSession.playerDisconnected:fire(plr, currentConnectData)
									plr:sendData("FirePlayerEvent", currentConnectData.fireId, "disconnected")
								end)

								existingSession.selfConnectedPlayers[plr] = selfConnectData
								existingSession.playerConnected:fire(plr, selfConnectData)
								return true
							end
						end
					end
				end,
			},

			DisconnectSession = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 3, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 0.6, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local sessionId = args[1]
					local remoteNetwork = remoteData.network

					if type(sessionId) == "string" then
						local existingSession = ConnectedSessions[sessionId]

						if existingSession and existingSession:isActive() and existingSession:hasPermission(plr) then
							if existingSession.network and remoteNetwork ~= existingSession.network then return end

							local currentConnectData = existingSession.selfConnectedPlayers[plr]

							if currentConnectData then
								currentConnectData.active = false
								currentConnectData.playerLeftEvent:disconnect()
								existingSession.selfConnectedPlayers[plr] = nil
								existingSession.playerDisconnected:fire(plr, currentConnectData)
								return true
							end
						end
					end
				end,
			},

			ManageSession = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 3, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 0.6, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local invokedCall = remoteData.invoked
					local remoteNetwork = remoteData.network
					local remoteNetworkName = if remoteNetwork then remoteNetwork.name else `_MAINNETWORK_`

					local sessionId = args[1]
					local manageType = args[2]

					if type(sessionId) == "string" then
						local existingSession = ConnectedSessions[sessionId]

						if existingSession and existingSession:isActive() then
							local sessionNetwork = existingSession.network

							if remoteNetwork and sessionNetwork ~= remoteNetwork then return "Invalid_Network" end

							-- Check if connected to session
							local connectedPlayers = existingSession.connectedPlayers
							local allowedTriggers = existingSession.allowedTriggers

							if existingSession:hasPermission(plr) then
								if manageType == "FireEvent" and not invokedCall then
									-- Check existence
									local eventId = tostring(args[3])
									local existingEvent = existingSession.events[eventId]

									if existingEvent and existingEvent.active then
										-- Check permissions
										local eventAllowedTriggers = existingEvent.allowedTriggers
										local eventConnectedPlayers = existingEvent.connectedPlayers

										if existingEvent.canFire and existingEvent:hasPermission(plr) then
											existingEvent._event:fire(plr, unpack(args, 4))
										end
									end
								elseif manageType == "GetEvent" and invokedCall then
									for i, event in pairs(existingSession.events) do
										if (event.name and event.name == args[3]) or event.id == args[3] then
											return event
										end
									end
								elseif manageType == "ConnectEvent" and invokedCall then
									local eventId = tostring(args[3])
									local existingEv = existingSession.events[eventId]

									if
										existingEv
										and existingEv:isActive()
										and existingEv:hasPermission(plr)
										and existingEv.canConnect
									then
										local playerFireId = tostring(args[4])
										local expireDuration = math.clamp(tonumber(args[5]) or 0, 0, 18000)

										if #playerFireId < 20 then
											error "Fire connection id must have at least 20 characters"
										else
											local connectData = existingEv:makeConnection(
												plr,
												playerFireId,
												(expireDuration > 0 and os.time() + expireDuration) or nil
											)

											if connectData == -1 then
												--error("Max connections reached for event "..eventId.." ("..tostring(existingEv.maxPlayerConnections)..")", 0)
												return -1
											end

											return connectData.disconnectId
										end
									end
								elseif manageType == "DisconnectEvent" then
									local eventId = tostring(args[3])
									local existingEv = existingSession.events[eventId]
									local disconnectId = (type(args[4]) == "string" and args[4]) or nil

									if existingEv and existingEv:isActive() then
										local playerEvents = {}

										for i, connectionData in pairs(existingEv.playerConnections) do
											local conPlayer = connectionData.player

											if conPlayer == plr then table.insert(playerEvents, connectionData) end
										end

										if #playerEvents > 0 then
											local didKill = existingEv:killConnections(plr.UserId, disconnectId)

											if didKill then return true end
										end
									end
								elseif manageType == "KillEvents" and not invokedCall then
									local eventId = (type(args[3]) == "string" and args[3]) or nil
									local existingEv = eventId and existingSession.events[eventId]

									if not eventId then
										for eventId, eventData in pairs(existingSession.events) do
											eventData:killConnections(plr.UserId)
										end
									else
										if existingEv then
											local playerConnections = existingEv:getConnections(plr)
											if #playerConnections > 0 then existingEv:killConnections(plr.UserId) end
										end
									end
								elseif manageType == "RunCommand" then
									local commandId = tostring(args[3])
									local existingCmd = existingSession.commands[commandId]

									if existingCmd and existingCmd.active then
										-- Check call type
										local canInvoke = existingCmd.canInvoke
										local canFire = existingCmd.canFire

										local cmdFunction = existingCmd.execute

										if (invokedCall and canInvoke) or (not invokedCall and canFire) then
											-- Check permissions
											local allowedTriggers = existingCmd.allowedTriggers
											local cmdConnectedPlayers = existingCmd.connectedPlayers or {}

											if
												Identity.checkTable(plr, allowedTriggers) or cmdConnectedPlayers[plr]
											then
												local cmdFuncRets = {
													service.trackTask(
														"_SESSION-"
															.. sessionId
															.. "-CMD-"
															.. existingCmd.id:upper()
															.. "-"
															.. plr.UserId,
														false,
														cmdFunction,
														plr,
														unpack(args, 4)
													),
												}
												local success, error, errTrace =
													cmdFuncRets[1], cmdFuncRets[2], cmdFuncRets[3]

												if not success then
													warn(
														"Session "
															.. sessionId
															.. ", command "
															.. existingCmd.id
															.. " encountered an error: "
															.. tostring(error or "[Unknown error]")
													)
													warn(errTrace)
												elseif success and invokedCall then
													return unpack(cmdFuncRets, 2)
												end
											else
												warn "Forbidden command"
											end
										end
									end
								elseif manageType == "GetCommand" and invokedCall then
									for i, cmd in pairs(existingSession.commands) do
										if (cmd.name and cmd.name == args[3]) or cmd.id == args[3] then return cmd end
									end
								end
							end
						end
					else
						plr:Kick "Invalid session data"
					end
				end,
			},

			FindSession = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 50, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local remoteNetwork = remoteData.network

					if type(args[1]) == "string" then
						for sessId, sessionData in pairs(ConnectedSessions) do
							local easyFind = rawget(sessionData, "easyFind")

							if easyFind then
								local sessionNetwork = sessionData.network
								local sessionName = sessionData.name

								if sessionNetwork and remoteNetwork ~= sessionNetwork then continue end

								if sessionName and rawequal(sessionName, args[1]) then return sessId end
							end
						end
					end
				end,
			},

			HelpAssist = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 30, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					if args[1] == "Setting" and settings.helpEnabled then
						local helpAssistDeb = service.Debounce("HelpAssist-" .. plr.UserId, function()
							local osTime = os.time()
							local timeTable = Parser:getTime(osTime)
							local formatTime = Parser:formatTime(timeTable.hours, timeTable.mins, timeTable.secs)
							local helpMessage = Parser:replaceStringWithDictionary(tostring(settings.helpMessage), {
								["{player}"] = plr.Name .. " (" .. plr.DisplayName .. ")",
								["{reason}"] = tostring(args[2] or "undefined"),
								["{osTime}"] = osTime,
								["{regTime}"] = formatTime,
								["{date}"] = Parser:osDate(osTime),
							})

							local agentCount = 0
							for i, otherPlr in pairs(service.getPlayers(true)) do
								local helpAgent = Roles:hasPermissionFromMember(otherPlr, { "Help_Assistance" })

								if helpAgent then
									agentCount = agentCount + 1
									coroutine.wrap(function()
										local openedNotif = otherPlr:makeUIGet("Notification", {
											title = "Help System",
											desc = helpMessage,
											time = settings.helpDuration,
										})

										if openedNotif then
											local targetChar = otherPlr.Character
											local playerChar = plr.Character

											if playerChar and targetChar then
												local targetHrp = targetChar:FindFirstChild "HumanoidRootPart"
													or targetChar:FindFirstChild "Torso"
												local playerHrp = playerChar:FindFirstChild "HumanoidRootPart"
													or playerChar:FindFirstChild "Torso"

												if
													(targetHrp and targetHrp:IsA "BasePart")
													and (playerHrp and playerHrp:IsA "BasePart")
												then
													playerHrp.CFrame = (
														targetHrp.CFrame + (targetHrp.CFrame.LookVector * 2)
													) * CFrame.Angles(0, math.rad(180), 0)
													plr:makeUI("Notification", {
														title = "Teleportation success",
														desc = "Teleported you to " .. otherPlr.Name,
														time = 2,
													})
												else
													plr:makeUI("Notification", {
														title = "Teleportation failed",
														desc = "You or "
															.. otherPlr.Name
															.. " didn't have a valid character",
														time = 2,
													})
												end
											end
										end
									end)()
								end
							end

							if agentCount == 0 then
								plr:makeUI("Notification", {
									title = "Help System",
									desc = "Unable to call help assistance due to no support agents nearby. Try calling later!",
									noWait = true,
								})
							end

							wait(math.clamp(settings.helpCooldown or 0, 10, math.huge))
						end)

						if helpAssistDeb == false then
							plr:makeUI("Notification", {
								title = "Help System",
								desc = "Unable to call help assistance. Try again later!",
								noWait = true,
							})
						end
					end
				end,
			},

			ManageLighting = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = false, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 30, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					if args[1] == "ClockTime" and type(args[2]) == "number" then
						service.Lighting.ClockTime = math.clamp(args[2], 0, 24)
					end
				end,
			},

			-- Messages

			GetMessages = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 30, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local pData = plr:getPData()
					return if pData.__messages then pData.__messages._table else {}
				end,
			},

			ManageClientSettings = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 30, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local pData = plr:getPData()
					local clientSettings = pData.__clientSettings

					local setting, settingVal = args[1], args[2]
					local ignoreValTypes = { "userdata" }

					if table.find(ignoreValTypes, type(settingVal)) then return end

					if type(setting) == "string" and clientSettings[setting] ~= settingVal then
						clientSettings[setting] = settingVal
						clientSettings._reviveIfDead()
					end
				end,
			},

			GetClientSettings = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 30, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local pData = plr:getPData()
					local clientSettings = pData.__clientSettings

					return clientSettings._table
				end,
			},

			ManageMusicPlayer = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = false, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 30, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = { "Manage_MusicPlayer" }, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local validTypes = {
						Pitch = "number",
						Volume = "number",
						TimePosition = "number",
					}

					if type(args[1]) == "string" and validTypes[args[1]] then
						local ingameMusic = Utility:getMainSound()

						if ingameMusic and type(args[2]) == validTypes[args[1]] then
							if args[1] == "Volume" then args[2] = math.clamp(args[2], 0, 10) end

							ingameMusic[args[1]] = args[2]
							return true
						end
					end
				end,
			},

			RejoinServer = {
				Disabled = not variables.privateServerData
					and (server.Studio or game.PrivateServerOwnerId > 0)
					and true, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 30, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local debounceRets = {
						service.debounce("Rejoin server - " .. plr.playerId, function()
							if variables.privateServerData or not (server.Studio or game.PrivateServerOwnerId > 0) then
								local cliData = plr:getClientData()
								local privateServerData = variables.privateServerData

								if cliData and tick() - cliData.joined >= 15 then
									local teleportOpts = service.New "TeleportOptions"

									local failSignal = Signal.new()
									local function errCallback(errType) failSignal:fire(false) end

									if privateServerData then
										plr:teleportToReserveWithSignature(
											privateServerData.details.serverAccessId,
											errCallback
										)
									else
										plr:teleportToServer(game.JobId, errCallback)
									end

									local failSignal = Signal.new()
									local didFail = failSignal:wait(nil, 180)

									if didFail then
										return false
									else
										return true
									end
								end
							end
						end),
					}

					return unpack(debounceRets, 2)
				end,
			},

			CanRejoinServer = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 30, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					if variables.privateServerData then return true end

					return not (server.Studio or game.PrivateServerOwnerId > 0)
				end,
			},

			ManageServer = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = false, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 30, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = { "Manage_Game" }, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local actionType = args[1]

					if actionType == "Shutdown" then
						local reason = args[2]
						Utility:shutdown(reason, nil, plr.UserId)
					end
				end,
			},

			--// Network finder & management
			FindNetwork = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 50, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					if type(args[1]) == "string" then
						for originalName, subNetwork in pairs(SubNetworks) do
							if subNetwork and subNetwork.active then
								local easyFind = rawget(subNetwork, "easyFind")
								local subNetworkName = rawget(subNetwork, "name")

								if
									easyFind
									and subNetworkName
									and (subNetworkName == args[1] or originalName == args[1])
								then
									return subNetwork.id
								end
							end
						end
					end
				end,
			},

			RegisterToNetwork = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 100, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 30, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					if type(args[1]) == "string" then
						for netId, subNetwork in pairs(SubNetworks) do
							if subNetwork and subNetwork.active and subNetwork.id == args[1] then
								if
									not table.find(subNetwork.disallowedPlayerIds, plr.playerId)
									and (
										subNetwork.joinable
										or subNetwork.connectedPlayers[plr]
										or Identity.checkTable(plr, subNetwork.allowedTriggers)
									)
								then
									local keyInfo = subNetwork:getPlayerKey(plr)

									if keyInfo then
										return keyInfo.id, keyInfo.trustKey
									else
										local playerKeyId, keyInfo = subNetwork:createPlayerKey(plr)
										keyInfo.selfCreated = true

										return playerKeyId, keyInfo.trustKey
									end
								end
							end
						end
					end
				end,
			},

			RegisterNetworkTrustCheck = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 60, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 30, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local subNetworkId = args[1]

					if type(args[1]) == "string" then
						local subNetwork = (function()
							for i, subNetwork in pairs(SubNetworks) do
								if subNetwork.id == args[1] then return subNetwork end
							end
						end)()

						if subNetwork then
							local keyInfo = subNetwork:getPlayerKey(plr)
							if keyInfo then
							end
						end
					end
				end,
			},

			CheckNetworkKey = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 100, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 30, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					if type(args[1]) == "string" and type(args[2]) == "string" then
						local subNetwork = (function()
							for i, subNetwork in pairs(SubNetworks) do
								if subNetwork.id == args[1] then return subNetwork end
							end
						end)()

						if subNetwork then
							local keyInfo = subNetwork:getPlayerKey(plr)

							return (keyInfo and keyInfo:isActive() and keyInfo.id == args[2])
						end
					end
				end,
			},

			GetNetworkInfo = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 100, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 30, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					if type(args[1]) == "string" and type(args[2]) == "string" then
						local subNetwork = (function()
							for i, subNetwork in pairs(SubNetworks) do
								if subNetwork.id == args[1] then return subNetwork end
							end
						end)()

						if subNetwork then
							local keyInfo = subNetwork:getPlayerKey(plr)

							if keyInfo and keyInfo:isActive() and keyInfo.id == args[2] then
								return {
									id = subNetwork.id,

									invokeId = subNetwork._network1.publicId,
									fireId = subNetwork._network2.publicId,
									remoteCall_Allowed = subNetwork.remoteCall_Allowed,
									remoteCall_RLEnabled = subNetwork.remoteCall_RLEnabled,
									remoteCall_RL = {
										Rates = subNetwork.remoteCall_RL.Rates,
										Reset = subNetwork.remoteCall_RL.Reset,
									},
									processRLEnabled = subNetwork.processRLEnabled,
									processRateLimit = {
										Rates = subNetwork.processRateLimit.Rates,
										Reset = subNetwork.processRateLimit.Reset,
									},
									endToEndEncrypted = subNetwork.securitySettings.endToEndEncrypted,
								}
							end
						end
					end
				end,
			},

			--// Aliases & shortcuts
			CreateCommandAlias = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local alias, cmdLine = args[1], args[2]
					local playerSetsLimits = Process.playerSettingsLimits

					if type(alias) == "string" and type(cmdLine) == "string" then
						local shortenAlias = Parser:trimString(alias)
						local shortenCmdLine = Parser:trimString(cmdLine)

						if
							(#shortenAlias >= 2 and #shortenAlias <= playerSetsLimits.AliasNameCharLimit)
							and (
								#shortenCmdLine > 0
								and #shortenCmdLine <= playerSetsLimits.AliasAndShortcutCmdLineCharLimit
							)
						then
							local pData = plr:getPData()
							local selfActionAliases = pData.__aliases
							local cmdBatchSeparator = settings.batchSeperator or "|"
							local aliasCreationCount = service.tableCount(selfActionAliases._table)

							if aliasCreationCount + 1 > playerSetsLimits.MaxAliasCreation then return -1 end

							if selfActionAliases[shortenAlias:lower()] then
								return -2
							else
								if not Filter:safeString(shortenAlias, plr.UserId) then return -2.5 end

								if shortenAlias:find(cmdBatchSeparator) then return -3 end

								local commandFromAliasName = Commands.get(shortenAlias)
								if commandFromAliasName then return -4 end

								selfActionAliases[shortenAlias:lower()] = cmdLine

								return true
							end
						end
					end

					return 0
				end,
			},

			UpdateCommandAlias = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local alias, cmdLine = args[1], args[2]
					local playerSetsLimits = Process.playerSettingsLimits

					if type(alias) == "string" and type(cmdLine) == "string" then
						local shortenAlias = Parser:trimString(alias)
						local shortenCmdLine = Parser:trimString(cmdLine)

						if
							(#shortenAlias >= 2 and #shortenAlias <= playerSetsLimits.AliasNameCharLimit)
							and (
								#shortenCmdLine > 0
								and #shortenCmdLine <= playerSetsLimits.AliasAndShortcutCmdLineCharLimit
							)
						then
							local pData = plr:getPData()
							local selfActionAliases = pData.__aliases

							if selfActionAliases[shortenAlias:lower()] then
								selfActionAliases[shortenAlias:lower()] = cmdLine

								return true
							else
								return -2
							end
						end
					end

					return 0
				end,
			},

			DeleteCommandAlias = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 100, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 30, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local alias = args[1]
					local playerSetsLimits = Process.playerSettingsLimits

					if type(alias) == "string" then
						local pData = plr:getPData()
						local cmdAliases = pData.__aliases

						local shortenAlias = Parser:trimString(alias)

						if not cmdAliases[shortenAlias:lower()] then
							return -1
						else
							cmdAliases[shortenAlias:lower()] = nil

							return true
						end
					end

					return 0
				end,
			},

			GetCommandAliases = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 100, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 30, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local pData = plr:getPData()
					local cmdAliases = pData.__aliases._table

					return cmdAliases
				end,
			},

			CreateCommandButton = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local shortcutName, cmdLine = args[1], args[2]
					local playerSetsLimits = Process.playerSettingsLimits

					if type(shortcutName) == "string" and type(cmdLine) == "string" then
						local shortenShortcutName = Parser:trimString(shortcutName)
						local shortenCmdLine = Parser:trimString(cmdLine)

						if
							(
								#shortenShortcutName >= 2
								and #shortenShortcutName <= playerSetsLimits.ShortcutNameCharLimit
							)
							and (
								#shortenCmdLine > 0
								and #shortenCmdLine <= playerSetsLimits.AliasAndShortcutCmdLineCharLimit
							)
						then
							local pData = plr:getPData()
							local selfCmdShortcuts = pData.__shortcuts
							local shortcutCreationCount = service.tableCount(selfCmdShortcuts._table)

							if shortcutCreationCount + 1 > playerSetsLimits.MaxShortcutCreation then return -1 end

							if selfCmdShortcuts[shortenShortcutName] then
								return -2
							else
								if not Filter:safeString(shortenShortcutName, plr.UserId) then return -2.5 end

								selfCmdShortcuts[shortenShortcutName] = cmdLine

								return true
							end
						end
					end

					return 0
				end,
			},

			UpdateCommandButton = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local shortcutName, cmdLine = args[1], args[2]
					local playerSetsLimits = Process.playerSettingsLimits

					if type(shortcutName) == "string" and type(cmdLine) == "string" then
						local shortenShortcutName = Parser:trimString(shortcutName)
						local shortenCmdLine = Parser:trimString(cmdLine)

						if
							(
								#shortenShortcutName >= 2
								and #shortenShortcutName <= playerSetsLimits.ShortcutNameCharLimit
							)
							and (
								#shortenCmdLine > 0
								and #shortenCmdLine <= playerSetsLimits.AliasAndShortcutCmdLineCharLimit
							)
						then
							local pData = plr:getPData()
							local selfCmdShortcuts = pData.__shortcuts
							local shortcutCreationCount = service.tableCount(selfCmdShortcuts)

							if selfCmdShortcuts[shortenShortcutName] then
								selfCmdShortcuts[shortenShortcutName] = cmdLine

								return true
							else
								return -1
							end
						end
					end

					return 0
				end,
			},

			DeleteCommandButton = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local shortcutName, cmdLine = args[1], args[2]
					local playerSetsLimits = Process.playerSettingsLimits

					if type(shortcutName) == "string" then
						local shortenShortcutName = Parser:trimString(shortcutName)

						if
							#shortenShortcutName >= 2
							and #shortenShortcutName <= playerSetsLimits.ShortcutNameCharLimit
						then
							local pData = plr:getPData()
							local selfCmdShortcuts = pData.__shortcuts

							if selfCmdShortcuts[shortenShortcutName] then
								selfCmdShortcuts[shortenShortcutName] = nil

								return true
							else
								return -1
							end
						end
					end

					return 0
				end,
			},

			RunCommandButton = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local shortcutName = args[1]
					local playerSetsLimits = Process.playerSettingsLimits

					if type(shortcutName) == "string" then
						local shortenShortcutName = Parser:trimString(shortcutName)

						if
							#shortenShortcutName >= 2
							and #shortenShortcutName <= playerSetsLimits.ShortcutNameCharLimit
						then
							local pData = plr:getPData()
							local selfCmdShortcuts = pData.__shortcuts
							local shortcutCreationCount = service.tableCount(selfCmdShortcuts._table)

							if
								PolicyManager:getPolicyFromPlayer(plr, "SHORTCUTS_ALLOWED").value ~= false
								and selfCmdShortcuts[shortenShortcutName]
							then
								local shortCutCmdLine = selfCmdShortcuts[shortenShortcutName]
								if Utility:checkRate(Process.shortcutProcessCommand_RateLimit, plr.UserId) then
									Process.playerCommand(plr, shortCutCmdLine, { button = true })
								end
							end
						end
					end

					return 0
				end,
			},

			GetCommandButtons = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 100, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 30, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local pData = plr:getPData()
					local cmdShortcuts = pData.__shortcuts._table

					return cmdShortcuts
				end,
			},

			CreateCustomCmdAlias = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local alias, cmdLine = args[1], args[2]
					local playerSetsLimits = Process.playerSettingsLimits

					if type(alias) == "string" and type(cmdLine) == "string" then
						local shortenAlias = Parser:trimString(alias)
						local shortenCmdName = Parser:trimString(cmdLine)

						if #shortenAlias >= 2 and #shortenAlias <= playerSetsLimits.CustomCmdNameAliasCharLimit then
							local pData = plr:getPData()
							local selfCmdAliases = pData.__customCmdAliases
							local cmdBatchSeparator = settings.batchSeperator or "|"
							local aliasCreationCount = service.tableCount(selfCmdAliases._table)

							if aliasCreationCount + 1 > playerSetsLimits.MaxCustomCmdNameCreation then return -1 end

							if selfCmdAliases[shortenAlias:lower()] then
								return -2
							else
								if not Filter:safeString(shortenAlias, plr.UserId) then return -2.5 end

								if shortenAlias:find(cmdBatchSeparator) then return -3 end

								local commandFromAliasName = Commands.get(shortenAlias)
								if commandFromAliasName then return -4 end

								local commandFromCmdLine = Commands.get(shortenCmdName)
								if not commandFromCmdLine then return -5 end

								selfCmdAliases[shortenAlias:lower()] = cmdLine
								selfCmdAliases._reviveIfDead()

								return true
							end
						end
					end

					return 0
				end,
			},

			UpdateCustomCmdAlias = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local alias, cmdLine = args[1], args[2]
					local playerSetsLimits = Process.playerSettingsLimits

					if type(alias) == "string" and type(cmdLine) == "string" then
						local shortenAlias = Parser:trimString(alias)
						local shortenCmdLine = Parser:trimString(cmdLine)

						if #shortenAlias >= 2 and #shortenAlias <= playerSetsLimits.CustomCmdNameAliasCharLimit then
							local pData = plr:getPData()
							local selfCmdAliases = pData.__customCmdAliases or {}

							if selfCmdAliases[shortenAlias:lower()] then
								local commandFromCmdLine = Commands.get(cmdLine)
								if not commandFromCmdLine then return -2 end

								selfCmdAliases[shortenAlias:lower()] = cmdLine
								selfCmdAliases._reviveIfDead()

								return true
							else
								return -1
							end
						end
					end

					return 0
				end,
			},

			DeleteCustomCmdAlias = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 100, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 30, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local alias = args[1]
					local playerSetsLimits = Process.playerSettingsLimits

					if type(alias) == "string" then
						local pData = plr:getPData()
						local cmdAliases = pData.__customCmdAliases or {}

						local shortenAlias = Parser:trimString(alias)

						if not cmdAliases[shortenAlias:lower()] then
							return -1
						else
							cmdAliases[shortenAlias:lower()] = nil
							cmdAliases._reviveIfDead()

							return true
						end
					end

					return 0
				end,
			},

			GetCustomCmdAliases = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 100, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 30, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local pData = plr:getPData()
					local cmdAliases = pData.__customCmdAliases._table

					return cmdAliases
				end,
			},

			CreateCmdKeybind = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local keybindName, hotkeys, holdDuration, cmdLine, enabled =
						args[1], args[2], args[3], args[4], args[5]
					local playerSetsLimits = Process.playerSettingsLimits

					if
						type(keybindName) == "string"
						and type(hotkeys) == "table"
						and type(holdDuration) == "number"
						and holdDuration >= 0
						and type(cmdLine) == "string"
						and #cmdLine > 0
					then
						local shortenKeybindName = Parser:trimString(keybindName)
						local shortenCmdLine = Parser:trimString(cmdLine)

						if
							(#shortenKeybindName >= 2 and #shortenKeybindName <= playerSetsLimits.KeybindNameCharLimit)
							and #shortenCmdLine > 0
							and #shortenCmdLine <= playerSetsLimits.AliasAndShortcutCmdLineCharLimit
						then
							local pData = plr:getPData()
							local selfCmdKeybinds = pData.__cmdKeybinds
							local keybindCreationCount = service.tableCount(selfCmdKeybinds._table)

							if keybindCreationCount + 1 > playerSetsLimits.MaxKeybindCreations then return -1 end

							if selfCmdKeybinds[shortenKeybindName:lower()] then
								return -2
							else
								if not Filter:safeString(shortenKeybindName, plr.UserId) then return -2.5 end

								local keyCodes = Enum.KeyCode:GetEnumItems()
								local keyCodesInString = {}

								for i, keyCode in pairs(hotkeys) do
									if not table.find(keyCodes, keyCode) then return -3 end
								end

								for i, keyCode in ipairs(hotkeys) do
									table.insert(keyCodesInString, keyCode.Name)
								end

								if #hotkeys == 0 then return -4 end

								selfCmdKeybinds[shortenKeybindName:lower()] = {
									enabled = not not enabled,
									hotkeys = keyCodesInString,
									commandLine = shortenCmdLine,
									holdDuration = holdDuration,
								}
								selfCmdKeybinds._reviveIfDead()

								return true
							end
						end
					end

					return 0
				end,
			},

			UpdateCmdKeybind = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local keybindName, hotkeys, holdDuration, cmdLine, enabled =
						args[1], args[2], args[3], args[4], args[5]
					local playerSetsLimits = Process.playerSettingsLimits

					if
						type(keybindName) == "string"
						and type(hotkeys) == "table"
						and type(holdDuration) == "number"
						and holdDuration >= 0
						and type(cmdLine) == "string"
						and #cmdLine > 0
					then
						local shortenKeybindName = Parser:trimString(keybindName)
						local shortenCmdLine = Parser:trimString(cmdLine)

						if
							(#shortenKeybindName >= 2 and #shortenKeybindName <= playerSetsLimits.KeybindNameCharLimit)
							and #shortenCmdLine > 0
							and #shortenCmdLine <= playerSetsLimits.AliasAndShortcutCmdLineCharLimit
						then
							local pData = plr:getPData()
							local selfCmdKeybinds = pData.__cmdKeybinds
							local keybindData = selfCmdKeybinds[shortenKeybindName:lower()]

							if keybindData then
								local keyCodes = Enum.KeyCode:GetEnumItems()
								local keyCodesInString = {}

								for i, keyCode in pairs(hotkeys) do
									if not table.find(keyCodes, keyCode) then return -2 end
								end

								for i, keyCode in ipairs(hotkeys) do
									if not table.find(keyCodes, keyCode.Name) then
										table.insert(keyCodesInString, keyCode.Name)
									end
								end

								--if #hotkeys == 0 then
								--	return -3
								--end

								selfCmdKeybinds[shortenKeybindName:lower()] = {
									enabled = enabled,
									hotkeys = keyCodesInString,
									commandLine = shortenCmdLine,
									holdDuration = holdDuration,
								}

								selfCmdKeybinds._reviveIfDead()

								return true
							else
								return -1
							end
						end
					end

					return 0
				end,
			},

			DeleteCmdKeybind = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local keybindName = args[1]
					local playerSetsLimits = Process.playerSettingsLimits

					if type(keybindName) == "string" then
						local pData = plr:getPData()
						local selfCmdKeybinds = pData.__cmdKeybinds
						local shortenKeybindName = Parser:trimString(keybindName):lower()
						local keybindData = selfCmdKeybinds[shortenKeybindName]

						if keybindData then
							selfCmdKeybinds[shortenKeybindName] = nil
							selfCmdKeybinds._reviveIfDead()

							return true
						else
							return -1
						end
					end

					return 0
				end,
			},

			RunCmdKeybind = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local keybindName = args[1]
					local playerSetsLimits = Process.playerSettingsLimits

					if type(keybindName) == "string" then
						local shortenKeybindName = Parser:trimString(keybindName):lower()

						if
							#shortenKeybindName >= 2
							and #shortenKeybindName <= playerSetsLimits.KeybindNameCharLimit
						then
							local pData = plr:getPData()
							local selfCmdKeybinds = pData.__cmdKeybinds
							local selfCliSettings = pData.__clientSettings
							local shortcutCreationCount = service.tableCount(selfCmdKeybinds._table)

							if
								PolicyManager:getPolicyFromPlayer(plr, "KEYBINDS_ALLOWED").value ~= false
								and selfCliSettings.KeybindsEnabled
								and selfCmdKeybinds[shortenKeybindName]
							then
								local keybindData = selfCmdKeybinds[shortenKeybindName]
								if Utility:checkRate(Process.keybindProcessCommand_RateLimit, plr.UserId) then
									Process.playerCommand(plr, keybindData.commandLine, { keybind = true })
								end
							end
						end
					end

					return 0
				end,
			},

			GetCmdKeybinds = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 100, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 30, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local pData = plr:getPData()
					local cmdKeybinds = pData.__cmdKeybinds._table

					return cmdKeybinds
				end,
			},

			GetCustomKeybinds = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = false, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData) return plr:getPData().__customKeybinds._table end,
			},

			UpdateCustomKeybind = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 8, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 20, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					local keybindSaveId, hotkeys = args[1], args[2]
					local playerSetsLimits = Process.playerSettingsLimits

					if
						type(keybindSaveId) == "string"
						and ((type(hotkeys) == "table" and #hotkeys <= 3) or type(hotkeys) == "nil")
					then
						local shortenKeybindId = Parser:trimString(keybindSaveId):upper()

						if #shortenKeybindId > 0 and #shortenKeybindId <= playerSetsLimits.KeybindSaveIdCharLimit then
							local pData = plr:getPData()
							local customKeybinds = pData.__customKeybinds

							local keyCodes = Enum.KeyCode:GetEnumItems()
							local keyCodesInString = {}

							if hotkeys then
								for i, keyCode: Enum.KeyCode in hotkeys do
									if not table.find(keyCodes, keyCode) then return -2 end
								end

								for i, keyCode: Enum.KeyCode in hotkeys do
									if not table.find(keyCodesInString, keyCode.Name) then
										table.insert(keyCodesInString, keyCode.Name)
									end
								end

								customKeybinds[shortenKeybindId] = keyCodesInString
							else
								customKeybinds[shortenKeybindId] = nil
							end

							customKeybinds._reviveIfDead()

							return true
						end
					end

					return 0
				end,
			},

			ToggleMuteOnAFK = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 12, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 8, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					if type(args[1]) == "boolean" then Utility:toggleMuteOnAfk(plr, args[1]) end
				end,
			},

			ToggleIncognito = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 20, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 80, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData)
					if type(args[1]) == "boolean" then
						if not Utility:checkRate(Process.toggleIncognito_RateLimit.Global, plr.UserId) then
							plr:sendData(
								"SendMessage",
								"<b>Global Roadblock</b>: Too many players are toggling incognito mode right now. Try again later!",
								nil,
								5,
								"Context"
							)
							return 0
						end

						if not Utility:checkRate(Process.toggleIncognito_RateLimit.Player, plr.UserId) then
							plr:sendData(
								"SendMessage",
								`You can't update incognito mode too quick. Wait {Parser:relativeTimestamp(
									select(4, Utility:readRate(Process.toggleIncognito_RateLimit.Player, plr.UserId))
								)}`,
								nil,
								5,
								"Context"
							)
							return 0
						end

						plr:toggleIncognitoStatus(args[1])
						local incogStatus = plr:getPData().__clientSettings.IncognitoMode

						if incogStatus then
							plr:sendData(
								"SendMessage",
								`Incognito mode is now enabled! Your display name is replaced with your corresponding code name in logs and messages.`,
								nil,
								10,
								"Context"
							)
							return true
						else
							plr:sendData(
								"SendMessage",
								`You disabled incognito mode. Your display name in logs and messages will use your current Roblox display name.`,
								nil,
								10,
								"Context"
							)
							return false
						end
					end
				end,
			},

			EditDeviceType = {
				Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
				Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

				RL_Enabled = true, -- Rate limit enabled?
				RL_Rates = 12, -- (interval) (min: 1) Rate amount of requests
				RL_Reset = 8, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
				RL_Error = nil, -- (string) Error message returned after passing the rate limit

				Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
				Whitelist = {}, -- (table) List of users allowed to call this command
				Blacklist = {}, -- (table) List of users denied to call this command

				Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

				Can_Invoke = false, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
				Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
				--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

				--> Supported command functions: Function, Run, Execute, Call
				Function = function(plr, args, remoteData) plr:getClientData().deviceType = tostring(args[1]) end,
			},
		},

		privateMessage = function(creationData: { [any]: any }?)
			creationData = creationData or {}

			local receiver = creationData.receiver
			local sender = creationData.sender
			local topic = creationData.topic
			local desc = creationData.desc or creationData.detail
			local message = creationData.message
			local expireOs = creationData.expireOs
			local scheduledOs = creationData.scheduledOs
			local openTime = creationData.openTime
			local noReply = creationData.noReply or creationData.readOnly
			local notifyOpts = creationData.notifyOpts

			local instantOpen = creationData.instantOpen or creationData.instantRead
			local onRead = creationData.onRead
			local onReply = creationData.onReply

			local messageData = {
				topic = topic or "No topic",
				desc = desc or "Private message",
				message = message,

				expireTime = expireOs and expireOs - os.time(),
				expireOs = expireOs,
				scheduledOs = scheduledOs or os.time(),
				openTime = openTime,
				noReply = noReply,
				dontMessageSender = not sender,

				senderId = sender and sender.UserId,
				receiverId = receiver.UserId,

				openSince = nil,

				opened = Signal.new(),
				replied = Signal.new(),

				id = getRandom(30),
				active = true,
			}

			if onRead then messageData.opened:connectOnce(onRead) end

			if onReply then messageData.replied:connectOnce(onReply) end

			local remSession = Remote.newSession()
			remSession.connectedPlayers[receiver] = true

			local sessOpenNotif = remSession:makeCommand "OpenNotif"
			sessOpenNotif.connectedPlayers = remSession.connectedPlayers
			sessOpenNotif.execute = function(plr)
				if messageData:isExpired() then
					plr:sendData(
						"SendMessage",
						"The private message you tried to open is expired and can no longer accept any replies.",
						nil,
						5,
						"Context"
					)
				else
					messageData.opened:fire(true)
					messageData:showToPlayer(plr)
				end
			end

			function messageData:isExpired(): boolean
				local currentOs = os.time()
				return self.active
					and (
						self.expireOs and (self.expireOs - os.time() <= 0)
						or not self.expireOs and self.openTime and self.openSince and not (self.openSince <= currentOs and self.openSince + self.openTime >= currentOs)
						or false
					)
			end

			function messageData:showToPlayer(plr: ParsedPlayer)
				if not self.openSince then self.openSince = os.time() end

				plr:makeUI("PrivateMessageV2", {
					title = messageData.topic,
					desc = messageData.desc,
					message = messageData.message,
					publishId = not messageData.noReply and messageData.id,
					readOnly = messageData.noReply,
					time = (messageData.expireOs and math.clamp(messageData.expireOs - os.time(), 0, math.huge))
						or (messageData.openTime and math.clamp(messageData.openTime, 2, math.huge))
						or nil,
				})
			end

			function messageData:destroy()
				if variables.privateMessages[messageData.id] == messageData then
					variables.privateMessages[messageData.id] = nil
				end
				remSession.active = false
			end

			if not messageData.noReply then variables.privateMessages[messageData.id] = messageData end

			task.spawn(function()
				if scheduledOs and scheduledOs - os.time() > 0 then
					repeat
						wait(0.1)
					until not messageData.active or messageData:isExpired() or (scheduledOs - os.time() <= 0)

					if not messageData.active or not receiver:isInGame() then return messageData:destroy() end
				end

				if messageData.active and not messageData:isExpired() then
					if receiver:isInGame() then
						task.defer(function()
							if instantOpen then
								messageData.opened:fire(true)
								messageData:showToPlayer(receiver)
								return
							end

							receiver:makeUI("NotificationV2", {
								title = (notifyOpts and notifyOpts.title) or "Private Message",
								desc = (notifyOpts and notifyOpts.desc) or "From " .. tostring(
									(sender and sender:toStringDisplayForPlayer(receiver)) or "[unknown]"
								),
								time = (notifyOpts and notifyOpts.time) or messageData.expireTime,
								actionText = "Reply",
								iconUrl = "mti://message",
								--icon

								openFunc = "sessioncommand://main:" .. remSession.id .. "-" .. sessOpenNotif.id,
								--executeType = "session";
								--sessionId = remSession.id;
								--openNotifId = sessOpenNotif.id;
							})

							--if notifOpened and (not messageData.expireOs or (messageData.expireOs-os.time() > 0)) then
							--	receiver:makeUI("PrivateMessageV2", {
							--		title = messageData.topic;
							--		desc = messageData.desc;
							--		message = messageData.message;
							--		publishId = not messageData.noReply and messageData.id;
							--		readOnly = messageData.noReply;
							--		time = messageData.expireOs and math.clamp(messageData.expireOs-os.time(), 0, math.huge);
							--	})
							--end
						end)
					else
						messageData.active = false
					end
				end
			end)

			return messageData
		end,

		makePoll = function(players, topic, desc, options, canSelectMultiple, tallyProgress, publicResults, expireOs)
			local remoteSession = Remote.newSession()
			remoteSession.expireOs = expireOs or nil

			local submitPoll = remoteSession:makeCommand "SendResults"
			submitPoll.name = "submit results"
			submitPoll.canInvoke = false
			submitPoll.canFire = true

			local checkPoll = remoteSession:makeCommand "CheckResults"
			checkPoll.name = "check results"
			checkPoll.canInvoke = true
			checkPoll.canFire = false

			local connectedPlayers = {}
			remoteSession.connectedPlayers = connectedPlayers

			for i, player in pairs(players) do
				connectedPlayers[player] = true
				table.insert(submitPoll.allowedTriggers, player.UserId)
				table.insert(checkPoll.allowedTriggers, player.UserId)
			end

			local pollSession = {
				remoteSession = remoteSession,
				topic = topic or "No topic",
				desc = desc or "No description",
				options = {},
				results = {},
				expireOs = expireOs,
				players = players or {},
				confirmPlayers = {},

				confirmPlayerCount = 0,
				totalPlayerCount = 0,

				started = tick(),

				updated = Signal.new(),
				finished = Signal.new(),

				tallyProgress = tallyProgress or false,
				canSelectMultiple = canSelectMultiple or false,

				id = getRandom(20),
			}

			pollSession.totalPlayerCount = service.tableCount(connectedPlayers)

			for i, optData in pairs(options or {}) do
				if type(optData) == "table" then
					local clOptData = cloneTable(optData)
					clOptData.uniqueId = clOptData.uniqueId or getRandom()

					table.insert(pollSession.options, clOptData)

					pollSession.results[clOptData.uniqueId] = {
						count = 0,
						players = {},
						text = optData.text or "choice-" .. getRandom(),
					}
				end
			end

			submitPoll.execute = function(plr, chosenOpts)
				warn "did execute submit poll?"
				warn("chosenopts:", chosenOpts)
				if connectedPlayers[plr] and not pollSession.confirmPlayers[plr] and type(chosenOpts) == "table" then
					if
						#chosenOpts > 0
						and (
							(not canSelectMultiple and #chosenOpts == 1)
							or (canSelectMultiple and #pollSession.options >= #chosenOpts)
						)
					then
						local checkIds = {}

						warn "did submit poll?"
						for i, optData in pairs(chosenOpts) do
							if type(optData) == "table" then
								local uniqueId = optData.id
								local resultData = pollSession.results[uniqueId]

								if not checkIds[uniqueId] then
									checkIds[uniqueId] = true
									resultData.count += 1

									table.insert(resultData.players, plr)
								end
							end
						end

						pollSession.updated:fire(plr)
						pollSession.confirmPlayers[plr] = cloneTable(chosenOpts)
						pollSession.confirmPlayerCount += 1

						if service.tableCount(pollSession.confirmPlayers) == service.tableCount(connectedPlayers) then
							pollSession.finished:fire(true)
						end
					end
				end
			end

			checkPoll.execute = function(plr)
				warn "did check poll?"
				if connectedPlayers[plr] then
					local pollResults = {}

					for resultId, resultData in pairs(pollSession.results) do
						pollResults[resultId] = {
							percent = resultData.count / service.tableCount(pollSession.confirmPlayers),
							count = resultData.count,
						}
					end

					return pollResults
				end
			end

			for i, player in pairs(players) do
				player:makeUI("MultipleChoice", {
					title = topic,
					desc = desc,

					options = pollSession.options,
					multipleSelection = canSelectMultiple,
					responseType = (publicResults and "vote") or nil,

					resultSuffix = " player(s)",

					voteCheck = publicResults and {
						type = "Session",
						sessionId = remoteSession.id,
						submitResultsId = submitPoll.id,
						checkResultsId = checkPoll.id,
					} or nil,

					publishData = not publicResults and {
						type = "Session",
						sessionId = remoteSession.id,
						submitId = submitPoll.id,
					} or nil,

					progressEnabled = true,

					time = (expireOs and math.round(expireOs - os.time())) or nil,
				})
			end

			variables.pollSessions[pollSession.id] = pollSession

			return pollSession
		end,

		newSession = function(expireOs1)
			local sessionTab
			sessionTab = {
				active = true,
				name = nil,
				network = nil,
				id = getRandom(30),
				expireOs = expireOs1,

				events = {},
				commands = {},
				connectedPlayers = {},
				allowedTriggers = {},

				canConnect = false,
				selfConnectedPlayers = {},

				playerConnected = Signal.new(),
				playerDisconnected = Signal.new(),
			}

			-- Session handler
			function sessionTab:makeEvent(eventName, playersThatCanTrigger, expireOs2)
				eventName = eventName or "_Global-" .. getRandom()

				if self.active and not self:findEvent(eventName) then
					local eventData
					eventData = {
						id = getRandom(),
						name = eventName,
						active = true,
						canFire = true,
						canConnect = false,
						expireOs = expireOs2,
						allowedTriggers = {},
						connectedPlayers = playersThatCanTrigger or {},
						playerConnections = {},
						_event = Signal.new(),

						maxPlayerConnections = 5,
						maxConnectedPlayers = 0,
					}

					function eventData:isActive()
						return self.active and (not self.expireOs or os.time() - self.expireOs < 0)
					end

					function eventData:hasPermission(player)
						if self.active then
							return self.connectedPlayers[player] or Identity.checkTable(player, self.allowedTriggers)
						end
					end

					function eventData:killConnections(playerUserId, disconnectId)
						local killCount = 0

						for i, connectionData in pairs(self.playerConnections) do
							local conPlayerId = connectionData.player.UserId

							if
								conPlayerId == playerUserId
								and (not disconnectId or connectionData.disconnectId == disconnectId)
							then
								connectionData.active = false
								self.playerConnections[i] = nil
								killCount += 1
							end
						end

						if killCount > 0 then
							return true, killCount
						else
							return false, 0
						end
					end

					function eventData:makeConnection(player, fireEventId, expireOs)
						-- Connect id: 20-40 characters
						if not (#fireEventId >= 20 and #fireEventId <= 48) then
							error("Fire event id must have at least 20 characters and 48 characters maximum.", 0)
							return
						end

						local playerConnectionsMade = (function()
							local count = 0
							for i, connectData in pairs(self.playerConnections) do
								if connectData.player == player then
									count += 1
								end
							end
							return count
						end)()

						local connectedPlayersCount = (function()
							local count = 0
							local checkList = {}

							for i, connectData in pairs(self.playerConnections) do
								if connectData.player == player and not checkList[player.playerId] then
									count += 1
									checkList[player.playerId] = true
								end
							end

							return count
						end)()

						if playerConnectionsMade + 1 > self.maxPlayerConnections then return -1 end

						if self.maxConnectedPlayers > 0 and connectedPlayersCount + 1 > self.maxConnectedPlayers then
							return -2
						end

						local connectionData = {
							active = true,
							player = player,
							expireOs = expireOs,
							fireEventId = fireEventId,
							id = player.playerId .. "-" .. getRandom(15),
							disconnectId = getRandom(20),
						}

						function connectionData:isActive()
							return self.active
								and (not self.expireOs or os.time() - self.expireOs < 0)
								and player:isInGame()
						end

						table.insert(self.playerConnections, connectionData)
						return connectionData
					end

					function eventData:getConnections(player: ParsedPlayer | Player, playerUserId: number?)
						local results = {}
						for i, connectData in pairs(self.playerConnections) do
							if
								(player and connectData.player == player)
								or (playerUserId and connectData.player.UserId == playerUserId)
							then
								table.insert(results, connectData)
							end
						end

						return results
					end

					function eventData:fireToSpecificPlayers(players, ...)
						local subNetwork = sessionTab.network
						local allowedPlayers = {}

						for i, plr in pairs(players) do
							allowedPlayers[plr.UserId] = true
						end

						for i, connectionData in pairs(eventData.playerConnections) do
							local conPlayer = connectionData.player

							if
								allowedPlayers[conPlayer.UserId]
								and connectionData:isActive()
								and (sessionTab:hasPermission(conPlayer) and eventData:hasPermission(conPlayer))
							then
								if subNetwork then
									local networkKey = subNetwork:getPlayerKey(conPlayer)
									if networkKey:isReadyToUse() then
										subNetwork:fire(
											conPlayer,
											"FirePlayerEvent",
											connectionData.fireEventId,
											os.time(),
											...
										)
									else
										warn(
											"Unable to fire event "
												.. (eventData.name or eventData.id)
												.. " without a player key assigned in sub network "
												.. tostring(subNetwork.id)
										)
									end
								else
									conPlayer:sendData("FirePlayerEvent", connectionData.fireEventId, os.time(), ...)
								end
							end
						end
					end

					function eventData:fire(...) eventData._event:fire(...) end

					eventData._event:connect(function(...)
						local subNetwork = sessionTab.network

						if sessionTab:isActive() and eventData:isActive() then
							for i, connectionData in pairs(eventData.playerConnections) do
								local conPlayer = connectionData.player
								if
									connectionData:isActive()
									and (sessionTab:hasPermission(conPlayer) and eventData:hasPermission(conPlayer))
								then
									if subNetwork then
										local networkKey = subNetwork:getPlayerKey(conPlayer)
										if networkKey:isReadyToUse() then
											subNetwork:fire(
												conPlayer,
												"FirePlayerEvent",
												connectionData.fireEventId,
												os.time(),
												...
											)
										end
									else
										conPlayer:sendData(
											"FirePlayerEvent",
											connectionData.fireEventId,
											os.time(),
											...
										)
									end
								end
							end
						end
					end)

					self.events[eventData.id] = eventData
					return eventData
				end
			end

			function sessionTab:makeCommand(cmdName, cmdFunction, canInvoke, canFire)
				local cmdTab
				cmdTab = {
					active = true,
					id = getRandom(30),
					name = cmdName,
					canInvoke = canInvoke,
					canFire = canFire or not canInvoke,
					allowedTriggers = {},
					connectedPlayers = {},
					execute = cmdFunction or function(plr, ...) return "error-" .. math.random(300) end,
				}

				self.commands[cmdTab.id] = cmdTab
				return cmdTab
			end

			function sessionTab:findEvent(eventName)
				for i, event in pairs(self.events) do
					if event.name == eventName then return event end
				end
			end

			--function sessionTab:connectEvent(eventId, parsedPlayers)
			--	if self.active then
			--		-- Connected event
			--		local event = self.events[eventId]

			--		if not event then
			--			return false
			--		else
			--			for i, player in pairs(parsedPlayers) do
			--				local existedCon = self.connectedPlayers[player]

			--				if not existedCon then
			--					local connectId = getRandom(30)
			--					local connectCheckKey = getRandom(50)

			--					local connectData = {
			--						connectId = connectId;
			--						checkKey = connectCheckKey;
			--						_checked = false;

			--						connected = Signal.new();
			--					}

			--					self.connectedPlayers[player] = connectData
			--				end
			--			end
			--		end
			--	end
			--end

			function sessionTab:fireEvent(eventName, ...)
				local event = self:findEvent(eventName)

				if event then event:fire(...) end
			end

			function sessionTab:isActive() return self.active and (not self.expireOs or os.time() - self.expireOs < 0) end

			function sessionTab:hasPermission(player)
				return self.active
					and (
						self.selfConnectedPlayers[player]
						or self.connectedPlayers[player]
						or Identity.checkTable(player, self.allowedTriggers)
					)
			end

			ConnectedSessions[sessionTab.id] = sessionTab
			server.Events.sessionCreated:fire(sessionTab)

			return sessionTab
		end,

		getSubNetwork = function(networkName)
			return SubNetworks[networkName]
				or (function()
					for netName, subNetwork in pairs(SubNetworks) do
						if
							subNetwork.id:lower() == networkName:lower()
							or subNetwork.name:lower() == networkName:lower()
						then
							return subNetwork
						end
					end
				end)()
		end,

		newSubNetwork = function(networkName)
			if SubNetworks[networkName] then
				return SubNetworks[networkName]
			else
				local subNetwork = {}
				subNetwork.active = true
				subNetwork.id = getRandom(30)

				--// Server SEt

				subNetwork.joinable = false
				subNetwork.connectedPlayers = {}
				subNetwork.allowedTriggers = {}
				subNetwork.disallowedPlayerIds = {}

				subNetwork.securitySettings = {
					maxTrustKeyRetrievals = 3,
					canClientDisconnect = false,
					endToEndEncrypted = false,
				}

				subNetwork.playerKeySettings = {
					keyLength = 30,
					trustKeyLength = 40,
					disconnectKeyLength = 30,
				}

				subNetwork.processLogs = {}
				subNetwork.processRLEnabled = false
				subNetwork.processRateLimit = {
					Rates = 300,
					Reset = 120,
				}
				subNetwork.processFunc = function(...) end
				subNetwork.processWarnError = false
				subNetwork.processError = Signal.new()

				--// Client settings
				subNetwork.remoteCall_Allowed = true
				subNetwork.remoteCall_RLEnabled = false
				subNetwork.remoteCall_RL = {
					Rates = 300,
					Reset = 120,
				}

				subNetwork.connecting = Signal.new()
				subNetwork.connected = Signal.new()
				subNetwork.disconnected = Signal.new()

				subNetwork.commandLogs = {}
				subNetwork.networkCommands = {
					-- CORE COMMANDS [DO NOT REMOVE]
					Disconnect = { -- Disconnect from network
						Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
						Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

						RL_Enabled = false, -- Rate limit enabled?
						RL_Rates = 50, -- (interval) (min: 1) Rate amount of requests
						RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
						RL_Error = nil, -- (string) Error message returned after passing the rate limit

						Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
						Whitelist = {}, -- (table) List of users allowed to call this command
						Blacklist = {}, -- (table) List of users denied to call this command

						Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

						Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
						Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
						--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

						--> Supported command functions: Function, Run, Execute, Call
						Function = function(plr, args, remoteData)
							if subNetwork.securitySettings.canClientDisconnect then
								local givenDiscId = args[1]
								local personalKey = subNetwork.networkKeys[plr.playerId]

								if type(givenDiscId) == "string" and #givenDiscId > 20 then
									local personalDisconnectId = personalKey.disconnectId

									if personalDisconnectId == givenDiscId then
										personalKey:destroy()
										--warn("Disconnected personal key")
										return true
									end
								end
							end
						end,
					},

					CanDisconnect = { -- Disconnect from network
						Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
						Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

						RL_Enabled = false, -- Rate limit enabled?
						RL_Rates = 50, -- (interval) (min: 1) Rate amount of requests
						RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
						RL_Error = nil, -- (string) Error message returned after passing the rate limit

						Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
						Whitelist = {}, -- (table) List of users allowed to call this command
						Blacklist = {}, -- (table) List of users denied to call this command

						Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

						Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
						Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
						--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

						--> Supported command functions: Function, Run, Execute, Call
						Function = function(plr, args, remoteData)
							return subNetwork.securitySettings.canClientDisconnect
						end,
					},

					Verify = { -- Verifies personal key
						Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
						Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

						RL_Enabled = false, -- Rate limit enabled?
						RL_Rates = 50, -- (interval) (min: 1) Rate amount of requests
						RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
						RL_Error = nil, -- (string) Error message returned after passing the rate limit

						Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
						Whitelist = {}, -- (table) List of users allowed to call this command
						Blacklist = {}, -- (table) List of users denied to call this command

						Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

						Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
						Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
						--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

						--> Supported command functions: Function, Run, Execute, Call
						Function = function(plr, args, remoteData)
							local givenAccessKey = args[1]
							local personalKey = subNetwork.networkKeys[plr.playerId]

							--// Access key is used to communicate to the client's network
							if
								not personalKey.verifyStatus
								and type(givenAccessKey) == "string"
								and #givenAccessKey == 60
							then
								personalKey.clientAccessKey = givenAccessKey
								personalKey.verifyStatus = true
								personalKey.verifiedSince = os.time()
								personalKey.verified:fire()
								subNetwork._network1:remPlayerFromTrustCheck(plr, 300)
								subNetwork.connected:fire(plr)

								local isETEE = subNetwork.securitySettings.endToEndEncrypted
								local hashedOldKey = if isETEE then hashLib.sha1(personalKey.id) else nil
								local newPersonalKey = if isETEE
									then getRandomV3(subNetwork.playerKeySettings.keyLength)
									else nil

								if isETEE then personalKey.id = newPersonalKey end

								return true, hashedOldKey, newPersonalKey
							end
						end,
					},

					------------

					FindSession = {
						Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
						Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

						RL_Enabled = false, -- Rate limit enabled?
						RL_Rates = 50, -- (interval) (min: 1) Rate amount of requests
						RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
						RL_Error = nil, -- (string) Error message returned after passing the rate limit

						Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
						Whitelist = {}, -- (table) List of users allowed to call this command
						Blacklist = {}, -- (table) List of users denied to call this command

						Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

						Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
						Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
						--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

						--> Supported command functions: Function, Run, Execute, Call
						Function = function(plr, args, remoteData)
							return Remote.Commands.FindSession.Function(plr, args, remoteData)
						end,
					},

					ConnectSession = {
						Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
						Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

						RL_Enabled = false, -- Rate limit enabled?
						RL_Rates = 50, -- (interval) (min: 1) Rate amount of requests
						RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
						RL_Error = nil, -- (string) Error message returned after passing the rate limit

						Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
						Whitelist = {}, -- (table) List of users allowed to call this command
						Blacklist = {}, -- (table) List of users denied to call this command

						Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

						Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
						Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
						--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

						--> Supported command functions: Function, Run, Execute, Call
						Function = function(plr, args, remoteData)
							return Remote.Commands.ConnectSession.Function(plr, args, remoteData)
						end,
					},

					DisconnectSession = {
						Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
						Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

						RL_Enabled = false, -- Rate limit enabled?
						RL_Rates = 50, -- (interval) (min: 1) Rate amount of requests
						RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
						RL_Error = nil, -- (string) Error message returned after passing the rate limit

						Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
						Whitelist = {}, -- (table) List of users allowed to call this command
						Blacklist = {}, -- (table) List of users denied to call this command

						Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

						Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
						Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
						--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

						--> Supported command functions: Function, Run, Execute, Call
						Function = function(plr, args, remoteData)
							return Remote.Commands.DisconnectSession.Function(plr, args, remoteData)
						end,
					},

					CheckSession = {
						Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
						Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

						RL_Enabled = false, -- Rate limit enabled?
						RL_Rates = 50, -- (interval) (min: 1) Rate amount of requests
						RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
						RL_Error = nil, -- (string) Error message returned after passing the rate limit

						Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
						Whitelist = {}, -- (table) List of users allowed to call this command
						Blacklist = {}, -- (table) List of users denied to call this command

						Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

						Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
						Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
						--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

						--> Supported command functions: Function, Run, Execute, Call
						Function = function(plr, args, remoteData)
							return Remote.Commands.CheckSession.Function(plr, args, remoteData)
						end,
					},

					ManageSession = {
						Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
						Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

						RL_Enabled = false, -- Rate limit enabled?
						RL_Rates = 30, -- (interval) (min: 1) Rate amount of requests
						RL_Reset = 5, -- (number) (min: 0.01) Interval seconds to reset rate's cache.
						RL_Error = nil, -- (string) Error message returned after passing the rate limit

						Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
						Whitelist = {}, -- (table) List of users allowed to call this command
						Blacklist = {}, -- (table) List of users denied to call this command

						Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

						Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
						Can_Fire = true, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
						--> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT

						--> Supported command functions: Function, Run, Execute, Call
						Function = function(plr, args, remoteData)
							return Remote.Commands.ManageSession.Function(plr, args, remoteData)
						end,
					},
				}

				subNetwork.networkRemoteCall = function(plr, invoke, remoteData, ...)
					local parsed = Parser:apifyPlayer(plr)
					local rateKey = tostring(parsed.UserId)

					local remoteArguments = { ... }
					local cmdName = tostring(remoteArguments[1])
					local remoteCmd = subNetwork.networkCommands[cmdName]

					if remoteCmd and not remoteCmd.Disabled then
						local lockdown = Core.lockdown
						local whitelist = remoteCmd.Whitelist or {}
						local blacklist = remoteCmd.Blacklist or {}
						local permissions = remoteCmd.Permissions
						local publicUse = remoteCmd.Public

						local userWhitelisted = (whitelist and Identity.checkTable(plr, whitelist)) or false
						local userBlacklisted = (whitelist and Identity.checkTable(plr, blacklist)) or false
						local userHasPermissions = (
							permissions and server.Roles:hasPermissionFromMember(plr, permissions)
						) or false

						local userAdmin = Moderation.checkAdmin(plr)
						local canAccess = userAdmin
							or ((publicUse or userHasPermissions or userWhitelisted) and not userBlacklisted)

						-- Ensure lockdown is not enabled or remote command is allowed during lockdown, then make sure if the player can access it
						if (not lockdown or (lockdown and remoteCmd.Lockdown_Allowed)) and canAccess then
							local cmdFunction = remoteCmd.Function
								or remoteCmd.Run
								or remoteCmd.Execute
								or remoteCmd.Call
							cmdFunction = (type(cmdFunction) == "function" and cmdFunction) or nil

							-- Ensure Can_Fire is enabled by default if neither Can_Invoke and Can_Fire are enabled
							if not (remoteCmd.Can_Invoke or remoteCmd.Can_Fire) then remoteCmd.Can_Fire = true end

							local rL_Enabled = remoteCmd.RL_Enabled
							local rL_Rates = remoteCmd.RL_Rates or 1
							local rL_Reset = remoteCmd.RL_Reset or 0.01
							local rL_Error = remoteCmd.RL_Error
							local rL_Data = remoteCmd.RL_Data
								or (function()
									local data = {}

									rL_Rates = math.floor(math.abs(rL_Rates))
									rL_Reset = math.abs(rL_Reset)

									rL_Rates = (rL_Rates < 1 and 1) or rL_Rates

									remoteCmd.RL_Rates = rL_Rates
									remoteCmd.RL_Reset = rL_Reset

									data.Rates = rL_Rates
									data.Rest = rL_Reset

									remoteCmd.RL_Data = data
									return data
								end)()

							local canUseCommand = (invoke and remoteCmd.Can_Invoke)
								or (not invoke and remoteCmd.Can_Fire)
								or false

							if canUseCommand and cmdFunction then
								-- Command rate limit check
								if rL_Enabled then
									local passCmdRateCheck, curRemoteRate, maxRemoteRate =
										Utility:checkRate(rL_Data, rateKey)

									if not passCmdRateCheck then
										return (type(rL_Error) == "string" and rL_Error) or nil
									end
								end

								local parsed = server.Parser:apifyPlayer(plr)
								local rets = {
									service.trackTask(
										"_SUBNETWORK_"
											.. tostring(subNetwork.id)
											.. "_COMMAND-"
											.. cmdName
											.. "-Invoke:"
											.. tostring(invoke)
											.. "-"
											.. plr.UserId,
										false,
										cmdFunction,
										parsed,
										{ unpack(remoteArguments, 2) },
										remoteData
									),
								}
								local success, errMessage, errTrace = unpack(rets)

								table.insert(subNetwork.commandLogs, {
									title = "Player "
										.. plr.UserId
										.. " "
										.. (invoke and "invoked" or "fired")
										.. " "
										.. tostring(cmdName),
									desc = (success and "No errors found during process")
										or "Error found: " .. tostring(errMessage),
									errTrace = not success and errTrace or nil,
									errMessage = not success and errMessage or nil,
									startedTick = os.clock(),
									startedOs = os.time(),

									arguments = { unpack(remoteArguments, 2) },
									processRanSuccess = success,
									processRets = rets, -- cloneTable(rets);

									player = parsed,
								})

								if not rets[1] then
									warn(
										"Player "
											.. plr.Name
											.. " encountered an error while running remote "
											.. cmdName
											.. " from network "
											.. tostring(subNetwork.id)
											.. ": "
											.. tostring(rets[2])
									)
									-- Don't return the error ret to the client. It's never a good thing for them to see the error
								else
									-- Return the function rets from the function if this call was invoked by RemoteFunction
									if invoke then
										-- First parameter of the rets is the success whether the function ran successfully or not
										-- We never doubt on returning the success status with the function rets
										return unpack(rets, 2)
									end
								end
							end
						end
					end
				end
				subNetwork.networkKeys = {}

				subNetwork._network1 = Network.newCreate("SubNetwork-" .. subNetwork.id, {
					invokable = false,
					firewallEnabled = true,
					firewallType = "high",
					networkFunc = function(plr, ...)
						local invoke = false
						local processFunc = subNetwork.processFunc

						if type(processFunc) ~= "function" then return -101, "Invalid_Network_Function" end

						local parsedPlr = Parser:apifyPlayer(plr)
						local cliData = parsedPlr:getClientData()
						local remoteArguments = { ... }

						local personalKey = subNetwork.networkKeys[parsedPlr.playerId]
						local isETEE = subNetwork.securitySettings.endToEndEncrypted

						if
							subNetwork.active
							and cliData
							and personalKey
							and personalKey:isActive()
							and personalKey.trustChecked
						then
							local expectedPersonalKeyId = if isETEE
								then hashLib.sha1(personalKey.id)
								else personalKey.id

							local rateKey = tostring(parsedPlr.UserId)
							local didPassRL = not subNetwork.processRLEnabled
								or Utility:checkRate(subNetwork.processRateLimit, rateKey)

							if not didPassRL then
								return -202, "Rate_Limit_Exceeded"
							else
								if expectedPersonalKeyId ~= remoteArguments[1] then return end

								if isETEE then
									local _, encryptedArgs, instanceList = unpack(remoteArguments)
									--warn("Encrypted args:", encryptedArgs)
									if type(encryptedArgs) ~= "string" then return end
									encryptedArgs = decryptRemoteArguments(personalKey.id, encryptedArgs)
									--warn("Decrypted args:", encryptedArgs)
									--warn("Instance list:", instanceList)

									if type(encryptedArgs) ~= "table" then return end
									local assortedArguments = sortArgumentsWithInstances(encryptedArgs, instanceList)
									--warn("Assorted arguments:", assortedArguments)
									remoteArguments = { _, unpack(assortedArguments) }
								end

								-- Check sub network commands
								if subNetwork.networkCommands[tostring(remoteArguments[2])] then
									local remoteData = {
										invoked = invoke,
										fired = not invoke,
										sentTick = os.clock(),
										sentOs = os.time(),
										network = subNetwork,
									}

									return subNetwork.networkRemoteCall(
										plr,
										invoke,
										remoteData,
										unpack(remoteArguments, 2)
									)
								end

								local taskName = "SubNetwork_"
									.. subNetwork.id
									.. "_Process_"
									.. plr.UserId
									.. "-Invoke:"
									.. tostring(invoke and true or false)
								local processRets = {
									service.trackTask(
										taskName,
										false,
										subNetwork.processFunc,
										parsedPlr,
										{ unpack(remoteArguments, 2) }
									),
								}
								local success, errMessage, errTrace = processRets[1], processRets[2], processRets[3]

								-- Log player interaction
								table.insert(subNetwork.processLogs, {
									title = "Player " .. plr.UserId .. " interacted with network",
									desc = (success and "No errors found during process")
										or "Error found: " .. tostring(errMessage),
									errTrace = not success and errTrace or nil,
									errMessag = not success and errMessage or nil,
									startedTick = os.clock(),
									startedOs = os.time(),

									arguments = { unpack(remoteArguments, 2) },
									processRanSuccess = success,
									processRets = cloneTable(processRets),

									player = parsedPlr,
								})

								if not success then
									subNetwork.processError:fire(parsedPlr, errMessage, errTrace)
									if subNetwork.processWarnError then
										warn(
											"Sub Network "
												.. tostring(subNetwork.id)
												.. " encountered an error with player "
												.. tostring(plr.UserId)
												.. ": "
												.. tostring(errMessage),
											errTrace
										)
									end
								else
									if invoke then return unpack(processRets, 2) end
								end
							end
						end
					end,
				})

				subNetwork._network2 = Network.newCreate("SubNetwork-" .. subNetwork.id, {
					invokable = true,
					firewallEnabled = true,
					firewallType = "high",
					networkFunc = function(plr, ...)
						local invoke = true
						local processFunc = subNetwork.processFunc

						if type(processFunc) ~= "function" then return -101, "Invalid_Network_Function" end

						local parsedPlr = Parser:apifyPlayer(plr)
						local cliData = parsedPlr:getClientData()
						local remoteArguments = { ... }

						local personalKey = subNetwork.networkKeys[parsedPlr.playerId]
						local isETEE = subNetwork.securitySettings.endToEndEncrypted

						if
							subNetwork.active
							and cliData
							and personalKey
							and personalKey:isActive()
							and personalKey.trustChecked
						then
							local expectedPersonalKeyId = if isETEE
								then hashLib.sha1(personalKey.id)
								else personalKey.id

							local rateKey = tostring(parsedPlr.UserId)
							local didPassRL = not subNetwork.processRLEnabled
								or Utility:checkRate(subNetwork.processRateLimit, rateKey)

							if not didPassRL then
								return -202, "Rate_Limit_Exceeded"
							else
								if expectedPersonalKeyId ~= remoteArguments[1] then return end

								if isETEE then
									local _, encryptedArgs, instanceList = unpack(remoteArguments)
									--warn("Encrypted args:", encryptedArgs)
									if type(encryptedArgs) ~= "string" then return end
									encryptedArgs = decryptRemoteArguments(personalKey.id, encryptedArgs)
									--warn("Decrypted args:", encryptedArgs)
									--warn("Instance list:", instanceList)

									if type(encryptedArgs) ~= "table" then return end
									local assortedArguments = sortArgumentsWithInstances(encryptedArgs, instanceList)
									--warn("Assorted arguments:", assortedArguments)
									remoteArguments = { _, unpack(assortedArguments) }
								end

								-- Check sub network commands
								if subNetwork.networkCommands[tostring(remoteArguments[2])] then
									local remoteData = {
										invoked = invoke,
										fired = not invoke,
										sentTick = os.clock(),
										sentOs = os.time(),
										network = subNetwork,
									}

									return subNetwork.networkRemoteCall(
										plr,
										invoke,
										remoteData,
										unpack(remoteArguments, 2)
									)
								end

								local taskName = "SubNetwork_"
									.. subNetwork.id
									.. "_Process_"
									.. plr.UserId
									.. "-Invoke:"
									.. tostring(invoke and true or false)
								local processRets = {
									service.trackTask(
										taskName,
										false,
										subNetwork.processFunc,
										parsedPlr,
										{ unpack(remoteArguments, 2) }
									),
								}
								local success, errMessage, errTrace = processRets[1], processRets[2], processRets[3]

								-- Log player interaction
								table.insert(subNetwork.processLogs, {
									title = "Player " .. plr.UserId .. " interacted with network",
									desc = (success and "No errors found during process")
										or "Error found: " .. tostring(errMessage),
									errTrace = not success and errTrace or nil,
									errMessag = not success and errMessage or nil,
									startedTick = os.clock(),
									startedOs = os.time(),

									arguments = { unpack(remoteArguments, 2) },
									processRanSuccess = success,
									processRets = cloneTable(processRets),

									player = parsedPlr,
								})

								if not success then
									subNetwork.processError:fire(parsedPlr, errMessage, errTrace)
									if subNetwork.processWarnError then
										warn(
											"Sub Network "
												.. tostring(subNetwork.id)
												.. " encountered an error with player "
												.. tostring(plr.UserId)
												.. ": "
												.. tostring(errMessage),
											errTrace
										)
									end
								else
									if invoke then return unpack(processRets, 2) end
								end
							end
						end
					end,
				})

				--subNetwork._trustChecker = Network.newCreate("SubNetwork-"..subNetwork.id.."-TrustCheck", {
				--	invokable = false;
				--	networkFunc = function(plr: Player, keyId: string)
				--		local parsedPlr = Parser:apifyPlayer(plr)
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
				--	end
				--})

				function subNetwork:createPlayerKey(player, expireOs)
					local playerKey = getRandomV3(subNetwork.playerKeySettings.keyLength)
					local trustKey = getRandomV3(subNetwork.playerKeySettings.trustKeyLength)
					local disconnectKey = getRandomV3(subNetwork.playerKeySettings.disconnectKeyLength)
					local keyInfo
					keyInfo = {
						active = true,
						destroyed = false,
						verifyStatus = false,
						verifiedSince = nil, -- (os time) Given by the system after verifying
						id = playerKey,
						trustKey = trustKey,
						clientAccessKey = nil, -- Given by the client
						expireOs = expireOs,
						trustChecked = false,
						trustKeyRetrieveAttempts = 0,
						disconnectId = disconnectKey,

						--// Events
						disconnected = Signal.new(),
						verified = Signal.new(),
						trustCheckStarted = Signal.new(),
						trustCheckEnded = Signal.new(),
					}

					function keyInfo:isActive()
						return self.active and (not self.expireOs or os.time() - self.expireOs < 0)
					end

					function keyInfo:isVerified() return self.verifyStatus end

					function keyInfo:isReadyToUse() return self:isActive() and self:isVerified() end

					function keyInfo:destroy()
						if not self.destroyed then
							self.destroyed = true
							self.active = false
							self.disconnected:fire(true)

							if self.playerLeftEvent then self.playerLeftEvent:disconnect() end

							self.verified:disconnect()

							subNetwork.networkKeys[player.playerId] = nil
						end
					end

					keyInfo.playerLeftEvent = player.disconnected:connectOnce(function() keyInfo:destroy() end)

					self.networkKeys[player.playerId] = keyInfo

					return playerKey, keyInfo
				end

				function subNetwork:revokePlayerKeys()
					for i, keyInfo in pairs(self.networkKeys) do
						keyInfo.active = false
						keyInfo.expireOs = os.time()
						self.networkKeys[i] = nil
					end
				end

				function subNetwork:getPlayerKey(player) return self.networkKeys[player.playerId] end

				function subNetwork:revokePlayerKey(player)
					local personalKey = self:getPlayerKey(player)
					if personalKey then personalKey:destroy() end
				end

				function subNetwork:get(player, ...)
					local personalKey = self:getPlayerKey(player)

					if personalKey then
						local activeKey = personalKey:isActive()
						if activeKey and not personalKey:isReadyToUse() then personalKey.verified:wait(nil, 300) end

						if activeKey and personalKey:isReadyToUse() then
							local remoteArguments = { ... }
							local endToEndEncryption = subNetwork.securitySettings.endToEndEncrypted

							if endToEndEncryption then
								local filteredArguments, instanceList = convertListToArgumentsAndInstances(...)
								remoteArguments = {
									encryptRemoteArguments(personalKey.clientAccessKey, filteredArguments),
									instanceList,
								}
							end

							return unpack(
								self._network2:runToPlayers(
									{ player._object },
									if endToEndEncryption
										then hashLib.sha1(personalKey.clientAccessKey)
										else personalKey.clientAccessKey,
									unpack(remoteArguments)
								)[1] or {}
							)
						end
					end
				end

				function subNetwork:fire(player, ...)
					local personalKey = self:getPlayerKey(player)

					if personalKey then
						local activeKey = personalKey:isActive()
						if activeKey and not personalKey:isReadyToUse() then personalKey.verified:wait(nil, 300) end

						if activeKey and personalKey:isReadyToUse() then
							local remoteArguments = { ... }
							local endToEndEncryption = subNetwork.securitySettings.endToEndEncrypted

							if endToEndEncryption then
								local filteredArguments, instanceList = convertListToArgumentsAndInstances(...)
								remoteArguments = {
									encryptRemoteArguments(personalKey.clientAccessKey, filteredArguments),
									instanceList,
								}
							end

							self._network1:runToPlayer(
								player._object,
								if endToEndEncryption
									then hashLib.sha1(personalKey.clientAccessKey)
									else personalKey.clientAccessKey,
								unpack(remoteArguments)
							)
						end
					end
				end

				function subNetwork:destroy()
					if self.active then
						self.active = false --self._network:Disconnect()
					end
				end

				-- [REQUIRED] Create a system session listener
				do
					local netSession = Remote.newSession()
				end

				SubNetworks[networkName] = subNetwork
				return subNetwork
			end
		end,

		newEvent = function(name, checkTable, rateLimit, expireOs)
			local eventData
			eventData = {
				id = getRandom(40),
				name = name or "_UNKNOWN",
				noName = not name,
				allowedTriggers = checkTable or {},
				expireOs = expireOs,
				rateLimit = rateLimit,
				_event = Signal.new(),
			}

			table.insert(PlayerEvents, eventData)
			return eventData
		end,

		isPlayerDoingTrustCheckOnSubNetworks = function(player: ParsedPlayer, usedTrustKey: string?)
			for subNetworkName: string, subNetwork: { [any]: any } in pairs(SubNetworks) do
				if subNetwork.active then
					local playerKey: { [any]: any } = subNetwork:getPlayerKey(player)
					if playerKey and not playerKey.trustChecked and playerKey.trustKey == usedTrustKey then
						return true
					end
				end
			end

			return false
		end,
	}
end
