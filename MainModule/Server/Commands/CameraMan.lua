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

	local Signal = server.Signal

	local cmdsList = {
		trackPlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "track" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					ignoreSelf = not server.Studio,
					maxPlayers = 20,
				},
			},
			Permissions = { "Manage_Camera" },
			Roles = {},
			PlayerCooldown = 10,

			Description = "Focuses your camera to a specified player (not yourself)",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					plr:sendData(`TrackPlayer`, target._object)
				end
			end,
		},

		unTrackPlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "untrack" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					ignoreSelf = not server.Studio,
					allowFPCreation = true,
					maxPlayers = 20,
				},
			},
			Permissions = { "Manage_Camera" },
			Roles = {},
			PlayerCooldown = 10,

			Description = "UnFocuses your camera from a specified player (not yourself)",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					plr:sendData(`UnTrackPlayer`, target.UserId)
				end
			end,
		},

		focusOnPlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "focus", "view" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Camera" },
			Roles = {},

			Description = "Focuses your camera to a specified player",

			Function = function(plr, args)
				local target = args[1][1]

				--if target == plr then
				--	plr:sendData("SendMessage", "Now focusing on yourself.", nil, 4, "Context")
				--	plr:sendData("unfocusCamera")
				--	return
				--end

				if not target.Character then
					plr:sendData("SendMessage", target.Name .. " doesn't have a character.", nil, 4, "Context")
					--plr:sendData("SendMessage", "Camera management", target.Name.." doesn't have a character.", 6, "Hint")
				else
					local humanoid = target.Character:FindFirstChildOfClass "Humanoid"

					if not humanoid then
						plr:sendData(
							"SendMessage",
							target.Name .. "'s character doesn't have a humanoid.",
							nil,
							4,
							"Context"
						)
						--plr:sendData("SendMessage", "Camera management", target.Name.." doesn't have a humanoid.", 6, "Hint")
					else
						plr:sendData(
							"SendMessage",
							"Now focusing on " .. target.Name .. "'s character.",
							nil,
							4,
							"Context"
						)
						plr:sendData("focusCameraOnPart", humanoid)
					end
				end
			end,
		},

		unFocusCamera = {
			Prefix = settings.actionPrefix,
			Aliases = { "unFocus", "unview" },
			Arguments = {},
			Permissions = { "Manage_Camera" },
			Roles = {},

			Description = "Unfocuses your camera",

			Function = function(plr, args)
				plr:sendData("SendMessage", "Now focusing on yourself.", nil, 4, "Context")
				plr:sendData "unfocusCamera"
			end,
		},

		fixCamera = {
			Prefix = settings.actionPrefix,
			Aliases = { "fixcam", "unfview" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Camera" },
			Roles = {},

			Description = "Fixes specified players' camera",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					target:sendData "unfocusCamera"
				end
			end,
		},

		forceCameraForPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "fview", "forceview" },
			Arguments = {
				{
					type = "players",
					argument = "focusedPlayer",
					required = true,
				},
				{
					type = "players",
					argument = "targets",
					required = true,
				},
			},
			Permissions = { "Manage_Camera" },
			Roles = {},

			Description = "Fixes specified players' camera",

			Function = function(plr, args)
				local focusedPlr = args[1][1]

				if not focusedPlr.Character then
					plr:sendData("SendMessage", focusedPlr.Name .. " doesn't have a character.", nil, 6, "Context")
					--plr:sendData("SendMessage", "Camera management", focusedPlr.Name.." doesn't have a character.", 6, "Hint")
					return
				end

				local humanoid = focusedPlr.Character:FindFirstChildOfClass "Humanoid"

				if not humanoid then
					plr:sendData("SendMessage", focusedPlr.Name .. " doesn't have a humanoid.", nil, 6, "Context")
					--plr:sendData("SendMessage", "Camera management", focusedPlr.Name.." doesn't have a humanoid.", 6, "Hint")
					return
				end

				for i, target in pairs(args[2]) do
					target:sendData("focusCameraOnPart", humanoid)
				end
				plr:sendData(
					"SendMessage",
					(#args[2] > 6 and tostring(#args[2]) .. " players")
						or args[2] "concat" ", " .. " are now focused to " .. focusedPlr.Name .. ".",
					nil,
					8,
					"Context"
				)
			end,
		},

		freeCam = {
			Prefix = settings.actionPrefix,
			Aliases = { "freecam" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Camera" },
			Roles = {},

			Description = "Gives the specified players' freecam",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local playerGui = target:FindFirstChildOfClass "PlayerGui"

					if playerGui then
						local freecam = playerGui:FindFirstChild "Freecam"

						if not freecam then
							freecam = server.Assets.Freecam:Clone()
							freecam.Freecam.Disabled = false
							freecam.Parent = playerGui
						end

						local remoteFunc = freecam:FindFirstChildOfClass "RemoteFunction"
						local remoteEv = freecam:FindFirstChildOfClass "RemoteEvent"

						if remoteEv then
							remoteEv:FireClient(target._object, "Enable")
						elseif remoteFunc then
							service.threadTask(function() remoteFunc:InvokeClient(target._object, "Enable") end)
						end
					end
				end
			end,
		},

		stopFreeCam = {
			Prefix = settings.actionPrefix,
			Aliases = { "stopfreecam", "unfreecam" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Camera" },
			Roles = {},

			Description = "Ends the specified players' freecam",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local playerGui = target:FindFirstChildOfClass "PlayerGui"

					if playerGui then
						local freecam = playerGui:FindFirstChild "Freecam"

						if freecam then
							local remoteFunc = freecam:FindFirstChildOfClass "RemoteFunction"
							local remoteEv = freecam:FindFirstChildOfClass "RemoteEvent"

							if remoteEv then
								remoteEv:FireClient(target._object, "Disable")
							elseif remoteFunc then
								service.threadTask(function() remoteFunc:InvokeClient(target._object, "Disable") end)
							end
						end
					end
				end
			end,
		},

		toggleFreeCam = {
			Prefix = settings.actionPrefix,
			Aliases = { "togglefreecam" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Camera" },
			Roles = {},

			Description = "Toggles the specified players' freecam",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local playerGui = target:FindFirstChildOfClass "PlayerGui"

					if playerGui then
						local freecam = playerGui:FindFirstChild "Freecam"

						if freecam then
							local remoteFunc = freecam:FindFirstChildOfClass "RemoteFunction"
							local remoteEv = freecam:FindFirstChildOfClass "RemoteEvent"

							if remoteEv then
								remoteEv:FireClient(target._object, "Toggle")
							elseif remoteFunc then
								service.threadTask(function() remoteFunc:InvokeClient(target._object, "Toggle") end)
							end
						end
					end
				end

				plr:sendData("SendMessage", "Toggled <b>" .. #args[1] .. " players'</b> freecam", nil, 10, "Context")
			end,
		},

		removeFreeCam = {
			Prefix = settings.actionPrefix,
			Aliases = { "remfreecam" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Camera" },
			Roles = {},

			Description = "Removes the specified players' freecam",

			Function = function(plr, args)
				local concatPlayers = {}

				for i, target in pairs(args[1]) do
					local playerGui = target:FindFirstChildOfClass "PlayerGui"

					if playerGui then
						local freecam = playerGui:FindFirstChild "Freecam"

						if freecam then
							local remoteFunc = freecam:FindFirstChildOfClass "RemoteFunction"
							local remoteEv = freecam:FindFirstChildOfClass "RemoteEvent"

							if remoteEv then
								remoteEv:FireClient(target._object, "Disable")
							elseif remoteFunc then
								service.threadTask(function() remoteFunc:InvokeClient(target._object, "Disable") end)
							end

							service.Debris:AddItem(freecam, 4)
							table.insert(concatPlayers, target.Name)
						end
					end
				end

				if #concatPlayers > 0 and plr then
					plr:sendData(
						"SendMessage",
						"Removed <b>players freecam</b> from " .. table.concat(concatPlayers, ", ") .. ".",
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
