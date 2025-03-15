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
	local Parser = server.Parser
	local Process = server.Process
	local Remote = server.Remote
	local Roles = server.Roles
	local Utility = server.Utility

	local cmdsList = {
		rejoin = {
			Prefix = settings.playerPrefix,
			Aliases = { "rejoin" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Rejoins the current server",
			PlayerDebounce = true,

			Function = function(plr, args)
				if service.RunService:IsStudio() or (not variables.privateServerData and #game.PrivateServerId > 0) then
					plr:sendData(
						"SendMessage",
						"Teleportation Error",
						"Unable to rejoin due to private or studio server you are currently in",
						300,
						"Hint"
					)
					return
				end

				service.debounce("Rejoin server - " .. plr.playerId, function()
					local privateServerData = variables.privateServerData
					local failSignal = server.Signal.new()
					local function errCallback(errType)
						plr:sendData(
							"SendMessage",
							"Teleportation Error",
							"Failed to rejoin the server. Please try again later!",
							6,
							"Hint"
						)
					end

					if privateServerData then
						plr:teleportToReserveWithSignature(privateServerData.details.serverAccessId, errCallback)
					else
						plr:teleportToServer(game.JobId, errCallback)
					end

					local failSignal = server.Signal.new()
					local didFail = server.Signal:waitOnSingleEvents({ failSignal, plr.disconnected }, nil, 180)

					if didFail then
						plr:sendData(
							"SendMessage",
							"Teleportation Error",
							"Failed to rejoin the server. Please try again later!",
							6,
							"Hint"
						)
					end
				end)
			end,
		},

		nowPlaying = {
			Disabled = not settings.musicPlayer_Enabled,
			Prefix = settings.playerPrefix,
			Aliases = { "nowplaying" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "[WORKS IF THERE'S MUSIC NOW PLAYING] Shows the on going music with details",

			PlayerCooldown = 1,
			Function = function(plr, args)
				local mainSound = server.Utility:getMainSound()
				local musicStat = "playing"

				if mainSound then
					if mainSound.IsLoaded and mainSound.IsPaused then
						musicStat = "paused"
					elseif not mainSound.IsPlaying then
						musicStat = "stopped"
					end
					local timeLapData = server.Parser:getTime(mainSound.TimePosition)
					local timelapse = server.Parser:formatTime(timeLapData.hours, timeLapData.mins, timeLapData.secs)

					local timeLenData = server.Parser:getTime(mainSound.TimeLength)
					local timelength = server.Parser:formatTime(timeLenData.hours, timeLenData.mins, timeLenData.secs)

					plr:sendData(
						"SendMessage",
						"Now playing",
						tostring(variables.music_nowPlaying_name)
							.. " ("
							.. tostring(variables.music_nowPlaying_id)
							.. ") | <b>"
							.. timelapse
							.. " - "
							.. timelength
							.. "</b> | ("
							.. musicStat
							.. ")",
						15,
						"Hint"
					)
				end
			end,
		},

		getSound = {
			Disabled = not settings.musicPlayer_Enabled,
			Prefix = settings.playerPrefix,
			Aliases = { "getsound" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "[WORKS IF THERE'S MUSIC PLAYING] Prompts music asset purchase by Roblox",

			Function = function(plr, args)
				if variables.music_nowPlaying_id > 0 then
					service.Marketplace:PromptPurchase(plr._object, variables.music_nowPlaying_id)
				end
			end,
		},

		ping = {
			Prefix = settings.playerPrefix,
			Aliases = { "ping" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Provides details of your ping to Essential network",
			PlayerDebounce = true,
			PlayerCooldown = 5,

			Function = function(plr, args)
				plr:sendData(
					"SendMessage",
					"Generating a ping diagnotic report. This may take a while.",
					nil,
					10,
					"Context"
				)

				local started = os.time()
				local robloxPingMs = service.roundNumber(plr:GetNetworkPing(), 0.001)
				local essPingMs

				for i = 1, math.random(4, 6) do
					essPingMs = plr:getPing()
					wait(math.random(0.1, 0.4))
				end

				local robloxPingInfo = "no information"
				local essPingInfo = "unknown"

				if robloxPingMs >= 0 and robloxPingMs < 20 then
					robloxPingInfo =
						"Your roblox ping is <b>excellent</b>. It can handle high-performance physics and lagless interactions."
				elseif robloxPingMs >= 20 and robloxPingMs < 50 then
					robloxPingInfo =
						"Your roblox ping is <b>good</b>. It's stable enough to handle decent physics and invoke interactions smoothly."
				elseif robloxPingMs >= 50 and robloxPingMs < 80 then
					robloxPingInfo =
						[[Your roblox ping is <b>okay</b>. It's okay to handle some physics and invoke remote objects with a short delay.
						Expect an increase amount of delay if there are multiple in-game physics running at the same time. High-performance scripts
						could also affect the in-game's engine.
					]]
				else
					robloxPingInfo =
						[[Your roblox ping is <b>poor</b>. You may expect large amount of delay while interacting with physics and objects.
						If your wifi connection is good between Roblox and you, it's possible that the game server is having difficulties handling the physics
						and scripts. This is most likely due to scripts using a poor system to degrade the game server's performance.
					]]
				end

				if essPingMs >= 0 and essPingMs < 20 then
					essPingInfo = "Excellent"
				elseif essPingMs >= 20 and essPingMs < 50 then
					essPingInfo = "Good"
				elseif essPingMs >= 50 and essPingMs < 80 then
					essPingInfo = "Okay"
				else
					essPingInfo = "Bad"
				end

				local pingReport = {
					"Diagnostic started: <b>" .. server.Parser:osDate(started) .. " UTC</b>",
					"",
					"<b>Roblox ping:</b> " .. tostring(robloxPingMs) .. "ms",
					"<i>" .. robloxPingInfo .. "</i>",
					"",
					"<b>Essential network ping:</b> " .. tostring(essPingMs) .. "ms",
					"<i>Status: " .. essPingInfo .. "</i>",
				}

				plr:makeUI("PrivateMessageV2", {
					title = "Ping diagnostic report",
					desc = "This is a diagnostic report about the ping you sent between you, Roblox server & Essential network.",
					message = table.concat(pingReport, "\n"),
					readOnly = true,
				})
			end,
		},

		serverInfo = {
			Prefix = settings.playerPrefix,
			Aliases = { "serverinfo" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Provides details of the current server",

			Function = function(plr, args)
				local serverInfo = variables.serverInfo
				local timeData = server.Parser:getTime(serverInfo.started)
				local formatTime = server.Parser:formatTime(timeData.hours, timeData.mins, timeData.secs)
				local serverId = (serverInfo.private and serverInfo.privateId) or serverInfo.id

				local serverReport = {
					"Id: <b>" .. serverId .. "</b>",
					"Type: <b>" .. tostring(serverInfo.type) .. "</b>",
					"Started since " .. tostring(server.Parser:osDate(serverInfo.started)),
				}

				plr:sendData("SendMessage", "Server information", table.concat(serverReport, " | "), 20, "Hint")
			end,
		},

		openNotepad = {
			Prefix = settings.playerPrefix,
			Aliases = { "notepad" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Opens notepad",

			Function = function(plr, args)
				plr:makeUI("ResponseEntry", {
					resizeEnabled = true,
					title = "🖋️📒 Notepad",
				})
			end,
		},

		openChangelog = {
			Prefix = settings.playerPrefix,
			Aliases = { "changelog" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Views changelog",

			Function = function(plr, args)
				local changelog = require(server.Assets.Changelog)
				local lastUpdated, updateDuration, updateVers, updateInfo =
					changelog.lastUpdated, changelog.updateDuration, changelog.updateVers, changelog.updateInformation

				plr:makeUI("PrivateMessageV2", {
					title = "Essential Changelogs",
					desc = "Latest information of Essential <i>(latest version: v" .. updateVers .. ")</i>",
					message = server.Parser:replaceStringWithDictionary(table.concat(updateInfo, "\n"), {
						["{$selfprefix}"] = settings.playerPrefix,
						["{$actionprefix}"] = settings.actionPrefix,
						["{$delimiter}"] = settings.delimiter,
						["{$batchSeperator}"] = settings.batchSeperator,
					}),
					readOnly = true,
				})
			end,
		},

		openCredits = {
			Prefix = settings.playerPrefix,
			Aliases = { "credits", "attributions" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Views the credits and attributions of Essential",

			Function = function(plr, args)
				local credits = require(server.Assets.Credits)

				plr:makeUI("PrivateMessageV2", {
					title = "Essential Credits & Attributions",
					desc = "Latest credits information of Essential",
					message = server.Parser:replaceStringWithDictionary(table.concat(credits, "\n"), {
						["{$selfprefix}"] = settings.playerPrefix,
						["{$actionprefix}"] = settings.actionPrefix,
						["{$delimiter}"] = settings.delimiter,
						["{$batchSeperator}"] = settings.batchSeperator,
					}),
					readOnly = true,
				})
			end,
		},

		openUsage = {
			Prefix = "",
			Aliases = { settings.playerPrefix .. "usage", "!usage" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Gives a detailed information about target selectors and how to utilize Essential",

			Function = function(plr, args)
				local canUseSlashCommands = settings.chatAccess and settings.slashCommands
				local playerPrefix = Parser:filterForRichText(settings.playerPrefix)
				local actionPrefix = Parser:filterForRichText(settings.actionPrefix)
				local batchSeperator = Parser:filterForRichText(settings.batchSeperator)
				local delimiter = Parser:filterForRichText(settings.delimiter)
				local usageInfo = {
					"<b>User Interfaces</b>:",
					"Some UIs like Adonis Window have the resizable feature enabled. You can resize the UIs by dragging from the corners and edges.",
					"Be aware that not all UIs have that feature enabled. Most UIs have the draggable feature enabled, allowing you to drag the UI anywhere",
					"-on your screen.",
					"",
					"<b>Slash commands & silent commands</b>",
					"Enabled in the server: <i>" .. (canUseSlashCommands and "Yes" or "No") .. "</i>",
					"If the server has slash commands enabled, you could use the slash (/) prefix to run commands. For example, /rejoin",
					"However, slash commands aren't the only feature you could hide your command input. An alternative is /e (emote)",
					"Start with /e then your command after a space from /e (e.g. /e "
						.. playerPrefix
						.. "help). This alternative doesn't require slash commands",
					"-enabled, but it's a great feature to hide your commands. Regardless of how you interact with Roblox chat, your chat messages aren't hidden",
					"from scripts. <u>Keep in mind that slash commands are ONLY available on Roblox chat.</u>",
					"",
					"<b>Quick actions</b>",
					"ℹ️ The 'E' button on the top right of your screen is called 'Quick actions'.",
					"Quick actions are quick shortcuts navigatable in Essential utility.",
					"- Get help: <i>Notifies any available moderator to come assist you.</i>",
					"- Console bar: <i>Opens the console bar (permission required)</i>",
					"- CommandX (aka command box): <i>Opens the console box</i>",
					"- Client settings: <i>Opens the settings dashboard with general, aliases, shortcuts, & administration panel.</i>",
					"",
					"<b>Shortcuts (via client settings)</b>",
					"Shortcuts are command buttons you could use to execute commands on the topbar icon.",
					"The maximum amount of shortcuts you can have/create is " .. tostring(
						Process.playerSettingsLimits.MaxShortcutCreation
					) .. ".",
					"",
					"<b>Action aliases (formerly known as Aliases) (via client settings)</b>",
					"Action aliases are custom command aliases you could create. This idea of 'aliases' was inspired from Adonis.",
					"The maximum amount of action aliases you can have/create is " .. tostring(
						Process.playerSettingsLimits.MaxAliasCreation
					) .. ".",
					"",
					"<b>CC Aliases/Names (via client settings)</b>",
					"CC Aliases are your own aliases to refer a command. For instance, you could make an alias called 'ref' to refer "
						.. actionPrefix
						.. "refresh.",
					"Therefore, you could simply perform 'ref me'. The alias 'ref' is a replacement of the target command you specified. The maximum amount of"
						.. " aliases you can have/create is "
						.. tostring(Process.playerSettingsLimits.MaxCustomCmdNameCreation)
						.. ".",
					"",
					"<b>Target selectors (command targets)</b>",
					"admins - Selects admins (players with permission 'Manage_Game')",
					"nonadmins - Selects non-admins (players without permission 'Manage_Game')",
					"random - Selects a random from a list of in-game players",
					"friends - Selects players who are your Roblox friend (relies on friendship cache)",
					"%team_name - Selects a team with a qualifying name",
					"@user_name - Selects players with the specified username (e.g. "
						.. actionPrefix
						.. "pm @"
						.. plr.Name
						.. " false Hey, it's me!)",
					"&role_name - Selects players with the specified role name (note: The role name CANNOT be partial. You can view the roles list by "
						.. actionPrefix
						.. "roleslist)",
					"*range - Selects players within the specified radius of your character (e.g. *10 = 10 stud radius)",
					"$group_id - Selects players who are in this group",
					".display_name - Selects players with this display name (CANNOT be partial)",
					"-exemption - Deselects players who qualify this exemption (e.g. -.Slender - Deselects players who have a display name 'Slender')",
					"limit-limit_count - Limits the amount of targets you supplied in the command argument to that amount (e.g. limit-10 - Limits to 10 player targets)",
					"!partial_user_name - Selects players with a matching partial display name",
					"",
					"<i>Note: If you want to target offline players, you must use the @user_name selector. Some commands may support offline player selection while most do not.</i>",
					"",
					"<i>By default, Essential uses partial_display_name to select players without needing any of the selectors above.</i>",
					"",
					"You could supply a bunch of target selectors by putting each selector in an array/list. For example, admins,friends,*18",
					"",
					"<b>Target duplications</b>",
					"Some commands like "
						.. actionPrefix
						.. "gear allow supplying the same player twice. Therefore, the action can target them multiple times. On the other hand,",
					"not all commands allow target duplication. Parser has a setting 'noDuplicates' enabled by default if the command is parsing arguments.",
					"You can target the same player multiple times by using the same selector. For example, "
						.. actionPrefix
						.. "gear me,me,me,me,me 11419319",
					"",
					"<b>Command batches</b>",
					"ℹ️ Command batches CAN BE DISABLED via developer settings. The maximum amount of command batches is "
						.. tostring(settings.MaxBatchCommands),
					"Command batches are batches of commands supplied in a message. For example,",
					"<i>"
						.. actionPrefix
						.. "m Hey guys. Watch me do a magic trick. "
						.. batchSeperator
						.. " "
						.. actionPrefix
						.. "invisible "
						.. batchSeperator
						.. " "
						.. actionPrefix
						.. "wait5 "
						.. batchSeperator
						.. " "
						.. actionPrefix
						.. "visible</i>",
					"",
					"<b>HandTo system</b>",
					"You can send items to players closer to you. If you want to override the character proximity restriction, you must own permission `HandTo_Utility`. To use handto, do "
						.. playerPrefix
						.. "handto "
						.. Parser:filterForRichText "<player using target selectors>",
					"If you're not an in-game administrator, the receiver will receive a HandTo request from you, which they must accept in order to accept the tool transfer. Keep in mind that this must be done within a 20-stud character radius.",
					"Over 20-stud character radius will not grant the receiver for the request. The HandTo command has a 5 second player cooldown.",
					"",
					"<b>Prefix references</b>",
					"These prefixes are configured by the game developer.",
					"[ " .. playerPrefix .. " ]  Player prefix - Used for self-targeted commands",
					"[ " .. actionPrefix .. " ] Action prefix - Used for action commands",
					"[ " .. batchSeperator .. " ] Batch seperator - Used to seperate command batches",
					"[ " .. delimiter .. " ] Delimiter - Used to seperate each word in the message",
					"",
					"Batches can also have a delay command. This is referred as "
						.. playerPrefix
						.. "wait(NUMBER). Take this as a reference, "
						.. playerPrefix
						.. "wait10 - Delays the next command till 10 commands",
					"",
					"--",
					"That's all information of how you can utilize Essential. For a list of commands, do "
						.. actionPrefix
						.. "cmds",
				}

				plr:makeUI("PrivateMessageV2", {
					title = "Utility Usage",
					desc = "Latest information on target selectors and how to utilize Essential",
					message = table.concat(usageInfo, "\n"),
					readOnly = true,
				})
			end,
		},

		openPlayersList = {
			Prefix = settings.playerPrefix,
			Aliases = { "players" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Gives information about the players in the server",
			PlayerCooldown = 2,

			Function = function(plr, args)
				local tab = {}
				local players = service.getPlayers(true, true)
				local gameCreatorId = (game.CreatorType == Enum.CreatorType.User and game.CreatorId)
					or service.getGroupCreatorId(game.CreatorId)

				for i, target in ipairs(players) do
					local clientData = target:getClientData()
					local targetDisplayAndUser = tostring(target)
					local isNotMyself = target.UserId ~= plr.UserId
					local isFriends = isNotMyself and Identity.checkFriendship(plr.UserId, target.UserId)
					local isCreator = gameCreatorId == target.UserId
					local tagPrefix = (isFriends and "<font color='#51d93f'>[Friend]</font>" .. " ")
						or (isCreator and "<font color='#51d93f'>[Game Creator]</font>" .. " ")
					local deviceInfo = clientData
							and (if clientData.deviceType == "VR"
								then "📷 VR"
								elseif clientData.deviceType == "Console" then "🎮 Console"
								elseif clientData.deviceType == "Mobile" then "📱 Mobile"
								elseif clientData.deviceType == "PC" then "💻 PC"
								else "Unknown")
						or "[unknown device or hasn't loaded yet]"

					local inGameDuration = clientData and Parser:formatTime(tick() - clientData.joined)
						or "<i>Not registered in the system</i>"
					local isAGhost = target:getReplicator().instance.Parent ~= service.NetworkServer
					local isInServer = target.Parent == service.Players or not isAGhost

					table.insert(tab, {
						type = "Detailed",
						label = tagPrefix .. targetDisplayAndUser .. ` - {deviceInfo}`,
						description = (
							isAGhost
								and "Player " .. targetDisplayAndUser .. " exists in the server, but hides in the game\n"
							or ""
						)
							.. "Duration: "
							.. inGameDuration,
						richText = true,
					})

					--if isMutual then
					--	local canShowMutualList = #mutualList < 8

					--	if canShowMutualList then
					--		for d, mutualId in ipairs(mutualList) do
					--			local mutualTarget = service.getPlayer(mutualId)
					--			if mutualTarget then
					--				table.insert(tab, "> <font color='#ebba34'>Mutual with</font> <b>"..tostring(target).."</b>")
					--			end
					--		end
					--	else
					--		table.insert(tab, "> <font color='#ebba34'>Mutual with</font> <b>"..#mutualList.." friends in the server</b>")
					--	end
					--end
				end

				plr:makeUI("List", {
					Title = "E. In-game players",
					List = tab,
				})
			end,
		},

		handToPlayer = {
			Prefix = settings.playerPrefix,
			Aliases = { "handto", "giveitem" },
			Arguments = {
				{
					argument = "player",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Use_Utility", "HandTo_Utility" },
			Roles = {},

			Description = "Gives current item to the target.",
			PlayerCooldown = 5,

			Function = function(plr, args)
				local hasOverridePerm = Moderation.checkAdmin(plr)
				local target = args[1][1]

				if not hasOverridePerm and (target:getVar "HandToPrompt" or plr:getVar "HandToPrompt") then
					plr:sendData(
						"SendMessage",
						"HandTo Error",
						"You or "
							.. target.Name
							.. " is currently in a HandTo prompt. Unable to proceed with the HandTo prompt if there's an on-going session. Sorry!",
						10,
						"Hint"
					)
					return
				end

				local playerChar = plr.Character

				-- Proximity check
				if not hasOverridePerm then
					local targetChar = target.Character

					local targetTorso = targetChar
						and (targetChar:FindFirstChild "Torso" or targetChar:FindFirstChild "HumanoidRootPart")
					local playerTorso = playerChar
						and (playerChar:FindFirstChild "Torso" or playerChar:FindFirstChild "HumanoidRootPart")

					if not (targetTorso and playerTorso) then
						plr:sendData(
							"SendMessage",
							"HandTo Error",
							"Unable to check character proximity. You and the target must have a torso.",
							10,
							"Hint"
						)
						return
					end

					local acceptableDist = 20
					local theirCharDist = (targetTorso.Position - playerTorso.Position).magnitude
					if theirCharDist > acceptableDist then
						plr:sendData(
							"SendMessage",
							"HandTo Error",
							"You are not close to your target. If you want to override proximity check, you must have permission <b>HandTo_Utility</b>.",
							10,
							"Hint"
						)
						return
					end
				end

				local currentTool = playerChar and playerChar:FindFirstChildOfClass "Tool"
				local backpack = plr:FindFirstChildOfClass "Backpack"
				local targetStoreLocation = target:FindFirstChildOfClass "Backpack" or target.Character

				if not currentTool then
					plr:sendData("SendMessage", "HandTo Error", "You don't have a tool in your hand.", 5, "Hint")
					return
				end

				if not backpack then
					plr:sendData(
						"SendMessage",
						"HandTo Error",
						"You must have a backpack to continue this process.",
						5,
						"Hint"
					)
					return
				end

				if not targetStoreLocation or targetStoreLocation.Parent == nil then
					plr:sendData(
						"SendMessage",
						"HandTo Error",
						target.Name .. " doesn't have a place to store the item.",
						5,
						"Hint"
					)
					return
				end

				local didDebounce = service.debounce("HandTo-" .. plr.playerId .. "-" .. target.playerId, function()
					if not hasOverridePerm then
						target:setVar("HandToPrompt", true)
						plr:setVar("HandToPrompt", true)

						wait(0.5)
						currentTool.Parent = nil

						plr:sendData(
							"SendMessage",
							"Handling HandTo process..",
							"Sent a request to " .. target.DisplayName .. " (@" .. target.Name .. "). Please wait",
							50,
							"Hint"
						)
						local didPass = false
						local requestTime = 30
						local openedNotif = target:customGetData(requestTime + 2, "MakeUI", "Notification", {
							title = "HandTo request",
							desc = "From " .. plr.DisplayName .. " (@" .. plr.Name .. ")",
							actionText = "Review confirmation",
							time = requestTime,
							returnStateOnInteraction = true
						})

						if openedNotif then
							plr:sendData(
								"SendMessage",
								"Handling HandTo process..",
								target.DisplayName
									.. " (@"
									.. target.Name
									.. ") opened the prompt. Waiting for their confirmation",
								10,
								"Hint"
							)

							local checkConfirm = target:customGetData(12, "MakeUI", "Confirmation", {
								title = "HandTo Confirmation",
								desc = "Would you like to accept the tool "
									.. currentTool.Name:sub(1, 30)
									.. " from "
									.. plr.DisplayName
									.. " (@"
									.. plr.Name
									.. ")?",
								choiceA = "Yes, I confirm.",
								returnOutput = true,
								time = 10,
							})

							if checkConfirm == 1 then
								didPass = true
								plr:sendData(
									"SendMessage",
									"HandTo process successful",
									target.DisplayName
										.. " (@"
										.. target.Name
										.. ") accepted your request. The tool went to your backpack/character.",
									10,
									"Hint"
								)
								currentTool.Parent = targetStoreLocation
							else
								plr:sendData(
									"SendMessage",
									"HandTo process failed",
									target.DisplayName
										.. " (@"
										.. target.Name
										.. ") declined the confirmation. The tool was returned to your backpack.",
									10,
									"Hint"
								)
							end
						else
							plr:sendData(
								"SendMessage",
								"HandTo process failed",
								target.DisplayName
									.. " (@"
									.. target.Name
									.. ") declined your request. The tool was returned to your backpack.",
								10,
								"Hint"
							)
						end

						if not didPass then
							wait(0.5)
							currentTool.Parent = backpack
						end

						target:setVar("HandToPrompt", false)
						plr:setVar("HandToPrompt", false)
					else
						plr:sendData(
							"SendMessage",
							"HandTo Success",
							"Successfully gave the tool to " .. target.DisplayName .. " (@" .. target.Name .. ")",
							5,
							"Hint"
						)
						wait(0.5)
						currentTool.Parent = targetStoreLocation
					end
				end)

				if not didDebounce then
					plr:sendData(
						"SendMessage",
						"HandTo Error",
						"You are already in a session with " .. target.Name .. ".",
						5,
						"Hint"
					)
				end
			end,
		},

		joinPlayer = {
			Prefix = settings.playerPrefix,
			Aliases = { "joinplayer" },
			Arguments = {
				{
					argument = "username",
					type = "playerName",
					required = true,
				},
			},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Joins a player from this game",
			PlayerCooldown = 15,
			PlayerDebounce = true,

			Function = function(plr, args)
				local targetId = service.playerIdFromName(args[1])
				if targetId == plr.UserId then
					plr:sendData("SendMessage", "You cannot join yourself.", nil, 5, "Context")
					return
				end

				if service.getPlayer(targetId) then
					plr:sendData("SendMessage", "Player " .. args[1] .. " is already in your server", nil, 5, "Context")
				end

				plr:sendData("SendMessage", "Finding player " .. args[1] .. "..", nil, 5, "Context")

				local targetPData = Core.getPlayerData(targetId)
				targetPData._updateIfDead()

				if targetPData.__clientSettings.IncognitoMode and not Moderation.checkAdmin(plr) then
					plr:sendData(
						"SendMessage",
						`Player {args[1]} has enabled Incognito mode. You are forbidden to join their server unless you are an in-game administrator`,
						nil,
						5,
						"Context"
					)
					return
				end

				local serverDetails = targetPData.__serverDetails
				if not serverDetails then
					plr:sendData("SendMessage", "Player " .. args[1] .. " isn't online in the game", nil, 5, "Context")
				else
					local accessCode = serverDetails.serverAccessCode
					if accessCode then
						local privateServerData = Utility:getReserveServer(serverDetails.privateServerId)
						if privateServerData then
							local canJoinServer = privateServerData.creatorId == plr.UserId
								or not privateServerData.inviteOnly
								or (
									Identity.checkTable(plr, privateServerData.whitelist)
									and not Identity.checkTable(plr, privateServerData.banlist)
								)

							if not canJoinServer then
								plr:sendData(
									"SendMessage",
									"Player "
										.. args[1]
										.. " is in a Essential-reserved server which requires a teleport signature. You cannot join this server unless you have permission.",
									nil,
									5,
									"Context"
								)
							else
								plr:sendData("SendMessage", "Joining player " .. args[1], nil, 5, "Context")
								plr:teleportToReserveWithSignature(accessCode)
							end
						end
					elseif serverDetails.privateServer then
						plr:sendData(
							"SendMessage",
							"Player " .. args[1] .. " is in a private/personal server. You cannot join this server.",
							nil,
							5,
							"Context"
						)
					else
						plr:sendData("SendMessage", "Joining player " .. args[1], nil, 5, "Context")
						plr:teleportToServer(serverDetails.serverJobId)
					end
				end
			end,
		},

		showScreenshotHud = {
			Prefix = settings.playerPrefix,
			Aliases = { "screenshot", "camera" },
			Arguments = {
				{
					type = "trueOrFalse",
					argument = "showExperienceName",
				},
			},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Opens the camera HUD by Roblox",

			Function = function(plr, args) plr:sendData("showScreenshotHud", args[1] or false) end,
		},

		hideScreenshotHud = {
			Prefix = settings.playerPrefix,
			Aliases = { "closescreenshot", "closecamera" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Hides the camera HUD by Roblox",

			Function = function(plr, args) plr:sendData "hideScreenshotHud" end,
		},

		showClientSettings = {
			Prefix = settings.playerPrefix,
			Aliases = { "settings", "clisettings", "clientsettings" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Opens client settings",

			Function = function(plr, args)
				plr:makeUI("ClientSettings", {
					openSpecificCategory = "Client settings",
				})
			end,
		},

		showShortcuts = {
			Prefix = settings.playerPrefix,
			Aliases = { "shortcuts", "buttons", "cmdshortcuts" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Shows shortcuts in client settings",

			Function = function(plr, args)
				plr:makeUI("ClientSettings", {
					openSpecificCategory = "Shortcuts",
				})
			end,
		},

		showCCAliases = {
			Prefix = settings.playerPrefix,
			Aliases = { "ccaliases", "customcmdaliases" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Shows custom cmd aliases in client settings",

			Function = function(plr, args)
				plr:makeUI("ClientSettings", {
					openSpecificCategory = "CC Aliases/Names",
				})
			end,
		},

		showActionAliases = {
			Prefix = settings.playerPrefix,
			Aliases = { "actionaliases", "groupaliases" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Shows action aliases in client settings",

			Function = function(plr, args)
				plr:makeUI("ClientSettings", {
					openSpecificCategory = "Action Aliases",
				})
			end,
		},

		showKeybinds = {
			Prefix = settings.playerPrefix,
			Aliases = { "keybinds" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Shows keybinds in client settings",

			Function = function(plr, args)
				plr:makeUI("ClientSettings", {
					openSpecificCategory = "Keybinds",
				})
			end,
		},

		randomizeMyIncognitoName = {
			Prefix = settings.playerPrefix,
			Aliases = { "newincognitoname" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "Randomizes my incognito name",
			PlayerCooldown = 10,

			Function = function(plr, args)
				local oldIncognitoName = plr:getPData().incognitoName
				plr:generateIncognitoName()
				local incognitoName = plr:getPData().incognitoName
				local playerIncognitoStatus, playerIncognitoOverriden = plr:isPrivate()

				plr:toggleIncognitoStatus(playerIncognitoStatus, playerIncognitoOverriden)

				plr:sendData("SendNotification", {
					title = `Incognito Name Changed`;
					description = `You changed your incognito name to {Parser:filterForRichText(incognitoName)}`
						.. `\n\n<i>Previously {Parser:filterForRichText(oldIncognitoName)}</i>`,
					time = 10,
				})
			end,
		},
	}

	for cmdName, cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
