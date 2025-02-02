--!nocheck
return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service
	local settings = server.Settings
	local variables = envArgs.variables

	local corotThread = envArgs.corotThread

	local Filter = server.Filter
	local Network = server.Network
	local Parser = server.Parser
	local Roles = server.Roles
	local Utility = server.Utility
	local Vela = server.Vela

	local HashLib = server.HashLib
	local Promise = server.Promise

	local Cmds, Core, Cross, Datastore, Identity, Logs, Moderation, Process, Remote
	local Datastore_Scopes = {
		BAN_CASES = `MD_BANCASES`,
		UNIVERSAL_BANS = `MD_UNIVERSALBANS`,
		LEGACY_BANCASES = `Banlist`,
	}
	local BanCase_Limits = {
		Notes_Length = 20,
		Note_CharLimit = 200,
	}
	local BanCase_EmptyTable = table.freeze {}
	local BanList_Limits = {
		MaxEntries = 30,
	}

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

		Moderation.cachePermissions()

		local globalBanCases = Moderation.globalBanCasesList
		local legacyGlobalBans = Moderation.legacyGlobalBans
		local function checkGlobalBans()
			local dataGlobalBans = Datastore.read(nil, Datastore_Scopes.UNIVERSAL_BANS)
			if type(dataGlobalBans) ~= "table" then dataGlobalBans = {} end

			table.clear(globalBanCases)

			local nowTimestamp = DateTime.now()
			for i, banInfo in pairs(dataGlobalBans) do
				if type(banInfo) == "table" then
					if not Moderation.isBanDataFormatted(banInfo, "UniversalBans") then
						task.defer(Datastore.tableRemove, nil, Datastore_Scopes.UNIVERSAL_BANS, "value", banInfo)
						continue
					else
						if banInfo.expiresOn and banInfo.expiresOn - nowTimestamp.UnixTimestampMillis <= 0 then
							task.defer(Datastore.tableRemove, nil, Datastore_Scopes.UNIVERSAL_BANS, "value", banInfo)
							continue
						end
					end

					globalBanCases[banInfo.caseId] = banInfo
				else
					task.defer(Datastore.tableRemove, nil, Datastore_Scopes.UNIVERSAL_BANS, "value", banInfo)
				end
			end

			local dataLegacyGlobalBans = Datastore.read(nil, Datastore_Scopes.LEGACY_BANCASES)
			if type(dataLegacyGlobalBans) ~= "table" then dataLegacyGlobalBans = {} end
			--warn(`data legacy bans:`, dataLegacyGlobalBans)

			table.clear(legacyGlobalBans)

			local nowOs = os.time()
			for i, banInfo in pairs(dataLegacyGlobalBans) do
				if type(banInfo) == "table" then
					if not Moderation.isBanDataFormatted(banInfo, "Legacy") then
						task.defer(Datastore.tableRemove, nil, Datastore_Scopes.LEGACY_BANCASES, "value", banInfo)
						continue
					else
						if banInfo.expireTime and banInfo.expireTime - nowOs <= 0 then
							task.defer(Datastore.tableRemove, nil, Datastore_Scopes.LEGACY_BANCASES, "value", banInfo)
							continue
						end
					end

					legacyGlobalBans[banInfo.id] = banInfo
				else
					task.defer(Datastore.tableRemove, nil, Datastore_Scopes.LEGACY_BANCASES, "value", banInfo)
				end
			end
		end

		service.trackTask("CHECK NOW GLOBAL BANS", true, checkGlobalBans)
		task.delay(180, service.loopTask, "LOOP UPDATE GLOBAL BANS", 180, checkGlobalBans)
	end

	server.Moderation = {
		Init = Init,

		datastore_scopes = service.tableRead(Datastore_Scopes),

		-- Ehh.. the important ones
		permissions = {},

		legacyGlobalBans = setmetatable({}, {
			__metatable = "Essential global bans",
		}),
		globalBanCases = setmetatable({}, {
			__metatable = "Essential global ban cases",
		}),
		globalBanCasesList = {},
		serverBans = {},
		serverBanCases = {},
		banProcessors = {},

		checkServerEntry = function(plr)
			local placeOwner = Identity.checkPlaceOwner(plr)
			local ignoreBan = placeOwner or false

			local serverWhitelisted = variables.whitelistData.enabled
			local whitelistData = variables.whitelistData
			local whitelistIgnore = server.Studio
				or placeOwner
				or Moderation.checkAdmin(plr)
				or (
					not whitelistData.admins and Identity.checkTable(plr, settings.WhiteList_Players or {})
					or Identity.checkTable(
						plr,
						whitelistData.whitelisted
							or {}
							or server.Roles:hasPermissionFromMember(plr, { "Manage_Server" })
					)
				)

			if variables.privateServerData then
				local privateServerData = variables.privateServerData

				local playerJoinData = plr:GetJoinData()
				local joinTeleportData = playerJoinData.TeleportData or {}
				local essTeleportData = joinTeleportData.EssPrivateTeleport

				if type(essTeleportData) ~= "string" then
					return false, "EssPrivate-InvalidTpData"
				else
					essTeleportData = Utility:decryptDataForTeleport(plr.UserId, essTeleportData, "join")
				end

				local originJobId = essTeleportData and essTeleportData.originJobId
				local privateServerJobId = game.JobId
				originJobId = originJobId ~= privateServerJobId and originJobId or nil

				local privateServerData = variables.privateServerData
				local serverWhitelist = privateServerData.whitelist or {}
				local serverBanlist = privateServerData.banlist or {}

				if privateServerData.inviteOnly then
					if not (privateServerData.creatorId == plr.UserId or Identity.checkTable(plr, serverWhitelist)) then
						return false, "EssPrivate-Invite", originJobId
					end
				end

				if privateServerData.adminLock then
					if not Moderation.checkAdmin(plr) then return false, "EssPrivate-AdminOnly", originJobId end
				end
			end

			if Utility.shutdownState then return false, "Shutdown", Utility.shutdownReason end

			if not server.Running then return false, "DeadLock" end

			--// Whitelist check
			if serverWhitelisted and not whitelistIgnore then return false, "Whitelist" end

			if not ignoreBan then
				local ban, banInfo: {
					isPermanent: boolean,
					caseId: string,
					moderatorId: string,
					reason: string,

					startedOn: number,
					expiresOn: number,
				} =
					Moderation.checkBanStatus(plr)

				--// Check bans
				if ban then return false, "Ban", banInfo end
			end

			return true
		end,

		--[[
			BAN STATUS FORMAT:
			
			{
				isPermanent: boolean;
				caseId: string;
				moderatorId: string;
				reason: string;
				
				startedOn: number;
				expiresOn: number;
			}
			
			Compatible check means that the checker will check for all types of ban
		]]
		checkBanStatus = function(
			player: ParsedPlayer | Player | string | number,
			checker: "BanCase" | "Settings" | "Legacy" | "Compatible" | nil,
			customBanCase: { [any]: any }
		)
			checker = checker or `Compatible`

			local _playerType = if Parser:isParsedPlayer(player) then `ParsedPlayer` else typeof(player)
			local playerUserId = if _playerType == "number"
				then math.floor(player)
				elseif _playerType == "Instance" and player:IsA "Player" then player.UserId
				elseif _playerType == "ParsedPlayer" then player.UserId
				elseif _playerType == "string" then service.playerIdFromName(player)
				else nil
			local isARealPlayer = _playerType == "ParsedPlayer" or (_playerType == "Instance" and player:IsA "Player")
			local isBanCompatible = checker == `Compatible`

			if (not playerUserId or playerUserId < 0) and not customBanCase then return false end

			-- Settings ban
			if isBanCompatible or checker == "Settings" then
				local isBanned = Identity.checkTable(playerUserId, settings.BanList)

				if isBanned then
					return true,
						{
							isPermanent = true,
							caseId = `Settings`,
							moderatorId = 0,
							reason = `Game developer settings`,

							startedOn = server.Started * 1000,
							expiresOn = -1,
						}
				end
			end

			if isBanCompatible or checker == "Legacy" then
				local isBanned, legacyBan = Moderation.checkBan(player, `Game`)

				if isBanned then
					return true,
						{
							isPermanent = legacyBan.type == "Game" or legacyBan.expireTime == nil or false,
							caseId = `L-{legacyBan.id}`,
							moderatorId = legacyBan.moderator.userid,
							reason = legacyBan.reason,

							startedOn = legacyBan.registered * 1000,
							expiresOn = if legacyBan.expireTime then legacyBan.expireTime * 1000 else nil,
						}
				end
			end

			-- Player data ban check
			local playerBanCase = if customBanCase
				then customBanCase
				else (function()
					for i, serverBanCase in Moderation.serverBanCases do
						if
							serverBanCase.status == "active"
							and table.find(serverBanCase.users, playerUserId)
							and not table.find(serverBanCase.releasedUsers, playerUserId)
						then
							return serverBanCase
						end
					end

					local pData = Core.getPlayerData(playerUserId)
					pData._updateIfDead()
					return pData.BanCase
				end)()

			if not playerBanCase then return false end

			if
				not (
					Moderation.isBanDataFormatted(playerBanCase, "PlayerData")
					or Moderation.isBanDataFormatted(playerBanCase, "BanCase")
				)
			then
				return false
			end
			if playerBanCase.expiresOn and playerBanCase.expiresOn <= DateTime.now().UnixTimestampMillis then
				return false
			end

			return true,
				{
					isPermanent = if playerBanCase.expiresOn then false else true,
					caseId = playerBanCase.caseId,
					moderatorId = playerBanCase.moderatorId,
					reason = playerBanCase.reason,

					startedOn = playerBanCase.startedOn,
					expiresOn = playerBanCase.expiresOn,
				}
		end,

		--// Deprecated
		checkBan = function(plr, checkInfo)
			local settingsBan = settings.BanList or {}
			--local savedBans = Moderation.savedBans or {}
			local serverBans = Moderation.serverBans or {}
			local serverBanCases = Moderation.serverBanCases

			-- Check settings ban
			if not checkInfo or checkInfo == true or checkInfo == "Setting" then
				if Identity.checkTable(plr.UserId, settingsBan) then
					return true,
						{
							moderator = {
								name = "Developer/System",
								userid = -1,
							},
							type = "Developer Setting",
							reason = "The developer/game have banned you via settings",
							registered = os.time(),
							offender = {
								name = plr.Name,
								userid = plr.UserId,
							},
							_offenderId = plr.UserId,
							contents = {},
							id = "setting",
						},
						true
				else
					if checkInfo == "Setting" then return end
				end
			end

			-- SAVED BAN TABLE INFORMATION
			--[[
				{
					moderator = {
						name = Moderator_Name;
						userid = Moderator_Id;
					};
					type = Ban_Type;
					reason = Ban_Reason;
					registered = Ban_Registered;
					expireTime = Ban_Expiration;
					offender = {
						name = Offender_Name;
						userid = Offender_Id;
					};
					_offenderId = plr.UserId;
					contents = {};
					id = service.getRandom(40);
				};
			]]

			local function checkBanInfo(ban)
				if ban.type ~= "Time" then
					if
						ban.offender.name == plr.Name
						or ban.offender.userid == plr.UserId
						or ban._offenderId == plr.UserId
					then
						return true, ban
					end
				else
					if ban.expireTime - os.time() > 0 then
						if
							ban.offender.name == plr.Name
							or ban.offender.userid == plr.UserId
							or ban._offenderId == plr.UserId
						then
							return true, ban
						end
					else
						return -1
					end
				end
			end

			local function tableCheck(tab)
				for i, ban in pairs(tab) do
					if type(ban) == "table" then
						local banStatus = checkBanInfo(ban)

						if banStatus == true then
							return true, service.cloneTable(ban)
						elseif banStatus == -1 then
							rawset(tab, i, nil)
						end
					elseif type(ban) == "number" and plr.UserId == ban then
						return true
					elseif type(ban) == "string" and Identity.checkMatch(plr.UserId, ban) then
						return true
					end
				end
			end

			--local found,info = tableCheck(savedBans)
			--if found then
			--	return true,info
			--end

			if not checkInfo or checkInfo == true or checkInfo == "Server" then
				local found2, info2 = tableCheck(serverBans)

				if found2 then
					return true, info2
				else
					if checkInfo == "Server" then return end
				end
			end

			if checkInfo and type(checkInfo) == "table" then
				return Moderation.isBanDataFormatted(checkInfo) and checkBanInfo(checkInfo) == true, checkInfo
			end

			-- Check global ban table
			local legacyGlobalBans = Moderation.legacyGlobalBans

			for i, valData in pairs(legacyGlobalBans) do
				if type(valData) == "table" then
					if Moderation.isBanDataFormatted(valData) and checkBanInfo(valData) == true then
						return true, valData
					end
				end
			end

			local pData = Core.getPlayerData(plr.UserId)
			if pData then
				if pData.Banned ~= nil then
					local banInfo = pData.Banned
					if Moderation.isBanDataFormatted(banInfo) and checkBanInfo(banInfo) == true then
						return true, banInfo
					end
				end
			end

			return false
		end,

		isBanDataFormatted = function(
			banData,
			checker: "Legacy" | "PlayerData" | "UniversalBans" | "List" | "BanNote" | nil
		)
			local legacy_formatTableType = {
				moderator = {
					name = "string",
					userid = "number",
				},
				type = "string",
				reason = "string",
				registered = "number",
				expireTime = "number/nil",
				offender = {
					name = "string",
					userid = "number",
				},
				_offenderId = "number",
				contents = "table",
				id = "string",
			}
			local playerdata_formatTableType = {
				caseId = "string",
				startedOn = "number",
				expiresOn = "number/nil",
				reason = "string",
			}

			local universalBanCaseInList_formatTableType = {
				caseId = "string",
				moderatorId = "number",
				users = "table",
				reason = "string",

				startedOn = "number",
				expiresOn = "number/nil",
			}

			local banCase_formatTableType = {
				type = "string",
				status = "string",

				caseId = "string",
				moderatorId = "number",
				users = "table",
				releasedUsers = "table",

				reason = "string",

				startedOn = "number",
				expiresOn = "number",

				useRobloxApi = "boolean",
				notes = "table", --// Plain note format {[number]: string}
			}

			checker = checker or "Legacy"

			if type(banData) ~= "table" then
				return false
			else
				local function checkType(givenType, value)
					local valType = type(value)

					if valType == "table" and type(givenType) == "table" then
						for i, type in pairs(givenType) do
							if not checkType(type, value[i]) then return false end
						end

						return true
					else
						if type(givenType) == "string" then
							if string.find(givenType, "/") then
								for type in string.gmatch(givenType, "[^/]+") do
									if valType == type then return true end
								end

								return false
							end
						end

						return valType == givenType
					end
				end

				if not checker or (checker == "Legacy") then
					for i, type in pairs(legacy_formatTableType) do
						if not checkType(type, banData[i]) then return false end
					end
				end

				if checker == "PlayerData" then
					for i, type in pairs(playerdata_formatTableType) do
						if not checkType(type, banData[i]) then return false end
					end
				end

				if checker == "UniversalBans" then
					for i, type in pairs(universalBanCaseInList_formatTableType) do
						if not checkType(type, banData[i]) then return false end
					end
				end

				if checker == "BanCase" then
					for i, type in pairs(banCase_formatTableType) do
						if not checkType(type, banData[i]) then return false end
					end
				end

				if checker == "BanNote" then
					return type(banData[1]) == "number"
						and type(banData[2]) == "number"
						and type(banData[3]) == "string"
				end

				return true
			end
		end,

		checkPlayerBansFromTable = function(player, customBanlist)
			for i, banData in customBanlist do
				if Moderation.isBanDataFormatted(banData) and Moderation.checkBan(player, banData) then
					return true, banData
				end
			end

			return false
		end,

		checkBans = function()
			Promise.each(service.getPlayers(), function(player: Player, index)
				local ban, banInfo = Moderation.checkBan(player)

				if ban then
					local banMessage = settings.BanMessage
					banMessage = (type(banMessage) == "string" and banMessage)
						or "The server is prohibiting you from joining"

					local banDate = (banInfo and banInfo.expireTime and server.Parser:osDate(banInfo.expireTime)) or nil

					banMessage = server.Parser:replaceStringWithDictionary(banMessage, {
						["{user}"] = player.Name .. " #" .. player.UserId,
						["{name}"] = player.Name,
						["{displayname}"] = player.UserId,
						["{userid}"] = player.UserId,
						["{moderator}"] = (banInfo and banInfo.moderator.name .. " #" .. banInfo.moderator.userid)
							or "SYSTEM",
						["{mod}"] = (banInfo and banInfo.moderator.name .. " #" .. banInfo.moderator.userid)
							or "SYSTEM",
						["{mod_name}"] = (banInfo and banInfo.moderator.name) or "SYSTEM",
						["{mod_id}"] = (banInfo and banInfo.moderator.userid) or "-1",
						["{id}"] = (banInfo and banInfo.id) or "n/a",
						["{type}"] = (banInfo and banInfo.type) or "Settings",
						["{reason}"] = (banInfo and banInfo.reason) or "Undefined",
						["{dueDate}"] = (banInfo and banDate) or server.Parser:osDate(banInfo.expireTime),
						["{expireTime}"] = (banInfo and banInfo.expireTime and tostring(
							math.max(banInfo.expireTime - os.time(), 0)
						)) or "INFINITE",
						["{startTime}"] = (banInfo and server.Parser:osDate(banInfo.registered)) or "n/a",
						["{relativeStartTime}"] = (banInfo and Parser:relativeTimestamp(banInfo.registered)) or "now",
						["{relativeEndTime}"] = (banInfo and banInfo.expireTime and Parser:relativeTimestamp(
							banInfo.expireTime
						)) or "N/A",
					})

					player:Kick("\n" .. banMessage)
				end
			end)
			--for i,plr in pairs(service.GetPlayers()) do
			--	local suc,ers = service.trackTask("CheckingBan_"..plr.UserId, true, function()
			--		local ban,banInfo = Moderation.checkBan(plr)

			--		if ban then
			--			local banMessage = settings.BanMessage
			--			banMessage = (type(banMessage)=="string" and banMessage) or "The server is prohibiting you from joining"

			--			local banDate = (banInfo and banInfo.expireTime and server.Parser:osDate(banInfo.expireTime)) or nil

			--			banMessage = server.Parser:replaceStringWithDictionary(banMessage, {
			--				["{user}"] 			= plr.Name.." #"..plr.UserId;
			--				["{name}"] 			= plr.Name;
			--				["{displayname}"] 	= plr.UserId;
			--				["{userid}"] 		= plr.UserId;
			--				["{moderator}"] 	= (banInfo and banInfo.moderator.name.." #"..banInfo.moderator.userid) or "SYSTEM";
			--				["{mod}"] 			= (banInfo and banInfo.moderator.name.." #"..banInfo.moderator.userid) or "SYSTEM";
			--				["{mod_name}"] 		= (banInfo and banInfo.moderator.name) or "SYSTEM";
			--				["{mod_id}"] 		= (banInfo and banInfo.moderator.userid) or "-1";
			--				["{id}"] 			= (banInfo and banInfo.id) or "n/a";
			--				["{type}"] 			= (banInfo and banInfo.type) or "Settings";
			--				["{reason}"]		= (banInfo and banInfo.reason) or "Undefined";
			--				["{dueDate}"]		= (banInfo and banDate) or server.Parser:osDate(banInfo.expireTime);
			--				["{expireTime}"]	= (banInfo and banInfo.expireTime and tostring(math.max(banInfo.expireTime-os.time(), 0))) or "INFINITE";
			--				["{startTime}"]		= (banInfo and server.Parser:osDate(banInfo.registered)) or "n/a";
			--				["{relativeStartTime}"] 	= (banInfo and Parser:relativeTimestamp(banInfo.registered)) or "now";
			--				["{relativeEndTime}"] 		= (banInfo and banInfo.expireTime and Parser:relativeTimestamp(banInfo.expireTime)) or "N/A";
			--			})

			--			plr:Kick("\n"..banMessage)

			--			return;
			--		end
			--	end)
			--end
		end,

		addBan = function(
			userName: string,
			banType: string,
			reason: string,
			registered: number?,
			moderator: { name: string, userid: number }?,
			expireTime: number?,
			save: boolean?,
			contents: {}?
		)
			-- SAVED BAN TABLE INFORMATION
			--[[
				{
					moderator = {
						name = Moderator_Name;
						userid = Moderator_Id;
					};
					type = Ban_Type;
					reason = Ban_Reason;
					registered = Ban_Registered;
					expireTime = Ban_Expiration;
					offender = {
						name = Offender_Name;
						userid = Offender_Id;
					};
					contents = {};
					id = service.getRandom(40);
				};
			]]

			local userid = service.playerIdFromName(userName) or 0
			local function removePlayerBan(banType)
				local banStat, banInfo = Moderation.checkBan({ UserId = userid }, banType)

				if banStat then
					if banType == "Game" or banType == "Time" then
						Datastore.tableRemove(nil, Datastore_Scopes.LEGACY_BANCASES, "value", banInfo)
					else
						Moderation.removeBan(userid, banType)
					end
				end
			end

			reason = if reason then reason:sub(1, 400) else "Unknown reason"
			moderator = (type(moderator) == "table" and service.cloneTable(moderator)) or {}
			expireTime = (type(expireTime) == "number" and expireTime) or os.time() + 86400 -- Default: 1 day

			if banType == "Server" then
				local banInfo
				banInfo = {
					moderator = {
						name = (moderator and moderator.name) or "SYSTEM",
						userid = (moderator and (moderator.userid or moderator.userId)) or -1,
					},
					type = banType,
					reason = reason or "undefined",
					registered = registered or os.time(),
					expireTime = nil,
					offender = {
						name = userName,
						userid = userid,
					},
					_offenderId = userid,
					contents = (type(contents) == "table" and service.cloneTable(contents)) or {},
					id = service.getRandom(20),
				}

				if userid > 0 then
					removePlayerBan(banType)

					table.insert(Moderation.serverBans, banInfo)
					server.Events.banAdded:fire(
						banType,
						{ name = userName, userId = userid },
						banInfo,
						moderator,
						false
					)

					Logs.addLog({ "Admin", "Script" }, {
						title = userName .. " (" .. userid .. ") was server-banned",
						desc = "Reason: " .. tostring(reason or "-undefined-"),
					})

					local plr = service.getPlayer(userName)

					if plr then
						local parsedPlr = Parser:apifyPlayer(plr)
						parsedPlr:Kick("Server Banned:\n" .. reason)
					end
				end
			end

			if banType == "Game" then
				local banInfo
				banInfo = {
					moderator = {
						name = (moderator and moderator.name) or "SYSTEM",
						userid = (moderator and (moderator.userid or moderator.userId)) or -1,
					},
					type = banType,
					reason = reason or "undefined",
					registered = registered or os.time(),
					expireTime = nil,
					offender = {
						name = userName,
						userid = userid,
					},
					_offenderId = userid,
					contents = (type(contents) == "table" and service.cloneTable(contents)) or {},
					id = service.getRandom(20),
				}

				if userid > 0 and Datastore.canWrite() then
					removePlayerBan "Time"
					removePlayerBan "Game"

					Datastore.tableAdd(nil, Datastore_Scopes.LEGACY_BANCASES, banInfo, false, function()
						Logs.addLog("Admin", {
							title = userName .. " (" .. userid .. ") was game-banned",
							desc = "Id: " .. banInfo.id .. " | Reason: " .. tostring(reason or "-undefined-"),
						})

						Cross.send("KickPlayers", { userid }, "Game banned")
					end)

					local pData = Core.getPlayerData(userid)
					if pData then
						pData.Banned = banInfo
						pData._updateIfDead()
					end

					server.Events.banAdded:fire(banType, { name = userName, userId = userid }, banInfo, moderator, true)
				end
			end

			if banType == "Time" then
				local expired = (expireTime and expireTime - os.time() <= 0) or false
				local banInfo
				banInfo = {
					moderator = {
						name = (moderator and moderator.name) or "SYSTEM",
						userid = (moderator and (moderator.userid or moderator.userId)) or -1,
					},
					type = banType,
					reason = reason or "undefined",
					registered = registered or os.time(),
					expireTime = (not expired and expireTime) or os.time() + 86400, -- Default: 1 day if not provided or given time was expired
					offender = {
						name = userName,
						userid = userid,
					},
					_offenderId = userid,
					contents = (type(contents) == "table" and service.cloneTable(contents)) or {},
					id = service.getRandom(20),
				}

				if expireTime and not expired then -- Expiration time must exist and not already expired to save nor not save
					if save then
						if userid > 0 and Datastore.canWrite() then
							removePlayerBan "Time"
							removePlayerBan "Game"

							Datastore.tableAdd(nil, Datastore_Scopes.LEGACY_BANCASES, banInfo, false, function()
								Logs.addLog("Admin", {
									title = userName .. " (" .. userid .. ") was gameTime-banned",
									desc = "Id: "
										.. banInfo.id
										.. " | ExpireTime: "
										.. banInfo.expireTime
										.. " | Reason: "
										.. tostring(reason or "-undefined-"),
								})

								Cross.send("KickPlayers", { userid }, "Game banned")
							end)

							local pData = Core.getPlayerData(userid)
							if pData then
								pData.Banned = banInfo
								pData._updateIfDead()
							end

							server.Events.banAdded:fire(
								banType,
								{ name = userName, userId = userid },
								banInfo,
								moderator,
								true
							)
						end
					else
						removePlayerBan "Server"

						server.Events.banAdded:fire(
							banType,
							{ name = userName, userId = userid },
							banInfo,
							moderator,
							false
						)
						table.insert(Moderation.serverBans, banInfo)

						Logs.addLog("Script", {
							title = "ServerTime-banned " .. tostring(userName) .. " (" .. userid .. ")",
							desc = "ExpireTime: " .. banInfo.expireTime .. " | Reason: " .. banInfo.reason,
						})
						Logs.addLog("Admin", {
							title = userName .. " (" .. userid .. ") was serverTime-banned",
							desc = "Id: " .. banInfo.id .. " | Reason: " .. tostring(reason or "-undefined-"),
						})

						local plr = service.getPlayer(userid)

						if plr then
							local parsedPlr = Parser:apifyPlayer(plr)
							parsedPlr:Kick("Server Banned:\n" .. reason)
						end
					end
				elseif expireTime and expired then
					error("Expire time had already passed (" .. os.time() - expireTime .. " seconds)")
				end
			end
		end,

		--[[
			BAN CREATION FORMAT:
			
			{
				type: "Universal"|"Server";
				caseId: string;
				moderatorId: string;
				reason: string;
				
				expiresOn: number;
				
				users = {[number]: user_id};
			}
			
				Notes:
					- Multiple users can have the same case.
					- Case Id is formatted based on timestamp, place id, and game server id
		]]

		createBan = function(
			banRegisterInfo: {
				type: "Universal" | "Server" | nil,
				expiresOn: number?, --// Must be in milliseconds

				users: { [number]: number | string },
				moderatorId: number,

				reason: string?,
				notes: { [number]: string },

				useRobloxApi: boolean?,
				affectAltAccounts: boolean?,
			},
			successCallback
		)
			assert(type(banRegisterInfo) == "table", "Ban info must be in a table")

			banRegisterInfo = service.shallowCloneTable(banRegisterInfo)
			banRegisterInfo.useRobloxApi = if type(banRegisterInfo.useRobloxApi) == "boolean"
				then banRegisterInfo.useRobloxApi
				else true --// Default: true
			banRegisterInfo.reason = if banRegisterInfo.reason
				then banRegisterInfo.reason:sub(1, 200)
				else `No reason specified`
			banRegisterInfo.moderatorId = banRegisterInfo.moderatorId or 0

			assert(
				type(banRegisterInfo.moderatorId) == "number"
					and math.floor(banRegisterInfo.moderatorId) == banRegisterInfo.moderatorId
					and math.abs(banRegisterInfo.moderatorId) ~= math.huge,
				`Moderator id must be an integer`
			)
			assert(
				not banRegisterInfo.type or table.find({ "Universal", "Server" }, banRegisterInfo.type),
				`Ban type {banRegisterInfo.type}`
			)
			banRegisterInfo.type = if not banRegisterInfo.type then `Server` else banRegisterInfo.type

			local banTimestamp = DateTime.now()
			local banStatusCode = if banRegisterInfo.type == "Universal"
				then (banRegisterInfo.expiresOn ~= nil and 11002) or 11001
				else 11004 -- Server

			-- Check notes
			do
				assert(
					not banRegisterInfo.notes
						or (type(banRegisterInfo.notes) == "table" and service.isTableAnArray(banRegisterInfo.notes)),
					`Ban notes must be an array of messages`
				)

				if banRegisterInfo.notes then
					for i, noteMessage in banRegisterInfo.notes do
						assert(type(noteMessage) == "string", `Ban note {i} must have a message in string`)
					end
				end
			end

			do
				assert(
					type(banRegisterInfo.users) == "table" and service.isTableAnArray(banRegisterInfo.users),
					"Banned users must be an array of userids/usernames"
				)
				assert(
					#banRegisterInfo.users > 0 and #banRegisterInfo.users < 10,
					`Banned users cannot be empty and must list up to 10 users or less`
				)
				for i, userIdOrName: number | string in banRegisterInfo.users do
					local userValueType = type(userIdOrName)
					assert(
						userValueType == "string" or userValueType == "number",
						"Banned users list values doesn't contain a string or integer"
					)
					assert(
						userValueType == "number" and math.floor(userIdOrName) == userIdOrName and userIdOrName > 0,
						"Banned users list values contains a decimal value"
					)

					if userValueType == "string" then
						local originalName = userIdOrName
						userIdOrName = service.playerIdFromName(userIdOrName)
						if userIdOrName <= 0 then error(`User {originalName} does not exist`, 2) end

						banRegisterInfo.users[i] = userIdOrName
					else
						assert(
							userIdOrName > 0 and service.playerNameFromId(userIdOrName) ~= `[unknown]`,
							`User with id {userIdOrName} does not exist`
						)
					end
				end

				if banRegisterInfo.expiresOn then
					assert(
						type(banRegisterInfo.expiresOn) == "number"
							and banRegisterInfo.expiresOn > banTimestamp.UnixTimestampMillis
							and math.floor(banRegisterInfo.expiresOn) == banRegisterInfo.expiresOn,
						"ExpiresOn must be an integer and cannot be past or current unix timestamp milliseconds"
					)
				end
			end

			assert(
				not successCallback or type(successCallback) == "function" or Promise.is(successCallback),
				`Success callback must be a function/Promise/nil`
			)

			local isBanCaseOnlyOnServer = banRegisterInfo.type == "Server"
			local banCaseId = HashLib.md5(`{banTimestamp.UnixTimestampMillis}-{service.getRandom(15)}`)

			if isBanCaseOnlyOnServer then banCaseId = `S-{banCaseId}` end

			local creationInfo = {
				type = banRegisterInfo.type,
				status = "active",

				caseId = banCaseId,
				moderatorId = banRegisterInfo.moderatorId,

				users = banRegisterInfo.users,
				releasedUsers = {},

				reason = banRegisterInfo.reason,

				startedOn = banTimestamp.UnixTimestampMillis,
				expiresOn = banRegisterInfo.expiresOn,

				useRobloxApi = if isBanCaseOnlyOnServer then false else banRegisterInfo.useRobloxApi,
				notes = {},
			}

			if banRegisterInfo.notes then
				for i, noteMessage in banRegisterInfo.notes do
					assert(type(noteMessage) == "string", `Ban note {i} must have a message in string`)
					table.insert(creationInfo.notes, { i, banTimestamp.UnixTimestampMillis, noteMessage })
				end
			end

			local creationPromise = Promise.promisify(function()
				if isBanCaseOnlyOnServer then
					table.insert(Moderation.serverBanCases, creationInfo)
					return
				end

				Datastore.readAndWrite(nil, Datastore_Scopes.UNIVERSAL_BANS, function(listOfUniversalBans)
					if type(listOfUniversalBans) ~= "table" or not service.isTableAnArray(listOfUniversalBans) then
						listOfUniversalBans = {}
					end

					local lengthOfList = #listOfUniversalBans
					local lengthExceeded = lengthOfList + 1 > BanList_Limits.MaxEntries

					repeat
						table.remove(listOfUniversalBans, 1)
					until #listOfUniversalBans == 0 or #listOfUniversalBans + 1 <= BanList_Limits.MaxEntries

					local minimizedBanCase = {
						caseId = banCaseId,
						moderatorId = banRegisterInfo.moderatorId,

						users = banRegisterInfo.users,
						reason = banRegisterInfo.reason,

						startedOn = banTimestamp.UnixTimestampMillis,
						expiresOn = banRegisterInfo.expiresOn,
					}

					table.insert(listOfUniversalBans, minimizedBanCase)
					Moderation.globalBanCasesList[banCaseId] = service.cloneTable(minimizedBanCase)

					return listOfUniversalBans
				end)

				Datastore.write(Datastore_Scopes.BAN_CASES, banCaseId, creationInfo)

				local banCache = Moderation.globalBanCases[banCaseId]
				if banCache then
					for index, value in banCache do
						banCache[index] = creationInfo[index]
					end

					banCache._cacheUpdated = tick()
				else
					banCache = service.cloneTable(creationInfo)
					banCache._cacheUpdated = tick()
					Moderation.globalBanCases[banCaseId] = banCache
				end
			end)()
				:andThen(function()
					return Promise.each(banRegisterInfo.users, function(userId, index)
						local playerData = Core.getPlayerData(userId)
						if not isBanCaseOnlyOnServer and playerData then
							playerData.BanCase = {
								caseId = banCaseId,
								moderatorId = banRegisterInfo.moderatorId,
								startedOn = banTimestamp.UnixTimestampMillis,
								expiresOn = banRegisterInfo.expiresOn,
								reason = banRegisterInfo.reason,
							}
						end

						return Promise.promisify(function() playerData._updateIfDead() end)():andThen(function()
							local player = service.getPlayer(userId)
							if player then
								local parsed = Parser:apifyPlayer(player)
								parsed:_kick(Parser:filterStringWithSpecialMarkdown(settings.banMessage, nil, {
									customReplacements = {
										["statusCode"] = banStatusCode,
										["moderator"] = if creationInfo.moderatorId > 0
											then service.playerNameFromId(creationInfo.moderatorId)
												.. ` ({creationInfo.moderatorId})`
											elseif creationInfo.moderatorId == -1 then `AutoModerator`
											else `System`,
										["mod_id"] = creationInfo.moderatorId,
										["moderatorId"] = creationInfo.moderatorId,
										["id"] = creationInfo.caseId,
										["caseId"] = creationInfo.caseId,
										["reason"] = creationInfo.reason,
										["startDate"] = Parser:osDate(
											math.floor(creationInfo.startedOn / 1000),
											nil,
											"longdatetime"
										) .. " UTC",
										["dueDate"] = if creationInfo.isPermanent
											then `Unknown`
											else Parser:osDate(
												math.floor(creationInfo.expiresOn / 1000),
												nil,
												"longdatetime"
											) .. " UTC",
										["relativeStartTime"] = Parser:relativeTimestamp(
											math.floor(creationInfo.startedOn / 1000)
										),
										["relativeEndTime"] = Parser:relativeTimestamp(
											math.floor(creationInfo.expiresOn / 1000)
										),
									},
								}))
							end
						end)
					end)
				end)
				:andThen(function()
					--// zDeprecated until further notice
					if not isBanCaseOnlyOnServer and banRegisterInfo.useRobloxApi then
						service.Players:BanAsync {
							UserIds = banRegisterInfo.users,
							ApplyToUniverse = banRegisterInfo.type == `Universal`,
							Duration = if banRegisterInfo.expiresOn
								then math.max(
									math.floor((banRegisterInfo.expiresOn - banTimestamp.UnixTimestampMillis) / 1000),
									1
								)
								else -1,
							DisplayReason = "[Essential Ban "
								.. banStatusCode
								.. "]\n"
								.. "Case Id: "
								.. banCaseId
								.. "\n"
								.. "Moderator Id: "
								.. banRegisterInfo.moderatorId
								.. "\n"
								.. ""
								.. "\nContact the in-game administrators for ban appeal or the full details of your "
								.. banRegisterInfo.type
								.. " ban",
							PrivateReason = `ESSENTIAL-BANCASE-{banCaseId}`,
							ExcludeAltAccounts = not banRegisterInfo.affectAltAccounts,
						}
					end
				end)
				:catch(
					function(err)
						warn(
							`Moderation createBan encountered an error while registering ban case for {table.concat(
								banRegisterInfo.users,
								", "
							)}:\n{tostring(err)}`
						)
					end
				)

			if Promise.is(successCallback) then
				creationPromise = creationPromise:andThen(
					function() return Promise.resolve(banCaseId):andThen(successCallback) end
				)
			elseif successCallback then
				creationPromise = creationPromise:finallyCall(successCallback, banCaseId)
			end

			return table.freeze(service.shallowCloneTable(creationInfo))
		end,

		addNoteToBanCase = function(caseId: string, noteMessage: string)
			assert(type(noteMessage) == "string" and utf8.len(noteMessage) > 0, "Note message must be a string")

			local function updateNotesInBanCase(banCase: string | number | boolean | { [any]: any } | nil)
				if type(banCase) == "table" then
					if type(banCase.notes) == "table" then
						local lengthOfBanNotes: number = #banCase.notes
						local newNoteId = if lengthOfBanNotes > 0 then banCase.notes[lengthOfBanNotes][1] + 1 else 1

						if lengthOfBanNotes + 1 > BanCase_Limits.Notes_Length then
							repeat
								table.remove(banCase.notes, 1)
							until #banCase.notes + 1 >= BanCase_Limits.Notes_Length
						end

						table.insert(
							banCase.notes,
							{ newNoteId, DateTime.now().UnixTimestampMillis, noteMessage:sub(1, 200) }
						)
					end

					if caseId:sub(1, 2) ~= "S-" then
						local banCache = Moderation.globalBanCases[caseId]
						if banCache then
							for index, value in banCache do
								banCache[index] = banCase[index]
							end

							banCache._cacheUpdated = tick()
						else
							banCache = service.cloneTable(banCase)
							banCache._cacheUpdated = tick()
							Moderation.globalBanCases[caseId] = banCache
						end
					end
				end
			end

			if caseId:sub(1, 2) == `S-` then
				local serverBanCase
				for i, otherSBCase in Moderation.serverBanCases do
					if otherSBCase.caseId == caseId then
						serverBanCase = otherSBCase
						break
					end
				end

				if serverBanCase then updateNotesInBanCase(serverBanCase) end

				return
			end

			Datastore.readAndWrite(
				Datastore_Scopes.BAN_CASES,
				caseId,
				function(banCase: string | number | boolean | { [any]: any } | nil)
					if Moderation.isBanDataFormatted(banCase, "BanCase") then updateNotesInBanCase(banCase) end

					return banCase
				end
			)
		end,

		removeNoteFromBanCase = function(caseId: string, noteId: number)
			assert(type(caseId) == "string" and #caseId > 0, "Case id must be a string and not empty")
			assert(type(noteId) == "number" and noteId > 0, "Note id must be a number and greater than zero")
			if caseId:sub(1, 2) == "L-" then return end

			local function updateNotesInBanCase(banCase: string | number | boolean | { [any]: any } | nil)
				if type(banCase) == "table" then
					if type(banCase.notes) == "table" then
						for i, banNote in banCase.notes do
							local otherNoteId = banNote[1]

							if otherNoteId == noteId then
								table.remove(banCase.notes, i)
								break
							end
						end
					end

					if caseId:sub(1, 2) ~= "S-" then
						local banCache = Moderation.globalBanCases[caseId]
						if banCache then
							for index, value in banCache do
								banCache[index] = banCase[index]
							end

							banCache._cacheUpdated = tick()
						else
							banCache = service.cloneTable(banCase)
							banCache._cacheUpdated = tick()
							Moderation.globalBanCases[caseId] = banCache
						end
					end
				end
			end

			if caseId:sub(1, 2) == `S-` then
				local serverBanCase
				for i, otherSBCase in Moderation.serverBanCases do
					if otherSBCase.caseId == caseId then
						serverBanCase = otherSBCase
						break
					end
				end

				if serverBanCase then updateNotesInBanCase(serverBanCase) end

				return
			end

			Datastore.readAndWrite(
				Datastore_Scopes.BAN_CASES,
				caseId,
				function(banCase: string | number | boolean | { [any]: any } | nil)
					if Moderation.isBanDataFormatted(banCase, "BanCase") then updateNotesInBanCase(banCase) end

					return banCase
				end
			)
		end,

		removeAllNotesFromBanCase = function(caseId: string)
			assert(type(caseId) == "string" and #caseId > 0, "Case id must be a string and not empty")
			if caseId:sub(1, 2) == "L-" then return end

			local function updateNotesInBanCase(banCase: string | number | boolean | { [any]: any } | nil)
				if type(banCase) == "table" then
					table.clear(banCase.notes)

					if caseId:sub(1, 2) ~= "S-" then
						local banCache = Moderation.globalBanCases[caseId]
						if banCache then
							for index, value in banCache do
								banCache[index] = banCase[index]
							end

							banCache._cacheUpdated = tick()
						else
							banCache = service.cloneTable(banCase)
							banCache._cacheUpdated = tick()
							Moderation.globalBanCases[caseId] = banCache
						end
					end
				end
			end

			if caseId:sub(1, 2) == `S-` then
				local serverBanCase
				for i, otherSBCase in Moderation.serverBanCases do
					if otherSBCase.caseId == caseId then
						serverBanCase = otherSBCase
						break
					end
				end

				if serverBanCase then updateNotesInBanCase(serverBanCase) end

				return
			end

			Datastore.readAndWrite(
				Datastore_Scopes.BAN_CASES,
				caseId,
				function(banCase: string | number | boolean | { [any]: any } | nil)
					if Moderation.isBanDataFormatted(banCase, "BanCase") then updateNotesInBanCase(banCase) end

					return banCase
				end
			)
		end,

		resolveBanCase = function(caseId: string, updateCallback)
			assert(type(caseId) == "string" and #caseId > 0, "Case id must be a string and not empty")
			assert(not updateCallback or type(updateCallback) == "function", "Update callback must be a function")
			if caseId:sub(1, 2) == "L-" then return end

			local isCaseIdServerOnly = caseId:sub(1, 2) == "S-"
			local function resolveBanCase(banCase)
				if type(banCase) == "table" then
					if banCase.status == "active" then
						banCase.status = "resolved"

						if not isCaseIdServerOnly then
							Promise.each(banCase.users, function(userId, index)
								if table.find(banCase.releasedUsers, userId) then return end
								local playerData = Core.getPlayerData(userId)

								if playerData then
									playerData._updateIfDead()
									if playerData.BanCase and playerData.BanCase.caseId == caseId then
										playerData.BanCase = nil
									end
								end
							end)
								:andThen(function()
									local banCache = Moderation.globalBanCases[caseId]
									if banCache then Moderation.globalBanCases[caseId] = nil end

									local listedBanCache = Moderation.globalBanCasesList[caseId]
									if listedBanCache then Moderation.globalBanCasesList[caseId] = nil end

									if updateCallback then task.spawn(updateCallback, true) end
								end)
								:catch(Logs.Reporters.Promise.issue(`Moderation Resolving Ban Case`, "Process"))
						end
					end

					if caseId:sub(1, 2) ~= "S-" then
						local banCache = Moderation.globalBanCases[caseId]
						if banCache then
							for index, value in banCache do
								banCache[index] = banCase[index]
							end

							banCache._cacheUpdated = tick()
						else
							banCache = service.cloneTable(banCase)
							banCache._cacheUpdated = tick()
							Moderation.globalBanCases[caseId] = banCache
						end
					end
				end
			end

			if isCaseIdServerOnly then
				local serverBanCase
				for i, otherSBCase in Moderation.serverBanCases do
					if otherSBCase.caseId == caseId then
						serverBanCase = otherSBCase
						break
					end
				end

				if serverBanCase then resolveBanCase(serverBanCase) end

				return
			end

			Datastore.readAndWrite(
				Datastore_Scopes.BAN_CASES,
				caseId,
				function(banCase: string | number | boolean | { [any]: any } | nil)
					resolveBanCase(banCase)

					return banCase
				end
			)

			Datastore.readAndWrite(nil, Datastore_Scopes.UNIVERSAL_BANS, function(listOfUniversalBans)
				if type(listOfUniversalBans) ~= "table" or not service.isTableAnArray(listOfUniversalBans) then
					listOfUniversalBans = {}
				end

				for i, minimizedBanCase in listOfUniversalBans do
					if
						Moderation.isBanDataFormatted(minimizedBanCase, "UniversalBans")
						and minimizedBanCase.caseId == caseId
					then
						table.remove(listOfUniversalBans, i)
						break
					end
				end

				return listOfUniversalBans
			end)
		end,

		resolveBanCaseForPlayers = function(caseId: string, userIds: { [number]: number })
			assert(type(caseId) == "string" and #caseId > 0, "Case id must be a string and not empty")
			assert(type(userIds) == "table" and #userIds > 0, `An array of user Ids must be a table and not empty`)
			if caseId:sub(1, 2) == "L-" then return end

			local isCaseIdServerOnly = caseId:sub(1, 2) == "S-"
			local function resolveBanCase(banCase, ignoreCase)
				if type(banCase) == "table" or ignoreCase then
					if not isCaseIdServerOnly then
						Promise
							.each(userIds, function(userId, index)
								if type(userId) ~= "number" then
								end
								if not ignoreCase and table.find(banCase.releasedUsers, userId) then return end

								local playerData = Core.getPlayerData(userId)
								playerData._updateIfDead()

								if playerData and playerData.BanCase and playerData.BanCase.caseId == caseId then
									playerData.BanCase = nil
								end
							end)
							--:andThen(function()
							--	if updateCallback then
							--	task.spawn(updateCallback, true)
							--end
							--end)
							:catch(
								Logs.Reporters.Promise.issue(`Moderation Resolving Ban Case`, "Process")
							)
					end

					if ignoreCase then return end

					local _resolvedUserIds = {}

					for i, userId in userIds do
						if
							type(userId) == "number"
							and table.find(banCase.users, userId)
							and not table.find(_resolvedUserIds, userId)
						then
							table.insert(_resolvedUserIds, userId)
							if not table.find(banCase.releasedUsers, userId) then
								table.insert(banCase.releasedUsers, userId)
							end
						end
					end

					if #banCase.users - #banCase.releasedUsers <= 0 and banCase.status ~= "resolved" then
						banCase.status = "resolved"
					end

					if caseId:sub(1, 2) ~= "S-" then
						local banCache = Moderation.globalBanCases[caseId]
						if banCache then
							for index, value in banCache do
								banCache[index] = banCase[index]
							end

							banCache._cacheUpdated = tick()
						else
							banCache = service.cloneTable(banCase)
							banCache._cacheUpdated = tick()
							Moderation.globalBanCases[caseId] = banCache
						end
					end
				end
			end

			if isCaseIdServerOnly then
				local serverBanCase
				for i, otherSBCase in Moderation.serverBanCases do
					if otherSBCase.caseId == caseId then
						serverBanCase = otherSBCase
						break
					end
				end

				if serverBanCase then resolveBanCase(serverBanCase) end

				return
			end

			Datastore.readAndWrite(
				Datastore_Scopes.BAN_CASES,
				caseId,
				function(banCase: string | number | boolean | { [any]: any } | nil)
					if not Moderation.isBanDataFormatted(banCase, "BanCase") then
						resolveBanCase(nil, true)
						return nil
					end

					resolveBanCase(banCase)

					return banCase
				end
			)
		end,

		getBanCase = function(caseId: string)
			assert(type(caseId) == "string" and #caseId > 0, "Case id must be a string and not empty")
			if caseId:sub(1, 2) == "L-" then return nil end
			if caseId:sub(1, 2) == "S-" then
				for i, banCase in Moderation.serverBanCases do
					if banCase.caseId == caseId then return banCase end
				end

				return nil
			end

			local existingCache = Moderation.globalBanCases[caseId]

			if not existingCache or tick() - existingCache._cacheUpdated > 300 then
				if not existingCache then
					existingCache = {
						type = "Unknown",
						status = "caching",
						caseId = caseId,
						moderatorId = 0,

						users = BanCase_EmptyTable,
						releasedUsers = BanCase_EmptyTable,

						reason = "",

						startedOn = 0,
						expiresOn = 0,

						useRobloxApi = false,
						notes = BanCase_EmptyTable,

						_cacheUpdated = tick(),
					}
					Moderation.globalBanCases[caseId] = existingCache
				end

				existingCache._cacheUpdated = tick()
				local dataBanCase = Datastore.read(Datastore_Scopes.BAN_CASES, caseId)

				if not dataBanCase or not Moderation.isBanDataFormatted(dataBanCase, "BanCase") then
					existingCache.status = `inactive`
				else
					for index, value in existingCache do
						if index == `_cacheUpdated` then continue end
						existingCache[index] = dataBanCase[index]
					end

					if
						existingCache.status == "active"
						and existingCache.expiresOn
						and DateTime.now().UnixTimestampMillis >= existingCache.expiresOn
					then
						existingCache.status = "resolved"
						task.defer(Moderation.resolveBanCase, caseId)
					end
				end
			end

			local realBanCase = table.clone(existingCache)
			realBanCase._cacheUpdated = nil

			return realBanCase
		end,

		processBan = function(player, banInfo: { [any]: any }?): boolean
			-- Check with the ban processors
			for i, process in pairs(Moderation.banProcessors) do
				local didHandle = process(player)

				if didHandle then
					return true -- Stop continuing the process if it's been handled
				end
			end

			-- Default processor
			if banInfo then
				local banMessage = settings.banMessage or settings.BanMessage
				banMessage = (type(banMessage) == "string" and banMessage)
					or "The server is prohibiting you from joining"

				local banDate = (banInfo and banInfo.expireTime and server.Parser:osDate(banInfo.expireTime)) or nil

				banMessage = Parser:replaceStringWithDictionary(banMessage, {
					["{user}"] = player.Name .. " #" .. player.UserId,
					["{name}"] = player.Name,
					["{displayname}"] = player.DisplayName,
					["{userid}"] = player.UserId,
					["{moderator}"] = (banInfo and banInfo.moderator.name .. " #" .. banInfo.moderator.userid)
						or "SYSTEM",
					["{mod}"] = (banInfo and banInfo.moderator.name .. " #" .. banInfo.moderator.userid) or "SYSTEM",
					["{mod_name}"] = (banInfo and banInfo.moderator.name) or "SYSTEM",
					["{mod_id}"] = (banInfo and banInfo.moderator.userid) or "-1",
					["{id}"] = (banInfo and banInfo.id) or "n/a",
					["{type}"] = (banInfo and banInfo.type) or "Settings/GlobalData",
					["{reason}"] = (banInfo and banInfo.reason) or "Undefined",
					["{dueDate}"] = (banInfo and server.Parser:osDate(banInfo.expireTime)) or "N/A",
					["{expireTime}"] = (banInfo and banInfo.expireTime and tostring(
						math.max(banInfo.expireTime - os.time(), 0)
					)) or "INFINITE",
					["{startTime}"] = (banInfo and server.Parser:osDate(banInfo.registered)) or "n/a",
					["{relativeStartTime}"] = (banInfo and Parser:relativeTimestamp(banInfo.registered)) or "now",
					["{relativeEndTime}"] = (banInfo and banInfo.expireTime and Parser:relativeTimestamp(
						banInfo.expireTime
					)) or "N/A",
				})

				server.Events.playerKicked:fire(player, "Banned", banInfo or "SYSTEM")
				player:Kick("\n" .. banMessage)
				return true
			else
				return false
			end
		end,

		addBanProcess = function(process)
			if not table.find(Moderation.banProcessors, Process) then
				table.insert(Moderation.banProcessors, process)
			end
		end,

		removeBanProcess = function(process)
			local processInd = table.find(Moderation.banProcessors, Process)
			if processInd then table.remove(Moderation.banProcessors, processInd) end
		end,

		removeBan = function(userid, banType, responsibleMod)
			userid = (type(userid) == "number" and userid) or 0
			banType = (type(banType) == "string" and banType) or "Server"
			responsibleMod = (type(responsibleMod) == "table" and service.cloneTable(responsibleMod)) or nil

			local serverBans = Moderation.serverBans
			--local savedBans = Moderation.savedBans

			if banType == "Server" then
				local didAttempt

				for i, ban in pairs(serverBans) do
					if type(ban) == "table" then
						if ban.type == banType and ban.offender.userid == userid then
							serverBans[i] = nil
							server.Events.banRemoved:fire(
								banType,
								{ name = ban.offender.name, userId = ban.offender.userid },
								ban,
								responsibleMod,
								false
							)
							didAttempt = true
						end
					elseif type(ban) == "number" then
						if ban == userid then
							serverBans[i] = nil
							server.Events.banRemoved:fire(
								banType,
								{ name = ban.offender.name, userId = ban.offender.userid },
								ban,
								responsibleMod,
								false
							)
							didAttempt = true
						end
					end
				end

				if didAttempt then return true end
			end

			if banType == "Game" or banType == "Time" then
				local banStatus, dataBan = Moderation.checkBan({ UserId = userid }, banType)

				if dataBan and type(dataBan) == "table" then
					if (banStatus == true or banStatus == -1) and dataBan.type:lower() == banType:lower() then
						local pData = Core.getPlayerData(userid)

						if pData then
							pData.Banned = nil
							pData._updateIfDead()
						end

						--server.playerDataGlobal:add(tostring(userid), {
						--	type = "changeData";
						--	index = "Banned";
						--	value = nil;
						--})

						Datastore.tableRemove(nil, Datastore_Scopes.LEGACY_BANCASES, "value", dataBan)
						server.Events.banRemoved:fire(
							banType,
							{ name = service.playerNameFromId(userid) or "[unknown]", userId = userid },
							dataBan,
							responsibleMod,
							true
						)
						return true
					end
					--elseif dataBan and banType == "Game" then
					--	server.playerDataGlobal:add(tostring(userid), {
					--		type = "changeData";
					--		index = "Banned";
					--		value = nil;
					--	})
					--	server.Events.banRemoved:fire(banType, userid, banStatus)
					--	return true
					--elseif dataBan and banType == "Force" then
					--	server.playerDataGlobal:add(tostring(userid), {
					--		type = "changeData";
					--		index = "Banned";
					--		value = nil;
					--	})
					--	server.Events.banRemoved:fire(banType, userid, "Force")
					--	return true
				end
			end

			--local savedBanRemoved = 0
			--for i,ban in pairs(savedBans) do
			--	if type(ban) == "table" then
			--		if ban.type == banType and ban.offender.userid == userid then
			--			rawset(savedBans, i, nil)
			--			savedBanRemoved = savedBanRemoved + 1
			--		end
			--	elseif type(ban) == "number" then
			--		if ban == userid then
			--			rawset(savedBans, i, nil)
			--			savedBanRemoved = savedBanRemoved + 1
			--		end
			--	end
			--end

			--if savedBanRemoved > 0 then
			--	savedBans._sync()
			--end
		end,

		warnPlayer = function(
			player: ParsedPlayer,
			warnOptions: { 
				reason: string,
				category: string,
				moderator: {name: string, userId: number}
			}
		)
			local pData = player:getPData()

			local moderatorData = warnOptions.moderator or {}
			local modUsername = moderatorData.Name or "[unknown]"
			local modUserId = moderatorData.UserId or 0

			local warnReason = warnOptions.reason or "no reason specified"
			local warnCategory = warnOptions.category or "default"
			local warnId = warnCategory .. "-" .. service.getRandom()

			if type(pData.warnings) ~= "table" then pData.warnings = {} end

			pData._tableAdd("warnings", {
				moderator = {
					name = modUsername,
					userId = modUserId,
				},

				reason = warnReason,
				created = os.time(),
				category = warnCategory,
				id = warnId,
			})
			pData._updateIfDead()

			if player:isReal() then
				Remote.privateMessage {
					receiver = player,
					sender = nil,
					topic = "Warning from moderator",
					desc = "This is a private message regarding that you've been warned by a moderator. Read the detail below about your warning.",
					message = table.concat({
						Parser:filterForRichText(warnReason),
						"",
						"----",
						"<b>Moderator:</b>",
						modUsername .. " (" .. modUserId .. ")",
						"",
						"<b>Category</b>: " .. tostring(warnCategory),
						"<b>Id:</b>: " .. warnId,
					}, "\n"),
					notifyOpts = {
						title = "You've been warned",
						desc = "Read to view private message",
					},
					readOnly = true,
				}
			end
		end,

		cachePermissions = function()
			local Roles = server.Roles

			for name, perm in pairs(settings.Permissions) do
				if type(perm) == "table" then
					local newRole = Roles:create(name, perm.Priority or 0, perm.Color, perm.Members, perm.Permissions)

					if newRole then
						for ind, val in pairs(perm) do
							newRole[tostring(ind):lower()] = val
						end
					end
				end
			end
		end,

		checkAdmin = function(check)
			check = (typeof(check) == "Instance" and check:IsA "Player" and check.UserId)
				or (type(check) == "userdata" and getmetatable(check) == "EP-" .. check.UserId and check.UserId)
				or check

			local checkType = type(check)

			if checkType == "number" or checkType == "string" then
				local result = false

				for i, role in pairs(server.Roles:getAll()) do
					if type(role) == "table" and role:checkPermissions { "Manage_Game" } then
						local checked = role:checkMember(check)

						if checked then
							result = true
							break
						end
					end
				end

				return result
			end

			return nil
		end,

		hasPermissions = function(check, perms) return server.Roles:hasPermissionFromMember(check, perms) end,

		getIncognitoPlayers = function()
			local list = {}

			for i, player in service.getPlayers() do
				local parsedPlayer = Parser:apifyPlayer(player)

				if parsedPlayer and parsedPlayer:isPrivate() then table.insert(list, parsedPlayer) end
			end

			return list
		end,

		updateIncognitoPlayersDynamicPolicy = function()
			local incognitoPlayers = Moderation.getIncognitoPlayers()
			local listOfIncognitosInUserId = {}

			--TODO: Work on permission Character_Incognito

			Promise.each(incognitoPlayers, function(target, index)
				if Roles:hasPermissionFromMember(target, { "Hide_Incognito" }) then
					table.insert(listOfIncognitosInUserId, target.UserId)
				end
			end):andThen(function()
				return Promise.each(service.getPlayers(), function(player)
					local parsedPlayer = Parser:apifyPlayer(player)

					if parsedPlayer and parsedPlayer:isInGame() then
						server.PolicyManager:setPolicyForPlayer(
							parsedPlayer,
							"INCOGNITO_PLAYERS",
							listOfIncognitosInUserId,
							`DYNAMIC`
						)
					end
				end)
			end)
		end,
	}
end
