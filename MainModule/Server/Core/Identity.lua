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
	local Signal = server.Signal

	local cloneTable = service.cloneTable

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

	local checkSelectors = {
		{
			name = "GroupSelection",
			type = "string",
			match = {},

			runCheck = function(target, matchArgs) local matchType = type(matchArgs[1]) end,

			tableCheck = function(target, tab) end,
		},
	}

	server.Identity = {
		Init = Init,

		-- Cache tables
		playerGroupsCache = {},
		donorCache = {},
		friendsCache = {},
		mutualFriendsCache = {},
		displayNameCache = {},

		updateGroupCache = function()
			for i, cache in pairs(Identity.playerGroupsCache) do
				if type(cache) == "table" then
					service.trackTask("UPDATE GROUP " .. i .. " CACHE", true, function()
						local suc, ret = pcall(function() return service.GroupService:GetGroupsAsync(i) or {} end)

						cache.LastUpdated = os.time()

						if type(ret) == "table" then cache.Groups = ret end
					end)
				end
			end
		end,

		updateDonorCache = function()
			for userid, cache in pairs(Identity.donorCache) do
				if type(cache) == "table" then
					service.trackTask("UPDATE DONOR " .. userid .. " CACHE", true, function()
						local donor = false

						for i, val in pairs(variables.donorAssets) do
							if donor then -- If the user is a donor, cut the rope already !!
								break
							end

							if type(val) == "table" then
								if val.Type == "Gamepass" and tonumber(val.Id) then
									donor = service.checkPassOwnership(userid, tonumber(val.Id))
								elseif val.Type == "Asset" and tonumber(val.Id) then
									local plr = service.getPlayer(userid)

									if plr then donor = service.checkAssetOwnership(plr, tonumber(val.Id)) end
								end
							elseif type(val) == "number" then
								donor = service.checkPassOwnership(userid, tonumber(val.Id))
							end
						end

						cache.Donor = donor
						cache.LastUpdated = os.time()
					end)
				end
			end
		end,

		getDisplayName = function(uid, updateCache)
			uid = tonumber(uid) or nil

			if type(uid) == "number" then
				local existCache = Identity.displayNameCache[uid]

				local canUpdate = false

				if not updateCache then
					--> Feel free to adjust the time to update over or less than 300 seconds (5 minutes).
					--> 300 seconds is recommended in the event of unexpected server breakdowns with Roblox and faster performance.
					if not existCache or existCache and (os.time() - existCache.LastUpdated > 300) then
						canUpdate = true
					end
				else
					canUpdate = true
				end

				if canUpdate then
					local cacheTab = {
						DisplayName = (existCache and existCache.DisplayName) or nil,
						LastUpdated = os.time(),
					}
					Identity.displayNameCache[uid] = cacheTab

					local suc, result = pcall(
						function() return service.UserService:GetUserInfosByUserIdsAsync { uid } or {} end
					)

					if suc and type(result) == "table" and type(result[1]) == "table" then
						cacheTab.DisplayName = result[1].DisplayName
					end

					return cacheTab.DisplayName or service.playerNameFromId(cacheTab) "[unknown]"
				else
					return (existCache and existCache.DisplayName) or nil
				end
			end
		end,

		getFriends = function(uid, updateCache)
			uid = tonumber(uid) or nil

			if type(uid) == "number" then
				local existCache = Identity.friendsCache[uid]

				local canUpdate = false

				if not updateCache then
					--> Feel free to adjust the time to update over or less than 300 seconds (5 minutes).
					--> 300 seconds is recommended in the event of unexpected server breakdowns with Roblox and faster performance.
					if not existCache or existCache and (os.time() - existCache.LastUpdated > 300) then
						canUpdate = true
					end
				else
					canUpdate = true
				end

				if canUpdate then
					local cacheTab = {
						Friends = (existCache and existCache.Friends) or {},
						LastUpdated = os.time(),
					}
					Identity.friendsCache[uid] = cacheTab

					local suc, friendsPage = pcall(function() return service.Players:GetFriendsAsync(uid) or {} end)

					if suc and typeof(friendsPage) == "Instance" and friendsPage:IsA "FriendPages" then
						cacheTab.Friends = (function()
							local list = {}

							for friend, pageNum in service.iterPageItems(friendsPage) do
								table.insert(list, friend)
							end

							return list
						end)()

						return cloneTable(cacheTab.Friends)
					else
						return cloneTable(cacheTab.Friends)
					end
				else
					return cloneTable((existCache and existCache.Friends) or {})
				end
			end
		end,

		getGroups = function(uid, updateCache)
			uid = tonumber(uid) or nil

			if type(uid) == "number" then
				local existCache = Identity.playerGroupsCache[uid]
				local canUpdate = false

				if not updateCache then
					--> Feel free to adjust the time to update over or less than 300 seconds (5 minutes).
					--> 300 seconds is recommended in the event of unexpected server breakdowns with Roblox and faster performance.
					if not existCache or existCache and (os.time() - existCache.LastUpdated > 300) then
						canUpdate = true
					end
				else
					canUpdate = true
				end

				if canUpdate then
					local cacheTab = {
						Groups = (existCache and existCache.Groups) or {},
						LastUpdated = os.time(),
					}
					Identity.playerGroupsCache[uid] = cacheTab

					local suc, groups = pcall(function() return service.GroupService:GetGroupsAsync(uid) or {} end)

					if suc and type(groups) == "table" then
						cacheTab.Groups = groups
						return cacheTab.Groups
					end

					Identity.playerGroupsCache[uid] = cacheTab
					return cloneTable(cacheTab.Groups)
				else
					return cloneTable((existCache and existCache.Groups) or {})
				end
			end
		end,

		getGroupLevel = function(uid, groupId)
			groupId = tonumber(groupId)

			if groupId then
				local groups = Identity.getGroups(uid) or {}

				for i, group in pairs(groups) do
					if group.Id == groupId then return group.Rank end
				end
			end

			return 0
		end,

		checkInGroup = function(uid, groupId)
			local groups = Identity.getGroups(uid) or {}
			groupId = tonumber(groupId)

			if groupId then
				for i, group in pairs(groups) do
					if group.Id == groupId then return true end
				end
			end

			return false
		end,

		checkMatch = function(plr, check)
			-- Supported player checks: Instance, Parsed Player, string, number
			local plr = (type(plr) == "userdata" and Parser:isParsedPlayer(plr) and plr._object) or plr
			local checkType = type(check) or "unknown"
			local checkInPlayer = (typeof(plr) == "Instance" and plr:IsA "Player") or false

			local function doCheck(userId)
				if checkType == "string" then
					if check:lower():match "^@everyone$" or check:lower():match "^@all$" then
						return true
					elseif check:match "^Group:(.+)" then
						local match = check:match "^Group:(.+)"

						if tonumber(match) then
							return Identity.checkInGroup(userId, tonumber(match))
						else
							local groupId, ranks = match:match "^(%d+):(.+)"
							local playerRank = (tonumber(groupId) and Identity.getGroupLevel(userId, tonumber(groupId)))
								or 0

							if tonumber(groupId) then
								if tonumber(ranks:match"^(%d+)$") then
									local fixedRank = tonumber(ranks:match"^(%d+)$")
									if fixedRank == playerRank then
										return true
									end
								elseif ranks:sub(1, 2) == ">=" then
									local minimumRank = tonumber(match:sub(3))

									if minimumRank and playerRank >= minimumRank then return true end
								elseif ranks:sub(1, 2) == "<=" then
									local maximumRank = tonumber(match:sub(3))

									if maximumRank and playerRank <= maximumRank then return true end
								elseif ranks:sub(1, 2) == "==" then
									local specifiedRank = tonumber(match:sub(3))

									if specifiedRank and playerRank == specifiedRank then return true end
								elseif ranks:match "^(%d+)-(%d+)" then
									local minRank, maxRank = ranks:match "^(%d+)-(%d+)"
									minRank, maxRank = tonumber(minRank), tonumber(maxRank)

									if minRank and maxRank then
										if playerRank >= minRank and playerRank <= maxRank then return true end
									end
								end
							end
						end

						return false
					elseif check:match "^Subscription:(.+)" and checkInPlayer then
						local subscriptionId = check:match "^Subscription:(.+)"
						return select(1, service.checkActiveSubscription(plr, subscriptionId))
					elseif check:match "^Membership:(.+)" then
						local membership = check:match "^Membership:(.+)"

						if membership:lower() == "premium" and checkInPlayer then
							return plr.MembershipType == Enum.MembershipType.Premium
						elseif membership:lower() == "nonpremium" and checkInPlayer then
							return plr.MembershipType ~= Enum.MembershipType.Premium
						elseif membership:lower() == "donator" then
							return Identity.checkDonor(userId, (checkInPlayer and plr) or false)
						end
					elseif check:match "^Gamepass:(%d+)" then
						local match = tonumber(check:match "^Gamepass:(%d+)")

						if match then return service.checkPassOwnership(userId, match) end
					elseif check:match "^Badge:(%d+)" then
						local match = check:match "^Badge:(%d+)"

						if tonumber(match) then
							return service.BadgeService:UserHasBadgeAsync(userId, tonumber(match))
						end
					elseif check:match "^Asset:(%d+)" then
						local match = check:match "^Asset:(%d+)"

						if tonumber(match) then return service.Marketplace:PlayerOwnsAsset(plr, tonumber(match)) end
					elseif check:match "^FriendsWith:(%d+)" then
						local match = check:match "^FriendsWith:(%d+)"

						if tonumber(match) then return Identity.friendsWith(userId, tonumber(match)) end
					elseif check:match "^*PrivateServerOwner$" then
						if #game.PrivateServerId > 0 then return game.PrivateServerOwnerId == userId end
					elseif check:match "^*PrivateServerMember$" then
						if #game.PrivateServerId > 0 then return true end
					elseif check:match "^*PlaceOwner$" then
						if game.CreatorType == Enum.CreatorType.Group then
							local groupOwnerId = service.getGroupCreatorId(game.CreatorId)
							return groupOwnerId == userId
						else
							return game.CreatorId == userId
						end
					elseif check:match "^User:(%w+)$" or check:match "^Player:(%w+)$" then
						local match = check:match "^User:(%w+)$" or check:match "^Player:(%w+)$"
						local checkUserId = service.playerIdFromName(check) or 0

						if checkUserId > 0 and checkUserId == userId then return true end
					elseif check:match "^UserId:(d+)$" or check:match "^PlayerId:(d+)$" then
						local match = tonumber(check:match "^UserId:(%d+)$" or check:match "^PlayerId:(d+)$") or 0

						if match > 0 and match == userId then return true end
					else
						local checkUserId = service.playerIdFromName(check) or 0

						if checkUserId > 0 and checkUserId == userId then return true end
					end
				elseif checkType == "table" then
					local selectType = check.Type or checkType.type

					if selectType == "Group" and check.Id then
						local groupId = tonumber(check.Id)
						local groupRank = tonumber(check.Value)
						local playerRank = (groupId and Identity.getGroupLevel(userId, groupId)) or 0

						if groupRank then
							if check.Operator == ">=" then
								return playerRank >= groupRank
							elseif check.Operator == "<=" then
								return playerRank <= groupRank
							elseif check.Operator == ">" then
								return playerRank > groupRank
							elseif check.Operator == "<" then
								return playerRank < groupRank
							elseif check.Operator == "==" then
								return playerRank == groupRank
							end
						else
							if check.Operator == "-" then
								local minRank, maxRank = tonumber(check.MinValue), tonumber(check.MaxValue)

								if (minRank and maxRank) and (minRank <= playerRank and maxRank >= playerRank) then
									return true
								end
							elseif not check.Operator then
								return playerRank > 0
							end
						end
					end

					if selectType == "Membership" and plr then
						local list = check.List or {}
						local hasPremium = (checkInPlayer and plr.MembershipType == Enum.MembershipType.Premium)
							or false

						for i, v in pairs(list) do
							if type(v) == "string" then
								if v:lower() == "premium" and checkInPlayer and hasPremium then
									return hasPremium
								elseif v:lower() == "nonpremium" and checkInPlayer and not hasPremium then
									return not hasPremium
								elseif
									(v:lower() == "donator" or v:lower() == "donor")
									and Identity.checkDonor(userId, plr)
								then
									return true
								end
							end
						end
					end

					if selectType == "Subscription" then
						local list = check.List or {}

						for i, v in pairs(list) do
							local id = string.match "^(.+)$"

							if id then
								local checkOwned = service.checkActiveSubscription(plr, id)

								if checkOwned then return checkOwned end
							end
						end
					end

					if selectType == "Gamepass" then
						local list = check.List or {}

						for i, v in pairs(list) do
							local id = tonumber(v)

							if id then
								local checkOwned = service.checkPassOwnership(userId, id)

								if checkOwned then return checkOwned end
							end
						end
					end

					if selectType == "Badge" then
						local list = check.List or {}

						for i, v in pairs(list) do
							local id = tonumber(v)

							if id then
								local checkOwned = service.BadgeService:UserHasBadgeAsync(userId, id)

								if checkOwned then return checkOwned end
							end
						end
					end

					if selectType == "Asset" and checkInPlayer then
						local list = check.List or {}

						for i, v in pairs(list) do
							local id = tonumber(v)

							if id then
								local checkOwned = service.Marketplace:PlayerOwnsAsset(plr, id)

								if checkOwned then return checkOwned end
							end
						end
					end

					if selectType == "FriendsWith" then
						local list = check.List or {}

						for i, v in pairs(list) do
							local id = tonumber(v)

							if id then
								local checkFriends = Identity.friendsWith(userId, id)

								if checkFriends then return checkFriends end
							end
						end
					end

					if selectType == "Users" or selectType == "Players" then
						local list = check.List or {}

						for i, userName in pairs(list) do
							if type(userName) == "string" then
								local checkUserId = service.playerIdFromName(userName) or 0

								if checkUserId > 0 and checkUserId == userId then return true end
							elseif type(userName) == "number" then
								if userName > 0 and userName == userId then return true end
							end
						end
					end

					if selectType == "Player" then
						local checkUserId = check.PlayerUserId or check.UserId or 0

						if checkUserId == userId then return true end
					end
				elseif checkType == "userdata" and checkInPlayer then
					return (getmetatable(check) == "EP-" .. tostring(plr.UserId) and check.UserId == plr.UserId) or plr
				elseif checkType == "number" and userId == check then
					return true
				elseif checkType == "function" then
					return check(userId, (checkInPlayer and plr) or nil)
				end

				return false
			end

			if checkInPlayer then
				return doCheck(plr.UserId)
			elseif type(plr) == "number" then
				return doCheck(plr)
			elseif type(plr) == "string" then
				local userId = service.playerIdFromName(plr)

				if userId > 0 then return doCheck(userId) end
			end
		end,

		checkTable = function(check, table)
			table = (type(table) == "table" and table) or {}

			for i, v in pairs(table) do
				if Identity.checkMatch(check, v) then return true end
			end

			return false
		end,

		--checkMutualship = function(userId, strangerUserId)
		--	local friends = Identity.getFriends(userId) or {}

		--	for i, friend in pairs(friends) do
		--		if type(friend)=="table" then
		--			if Identity.checkFriendship(friend.Id, strangerUserId) then
		--				return true, friend.Id
		--			end
		--		end
		--	end

		--	return false
		--end;

		--getMutuals = function(userId)
		--	local friends = Identity.getFriends(userId) or {}
		--	local results = {}
		--	local checkList = {}

		--	local existingCache = Identity.mutualFriendsCache[userId]
		--	local canUpdateCache = not existingCache or existingCache.lastUpdated > 600

		--	if not canUpdateCache then
		--		return cloneTable(existingCache and existingCache.list or {})
		--	else
		--		local mFriendsCache = {
		--			list = (existingCache and existingCache.list) or {};
		--			lastUpdated = os.time();
		--		}

		--		Identity.mutualFriendsCache[userId] = mFriendsCache

		--		local listOfSignals = {}

		--		for i, friend in pairs(friends) do
		--			if type(friend)=="table" then
		--				local waitSignal = Signal.new()
		--				table.insert(listOfSignals, waitSignal)

		--				task.defer(function()
		--					local friendFriends = Identity.getFriends(friend.Id) or {}
		--					local ignoreIds = {userId, friend.Id}
		--					for d, mutualFriend in pairs(friendFriends) do
		--						if type(mutualFriend) == "table" and not table.find(ignoreIds, mutualFriend.Id) then
		--							if not checkList[mutualFriend.Id] then
		--								checkList[mutualFriend.Id] = mutualFriend
		--								mutualFriend.mutualsFrom = {friend.Id}
		--								table.insert(results, mutualFriend)
		--							else
		--								local existMutualInfo = checkList[mutualFriend.Id]
		--								if not table.find(existMutualInfo.mutualsFrom, friend.Id) then
		--									table.insert(existMutualInfo.mutualsFrom, friend.Id)
		--								end
		--							end
		--						end
		--					end

		--					waitSignal:fire(true)
		--				end)
		--			end
		--		end

		--		Signal:waitOnMultipleEvents(listOfSignals)
		--		mFriendsCache.list = results

		--		return cloneTable(results)
		--	end
		--end;

		--getMutualsByIds = function(userId)
		--	local results = {}

		--	for i, friendInfo in ipairs(Identity.getMutuals(userId)) do
		--		table.insert(results, friendInfo.Id)
		--	end

		--	return results
		--end;

		--getMutualsByIdsAndFriends = function(userId, indexFriendId)
		--	local results = {}

		--	for i, friendInfo in ipairs(Identity.getMutuals(userId)) do
		--		if indexFriendId then
		--			results[friendInfo.Id] = friendInfo.mutualsFrom
		--		else
		--			table.insert(results, {
		--				mutualId = friendInfo.Id,
		--				mutualsFrom = friendInfo.mutualsFrom
		--			})
		--		end
		--	end

		--	return results
		--end,

		checkFriendship = function(userId, friendUserId)
			local friends = Identity.getFriends(userId) or {}

			-- FRIEND TABLE INFORMATION
			--
			--		Id				-		Friend's userId 			(number)
			--		Username		-		Friend's name/username 		(string)
			--		DisplayName 	-		Friend's display name 		(string)
			--		IsOnline		-		Friend's online status 		(boolean)

			for i, friend in pairs(friends) do
				if type(friend) == "table" and friend.Id == friendUserId then return true end
			end

			return false
		end,

		friendsWith = function(...) return Identity.checkFriendship(...) end,

		checkDonor = function(userId, plr)
			if type(userId) == "number" then
				local existingCache = Identity.donorCache[userId]

				if existingCache and existingCache.donor then
					return true
				elseif (existingCache and (os.time() - existingCache.lastUpdated > 300)) or not existingCache then
					local donor

					for i, val in pairs(variables.donorAssets) do
						if donor then -- If the user is a donor, cut the rope already !!
							break
						end

						if type(val) == "table" then
							if val.Type == "Gamepass" and tonumber(val.Id) then
								donor = service.checkPassOwnership(userId, tonumber(val.Id))
							elseif val.Type == "Asset" and tonumber(val.Id) and plr then
								donor = service.checkAssetOwnership(plr, tonumber(val.Id))
							end
						elseif type(val) == "number" then
							donor = service.checkPassOwnership(userId, tonumber(val.Id))
						end
					end

					local donorCache = {
						donor = donor,
						lastUpdated = os.time(),
					}

					Identity.donorCache[userId] = donorCache

					if donor then return true end
				elseif existingCache then
					return existingCache.donor
				end
			end

			return false
		end,

		checkPlaceOwner = function(checker)
			if Parser:isParsedPlayer(checker) or (typeof(checker) == "Instance" and checker:IsA "Player") then
				return (game.CreatorType == Enum.CreatorType.User and game.CreatorId == checker.UserId)
					or (game.CreatorType == Enum.CreatorType.Group and Identity.getGroupLevel(
						checker.UserId,
						game.CreatorId
					) == 255)
					or false
			elseif type(checker) == "number" then
				return (game.CreatorType == Enum.CreatorType.User and game.CreatorId == checker)
					or (game.CreatorType == Enum.CreatorType.Group and Identity.getGroupLevel(checker, game.CreatorId) == 255)
					or false
			else
				return false
			end
		end,
	}
end
