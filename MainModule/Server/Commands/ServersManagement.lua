return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service
	local settings = server.Settings
	local variables = envArgs.variables
	local getEnv = envArgs.getEnv
	local script = envArgs.script

	local Cmds = server.Commands
	local Core = server.Core
	local Cross = server.Cross
	local Datastore = server.Datastore
	local Identity = server.Identity
	local Logs = server.Logs
	local Moderation = server.Moderation
	local Process = server.Process
	local Remote = server.Remote
	local Utility = server.Utility

	local Parser = server.Parser
	local Signal = server.Signal

	local defaultPerm = "Manage_Server"
	local reserveHostRole = "esserverHost"

	local cmdsList = {
		reserveServer = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "reserveserver" },
			Arguments = {
				{
					argument = "name",
					required = true,
					filter = true,
					requireSafeString = true,
				},
			},
			Permissions = { defaultPerm },
			Roles = {},

			Description = "Reserves a server",
			PlayerCooldown = 2,
			ServerDebounce = true,
			ServerCooldown = 10,

			Function = function(plr, args)
				local maximumCreation = variables.serverCreationSettings.maxCreation
				local reserveListName = variables.serverCreationSettings.reserveListName

				if not (#args[1] >= 3 and #args[1] <= 20) then
					plr:sendData("SendMessage", "Server name must be within 3-20 characters.", nil, 4, "Context")
					return
				elseif args[1]:find "%s" then
					plr:sendData("SendMessage", "Server name must <u>not contain spaces</u>.", nil, 4, "Context")
					return
				end

				if server.Studio then
					plr:sendData("SendMessage", "You cannot reserve a server while on studio.", nil, 6, "Context")
					return
				end

				plr:sendData(
					"SendMessage",
					"Reserving server <b>" .. Parser:filterForRichText(args[1]) .. "</b>..",
					"Reserving server " .. args[1] .. "..",
					12,
					"Context"
				)

				local serversList = Datastore.read(nil, reserveListName, true)
				if type(serversList) ~= "table" then
					serversList = {}

					if serversList ~= nil then
						local checkConfirm = plr:makeUIGet("Confirmation", {
							title = "Confirmation",
							desc = "Reserved servers list didn't return a table and possibly contain reserved servers. By agreeing, you are to reset the list.",
							choiceA = "Yes, I confirm.",
							returnOutput = true,
							time = 10,
						})

						if checkConfirm ~= 1 then
							plr:sendData("SendMessage", "Reset server list modal canceled.", nil, 4, "Context")
							return
						end
					end

					Datastore.overWrite(nil, reserveListName, {})
				end

				if serversList[args[1]] then
					plr:sendData(
						"SendMessage",
						"Server <b>" .. Parser:filterForRichText(args[1]) .. "</b> is <u>already reserved</u>.",
						"Server " .. args[1] .. " is already reserved.",
						10,
						"Context"
					)
					return
				end

				if service.tableCount(serversList) > maximumCreation then
					plr:sendData(
						"SendMessage",
						"Unable to reserve server due to maximum amount of reserved servers.",
						nil,
						10,
						"Context"
					)
				else
					plr:sendData(
						"SendMessage",
						"Creating reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>..",
						"Creating reserved server " .. args[1] .. "..",
						12,
						"Context"
					)

					Utility:createReserveServer(args[1], plr.UserId)

					plr:sendData(
						"SendMessage",
						"Successfully reserved server " .. Parser:filterForRichText(args[1]),
						"Successfully reserved server " .. args[1],
						5,
						"Context"
					)
				end
			end,
		},

		joinReserveServer = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "joinreserve", "joinprivateserver", "toserver" },
			Arguments = {
				{
					argument = "name",
					required = true,
					filter = true,
					requireSafeString = true,
				},
			},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Joins a reserved server",
			PlayerCooldown = 4,

			Function = function(plr, args)
				local reserveListName = variables.serverCreationSettings.reserveListName

				if not (#args[1] >= 3 and #args[1] <= 20) then
					plr:sendData("SendMessage", "Server name must be within 3-20 characters.", nil, 10, "Context")
					return
				end

				if server.Studio then
					plr:sendData("SendMessage", "You cannot join a reserved server while on studio.", nil, 6, "Context")
					return
				end

				plr:sendData(
					"SendMessage",
					"Joining reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>..",
					"Joining reserved server " .. args[1] .. "..",
					12,
					"Context"
				)
				local serverProfile = Utility:getReserveServer(nil, args[1])

				if not serverProfile then
					plr:sendData(
						"SendMessage",
						"Server <b>" .. Parser:filterForRichText(args[1]) .. "</b> is <u>not reserved</u>.",
						"Server " .. args[1] .. " is not reserved.",
						10,
						"Context"
					)
					return
				end

				plr:teleportToReserveWithSignature(
					serverProfile.details.serverAccessId,
					function()
						plr:sendData(
							"SendMessage",
							"Failed to join the reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>",
							nil,
							4,
							"Context"
						)
					end
				)
			end,
		},

		forceTeleportReserveServer = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "ftpserver", "forcejoinreserve" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "name",
					required = true,
					filter = true,
					requireSafeString = true,
				},
			},
			Permissions = { defaultPerm },
			Roles = {},

			Description = "Forces specified players to join a specified reserved server.",
			PlayerCooldown = 2,

			Function = function(plr, args)
				local serverName = args[2]
				local reserveListName = variables.serverCreationSettings.reserveListName

				if not (#serverName >= 3 and #serverName <= 20) then
					plr:sendData("SendMessage", "Server name must be within 3-20 characters.", nil, 10, "Context")
					return
				end

				if server.Studio then
					plr:sendData("SendMessage", "You cannot join a reserved server while on studio.", nil, 6, "Context")
					return
				end

				plr:sendData(
					"SendMessage",
					"Finding reserved server <b>" .. Parser:filterForRichText(serverName) .. "</b>..",
					"Finding reserved server " .. serverName .. "..",
					12,
					"Context"
				)
				local serverProfile = Utility:getReserveServer(nil, serverName)
				if not serverProfile then
					plr:sendData(
						"SendMessage",
						"Server <b>" .. Parser:filterForRichText(serverName) .. "</b> is <u>not reserved</u>.",
						"Server " .. serverName .. " is not reserved.",
						10,
						"Context"
					)
					return
				end

				plr:sendData(
					"SendMessage",
					"Found reserved server <b>"
						.. Parser:filterForRichText(serverName)
						.. "</b>. Now teleporting them..",
					nil,
					12,
					"Context"
				)

				for i, target in pairs(args[1]) do
					task.defer(function()
						target:sendData(
							"SendMessage",
							"You are now teleporting to reserved server <b>"
								.. Parser:filterForRichText(serverName)
								.. "</b>.",
							"You are now teleporting to reserved server " .. serverName .. ".",
							10,
							"Context"
						)

						target:teleportToReserveWithSignature(serverProfile.details.serverAccessId, function(errType)
							if errType == "teleporting" then
								plr:sendData(
									"SendMessage",
									"Uh, oh! <b>"
										.. target.Name
										.. "</b> cannot teleport to reserved server <i>"
										.. Parser:filterForRichText(serverName)
										.. "</i> if they are already teleporting.",
									"Uh, oh! "
										.. target.Name
										.. " failed to teleport to reserved server "
										.. serverName
										.. " if they are already teleporting.",
									10,
									"Context"
								)
							elseif errType == "error" then
								plr:sendData(
									"SendMessage",
									"Uh, oh! <b>"
										.. target.Name
										.. "</b> failed to teleport to reserved server <i>"
										.. Parser:filterForRichText(serverName)
										.. "</i>.",
									"Uh, oh! "
										.. target.Name
										.. " failed to teleport to reserved server "
										.. serverName
										.. ".",
									10,
									"Context"
								)

								target:sendData(
									"SendMessage",
									"Uh, oh! You failed to teleport to reserved server <i>"
										.. Parser:filterForRichText(serverName)
										.. "</i>.",
									"Uh, oh! You failed to teleport to reserved server " .. serverName .. ".",
									10,
									"Context"
								)
							end
						end)
					end)
				end
			end,
		},

		deleteReserveServer = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "delprivateserver" },
			Arguments = {
				{
					argument = "name",
					required = true,
					filter = true,
					requireSafeString = true,
				},
			},
			Permissions = { defaultPerm },
			Roles = {},

			Description = "Deletes a reserved server",
			PlayerCooldown = 8,

			Function = function(plr, args)
				local reserveListName = variables.serverCreationSettings.reserveListName

				if not (#args[1] >= 3 and #args[1] <= 20) then
					plr:sendData("SendMessage", "Server name must be within 3-20 characters.", nil, 10, "Context")
					return
				end

				plr:sendData(
					"SendMessage",
					"Finding reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>..",
					"Finding reserved server " .. args[1] .. "..",
					12,
					"Context"
				)
				local serversList = Datastore.read(nil, reserveListName)
				if type(serversList) ~= "table" then serversList = {} end

				if not serversList[args[1]] then
					plr:sendData(
						"SendMessage",
						"Reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b> doesn't exist",
						"Reserved server " .. args[1] .. " doesn't exist",
						6,
						"Context"
					)
				else
					local privateServerProfile = Utility:getReserveServer(nil, args[1]) or {}
					local isAdmin = Moderation.checkAdmin(plr)
					local canDeleteServer = privateServerProfile.creatorId == plr.UserId or isAdmin

					if not canDeleteServer then
						plr:sendData(
							"SendMessage",
							"You must own reserved server <b>"
								.. Parser:filterForRichText(args[1])
								.. "</b> or server administrator to delete it.",
							nil,
							6,
							"Context"
						)
						return
					end

					local didRemoveRegistry = Utility:deleteReserveServer(nil, args[1])

					if didRemoveRegistry then
						plr:sendData(
							"SendMessage",
							"Successfully deleted reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>",
							"Successfully deleted reserved server " .. args[1],
							6,
							"Context"
						)
					else
						plr:sendData(
							"SendMessage",
							"Failed to delete reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>",
							"Failed to delete reserved server " .. args[1],
							6,
							"Context"
						)
					end
				end
			end,
		},

		closeReserveServer = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "closeprivateserver", "closereserve" },
			Arguments = {
				{
					argument = "name",
					required = true,
					filter = true,
					requireSafeString = true,
				},
			},
			Permissions = { defaultPerm },
			Roles = {},

			Description = "Deletes a reserved server",
			PlayerCooldown = 8,

			Function = function(plr, args)
				local reserveListName = variables.serverCreationSettings.reserveListName

				if not (#args[1] >= 3 and #args[1] <= 20) then
					plr:sendData("SendMessage", "Server name must be within 3-20 characters.", nil, 10, "Context")
					return
				end

				plr:sendData(
					"SendMessage",
					"Finding reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>..",
					"Finding reserved server " .. args[1] .. "..",
					12,
					"Context"
				)
				local serversList = Datastore.read(nil, reserveListName)
				if type(serversList) ~= "table" then serversList = {} end

				if not serversList[args[1]] then
					plr:sendData(
						"SendMessage",
						"Reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b> doesn't exist",
						"Reserved server " .. args[1] .. " doesn't exist",
						6,
						"Context"
					)
				else
					local privateServerProfile = Utility:getReserveServer(nil, args[1]) or {}
					local isAdmin = Moderation.checkAdmin(plr)
					local canDeleteServer = privateServerProfile.creatorId == plr.UserId or isAdmin

					if not canDeleteServer then
						plr:sendData(
							"SendMessage",
							"You must own reserved server <b>"
								.. Parser:filterForRichText(args[1])
								.. "</b> or server administrator to delete it.",
							nil,
							6,
							"Context"
						)
						return
					end

					local didRemoveRegistry = Utility:deleteReserveServer(nil, args[1])

					if didRemoveRegistry then
						plr:sendData(
							"SendMessage",
							"Successfully deleted reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>",
							"Successfully deleted reserved server " .. args[1],
							6,
							"Context"
						)
					else
						plr:sendData(
							"SendMessage",
							"Failed to delete reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>",
							"Failed to delete reserved server " .. args[1],
							6,
							"Context"
						)
					end
				end
			end,
		},

		listReservedServers = {
			Prefix = settings.actionPrefix,
			Aliases = { "listreserves", "privateservers" },
			Arguments = {},
			Permissions = { defaultPerm },
			Roles = {},

			Description = "Lists reserved servers",
			PlayerCooldown = 2,
			ServerDebounce = true,
			ServerCooldown = 4,

			Function = function(plr, args)
				local reserveListName = variables.serverCreationSettings.reserveListName

				plr:sendData("SendMessage", "Retrieving list of reserved servers..", nil, 10, "Context")

				local serversList = Datastore.read(nil, reserveListName) or {}
				if type(serversList) ~= "table" then serversList = {} end

				local privateServerData = variables.privateServerData
				local hasPermissionToViewAll = server.Roles:hasPermissionFromMember(plr, { "Manage_Server" })

				local tabList = {}

				for serverName, detail in pairs(serversList) do
					local formatTime = Parser:osDate(detail.created)
					local ownerName = detail.creatorId == 0 and "-SYSTEM-"
						or "@" .. service.playerNameFromId(detail.creatorId)

					table.insert(tabList, {
						type = "Detailed",
						Text = "[Owned by " .. ownerName .. "] " .. serverName,
						Desc = "Created on " .. formatTime .. " UTC",
						Color = privateServerData
								and privateServerData.details.serverId == detail.serverId
								and Color3.fromRGB(121, 200, 30)
							or nil,
					})
				end

				plr:makeUI("List", {
					Title = `E. Reserved Servers {(not hasPermissionToViewAll and "(Membership and Public Joins only)" or "")}`,
					List = tabList,
				})
			end,
		},

		-- RESERVED SERVER COMMANDS

		manageReserveMaxPlayers = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "reserve-maxplayers" },
			Arguments = {
				{
					argument = "servername",
					required = true,
					filter = true,
					requireSafeString = true,
				},
				{
					argument = "count",
					type = "integer",
					min = 1,
					max = math.huge,
					required = true,
				},
			},
			Permissions = {},
			Roles = { reserveHostRole },
			--Whitelist = {
			--	function(userId)
			--		local privateServerData = variables.privateServerData
			--		if privateServerData and privateServerData.creatorId == userId then
			--			return true
			--		end
			--	end,
			--};

			Description = "Manages the maximum players of the reserved server",
			PlayerCooldown = 4,

			Function = function(plr, args)
				if not (#args[1] >= 3 and #args[1] <= 20) then
					plr:sendData("SendMessage", "Server name must be within 3-20 characters.", nil, 10, "Context")
					return
				end

				plr:sendData(
					"SendMessage",
					"Finding reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>..",
					"Finding reserved server " .. args[1] .. "..",
					12,
					"Context"
				)

				local serverName = args[1]
				local serverProfile = Utility:getReserveServer(nil, serverName)
				if not serverProfile then
					plr:sendData(
						"SendMessage",
						"Server <b>" .. Parser:filterForRichText(serverName) .. "</b> is <u>not reserved</u>.",
						"Server " .. serverName .. " is not reserved.",
						10,
						"Context"
					)
					return
				end

				local prevMaxPlayers = serverProfile.maxPlayers
				if prevMaxPlayers ~= args[1] then
					serverProfile.maxPlayers = args[1]
					if
						variables.privateServerData
						and variables.privateServerData.details.serverId == serverProfile.details.serverId
					then
						variables.privateServerData.maxPlayers = args[1]
					end

					Datastore.tableUpdate("PrivateServerProfile", game.PrivateServerId, "Index", "maxPlayers", args[1])
				end

				plr:sendData(
					"SendMessage",
					"Successfully set max number of players for reserved server to <b>"
						.. args[1]
						.. "</b>. This may take a few minutes to apply the changes.",
					nil,
					10,
					"Context"
				)
			end,
		},

		--manageReserveInviteOnly = {
		--	Prefix = settings.actionPrefix;
		--	Silent = true;
		--	Aliases = {"reserve-inviteonly"};
		--	Arguments = {
		--		{
		--			argument = "trueOrFalse";
		--			type = "trueOrFalse";
		--			required = true;
		--		}
		--	};
		--	Permissions = {defaultPerm};
		--	Roles = {};
		--	--Whitelist = {
		--	--	function(userId)
		--	--		local privateServerData = variables.privateServerData
		--	--		if privateServerData and privateServerData.creatorId == userId then
		--	--			return true
		--	--		end
		--	--	end,
		--	--};

		--	Description = "Manages a reserved server";
		--	PlayerCooldown = 4;

		--	Function = function(plr, args)
		--		local privateServerData = variables.privateServerData
		--		if not privateServerData then
		--			plr:sendData("SendMessage", "You cannot use this command in a non-Essential reserved server", nil, 10, "Context")
		--			return
		--		end

		--		local prevInviteOnly = privateServerData.inviteOnly
		--		if prevInviteOnly ~= args[1] then
		--			privateServerData.inviteOnly = args[1]
		--			Datastore.tableUpdate("PrivateServerProfile", game.PrivateServerId, "Index", "inviteOnly", args[1])
		--		end

		--		plr:sendData("SendMessage", "Successfully set invite only to <b>"..tostring(args[1]).."</b>", nil, 10, "Context")
		--	end;
		--};

		addWhitelistToTheReserve = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "reserve-addwhitelist" },
			Arguments = {
				{
					argument = "servername",
					required = true,
					filter = true,
					requireSafeString = true,
				},
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { defaultPerm },
			Roles = {},

			Description = "Adds whitelist players to the reserve server",
			PlayerCooldown = 6,

			Function = function(plr, args)
				if not (#args[1] >= 3 and #args[1] <= 20) then
					plr:sendData("SendMessage", "Server name must be within 3-20 characters.", nil, 10, "Context")
					return
				end

				plr:sendData(
					"SendMessage",
					"Finding reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>..",
					"Finding reserved server " .. args[1] .. "..",
					12,
					"Context"
				)

				local serverName = args[1]
				local serverProfile = Utility:getReserveServer(nil, serverName)
				if not serverProfile then
					plr:sendData(
						"SendMessage",
						"Server <b>" .. Parser:filterForRichText(serverName) .. "</b> is <u>not reserved</u>.",
						"Server " .. serverName .. " is not reserved.",
						10,
						"Context"
					)
					return
				end

				plr:sendData(
					"SendMessage",
					`Whitelisting <b>{#args[2]} player(s)</b> to the reserved server..`,
					nil,
					12,
					"Context"
				)

				local whitelist, blacklist = serverProfile.whitelist, serverProfile.banlist
				local successPlayers, failedPlayers = {}, {}

				for i, target in pairs(args[2]) do
					local blacklisted = Identity.checkTable(target, blacklist)
					local whitelisted = not blacklisted and Identity.checkTable(target, whitelist)

					if blacklisted or whitelisted or target.UserId == serverProfile.creatorId then
						table.insert(failedPlayers, target.UserId)
					else
						if Utility:addWhitelistUserToReserveServer(serverName, target.UserId) then
							table.insert(successPlayers, target.UserId)
						else
							table.insert(failedPlayers, target.UserId)
						end
					end
				end

				if #failedPlayers > 0 then
					plr:sendData(
						"SendMessage",
						`Failed to whitelist <b>{#failedPlayers} player(s)</b> in reserved server {serverName}`,
						nil,
						10,
						"Context"
					)
					wait(2)
				end

				if #successPlayers > 0 then
					plr:sendData(
						"SendMessage",
						`Successfully whitelisted <b>{#successPlayers} player(s)</b> in reserved server {serverName}.  This may take a few minutes to apply the changes.`,
						nil,
						10,
						"Context"
					)
				end
			end,
		},

		remWhitelistToTheReserve = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "reserve-remwhitelist" },
			Arguments = {
				{
					argument = "servername",
					required = true,
					filter = true,
					requireSafeString = true,
				},
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { defaultPerm },
			Roles = {},

			Description = "Removes whitelisted players from the reserve server",
			PlayerCooldown = 6,

			Function = function(plr, args)
				if not (#args[1] >= 3 and #args[1] <= 20) then
					plr:sendData("SendMessage", "Server name must be within 3-20 characters.", nil, 10, "Context")
					return
				end

				plr:sendData(
					"SendMessage",
					"Finding reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>..",
					"Finding reserved server " .. args[1] .. "..",
					12,
					"Context"
				)

				local serverName = args[1]
				local serverProfile = Utility:getReserveServer(nil, serverName)
				if not serverProfile then
					plr:sendData(
						"SendMessage",
						"Server <b>" .. Parser:filterForRichText(serverName) .. "</b> is <u>not reserved</u>.",
						"Server " .. serverName .. " is not reserved.",
						10,
						"Context"
					)
					return
				end

				plr:sendData(
					"SendMessage",
					`Unwhitelisting from <b>{#args[2]} player(s)</b> in the reserved server..`,
					nil,
					12,
					"Context"
				)

				local whitelist, blacklist = serverProfile.whitelist, serverProfile.banlist
				local successPlayers, failedPlayers = {}, {}

				for i, target in pairs(args[2]) do
					local blacklisted = Identity.checkTable(target, blacklist)
					local whitelisted = not blacklisted and Identity.checkTable(target, whitelist)

					if blacklisted then
						table.insert(failedPlayers, target.UserId)
					else
						if Utility:removeWhitelistUserFromReserveServer(serverName, target.UserId) then
							table.insert(successPlayers, target.UserId)
						else
							table.insert(failedPlayers, target.UserId)
						end
					end
				end

				if #failedPlayers > 0 then
					plr:sendData(
						"SendMessage",
						`Failed to unwhitelist <b>{#failedPlayers} player(s)</b> in reserved server {serverName}`,
						nil,
						10,
						"Context"
					)
					wait(2)
				end

				if #successPlayers > 0 then
					plr:sendData(
						"SendMessage",
						`Successfully unwhitelisted <b>{#successPlayers} player(s)</b> in reserved server {serverName}.  This may take a few minutes to apply the changes.`,
						nil,
						10,
						"Context"
					)
				end
			end,
		},

		addBlacklistToTheReserve = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "reserve-blacklist" },
			Arguments = {
				{
					argument = "servername",
					required = true,
					filter = true,
					requireSafeString = true,
				},
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { defaultPerm },
			Roles = {},

			Description = "Adds blacklisted players to the reserve server",
			PlayerCooldown = 6,

			Function = function(plr, args)
				if not (#args[1] >= 3 and #args[1] <= 20) then
					plr:sendData("SendMessage", "Server name must be within 3-20 characters.", nil, 10, "Context")
					return
				end

				plr:sendData(
					"SendMessage",
					"Finding reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>..",
					"Finding reserved server " .. args[1] .. "..",
					12,
					"Context"
				)

				local serverName = args[1]
				local serverProfile = Utility:getReserveServer(nil, serverName)
				if not serverProfile then
					plr:sendData(
						"SendMessage",
						"Server <b>" .. Parser:filterForRichText(serverName) .. "</b> is <u>not reserved</u>.",
						"Server " .. serverName .. " is not reserved.",
						10,
						"Context"
					)
					return
				end

				plr:sendData(
					"SendMessage",
					`Blacklisting <b>{#args[2]} player(s)</b> in the reserved server..`,
					nil,
					12,
					"Context"
				)

				local whitelist, blacklist = serverProfile.whitelist, serverProfile.banlist
				local successPlayers, failedPlayers = {}, {}

				for i, target in pairs(args[2]) do
					local blacklisted = Identity.checkTable(target, blacklist)
					local whitelisted = not blacklisted and Identity.checkTable(target, whitelist)

					if blacklisted or whitelisted or target.UserId == serverProfile.creatorId then
						table.insert(failedPlayers, target.UserId)
					else
						if Utility:addBlacklistUserToReserveServer(serverName, target.UserId) then
							table.insert(successPlayers, target.UserId)
						else
							table.insert(failedPlayers, target.UserId)
						end
					end
				end

				if #failedPlayers > 0 then
					plr:sendData(
						"SendMessage",
						`Failed to blacklist <b>{#failedPlayers} player(s)</b> in reserved server {serverName}`,
						nil,
						10,
						"Context"
					)
					wait(2)
				end

				if #successPlayers > 0 then
					plr:sendData(
						"SendMessage",
						`Successfully blacklisted <b>{#successPlayers} player(s)</b> in reserved server {serverName}.  This may take a few minutes to apply the changes.`,
						nil,
						10,
						"Context"
					)
				end
			end,
		},

		remBlacklistToTheReserve = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "reserve-remblacklist" },
			Arguments = {
				{
					argument = "servername",
					required = true,
					filter = true,
					requireSafeString = true,
				},
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { defaultPerm },
			Roles = {},

			Description = "Removes blacklisted players from the reserve server",
			PlayerCooldown = 6,

			Function = function(plr, args)
				if not (#args[1] >= 3 and #args[1] <= 20) then
					plr:sendData("SendMessage", "Server name must be within 3-20 characters.", nil, 10, "Context")
					return
				end

				plr:sendData(
					"SendMessage",
					"Finding reserved server <b>" .. Parser:filterForRichText(args[1]) .. "</b>..",
					"Finding reserved server " .. args[1] .. "..",
					12,
					"Context"
				)

				local serverName = args[1]
				local serverProfile = Utility:getReserveServer(nil, serverName)
				if not serverProfile then
					plr:sendData(
						"SendMessage",
						"Server <b>" .. Parser:filterForRichText(serverName) .. "</b> is <u>not reserved</u>.",
						"Server " .. serverName .. " is not reserved.",
						10,
						"Context"
					)
					return
				end

				plr:sendData(
					"SendMessage",
					`Unblacklisting from <b>{#args[2]} player(s)</b> in the reserved server..`,
					nil,
					12,
					"Context"
				)

				local whitelist, blacklist = serverProfile.whitelist, serverProfile.banlist
				local successPlayers, failedPlayers = {}, {}

				for i, target in pairs(args[2]) do
					local blacklisted = Identity.checkTable(target, blacklist)
					local whitelisted = not blacklisted and Identity.checkTable(target, whitelist)

					if blacklisted then
						table.insert(failedPlayers, target.UserId)
					else
						if Utility:removBlacklistUserFromReserveServer(serverName, target.UserId) then
							table.insert(successPlayers, target.UserId)
						else
							table.insert(failedPlayers, target.UserId)
						end
					end
				end

				if #failedPlayers > 0 then
					plr:sendData(
						"SendMessage",
						`Failed to unwhitelist <b>{#failedPlayers} player(s)</b> in reserved server {serverName}`,
						nil,
						10,
						"Context"
					)
					wait(2)
				end

				if #successPlayers > 0 then
					plr:sendData(
						"SendMessage",
						`Successfully unwhitelisted <b>{#successPlayers} player(s)</b> in reserved server {serverName}.  This may take a few minutes to apply the changes.`,
						nil,
						10,
						"Context"
					)
				end
			end,
		},
	}

	for cmdName, cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
