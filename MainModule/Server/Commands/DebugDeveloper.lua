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

	local cmdPrefix = "debug-"
	local cmdsList = {
		-- This was used for testing purposes
		-- viewRunningNetworks = {
		-- 	Disabled = true,
		-- 	Prefix = settings.actionPrefix,
		-- 	Aliases = { cmdPrefix .. "networks" },
		-- 	Arguments = {},
		-- 	Permissions = {},
		-- 	Roles = { "developer" },
		-- 	PlayerCooldown = 1,
		-- 	NoPermissionsBypass = true,

		-- 	Description = "Gives boombox to specific players",

		-- 	Function = function(plr, args)
		-- 		local tabResults = {}
		-- 		local fireNetworks = Core.remoteNetwork1
		-- 		local invokeNetworks = Core.remoteNetwork2

		-- 		table.insert(tabResults, "Players: ---------")
		-- 		for i, target in pairs(service.getPlayers(true)) do
		-- 			local cliData = target:getClientData()

		-- 			if cliData then
		-- 				if not cliData.trustChecked then
		-- 					table.insert(tabResults, tostring(target) .. ": *waiting to trust check*")
		-- 				else
		-- 				end
		-- 			end
		-- 		end

		-- 		plr:makeUI("ADONIS_LIST", {
		-- 			Title = "E. Network system",
		-- 			Table = tabResults,
		-- 		})
		-- 	end,
		-- },
	}

	for cmdName, cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
