local parser = {}
local server, service, getEnv = nil
local cloneTable, getRandom = nil
local luaParser, tulirAES, hashLib, base64, base64Encode, base64Decode, compression

local endToEndEncryption = false
--[[ ===================================
	TARGET SELECTORS
	
		admins					-		Selecting admins
		nonadmins				- 		Selecting non-admins
		genuines				-		Selecting verified people
		random					-		Selecting randoms
		friends					-		Selecting friends with the caller
		others					-		Selecting other players except the caller
		
		%team_name				-		Selecting teams with this
		@user_name				-		Selecting players with the username
		&role_name				-		Selecting players with the assigned roles with the name
		*range					-		Selecting players within a close range (i.g. *10 = 10-stud radius)
		$group_id				-		Selecting players in a valid group with id
		.display_name			-		Selecting players with this display name
		-excemption				-		Removing players with matches (usernames only)
		limit-limit_count		- 		Limiting selected players count to specified number
		!partial_user_name		-		Selecting players by checking a partial of their username
]]

local playerNameSelector = `%w+[\_]?%w*`
local selectors = {
	{ -- Admins
		match = "admins",
		public = true,
		permissions = {},
		run = function(caller, match)
			local list = {}

			for i, plr in pairs(service.getPlayers()) do
				if server.Moderation.checkAdmin(plr) then table.insert(list, plr) end
			end

			return list
		end,
	},
	{ -- Non admins
		match = "nonadmins",
		public = true,
		permissions = {},
		run = function(caller, match)
			local list = {}

			for i, plr in pairs(service.getPlayers()) do
				if not server.Moderation.checkAdmin(plr) then table.insert(list, plr) end
			end

			return list
		end,
	},
	{ -- Genuines
		match = "genuines",
		public = true,
		permissions = {},
		run = function(caller, match)
			local list = {}

			for i, plr in pairs(service.getPlayers()) do
				if plr:IsVerified() then table.insert(list, plr) end
			end

			return list
		end,
	},
	{ -- Select a random player
		match = "random",
		public = true,
		permissions = {},
		run = function(caller, match)
			local players = service.getPlayers()

			return { players[math.random(1, #players)] }
		end,
	},
	{ -- Friends of the caller
		match = "friends",
		public = true,
		permissions = {},
		requireCaller = true,
		run = function(caller, match)
			local list = {}

			if caller then
				for i, target in pairs(service.getPlayers(true)) do
					if
						target.UserId ~= caller.UserId and server.Identity.checkFriendship(caller.UserId, target.UserId)
					then
						table.insert(list, target)
					end
				end
			end

			return list
		end,
	},
	{ -- Caller
		match = "me",
		public = true,
		permissions = {},
		run = function(caller, match) return { caller } end,
	},
	{ -- Everyone except the caller
		match = "others",
		public = true,
		permissions = {},
		requireCaller = true,
		run = function(caller, match)
			local list = {}

			if caller then
				for i, target in pairs(service.getPlayers()) do
					if target.UserId ~= caller.UserId then table.insert(list, target) end
				end
			end

			return list
		end,
	},
	{ -- Everyone
		match = "all",
		public = true,
		permissions = {},
		run = function(caller, match) return service.getPlayers() end,
	},
	{ -- Players with exact specified username
		match = "^@([%w]*[_]?[%w]*)$",
		stringMatch = true,
		public = true,
		permissions = {},
		run = function(caller, match, selectedPlayers, filterOpts)
			local results = {}

			for i, plr in pairs(service.getPlayers()) do
				if plr.Name:lower() == match[1]:lower() then table.insert(results, plr) end
			end

			if filterOpts.allowFPCreation then
				local userIdFromMatch = service.playerIdFromName(match[1])

				if userIdFromMatch > 0 then
					table.insert(
						results,
						parser:apifyPlayer({
							Name = match[1],
							UserId = userIdFromMatch,
						}, true)
					)
				end
			end

			return results
		end,
	},
	{ -- Players with exact specified display name
		match = `^%.({playerNameSelector})$`,
		stringMatch = true,
		public = true,
		permissions = {},
		run = function(caller, match)
			local results = {}

			for i, plr in pairs(service.getPlayers()) do
				if plr.DisplayName:lower() == match[1]:lower() then table.insert(results, plr) end
			end

			return results
		end,
	},
	{ -- Players in specified roles
		match = "^&(.+)$",
		stringMatch = true,
		public = true,
		permissions = {},
		run = function(caller, match)
			local results = {}

			local role = server.Roles:get(match[1])

			if
				role
				and (
					not caller
					or role.mentionable
					or server.Roles:hasPermissionFromMember(caller.UserId, { "Mention_Roles" })
				)
			then
				for i, plr in pairs(service.getPlayers()) do
					if role:checkMember(plr.UserId) then table.insert(results, plr) end
				end
			end

			return results
		end,
	},
	{ -- Team
		match = "^%%(.+)$",
		stringMatch = true,
		public = true,
		permissions = {},
		run = function(caller, match)
			local results = {}
			local teams = {}

			for i, obj in pairs(service.Teams:GetChildren()) do
				if obj:IsA "Team" and obj.Name:lower():sub(1, #match[1]) == match[1]:lower() then
					table.insert(teams, obj)
				end
			end

			if #teams > 0 then
				for i, plr in pairs(service.getPlayers()) do
					if plr.Team and table.find(teams, plr.Team) then table.insert(results, plr) end
				end
			end

			return results
		end,
	},
	{ -- Within a range
		match = "^%*(%d+)$",
		stringMatch = true,
		public = true,
		permissions = {},
		requireCaller = true,
		run = function(caller, match)
			local results = {}
			local teams = {}

			local range = math.max(tonumber(match[1]), 3)

			if caller then
				local mainChar = caller.Character
				local mainHrp = mainChar and mainChar:FindFirstChild "HumanoidRootPart"

				if mainHrp then
					for i, plr in pairs(service.getPlayers()) do
						local char = plr.Character

						if plr ~= caller._object and char then
							local hrp = char:FindFirstChild "HumanoidRootPart"

							if hrp and hrp:IsA "BasePart" then
								local targetRange = (hrp.Position - mainHrp.Position).magnitude

								if targetRange <= range then table.insert(results, plr) end
							end
						end
					end
				end
			end

			return results
		end,
	},
	{ -- Removing players
		match = "^-(.+)$",
		stringMatch = true,
		public = true,
		permissions = {},
		run = function(caller, match, selectedPlayers)
			if not string.match(match[1], "^-(.*)$") then return end

			local playersFromMatch = parser:getPlayers(match[1], caller, {
				errorIfNone = false,
				noDuplicates = true,
			}) or {}

			for i, plr in pairs(selectedPlayers) do
				if table.find(playersFromMatch, plr) then selectedPlayers[i] = nil end
			end
		end,
	},
	{ -- DEFAULT: Selecting players by a partial of their display name
		match = `^({playerNameSelector})$`,
		stringMatch = true,
		public = true,
		permissions = {},
		run = function(caller, match)
			local results = {}

			for i, plr in pairs(service.getPlayers()) do
				if plr.DisplayName:lower():sub(1, #match[1]) == match[1]:lower() then table.insert(results, plr) end
			end

			return results
		end,
	},
	{ -- Limitng the amount of selection
		match = "^limit%-(%d+)$",
		stringMatch = true,
		public = true,
		permissions = {},
		run = function(caller, match, selectedPlayers)
			local maxCount = service.tableCount(selectedPlayers)
			local expectedCount = tonumber(match[1])

			if maxCount > 0 and expectedCount < maxCount then
				for i = maxCount, expectedCount + 1, -1 do
					if selectedPlayers[i] then selectedPlayers[i] = nil end
				end
			end
		end,
	},
	{ -- Selecting players with a partial of their username
		match = "^!([%w]*[_]?[%w]*)$",
		stringMatch = true,
		public = true,
		permissions = {},
		run = function(caller, match, selectedPlayers)
			local results = {}

			for i, plr in pairs(service.getPlayers()) do
				if plr.Name:lower():sub(1, #match[1]) == match[1]:lower() then table.insert(results, plr) end
			end

			return results
		end,
	},
}

local defaultGetPlayersFilter = table.freeze {
	admins = false, -- Selecting admins only
	noAdmins = false, -- No selecting admins
	noDuplicates = true, -- No duplicates. This is useful to prevent duplicated targets
	ignoreHigherPriority = false, -- Ignores others players with higher priority level than the player's
	ignoreCaller = false, -- Ignore the caller retrieving players
	errorIfNone = true,
	allowFPCreation = false, -- Allow fake player creation
	ignoreRestrictedSelections = false, -- Allow to filter with restricted selections policy
	ignoreIncognitoRestriction = false, -- Allow to filter incognito players

	whitelist = {},
	blacklist = {},

	ignoreRoles = {},
	ignorePerms = {},

	allowedRoles = {},
	allowedPerms = {},

	customSelection = {},
} -- Default filter

function parser:getPlayers(msg: string | table, caller: Player | ParsedPlayer, filter: { [any]: any }?): { [any]: any }
	local filter: { [any]: any } = filter or defaultGetPlayersFilter

	local customSelection: { [any]: any } = filter.customSelection
	local selectedPlayers: { [any]: any } = {}

	local isCallerSystem = not caller
	local isCallerAdmin = isCallerSystem or server.Moderation.checkAdmin(caller)

	if (not msg or #msg == 0) and caller then
		table.insert(selectedPlayers, caller)
	elseif msg then
		local function runSelector(selectorName: string, selector: { [any]: any }, part: string)
			local msgMatch
			local stringMatch = selector.stringMatch

			if not stringMatch and selector.match:lower() == part:lower() then
				msgMatch = { msg }
			elseif stringMatch and string.match(part, selector.match) then
				local strMatch = string.match(part, selector.match)

				if #strMatch > 0 then msgMatch = { strMatch } end
			end

			if msgMatch then
				local requireCaller = selector.requireCaller
				local canUseFilter = (isCallerSystem and not requireCaller)
					or (
						not isCallerSystem and selector.public
						or isCallerAdmin
						or server.Roles:hasPermissionFromMember(caller, selector.permissions or {})
					)

				if canUseFilter then
					local selectorRun = selector.run

					if not selectorRun then
						warn("Parser GetPlayers selector -> " .. tostring(selectorName) .. " run is missing")
					else
						local results = selectorRun(caller, msgMatch, selectedPlayers, filter)

						if results and type(results) ~= "table" then
							warn(
								"Parser GetPlayers selector -> "
									.. tostring(selectorName)
									.. " didn't return a table value (received "
									.. type(results)
									.. "?)"
							)
							results = {}
						elseif not results then
							results = {}
						end

						for i, result in pairs(results) do
							local isParsed = parser:isParsedPlayer(result)

							if not isParsed then
								table.insert(selectedPlayers, parser:apifyPlayer(result))
							else
								table.insert(selectedPlayers, result)
							end
						end
					end
				end
			end
		end

		for part in
			(type(msg) == "table" and ipairs(msg)) or (type(msg) == "string" and string.gmatch(msg, "[^,]+") or {})
		do
			local foundSelector

			if customSelection then
				for nameOrIndex, selector in customSelection do
					local msgMatch
					local stringMatch = selector.stringMatch

					if not stringMatch and selector.match:lower() == part:lower() then
						msgMatch = { msg }
					elseif stringMatch and string.match(part, selector.match) then
						msgMatch = { string.match(part, selector.match) }
					end

					if msgMatch then
						foundSelector = true
						runSelector(nameOrIndex, selector, part)
						break
					end
				end
			end

			if not foundSelector then
				for nameOrIndex, selector in selectors do
					local msgMatch
					local stringMatch = selector.stringMatch

					if not stringMatch and selector.match:lower() == part:lower() then
						msgMatch = { msg }
					elseif stringMatch and string.match(part, selector.match) then
						msgMatch = { string.match(part, selector.match) }
					end

					if msgMatch then
						foundSelector = true
						runSelector(nameOrIndex, selector, part)
						break
					end
				end
			end
		end
	end

	-- Filtering checks
	do
		if filter.admins then
			for i, target in pairs(selectedPlayers) do
				if not server.Moderation.checkAdmin(target) then table.remove(selectedPlayers, i) end
			end
		elseif filter.noAdmins then
			for i, target in pairs(selectedPlayers) do
				if server.Moderation.checkAdmin(target) then table.remove(selectedPlayers, i) end
			end
		end

		if filter.ignoreCaller and caller then
			for i, target in pairs(selectedPlayers) do
				if target.UserId == caller.UserId then table.remove(selectedPlayers, i) end
			end
		end

		if filter.whitelist and #filter.whitelist > 0 then
			local playerWhitelisted = {}

			for i, whitelist in pairs(filter.whitelist) do
				for _, target in pairs(selectedPlayers) do
					if not playerWhitelisted[target] then
						local check = server.Moderation.checkAdmin(target)
							or server.Identity.checkMatch(target, whitelist)

						if check then playerWhitelisted[target] = true end
					end
				end
			end

			for i, selected in pairs(selectedPlayers) do
				if not playerWhitelisted[selected] then table.remove(selected, i) end
			end
		elseif filter.blacklist and #filter.blacklist > 0 then
			local playerBlacklisted = {}

			for i, blacklist in pairs(filter.blacklist) do
				local isListATable = type(blacklist) == "table"
				local sortedTable = isListATable and service.checkTableIndexes(blacklist, "number")

				if not isListATable or not sortedTable then
					for _, target in pairs(selectedPlayers) do
						if not playerBlacklisted[target] then
							local check = server.Identity.checkMatch(target, blacklist)

							if check then playerBlacklisted[target] = true end
						end
					end
				elseif isListATable and sortedTable then
				end
			end

			for i, selected in pairs(selectedPlayers) do
				if not playerBlacklisted[selected] then table.remove(selected, i) end
			end
		end

		if filter.ignoreRoles and #filter.ignoreRoles > 0 then
			local checkList = {}

			for _, target in pairs(selectedPlayers) do
				if not checkList[target] then
					for i, role in pairs(filter.ignoreRoles) do
						local check = server.Roles:checkMemberInRoles(target, { role })

						if check then checkList[target] = true end
					end
				end
			end

			for _, target in pairs(selectedPlayers) do
				if not checkList[target] then table.remove(selectedPlayers, target) end
			end
		end

		if filter.ignorePerms and #filter.ignorePerms > 0 then
			local checkList = {}

			for _, target in pairs(selectedPlayers) do
				if not checkList[target] then
					for i, perm in pairs(filter.ignorePerms) do
						local check, missingPerms = server.Roles:hasPermissionFromMember(target, { perm })

						if check then checkList[target] = true end
					end
				end
			end

			for _ind, target in pairs(selectedPlayers) do
				if checkList[target] then table.remove(selectedPlayers, _ind) end
			end
		end

		if filter.allowedPerms and #filter.allowedPerms > 0 then
			local checkList = {}

			for _, target in pairs(selectedPlayers) do
				if not checkList[target] then
					for i, perm in pairs(filter.allowedPerms) do
						local check, missingPerms = server.Roles:hasPermissionFromMember(target, { perm })

						if check then checkList[target] = true end
					end
				end
			end

			for _ind, target in pairs(selectedPlayers) do
				if not checkList[target] then table.remove(selectedPlayers, _ind) end
			end
		end

		if filter.allowedRoles and #filter.allowedRoles > 0 then
			local checkList = {}

			for _, target in pairs(selectedPlayers) do
				if not checkList[target] then
					for i, role in pairs(filter.allowedRoles) do
						local check = server.Roles:checkMemberInRoles(target, { role })

						if check then checkList[target] = true end
					end
				end
			end

			for _ind, target in pairs(selectedPlayers) do
				if not checkList[target] then table.remove(selectedPlayers, _ind) end
			end
		end

		if not filter.ignoreRestrictedSelections and not isCallerAdmin then
			local parsedPlayer = if parser:isParsedPlayer(caller) then caller else parser:apifyPlayer(caller)

			if parsedPlayer then
				if parsedPlayer.policies.TARGETSELECTORS_ONLYSELF.value == true then
					for i, target in selectedPlayers do
						if target.UserId ~= caller.UserId then selectedPlayers[i] = nil end
					end
				else
					local disallowedSelectionIndexes = {}

					for i, selector: string | number in parsedPlayer.policies.TARGETSELECTORS_ALLOWLIST.value do
						local selectorType = type(selector)

						if selectorType == "string" then
							for i, target in selectedPlayers do
								if
									target.Name:lower() ~= parser:trimString(selector):lower()
									and not table.find(disallowedSelectionIndexes, target)
								then
									table.insert(disallowedSelectionIndexes, selector)
								end
							end
						end
					end

					for i, selector: string | number in parsedPlayer.policies.TARGETSELECTORS_IGNORELIST.value do
						local selectorType = type(selector)

						if selectorType == "string" then
							for i, target in selectedPlayers do
								if
									target.Name:lower() == parser:trimString(selector):lower()
									and not table.find(disallowedSelectionIndexes, target)
								then
									table.insert(disallowedSelectionIndexes, selector)
								end
							end
						end
					end

					for i, target in pairs(selectedPlayers) do
						if table.find(disallowedSelectionIndexes, target) then selectedPlayers[i] = nil end
					end
				end
			end
		end

		if not filter.ignoreIncognitoRestriction and not isCallerAdmin then
			local parsedPlayer = if parser:isParsedPlayer(caller) then caller else parser:apifyPlayer(caller)
			local ignoreIcognito = parsedPlayer.policies.IGNORE_INCOGNITO_PLAYERS.value == true or isCallerAdmin

			if not ignoreIcognito then
				for i, target in pairs(selectedPlayers) do
					if parsedPlayer and target.UserId == parsedPlayer.UserId then continue end

					local targetPData = target:getPData()
					if targetPData and targetPData.__clientSettings.IncognitoMode then selectedPlayers[i] = nil end
				end
			end
		end

		if filter.ignoreHigherPriority then
			local playerPriorityLevel = server.Roles:getHighestPriority(caller)

			for i, target in pairs(selectedPlayers) do
				local targetPriorityLevel = server.Roles:getHighestPriority(target)
				if targetPriorityLevel >= playerPriorityLevel then selectedPlayers[i] = nil end
			end
		end

		if filter.noDuplicates then
			local checkList = {}

			for i, target in pairs(selectedPlayers) do
				if checkList[target.UserId] or checkList[target] then
					selectedPlayers[i] = nil
				else
					checkList[target.UserId] = true
					checkList[target] = true
				end
			end
		end
	end

	local renewedSelection = {}

	-- Apify all selected players
	for i, selected in pairs(selectedPlayers) do
		local parsed = parser:isParsedPlayer(selected)

		if not parsed then
			table.insert(renewedSelection, parser:apifyPlayer(selected))
		else
			table.insert(renewedSelection, selected)
		end
	end

	if filter.errorIfNone and msg and #renewedSelection == 0 then
		if caller then
			caller:sendData("SendMessage", "Target Selection error", "<b>" .. msg .. "</b> was not found", 5, "Hint")
		end
	end

	local metaFunc = service.metaFunc
	local selectionMethods = {
		concat = function(...)
			local concatPlayers = {}

			for i, player in pairs(renewedSelection) do
				if parser:isParsedPlayer(player) then
					table.insert(
						concatPlayers,
						if caller and not isCallerAdmin
							then player:toStringDisplayForPlayer(caller)
							else player:toStringDisplay()
					)
				end
			end

			local suppliedArgs = { ... }

			return table.concat(
				concatPlayers,
				suppliedArgs[1],
				suppliedArgs[2],
				math.clamp(suppliedArgs[3] or #concatPlayers, 1, math.max(#concatPlayers, 1))
			)
		end,

		listUserIds = function()
			local list = {}
			for i, player in pairs(renewedSelection) do
				table.insert(list, player.UserId)
			end

			return list
		end,

		nonParsed = function(...)
			local nonParsedPlayers = {}

			for i, player in pairs(renewedSelection) do
				table.insert(nonParsedPlayers, player._object)
			end

			return nonParsedPlayers
		end,

		forEach = function(func)
			for i, player in pairs(renewedSelection) do
				service.threadTask(func, player)
			end
		end,

		getPlayer = function(playerIdOrName)
			assert(
				type(playerIdOrName) == "number" or type(playerIdOrName) == "string",
				"Argument #1 must be a string or number"
			)

			for i, player in pairs(renewedSelection) do
				if parser:isParsedPlayer(player) then
					if player.UserId == playerIdOrName or player.Name == playerIdOrName then return player end
				end
			end
		end,
	}

	setmetatable(renewedSelection, {

		__call = function(self, callType, ...)
			if selectionMethods[callType] then return metaFunc(selectionMethods[callType], true) end

			local rawName = ""

			if type(callType) == "string" then
				rawName = rawName
			else
				rawName = type(callType)
			end

			error("Invalid invoke method '" .. tostring(rawName) .. "'", 0)
		end,
		__len = function(self)
			local count = 0
			for i, v in pairs(renewedSelection) do
				count += 1
			end

			return count
		end,

		__iter = function(self)
			return pairs, renewedSelection
		end,

		__metatable = "Essential - Grouped players",
	})

	return renewedSelection
end

local apifiedPlayers = {}

function parser:isParsedPlayer(parsedPlr: ParsedPlayer): boolean
	if type(parsedPlr) == "userdata" then
		for i, data in pairs(apifiedPlayers) do
			if rawequal(data, parsedPlr) then return true end
		end
	end

	return false
end

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

function parser:apifyPlayer(
	player: Player | {
		Name: string,
		UserId: string,
	},
	fakePlayer: boolean?
)
	fakePlayer = if fakePlayer then true else false

	local isAPlayer = (typeof(player) == "Instance" and player:IsA "Player") or false

	if fakePlayer or isAPlayer then
		if apifiedPlayers[player.UserId] then
			local parsifiedPlayer = apifiedPlayers[player.UserId]

			if not fakePlayer and (parsifiedPlayer._object ~= player or parsifiedPlayer._instance ~= player) then
				parsifiedPlayer._object = player
				parsifiedPlayer._instance = player
				parsifiedPlayer:_setupRbxEvents()
			end

			return parsifiedPlayer
		elseif fakePlayer and apifiedPlayers[`_{player.UserId}`] then
			return apifiedPlayers[`_{player.UserId}`]
		else
			local self = { _fakePlayer = if fakePlayer then true else false }
			local playerVars = {}
			local playerUserId = player.UserId
			local selfProxy

			if fakePlayer then
				local plrAttributes = {}
				local plrHolder = service.New("Folder", { Name = player.Name })
				local _destroyed = false
				local plrTable
				plrTable = setmetatable({
					UserId = player.UserId,
					Name = player.Name,
					AccountAge = 0,
					ClassName = "Player",
					IsA = function(class)
						if rawequal(class, "Player") then return true end
					end,
					Character = service.New("Model", { Name = player.Name }),
					CharacterAppearanceId = player.UserId,
					DisplayName = server.Identity.getDisplayName(player.UserId),
					GetAttribute = function(self, attribute) return plrAttributes[attribute] end,
					GetAttributes = function() return cloneTable(plrAttributes) end,
					SetAttribute = function(self, attribute, val) plrAttributes[attribute] = val end,

					CharacterAdded = server.Signal.new(),
					CharacterAppearanceLoaded = server.Signal.new(),
					CharacterRemoving = server.Signal.new(),
					Chatted = server.Signal.new(),
					Idled = server.Signal.new(),
					OnTeleport = server.Signal.new(),
					SimulationRadiusChanged = server.Signal.new(),

					Destroy = function()
						if _destroyed then
							error("Attempted to destroy a LOCKED instance that has already been destroyed", 0)
						else
							service.Debris:AddItem(plrHolder, 0)
							_destroyed = true
						end
					end,

					Parent = service.Players,
				}, {
					__index = function(self, ind)
						local plrInd = plrHolder[ind]

						if type(plrInd) == "function" then
							return function(_, ...) return plrInd(plrHolder, ...) end
						else
							return plrInd
						end
					end,

					__newindex = function(self, ind, val) plrHolder[ind] = val end,

					__metatable = "ESP-" .. player.UserId,
				})

				player = plrTable
			end

			self._instance = player
			self._object = player
			self.playerId = (fakePlayer and "_" .. service.getRandom(40)) or service.getRandom(60)

			self._rbxEvents = server.Signal:createHandler()

			self.characterAdded = service.metaRead(self._rbxEvents.new("RbxEvent"):wrap())
			self.CharacterAdded = self.characterAdded
			self.characterRemoving = service.metaRead(self._rbxEvents.new("RbxEvent"):wrap())
			self.CharacterRemoving = self.characterRemoving

			self.disconnected = service.metaRead(self._rbxEvents.new("RbxEvent"):wrap())
			self.left = self.disconnected

			self.verified = service.metaRead(self._rbxEvents.new():wrap())

			function self:_setupRbxEvents()
				local plr: Player = self._object or self._instance

				if plr and typeof(plr) == "Instance" and plr:IsA "Player" and plr.Parent == service.Players then
					self:_stopRbxEvents()

					local playerLeftConnection = self._rbxEvents.new(`RbxEventConnection`)
					playerLeftConnection:connect(function()
						if plr.Parent ~= service.Players then
							self.disconnected:fire()
							self:_stopRbxEvents()
						end
					end)
					playerLeftConnection:linkRbxEvent(plr:GetPropertyChangedSignal "Parent")

					self.characterAdded:linkRbxEvent(plr.CharacterAdded)
					self.characterRemoving:linkRbxEvent(plr.CharacterRemoving)
				end
			end

			function self:_stopRbxEvents()
				self._rbxEvents:killSignals(`RbxEventConnection`)
				self.characterAdded:stopRbxEvents()
				self.characterRemoving:stopRbxEvents()
			end

			-- PolicyService policies
			self.socialPolicies = table.freeze {
				AreAdsAllowed = true,
				ArePaidRandomItemsRestricted = false,
				AllowedExternalLinkReferences = {},
				IsPaidItemTradingAllowed = false,
				IsSubjectToChinaPolicies = false,
			}

			function self:retrieveSocialPolicies()
				local plr = self._object or self._instance
				local canUpdatePolicies = not self.socialPoliciesLastUpdated
					or os.time() - self.socialPoliciesLastUpdated

				if canUpdatePolicies then
					self.socialPoliciesLastUpdated = os.time()

					local success, results = service.nonThreadTask(
						service.PolicyService.GetPolicyInfoForPlayerAsync,
						service.PolicyService,
						plr
					)

					if success and type(results) == "table" then
						self.socialPolicies = table.freeze(service.cloneTable(results))
					end
				end
			end

			function self:isAllowedToUseSocialMedia(socialMedia: string)
				return table.find(self.socialPolicies.AllowedExternalLinkReferences, socialMedia) and true or false
			end

			function self:hasSafeChat() return not self.socialPolicies.AreAdsAllowed end

			function self:sendData(...)
				local plr = self._object or self._instance

				if not fakePlayer and self:isInGame() then
					local cliData = server.Core.clients[plr]

					if cliData and cliData.ready and cliData.remoteEv then
						if not cliData.verified then self.verified:wait() end

						local remoteRateLimitData =
							{ server.Utility:deferCheckRate(self:getVar "clientRemoteRateLimit", "Remote") }
						local remoteRatePass, remoteRateResetOs = remoteRateLimitData[1], remoteRateLimitData[7]

						if not remoteRatePass then
							wait(remoteRateResetOs - tick())
							return self:sendData(...)
						end

						local remoteArguments = { ... }
						if endToEndEncryption then
							local filteredArguments, instanceList = convertListToArgumentsAndInstances(...)
							remoteArguments = {
								encryptRemoteArguments(cliData.clientRemoteKey, filteredArguments),
								instanceList,
							}
						end

						cliData.remoteEv.Instance:FireClient(
							plr,
							if endToEndEncryption
								then hashLib.sha1(cliData.clientRemoteKey)
								else cliData.clientRemoteKey,
							unpack(remoteArguments)
						)
					end
				end
			end

			function self:getData(...)
				local plr = self._object or self._instance

				if not fakePlayer and self:isInGame() then
					local cliData = server.Core.clients[plr]

					if cliData and cliData.ready and cliData.remoteFunc then
						if not cliData.verified then self.verified:wait() end

						local remoteRateLimitData =
							{ server.Utility:deferCheckRate(self:getVar "clientRemoteRateLimit", "Remote") }
						local remoteRatePass, remoteRateResetOs = remoteRateLimitData[1], remoteRateLimitData[7]

						if not remoteRatePass then
							wait(remoteRateResetOs - tick())
							return self:getData(...)
						end

						local idleTimeout = 300
						local returnSignal = server.Signal.new()

						local remoteArguments = { ... }
						if endToEndEncryption then
							local filteredArguments, instanceList = convertListToArgumentsAndInstances(...)
							remoteArguments = {
								encryptRemoteArguments(cliData.clientRemoteKey, filteredArguments),
								instanceList,
							}
						end

						service.trackTask("PLAYER " .. plr.UserId .. " GETDATA", true, function()
							local rets = {
								cliData.remoteFunc.Instance:InvokeClient(
									plr,
									if endToEndEncryption
										then hashLib.sha1(cliData.clientRemoteKey)
										else cliData.clientRemoteKey,
									unpack(remoteArguments)
								),
							}
							returnSignal:fire(unpack(rets))
						end)

						return returnSignal:wait(nil, idleTimeout)
					end
				end
			end

			function self:customGetData(idleTimeout, ...)
				local plr = self._object or self._instance

				if not fakePlayer and self:isInGame() then
					local cliData = server.Core.clients[plr]

					if cliData and cliData.ready and cliData.remoteFunc then
						if not cliData.verified then self.verified:wait() end

						local remoteRateLimitData =
							{ server.Utility:deferCheckRate(self:getVar "clientRemoteRateLimit", "Remote") }
						local remoteRatePass, remoteRateResetOs = remoteRateLimitData[1], remoteRateLimitData[7]

						if not remoteRatePass then
							wait(remoteRateResetOs - tick())
							return self:customGetData(idleTimeout, ...)
						end

						local idleTimeout = math.clamp(tonumber(idleTimeout) or 300, 5, 600)
						local returnSignal = server.Signal.new()

						local remoteArguments = { ... }
						if endToEndEncryption then
							local filteredArguments, instanceList = convertListToArgumentsAndInstances(...)

							remoteArguments = {
								encryptRemoteArguments(cliData.clientRemoteKey, filteredArguments),
								instanceList,
							}
						end

						service.trackTask("PLAYER " .. plr.UserId .. " GETDATA", true, function()
							local rets = {
								cliData.remoteFunc.Instance:InvokeClient(
									plr,
									if endToEndEncryption
										then hashLib.sha1(cliData.clientRemoteKey)
										else cliData.clientRemoteKey,
									unpack(remoteArguments)
								),
							}
							returnSignal:fire(unpack(rets))
						end)

						local disconnectEvent = self.disconnected:connectOnce(function() returnSignal:fire() end)

						local rets = { returnSignal:wait(nil, idleTimeout) }
						disconnectEvent:disconnect()

						return unpack(rets)
					end
				end
			end

			function self:getPData(ignoreLoading: boolean?)
				local plr = self._object or self._instance
				return server.Core.getPlayerData(plr.UserId, ignoreLoading)
			end

			function self:getVar(var) return playerVars[var] end

			function self:setVar(var, val) playerVars[var] = val end

			function self:getPing()
				if fakePlayer then
					return 0
				else
					local callStarted = tick()

					local ping = self:getData "TestRandom"
					if not rawequal(ping, "Received") then return 400000, callStarted end

					local callEnded = tick()
					local pingOs = (callEnded - callStarted) / 2
					local ms = service.roundNumber(pingOs * 1000, 0.001)

					return ms, callStarted
				end
			end

			function self:makeUI(uiName, data) self:sendData("MakeUI", uiName, data) end

			function self:makeUIGet(uiName, data) return self:getData("MakeUI", uiName, data) end

			function self:isInGame()
				local plr = self._object or self._instance
				return not fakePlayer and plr.Parent == service.Players
			end

			function self:isVerified()
				local cliData = server.Core.clients[self._object or self._instance]

				return (cliData and cliData.verified) or false
			end

			function self:isPrivate() -- similarly to icognito mode
				local pPolicies = self.policies

				if pPolicies.OVERRIDE_INCOGNITO_MODE.value ~= nil then
					return pPolicies.OVERRIDE_INCOGNITO_MODE.value and true or false
				end

				local pData = self:getPData(true)
				if pData then return pData.__clientSettings.IncognitoMode and true or false end

				return false
			end

			function self:isReal()
				local plr = self._object or self._instance
				return typeof(plr) == "Instance" and plr:IsA "Player" and plr.UserId == playerUserId
			end

			self.disguiseUserId = 0
			function self:isDisguised()
				return self.disguiseUserId > 0
			end

			function self:disguiseAsPlayer(targetUserId: number)
				if targetUserId == self.disguiseUserId then return end

				self.disguiseUserId = targetUserId

				if self:isInGame() then
					self:applyDisguise()

					local targetUsername = service.playerNameFromId(targetUserId)
					self:sendData("SendNotification", {
						title = "Character Disguise",
						description = if targetUserId == 0 or targetUserId == player.UserId then
							`You are back as your original character`
							else `You are now disguised as <b>{targetUsername}</b> ({targetUserId})`;
						time = 10;
					})
				end

			end

			function self:applyDisguise()
				local targetUserId = self.disguiseUserId

				if targetUserId == 0 or targetUserId == player.UserId then
					selfProxy:SetAttribute("DisplayName", nil)
					selfProxy:SetAttribute("DisplayNameColor", nil)
					self._object.CharacterAppearanceId = self._object.UserId

					local success, desc =
						pcall(service.Players.GetHumanoidDescriptionFromUserId, service.Players, self._object.UserId)
					
					local humanoid = selfProxy.Character and selfProxy.Character:FindFirstChildOfClass "Humanoid"

					if success and humanoid then
						humanoid:ApplyDescription(desc:Clone())
					end

					if humanoid then
						humanoid.DisplayName = self._object.DisplayName
					end
				end

				local targetDisplayName = server.Identity.getDisplayName(targetUserId)
				
				selfProxy:SetAttribute("DisplayName", targetDisplayName)
				-- selfProxy:SetAttribute("DisplayNameColor", server.TextChatModule:GetSpeakerNameColor(targetDisplayName))
				self._object.CharacterAppearanceId = targetUserId

				local success, desc =
					pcall(service.Players.GetHumanoidDescriptionFromUserId, service.Players, targetUserId)

				local humanoid = selfProxy.Character and selfProxy.Character:FindFirstChildOfClass "Humanoid"
				
				if success and humanoid then
					humanoid:ApplyDescription(desc:Clone())
				end

				if humanoid then
					humanoid.DisplayName = targetDisplayName
				end
			end

			function self:getInfo()
				local plr = self._object or self._instance
				return {
					name = plr.Name,
					userId = plr.UserId,
				}
			end

			function self:toStringDisplay()
				local plr = self._object or self._instance

				if plr.Name == plr.DisplayName then return plr.Name end

				return plr.DisplayName .. " (@" .. plr.Name .. ")"
			end

			function self:toStringPublicDisplay()
				local plr = self._object or self._instance
				local isPrivate = self:isPrivate()

				if isPrivate then
					local pData = self:getPData()
					return pData.incognitoName
				end

				if plr.DisplayName == plr.Name then return plr.Name end
				return plr.DisplayName .. " (@" .. plr.Name .. ")"
			end

			function self:toStringDisplayForPlayer(otherPlr: ParsedPlayer)
				if not otherPlr then return self:toStringDisplay() end

				local plr = self._object or self._instance
				if otherPlr.UserId == plr.UserId then return self:toStringDisplay() end

				local isPrivate = self:isPrivate()

				if isPrivate and not (server.Moderation.checkAdmin(otherPlr)) then
					local pData = self:getPData()
					return pData.incognitoName
				end

				if plr.DisplayName == plr.Name then return plr.Name end
				return plr.DisplayName .. " (@" .. plr.Name .. ")"
			end

			function self:toggleIncognitoStatus(status: boolean?, isEnforced: boolean?)
				status = if status == nil and isEnforced
					then nil
					elseif status ~= nil then (status and true) or false
					else not self:isPrivate()

				local oldStatus = self:isPrivate()

				if isEnforced then
					server.PolicyManager:setPolicyForPlayer(selfProxy, "OVERRIDE_INCOGNITO_MODE", status, "ENFORCED")
				else
					local pData = self:getPData()
					if pData then pData.__clientSettings.IncognitoMode = status end
				end

				local currentStatus = self:isPrivate()
				if oldStatus ~= currentStatus then server.Moderation.updateIncognitoPlayersDynamicPolicy() end
			end

			function self:generateIncognitoName()
				local pData = self:getPData()
				local incognitoName = server.NameGeneration:generate {
					NoSplitNames = false,
					IncludeSurName = true,
					NumberOfSurNames = 1,
				} .. ` {pData.encryptKey:sub(3, 6)}`

				pData.incognitoName = incognitoName
				--warn(`Player {player.Name} has a new incognito name: {incognitoName}`)
			end

			function self:kill()
				local plr = self._object or self._instance

				if not fakePlayer then
					local cliData = server.Core.clients[plr]
					local char = plr.Character

					if char then
						pcall(function() char.Parent = nil end)
						plr.Character = nil
					end

					if cliData.remoteEv then
						cliData.remoteEv.Instance:FireClient(plr, cliData.remoteServerKey, "Kill")
					end
				end
			end

			self.Kill = self.kill

			function self:executeCommand(command, suppliedArgs)
				local plr = self._object or self._instance
				return server.Core.executeCommand(plr, command, suppliedArgs)
			end

			function self:Kick(message)
				local plr = self._object or self._instance

				if self:isReal() then
					local kickMessage = tostring(settings.KickMessage or "")
					kickMessage = (#kickMessage > 0 and kickMessage) or "{reason}"
					message = (type(message) == "string" and #message > 0 and message) or nil

					local serverId = game.JobId

					if #game.PrivateServerId > 0 then
						serverId = "PS_" .. game.PrivateServerId .. "-" .. tostring(game.PrivateServerOwnerId)
					end

					local displayMessage = parser:replaceStringWithDictionary(kickMessage, {
						["{reason}"] = message or "Undefined",
						["{user}"] = plr.Name,
						["{name}"] = plr.DisplayName,
						["{displayname}"] = plr.DisplayName,
						["{mod}"] = "SYSTEM",
						["{moderator}"] = "SYSTEM",
						["{startTime}"] = parser:osDate(os.time()),
						["{serverId}"] = serverId,
						["{serverid}"] = serverId,
					})

					self:_kick(displayMessage)
				end
			end
			self.kick = self.Kick

			function self:_kick(message, kickType: "Kick" | "Moderation" | nil)
				local plr = self._object or self._instance

				if self:isReal() and plr.Parent == service.Players then
					server.Events.playerKicked:fire(plr, message, kickType)
					plr:Kick(message)
				end

				return self
			end

			function self:respawn(retreatToCurrentPos: boolean?, saveItems: boolean?)
				local plr = self._object or self._instance

				if self:isReal() then
					task.defer(function()
						local oldChar = plr.Character
						local oldCF
						local items = {}

						local backpack = plr:FindFirstChildOfClass "Backpack"

						if saveItems and backpack then
							for i, tool in ipairs(backpack:GetChildren()) do
								if tool:IsA "Tool" then
									table.insert(items, tool)
									tool.Parent = nil
								end
							end

							if oldChar then
								local curTool = oldChar:FindFirstChildOfClass "Tool"
								if curTool then
									table.insert(items, curTool)
									curTool.Parent = nil
								end
							end
						end

						if oldChar and retreatToCurrentPos then
							local primaryPart = oldChar:FindFirstChild "Head"
								or oldChar:FindFirstChild "HumanoidRootPart"
							if primaryPart and primaryPart:IsA "BasePart" then oldCF = primaryPart.CFrame end
						end

						if (saveItems and backpack) or (retreatToCurrentPos and oldCF) then
							local charAdded = server.Signal.new()
							charAdded:connect(function(newChar: Model)
								if not oldChar or newChar ~= oldChar then
									charAdded:disconnect()
									if saveItems and backpack then
										for i, item in ipairs(items) do
											task.delay(0.5, function() item.Parent = backpack end)
										end
									end

									if retreatToCurrentPos and oldCF then
										local primaryPart = newChar:WaitForChild("Head", 30)
											or newChar:WaitForChild("HumanoidRootPart", 30)

										if primaryPart and primaryPart:IsA "BasePart" then
											for i = 1, 10 do
												primaryPart.CFrame = oldCF
												if plr.Character ~= newChar or primaryPart.CFrame == oldCF then
													break
												else
													task.wait()
												end
											end
										end
									end
								end
							end)
							charAdded:linkRbxEvent(plr.CharacterAdded)
							charAdded:disconnect(30)
						end

						task.delay(0.1, function()
							if self:isInGame() then plr:LoadCharacter() end
						end)
					end)
				end
			end

			function self:refresh(saveItems: boolean?)
				if not fakePlayer then self:respawn(true, saveItems) end
			end

			function self:internalTeleport(
				serverAccessCodeOrJobId: string,
				isReserved: boolean?,
				failCallback: FunctionalTest?
			)
				local plr = self._object or self._instance

				if plr and typeof(plr) == "Instance" and plr:IsA "Player" then
					task.defer(function()
						local Utility, Parser = server.Utility, server.Parser

						local teleportSignData = Utility:encryptDataForTeleport(plr.UserId, {
							originJobId = game.JobId,
							originPlaceId = game.PlaceId,
						}, "join")
						local teleportOpts = service.New "TeleportOptions"

						local maxRetries, curRetries = 3, 0
						local function tryTeleport()
							if curRetries + 1 <= maxRetries then
								curRetries += 1
								if isReserved then
									teleportOpts.ReservedServerAccessCode = serverAccessCodeOrJobId
								else
									teleportOpts.ServerInstanceId = serverAccessCodeOrJobId
								end
								teleportOpts:SetTeleportData {
									EssPrivateTeleport = teleportSignData,
								}
								if self:isInGame() then
									service.TeleportService:TeleportAsync(game.PlaceId, { self._object }, teleportOpts)
								end
								return true
							else
								return false
							end
						end

						local telepFailCheck = server.Signal.new()
						telepFailCheck:connect(function(failedPlr, tpResult, tpErrMessage, tpPlaceId, usedTpOptions)
							if failedPlr == self._object and usedTpOptions == teleportOpts then
								if
									tpResult == Enum.TeleportResult.Failure
									or tpResult == Enum.TeleportResult.Flooded
								then
									local didSucceed = tryTeleport()
									if not didSucceed then
										telepFailCheck:disconnect()

										if failCallback then task.defer(failCallback, "error") end
									end
								elseif tpResult == Enum.TeleportResult.IsTeleporting then
									telepFailCheck:disconnect()
									if failCallback then task.defer(failCallback, "teleporting") end
								end
							end
						end)
						telepFailCheck:linkRbxEvent(service.TeleportService.TeleportInitFailed)
						telepFailCheck:disconnect(300)

						tryTeleport()
					end)
				end
			end

			function self:teleportToReserveWithSignature(
				privateServerAccessCode: string,
				failCallback: FunctionalTest
			)
				self:internalTeleport(privateServerAccessCode, true, failCallback)
			end

			function self:teleportToServer(serverJobId: string, failCallback: FunctionalTest)
				self:internalTeleport(serverJobId, false, failCallback)
			end

			function self:directMessage(directMessageOpts: {
				title: string?,
				text: string,
				time: number?,
				senderUserId: number?,
				noReply: boolean?,
			})
				directMessageOpts = directMessageOpts or {}
				local senderUserId = directMessageOpts.senderUserId

				local targetPData = self:getPData()
				task.defer(function()
					targetPData._updateIfDead()
					local directMessage = cloneTable(directMessageOpts)
					local directMessageId, goodId = nil, false

					repeat
						directMessageId = getRandom()

						local caughtDuplicate = false
						for i, otherMsg in (targetPData.messages or {}) do
							if otherMsg.id == directMessageId then
								caughtDuplicate = true
								break
							end
						end

						if not caughtDuplicate then goodId = true end
					until goodId

					directMessage.senderUserId = if type(senderUserId) == "number" then senderUserId else 0
					directMessage.id = directMessageId
					directMessage.openTime = directMessageOpts.openTime or 600
					directMessage.sent = os.time()
					targetPData._tableAdd("messages", directMessage)
				end)
			end

			function self:getClientData()
				local plr = self._object or self._instance

				if not fakePlayer then return server.Core.clients[plr] end
			end
			self.getRegisteredData = self.getClientData

			function self:getReplicator(): ServerReplicator
				local plr = self._object or self._instance

				if not fakePlayer then
					for i, replicator: ServerReplicator in pairs(server.Network:getReplicators()) do
						local player = replicator.player
						if player and player == plr then return replicator end
					end
				end
			end

			self:_setupRbxEvents()

			selfProxy = service.newProxy {
				__index = function(proxy, ind)
					local indexSelectedFromSelf = self[ind]

					if type(indexSelectedFromSelf) == "function" then
						return service.metaFunc(function(ignore, ...) return indexSelectedFromSelf(self, ...) end)
					elseif indexSelectedFromSelf ~= nil then
						return indexSelectedFromSelf
					end

					return (function()
						local plr = self._object or self._instance
						local selected = plr[ind]

						if type(selected) == "function" then
							return service.metaFunc(function(_, ...) return selected(plr, ...) end, true)
						else
							return selected
						end
					end)()
				end,

				__newindex = function(proxy, ind, val) self[ind] = val end,

				__tostring = function() return self:toStringDisplay() end,
				__metatable = "EP-" .. player.UserId,
			}

			local ste = tick()
			self.policies = server.PolicyManager:getClientPolicies(selfProxy)
			--warn(`policies retrieved took {tick()-ste} seconds`)
			if not fakePlayer then
				apifiedPlayers[player.UserId] = selfProxy
				apifiedPlayers[`_{player.UserId}`] = nil
			else
				apifiedPlayers[`_{player.UserId}`] = selfProxy
			end

			return selfProxy
		end
	end
end

function parser:getParsedPlayer(playerIdOrName: string | number, createIfNonExistent: boolean?): ParsedPlayer
	local player = service.getPlayer(playerIdOrName)
	
	if not player and createIfNonExistent then
		local playerUserId = if type(playerIdOrName) == "number" then playerIdOrName
			else service.playerIdFromName(playerIdOrName)
			
		return parser:apifyPlayer({
			Name = if type(playerIdOrName) == "string" then
				playerIdOrName else service.playerNameFromId(playerIdOrName);
			UserId = playerUserId;
		}, true)
	end
	
	return parser:apifyPlayer(player)
end

--TODO: GET PLAYER FROM INCOGNITO NAME
function parser:getParsedPlayerFromIncognitoName(incognitoName: string): ParsedPlayer
	for playerUserId, parsedPlr in pairs(apifiedPlayers) do
		if parsedPlr:isReal() then
			local pData = parsedPlr:getPData()
			if pData then
				local foundIncognitoName = pData.incognitoName
				if
					foundIncognitoName
					and #foundIncognitoName > 0
					and foundIncognitoName:lower() == incognitoName:lower()
				then
					return parsedPlr
				end
			end
		end
	end
end

function parser:replaceStringWithDictionary(str: string, dictionary: { [any]: any }): string
	local newstr = str or ""

	if type(dictionary) == "table" then
		for word, newWord in pairs(dictionary) do
			newstr = newstr:gsub(word, tostring(newWord or "")) or newstr
		end
	end

	return newstr
end

-- New replacement for Parser:replaceStringWithDictionary
-- Dictionary array: { matchPattern<string>, substitution<string|function>, isOneCharacter[boolean] }

function parser:filterStringWithDictionary(str: string, dictionary: { [number]: {} })
	assert(type(str) == "string", "Argument 1 must be a string")
	assert(type(dictionary) == "table", "Argument 2 must be a table")

	local newString = str
	local function filterPattern(selected: string, entryArray: {})
		local matchPattern: string = entryArray[1]
		local substitution: string = entryArray[2]
		local substitutionType: string | (...any) -> any = type(substitution)
		local isOneCharacter: boolean = entryArray[4]

		if isOneCharacter then
			local newSelected = {}

			for i = 1, utf8.len(selected), 1 do
				local letter = selected:sub(i, i)

				if letter == matchPattern then
					table.insert(newSelected, substitution)
				else
					table.insert(newSelected, letter)
				end
			end

			return table.concat(newSelected)
		end

		return select(1, string.gsub(selected, matchPattern, substitution))
	end

	for i, strMatchArray in dictionary do
		newString = filterPattern(newString, strMatchArray)
	end

	return newString
end

local defaultTextSettings = {
	richText = false,
}

function parser:filterStringWithSpecialMarkdown(
	str: string,
	delimiter: string?,
	textSettings: {
		richText: boolean,
	}?
)
	textSettings = textSettings or defaultTextSettings
	textSettings = table.clone(textSettings)
	textSettings.startedSince = textSettings.startedSince or os.time()

	local specialMarkdownList = server.SpecialTextMarkdown
	local messageArguments = parser:getArguments(str, delimiter or " ", {
		--includeQuotesInArgs = true;
		includeDelimiter = true,
	})

	for i, messageArg in messageArguments do
		for i, textMarkdown in specialMarkdownList do
			local markdownName, listOfMatches, onMatchDetection =
				tostring(textMarkdown[1]), textMarkdown[2], textMarkdown[3]
			local isRichTextMarkdown = markdownName:sub(1, 9) == `RichText-`
			local isTagMarkdown = markdownName:sub(1, 4) == "Tag-"

			if isTagMarkdown then continue end

			if isRichTextMarkdown and not textSettings.richText then continue end

			for d, markdownMatch in listOfMatches do
				messageArg = messageArg:gsub(`\{\{{markdownMatch}\}\}`, function(...: matchInParameters<array>)
					local detectionResult = onMatchDetection({ ... }, textSettings, parser)
					--// Error code is less than 0

					if type(detectionResult) == "number" and detectionResult < 0 then
						if detectionResult == 0 then return "{{forbidden}}" end
						return "{{unknown}}"
					else
						return detectionResult
					end
				end)
			end
		end

		messageArguments[i] = messageArg
	end

	--do
	--	local newString = table.concat(messageArguments)
	--	local secondMessageArguments = parser:getArguments(newString, delimiter or " ", {
	--		--includeQuotesInArgs = true;
	--		includeDelimiter = true;
	--		debugInfo = true;
	--	})

	--	for i, textMarkdown in specialMarkdownList do
	--		local markdownName, listOfMatches, onMatchDetection = tostring(textMarkdown[1]), textMarkdown[2], textMarkdown[3]
	--		local isTagMarkdown = markdownName:sub(1,4) == "Tag-"

	--		if not isTagMarkdown then
	--			continue
	--		end

	--		local startMatch, endMatch = listOfMatches[1], listOfMatches[2] or listOfMatches[1]
	--		local foundStartingMatch, matchOptions = restOfMessageFromStartIndex:match(`<({startMatch})%((.+)%)>`)
	--		local startMatchIndex, startMatchLastIndex;

	--		if not foundStartingMatch then
	--			foundStartingMatch = restOfMessageFromStartIndex:match(`<({startMatch})>`)
	--			startMatchIndex, startMatchLastIndex = restOfMessageFromStartIndex:find(`<({startMatch})>`)
	--		else
	--			startMatchIndex, startMatchLastIndex = restOfMessageFromStartIndex:find(`<({startMatch})%((.+)%)>`)
	--		end

	--		-- TODO: finish the tag markdown and make sure the tag markdown onMatchDetection runs after the tag markdown ends

	--		if not foundStartingMatch then
	--			continue
	--		end

	--		local foundEndMarkdown = false
	--		local restOfMessageAfterLastIndex = startMatchLastIndex+1

	--		--[[
	--			input: hell<o>sh</o> world!
	--			output: hellsh world!

	--		]]

	--		if restOfMessageAfterLastIndex:match(`<(/{endMatch})`) then
	--			local endMatchIndex, endMatchLastIndex = restOfMessageAfterLastIndex:find(`<(/{endMatch})`)
	--			local insideTheMarkdown = startMessageIndex:sub(1)

	--		else
	--			startMessageIndex = startMatchLastIndex + 1
	--		end

	--		--onTagMarkdown = true
	--		--tagMarkdownOptions = if matchOptions then parser:getArguments(matchOptions, delimiter or " ", {
	--		--	--includeQuotesInArgs = true;
	--		--	debugInfo = true;
	--		--}) else nil

	--		--tagMarkdownEndMatch = endMatch
	--		--startMessageIndex = startMatchLastIndex+1
	--	end
	--end

	return table.concat(messageArguments):gsub("&dlb;", "{{"):gsub("&drb;", "}}"):gsub("{", "{"):gsub("};", "}")
end
function parser:filterForSpecialMarkdownTags(str: string) return str:gsub("{{", "&dlb;"):gsub("}}", "&drb;") end

function parser:filterForSpecialMarkdownAndRichText(str: string)
	str = parser:filterForRichText(str)

	return parser:filterForSpecialMarkdownTags(str)
end

function parser:osDate(
	osTime: number,
	timezone: string?,
	dateAndTimeFormat: "shorttime" | "longtime" | "shortdate" | "longdate" | "shortdatetime" | "longdatetime" | "relativetime" | nil
): string
	if dateAndTimeFormat == "relativetime" then return parser:relativeTimestamp(osTime) end

	local date = os.date(timezone or "!*t", osTime or os.time())
	local year, month, day, hour, minute, sec = date.year, date.month, date.day, date.hour, date.min, date.sec

	if hour < 10 then hour = `0{hour}` end
	if minute < 10 then minute = `0{minute}` end
	if sec < 10 then sec = `0{sec}` end

	local monthName = ({
		"January",
		"February",
		"March",
		"April",
		"May",
		"June",
		"July",
		"August",
		"September",
		"October",
		"November",
		"December",
	})[date.month]

	local weekDayName = ({
		"Sunday",
		"Monday",
		"Tuesday",
		"Wednesday",
		"Thursday",
		"Friday",
		"Saturday",
	})[date.wday]

	if dateAndTimeFormat == "shorttime" then
		return `{hour}:{minute}`
	elseif dateAndTimeFormat == "longtime" then
		return `{hour}:{minute}:{sec}`
	elseif dateAndTimeFormat == "shortdate" then
		return `{day}/{month}/{year}`
	elseif dateAndTimeFormat == "longdate" then
		return `{day} {monthName} {year}`
	elseif dateAndTimeFormat == "shortdatetime" then
		return `{day} {monthName} {year} {hour}:{minute}`
	elseif dateAndTimeFormat == "longdatetime" then
		return `{weekDayName} {day} {monthName} {year} {hour}:{minute}`
	else
		-- Default (longdatetime)
		return `{weekDayName} {day} {monthName} {year} {hour}:{minute}`
	end
end

function parser:osTimestamp(unixTime: string?): DateTime
	return DateTime.fromIsoDate(unixTime)
	--return os.date("!%Y-%m-%dT%H:%M:%SZ", unixTime)
end

function parser:relativeTime(timeInSeconds: number) --// Similar to discord's timestamp easy readability
	assert(type(timeInSeconds) == "number", `Time in seconds`)
	timeInSeconds = math.floor(math.max(timeInSeconds, 0))

	local remaining = timeInSeconds
	local years = math.floor(remaining / 31536000)
	remaining -= years * 31536000

	local months = math.floor(remaining / 2592000)
	remaining -= months * 2592000

	local days = math.floor(remaining / 86400)
	remaining -= days * 86400

	local hours = math.floor(remaining / 3600)
	remaining -= hours * 3600

	local minutes = math.floor(remaining / 60)
	remaining -= minutes * 60

	local listToConcat = {}
	if years > 0 then table.insert(listToConcat, `{years} year{if years > 1 then "s" else ""}`) end
	if months > 0 then table.insert(listToConcat, `{months} month{if months > 1 then "s" else ""}`) end
	if days > 0 then table.insert(listToConcat, `{days} day{if days > 1 then "s" else ""}`) end
	if hours > 0 then table.insert(listToConcat, `{hours} hour{if hours > 1 then "s" else ""}`) end
	if minutes > 0 then table.insert(listToConcat, `{minutes} minute{if minutes > 1 then "s" else ""}`) end
	if remaining > 0 then table.insert(listToConcat, `{remaining} second{if remaining > 1 then "s" else ""}`) end

	return table.concat(listToConcat, ", ")
end

function parser:relativeTimestamp(osTime: number) --// Similar to discord's timestamp easy readability
	local nowOsTime = os.time()
	local minuteInSeconds = 60
	local hourInSeconds = minuteInSeconds * 60
	local dayInSeconds = hourInSeconds * 24
	local monthInSeconds = dayInSeconds * 30
	local yearInSeconds = dayInSeconds * 365

	local timeDifference = math.abs(nowOsTime - osTime)
	local behindTime = nowOsTime - osTime > 0

	if timeDifference == 0 then
		return "now"
	else
		if timeDifference >= yearInSeconds then
			local years = math.floor(timeDifference / yearInSeconds)
			return `{years} year{if years > 1 then "s" else ""}{if behindTime then " ago" else ""}`
		elseif timeDifference >= monthInSeconds then
			local months = math.floor(timeDifference / monthInSeconds)
			return `{months} month{if months > 1 then "s" else ""}{if behindTime then " ago" else ""}`
		elseif timeDifference >= dayInSeconds then
			local days = math.floor(timeDifference / dayInSeconds)
			return `{days} day{if days > 1 then "s" else ""}{if behindTime then " ago" else ""}`
		elseif timeDifference >= hourInSeconds then
			local hours = math.floor(timeDifference / hourInSeconds)
			return `{hours} hour{if hours > 1 then "s" else ""}{if behindTime then " ago" else ""}`
		elseif timeDifference >= minuteInSeconds then
			local minutes = math.floor(timeDifference / minuteInSeconds)
			return `{minutes} minute{if minutes > 1 then "s" else ""}{if behindTime then " ago" else ""}`
		else
			return `{timeDifference} second{if timeDifference > 1 then "s" else ""}{if behindTime then " ago" else ""}`
		end
	end
end

local _knownQuoteCharacters = { '"', "'" }
local defaultGetArgumentsFilterOptions = {
	ignoreQuotes = false,
	includeQuotesInArgs = false,
	includeDelimiter = false,
	debugInfo = false,
}

function parser:getArguments(
	str: string,
	delimiter: string,
	filterOptions: {
		maxArguments: number?,
		reduceDelimiters: boolean?,

		ignoreQuotes: boolean?,
		includeQuotesInArgs: boolean?,
		includeDelimiter: boolean?,
		debugInfo: boolean?,
	}
): { [any]: any }
	delimiter = delimiter or " "
	filterOptions = filterOptions or defaultGetArgumentsFilterOptions

	if utf8.len(str) == 0 then return {} end
	if table.find(_knownQuoteCharacters, delimiter) and not filterOptions.ignoreQuotes then
		error("Delimiter contains one of the known quote characters", 0)
	end

	local results = {}
	--local splitedArgs = string.split(str, delimiter)

	--for i,part in pairs(splitedArgs) do
	--	if #part > 0 then
	--		local trimmedPart = parser:trimString(part)

	--		if #trimmedPart > 0 then -- Make sure the trimmed string doesn't have nothing like ""
	--			table.insert(results, trimmedPart)
	--		end
	--	end
	--end
	local currentArg = ""
	local argumentInQuote = ""
	local targetQuoteChar = ""
	local inQuotationArg, inDelimiter = false, false
	local useDebugInfo = filterOptions.debugInfo
	local includeDelimiter = filterOptions.includeDelimiter
	local reduceDelimiters = filterOptions.reduceDelimiters
	local maxArguments = if filterOptions.maxArguments then math.max(filterOptions.maxArguments, 1) else math.huge

	local delimiterMatchCount = 0
	local delimiterLen = utf8.len(delimiter)
	local stringLen = utf8.len(str)

	local _numOfRealMatches = 0
	local lastIndexOfRealMatch = 0
	local canMergeArguments = function() return maxArguments <= _numOfRealMatches end
	local function addResultToTable(matchResult: string, isDelimiter: boolean, startIndex: number, endIndex: number)
		if isDelimiter and (not filterOptions.includeDelimiter and not canMergeArguments()) then return end

		if canMergeArguments() then
			local lastResult

			for i = #results, 1, -1 do
				if i == lastIndexOfRealMatch then lastResult = results[i] end
			end

			if lastResult and useDebugInfo then
				lastResult.match = lastResult.match .. matchResult
				lastResult.endIndex = endIndex
				lastResult.matchLength = utf8.len(lastResult.match .. matchResult)
				return
			elseif lastResult and not useDebugInfo then
				results[lastIndexOfRealMatch] = lastResult .. matchResult
				return
			end
		end

		if not isDelimiter then
			_numOfRealMatches += 1
		end

		lastIndexOfRealMatch = #results + 1
		table.insert(
			results,
			if not useDebugInfo
				then matchResult
				else {
					startIndex = startIndex,
					endIndex = endIndex,
					match = matchResult,
					matchIndex = if isDelimiter then 0 else _numOfRealMatches,
					matchLength = utf8.len(matchResult),
					isDelimiter = isDelimiter,
				}
		)
	end

	local function checkForNextQuoteMatches(targetQuote: string, startLen: number): boolean
		if startLen > stringLen then return false end
		for i = startLen, stringLen, 1 do
			local char = str:sub(i, i)
			if char == targetQuote then
				local escapeCharCheckPrevious = string.byte(str:sub(i - 1, i - 1)) == 92
				if escapeCharCheckPrevious then continue end

				return true
			end
		end

		return false
	end

	local function checkNextDelimiterMatches(targetStr: string, startLen: number, customLen: number?): number
		if startLen > utf8.len(targetStr) then return 0 end
		local stringLen = customLen or utf8.len(targetStr)
		local subMatches = 0
		local checkMatches = 0
		local lastCharLine

		for i = startLen, stringLen, 1 do
			local char = targetStr:sub(i, i)
			--warn("Target char:", char)
			--warn("Checking delimiter match:", delimiter:sub(initialCount+1, initialCount+1))
			if char == delimiter:sub(subMatches + 1, subMatches + 1) then
				local escapeCharCheckPrevious = string.byte(targetStr:sub(i - 1, i - 1)) == 92
				if escapeCharCheckPrevious then
					lastCharLine = i
					break
				end

				subMatches += 1
				--warn(`Delimiter sub check match found: {initialCount}`)
				subMatches = subMatches % delimiterLen

				if subMatches == 0 then
					checkMatches += 1
				elseif i == stringLen and subMatches > 0 then
					lastCharLine = i - subMatches + 1
				end
			else
				lastCharLine = i - subMatches

				break
			end
		end

		if subMatches > 0 and not lastCharLine then lastCharLine = stringLen end

		--warn("Delimiter matches:", checkMatches)

		return checkMatches, lastCharLine
	end

	local maxLen = utf8.len(str)
	local startFromLastCharLine
	local startLen = 1

	for i = 1, maxLen, 1 do
		if startFromLastCharLine and i < startFromLastCharLine then continue end

		local char = str:sub(i, i)
		if
			not filterOptions.ignoreQuotes
			and table.find(_knownQuoteCharacters, char)
			and (#targetQuoteChar == 0 or targetQuoteChar == char)
		then
			local escapeCharCheckPrevious = string.byte(str:sub(i - 1, i - 1)) == 92
			if escapeCharCheckPrevious then
				if inQuotationArg then
					argumentInQuote = argumentInQuote:sub(1, utf8.len(argumentInQuote) - 1) .. char
				else
					currentArg = currentArg:sub(1, utf8.len(currentArg) - 1) .. char
				end
				continue
			end

			if inDelimiter then
				if includeDelimiter then
					if #currentArg > 0 and delimiterMatchCount >= delimiterLen then
						addResultToTable(currentArg, true, startLen, i - 1)
					end
				end

				startLen = i
				currentArg = ""
			end
			delimiterMatchCount = 0
			inDelimiter = false

			inQuotationArg = not inQuotationArg

			if inQuotationArg then
				targetQuoteChar = char
				if not checkForNextQuoteMatches(char, i + 1) and not filterOptions.includeQuotesInArgs then
					currentArg = currentArg .. char
				end
			else
				targetQuoteChar = ""
			end

			if #argumentInQuote > 0 then
				currentArg = currentArg .. argumentInQuote
				argumentInQuote = ""
			end

			if filterOptions.includeQuotesInArgs then currentArg = currentArg .. char end
		elseif char == delimiter:sub(delimiterMatchCount + 1, delimiterMatchCount + 1) and not inQuotationArg then
			--// Delimiters do not have an escape character check
			--local escapeCharCheckPrevious = string.byte(str:sub(i-1,i-1)) == 92
			--if escapeCharCheckPrevious then
			--	if inQuotationArg then
			--		argumentInQuote = argumentInQuote:sub(1, utf8.len(argumentInQuote)-1) .. delimiter:sub(1, delimiterMatchCount+1)
			--	else
			--		currentArg = currentArg:sub(1,utf8.len(currentArg)-1) .. delimiter:sub(1, delimiterMatchCount+1)
			--	end

			--	continue
			--end
			if not inDelimiter and #currentArg > 0 then addResultToTable(currentArg, inDelimiter, startLen, i - 1) end
			startLen = i

			if not inDelimiter and includeDelimiter then currentArg = "" end
			inDelimiter = true

			local futureMatches, lastCharLine = checkNextDelimiterMatches(str, i, stringLen)

			if futureMatches > 0 then
				if includeDelimiter or canMergeArguments() then
					currentArg = if reduceDelimiters then delimiter else string.rep(delimiter, futureMatches)
					addResultToTable(
						currentArg,
						inDelimiter,
						startLen,
						if lastCharLine then lastCharLine - 1 else stringLen
					)
				end

				currentArg = ""
				delimiterMatchCount = 0

				startFromLastCharLine = lastCharLine
				if not lastCharLine then break end
			else
				if includeDelimiter then currentArg = currentArg .. char end
				inDelimiter = false
				startFromLastCharLine = nil
				delimiterMatchCount = 0
			end

			--if currentArg ~= "" then
			--	addResultToTable(currentArg, inDelimiter, startLen, lastCharLine-1)
			--	currentArg = ""
			--	delimiterMatchCount = 0
			--end

			startLen = startFromLastCharLine or startLen + 1
		else
			delimiterMatchCount = 0
			if inDelimiter and includeDelimiter and #currentArg > 0 then
				addResultToTable(currentArg, inDelimiter, startLen, i - 1)
				startLen = i
				currentArg = ""
			end
			inDelimiter = false

			if inQuotationArg then
				local delimiterMatches, endOfDelimiterLine = checkNextDelimiterMatches(str, i)
				if delimiterMatches > 0 then
					argumentInQuote = argumentInQuote
						.. (if reduceDelimiters then delimiter else string.rep(delimiter, delimiterMatches))
					if not endOfDelimiterLine or endOfDelimiterLine == stringLen then
						if not includeDelimiter then argumentInQuote = "" end
					else
						startFromLastCharLine = endOfDelimiterLine
					end
				else
					argumentInQuote = argumentInQuote .. char
				end
			else
				currentArg = currentArg .. char
			end
		end
	end

	if inQuotationArg and #argumentInQuote > 0 then
		currentArg = currentArg .. argumentInQuote
		addResultToTable(currentArg, inDelimiter, startLen, maxLen)
		--table.insert(results, argumentInQuote)
	elseif currentArg ~= "" then
		addResultToTable(currentArg, inDelimiter, startLen, maxLen)
		--table.insert(results, currentArg)
	end

	if filterOptions.debugInfo then
		local resultsWithoutDelimiter = {}

		for i, result in
			results :: {
				[number]: {
					startIndex: number,
					endIndex: number,
					match: string,
					matchIndex: number,
					isDelimiter: boolean,
				},
			}
		do
			if not result.isDelimiter then resultsWithoutDelimiter[result.matchIndex] = result.match end
		end

		return results, resultsWithoutDelimiter, inQuotationArg
	end

	return results, inQuotationArg
end

function parser:getMaxArguments(
	str: string,
	delimiter: string,
	maxArguments: number,
	ignoreQuotes: boolean?,
	includeQuotesInArgs: boolean?
): { [any]: any }
	delimiter = delimiter or " "
	maxArguments = math.max(maxArguments or 0, 1)

	local stringArguments = parser:getArguments(str, delimiter, {
		ignoreQuotes = ignoreQuotes,
		includeQuotesInArgs = includeQuotesInArgs,
	})

	if #stringArguments > maxArguments then
		local lastArgument = stringArguments[maxArguments]
		for i = maxArguments + 1, #stringArguments, 1 do
			lastArgument = lastArgument .. delimiter .. stringArguments[i]
		end
		for i = maxArguments + 1, #stringArguments, 1 do
			stringArguments[i] = nil
		end
		stringArguments[maxArguments] = lastArgument
	end

	--local firstResults = {}
	--local secondResults = {}
	--local splitedArgs = string.split(str, delimiter)

	--for i,part in ipairs(splitedArgs) do
	--	if #part > 0 then
	--		local trimmedPart = string.match(part, "^%s*(.-)%s*$")

	--		if #trimmedPart > 0 then -- Make sure the trimmed string doesn't have nothing like ""
	--			table.insert(firstResults, trimmedPart)
	--		end
	--	end
	--end

	--local argumentLen = 0
	--for i, arg in ipairs(firstResults) do
	--	argumentLen += 1
	--	if argumentLen <= maxArguments then
	--		table.insert(secondResults, table.concat({table.unpack(firstResults, argumentLen, (argumentLen==maxArguments and #firstResults) or argumentLen)}, delimiter))
	--	end
	--	--table.concat({table.unpack(msgArguments, processArgLen, (processArgLen==argsCount and #msgArguments) or processArgLen)}, delimiter)
	--end

	--if #secondResults > maxArguments then
	--	secondResults[maxArguments+1] = table.concat({table.unpack(secondResults, maxArguments+1)}, delimiter)
	--end

	return stringArguments
end

function parser:filterArguments(
	msgArguments: { [any]: any },
	argsList: { [any]: any },
	delimiter: string,
	player: ParsedPlayer? | Player?,
	plainFilter: boolean?
): { [any]: any }
	delimiter = delimiter or " "

	local results = {}
	local failedArgs = {}
	local filteredMessageArguments = table.clone(msgArguments)
	local argsCount = 0

	for i, arg in pairs(argsList) do
		argsCount = argsCount + 1
	end

	local processArgLen = 0

	for i, arg in pairs(argsList) do
		processArgLen = processArgLen + 1
		local msgArg = msgArguments[i]

		if type(arg) == "string" and msgArg then
			results[i] = table.concat({
				table.unpack(
					msgArguments,
					processArgLen,
					(processArgLen == argsCount and #msgArguments) or processArgLen
				),
			}, delimiter)
		elseif type(arg) == "table" and not plainFilter then
			local filtered = false
			local argType = arg.type

			if argType == "number" and msgArg then
				local number = tonumber(string.match(msgArg, "^[%d%p]+$")) or false

				if number then
					filtered = true
					results[i] = math.clamp(number, arg.min or 0, arg.max or math.huge)
				end
			elseif (argType == "int" or argType == "integer" or argType == "interval") and msgArg then
				local number = tonumber(string.match(msgArg, "^(%d+)$")) or false

				if number then
					local roundedNumber = math.floor(number)

					if number == roundedNumber then
						filtered = true

						local argMinimum = math.floor(math.clamp(arg.min or 0, 0, math.huge))
						local argMaximum = math.floor(math.clamp(arg.max or math.huge, argMinimum, math.huge))

						if number < argMinimum then
							filtered = false
							failedArgs[i] = string.format(
								"The integer you supplied must reach exactly at " .. argMinimum,
								argMinimum
							)
						elseif number > argMaximum then
							filtered = false
							failedArgs[i] =
								string.format("The integer you supplied must reach exactly or below %s", argMaximum)
						end

						if filtered or not arg.required then
							local realInteger = math.clamp(number, argMinimum, argMaximum)
							results[i] = realInteger
						end
					end
				else
					failedArgs[i] = true
				end
			elseif (argType == "trueOrFalse" or argType == "boolean") and msgArg then
				if msgArg:lower() == "true" then
					filtered = true
					results[i] = true
				elseif msgArg:lower() == "false" then
					filtered = true
					results[i] = false
				end
			elseif argType == "color" and msgArg then
				if msgArg:lower():match "^rgb%((%d+),(%d+),(%d+)%)$" then
					filtered = true

					local red, green, blue = msgArg:lower():match "^rgb%((%d+),(%d+),(%d+)%)$"
					results[i] = Color3.fromRGB(tonumber(red), tonumber(green), tonumber(blue))
				elseif msgArg:lower():match "^(%d+),(%d+),(%d+)$" then
					filtered = true

					local red, green, blue = msgArg:lower():match "^(%d+),(%d+),(%d+)$"
					results[i] = Color3.fromRGB(tonumber(red), tonumber(green), tonumber(blue))
				elseif msgArg:match "^#([%w]+)$" then
					local hexcode = msgArg:match "^#([%w]+)$"
					local hue, saturation, val =
						tonumber("0x" .. hexcode:sub(1, 2)),
						tonumber("0x" .. hexcode:sub(3, 4)),
						tonumber("0x" .. hexcode:sub(5, 6))

					filtered = true
					results[i] = Color3.fromHSV(hue, saturation, val)
				end
			elseif argType == "date" and msgArg then
				local calendarMonths = {
					"january",
					"february",
					"march",
					"april",
					"may",
					"june",
					"july",
					"august",
					"september",
					"october",
					"november",
					"december",
				}

				-- Military date
				local day, month, year = string.match(msgArg, "^(%d+)(%a+)(%d+)$")
				month = (month and (calendarMonths[month] or table.find(calendarMonths, month:lower())) and month)
					or nil
				day = (day and tonumber(day)) or nil
				year = (year and tonumber(year)) or nil

				if day and month and year then
					results[i] = {
						month = month,
						day = day,
						year = year,
					}
					filtered = true
					continue
				end

				-- Old school date
				local month, day, year = string.match(msgArg, "^(%d+)/(%d+)/(%d+)$")
				month = (month and calendarMonths[tonumber(month)]) or nil
				day = (day and tonumber(day)) or nil
				year = (year and tonumber(year)) or nil

				if day and month and year then
					results[i] = {
						month = month,
						day = day,
						year = year,
					}
					filtered = true
					continue
				end

				--> Second type of old school
				local month, day, year = string.match(msgArg, "^(%d+)-(%d+)-(%d+)$")
				month = (month and calendarMonths[month]) or nil
				day = (day and tonumber(day)) or nil
				year = (year and tonumber(year)) or nil

				if day and month and year then
					results[i] = {
						month = month,
						day = day,
						year = year,
					}
					filtered = true
					continue
				end

				-- Common date
				local month, day, year = string.match(msgArg, "(%d+)/(%d+)/(%d+)")
				month = (month and calendarMonths[month]) or nil
				day = (day and tonumber(day)) or nil
				year = (year and tonumber(year)) or nil

				if day and month and year then
					results[i] = {
						month = month,
						day = day,
						year = year,
					}
					filtered = true
					continue
				else
					failedArgs[i] = string.format "%s must supply the month, day, and year. (e.g. MM-DD-YY, MM/DD/YY)"
				end
			elseif argType == "time" and msgArg then
				if tonumber(msgArg) then
					local timeData = parser:getTime(tonumber(msgArg))
					local timeTab = {
						hour = math.clamp(timeData.hours, 0, math.huge),
						min = math.clamp(timeData.mins, 0, math.huge),
						sec = math.clamp(timeData.secs, 0, math.huge),
					}
					timeTab.total = math.floor((timeTab.hour * 3600) + (timeTab.min * 60) + timeTab.sec)
					results[i] = timeTab

					filtered = true
					continue
				end

				local min1, sec1 = string.match(msgArg, "^(%d+):(%d+)$")

				if min1 and sec1 then
					local timeTab = {
						hour = 0,
						min = math.clamp(tonumber(min1) or 0, 0, math.huge),
						sec = math.clamp(tonumber(sec1) or 0, 0, math.huge),
					}
					timeTab.total = math.floor((timeTab.hour * 3600) + (timeTab.min * 60) + timeTab.sec)
					results[i] = timeTab

					filtered = true
					continue
				end

				-- With seconds included

				local hour2, min2, sec2 = string.match(msgArg, "^(%d+):(%d+):(%d+)$")

				if hour2 and min2 and sec2 then
					local timeTab = {
						hour = math.clamp(tonumber(hour2) or 0, 0, math.huge),
						min = math.clamp(tonumber(min2) or 0, 0, math.huge),
						sec = math.clamp(tonumber(sec2) or 0, 0, math.huge),
					}
					timeTab.total = math.floor((timeTab.hour * 3600) + (timeTab.min * 60) + timeTab.sec)
					results[i] = timeTab

					filtered = true
					continue
				else
					failedArgs[i] = string.format(
						"%s must supply the hour, minute, and second. (e.g. 1:20:30 - 1 hour, 20 minutes, & 30 seconds)",
						msgArg
					)
				end
			elseif argType == "duration" and msgArg then
				local justSecs = tonumber(string.match(msgArg, "^(%d+)$"))
				local minSeconds = arg.minDuration or arg.minSeconds
				local maxSeconds = arg.maxDuration or arg.maxSeconds

				if justSecs then
					justSecs = math.floor(justSecs)
					justSecs = math.clamp(justSecs, minSeconds or 0, maxSeconds or math.huge)

					local origSecs = justSecs
					local years = math.floor(justSecs / 31556952)
					justSecs = justSecs - (years * 31556952)

					local months = math.floor(justSecs / 2629746)
					justSecs = justSecs - (months * 2629746)

					local weeks = math.floor(justSecs / 604800)
					justSecs = justSecs - (weeks * 604800)

					local days = math.floor(justSecs / 86400)
					justSecs = justSecs - (days * 86400)

					local hours = math.floor(justSecs / 3600)
					justSecs = justSecs - (hours * 3600)

					local minutes = math.floor(justSecs / 60)
					justSecs = justSecs - (minutes * 60)

					results[i] = {
						secs = justSecs,
						mins = minutes,
						hours = hours,
						days = days,
						weeks = weeks,
						months = months,
						years = years,

						total = origSecs,
					}

					filtered = true
					continue
				end

				local secs = math.clamp(math.floor(tonumber(string.match(msgArg, "(%d+)s")) or 0), 0, math.huge)
				local mins = math.clamp(math.floor(tonumber(string.match(msgArg, "(%d+)m$")) or 0), 0, math.huge)
				local hours = math.clamp(math.floor(tonumber(string.match(msgArg, "(%d+)h")) or 0), 0, math.huge)
				local days = math.clamp(math.floor(tonumber(string.match(msgArg, "(%d+)d")) or 0), 0, math.huge)
				local months = math.clamp(math.floor(tonumber(string.match(msgArg, "(%d+)mo")) or 0), 0, math.huge)
				local weeks = math.clamp(math.floor(tonumber(string.match(msgArg, "(%d+)w")) or 0), 0, math.huge)
				local years = math.clamp(math.floor(tonumber(string.match(msgArg, "(%d+)y")) or 0), 0, math.huge)

				local totalSeconds = secs
					+ (mins * 60)
					+ (hours * 3600)
					+ (days * 86400)
					+ (months * 2629746)
					+ (weeks * 604800)
					+ (years * 31536000)

				local minDuration = tonumber(arg.minimum)
				local maxDuration = tonumber(arg.maximum)
				local inputPass = false

				if minDuration and not maxDuration then
					if totalSeconds >= minDuration then inputPass = true end
				elseif maxDuration and not minDuration then
					if totalSeconds <= maxDuration then inputPass = true end
				elseif minDuration and maxDuration then
					if totalSeconds >= minDuration and totalSeconds <= maxDuration then inputPass = true end
				elseif not minDuration and not maxDuration then
					inputPass = true
				end

				if inputPass then
					filtered = true
					results[i] = {
						secs = secs,
						mins = mins,
						hours = hours,
						days = days,
						weeks = weeks,
						years = years,

						total = totalSeconds,
					}
					continue
				else
					failedArgs[i] = string.format "%s isn't a valid duration. (e.g. 1m - 1 minute)"
				end
			elseif argType == "command" and msgArg then
				local isPermissionLocked = arg.permissionLocked
				local cmdFromInput, cmdMatch = server.Commands.get(msgArg)

				if cmdFromInput then
					if isPermissionLocked then
						local hasPermissionToUse = server.Core.checkCommandUsability(player, cmdFromInput, true)
						if not hasPermissionToUse then
							failedArgs[i] = if cmdFromInput.Hidden
								then string.format(
									"%s isn't a valid command. (e.g. " .. tostring(settings.actionPrefix) .. "cmds)",
									msgArg
								)
								else string.format(
									"You must have permission to select the command " .. cmdMatch,
									msgArg
								)
							continue
						end
					end

					filtered = true
					results[i] = {
						command = cmdFromInput,
						cmdMatch = cmdMatch,
						match = cmdMatch,
					}
				else
					failedArgs[i] = string.format(
						"%s isn't a valid command. (e.g. " .. tostring(settings.actionPrefix) .. "cmds)",
						msgArg
					)
				end
			elseif argType == "list" and msgArg then
				local list = {}

				local canFilter = arg.filter
				local requireSafeStr = canFilter and arg.requireSafeString

				local didPass = true

				for part in string.gmatch(msgArg, "[^,]+") do
					if canFilter then
						local safeString, filteredArg = server.Filter:safeString(part, player.UserId, player.UserId)

						if not safeString and requireSafeStr then
							didPass = false
							argType = "safestring"
						else
							table.insert(list, filteredArg)
						end
					else
						table.insert(list, part)
					end
				end

				if didPass then
					results[i] = list
					filtered = true
					continue
				end
			elseif argType == "players" then
				local minPlayers = tonumber(arg.minimum)
				local maxPlayers = tonumber(arg.maximum)

				local ignoreSelf = arg.ignoreSelf or false
				local noDuplicates = arg.noDuplicates
				local allowFPCreation = arg.allowFPCreation
				local ignoreIncognitoRestriction = arg.ignoreIncognitoRestriction
				local ignoreRestrictedSelections = arg.ignoreRestrictedSelections
				local ignoreHigherPriority = arg.ignoreHigherPriority

				if ignoreSelf == nil then ignoreSelf = false end

				if noDuplicates == nil then noDuplicates = true end

				local minAndMaxPass = false
				local list = parser:getPlayers(msgArg, player, {
					noDuplicates = noDuplicates,
					errorIfNone = false,
					ignoreCaller = ignoreSelf,
					allowFPCreation = allowFPCreation,
					ignoreIncognitoRestriction = ignoreIncognitoRestriction,
					ignoreRestrictedSelections = ignoreRestrictedSelections,
					ignoreHigherPriority = ignoreHigherPriority,
				}) or {}

				if ((minPlayers and not maxPlayers) and #list >= minPlayers) or
					((not minPlayers and maxPlayers) and #list <= maxPlayers) or
					((not minPlayers and maxPlayers) and #list <= maxPlayers) or
					((minPlayers and maxPlayers) and (#list >= minPlayers and #list <= maxPlayers)) or
					(not minPlayers and not maxPlayers)
				then
					minAndMaxPass = true
				end

				if minAndMaxPass then
					if #list > 0 then
						filtered = true
						results[i] = list
						continue
					else
						if msgArg then
							failedArgs[i] =
								string.format("Couldn't find <b>%s</b> as a player", parser:filterForRichText(msgArg))
						end
					end
				else
					if not arg.required then
						filtered = true
						results[i] = {}
						continue
					end

					failedArgs[i] =
						`Cannot target amount of players below the minimum amount {minPlayers} nor exceed the maximum amount {(maxPlayers or "[infinite]")}`
				end
			elseif argType == "playerName" and msgArg then
				local playerId = service.playerIdFromName(msgArg)
				if playerId > 0 then
					results[i] = msgArg
					filtered = true
				end
			elseif msgArg then
				-- String argument
				local stringResult = table.concat({
					table.unpack(
						msgArguments,
						processArgLen,
						(processArgLen == argsCount and #msgArguments) or processArgLen
					),
				}, delimiter)
				filtered = true

				-- If the argument has a string pattern
				if arg.stringPattern then
					local patterns = { string.match(stringResult, arg.stringPattern) }
					if #patterns == 0 and arg.required then
						filtered = false
						return false, i, `Argument {arg.argument or i} didn't match the specified string pattern`
					else
						filtered = true
						results[i] = patterns
					end

					continue
				end

				-- If the string
				if (arg.filter or arg.filterForPublic) and player then
					local safeString, filteredArg

					if not arg.filterForPublic then
						safeString, filteredArg = server.Filter:safeString(stringResult, player.UserId, player.UserId)
					else
						safeString, filteredArg = server.Filter:safeStringForPublic(stringResult, player.UserId)
					end

					if not safeString and (arg.requireSafeString or arg.safeString) then
						filtered = false
						argType = "safestring"
					else
						results[i] = filteredArg
						continue
					end
				else
					results[i] = stringResult
					continue
				end
			end

			if not filtered then
				local existingFailedArgSet = failedArgs[i]

				if existingFailedArgSet == nil then failedArgs[i] = true end

				if arg.required then
					return false, i, argType, (type(failedArgs[i]) == "string" and failedArgs[i]) or nil
				end
			end
		elseif not msgArg then
			if type(arg) == "table" then
				failedArgs[i] = true

				if arg.required then return false, i, arg.type or i end
			end
		end
	end

	local filterCount = 0

	for i, result in pairs(results) do
		if failedArgs[i] == nil then filterCount = filterCount + 1 end
	end

	if #msgArguments > argsCount then
		results[argsCount + 1] = table.concat({ table.unpack(msgArguments, argsCount + 1) }, delimiter)
	end

	return results, failedArgs, filteredMessageArguments
end

function parser:getDuration(number: number): {
	years: number,
	months: number,
	weeks: number,
	days: number,
	hours: number,
	mins: number,
	secs: number,
}
	local justSecs = tonumber(number) or 0

	justSecs = math.clamp(justSecs, 0, math.huge)

	local origSecs = justSecs
	local years = math.floor(justSecs / 31556952)
	justSecs = justSecs - (years * 31556952)

	local months = math.floor(justSecs / 2629746)
	justSecs = justSecs - (months * 2629746)

	local weeks = math.floor(justSecs / 604800)
	justSecs = justSecs - (weeks * 604800)

	local days = math.floor(justSecs / 86400)
	justSecs = justSecs - (days * 86400)

	local hours = math.floor(justSecs / 3600)
	justSecs = justSecs - (hours * 3600)

	local minutes = math.floor(justSecs / 60)
	justSecs = justSecs - (minutes * 60)

	return {
		years = years,
		months = months,
		weeks = weeks,
		days = days,
		hours = hours,
		mins = minutes,
		secs = justSecs,
	}
end

function parser:getTime(number: number): { hours: number, mins: number, secs: number }
	local remaining = number

	local hours = math.floor(remaining / 3600)
	remaining = remaining - (hours * 3600)

	local mins = math.floor(remaining / 60)
	remaining = remaining - (mins * 60)

	remaining = math.floor(remaining)
	if remaining < 0 then remaining = 0 end

	return {
		hours = hours,
		mins = mins,
		secs = remaining,
	}
end

function parser:formatTime(hours: number, mins: number?, secs: number?): boolean
	if hours and not (mins or secs) then
		local timeData = parser:getTime(hours)
		hours, mins, secs = timeData.hours, timeData.mins, timeData.secs
	end

	hours = hours % 24
	hours = (hours < 10 and "0" .. hours) or tostring(hours)
	mins = (mins < 10 and "0" .. mins) or tostring(mins)
	secs = (secs < 10 and "0" .. secs) or tostring(secs)

	return hours .. ":" .. mins .. ":" .. secs
end

function parser:trimString(str: string): string return string.match(string.match(str, "^%s*(.-)%s*$"), "^\9*(.-)\9*$") end

function parser:trimStringForTabSpaces(str: string): string return string.match(str, "^\9*(.-)\9*$") end

function parser:filterForRichText(text: string): string
	return parser:filterStringWithDictionary(text, {
		{ "&", "&amp;" },
		{ "<", "&lt;" },
		{ ">", "&gt;" },
		{ '"', "&quot;" },
		{ "'", "&apos;" },
	})
	
	--return parser:replaceStringWithDictionary(text, {
		--	["<"] 		= "&lt;";
		--	[">"] 		= "&gt;";
		--	["&"] 		= "&amp;";
		--	["\""]		= "&quot;";
		--	["'"]		= "&apos;";
		--})
	end
	
function parser:reverseFilterForRichText(richText: string): string
	return parser:filterStringWithDictionary(richText, {
		{ "&amp;", "&" },
		{ "&lt;", "<" },
		{ "&gt;", ">" },
		{ "&quot;", '"' },
		{ "&apos;", "'" },
	})
end

function parser:removeRichTextTags(str: string): string
	str = str:gsub("<br%s*/>", "\n")
	return (str:gsub("<[^<>]->", ""))
end

function parser:filterForStrPattern(text: string): string
	local strResults = {}
	local specialChars = { "(", ")", "%", ".", "+", "-", "*", "[", "]", "?", "^", "$" }

	if #text > 0 then
		for i = 1, utf8.len(text) or 0, 1 do
			local oneChar = text:sub(i, i)

			if table.find(specialChars, oneChar) then
				table.insert(strResults, "%" .. oneChar)
			else
				table.insert(strResults, oneChar)
			end
		end
	end

	return table.concat(strResults, "")
end

function parser.Init(env: { [any]: any }): boolean
	server = env.server
	service = env.service
	getEnv = env.getEnv
	cloneTable = service.cloneTable
	getRandom = service.getRandom

	endToEndEncryption = settings.endToEndEncryption or settings.remoteClientToServerEncryption

	luaParser = server.LuaParser
	base64 = server.Base64
	tulirAES = server.TulirAES
	hashLib = server.HashLib

	base64Encode = base64.encode
	base64Decode = base64.decode

	compression = server.Compression

	return true
end

return parser
