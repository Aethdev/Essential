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

	local cmdsList = {
        disguisePlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "disguise" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "displayname",
					filter = true,
                    requireSafeString = true,
					required = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Presents a message to specified players with supplied message",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					target:SetAttribute("DisplayName", args[2])
				end
			end,
		},

        disguiseName = {
			Prefix = settings.actionPrefix,
			Aliases = { "disguisename" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "displayname",
					filter = true,
                    requireSafeString = true,
					required = true,
				},
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Presents a message to specified players with supplied message",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					target:SetAttribute("DisplayName", args[2])
				end
			end,
		},

        resetDisguiseName = {
			Prefix = settings.actionPrefix,
			Aliases = { "resetdisguisename" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				}
			},
			Permissions = { "Message_Commands" },
			Roles = {},

			Description = "Presents a message to specified players with supplied message",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					target:SetAttribute("DisplayName", nil)
				end
			end,
		},
    }

	for cmdName, cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
