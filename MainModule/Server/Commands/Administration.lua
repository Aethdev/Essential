--!nocheck
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

	local Parser = server.Parser
	local Roles = server.Roles
	local Filter = server.Filter
	local Utility = server.Utility

	local Promise = server.Promise
	local Signal = server.Signal

	local cmdsList = {
		cmdBlacklist = {
			Prefix = settings.actionPrefix,
			Aliases = { "cmdblacklist" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
				{
					argument = "command",
					required = true,
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},
			PlayerCooldown = 1,

			Description = "Blacklists specified players from the command",

			Function = function(plr, args)
				local specifiedCmd = Cmds.get(args[2])

				if not specifiedCmd then
					plr:sendData(
						"SendMessage",
						"Command blacklist error",
						"Command <b>" .. args[2] .. "</b> doesn't exist.",
						6,
						"Hint"
					)
				else
					local successPlayers = {}
					local cmdBlacklist = specifiedCmd.Blacklist
						or (function()
							local tab = {}
							specifiedCmd.Blacklist = tab
							return tab
						end)()

					for i, target in pairs(args[1]) do
						if not Moderation.checkAdmin(target) and not Identity.checkTable(cmdBlacklist, target) then
							table.insert(cmdBlacklist, target.UserId)
							table.insert(successPlayers, target.Name)
						end
					end

					if #successPlayers > 0 then
						plr:sendData(
							"SendMessage",
							"Command blacklist success",
							"Blacklisted "
								.. #successPlayers
								.. " players from the command: "
								.. table.concat(successPlayers, 1, 50),
							8
						)
					else
						plr:sendData(
							"SendMessage",
							"Command blacklist failed",
							"There were nobody to blacklist. Make sure they're not already blacklisted",
							8
						)
					end
				end
			end,
		},

		unCmdBlacklist = {
			Prefix = settings.actionPrefix,
			Aliases = { "uncmdblacklist" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
				{
					argument = "command",
					required = true,
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},
			PlayerCooldown = 1,

			Description = "UnBlacklists specified players from the command",

			Function = function(plr, args)
				local specifiedCmd = Cmds.get(args[2])

				if not specifiedCmd then
					plr:sendData(
						"SendMessage",
						"Command blacklist error",
						"Command <b>" .. args[2] .. "</b> doesn't exist.",
						6,
						"Hint"
					)
				else
					local successPlayers = {}
					local cmdBlacklist = specifiedCmd.Blacklist or {}

					for i, target in pairs(args[1]) do
						if Identity.checkTable(cmdBlacklist, target) then
							local tabInd = table.find(cmdBlacklist, target.UserId)

							if tabInd then
								table.remove(cmdBlacklist, tabInd)
								table.insert(successPlayers, target.Name)
							end
						end
					end

					if #successPlayers > 0 then
						plr:sendData(
							"SendMessage",
							"Command blacklist success",
							"UnBlacklisted "
								.. #successPlayers
								.. " players from the command: "
								.. table.concat(successPlayers, 1, 50),
							8
						)
					else
						plr:sendData(
							"SendMessage",
							"Command blacklist failed",
							"There were nobody to unblacklist. Make sure they're not already unblacklisted",
							8
						)
					end
				end
			end,
		},

		serverCommandBlacklist = {
			Prefix = settings.actionPrefix,
			Aliases = { "sercommandblacklist" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},
			PlayerCooldown = 1,

			Description = "Blacklists specified players to prevent them running commands in the server",

			Function = function(plr, args)
				local successPlayers = {}
				local cmdBlacklist = variables.commandBlacklist

				for i, target in pairs(args[1]) do
					if not Moderation.checkAdmin(target) and not Identity.checkTable(cmdBlacklist, target) then
						table.insert(cmdBlacklist, target.UserId)
						table.insert(successPlayers, target.Name)
					end
				end

				if #successPlayers > 0 then
					plr:sendData(
						"SendMessage",
						"GCommand blacklist success",
						"GBlacklisted "
							.. #successPlayers
							.. " players from the server: "
							.. table.concat(successPlayers, 1, 50),
						8
					)
				else
					plr:sendData(
						"SendMessage",
						"GCommand blacklist failed",
						"There were nobody to blacklist. Make sure they're not already blacklisted",
						8
					)
				end
			end,
		},

		unServerCommandBlacklist = {
			Prefix = settings.actionPrefix,
			Aliases = { "unsercommandblacklist" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},
			PlayerCooldown = 1,

			Description = "UnBlacklists specified players from the server command blacklist",

			Function = function(plr, args)
				local successPlayers = {}
				local cmdBlacklist = variables.commandBlacklist

				for i, target in pairs(args[1]) do
					if Identity.checkTable(cmdBlacklist, target) then
						local tabInd = table.find(cmdBlacklist, target.UserId)

						if tabInd then
							table.remove(cmdBlacklist, tabInd)
							table.insert(successPlayers, target.Name)
						end
					end
				end

				if #successPlayers > 0 then
					plr:sendData(
						"SendMessage",
						"GCommand blacklist success",
						"UnGBlacklisted "
							.. #successPlayers
							.. " players from the server: "
							.. table.concat(successPlayers, 1, 50),
						8
					)
				else
					plr:sendData(
						"SendMessage",
						"GCommand blacklist failed",
						"There were nobody to unblacklist. Make sure they're not already unblacklisted",
						8
					)
				end
			end,
		},

		systemCommandBlacklist = {
			Prefix = settings.actionPrefix,
			Aliases = { "syscmdblacklist" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
					ignoreCaller = true,
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},
			PlayerCooldown = 5,

			Description = "Blacklists specified players from using the in-game commands via player data",

			Function = function(plr, args)
				local successPlayers = {}
				local cmdBlacklist = variables.commandBlacklist
				local playerPriority = Roles:getHighestPriority(plr)

				for i, target in args[1] do
					local targetPriority = Roles:getHighestPriority(target)
					if targetPriority < playerPriority then
						local targetPData = target:getPData()

						targetPData._updateIfDead()
						if not targetPData.systemBlacklist then
							targetPData.systemBlacklist = true
							table.insert(successPlayers, target.Name)

							server.PolicyManager:_updateDynamicClientPolicies(target)
						end
					end
				end

				if #successPlayers > 0 then
					plr:sendData(
						"SendMessage",
						"DCommand blacklist success",
						"Data-Blacklisted "
							.. #successPlayers
							.. " players from the server: "
							.. table.concat(successPlayers, 1, 20),
						8
					)
				else
					plr:sendData(
						"SendMessage",
						"DCommand blacklist failed",
						"There were nobody to data-blacklist. Make sure they're already undata-blacklisted",
						8
					)
				end
			end,
		},

		unSystemCommandBlacklist = {
			Prefix = settings.actionPrefix,
			Aliases = { "unsyscmdblacklist" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},
			PlayerCooldown = 5,

			Description = "UnBlacklists specified players via player data",

			Function = function(plr, args)
				local successPlayers = {}
				local cmdBlacklist = variables.commandBlacklist

				for i, target in pairs(args[1]) do
					local targetPData = target:getPData()
					targetPData._updateIfDead()
					if targetPData.systemBlacklist then
						targetPData.systemBlacklist = false
						table.insert(successPlayers, target.Name)
					end
				end

				if #successPlayers > 0 then
					plr:sendData(
						"SendMessage",
						"DCommand blacklist success",
						"Data-UnBlacklisted "
							.. #successPlayers
							.. " players from the server: "
							.. table.concat(successPlayers, 1, 50),
						8
					)
				else
					plr:sendData(
						"SendMessage",
						"DCommand blacklist failed",
						"There were nobody to data-unblacklist. Make sure they're already data-unblacklisted",
						8
					)
				end
			end,
		},

		viewPlayerInfo = {
			Prefix = settings.actionPrefix,
			Aliases = { "pInfo", "playerInfo", "plrInfo" },
			Arguments = {
				{
					argument = "player",
					type = "players",
					required = true,
					allowFPCreation = true
				},
			},
			Permissions = { "Manage_Players" },
			Roles = {},

			Description = "Views a specified player's information",
			PlayerCooldown = 5,

			Function = function(plr, args)
				local target = args[1][1]
				local cliDat = plr:getClientData()
				local pData = target:getPData()

				local highestRole;
				local joinedRoles = {}
				local enlistedRoles = Roles:getRolesFromMember(target)
				local otherRoleCount = 0

				table.sort(enlistedRoles, function(roleA, roleB)
					return roleA.priority > roleB.priority
				end)

				for i, roleInfo in enlistedRoles do
					if not highestRole or roleInfo.priority >= highestRole.priority then
						highestRole = roleInfo
					end
				end

				for i, roleInfo in enlistedRoles do
					local canShowToViewer = not roleInfo.hiddenfromlist
						and (not roleInfo.hidelistfromlowranks or roleInfo.priority <= highestRole.priority)
					
					if canShowToViewer then
						if #joinedRoles + 1 <= 20 then
							table.insert(joinedRoles, "<font color='#"..roleInfo.color:ToHex().."'><b>" .. Parser:filterForRichText(roleInfo.name) .. "</b> ("..roleInfo.priority..")</font>")
						else
							otherRoleCount += 1
						end
					else
						otherRoleCount += 1
					end
				end

				local banCaseInfo: {
					caseId: string,
					moderatorId: number,
					startedOn: number,
					expiresOn: number,
					reason: string,
				}? = pData.BanCase
				local isBanExpired = if banCaseInfo and banCaseInfo.expiresOn then
					DateTime.now().UnixTimestampMillis >= banCaseInfo.expiresOn else false

				local targetInfo = {
					{
						type = "Label",
						selectable = true,
						label = `{plr:toStringDisplay()} - {plr.UserId}\n`
					},
					{
						type = "Label",
						selectable = true,
						richText = true,
						label = `<b>Details</b>\n`
							.. `Full name: <u>{Parser:filterForRichText(target:toStringDisplay())}</u>\n`
							.. `User Id: {target.UserId}\n`
							.. `Character Appearance Id: {target.CharacterAppearanceId}\n`
							.. `Device Type: {cliDat.deviceType}\n\n`
					},
					{
						type = "Label",
						selectable = true,
						richText = true,
						label = `<b>Incognito</b>\n`
							.. `Status: {pData.clientSettings.IncognitoMode and "<b>Active</b>" or "<b>Inactive</b>"}\n`
							.. `Name: {Parser:filterForRichText(pData.incognitoName or "<u>Not provided</u>")}\n\n`
					},
					{
						type = "Label",
						selectable = true,
						richText = true,
						label = `<b>Team</b>\n`
							.. `Assigned to {if not plr.Team then `<i>None</i>` else
								`<font color='#{plr.TeamColor.Color:ToHex()}'>{Parser:filterForRichText(plr.Team.Name)}</font>\n`
							}`
					},
					{
						type = "Detailed",
						selectable = true,
						richText = true,
						specialMarkdownSupported = true,
						label = `Warnings ({#pData.warnings})`;
						description = (function()
							local listOfWarnings = {}

							for i, warnInfo in pData.warnings do
								table.insert(listOfWarnings,  `[{warnInfo.id}]: {Parser:filterForRichText(warnInfo.reason)}`)
							end

							return table.concat(listOfWarnings, "\n")
						end)();
					}, 
					{
						type = "Detailed",
						selectable = true,
						richText = true,
						specialMarkdownSupported = true,
						label = `Enlisted Roles ({#enlistedRoles})`;
						description = (function()
							return (if otherRoleCount > 0 then `<i>+ {otherRoleCount} role{if otherRoleCount > 1 then `s` else ""} not shown</i>\n\n` else "")
								.. `{table.concat(joinedRoles, "\n")}`
						end)();
					}, 
					{
						type = "Detailed",
						selectable = true,
						richText = true,
						specialMarkdownSupported = true,
						label = `Ban Case ({if banCaseInfo and isBanExpired then `<i>Expired</i>`
							elseif not banCaseInfo then `<i>None</i>` else 
							`<i>Active</i>`})`;
						description = (function()
							if not banCaseInfo then return `User was not banned` end
							
							return `Started on \{\{t:{banCaseInfo.startedOn}:ldt\}\}`
								.. (if not banCaseInfo.expiresOn then `` else `\nExpires on \{\{{banCaseInfo.expiresOn}\}\}`)
								.. `\nModerator: {if banCaseInfo.moderatorId <= 0 then `[SYSTEM]` else service.playerNameFromId(banCaseInfo.moderatorId)}`
								.. `\nReason: {Parser:filterForRichText(banCaseInfo.reason or "")}`
						end)();
					}
				}

				plr:makeUI("List", {
					Title = target.Name .. "'s player information",
					List = targetInfo;
					MainSize = Vector2.new(350, 250),
				})
			end,
		},

		sudoPlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "sudo" },
			Chattable = false,
			Silent = true,
			Loggable = false,
			Arguments = {
				{
					type = "players",
					argument = "players",
					ignoreSelf = true,
					required = true,
				},
				{
					argument = "command line",
					required = true,
				},
			},
			Permissions = { "Manage_Players" },
			Roles = {},

			Description = "Forces specified players to run a command",

			Function = function(plr, args)
				local playerPriority = server.Roles:getHighestPriorityFromPermission(plr, "Manage_Players")

				for i, target in pairs(args[1]) do
					local targetPriority = server.Roles:getHighestPriorityFromPermission(target, "Manage_Players")

					if playerPriority > targetPriority then
						task.spawn(function()
							local didProcessSudo =
								Process.playerCommand(target, args[2], { noReturn = true, dontLog = true })

							if didProcessSudo then
								Logs.addLog(
									"Admin",
									"Player " .. plr.Name .. " sudoed " .. target.Name .. ": " .. tostring(args[2])
								)
							end
						end)
					end
				end
			end,
		},

		forcePlacePlayer = {
			--Disabled = server.Studio;
			Prefix = settings.actionPrefix,
			Aliases = { "forceplace", "fplace", "fteleport", "tpplace" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					--ignoreSelf = true;
					required = true,
				},
				{
					argument = "placeId",
					type = "integer",
					required = true,
				},
				{
					argument = "shouldReserveServer",
					type = "trueOrFalse",
					required = false,
				},
			},
			Permissions = { "Manage_Players" },
			Roles = {},
			Chattable = false,

			Description = "Forces specified players to teleport to a specific place",

			Function = function(plr, args)
				local placeInfo = service.getProductInfo(args[2])
				if not placeInfo or placeInfo.AssetTypeId ~= 9 then
					plr:sendData("SendMessage", "❌ Place " .. args[2] .. " doesn't exist", nil, 5, "Context")
					return
				end

				local playerPriority = server.Roles:getHighestPriorityFromPermission(plr, "Manage_Players")
				local successPlayers = {}

				for i, target in pairs(args[1]) do
					local targetPriority = server.Roles:getHighestPriorityFromPermission(target, "Manage_Players")

					if playerPriority > targetPriority then table.insert(successPlayers, target._object) end
				end

				return Promise.each(successPlayers, function(target, index)
					local parsedTarget = Parser:apifyPlayer(target)
					local playerDisplayName = plr:toStringDisplayForPlayer(target)
					parsedTarget:sendData(
						"SendMessage",
						"🏢 Teleporting to place <b>" .. tostring(placeInfo.Name or args[2]) .. "</b>",
						nil,
						20,
						"Context"
					)
					parsedTarget:sendData("SendMessage", "🧙 Teleporter: " .. playerDisplayName, nil, 20, "Context")

					local tpOptions = service.New("TeleportOptions", {
						ShouldReserveServer = args[3] or false,
					})

					service.TeleportService:TeleportAsync(game.PlaceId, { target }, tpOptions)
				end):catch(Logs.Reporters.Promise.issue(`ForcePlace`, "Process"))
			end,
		},

		forceRejoin = {
			Disabled = server.Studio,
			Prefix = settings.actionPrefix,
			Aliases = { "forcerejoin", "frejoin" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					ignoreSelf = true,
					required = true,
				},
				{
					argument = "newPublicServer",
					type = "trueOrFalse",
					required = true,
				},
			},
			Permissions = { "Manage_Players" },
			Roles = {},
			Chattable = false,

			Description = "Forces specified players to rejoin the server/game.",

			Function = function(plr, args)
				local successPlayers = {}

				for i, target in pairs(args[1]) do
					table.insert(successPlayers, target._object)
				end

				return Promise.each(successPlayers, function(target, index)
					local parsedTarget = Parser:apifyPlayer(target)
					parsedTarget:sendData("SendMessage", "🧙🔁 Rejoining the game", nil, 20, "Context")

					local tpOptions = service.New("TeleportOptions", {
						--ShouldReserveServer = args[2] or false;
						ServerInstanceId = (not args[2] and game.JobId) or nil,
					})

					if args[2] then tpOptions.ShouldReserveServer = false end

					service.TeleportService:TeleportAsync(game.PlaceId, { target }, tpOptions)
				end):catch(Logs.Reporters.Promise.issue(`ForcePlace`, "Process"))
			end,
		},

		-- INCOGNITO

		changeIncognitoName = {
			Prefix = settings.actionPrefix,
			Aliases = { "changeincognitoname" },
			Arguments = {
				{
					type = "players",
					argument = "target",
					required = true,
				},
				{
					argument = "newString",
					required = true,
					filter = true,
					requireSafeString = true,
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},
			Chattable = false,

			Description = "Changes specified player' incognito name.",

			Function = function(plr, args)
				local target = args[1][1]
				local targetPData = target:getPData()

				local oldIncognitoName = targetPData.incognitoName or ""
				local incognitoName = Parser:trimString(args[2]) .. ` {targetPData.encryptKey:sub(3, 6)}`

				targetPData.incognitoName = incognitoName

				plr:sendData("SendMessage", `Successfully changed {target:toStringDisplayForPlayer(plr)}'s incognito name to {Parser:filterForRichText(incognitoName)}`, nil, 10, "Context")
				target:sendData("SendNotification", {
					title = `Incognito Name Changed`;
					description = `{plr:toStringDisplayForPlayer(target)} changed your incognito name to {Parser:filterForRichText(incognitoName)}`
						.. `\n\n<i>Previously {Parser:filterForRichText(oldIncognitoName)}</i>`,
					time = 10,
				})
			end,
		},

		--

		clearActivityLogs = {
			Prefix = settings.actionPrefix,
			Aliases = { "clearactivitylogs" },
			Chattable = false,
			Silent = true,
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},

			Description = "Clears activity logs from specified players",

			Function = function(plr, args)
				local successIds = {}

				for i, target in pairs(args[1]) do
					local userId = target.UserId

					if userId and userId > 0 then
						local pData = Core.getPlayerData(userId)
						if #pData.activityLogs == 0 then continue end
						pData.activityLogs = {}

						table.insert(successIds, target.Name .. " (" .. userId .. ")")
					end
				end

				if #successIds > 0 then
					plr:sendData(
						"SendMessage",
						"Successfully cleared activity logs from <b>" .. #successIds .. " players</b>",
						table.concat(successIds, ", "),
						8,
						"Hint"
					)
				end
			end,
		},

		showCmdLogs = {
			Prefix = settings.actionPrefix,
			Aliases = { "cmdlogs" },
			Arguments = {
				{
					type = "trueOrFalse",
					argument = "autoUpdate",
				},
			},
			Permissions = { "View_Logs" },
			Roles = {},
			PlayerCooldown = 2,

			Description = "Show command logs",

			Function = function(plr, args)
				plr:makeUI("List", {
					Title = "E. Command Logs",
					List = Remote.ListData.UsedCmds.Function(plr),
					AutoUpdate = args[1] or false,
					AutoUpdateListData = "UsedCmds",
				})
			end,
		},

		showClientLogs = {
			Prefix = settings.actionPrefix,
			Aliases = { "clientlogs" },
			Arguments = {
				{
					type = "trueOrFalse",
					argument = "autoUpdate",
				},
			},
			Permissions = {},
			Roles = {},
			PlayerCooldown = 2,

			Description = "Show client logs",

			Function = function(plr, args)
				local tab = {}

				plr:makeUI("List", {
					Title = `E. Client Logs for {tostring(plr)}`,
					List = Remote.ListData.Client.Function(plr),
					AutoUpdate = args[1] or false,
					AutoUpdateListData = "Client",
				})

				--plr:makeUI("List", {
				--	Title = "E. Client Logs";
				--	Table = tab;
				--	Stacking = true;
				--	Update = true;
				--	UpdateArg = "Client";
				--	Size = {250, 400};
				--})
			end,
		},

		showGlobalLogs = {
			Prefix = settings.actionPrefix,
			Aliases = { "globallogs" },
			Arguments = {
				{
					type = "trueOrFalse",
					argument = "autoUpdate",
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},
			PlayerCooldown = 2,

			Description = "Show global logs",

			Function = function(plr, args)
				plr:makeUI("List", {
					Title = "E. Global Logs",
					List = Remote.ListData.GlobalApi.Function(plr),
					AutoUpdate = args[1] or false,
					AutoUpdateListData = "GlobalApi",
				})
			end,
		},

		showRemoteLogs = {
			Prefix = settings.actionPrefix,
			Aliases = { "remotelogs" },
			Arguments = {
				{
					type = "trueOrFalse",
					argument = "autoUpdate",
				},
			},
			Permissions = { "View_Logs" },
			Roles = {},
			PlayerCooldown = 2,

			Description = "Show remote logs",

			Function = function(plr, args)
				plr:makeUI("List", {
					Title = "E. Remote Logs",
					List = Remote.ListData.Remote.Function(plr),
					AutoUpdate = args[1] or false,
					AutoUpdateListData = "Remote",
				})
			end,
		},

		showChatLogs = {
			Prefix = settings.actionPrefix,
			Aliases = { "chatlogs" },
			Arguments = {
				{
					type = "trueOrFalse",
					argument = "autoUpdate",
				},
			},
			Permissions = { "View_Logs" },
			Roles = {},
			PlayerCooldown = 2,

			Description = "Show chat logs",

			Function = function(plr, args)
				plr:makeUI("List", {
					Title = "E. Chat Logs",
					List = Remote.ListData.Chat.Function(plr),
					AutoUpdate = args[1] or false,
					AutoUpdateListData = "Chat",
				})
			end,
		},

		showActivityLogs = {
			Prefix = settings.actionPrefix,
			Aliases = { "activitylogs" },
			Arguments = {
				{
					type = "trueOrFalse",
					argument = "autoUpdate",
				},
			},
			Permissions = { "View_Logs" },
			Roles = {},
			PlayerCooldown = 2,

			Description = "Show activity logs (Join & leave logs)",

			Function = function(plr, args)
				plr:makeUI("List", {
					Title = "E. Activity Logs",
					List = Remote.ListData.PlayerActivity.Function(plr),
					AutoUpdate = args[1] or false,
					AutoUpdateListData = "PlayerActivity",
				})
			end,
		},

		showExploitLogs = {
			Prefix = settings.actionPrefix,
			Aliases = { "exploitlogs" },
			Arguments = {
				{
					type = "trueOrFalse",
					argument = "autoUpdate",
				},
			},
			Permissions = { "View_Logs" },
			Roles = {},
			PlayerCooldown = 2,

			Description = "Show exploit logs (Firewall activities currently)",

			Function = function(plr, args)
				plr:makeUI("List", {
					Title = "E. Exploit Logs",
					List = Remote.ListData.Exploit.Function(plr),
					AutoUpdate = args[1] or false,
					AutoUpdateListData = "Exploit",
				})
			end,
		},

		showPlayerActivityLogs = {
			Prefix = settings.actionPrefix,
			Aliases = { "playeractivitylogs" },
			Arguments = {
				{
					argument = "player",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { "View_Logs" },
			Roles = {},
			PlayerCooldown = 2,

			Description = "Show player's activity logs (Join & leave logs)",

			Function = function(plr, args)
				local target = args[1][1]
				local targetData = Core.getPlayerData(target.UserId)

				local tab = {}
				local activeLogs = service.cloneTable(targetData.__activityLogs._table)

				table.sort(activeLogs, function(logA, logB) return (logA.sentOs or 0) > (logB.sentOs or 0) end)

				for i, activeLog in activeLogs do
					table.insert(tab, {
						type = "Log",
						title = activeLog.title,
						desc = activeLog.desc,
						sentOs = activeLog.sentOs,
					})
				end

				plr:makeUI("List", {
					Title = `E. Player Activity Logs for {tostring(target)}`,
					List = tab,
					MinimumSize = Vector2.new(345, 280),
					MainSize = Vector2.new(345, 280),
					ShowDateAndTime = true,
				})
			end,
		},

		showAdminLogs = {
			Prefix = settings.actionPrefix,
			Aliases = { "adminlogs" },
			Arguments = {},
			Permissions = { "Manage_Game" },
			Roles = {},
			PlayerCooldown = 2,

			Description = "Show admin logs",

			Function = function(plr, args)
				plr:makeUI("List", {
					Title = "E. Admin Logs",
					List = Remote.ListData.Admin.Function(plr),
					AutoUpdate = args[1] or false,
					AutoUpdateListData = "Admin",
				})
			end,
		},

		showProcessLogs = {
			Prefix = settings.actionPrefix,
			Aliases = { "processlogs" },
			Arguments = {
				{
					type = "trueOrFalse",
					argument = "autoUpdate",
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},
			PlayerCooldown = 2,

			Description = "Show process logs",

			Function = function(plr, args)
				plr:makeUI("List", {
					Title = "E. Process Logs",
					List = Remote.ListData.Process.Function(plr),
					AutoUpdate = args[1] or false,
					AutoUpdateListData = "Process",
				})
			end,
		},

		showShutdownLogs = {
			Prefix = settings.actionPrefix,
			Aliases = { "shutdownlogs" },
			Arguments = {},
			Permissions = { "Manage_Server" },
			Roles = {},
			PlayerCooldown = 2,

			Description = "Show shutdown logs",

			Function = function(plr, args)
				local tab = {}
				local delimiter = settings.delimiter

				local shutdownLogs = Datastore.read(nil, "shutdownLogs")
				if type(shutdownLogs) ~= "table" then shutdownLogs = {} end

				for i, shutdownD in pairs(shutdownLogs) do
					if type(shutdownD) == "table" then
						local modId = shutdownD.moderatorId
						local serverId = shutdownD.serverId
						local reason = shutdownD.reason
						local startTime = Parser:formatTime(shutdownD.started or 0)

						local serverStarted = shutdownD.serverInfo and shutdownD.serverInfo.started or 0
						local detailedName = shutdownD.serverInfo and shutdownD.serverInfo.detailedName or "[unknown]"

						table.insert(tab, {
							title = `[{startTime}]: {service.playerNameFromId(modId)} closed server {detailedName}`,
							desc = `Server Duration: {Parser:formatTime((shutdownD.started or 0) - serverStarted)} | Reason: {tostring(
								reason
							)}`,
							sentOs = shutdownD.started or 0,
						})

						table.sort(tab, function(a, b) return a.sentOs > b.sentOs end)
					end
				end

				plr:makeUI("List", {
					Title = "E. Shutdown Logs",
					List = tab,
				})
			end,
		},

		shutdownServer = {
			Prefix = settings.actionPrefix,
			Aliases = { "shutdown", "killserver", "terminate", "closeserver", "endserver" },
			Arguments = {
				{
					argument = "reason",
					filter = true,
				},
			},
			Permissions = { "Manage_Server" },
			Roles = {},

			Description = "Shuts down the server (5-second countdown)",
			ServerDebounce = true,

			Function = function(plr, args)
				if not server.Utility.shuttingDownState then
					service.trackTask(`Log Shutdown {plr.UserId}`, false, function()
						plr:sendData("SendMessage", "Logging shutdown data. Please wait..", nil, 5, "Context")

						local shutdownLogs = Datastore.read(nil, "shutdownLogs")
						local shutdownLogData = {
							serverInfo = variables.serverInfo or nil,
							serverId = game.JobId,
							moderatorId = plr.UserId,
							reason = args[1],
							started = tick(),
						}

						if type(shutdownLogs) ~= "table" or #shutdownLogs > 30 then
							Datastore.write(nil, "shutdownLogs", {
								[1] = shutdownLogData,
							})
						else
							Datastore.tableAdd(nil, "shutdownLogs", false, shutdownLogData)
						end

						plr:sendData(
							"SendMessage",
							"Successfully logged shutdown. Now closing the server..",
							nil,
							5,
							"Context"
						)
					end)

					server.Utility:shutdown(args[1], nil, plr.UserId)
				end
			end,
		},

		softShutdownServer = {
			Prefix = settings.actionPrefix,
			Aliases = { "softshutdown", "restartserver", "rebootserver" },
			Arguments = {
				{
					argument = "reason",
					filter = true,
				},
			},
			Permissions = { "Manage_Server" },
			Roles = {},

			Description = "Restarts the server (5-second countdown)",
			PlayerCooldown = 5,
			ServerDebounce = true,

			Function = function(plr, args)
				if not server.Utility.shuttingDownState then
					if server.Studio or game.PrivateServerOwnerId > 0 then
						plr:sendData(
							"SendMessage",
							"❌ Studio & personal servers cannot permit soft shutdown.",
							nil,
							5,
							"Context"
						)
						return
					end

					service.trackTask(`Log SoftShutdown {plr.UserId}`, false, function()
						plr:sendData("SendMessage", "Logging soft shutdown data. Please wait..", nil, 5, "Context")

						local shutdownLogs = Datastore.read(nil, "shutdownLogs")
						local shutdownLogData = {
							serverInfo = variables.serverInfo or nil,
							serverId = game.JobId,
							moderatorId = plr.UserId,
							reason = args[1],
							started = tick(),
						}

						if type(shutdownLogs) ~= "table" or #shutdownLogs > 30 then
							Datastore.write(nil, "shutdownLogs", {
								[1] = shutdownLogData,
							})
						else
							Datastore.tableAdd(nil, "shutdownLogs", false, shutdownLogData)
						end

						plr:sendData(
							"SendMessage",
							"Successfully logged soft shutdown. Now preparing soft shutdown..",
							nil,
							5,
							"Context"
						)
					end)

					plr:sendData("SendMessage", "Preparing a new server to hop on. Please wait..", nil, 5, "Context")
					local reservedServerDetails = Utility:createReserveServer(nil, nil, {
						temporary = true,
						publicJoin = true,
					})

					plr:sendData(
						"SendMessage",
						"Success! This may take a while to have everyone teleport to the new server..",
						nil,
						5,
						"Context"
					)

					for i, target in ipairs(service.getPlayers(true)) do
						local playerDisplayName = plr:toStringDisplayForPlayer(target)
						target:sendData(
							"SendMessage",
							"Moderator <u>"
								.. playerDisplayName
								.. "</u> performed a soft shutdown. You are being teleported to the new server.",
							nil,
							30,
							"Context"
						)
						target:teleportToReserveWithSignature(
							reservedServerDetails.serverAccessId,
							function()
								target:Kick "Failed to teleport to a new server. You are not allowed to join the current server."
							end
						)
					end

					Utility:shutdown("Soft shutdown in progress", 20)
				end
			end,
		},

		crossShutdown = {
			Prefix = settings.actionPrefix,
			Aliases = { "crossshutdown", "globalshutdown" },
			Arguments = {
				{
					argument = "reason",
					filter = true,
				},
			},
			Permissions = { "Cross_Commands", "Manage_Server" },
			Roles = {},

			Description = "Shuts down running servers from the game (5-second countdown)",
			CrossCooldown = 15,

			Function = function(plr, args)
				plr:sendData(
					"SendMessage",
					"Successfully sent shutdown command to all servers. This may take a while to register in servers.",
					nil,
					5,
					"Context"
				)
				Cross.send("Shutdown", plr.Name .. ": " .. tostring(args[1] or "No reason specified"), 2)
			end,
		},

		crossCommand = {
			Prefix = settings.actionPrefix,
			Aliases = { "cross" },
			Arguments = { "command" },
			ServerCooldown = 5,
			Permissions = { "Cross_Commands/Manage_Game" },
			Roles = {},

			Description = "Executes a command to running servers",
			PlayerCooldown = 2,

			Function = function(plr, args)
				plr:sendData(
					"SendMessage",
					"Successfully sent command to all servers. This may take a while to register in servers.",
					nil,
					5,
					"Context"
				)

				Cross.send("ExecuteCommand", {
					playerName = plr.Name,
					playerId = plr.UserId,
					input = args[1],
					ranCross = true,
				})
			end,
		},

		crossMessage = {
			Prefix = settings.actionPrefix,
			Aliases = { "cmessage" },
			Arguments = {
				{
					argument = "message",
					filterForPublic = true,
					required = true,
				},
			},
			ServerCooldown = 10,
			Permissions = { "Cross_Commands", "Manage_Server" },
			Roles = {},

			Description = "Presents a message to all players in the game",

			Function = function(plr, args)
				Cross.send(
					"PublishMessage",
					"Broadcast from <b>" .. plr.Name .. "</b>",
					args[1],
					math.clamp(#args[1] * 0.1, 3, 30)
				)
			end,
		},

		crossPrivateMessage = {
			Prefix = settings.actionPrefix,
			Aliases = { "cpmessage" },
			Arguments = {
				{
					argument = "players",
					required = true,
				},
				{
					argument = "message",
					filter = true,
					required = true,
				},
			},
			ServerCooldown = 20,
			PlayerCooldown = 35,
			Permissions = { "Cross_Commands", "Manage_Server" },
			Roles = {},

			Description = "Presents a message to all players in the game",

			Function = function(plr, args)
				local crossEvent = Signal.new()
				local eventId = "Pm-" .. service.getRandom(15)
				local expireOs = os.time() + 180

				variables.crossEvents[eventId] = crossEvent

				crossEvent:connect(function(jobId, receiverId, replyMsg, expireOs, scheduledOs)
					local receiverName = service.playerNameFromId(receiverId) or "[unknown]"

					local replyPm = Remote.privateMessage {
						receiver = plr,
						sender = { UserId = receiverId, Name = receiverName },
						topic = "Cross Message from " .. receiverName,
						message = Parser:filterForRichText(replyMsg),
						expireOs = expireOs,
						scheduledOs = scheduledOs,
					}
					replyPm.dontMessageSender = true

					replyPm.replied:connectOnce(function(newReply)
						local safeString, filterMsg = Filter:safeString(newReply, receiverId, receiverId)
						Cross.send(
							"PrivateMessage",
							"Cross Message from " .. plr.Name,
							filterMsg:sub(1, 300),
							expireOs,
							nil,
							{ Name = plr and plr.Name, UserId = plr and plr.UserId },
							"@" .. receiverName,
							eventId
						)
					end)
				end)

				Cross.send(
					"PrivateMessage",
					"Cross Message from " .. plr.Name,
					args[2]:sub(1, 300),
					expireOs,
					nil,
					{ Name = plr and plr.Name, UserId = plr and plr.UserId },
					args[1],
					eventId
				)
			end,
		},

		crossChat = {
			Prefix = settings.actionPrefix,
			Aliases = { "cchat" },
			Arguments = {
				{
					argument = "message",
					filter = true,
					required = true,
				},
			},
			Permissions = { "Cross_Commands", "Manage_Server" },
			Roles = {},

			Description = "Presents a chat message to all players in the game",
			PlayerCooldown = 5,

			Function = function(plr, args) Cross.send("CrossChat", plr.Name, args[1]) end,
		},

		whitelist = {
			Prefix = settings.actionPrefix,
			Aliases = { "wlstatus" },
			Arguments = {
				{
					type = "trueOrFalse",
					argument = "enabled (true/false)",
				},
			},
			Permissions = { "Manage_Server" },
			Roles = {},

			Description = "Modifies the server whitelist status",

			Function = function(plr, args)
				if args[1] == nil then
					plr:sendData(
						"SendMessage",
						"Whitelist",
						"Status: " .. tostring(variables.whitelistData.enabled),
						5,
						"Hint"
					)
				else
					plr:sendData(
						"SendMessage",
						"Whitelist",
						"Set status to <b>" .. tostring(args[1]) .. "</b>",
						5,
						"Hint"
					)
					variables.whitelistData.enabled = args[1]
				end
			end,
		},

		whitelist_addPlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "wladd" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { "Manage_Server" },
			Roles = {},

			Description = "Adds a whitelisted player from data (cannot stack)",

			Function = function(plr, args)
				local whitelistTable = variables.whitelistData.whitelisted
				local successPlayers = {}

				for i, target in ipairs(args[1]) do
					local alreadyExist = table.find(whitelistTable, "Player:" .. target.Name:lower())

					if not alreadyExist then
						table.insert(whitelistTable, "Player:" .. target.Name:lower())
						table.insert(successPlayers, target.Name)
					end
				end

				if #successPlayers > 0 then
					plr:sendData(
						"SendMessage",
						"Added player to whitelist",
						tostring(
							(#successPlayers < 6 and table.concat(successPlayers, ", "))
								or #successPlayers .. " players"
						) .. " is/are added to the whitelist",
						5,
						"Hint"
					)
				end
			end,
		},

		whitelist_removePlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "wlremove" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { "Manage_Server" },
			Roles = {},

			Description = "Removes a whitelisted player from data",

			Function = function(plr, args)
				local whitelistTable = variables.whitelistData.whitelisted
				local successPlayers = {}

				for i, target in ipairs(args[1]) do
					local alreadyExist = table.find(whitelistTable, "Player:" .. target.Name:lower())

					if alreadyExist then
						table.remove(whitelistTable, alreadyExist)
						table.insert(successPlayers, target.Name)
					end
				end

				if #successPlayers > 0 then
					plr:sendData(
						"SendMessage",
						"Removed players from whitelist",
						tostring(
							(#successPlayers < 6 and table.concat(successPlayers, ", "))
								or #successPlayers .. " players"
						) .. " is/are added to the whitelist",
						5,
						"Hint"
					)
				end
			end,
		},

		whitelist_adminOnly = {
			Prefix = settings.actionPrefix,
			Aliases = { "wladmins" },
			Arguments = {
				{
					argument = "true/false",
					type = "trueOrFalse",
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},

			Description = "Modifies whitelist to admins",

			Function = function(plr, args)
				local whitelistTable = variables.whitelistData.whitelisted

				if args[1] == nil then
					plr:sendData(
						"SendMessage",
						"Whitelist status",
						"OnlyAdmins: " .. tostring(whitelistTable.admins),
						5,
						"Hint"
					)
				else
					whitelistTable.admins = args[1]
					plr:sendData(
						"SendMessage",
						"Whitelist status",
						"Set OnlyAdmins to " .. tostring(args[1]),
						5,
						"Hint"
					)
				end
			end,
		},

		whitelist_setMessage = {
			Prefix = settings.actionPrefix,
			Aliases = { "setwlmessage" },
			Arguments = {
				{
					argument = "message",
					required = true,
					filter = true,
				},
			},
			Permissions = { "Manage_Server" },
			Roles = {},

			Description = "Modifies whitelist message to a specified one",

			Function = function(plr, args)
				settings.LockMessage = args[1]
				plr:sendData("SendMessage", "Whitelist message", "Changed to <b>" .. args[1] .. "</b>", 5, "Hint")
			end,
		},

		clearPlayerData = {
			Prefix = settings.actionPrefix,
			Aliases = { "clearplayerdata" },
			Chattable = false,
			Silent = true,
			Arguments = {
				{
					argument = "usernames",
					type = "list",
					required = true,
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},

			Description = "Clears player data from specified players",

			Function = function(plr, args)
				local successIds = {}

				local checkConfirm = plr:customGetData(10 + 30, "MakeUI", "ConfirmationV2", {
					title = "Player Data Management",
					desc = "Are you sure you want to clear "..#args[1].." player(s)'s player data? This action is irrversible.",

					firstChoice = {
						label = "I confirm",
						customSubmissionPage = {
							title = "Cleared player data",
						},
					},
					secondChoice = { label = "No" },

					returnOutput = true,
					time = 10,
				})

				if checkConfirm ~= 1 then
					return
				end

				for i, username in pairs(args[1]) do
					local userId = service.playerIdFromName(username) or 0

					if userId and userId > 0 then
						local stat =
							Datastore.remove("PData_" .. settings.Datastore_PlayerData:sub(1, 44), tostring(userId))

						if stat then
							local pData = Core.getPlayerData(userId)
							for i, v in pairs(pData._table) do
								pData[i] = nil
							end

							local defaultData = Core.defaultPlayerData()
							for i, v in pairs(defaultData) do
								pData[i] = v
							end

							table.insert(successIds, username .. " (" .. userId .. ")")
						end
					end
				end

				if #successIds > 0 then
					plr:sendData(
						"SendMessage",
						"Successfully cleared player datas from <b>" .. #successIds .. " players</b>",
						table.concat(successIds, ", "),
						8,
						"Hint"
					)
				end
			end,
		},

		-- Warning system
		warnPlayer = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "warn" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
				{
					argument = "reason",
					required = true,
					filter = true,
					requireSafeString = true,
				},
			},
			Permissions = { "Warn_Player" },
			Roles = {},

			Description = "Warns specified players to reason",
			PlayerCooldown = 5,

			Function = function(plr, args)
				local successPlayers = {}

				for i, target in pairs(args[1]) do
					Moderation.warnPlayer(target, {
						reason = args[2],
						moderator = plr,
						category = "player",
					})
					table.insert(successPlayers, target)
				end

				if #successPlayers > 0 then
					plr:sendData(
						"SendMessage",
						"Successfully warned "
							.. #successPlayers
							.. " players for "
							.. Parser:filterForRichText(args[2]),
						nil,
						5,
						"Context"
					)
				end
			end,
		},

		removeWarnings = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "removeWarn", "unWarn" },
			Arguments = {
				{
					argument = "player",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
				{
					argument = "id",
					required = true,
				},
			},
			Permissions = { "Warn_Player" },
			Roles = {},

			Description = "Removes a warning via its supplied id from a specified player",
			PlayerCooldown = 5,

			Function = function(plr, args)
				local targetName = args[1][1]:toStringDisplayForPlayer(plr)
				local targetId = args[1][1].UserId

				local targetPData = Core.getPlayerData(targetId)
				local warnings = targetPData.warnings

				if type(warnings) ~= "table" then
					warnings = {}
					targetPData.warnings = warnings
				end
				
				local removeCount = 0

				for i, warnInfo in pairs(warnings) do
					if warnInfo.id == args[2] and (not warnInfo.category or warnInfo.category == "player") then
						targetPData._tableRemove("warnings", warnInfo)
						removeCount += 1
					end
				end

				if removeCount > 0 then
					targetPData._updateIfDead()
					plr:sendData(
						"SendMessage",
						"Successfully removed warning <i>" .. args[2] .. "</i> from <b>" .. targetName .. "</b>",
						nil,
						10,
						"Context"
					)
				end
			end,
		},

		viewWarnings = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "warnings" },
			Arguments = {
				{
					argument = "player",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { "Warn_Player" },
			Roles = {},

			Description = "Views warnings from a specified player",
			PlayerCooldown = 5,

			Function = function(plr, args)
				local targetName = args[1][1].Name
				local targetId = args[1][1].UserId or 0

				if targetId > 0 then
					local pData = Core.getPlayerData(targetId)
					local warnings = pData.warnings

					if type(warnings) ~= "table" then
						warnings = {}
						pData.warnings = warnings
					end

					pData._updateIfDead()

					local list = {}

					table.sort(warnings, function(new, old) return new.created < old.created end)

					for i, warnInfo in pairs(warnings) do
						if not (not warnInfo.category or warnInfo.category == "player") then continue end

						table.insert(list, {
							type = "Log",
							title = `[{warnInfo.id}]: {warnInfo.reason}`,
							desc = `Type: {warnInfo.category}\nId: {warnInfo.id}\nModerator: {warnInfo.moderator.name} ({tostring(
								warnInfo.moderator.userId
							)})`,
							sentOs = warnInfo.created,
						})
					end

					plr:makeUI("List", {
						Title = "E. Warnings for " .. tostring(args[1][1]),
						List = list,
						AutoUpdateListData = "Remote",
					})
				end
			end,
		},

		clearWarnings = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Aliases = { "clearwarnings" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { "Warn_Player" },
			Roles = {},

			Description = "Views warnings from a specified player",
			PlayerCooldown = 5,

			Function = function(plr, args)
				local targetName = args[1][1]:toStringDisplayForPlayer(plr)

				local pData = args[1][1]:getPData()
				local warnings = pData.warnings

				if type(warnings) == "table" then
					pData.warnings = nil
					pData._updateIfDead()

					plr:sendData(
						"SendMessage",
						"Successfully cleared <b>" .. args[1] .. "</b>'s warnings",
						nil,
						10,
						"Context"
					)
				end
			end,
		},

		kickPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "kick", "bootoff", "remove" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "message",
					required = true,
					filter = true,
				},
			},
			Permissions = { "Kick_Player" },
			Roles = {},

			Description = "Kicks specified players with a given reason",

			Function = function(plr, args)
				local players = args[1]

				local playerPriority = server.Roles:getHighestPriorityFromPermission(plr, "Kick_Player")

				local successPlayers = {}
				local concatPlayers = {}

				for i, target in pairs(players) do
					local targetPriority = server.Roles:getHighestPriorityFromPermission(target, "Kick_Player")

					if playerPriority > targetPriority then
						target:Kick(args[2] or "No reason specified")
						table.insert(successPlayers, target)
						table.insert(concatPlayers, target:toStringDisplayForPlayer(plr))
					end
				end

				if #successPlayers > 0 and plr then
					plr:sendData(
						"SendMessage",
						"Successfully kicked "
							.. ((#concatPlayers < 6 and table.concat(concatPlayers, ", ") or #concatPlayers) .. " players")
							.. ".",
						nil,
						10,
						"Context"
					)
					server.Events.modKicked:fire(plr:getInfo(), successPlayers)
				end
			end,
		},

		resolveBanForSpecificPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "resolvebanforplayers" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,
					allowFPCreation = true,
				},
				{
					argument = "caseId",
					required = true,
					private = true,
				},
			},
			Permissions = { "Ban_Player" },
			Roles = {},
			CrossCooldown = 10,

			Description = "Resolves a ban case for specific players",

			Function = function(plr, args)
				plr:sendData("SendMessage", `Looking up ban case {args[2]}..`, nil, 10, "Context")

				local banCase = Moderation.getBanCase(args[2])
				if not banCase then
					plr:sendData("SendMessage", `Ban case {args[2]} doesn't exist.`, nil, 10, "Context")
					return
				end

				Moderation.resolveBanCaseForPlayers(args[2], args[1] "listUserIds"())
				plr:sendData(
					"SendMessage",
					`Resolved ban case {args[2]} for {#args[1]} player(s). If this is a universal ban case, please wait 30-90 seconds for it to take effect in the game.`,
					nil,
					15,
					"Context"
				)
			end,
		},

		resolveBan = {
			Prefix = settings.actionPrefix,
			Aliases = { "resolveban" },
			Arguments = {
				{
					argument = "caseId",
					required = true,
					private = true,
				},
			},
			Permissions = { "Ban_Player" },
			Roles = {},
			CrossCooldown = 10,

			Description = "Resolves a ban case for specific players",

			Function = function(plr, args)
				plr:sendData("SendMessage", `Looking up ban case {args[1]}..`, nil, 10, "Context")

				local banCase = Moderation.getBanCase(args[1])
				if not banCase then
					plr:sendData("SendMessage", `Ban case {args[1]} doesn't exist.`, nil, 10, "Context")
					return
				end

				local checkConfirm = plr:customGetData(10 + 30, "MakeUI", "ConfirmationV2", {
					title = "Ban Management",
					desc = "Are you sure you want to resolve ban case " .. args[1] .. "? This action is irreversible",

					firstChoice = {
						label = "I confirm",
						customSubmissionPage = {
							title = "Ban Resolved",
						},
					},
					secondChoice = { label = "No" },

					returnOutput = true,
					time = 10,
				})

				if checkConfirm ~= 1 then return end
				Moderation.resolveBanCase(args[1])
				plr:sendData(
					"SendMessage",
					`Resolved ban case {args[1]} for {#banCase.users} player(s). If this is a universal ban case, please wait 30-90 seconds for it to take effect in the game.`,
					nil,
					15,
					"Context"
				)
			end,
		},

		universalBan = {
			Prefix = settings.actionPrefix,
			Aliases = { "universeban", "universalban", "gban" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,

					maxPlayers = 10,
					ignoreSelf = true,
					allowFPCreation = true,
				},
				{
					type = "trueOrFalse",
					argument = "affectAltAccounts",
					required = true,
				},
				{
					type = "duration",
					argument = "timeDuration",
					required = true,
				},
				{
					argument = "reason",
					filter = true,
				},
			},
			Permissions = { "Request_Ban/Ban_Player" },
			Roles = {},
			CrossCooldown = 15,

			Description = "Creates a universal ban case for the specified players (max: 10)",

			Function = function(plr, args, data)
				local isCommandUniversal = data.isServer ~= true

				if args[3].total > 0 and args[3].total < 60 then
					plr:sendData(
						"SendMessage",
						`You must specify at a least minute for the time duration of the universal ban or 0 seconds for <b>PERMANENT</b>.`,
						nil,
						10,
						"Context"
					)
					return
				end

				local ignoredPlayers = {}
				local ignorePriorityLevel = server.Studio
				local playerPriority = not ignorePriorityLevel
					and server.Roles:getHighestPriorityFromPermission(plr, "Ban_Player")

				if not ignorePriorityLevel then
					for i, target in pairs(args[1]) do
						local targetPriority = server.Roles:getHighestPriorityFromPermission(target, "Ban_Player")

						if playerPriority <= targetPriority then
							table.insert(ignoredPlayers, target:toStringDisplayForPlayer(plr))
							args[1][i] = nil
						end
					end
				end

				if #ignoredPlayers > 0 then
					plr:makeUI("NotificationV2", {
						title = "Ban Management Error",
						desc = "Unable to ban players with higher/equal priority level: "
							.. table.concat(ignoredPlayers, " "),
					})
				end

				if #args[1] == 0 then return end
				--warn(`list of userids:`, args[1]("listUserIds")())
				plr:sendData("SendMessage", `Creating a ban case for {#args[1]} player(s)`, nil, 10, "Context")

				Moderation.createBan(
					{
						type = if isCommandUniversal then "Universal" else "Server",
						expiresOn = if args[3].total == 0 then nil else (os.time() + args[3].total) * 1000, --// Must be in milliseconds

						users = args[1] "listUserIds"(),
						moderatorId = plr.UserId,

						reason = args[4] or `Moderator did not specify`,
						useRobloxApi = true,
						affectAltAccounts = args[2],
					},
					function(caseId)
						plr:sendData(
							"SendMessage",
							`Successfully created ban case {caseId} for {#args[1]} player(s)`
								.. (
									if args[3].total == 0
										then `.`
										else ` It will expire on \{\{t:{(os.time() + args[3].total)}\}\}.`
								),
							nil,
							10,
							"Context"
						)
					end
				)
			end,
		},

		serverBan = {
			Prefix = settings.actionPrefix,
			Aliases = { "serverban", "sban" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,

					maxPlayers = 10,
					ignoreSelf = not server.Studio,
					allowFPCreation = true,
				},
				{
					type = "duration",
					argument = "timeDuration",
					required = true,
				},
				{
					argument = "reason",
					filter = true,
				},
			},
			Permissions = { "Ban_Player" },
			Roles = {},
			PlayerCooldown = 5,

			Description = "Creates a server ban case for the specified players (max: 10)",

			Function = function(plr, args, data)
				local universalBanCommand = server.Commands.Library["universalBan"]
				return universalBanCommand.Function(
					plr,
					{ args[1], false, args[2], args[3] },
					setmetatable({ isServer = true }, { __index = data or {} })
				)
			end,
		},

		listBans = {
			Prefix = settings.actionPrefix,
			Aliases = { "bans", "banlist", "banland", "unibans", "universebans" },
			Arguments = {},
			Permissions = { "Ban_Player" },
			Roles = {},
			CrossCooldown = 10,

			Description = "Shows a list of banned cases & legacy bans",

			Function = function(plr, args)
				local globalBans = Moderation.globalBanCasesList
				local tableList = {}

				table.insert(tableList, {
					type = "Label",
					label = "Universal\n---------",
				})

				local nowTimestamp = DateTime.now()
				for
					i,
					minimizedBanCase: {
					caseId: string,
					moderatorId: string,
					users: { [number]: number },
					reason: string,
					startedOn: number,
					expiresOn: number?,
				}
				in globalBans do
					local isActive = if minimizedBanCase.expiresOn
						then minimizedBanCase.expiresOn - nowTimestamp.UnixTimestampMillis > 0
						else true

					local concatUsers = {}

					for i, userId in minimizedBanCase.users do
						table.insert(concatUsers, service.playerNameFromId(userId) .. ` ({userId})`)
					end

					table.insert(tableList, {
						type = "Action",
						specialMarkdownSupported = true,
						label = `<b>Case {minimizedBanCase.caseId}</b>\nStarted on \{\{t:{math.floor(
							minimizedBanCase.startedOn / 1000
						)}\}\}\nReason: {minimizedBanCase.reason}\nUsers: {table.concat(concatUsers, ", ")}`,
						labelColor = if not isActive then Color3.fromRGB(121, 121, 121) else nil,
						richText = true,
						selectable = true,

						optionsLayoutStyle = "Log",
						options = {
							{
								label = "🔎 Lookup",
								backgroundColor = Color3.fromRGB(241, 117, 55),
								onExecute = "playercommand://" .. server.Commands.getIdFromCommand(
									settings.actionPrefix .. `lookupban`
								) .. "||" .. minimizedBanCase.caseId,
							},
							{
								label = "Resolve",
								backgroundColor = Color3.fromRGB(115, 143, 22),
								onExecute = "playercommand://"
									.. Cmds.get(settings.actionPrefix .. "resolveban").Id
									.. "||"
									.. minimizedBanCase.caseId,
							},
							--[number]: {
							--	label: string,
							--	textColor: Color3,
							--	backgroundColor: Color3,
							--	onExecute: () -> any?,
							--}
						},
					})
				end

				for
					i,
					minimizedBanCase: {
					moderator: { name: string, userid: Moderator_Id },
					type: string,
					reason: string,
					registered: number,
					expireTime: number?,
					offender: { name: string, userid: number },
					contents: {},
					id: string,
				}
				in Moderation.legacyGlobalBans do
					local isActive = if minimizedBanCase.expiresOn
						then minimizedBanCase.expiresOn - nowTimestamp.UnixTimestampMillis > 0
						else true

					local concatUsers = {}

					for i, userId in minimizedBanCase.users do
						table.insert(concatUsers, service.playerNameFromId(userId) .. ` ({userId})`)
					end

					table.insert(tableList, {
						type = "Action",
						specialMarkdownSupported = true,
						label = `<b>Case {minimizedBanCase.caseId}</b>\nStarted on \{\{t:{math.floor(
							minimizedBanCase.startedOn / 1000
						)}\}\}\nReason: {minimizedBanCase.reason}\nUsers: {table.concat(concatUsers, ", ")}`,
						labelColor = if not isActive then Color3.fromRGB(121, 121, 121) else nil,
						richText = true,
						selectable = true,

						optionsLayoutStyle = "Log",
						options = {
							{
								label = "🔎 Lookup",
								backgroundColor = Color3.fromRGB(241, 117, 55),
								onExecute = "playercommand://" .. server.Commands.getIdFromCommand(
									settings.actionPrefix .. `lookupban`
								) .. "||" .. minimizedBanCase.caseId,
							},
							{
								label = "Resolve",
								backgroundColor = Color3.fromRGB(115, 143, 22),
								onExecute = "playercommand://"
									.. Cmds.get(settings.actionPrefix .. "resolveban").Id
									.. "||"
									.. minimizedBanCase.caseId,
							},
							--[number]: {
							--	label: string,
							--	textColor: Color3,
							--	backgroundColor: Color3,
							--	onExecute: () -> any?,
							--}
						},
					})
				end

				--if #globalBans == 0 then
				--	table.insert(tableList, {
				--		type = "Label";
				--		label = "<i>No universe bans found</i>";
				--		richText = true;
				--	})
				--end

				table.insert(tableList, {
					type = "Label",
					label = "Server\n---------",
				})

				local serverBanCases = Moderation.serverBanCases

				for
					i,
					minimizedBanCase: {
					caseId: string,
					moderatorId: string,
					users: { [number]: number },
					reason: string,
					startedOn: number,
					expiresOn: number?,
				}
				in serverBanCases do
					local isActive = if minimizedBanCase.expiresOn
						then minimizedBanCase.expiresOn - nowTimestamp.UnixTimestampMillis > 0
						else true

					local concatUsers = {}

					for i, userId in minimizedBanCase.users do
						table.insert(concatUsers, service.playerNameFromId(userId) .. ` ({userId})`)
					end

					table.insert(tableList, {
						type = "Action",
						specialMarkdownSupported = true,
						label = `<b>Case {minimizedBanCase.caseId}</b>\nStarted on \{\{t:{math.floor(
							minimizedBanCase.startedOn / 1000
						)}\}\}\nReason: {minimizedBanCase.reason}\nUsers: {table.concat(concatUsers, ", ")}`,
						labelColor = if not isActive then Color3.fromRGB(121, 121, 121) else nil,
						richText = true,
						selectable = true,

						optionsLayoutStyle = "Log",
						options = {
							{
								label = "🔎 Lookup",
								backgroundColor = Color3.fromRGB(241, 117, 55),
								onExecute = "playercommand://" .. server.Commands.getIdFromCommand(
									settings.actionPrefix .. `lookupban`
								) .. "||" .. minimizedBanCase.caseId,
							},
							{
								label = "Resolve",
								backgroundColor = Color3.fromRGB(115, 143, 22),
								onExecute = "playercommand://"
									.. Cmds.get(settings.actionPrefix .. "resolveban").Id
									.. "||"
									.. minimizedBanCase.caseId,
							},
							--[number]: {
							--	label: string,
							--	textColor: Color3,
							--	backgroundColor: Color3,
							--	onExecute: () -> any?,
							--}
						},
					})
				end

				plr:makeUI("List", {
					Title = "Universe & Server Bans",
					List = tableList,

					MainSize = Vector2.new(400, 300),
					MinimumSize = Vector2.new(350, 300),
				})
			end,
		},

		lookupBanCase = {
			Prefix = settings.actionPrefix,
			Aliases = { "lookupban" },
			Arguments = {
				{
					argument = "caseId",
					stringPattern = "^([S%-]*%w+)$",
					required = true,
					private = true,
				},
			},
			Permissions = { "Ban_Player" },
			Roles = {},
			CrossCooldown = 10,
			ServerCooldown = 15,

			Description = "Looks up a ban case",

			Function = function(plr, args)
				if args[1][1]:sub(1, 2):lower() == `l-` then
					plr:sendData(
						"SendMessage",
						`Looking up legacy bans (pseudo ban case ids starting with <b>L-</b>) are not possible for lookups.`,
						nil,
						10,
						"Context"
					)
					return
				end

				plr:sendData(
					"SendMessage",
					`Looking up ban case {args[1][1]}..`
						.. (
							if args[1][1]:sub(1, 2) ~= `S-`
								then ` <i>It will take 10-45 seconds to look up.</i>`
								else ``
						),
					nil,
					5,
					"Context"
				)

				local banCase = if #args[1][1] == 0 then nil else Moderation.getBanCase(args[1][1])
				if not banCase or banCase.status == `inactive` then
					plr:makeUI("NotificationV2", {
						title = "Ban Management Error",
						desc = `Case Id {args[1][1]} doesn't exist`,
					})
					return
				end

				local isBanCaseExpired = if not banCase.expiresOn
					then false
					else DateTime.now().UnixTimestampMillis - banCase.expiresOn >= 0
				local banCaseNotes = service.cloneTable(banCase.notes)
				local concatNotes = {}

				table.sort(banCaseNotes, function(noteA, noteB) return noteA[2] > noteB[2] end)

				if #banCaseNotes == 0 then
					table.insert(concatNotes, {
						type = "Label",
						label = `<i>No notes available to show</i>`,
						richText = true,
					})
				else
					for i, noteData: { id: number, sentUnixMillis: number, message: string } in banCaseNotes do
						table.insert(concatNotes, {
							type = "Label",
							label = `[\{\{t:{math.floor(noteData[2] / 1000)}:lt\}\}] [{noteData[1]}]: {noteData[3]}`,
							specialMarkdownSupported = true,
							selectable = true,
						})
					end
				end

				local concatUsers = {}
				local resolveBanCommandId =
					server.Commands.getIdFromCommand(settings.actionPrefix .. `resolvebanforplayers`)

				for i, userId in banCase.users do
					table.insert(
						concatUsers,
						if table.find(banCase.releasedUsers, userId) or isBanCaseExpired
							then {
								type = "Label",
								label = `<s>` .. service.playerNameFromId(userId) .. ` ({userId})</s>`,
								richText = true,
								selectable = true,
							}
							else {
								type = "Action",
								label = service.playerNameFromId(userId) .. ` ({userId})`,
								optionsLayoutStyle = "Log",
								options = {
									{
										label = "Resolve",
										backgroundColor = Color3.fromRGB(30, 77, 149),
										onExecute = "playercommand://"
											.. resolveBanCommandId
											.. "||@"
											.. service.playerNameFromId(userId),
									},
								},
								selectable = true,
							}
					)
				end

				plr:makeUI("List", {
					Title = "Ban Case " .. args[1][1],
					List = service.mergeTables(
						true,
						{
							{
								type = "Label",
								label = `Moderator: `
									.. (
										if banCase.moderatorId == 0
											then `System`
											elseif banCase.moderatorId == -1 then `AutoModerator`
											else service.playerNameFromId(banCase.moderatorId)
												.. ` ({banCase.moderatorId})`
									),
								selectable = true,
							},
							{
								type = "Label",
								label = `Started on \{\{t:{math.floor(banCase.startedOn / 1000)}\}\}`
									.. (
										if not banCase.expiresOn
											then ``
											else ` and end{if isBanCaseExpired then "ed" else "s"} \{\{t:{math.floor(
												banCase.expiresOn / 1000
											)}:rt\}\}`
									),
								richText = true,
								selectable = true,
								specialMarkdownSupported = true,
							},
							{ type = "Label", label = `\n-------` },
							{ type = "Label", label = `Users:` },
						},
						concatUsers,
						{
							{ type = "Label", label = `\n-------` },
							{ type = "Label", label = `Notes:` },
						},
						concatNotes,
						{
							if not isBanCaseExpired
								then {
									type = "Action",
									label = `\n`,
									options = {
										{
											label = "Resolve",
											backgroundColor = Color3.fromRGB(241, 117, 55),
											onExecute = "playercommand://" .. server.Commands.getIdFromCommand(
												settings.actionPrefix .. "resolveban"
											) .. "||" .. args[1][1],
										},
									},
									selectable = true,
								}
								else nil,
						}
					),

					MainSize = Vector2.new(400, 300),
					MinimumSize = Vector2.new(350, 300),
				})
			end,
		},

		addNoteToBanCase = {
			Prefix = settings.actionPrefix,
			Aliases = { "addnotetobancase" },
			Arguments = {
				{
					argument = "caseId",
					stringPattern = "^([S%-]*%w+)$",
					required = true,
					private = true,
				},
				{
					argument = "reason",
					required = true,
					filter = true,
					requireSafeString = true,
					private = true,
				},
			},
			Permissions = { "Ban_Player" },
			Roles = {},
			CrossCooldown = 10,
			ServerCooldown = 15,

			Description = "Adds a note to a ban case",

			Function = function(plr, args)
				if args[1][1]:sub(1, 2):lower() == `l-` then
					plr:sendData(
						"SendMessage",
						`Looking up legacy bans (pseudo ban case ids starting with <b>L-</b>) are not possible for lookups.`,
						nil,
						10,
						"Context"
					)
					return
				end

				local banCase = if #args[1][1] == 0 then nil else Moderation.getBanCase(args[1][1])
				if not banCase or banCase.status == `inactive` then
					plr:makeUI("NotificationV2", {
						title = "Ban Management Error",
						desc = `Case Id {args[1][1]} doesn't exist`,
					})
					return
				end

				Moderation.addNoteToBanCase(args[1][1], plr:toStringDisplay() .. ": " .. args[2]:sub(1, 150))
				plr:sendData("SendMessage", `Added a note to ban case {args[1][1]}`, nil, 5, "Context")
			end,
		},

		remNoteFromBanCase = {
			Prefix = settings.actionPrefix,
			Aliases = { "remnotefrombancase" },
			Arguments = {
				{
					argument = "caseId",
					stringPattern = "^([S%-]*%w+)$",
					required = true,
					private = true,
				},
				{
					argument = "noteid",
					type = "integer",
					required = true,
					private = true,
				},
			},
			Permissions = { "Ban_Player" },
			Roles = {},
			CrossCooldown = 10,
			ServerCooldown = 15,

			Description = "Removes a note from a ban case",

			Function = function(plr, args)
				if args[1][1]:sub(1, 2):lower() == `l-` then
					plr:sendData(
						"SendMessage",
						`Looking up legacy bans (pseudo ban case ids starting with <b>L-</b>) are not possible for lookups.`,
						nil,
						10,
						"Context"
					)
					return
				end

				local banCase = if #args[1][1] == 0 then nil else Moderation.getBanCase(args[1][1])
				if not banCase or banCase.status == `inactive` then
					plr:makeUI("NotificationV2", {
						title = "Ban Management Error",
						desc = `Case Id {args[1][1]} doesn't exist`,
					})
					return
				end

				Moderation.removeNoteFromBanCase(args[1][1], args[2])
				plr:sendData("SendMessage", `Removed note {args[2]} from ban case {args[1][1]}`, nil, 5, "Context")
			end,
		},

		--gameBan = {
		--	--Disabled = true;
		--	Prefix = settings.actionPrefix;
		--	Aliases = {"gameban", "adminban", "pban"};
		--	Arguments = {
		--		{
		--			type = "list";
		--			argument = "players";
		--			required = true;
		--		},
		--		{
		--			argument = "reason";
		--			filter = true;
		--		}
		--	};
		--	Permissions = {"Ban_Player"};
		--	Roles = {};

		--	Description = "Gamebans specified players with a provided reason (takes 0-30 seconds to process)";

		--	Function = function(plr, args)
		--		--local players = server.Parser:getPlayers(args[1], plr, {
		--		--	--ignorePerms = {"Ban_Player"};
		--		--	errorIfNone = true;
		--		--})

		--		local banResults = {}
		--		local playerPriority = server.Roles:getHighestPriorityFromPermission(plr, "Ban_Player")

		--		if #args[1] > 0 then
		--			plr:sendData("SendMessage", "Banning "..#args[1].." players. This may take up to 20-60 seconds depending on the process.", nil, 10, "Context")
		--			--plr:sendData("SendMessage", "Banning "..tostring(#args[1]).." players", "Please note that unbanning/banning players takes between 20-60 seconds to process.", 60, "Hint")
		--		end

		--		for i,target in pairs(args[1]) do
		--			local targetPriority = server.Roles:getHighestPriorityFromPermission(target, "Ban_Player")

		--			if playerPriority > targetPriority then
		--				table.insert(banResults, "<b>"..target.."</b>")
		--				Moderation.addBan(target, "Game", args[2], nil, {name = plr.Name; userId = plr.UserId})
		--			end
		--		end

		--		if #banResults > 0 then
		--			plr:sendData("SendMessage", "Successfully game-banned <b>"..((#banResults > 5 and #banResults.." players") or table.concat(banResults, ", ")).."</b>.", nil, 10, "Context")
		--			--plr:sendData("SendMessage", "<b>Ban Successful</b>", "Banned "..table.concat(banResults, ", ").." ("..tostring(#banResults)..")", 8, "Hint")
		--		else
		--			plr:sendData("SendMessage", "There were nobody game banned. The players listed doesn't exist or have a higher/equal priority as you.", nil, 10, "Context")
		--		end
		--	end;
		--};

		--timeBan = {
		--	Prefix = settings.actionPrefix;
		--	Aliases = {"timeban", "tempban"};
		--	Arguments = {
		--		{
		--			type = "list";
		--			argument = "players";
		--			required = true;
		--		},
		--		{
		--			argument = "duration";
		--			type = "duration";
		--			required = true;
		--		},
		--		{
		--			argument = "saveable";
		--			type = "trueOrFalse";
		--			required = true;
		--		},
		--		{
		--			argument = "reason";
		--		},
		--	};
		--	Permissions = {"Ban_Player"};
		--	Roles = {};

		--	Description = "Server/game temporary bans specified players for a specific duration with a provided reason";

		--	Function = function(plr, args)
		--		--local players = server.Parser:getPlayers(args[1], plr, {
		--		--	--ignorePerms = {"Ban_Player"};
		--		--})

		--		local banResults = {}
		--		local playerPriority = server.Roles:getHighestPriorityFromPermission(plr, "Ban_Player")
		--		local banExpireOs = os.time()+args[2].total

		--		if #args[1] > 0 then
		--			plr:sendData("SendMessage", "Banning "..#args[1].." players. This may take up to 10-30 seconds depending on the process.", nil, 10, "Context")
		--		end

		--		for i,target in pairs(args[1]) do
		--			local targetPriority = server.Roles:getHighestPriorityFromPermission(target, "Ban_Player")

		--			if playerPriority > targetPriority then
		--				table.insert(banResults, "<b>"..target.."</b>")
		--				Moderation.addBan(target, "Time", args[4], nil, {name = plr.Name; userId = plr.UserId}, banExpireOs, args[3])
		--			end
		--		end

		--		if #banResults > 0 then
		--			local banDueDate = `<u>\{\{t:{banExpireOs}\}\} (\{\{t:{banExpireOs}:rt}\}\})</u>`
		--			plr:sendData("SendMessage", `Successfully time-banned <b>{((#banResults > 5 and #banResults.." players") or table.concat(banResults, ", "))}</b> until {banDueDate}`, nil, 10, "Context")
		--			--plr:sendData("SendMessage", "<b>Ban Successful</b>", "Banned "..table.concat(banResults, ", ").." ("..tostring(#banResults)..")", 8, "Hint")
		--		else
		--			plr:sendData("SendMessage", "There were nobody time banned. The players listed doesn't exist or have a higher/equal priority as you.", nil, 10, "Context")
		--		end
		--	end;
		--};

		--systemBan = {
		--	Disabled = true;

		--	Prefix = settings.actionPrefix;
		--	Aliases = {"systemBan"};
		--	Arguments = {
		--		{
		--			argument = "players";
		--			type = "list";
		--			required = true;
		--		},
		--		{
		--			argument = "banType";
		--			required = true;
		--		},
		--		{
		--			argument = "duration";
		--			type = "duration";
		--		},
		--		--{
		--		--	argument = "doSave (true/false)";
		--		--	type = "trueOrFalse";
		--		--},
		--	};
		--	Permissions = {};
		--	Roles = {};

		--	Function = function(plr, args)
		--		local players = args[1]

		--		local banResults = {}

		--		for i,target in pairs(players) do
		--			local targetUserId = service.playerIdFromName(target)
		--			local banCheck = Moderation.checkBan({UserId = targetUserId})

		--			if not banCheck then
		--				--(name, banType, reason, registered, moderator, expireTime, save, contents)
		--				Moderation.addBan(target, args[2], "system banned by "..plr.Name, nil, nil, args[3])
		--				table.insert(banResults, target)
		--			end
		--		end

		--		if #banResults > 0 then
		--			plr:sendData("SendMessage", "Successfully banned", "("..(#banResults).." players) "..table.concat(banResults, ", ")..".", 5, "Hint")
		--		end
		--	end;
		--};

		unBan = {
			Prefix = settings.actionPrefix,
			Aliases = { "legacy-unban" },
			Arguments = {
				{
					argument = "players",
					type = "list",
					required = true,
				},
				{
					argument = "banType (Server/Time/Game/Force)",
				},
			},
			Permissions = { "Manage_Bans" },
			Roles = {},

			Description = "Unbans specified players (Game: Delete all ban entries from the specified players | Takes within 3 minutes to remove their game ban !!)",

			Function = function(plr, args)
				local players = args[1]

				local unbanResults = {}

				local checkConfirm = plr:makeUIGet("Confirmation", {
					title = "Unban Confirmation",
					desc = "Are you sure you want to unban "
						.. tostring(table.concat(players, ", ") .. "?\n<b>The action cannot be permanently undone.</b>"),
					choiceA = "Yes, I confirm.",
					returnOutput = true,
					time = 10,
				})

				if checkConfirm ~= 1 then return end

				if #players > 0 then
					plr:sendData("SendMessage", "Unbanning " .. #players .. " players. Please wait.", nil, 5, "Context")
					--plr:sendData("SendMessage", "Unbanning "..tostring(#players).." players", "Please note that unbanning/banning players takes between 0-3 minutes to process.", 60, "Hint")
				end

				for i, target in pairs(players) do
					local targetUserId = service.playerIdFromName(target)
					local removedBan =
						Moderation.removeBan(targetUserId, args[2], { name = plr.Name, userId = plr.UserId })

					if removedBan then table.insert(unbanResults, target) end
				end

				if #unbanResults > 0 then
					plr:sendData(
						"SendMessage",
						"Successfully unbanned "
							.. ((#unbanResults > 5 and #unbanResults .. " players") or table.concat(unbanResults, ", "))
							.. ".",
						nil,
						10,
						"Context"
					)
					--plr:sendData("SendMessage", "Successfully unbanned", "("..(#unbanResults).." players) "..table.concat(unbanResults, ", ")..".", 5, "Hint")
				else
					plr:sendData(
						"SendMessage",
						"There were nobody unbanned. The players listed are already unbanned from the specified ban type.",
						nil,
						4,
						"Context"
					)
				end
			end,
		},

		legacy_checkBan = {
			Prefix = settings.actionPrefix,
			Aliases = { "legacy-checkban" },
			Arguments = {
				{
					argument = "playerName",
					required = true,
				},
			},
			Permissions = { "Manage_Bans" },
			Roles = {},

			Description = "[LEGACY] Checks whether they've been banned or not.",
			PlayerCooldown = 2,

			Function = function(plr, args)
				local targetUserId = service.playerIdFromName(args[1]) or 0
				local banCheck, banInfo, settingBan = Moderation.checkBan { UserId = targetUserId }

				if not banCheck and targetUserId > 0 then
					plr:sendData("SendMessage", "Ban status", "Player " .. args[1] .. " is not banned", 6, "Hint")
				elseif banCheck then
					if not banInfo then
						plr:sendData(
							"SendMessage",
							"Ban status",
							"Player " .. args[1] .. " is banned, but doesn't have any information.",
							6,
							"Hint"
						)
					else
						local messageInfo = {}

						if settingBan then
							table.insert(messageInfo, "Moderator: <b>DEVELOPER</b>")
							table.insert(messageInfo, "Reason: <i>Marked via developer setting. No reason listed.</i>")
						else
							table.insert(
								messageInfo,
								"Moderator: "
									.. banInfo.moderator.name
									.. " (<b>"
									.. banInfo.moderator.userid
									.. "</b>)"
							)
							table.insert(messageInfo, "-----")
							table.insert(messageInfo, "Registered: <b>" .. Parser:osDate(banInfo.registered) .. "</b>")
							table.insert(
								messageInfo,
								"Expire Os: "
									.. (
										banInfo.expireTime and Parser:osDate(banInfo.expireTime)
										or "<font color='#e64940'>N/A</font>"
									)
							)
							table.insert(messageInfo, "-----")
							table.insert(messageInfo, "Type: " .. banInfo.type)
							table.insert(messageInfo, "-----")
							table.insert(messageInfo, "Reason: " .. tostring(banInfo.reason or "-undefined-"))
							table.insert(messageInfo, "-----")
							table.insert(messageInfo, "Id: " .. tostring(banInfo.id or "-no id available-"))
						end

						plr:sendData(
							"SendMessage",
							"Ban Information for " .. args[1],
							table.concat(messageInfo, "\n"),
							30
						)
					end
				end
			end,
		},

		--syncedBansList = {
		--	Prefix = settings.actionPrefix;
		--	Aliases = {"banlist", "bans", "banland"};
		--	Arguments = {};
		--	Permissions = {"Ban_Player"};
		--	Roles = {};

		--	Description = "Shows a list of server and game banned players";
		--	PlayerCooldown = 10;

		--	Function = function(plr, args)
		--		local serverBans = {}

		--		table.insert(serverBans, {
		--			type = "Label";
		--			label = `<b>Server</b>:`;
		--			richText = true;
		--		})

		--		if #Moderation.serverBans > 0 then
		--			for i,banInfo in pairs(Moderation.serverBans) do
		--				table.insert(serverBans, {
		--					type = "Log";
		--					title = `{tostring(banInfo.moderator.name)} ({banInfo.moderator.userid}) -> {service.playerNameFromId(banInfo.offender.userid)}`;
		--					desc = `<b>Reason</b>: {Parser:filterForRichText(banInfo.reason)}`;
		--					richText = true;
		--					sentOs = banInfo.expireTime or banInfo.registered;
		--					showDateAndTime = true;
		--				})
		--			end
		--		else
		--			table.insert(serverBans, {
		--				type = "Label";
		--				label = `There are no players banned in the server`;
		--				richText = true;
		--			})
		--		end

		--		table.insert(serverBans, {
		--			type = "Label";
		--			label = `<i>----------</i>`;
		--			richText = true;
		--		})

		--		table.insert(serverBans, {
		--			type = "Label";
		--			label = `<b>Global</b>`;
		--			richText = true;
		--		})
		--		local globalBans = Moderation.globalBanCasesList

		--		local checkList = {}
		--		for i,banInfo in pairs(globalBans) do
		--			if type(banInfo) == "table" then
		--				local expiredBan = false

		--				local offenderD = banInfo.offender
		--				local moderatorD = banInfo.moderator

		--				if banInfo.type == "Time" then
		--					if banInfo.expireTime-os.time() <= 0 then
		--						expiredBan = true
		--						Datastore.tableRemove(nil, "Banlist", "entryFromId", banInfo.id or -1)
		--					end
		--				end

		--				if not Moderation.checkBan({Name = offenderD.name; UserId = offenderD.userid;}, true) then
		--					Datastore.tableRemove(nil, "Banlist", "entryFromId", banInfo.id or -1)
		--					expiredBan = true
		--				end

		--				if not checkList[offenderD.userid] then
		--					checkList[offenderD.userid] = true

		--					table.insert(serverBans, {
		--						type = "Log";
		--						title = `{tostring(banInfo.moderator.name)} ({banInfo.moderator.userid}) -> {service.playerNameFromId(banInfo.offender.userid)}`;
		--						desc = `<i>Reason</i>: {Parser:filterForRichText(banInfo.reason)}`;
		--						titleColor = if expiredBan then Color3.fromRGB(159, 159, 159) else nil;
		--						richText = true;
		--						sentOs = banInfo.expireTime or banInfo.registered;
		--						showDateAndTime = true;
		--					})

		--					--table.insert(serverBans, {
		--					--	Text = "["..banInfo.type.."] "..banInfo.offender.name.." ("..banInfo.offender.userid..") | Moderator: "..tostring(banInfo.moderator.name);
		--					--	Desc = "Saved: Yes | ExpireTime: "..tostring(banInfo.expireTime or "n/a").." | Reason: "..banInfo.reason;
		--					--	Color =
		--					--})
		--				else
		--					Datastore.tableRemove(nil, "Banlist", "entryFromId", banInfo.id or -1)
		--				end
		--			end
		--		end

		--		plr:makeUI("List", {
		--			Title = "E. Ban Land";
		--			List = serverBans;
		--			MainSize = Vector2.new(290, 280);
		--			MinimumSize = Vector2.new(290, 280);
		--		})
		--	end;
		--};

		manageGameServers = {
			Prefix = settings.actionPrefix,
			Aliases = { "gameservers" },
			Arguments = {},
			Permissions = { "Manage_Game_Servers" },
			Roles = {},
			PlayerDebounce = true,
			Description = "Shows a list of servers to manage",

			Function = function(plr, args)
				plr:sendData(
					"SendMessage",
					"Game servers management",
					"Retrieving list of servers. This will take up to 15 seconds.",
					15,
					"Hint"
				)
				local serversList = Core.getGameServers()
				if type(serversList) ~= "table" then serversList = {} end

				if #serversList == 0 then
					plr:sendData("SendMessage", "Game servers management", "There's no servers to manage", 4, "Hint")
					return
				end

				local manageGSSession = plr:getVar "ManageServersSession"
				local viewServerEvent
				local shutdownServerEvent

				if not manageGSSession then
					manageGSSession = Remote.newSession()
					manageGSSession.connectedPlayers[plr] = true

					local sessionRL = {
						Rates = 20,
						Reset = 10,
					}

					shutdownServerEvent = manageGSSession:makeEvent "ShutdownServer"
					shutdownServerEvent.connectedPlayers = manageGSSession.connectedPlayers
					shutdownServerEvent._event:Connect(function(caller, chosenServerId)
						if
							caller == plr
							and Roles:hasPermissionFromMember(plr, { "Manage_Game_Servers" })
							and server.Utility:checkRate(sessionRL, caller.UserId)
							and type(chosenServerId) == "string"
						then
							plr:sendData(
								"SendMessage",
								"Game servers management",
								"Attempting to shutdown " .. chosenServerId .. ". This may take up to 15 seconds.",
								18,
								"Hint"
							)

							local serversList = Core.getGameServers()
							if type(serversList) ~= "table" then serversList = {} end

							local didShutdown = false
							local playerDisplayName = plr:toStringPublicDisplay()

							for i, serverInfo in pairs(serversList) do
								if type(serverInfo) == "table" then
									local serverId = (serverInfo.private and serverInfo.privateId) or serverInfo.id

									if serverId and serverId == chosenServerId and not serverInfo.studio then
										Cross.sendToSpecificServers(
											{ serverId },
											"Shutdown",
											"Requested by " .. playerDisplayName,
											2,
											plr.UserId
										)
										plr:sendData(
											"SendMessage",
											"Cross shutdown command sent!",
											"Shutting down game server <b>" .. serverId .. "</b>",
											10,
											"Hint"
										)
										Logs.addLog("Admin", {
											title = plr.Name .. " sent a cross request to server " .. tostring(
												serverId
											) .. " for shutdown",
											desc = "Sent command to shutdown server",
										})
										didShutdown = true
										break
									end
								end
							end

							if not didShutdown then
								plr:sendData(
									"SendMessage",
									"Cross shutdown command failed to send.",
									"There was no server with id " .. chosenServerId .. " to shutdown.",
									4,
									"Hint"
								)
							end
						end
					end)

					viewServerEvent = manageGSSession:makeEvent "ViewServer"
					viewServerEvent.connectedPlayers = manageGSSession.connectedPlayers
					viewServerEvent._event:Connect(function(caller, chosenServerId)
						if
							caller == plr
							and Roles:hasPermissionFromMember(plr, { "Manage_Game_Servers" })
							and server.Utility:checkRate(sessionRL, caller.UserId)
							and type(chosenServerId) == "string"
						then
							local serversList = Core.getGameServers()
							if type(serversList) ~= "table" then serversList = {} end

							local foundServer
							for i, serverInfo in pairs(serversList) do
								if type(serverInfo) == "table" then
									local serverId = (serverInfo.private and serverInfo.privateId) or serverInfo.id

									if serverId and serverId == chosenServerId then
										foundServer = serverInfo
										break
									end
								end
							end

							if foundServer then
								local serverId = (foundServer.private and foundServer.privateId) or foundServer.id
								plr:makeUI("List", {
									Title = `Server Management - {serverId}`,
									MainSize = Vector2.new(500, 150),
									MinimumSize = Vector2.new(350, 250),
									List = {
										{
											type = "Label",
											label = `Created on \{\{t:{foundServer.started}\}\}`,
											specialMarkdownSupported = true,
										},
										{
											type = "Label",
											label = `Server Type: <b>{tostring(
												foundServer.type
											)}</b>`,
											richText = true,
											selectable = true,
										},
										{
											type = "Label",
											label = `Id: <b>{tostring(
												(foundServer.private and foundServer.privateId)
														or tostring(foundServer.id)
											)}</b>`,
											richText = true,
											selectable = true,
										},
										{
											type = "Action",
											label = ``,

											options = {
												{
													label = "Shutdown",
													labelColor = Color3.fromRGB(196, 58, 58),
													onExecute = `sessionevent://main:{manageGSSession.id}-{shutdownServerEvent.id}||{server.LuaParser.Encode {
														serverId
													}}`,
												},
											},
										},
									},
								})
							end
						end
					end)

					plr:setVar("ManageServersSession", manageGSSession)
				else
					shutdownServerEvent = manageGSSession:findEvent "ShutdownServer"
					viewServerEvent = manageGSSession:findEvent "ViewServer"
				end

				local tabList = {}

				for i, serverInfo in pairs(serversList) do
					if type(serverInfo) == "table" then
						local timeData = server.Parser:getTime(serverInfo.started)
						local formatTime = server.Parser:formatTime(timeData.hours, timeData.mins, timeData.secs)
						local serverId = (serverInfo.private and serverInfo.privateId) or serverInfo.id
						local isCurrentServer = (
							#game.PrivateServerId > 0 and variables.serverInfo.privateId == serverId
						) or variables.serverInfo.id == serverId

						table.insert(tabList, {
							type = "Action",
							label = (isCurrentServer and "🔸 ")
							or ""
								.. "["
								.. formatTime
								.. "] "
								.. (serverInfo.studio and "[studio server]" or serverId),

							optionsLayoutStyle = "Log",
							options = {
								{
									label = "View",
									onExecute = `sessionevent://main:{manageGSSession.id}-{viewServerEvent.id}||{server.LuaParser.Encode {
										serverId
									}}`,
								},
								{
									label = "Shutdown",
									labelColor = Color3.fromRGB(196, 58, 58),
									onExecute = `sessionevent://main:{manageGSSession.id}-{shutdownServerEvent.id}||{server.LuaParser.Encode {
										serverId
									}}`,
								},
							},
						})
					end
				end

				plr:makeUI("List", {
					Title = `Game Servers`,
					MainSize = Vector2.new(500, 400),
					MinimumSize = Vector2.new(350, 210),
					List = tabList
				})
			end,
		},

		disableCommands = {
			Prefix = settings.actionPrefix,
			Aliases = { "disablecommands" },
			Arguments = {
				{
					type = "list",
					argument = "commands",
					required = true,
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},
			NoDisableAndEnable = true,

			Description = "Disable specified commands",

			Function = function(plr, args)
				local failedCmds = {}
				local successCmds = {}
				local delimiter = settings.delimiter

				for i, segment in pairs(args[1]) do
					local foundCmd, cmdMatch = Cmds.get(segment)

					if foundCmd and (not foundCmd.Disabled and not foundCmd.NoDisableAndEnable) then
						table.insert(successCmds, cmdMatch)
						foundCmd.Disabled = true
					else
						table.insert(failedCmds, segment)
					end
				end

				if #failedCmds > 0 then
					local failCount = service.tableCount(failedCmds)
					plr:sendData(
						"SendMessage",
						"Command Management failed",
						"Failed to disable " .. failCount .. " cmds such as " .. table.concat(failedCmds, ", ") .. ".",
						3,
						"Hint"
					)
					wait(3)
				end

				local successCount = service.tableCount(successCmds)
				if successCount > 0 then
					plr:sendData(
						"SendMessage",
						"Command Management success",
						"Disabled " .. successCount .. " cmds such as " .. table.concat(successCmds, ", ") .. ".",
						5,
						"Hint"
					)
				end
			end,
		},

		enableCommands = {
			Prefix = settings.actionPrefix,
			Aliases = { "enablecommands" },
			Arguments = {
				{
					type = "list",
					argument = "commands",
					required = true,
				},
			},
			Permissions = { "Manage_Game" },
			Roles = {},
			NoDisableAndEnable = true,

			Description = "Enable specified commands",

			Function = function(plr, args)
				local failedCmds = {}
				local successCmds = {}
				local delimiter = settings.delimiter

				for i, segment in pairs(args[1]) do
					local foundCmd, cmdMatch = Cmds.get(segment)

					if foundCmd and (foundCmd.Disabled and not foundCmd.NoDisableAndEnable) then
						table.insert(successCmds, cmdMatch)
						foundCmd.Disabled = false
					else
						table.insert(failedCmds, segment)
					end
				end

				if #failedCmds > 0 then
					local failCount = service.tableCount(failedCmds)
					plr:sendData(
						"SendMessage",
						"Command Management failed",
						"Failed to enable " .. failCount .. " cmds such as " .. table.concat(failedCmds, ", ") .. ".",
						3,
						"Hint"
					)
					wait(3)
				end

				local successCount = service.tableCount(successCmds)
				if successCount > 0 then
					plr:sendData(
						"SendMessage",
						"Command Management success",
						"Enabled " .. successCount .. " cmds such as " .. table.concat(successCmds, ", ") .. ".",
						5,
						"Hint"
					)
				end
			end,
		},

		-- Prompt dev commands
		promptPremium = {
			Prefix = settings.actionPrefix,
			Aliases = { "promptpremium" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "PromptDev_Commands" },
			Roles = {},

			Description = "Prompts the specified players to purchase Roblox premium",
			PlayerCooldown = 5,

			Function = function(plr, args)
				for i, target in ipairs(args[1]) do
					service.MarketplaceService:PromptPremiumPurchase(target._object)
				end
			end,
		},

		promptProductPurchase = {
			Prefix = settings.actionPrefix,
			Aliases = { "promptproduct" },
			Arguments = {
				{
					argument = "productId",
					type = "integer",
					required = true,
				},
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "PromptDev_Commands" },
			Roles = {},

			Description = "Prompts the specified players to purchase a developer product (Dev products are not available in the player's inventory)",
			PlayerCooldown = 5,

			Function = function(plr, args)
				local productId: number = args[1]
				local productInfo: { [any]: any } = service.getProductInfo(productId, Enum.InfoType.Product)

				if not productInfo or not productInfo.Created then
					plr:sendData("SendMessage", "Product <b>" .. productId .. "</b> doesn't exist", nil, 5, "Context")
					return
				elseif not productInfo.CanBeSoldInThisGame then
					plr:sendData(
						"SendMessage",
						"Product <b>" .. productId .. "</b> cannot be sold in the game",
						nil,
						5,
						"Context"
					)
					return
				end

				for i, target in ipairs(args[1]) do
					service.MarketplaceService:PromptProductPurchase(target._object, productId)
				end
			end,
		},

		promptGamePassPurchase = {
			Prefix = settings.actionPrefix,
			Aliases = { "promptgamepass" },
			Arguments = {
				{
					argument = "gamepassId",
					type = "integer",
					required = true,
				},
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "PromptDev_Commands" },
			Roles = {},

			Description = "Prompts the specified players to purchase a developer gamepass",
			PlayerCooldown = 5,

			Function = function(plr, args)
				local productId: number = args[1]
				local productInfo: { [any]: any } = service.getProductInfo(productId, Enum.InfoType.GamePass)

				if not productInfo or not productInfo.Created then
					plr:sendData("SendMessage", "GamePass <b>" .. productId .. "</b> doesn't exist", nil, 5, "Context")
					return
				elseif not productInfo.CanBeSoldInThisGame or not productInfo.IsForSale then
					plr:sendData(
						"SendMessage",
						"GamePass <b>" .. productId .. "</b> cannot be sold in the game nor available for sale",
						nil,
						5,
						"Context"
					)
					return
				end

				local productCreatorUserId = (
					productInfo.CreatorType == Enum.CreatorType.User and productInfo.Creator.CreatorTargetId
				)
					or (productInfo.CreatorType == Enum.CreatorType.Group and service.getGroupCreatorId(
						productInfo.Creator.CreatorTargetId
					))
					or 0
				local inGameCreatorId = (
					game.CreatorType == Enum.CreatorType.Group and service.getGroupCreatorId(game.CreatorId)
				) or game.CreatorId

				local warnIfSomeoneHasOwnedThePass = false

				for i, target in ipairs(args[1]) do
					if service.checkPassOwnership(target.UserId, productId) then
						warnIfSomeoneHasOwnedThePass = true
						continue
					end
					local playerDisplayName = plr:toStringDisplayForPlayer(target)

					if productCreatorUserId ~= inGameCreatorId and target.UserId ~= plr.UserId then
						Remote.privateMessage {
							receiver = plr,
							sender = nil,
							topic = "Third party purchase notice",
							message = `You are prompted by <b>{playerDisplayName}</b> to purchase a third-party item, not owned by the game creator.`
								.. ` If you believe this asset <b>doesn't belong to the game</b>, you can ask the game developer to turn off third-party sales.`,
							notifyOpts = { title = "Purchase notice", desc = "Read to view" },
							expireOs = os.time() + 120,
						}
					end
					service.MarketplaceService:PromptGamePassPurchase(target._object, productId)
				end

				if warnIfSomeoneHasOwnedThePass then
					plr:sendData(
						"SendMessage",
						"Some or more players you specified didn't receive the prompt because they already owned the game pass",
						nil,
						5,
						"Context"
					)
				end
			end,
		},

		promptAssetPurchase = {
			Prefix = settings.actionPrefix,
			Aliases = { "promptasset" },
			Arguments = {
				{
					argument = "assetId",
					type = "integer",
					required = true,
				},
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "PromptDev_Commands" },
			Roles = {},

			Description = "Prompts the specified players to purchase a developer asset",
			PlayerCooldown = 5,

			Function = function(plr, args)
				local productId: number = args[1]
				local productInfo: { [any]: any } = service.getProductInfo(productId, Enum.InfoType.Asset)

				if not productInfo or not productInfo.Created then
					plr:sendData("SendMessage", "Asset <b>" .. productId .. "</b> doesn't exist", nil, 5, "Context")
					return
				elseif not productInfo.CanBeSoldInThisGame or not productInfo.IsForSale then
					plr:sendData(
						"SendMessage",
						"Asset <b>" .. productId .. "</b> cannot be sold in the game nor available for sale",
						nil,
						5,
						"Context"
					)
					return
				end

				local productCreatorUserId = (
					productInfo.CreatorType == Enum.CreatorType.User and productInfo.Creator.CreatorTargetId
				)
					or (productInfo.CreatorType == Enum.CreatorType.Group and service.getGroupCreatorId(
						productInfo.Creator.CreatorTargetId
					))
					or 0
				local inGameCreatorId = (
					game.CreatorType == Enum.CreatorType.Group and service.getGroupCreatorId(game.CreatorId)
				) or game.CreatorId

				local warnIfSomeoneHasOwnedTheAsset = false

				for i, target in ipairs(args[1]) do
					if service.checkAssetOwnership(target, productId) then
						warnIfSomeoneHasOwnedTheAsset = true
						continue
					end
					local playerDisplayName = plr:toStringDisplayForPlayer(target)
					if productCreatorUserId ~= inGameCreatorId and target.UserId ~= plr.UserId then
						Remote.privateMessage {
							receiver = plr,
							sender = nil,
							topic = "Third party purchase notice",
							message = `You are prompted by <b>{playerDisplayName}</b> to purchase a third-party item, not owned by the game creator.`
								.. ` If you believe this asset <b>doesn't belong to the game</b>, you can ask the game developer to turn off third-party sales.`,
							notifyOpts = { title = "Purchase notice", desc = "Read to view" },
							expireOs = os.time() + 120,
						}
					end
					service.MarketplaceService:PromptAssetPurchase(target._object, productId)
				end

				if warnIfSomeoneHasOwnedTheAsset then
					plr:sendData(
						"SendMessage",
						"Some or more players you specified didn't receive the prompt because they already owned the asset",
						nil,
						5,
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
