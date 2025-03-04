local ServerStorage = game:GetService("ServerStorage")

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
        disguisePlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "disguise" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true;
				},
				{
					argument = "targetname",
					required = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Disguises specified players as the target (DOES NOT WORK FOR IN-GAME ADMIN TARGETS IF YOU'RE NOT AN IN-GAME ADMINISTRATOR)",

			Function = function(plr, args)
				local targetUserId = service.playerIdFromName(args[2])
				if targetUserId <= 0 then
					plr:sendData("SendMessage", `Player name {Parser:filterForRichText(args[2])} does not exist as a player entity on Roblox platform`, nil, 5, "Context")
					return
				end

				local isPlayerAdmin = Moderation.checkAdmin(plr)
				local isTargetAdmin = Moderation.checkAdmin(targetUserId)

				if not isPlayerAdmin and isTargetAdmin then
					plr:sendData("SendMessage", `{Parser:filterForRichText(args[2])} is an <b>in-game administrator</b>. You CANNOT disguise specified players as this target without having Manage_Game permission.`, nil, 5, "Context")
					return
				end
				
				for i, otherPlayer in pairs(args[1]) do
					otherPlayer:disguiseAsPlayer(targetUserId)
				end
			end,
		},

        unDisguise = {
			Prefix = settings.actionPrefix,
			Aliases = { "undisguise" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Removes specified players' disguises",

			Function = function(plr, args)
				for i, otherPlayer in pairs(args[1]) do
					otherPlayer:disguiseAsPlayer(0)
				end
			end,
		},

        -- disguiseName = {
		-- 	Prefix = settings.actionPrefix,
		-- 	Aliases = { "disguisename" },
		-- 	Arguments = {
		-- 		{
		-- 			argument = "players",
		-- 			type = "players",
		-- 			required = true,
		-- 		},
		-- 		{
		-- 			argument = "displayname",
		-- 			filter = true,
        --             requireSafeString = true,
		-- 			required = true,
		-- 		},
		-- 	},
		-- 	Permissions = { "Message_Commands" },
		-- 	Roles = {},

		-- 	Description = "Presents a message to specified players with supplied message",

		-- 	Function = function(plr, args)
		-- 		for i, target in pairs(args[1]) do
		-- 			target:SetAttribute("DisplayName", args[2])
		-- 		end
		-- 	end,
		-- },

        -- resetDisguiseName = {
		-- 	Prefix = settings.actionPrefix,
		-- 	Aliases = { "resetdisguisename" },
		-- 	Arguments = {
		-- 		{
		-- 			argument = "players",
		-- 			type = "players",
		-- 			required = true,
		-- 		}
		-- 	},
		-- 	Permissions = { "Message_Commands" },
		-- 	Roles = {},

		-- 	Description = "Presents a message to specified players with supplied message",

		-- 	Function = function(plr, args)
		-- 		for i, target in pairs(args[1]) do
		-- 			target:SetAttribute("DisplayName", nil)
		-- 		end
		-- 	end,
		-- },
    }

	for cmdName, cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
