--[[

		ESSENTIAL UTILITY FOR SERVER
		- Made by trzistan
		
]]

local server, service, variables, settings
local getEnv, loadModule, assertWarn
local warn = warn
local Signal

local serverCores = {
	"Commands",
	"Core",
	"Cross",
	"Datastore",
	"Identity",
	"Logs",
	"Moderation",
	"Process",
	"Remote",
}

return {
	Dependencies = {},

	Init = function(self, env)
		server = env.server
		service = env.service
		getEnv = env.getEnv
		loadModule = env.loadModule
		variables = env.variables
		settings = server.Settings
		assertWarn = env.assertWarn

		Signal = server.Signal

		--// Output functions
		warn = env.warn

		self.Init = nil
	end,

	Apply = function(self, tab: { [any]: any })
		for i, v in pairs(self.Util) do
			rawset(tab, i, v)
		end
	end,

	Util = {
		awaitModule = function(moduleName) end,
	},
}
