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

	local cmdsList = {
		hint = {
			Prefix = settings.actionPrefix,
			Aliases = { "h", "hint" },
			Arguments = {
				{
					argument = "message",
					required = true,
					filterForPublic = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Presents a hint to everyone with supplied message",

			Function = function(plr, args)
				for i, target in pairs(service.getPlayers()) do
					local playerDisplayName = plr:toStringDisplayForPlayer(target)
					local parsedTarget = server.Parser:apifyPlayer(target)

					if parsedTarget then
						parsedTarget:sendData(
							"SendMessage",
							"Message from <b>" .. playerDisplayName .. "</b>",
							args[1],
							math.floor(math.clamp(#args[1] * 0.1, 3, 30)),
							"Hint"
						)
					end
				end
			end,
		},

		message = {
			Prefix = settings.actionPrefix,
			Aliases = { "m", "message" },
			Arguments = {
				{
					argument = "message",
					required = true,
					filterForPublic = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Presents a message to everyone with supplied message",

			Function = function(plr, args)
				for i, target in pairs(service.getPlayers()) do
					local parsedTarget = server.Parser:apifyPlayer(target)
					local playerDisplayName = plr:toStringDisplayForPlayer(parsedTarget)

					if parsedTarget then
						parsedTarget:sendData(
							"SendMessage",
							"Message from <b>" .. playerDisplayName .. "</b>",
							args[1],
							math.floor(math.clamp(#args[1] * 0.1, 3, 30))
						)
					end
				end
			end,
		},

		messagePrivate = {
			Prefix = settings.actionPrefix,
			Aliases = { "mpm" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "message",
					filter = true,
					required = true,
					private = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Presents a message to specified players with supplied message",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local playerDisplayName = plr:toStringDisplayForPlayer(target)
					target:sendData(
						"SendMessage",
						"Message from <b>" .. playerDisplayName .. "</b>",
						args[2],
						math.floor(math.clamp(#args[2] * 0.1, 3, 30))
					)
				end
			end,
		},

		bubble = {
			Prefix = settings.actionPrefix,
			Aliases = { "bub", "bubble" },
			Arguments = {
				{
					argument = "message",
					required = true,
					filterForPublic = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Presents a bubble to everyone with supplied message",

			Function = function(plr, args)
				for i, target in pairs(service.getPlayers()) do
					local parsedTarget = server.Parser:apifyPlayer(target)
					local playerDisplayName = plr:toStringDisplayForPlayer(parsedTarget)

					if parsedTarget then
						parsedTarget:sendData(
							"SendMessage",
							"Message from <b>" .. playerDisplayName .. "</b>",
							args[1],
							math.floor(math.clamp(#args[1] * 0.1, 3, 30)),
							"Bubble"
						)
					end
				end
			end,
		},

		bubblePrivate = {
			Prefix = settings.actionPrefix,
			Aliases = { "bpm" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "message",
					filter = true,
					required = true,
					private = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Presents a bubble to specified players with supplied message",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local playerDisplayName = plr:toStringDisplayForPlayer(target)
					target:sendData(
						"SendMessage",
						"Message from <b>" .. playerDisplayName .. "</b>",
						args[2],
						math.floor(math.clamp(#args[2] * 0.1, 3, 30)),
						"Bubble"
					)
				end
			end,
		},

		context = {
			Prefix = settings.actionPrefix,
			Aliases = { "context", "actiontext" },
			Arguments = {
				{
					argument = "message",
					required = true,
					filterForPublic = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Presents a context UI to everyone with supplied message",

			Function = function(plr, args)
				for i, target in pairs(service.getPlayers()) do
					local parsedTarget = server.Parser:apifyPlayer(target)
					local playerDisplayName = plr:toStringDisplayForPlayer(parsedTarget)

					if parsedTarget then
						parsedTarget:sendData(
							"SendMessage",
							"<b>" .. playerDisplayName .. "</b>: " .. server.Parser:filterForRichText(args[1]),
							playerDisplayName .. ": " .. args[1],
							math.floor(math.clamp(#args[1] * 0.1, 3, 30)),
							"Context"
						)
					end
				end
			end,
		},

		contextPrivate = {
			Prefix = settings.actionPrefix,
			Aliases = { "contextpm" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "message",
					filter = true,
					required = true,
					private = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Presents a context to specified players with supplied message",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local playerDisplayName = plr:toStringDisplayForPlayer(target)
					target:sendData(
						"SendMessage",
						"<b>" .. playerDisplayName .. "</b>: " .. server.Parser:filterForRichText(args[2]),
						playerDisplayName .. ": " .. args[2],
						math.floor(math.clamp(#args[2] * 0.1, 3, 30)),
						"Context"
					)
				end
			end,
		},

		privateMessage = {
			Prefix = settings.actionPrefix,
			Aliases = { "pm" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					--ignoreSelf = true;
					required = true,
				},
				{
					argument = "noReply",
					type = "trueOrFalse",
					required = true,
				},
				{
					argument = "message",
					filter = true,
					required = true,
					private = true,
				},
			},
			Permissions = { "Private_Messaging" },
			Roles = {},

			Description = "Direct/Private messages specified players with supplied message",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local playerDisplayName = plr:toStringDisplayForPlayer(target)
					Remote.privateMessage {
						receiver = target,
						sender = plr,
						topic = "From <b>" .. playerDisplayName .. "</b>",
						message = Parser:filterForRichText(args[3]),
						--notifyOpts = {title = "Private message", desc = "Click to view"};
						noReply = args[2],
					}
				end
			end,
		},

		directMessage = {
			Prefix = settings.actionPrefix,
			Aliases = { "dm", "directmessage" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					--ignoreSelf = true;
					required = true,
					allowFPCreation = true,
				},
				{
					argument = "noReply",
					type = "trueOrFalse",
					required = true,
				},
				{
					argument = "message",
					filter = true,
					required = true,
					private = true,
				},
			},
			Permissions = { "Private_Messaging" },
			Roles = {},

			Description = "Direct messages specified players with supplied message (1,000 char limit)",
			ServerCooldown = 4,

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local playerDisplayName = plr:toStringDisplayForPlayer(target)
					target:directMessage {
						title = "From " .. playerDisplayName,
						text = Parser:filterForRichText(args[3]:sub(1, 1000)),
						receiverUserId = plr.UserId,
					}
				end

				plr:sendData(
					"SendMessage",
					`Successfully direct messaged <b>{#args[1]} player(s)</b>. This process will take 60-90 seconds for the specified players to receive their message.`,
					nil,
					10,
					"Context"
				)
			end,
		},

		systemMessage = {
			Prefix = settings.actionPrefix,
			Aliases = { "sm" },
			Arguments = {
				{
					argument = "message",
					required = true,
					filterForPublic = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Presents a system message to everyone with supplied message",

			Function = function(plr, args)
				for i, target in pairs(service.getPlayers(true)) do
					target:sendData(
						"SendMessage",
						tostring(settings.systemMessage),
						args[1],
						math.floor(math.max(#args[1] * 0.1, 30))
					)
				end
			end,
		},

		countdown = {
			Prefix = settings.actionPrefix,
			Aliases = { "countdown" },
			Arguments = {
				{
					argument = "time",
					type = "time",
					required = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Presents a countdown with supplied message",
			PlayerCooldown = 1,

			Function = function(plr, args)
				if args[1].total > 0 then
					args[1] = math.clamp(args[1].total, 0, 10000)
					service.stopLoop "Countdown"

					local count = args[1]
					service.startLoop("Countdown", 1, function()
						if count > -1 then
							for i, target in pairs(service.getPlayers(true)) do
								target:sendData(
									"SendMessage",
									"Countdown",
									server.Parser:formatTime(count),
									1,
									"Bubble",
									true,
									true,
									true
								)
							end

							count -= 1
						else
							service.stopLoop "Countdown"

							for ind, target in pairs(service.getPlayers(true)) do
								target:sendData("PlaySound", "Countdown", 267883130)
							end

							for i = 1, 5, 1 do
								for ind, target in pairs(service.getPlayers(true)) do
									target:sendData(
										"SendMessage",
										"Countdown",
										"<font color='#ff3300'>00:00:00</font>",
										1,
										"Bubble",
										true,
										true,
										true
									)
								end
								wait(1)
							end
						end
					end)
				end
			end,
		},

		stopCountdown = {
			Prefix = settings.actionPrefix,
			Aliases = { "stopcountdown" },
			Arguments = {},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Stops the ongoing countdown",

			Function = function(plr, args) service.stopLoop "Countdown" end,
		},

		notifyPlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "notify" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "title",
					required = true,
					filter = true,
				},
				{
					argument = "message",
					required = true,
					filter = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Notifies specified players with supplied message",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local playerDisplayName = plr:toStringDisplayForPlayer(target)
					target:makeUI("NotificationV2", {
						title = "From " .. playerDisplayName .. ": " .. args[2],
						desc = args[3],
						time = 30,
					})
				end
			end,
		},

		--// Sticky messages
		--globalStickyMessage = {
		--	Prefix = settings.actionPrefix;
		--	Aliases = {"setglobalmessage"};
		--	Arguments = {
		--		{
		--			argument = "message";
		--			required = true;
		--			filter = true;
		--		}
		--	};
		--	Permissions = {"Manage_Server";};
		--	Roles = {};

		--	Description = "Sets a sticky message to all servers. Message expires after 30 real-time minutes. It will take 1-5 minutes to appear to old servers.";
		--	CrossCooldown = 30;
		--	PlayerCooldown = 30;

		--	Function = function(plr, args)
		--		local memoryStoreService = service.MemoryStoreService
		--		local memoryStoreService = service.MemoryStoreService
		--	end;
		--};
	}

	for cmdName, cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
