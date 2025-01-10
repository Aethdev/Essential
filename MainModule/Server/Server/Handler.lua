--!nolint DeprecatedGlobal
--[[

		ESSENTIAL INITIALIZER
		- Made by trzistan
		
]]

local _G, game, script, getfenv, setfenv, workspace,
	getmetatable, setmetatable, loadstring, coroutine,
	rawequal, typeof, print, math, warn, error,  pcall,
	xpcall, select, rawset, rawget, ipairs, pairs,
	next, Rect, Axes, os, tick, Faces, unpack, string, Color3,
	newproxy, tostring, tonumber, Instance, TweenInfo, BrickColor,
	NumberRange, ColorSequence, NumberSequence, ColorSequenceKeypoint,
	NumberSequenceKeypoint, PhysicalProperties, Region3int16,
	Vector3int16, elapsedTime, require, table, type, wait,
	Enum, UDim, UDim2, Vector2, Vector3, Region3, CFrame, Ray, spawn =
		_G, game, script, getfenv, setfenv, workspace,
	getmetatable, setmetatable, loadstring, coroutine,
	rawequal, typeof, print, math, warn, error,  pcall,
	xpcall, select, rawset, rawget, ipairs, pairs,
	next, Rect, Axes, os, tick, Faces, unpack, string, Color3,
	newproxy, tostring, tonumber, Instance, TweenInfo, BrickColor,
	NumberRange, ColorSequence, NumberSequence, ColorSequenceKeypoint,
	NumberSequenceKeypoint, PhysicalProperties, Region3int16,
	Vector3int16, elapsedTime, require, table, type, wait,
	Enum, UDim, UDim2, Vector2, Vector3, Region3, CFrame, Ray, spawn
local RaycastParams = RaycastParams
local task = task
local delay = delay
local assert = assert
local debug = debug
local Random = Random
local utf8 = utf8
local _VERSION = _VERSION
local DateTime = DateTime
local rawlen = rawlen

local server, service, variables, settings
local getEnv, loadModule, assertWarn
local warn = warn
local loadData

local serverCores = {
	"Logs";
	"Commands";
	"Core";
	"Cross";
	"Datastore";
	"Identity";
	"Moderation";
	"Process";
	"Remote";
}

return {
	Dependencies = {};
	
	Init = function(self, env)
		server = env.server
		service = env.service
		getEnv = env.getEnv
		loadModule = env.loadModule
		variables = env.variables
		settings = server.Settings
		assertWarn = env.assertWarn
		
		--// Load Data
		loadData = server.LoaderData
		
		--// Output functions
		warn = env.warn
		
		self.Init = nil
	end,
	
	LoadCores = function(self)
		local serverFolder: Folder = server.Folder
		local scriptSettings: {[any]: any} = server.ScriptSettings
		
		for i,core in pairs(serverCores) do
			local coreModule = serverFolder.Core:FindFirstChild(core)
			
			if scriptSettings.secureRun then
				coreModule = if coreModule then coreModule else nil
			end
			
			if not coreModule then
				warn("ERROR! Core "..core.." is missing.")
				return
			else
				loadModule(coreModule, {script = coreModule}, false, true)
			end
		end
		
		self.LoadCores = nil
	end,
	
	LoadInits = function(self)
		--local realWarn = warn
		--local debugWarn = true
		--local warn = function(...) if debugWarn then realWarn(...) end end
		
		local loadingOrders = {}
		for i, initLoader in pairs(self.Loaders) do
			local initOrder: number = initLoader.Order or 0
			local loadOrder: {[any]: any} = loadingOrders[initOrder] or {}

			initLoader.Order = initOrder
			loadingOrders[initOrder] = loadOrder

			table.sort(loadingOrders, function(a, b)
				return table.find(loadingOrders, a) < table.find(loadingOrders, b)
			end)

			if not table.find(loadOrder, initLoader.Runner) then
				table.insert(loadOrder, initLoader)
			end
		end

		
		for ind, orderList in ipairs(loadingOrders) do
			-- local loadOrderStartLoad = tick()
			--warn("Loading loading order "..tostring(ind))
			for d, func in ipairs(orderList) do
				local initFuncStart = tick()
				--warn("> Running init "..tostring(func.Name), d)
				--warn(service.nonThreadTask(func.Runner))
				if not func.RunAfterInit then
					func.Runner()
				end
				--warn(`> Init finished {tostring(func.Name)} in {tick()-initFuncStart} seconds`)
			end
			--warn(`Finished loading order {ind} in {tick()-loadOrderStartLoad} seconds`)
		end
		
		for ind, orderList in ipairs(loadingOrders) do
			-- local loadOrderStartLoad = tick()
			--warn("Loading RunAfterInit loading order "..tostring(ind))
			for d, func in ipairs(orderList) do
				local initFuncStart = tick()
				--warn("> Running init "..tostring(func.Name), d)
				--warn(service.nonThreadTask(func.Runner))
				if func.RunAfterInit then
					func.Runner()
				end
				--warn(`> RunAfterInit finished {tostring(func.Name)} in {tick()-initFuncStart} seconds`)
			end
			--warn(`Finished RunAfterInit loading order {ind} in {tick()-loadOrderStartLoad} seconds`)
		end
		
		self.LoadInits = nil
	end,
	
	LoadDeps = function(self)
		local scriptSettings: {[any]: any} = server.ScriptSettings
		local checkDep; checkDep = function(dep)
			if dep:IsA"ModuleScript" then
				local name = dep:GetAttribute("Name") or dep.Name
				local ret = require(dep)

				if type(ret) == "function" then
					loadModule(dep, getEnv(nil, {script = dep}), false, true)

					if server[name] then
						self.Dependencies[name] = server[name]
					end
				elseif type(ret) == "table" then
					server[name] = setmetatable({},{
						__index = function(self, ind)
							local selected = ret[ind]

							if type(selected) == "function" then
								local funcWithServerEnv = setfenv(selected, getEnv(nil, {script = dep}))

								return funcWithServerEnv
							else
								return selected
							end
						end;
					})

					self.Dependencies[name] = server[name]
				end
			elseif dep:IsA"Folder" then
				for i, subDep in pairs(dep:GetChildren()) do
					if subDep:IsA"ModuleScript" then
						checkDep(subDep)
					end
				end
			end
		end

		for i,dep in pairs(server.DepsFolder:GetChildren()) do
			local ignore = dep:GetAttribute"Ignore"

			if not ignore then
				if dep:IsA"ModuleScript" then
					checkDep((scriptSettings.secureRun and dep) or dep)
				elseif dep:IsA"Folder" or dep:IsA"Model" then
					for d,insideDep in pairs(dep:GetChildren()) do
						checkDep((scriptSettings.secureRun and insideDep) or insideDep)
					end
				end
			end
		end
		
		self.LoadDeps = nil
	end,
	
	RunAfterCores = function(self)
		for i,core in pairs(serverCores) do
			local tab = server[core]

			if tab and tab.Init then
				tab.Init()
				tab.Init = nil
			end

			server.Cores[core] = tab
		end
		
		self.RunAfterCores = nil
	end,
	
	RunAfterDeps = function(self)
		for dep,ret in pairs(self.Dependencies) do
			if type(ret) == "table" then
				if ret.Init then
					ret.Init(getEnv())
					ret.Init = nil
				end
			end

			server.Dependencies[dep] = ret
		end
		
		self.RunAfterDeps = nil
	end,
	
	LoadClientPlugins = function(self)
		local isStudio = server.Studio
		local clientFolder = server.ClientFolder
		
		for i,plug in pairs(loadData.clientPlugins) do
			local clonePlug = plug

			if clonePlug then
				clonePlug.Name = if isStudio then plug.Name else service.getRandom()
				clonePlug.Parent = clientFolder.Plugins

				if not isStudio and (clonePlug:IsA"Folder" or clonePlug:IsA"Model") then
					for d,subPlug in pairs(clonePlug:GetChildren()) do
						subPlug.Name = service.getRandom()
					end
				end
			end
		end
		
		if not isStudio then
			for i,plug in pairs(clientFolder.Plugins:GetChildren()) do
				if plug:IsA"Folder" or plug:IsA"ModuleScript" then
					plug.Name = service.getRandom()
				end
			end
		end
	end,
	
	RunPlugins = function(self)
		local clientFolder = server.ClientFolder
		
		--warn("Loading plugins..")
		-- Run plugins
		for i,obj in pairs(loadData.serverPlugins) do
			local function scan(plug)
				local plugEnabled = plug:GetAttribute"Enabled"
				local plugDisabled = (plugEnabled~=nil and plugEnabled==false) or plug:GetAttribute"Disabled"
				local noEnvironment = plug:GetAttribute"NoEnvironment" or plug:GetAttribute"NoEnv"
				
				if not plugDisabled then
					server.Events.pluginAdded:fire(plug)
					local retPlug = loadModule(plug, {script = plug}, true, (noEnvironment and true))
					local moduleName = plug:GetAttribute("PluginName") or string.match(plug.Name, "[^%s]+")
					--warn("Loaded plugin "..moduleName)		 			
					
					if retPlug and moduleName then
						server.Events.pluginInitialized:fire(moduleName, retPlug, plug)
						server["_"..moduleName] = retPlug
					end
				end
			end
			
			if obj:IsA"Folder" or obj:IsA"Model" then
				local doIgnore = obj:GetAttribute("Ignore")
				
				if doIgnore then
					continue
				end
				
				for d,otherObj in pairs(obj:GetChildren()) do
					if otherObj:IsA"ModuleScript" then
						scan(otherObj)
					end
				end
			elseif obj:IsA"ModuleScript" then
				scan(obj)
			end
		end

		for i,element in pairs(loadData.uiElements) do
			local cloneElement = element:Clone()

			if cloneElement and cloneElement:IsA"ModuleScript" then
				local anotherElement = clientFolder.UI.Elements:FindFirstChild(cloneElement.Name)

				if anotherElement then
					warn("UI Element "..cloneElement.Name.." already exists from the UI elements folder. Try renaming it to something else.")
				else
					cloneElement.Parent = clientFolder.UI.Elements
				end
			end
		end

		for i,uiTheme in pairs(loadData.uiLibrary) do
			local themeFromFolder = clientFolder.UI.Library:FindFirstChild(uiTheme.Name)

			if not themeFromFolder then
				themeFromFolder = service.New("Folder", {
					Name = uiTheme.Name;
					Parent = clientFolder.UI.Library;
				})
			end

			for i, uiItem in pairs(uiTheme:GetChildren()) do
				local cloneItem = uiItem:Clone()

				if cloneItem and (cloneItem:IsA"ScreenGui" or cloneItem:IsA"GuiObject" or cloneItem:IsA"ModuleScript") then
					local anotherItem = clientFolder.UI.Library:FindFirstChild(cloneItem.Name)

					if anotherItem then
						warn("UI "..cloneItem.Name.." already exists from the UI library folder. Try renaming it to something else.")
					else
						cloneItem.Parent = themeFromFolder
					end
				end
			end
		end
	end,
	
	Loaders = {
		{
			Name = "Install events";
			Order = 1;
			Runner = function()
				for i,event in pairs({
					-- Player events
					"playerAdded";
					"playerRemoved";
					"playerKicked";
					"playerVerified";
					"playerCheckIn";
					"playerChatted";
					"characterAdded";

					"playerMuteOnAfkStatusChanged";

					"securityCheck";
					"scriptErrored";

					-- Role events
					"memberAddedInRole";
					"memberRemovedFromRole";

					-- Session events
					"sessionCreated";

					-- Music events
					"musicPlaying";
					"musicStopped";
					"musicVolChanged";

					-- Moderation events
					"banAdded";
					"banRemoved";
					"banCaseAdded";
					"banCaseResolved";
					
					"modKicked";
					"modChangedSlowmode";
					"serverLocked";
					"serverShutdown";

					-- Core events
					"globalInitialized";

					-- Command events
					"commandRan";
					"commandError";
					"commandFailError";

					-- Datastore events
					"datastoreCorrupted";
					"playerDataSaveError";

					-- Plugin events
					"pluginAdded";
					"pluginInitialized";

					-- Loader events
					"loaderFinished";
				}) do
					local sigEvent = server.Signal.new()
					server.Events[event] = service.metaRead(sigEvent:wrap())
				end
			end,
		};
		{
			Name = "Obfuscator";
			Order = 1;
			Runner = function()
				if settings.Obfuscate_Allow then
					service.trackTask("Obfuscate areas", true, function()
						wait(10) -- Wait 20 seconds for other startups

						local ignoreDescs = {}
						local gameChildren = game:children()

						for i,player in pairs(service.Players:GetPlayers()) do
							local char = player.Character

							ignoreDescs[player] = true

							if char then
								ignoreDescs[char] = true

								for d,charPart in pairs(char:GetDescendants()) do
									ignoreDescs[charPart] = true
								end
							end

							for d,otherDesc in pairs(player:GetDescendants()) do
								ignoreDescs[otherDesc] = true
							end
						end

						if settings.Obfuscate_AllAreas then
							for i,part in pairs(gameChildren) do
								if not ignoreDescs[part] then
									part.Name = service.getRandom(#part.Name>4 and #part.Name or 8)

									for d,otherPart in pairs(part:GetDescendants()) do
										if not ignoreDescs[otherPart] then
											otherPart.Name = service.getRandom(#otherPart.Name>4 and #otherPart.Name or 8)
										end
									end
								end
							end
						else
							for i,part in pairs(settings.Obfuscate_Areas) do
								if not ignoreDescs[part] then
									part.Name = service.getRandom(#part.Name>4 and #part.Name or 8)

									for d,otherPart in pairs(part:GetDescendants()) do
										if not ignoreDescs[otherPart] then
											otherPart.Name = service.getRandom(#otherPart.Name>4 and #otherPart.Name or 8)
										end
									end
								end
							end
						end
					end)
				end
			end,
		};
		{
			Name = "RolesCreation";
			Order = 1;
			Runner = function()
				local everyoneRole = server.Roles:get("everyone")

				if everyoneRole then
					everyoneRole.permissions["Use_Utility"] = (settings.utilityCommands and true) or false
					server.Roles.defaultPerms["Use_Utility"] = (settings.utilityCommands and true) or false

					for perm,bool in pairs(settings.DefaultRolePermissions) do
						everyoneRole.permissions[perm] = (bool and true) or false
						server.Roles.defaultPerms[perm] = (bool and true) or false
					end
				end
			end,
		};
		{
			Name = "Create Remote Network";
			Order = 2;
			Runner = function()
				-- Create the remote networks
				service.trackTask("RemoteNetworkCreation", false, server.Core.createRemote)
			end,
		};
		{
			Name = "ESS Private Server Check";
			Order = 3;
			Runner = function()
				if #game.PrivateServerId > 0 and game.PrivateServerOwnerId == 0 and not server.Studio then
					local Datastore = server.Datastore
					local privateServerId = game.PrivateServerId
					local privateServerData, privateServerKey = Datastore.read("PrivateServerProfile", privateServerId)
					if privateServerData then
						variables.essPrivateServer = true
						variables.privateServerData = privateServerData
						variables.privateServerKeyData = privateServerKey
						
						if not privateServerData.temporary then
							local startedSince = tick()
							service.loopTask("Private server update data", 120, function()
								privateServerData = Datastore.read("PrivateServerProfile", privateServerId)
								if type(privateServerData) == "table" then
									variables.privateServerData = privateServerData
								end
							end)
						else
							task.defer(Datastore.remove, "PrivateServerProfile", privateServerId)
						end
					end
				end
			end,
		};
		{
			Name = "Setup PolicyManager";
			Order = 4;
			Runner = function()
				server.PolicyManager:setup()
			end,
		};
		{
			Name = "PlayerHandler";
			Order = 4;
			Runner = function()
				local onStudio = server.Studio
				-- Load in the players and create the playerAdded & playerRemoved events
				for i,plr in pairs(service.getPlayers()) do
					local suc,ers = service.trackTask("_LOADING_EXISTINGCLIENT-"..plr.UserId, true, function()
						if onStudio then
							warn(`Loading player {plr.Name} ({plr.UserId}`) 
						end
						server.Process.playerAdded(plr)
						if onStudio then
							warn(`Loaded player {plr.Name} ({plr.UserId}`) 
						end
					end)
					
					if not suc then
						warn("Loading existing player "..plr.Name.." encountered an error: "..tostring(ers))
					end
				end

				-- Create process events
				service.rbxEvent(service.Players.PlayerAdded, service.triggerTask("PlayerAdded", true, server.Process.playerAdded))
				service.rbxEvent(service.Players.PlayerRemoving, service.triggerTask("PlayerRemoving", true, server.Process.playerRemoving))

				-- Start checking in with players
				service.threadTask(function()
					wait(30)

					service.loopTask("Players checkIn", 60, function()
						for i,plr in pairs(service.getPlayers()) do
							local cliData = server.Core.clients[plr]

							if cliData and cliData.verified and not cliData.checkingIn then
								server.Process.playerCheckIn(plr)
							end
						end
					end)
				end)
			end,
		};
		{
			Name = "PrivateServer";
			Order = 5;
			Runner = function()
				-- Private server check with commands and gear management
				if #game.PrivateServerId > 0 then
					service.threadTask(function()	
						local cmdsBlacklist = settings.PServer_CommandsBlacklist or {}
						local gearBlacklist = settings.PServer_GearBlacklist or {}

						for i,cmdName in pairs(cmdsBlacklist) do
							if type(cmdName) == "string" then
								local existingCmd = server.Commands.get(cmdName)

								if existingCmd then
									existingCmd.Disabled = true
								end
							end
						end

						for i,gearId in pairs(gearBlacklist) do
							if tonumber(gearId) then
								table.insert(variables.gearBlacklist, tonumber(gearId))
							end
						end
					end)
				end
			end,
		};
		{
			Name = "SavingLightingObjects";
			Order = 6;
			Runner = function()
				service.trackTask("Saving lighting objects", true, function()
					local allowedLightingClasses = {"Atmosphere", "Clouds", "Sky", "BloomEffect", "BlurEffect",
						"ColorCorrectionEffect", "DepthOfFieldEffect", "SunRaysEffect"
					}
					for i,object in pairs(service.Lighting:GetChildren()) do
						if table.find(allowedLightingClasses, object.ClassName) then
							local clone = object:Clone()

							if clone then
								table.insert(variables.lightingObjects, clone)
							else
								object.Archivable = true
								clone = object:Clone()
								object.Archivable = false

								if clone then
									table.insert(variables.lightingObjects, clone)
								end
							end
						end
					end
				end)
			end,
		};
		{
			Name = "MusicPlayer";
			Order = 7;
			Runner = function()
				if settings.musicPlayer_Enabled then
					for name,id in pairs(settings.musicPlayer_Songs) do
						if type(name) == "string" and type(id) == "number" then
							local nameHasDelimiter = name:find("%"..settings.delimiter)

							if nameHasDelimiter then
								warn("Music player warning: Song name "..name.." has a delimiter. Try making up another name instead!")
							else
								variables.musicSongs[name:lower()] = id
							end
						end
					end

					for name,playlist in pairs(settings.musicPlayer_Playlists) do
						if type(name) == "string" and type(playlist) == "table" then
							local nameHasDelimiter = name:find("%"..settings.delimiter)

							if nameHasDelimiter then
								warn("Music player warning: Playlist name "..name.." has a delimiter. Try making up another name instead!")
							else
								variables.musicPlaylists[name:lower()] = service.cloneTable(playlist)
							end
						end
					end
				end
			end,
		};
		{
			Name = "ChatTower";
			Order = 8;
			RunAfterInit = false;
			Runner = function()
				local Utility,Process,Moderation,Roles,Parser = server.Utility, server.Process, server.Moderation, server.Roles, server.Parser
				local chatPriority = {
					slashCommand = 5;
					muteCheck = 30;
					slowmode = 0;
				}
				
				local isUsingLegacyChat = service.TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService
				local setupSlashCommandsListener = function()
					local chatRunner = server.chatRunner
					local chatSpeaker = server.chatSpeaker
					local chatChannel = server.chatChannel
					local chatService = server.chatService

					local slashPrefix = "/"

					if slashPrefix:lower() == settings.actionPrefix:lower() or
						slashPrefix:lower() == settings.playerPrefix:lower() then
						warn("Unable to setup slash command listener if action/player prefix is the same as '"..tostring(slashPrefix).."'.")
						return
					end
					
					if isUsingLegacyChat then
						if chatRunner and chatSpeaker and chatChannel then
							local function commandProcessor(speakerName, message, channelName)
								local speaker = chatService:GetSpeaker(speakerName) if not speaker then return true end
								local player = speaker:GetPlayer()

								local didUsePrefix = message:sub(1,#slashPrefix) == slashPrefix

								if didUsePrefix then
									message = message:sub(#slashPrefix+1)

									if player and typeof(player) == "Instance" and player:IsA"Player" and Utility:checkRate(Process.chatProcessCommand_RateLimit, player.UserId) then
										local parsedPlayer = server.Parser:apifyPlayer(player)
										--missingArgType,missingArgReason
										local ran,cmdMatch,parserError,cmdErrorOrMissingArg,missingArgTypeOrErrMessage,missingArgReason,failedCmdArg = Process.playerCommand(
											parsedPlayer, message,
											{
												returnOutput = true;
												noPrefixCheck = true;
												noBatch = true;
												chatted = true;
												robloxChat = true;
											}
										)
										
										if ran == false then
											--speaker:SendSystemMessage("", channelName)
											if parserError == "Args_NotParsed" then
												local missingArgIndex = cmdErrorOrMissingArg
												local missingArgValueType = type(failedCmdArg)
												local missingArgParseType = missingArgTypeOrErrMessage or "string"
												local missingArgName = (missingArgValueType=="table" and failedCmdArg.argument) or "Arg"..missingArgIndex
												local missingArgNameAndType = "\""..tostring(missingArgName).."\"".." \""..(failedCmdArg.type or "n/a").."\""

												speaker:SendSystemMessage("[Command "..cmdMatch.."]: Missing argument "..tostring(missingArgIndex).." '"..missingArgParseType.."'", channelName, {
													ChatColor = Color3.fromRGB(255, 78, 78);
													Font = Enum.Font.SourceSansItalic;
												})

												return true
											elseif parserError == "Args_NotFilled" then
												speaker:SendSystemMessage("[Command "..cmdMatch.."]: Message arguments didn't fulfill the command arguments", channelName, {
													ChatColor = Color3.fromRGB(255, 78, 78);
													Font = Enum.Font.SourceSansItalic;
												})
											elseif parserError == "CmdError" then
												speaker:SendSystemMessage("[Command "..cmdMatch.."]: Function encountered an error: "..tostring(cmdErrorOrMissingArg), channelName, {
													ChatColor = Color3.fromRGB(255, 78, 78);
													Font = Enum.Font.SourceSansItalic;
												})
											elseif parserError == "CmdInaccessible" then
												local isCmdHidden = missingArgReason
												if (cmdErrorOrMissingArg == "ServerCooldown" or cmdErrorOrMissingArg == "PlayerCooldown" or cmdErrorOrMissingArg == "CrossCooldown") then
													speaker:SendSystemMessage("[Command "..cmdMatch.."]: Wait for "..tostring(missingArgTypeOrErrMessage).." to run this command again.", channelName, {
														ChatColor = Color3.fromRGB(255, 78, 78);
														Font = Enum.Font.SourceSansItalic;
													})
												elseif (cmdErrorOrMissingArg == "PlayerDebounce") then
													speaker:SendSystemMessage("[Command "..cmdMatch.."]: You must wait for the previous execution to finish before running this command", channelName, {
														ChatColor = Color3.fromRGB(255, 78, 78);
														Font = Enum.Font.SourceSansItalic;
													})
												elseif (cmdErrorOrMissingArg == "ServerDebounce") then
													speaker:SendSystemMessage("[Command "..cmdMatch.."]: You must wait for the previous execution from other players to finish before running this command", channelName, {
														ChatColor = Color3.fromRGB(255, 78, 78);
														Font = Enum.Font.SourceSansItalic;
													})
												elseif (cmdErrorOrMissingArg == "Chat") and not isCmdHidden then
													speaker:SendSystemMessage("[Command "..cmdMatch.."]: Incompatible to run in chat.", channelName, {
														ChatColor = Color3.fromRGB(255, 78, 78);
														Font = Enum.Font.SourceSansItalic;
													})
												elseif (cmdErrorOrMissingArg == "MissingPerms") and not isCmdHidden then
													speaker:SendSystemMessage("[Command "..cmdMatch.."]: Missing permissions to run this command: "..table.concat(missingArgTypeOrErrMessage, ", ")..".", channelName, {
														ChatColor = Color3.fromRGB(255, 78, 78);
														Font = Enum.Font.SourceSansItalic;
													})
												elseif (cmdErrorOrMissingArg == "MissingRoles") and not isCmdHidden then
													speaker:SendSystemMessage("[Command "..cmdMatch.."]: Missing roles to run this command: "..table.concat(missingArgTypeOrErrMessage, ", ")..".", channelName, {
														ChatColor = Color3.fromRGB(255, 78, 78);
														Font = Enum.Font.SourceSansItalic;
													})
												elseif (cmdErrorOrMissingArg == "Disabled") and not isCmdHidden then
													speaker:SendSystemMessage("[Command "..cmdMatch.."]: Disabled via developer setting.", channelName, {
														ChatColor = Color3.fromRGB(255, 78, 78);
														Font = Enum.Font.SourceSansItalic;
													})
												elseif (cmdErrorOrMissingArg == "CommandBlacklist") then
													speaker:SendSystemMessage("[Command "..cmdMatch.."]: Cannot perform due to command's blacklist system.", channelName, {
														ChatColor = Color3.fromRGB(255, 78, 78);
														Font = Enum.Font.SourceSansItalic;
													})
												elseif (cmdErrorOrMissingArg == "GlobalBlacklist") then
													speaker:SendSystemMessage("[Command "..cmdMatch.."]: Cannot perform due to in-game blacklist system.", channelName, {
														ChatColor = Color3.fromRGB(40, 40, 40);
														Font = Enum.Font.SourceSansItalic;
													})
												elseif (cmdErrorOrMissingArg == "RanTwice") then
													speaker:SendSystemMessage("[Command "..cmdMatch.."]: Cannot perform twice in the same batch.", channelName, {
														ChatColor = Color3.fromRGB(40, 40, 40);
														Font = Enum.Font.SourceSansItalic;
													})
												else
													if isCmdHidden then
														return false
													end
													
													speaker:SendSystemMessage("[Command "..cmdMatch.."]: Insufficient permissions or data.", channelName, {
														ChatColor = Color3.fromRGB(255, 78, 78);
														Font = Enum.Font.SourceSansItalic;
													})
												end

											elseif parserError == "InvalidCommand" then
												return false
											end

											return true
										elseif ran then
											local curChannel = chatService:GetChannel(channelName)

											if curChannel and not curChannel.Private then
												if ran == -1 then
													curChannel:SendSystemMessageToSpeaker(player.Name.." — "..tostring(cmdMatch), {
														ChatColor = Color3.fromRGB(152, 92, 255);
														Font = Enum.Font.SourceSansItalic;
													}, speakerName)
													return true
												end
												
												curChannel:SendSystemMessage(player.Name.." — "..tostring(cmdMatch), {
													ChatColor = Color3.fromRGB(110, 161, 255);
													Font = Enum.Font.SourceSansItalic;
												})
											end

											return true
										end
									end
								end

								return false
							end

							chatService:RegisterProcessCommandsFunction("_SLASH_COMMANDS_"..service.getRandom(), commandProcessor, chatPriority.slashCommand)
						else
							
						end
					else
						
					end
				end

				local setupChat = function()
					local chatRunner = service.getCSR()

					if not chatRunner then
						for i = 1,10,1 do
							chatRunner = service.getCSR()
							if not chatRunner then
								wait(.5)
							else
								break
							end
						end
					end

					local chatSpeaker = (chatRunner and chatRunner:FindFirstChild"Speaker")
					local chatChannel = (chatRunner and chatRunner:FindFirstChild"ChatChannel")
					local chatService = (chatRunner and chatRunner:FindFirstChild"ChatService")
					
					chatSpeaker = (chatSpeaker and require(chatSpeaker)) or nil
					chatChannel = (chatChannel and require(chatChannel)) or nil
					chatService = (chatService and require(chatService)) or nil

					server.chatRunner = chatRunner
					server.chatSpeaker = chatSpeaker
					server.chatChannel = chatChannel
					server.chatService = chatService

					if chatService then
						chatService:RegisterProcessCommandsFunction("_MUTE_CHECK_"..service.getRandom(), service.metaFunc(function(speakerName, msg, channelName)
							local speaker = chatService:GetSpeaker(speakerName)  if not speaker then return true end
							local player = speaker:GetPlayer() 

							if player then
								if variables.deaflist[player.UserId] then
									--local parsedPlayer = server.Parser:apifyPlayer(player)

									--if parsedPlayer then
									--	parsedPlayer:Kick("Suspicious chat exploit while deafened?")
									--end

									return true
								elseif variables.mutelist[player.UserId] then
									speaker:SendSystemMessage("You cannot talk in chat", channelName, {
										ChatColor = Color3.fromRGB(255, 123, 123);
										Font = Enum.Font.SourceSansItalic;
									})
									return true
								else
									local parsed = server.Parser:apifyPlayer(player)
									if parsed and parsed:getVar("MuteChat") then
										return true
									end
								end
							end

							return false
						end, true), chatPriority.muteCheck)

						if settings.chatSlowmode_Enabled then
							local slowmodeInterval = math.floor(math.clamp(settings.chatSlowmode_Interval, 0, math.huge))

							if slowmodeInterval > 0 then
								chatService:RegisterProcessCommandsFunction("_SLOWMODE_CHECK_"..service.getRandom(), service.metaFunc(function(speakerName, msg, channelName)
									local speaker = chatService:GetSpeaker(speakerName)  if not speaker then return true end
									local player = speaker:GetPlayer()

									if player then
										local slowmodeCache = variables.slowmodeCache[player.UserId]
										local canBypass = Moderation.checkAdmin(player) or Roles:hasPermissionsFromMember(player, {"Bypass_Chat_Slowmode"})
										local goodCheck = canBypass or not slowmodeCache or (os.time()-slowmodeCache >= slowmodeInterval)

										if not goodCheck then
											local timeData = Parser:getTime(slowmodeInterval-(os.time()-slowmodeCache))
											speaker:SendSystemMessage(string.format("Slow down! You can send another message in %s hours, %s minutes, & %s seconds.", timeData.hours, timeData.mins, timeData.secs), channelName, {
												ChatColor = Color3.fromRGB(255, 123, 123);
												Font = Enum.Font.SourceSansItalic;
											})

											return true
										else
											slowmodeCache = os.time()
											variables.slowmodeCache[player.UserId] = slowmodeCache
										end
									end

									return false
								end, true), chatPriority.slowmode)
							end
						end

						local publicChannel_Id = service.getRandom()
						local publicChannel = chatService:AddChannel(publicChannel_Id)

						if publicChannel then
							publicChannel.Leavable = false
							--publicChannel.Private = true
							publicChannel.AutoJoin = true

							server.publicChannel = publicChannel
							server.publicChannel_Id = publicChannel_Id
						end
					end
				end

				-- Setup connection with chat services
				if settings.chatAccess then
					service.trackTask("Chat Initial", true, function()
						setupChat()

						-- Create slash commands if allowed via settings
						if settings.chatCommands and settings.slashCommands then
							setupSlashCommandsListener()
						end
					end)
				end
			end,
		};	
		{
			Name = "TaskScheduler";
			Order = 9;
			Runner = function()
				-- Load automated routines/tasks
				if settings.automatedTasks_Enabled then
					service.threadTask(function()
						for i,autoTask in pairs(settings.automatedTasks) do
							if type(autoTask) == "table" then
								autoTask = service.cloneTable(autoTask)

								local taskName = autoTask.name or service.getRandom()
								local taskType = autoTask.type

								local invalidTask = false
								local taskData = {
									name = taskName;
									type = taskType;

									ran = server.Signal.new();
									started = os.time();
								}

								if taskType == "Map" then
									local loopInd = "MAP"..tostring(autoTask.mode).."_"..service.getRandom()
									local loopInt = math.floor(math.clamp(autoTask.interval, 20, math.huge))

									local taskMode = autoTask.mode
									local maxHold = math.floor(math.clamp(autoTask.maxHold, 1, math.huge))
									local mapMode
									local mapBackup

									if taskMode == "Save" or taskMode == "Refresh" then
										mapMode = taskMode
									elseif taskMode == "Load" then
										mapMode = taskMode
										mapBackup = server.Utility:makeMapBackup(nil, nil, {ignoreChars = not autoTask.saveCharacters})
									end	

									if mapMode then
										service.loopTask(loopInd, loopInt, function()
											if mapMode == "Save" then
												local mapBackups = variables.mapBackups
												if #mapBackups+1 > maxHold then
													table.clear(variables.mapBackups)
												end
												server.Utility:makeMapBackup()
											elseif mapMode == "Load" then
												if os.time()-taskData.started > 30 then
													server.Utility:loadMapBackup(nil, nil, nil, nil, mapBackup)
												end
											elseif mapMode == "Refresh" then
												if os.time()-taskData.started > 30 then
													server.Utility:loadMapBackup()
												end
											end

											taskData.nextRun = os.time()+loopInt
											taskData.lastRun = os.time()
											taskData.ran:fire()
										end)
									end
								elseif taskType == "Command" then
									local cmdInput = autoTask.command or ""
									local cmdArgs = autoTask.arguments
									local realCmd,cmdMatch = server.Commands.get(cmdInput)

									if not realCmd then
										warn("AutoTask "..taskName.." cannot loop execute a non-executable command: "..cmdInput)
										continue
									end

									local playerName = autoTask.playerName
									local loopInd = "LOOP_COMMAND_EXECUTE_"..service.getRandom()
									local loopInt = math.floor(math.clamp(autoTask.interval, 1, math.huge))

									if playerName ~= nil and type(playerName) ~= "string" then
										warn("AutoTask "..taskName.." is missing a valid 'playerName' string.")
										continue
									end

									if type(cmdArgs) ~= "table" and type(cmdArgs) ~= "string" then
										warn("AutoTask "..taskName.." is missing valid 'arguments' table/string.")
										continue
									end

									service.loopTask(loopInd, loopInt, function()
										local fakePlayer

										if playerName then
											local inGamePlayer = service.getPlayer(playerName)

											if inGamePlayer then
												fakePlayer = inGamePlayer
											end
										end

										local executed,errorTyp = server.Core.executeCommand(fakePlayer, cmdInput, cmdArgs)

										if not executed then
											warn("AutoTask "..taskName.." didn't perform the command "..tostring(cmdMatch).." successfully. Error: "..tostring(errorTyp))
											service.stopLoop(loopInd)
										else
											taskData.nextRun = os.time()+loopInt
											taskData.lastRun = os.time()
										end

										taskData.ran:fire()
									end)
								elseif taskType == "Function" then
									local loopInd = "EXECUTE_FUNCTION_"..service.getRandom()
									local loopInt = math.floor(math.clamp(autoTask.interval, 1, math.huge))

									local taskFunc = autoTask.Function
									service.loopTask(loopInd, loopInt, function()
										local suc,err = pcall(taskFunc)

										if not suc then
											warn("AutoTask "..taskName.." didn't perform successfully. Error: "..tostring(err))
											service.stopLoop(loopInd)
										else
											taskData.nextRun = os.time()+loopInt
											taskData.lastRun = os.time()
										end

										taskData.ran:fire()
									end)
								else
									invalidTask = true
								end

								if not invalidTask then
									table.insert(variables.scheduledTasks, taskData)
								end
							else
								warn("Automated task "..tostring(i).." doesn't have a table. Make sure to change its value to a table before attempting to run this in the next run.")
							end
						end
					end)
				end

				-- CUSTOM COMMAND CREATIONS
				if settings.customCommands_Enabled then
					for cmdName,cmdTab in pairs(settings.customCommands_List) do
						if type(cmdTab) ~= "table" then
							warn("CC "..tostring(cmdName).." doesn't have a table value. Make sure the custom command's value is a table before attempting to create it.")
						else
							local aliases = cmdTab.Aliases
							local arguments = cmdTab.Arguments
							local permissions = cmdTab.Permissions
							local cmdRoles = cmdTab.Roles
							local descrip = cmdTab.Description
							local cmdFunc = cmdTab.Function or cmdTab.Run or cmdTab.Execute

							assertWarn(type(aliases) == "table", 		"CC "..tostring(cmdName)..": ".."Invalid aliases provided, expected table")
							assertWarn(type(arguments) == "table", 		"CC "..tostring(cmdName)..": ".."Invalid arguments provided, expected table")
							assertWarn(type(permissions) == "table", 	"CC "..tostring(cmdName)..": ".."Invalid aliases provided, expected table")
							assertWarn(type(cmdRoles) == "table", 		"CC "..tostring(cmdName)..": ".."Invalid roles provided, expected table")
							assertWarn(type(descrip) == "table", 		"CC "..tostring(cmdName)..": ".."Invalid description, expected string")
							assertWarn(type(cmdFunc) == "table", 		"CC "..tostring(cmdName)..": ".."Invalid function, expected function")

							server.Commands.create("CC-"..tostring(cmdName), service.cloneTable(cmdTab))
						end
					end
				end
			end,
		};
		{
			Name = "DexExplorer";
			Order = 10;
			RunAfterInit = true;
			Runner = function()
				local protectedAreas = {
					service.ServerStorage;
					service.ServerScriptStorage;
				}
				local protectedClasses = {
					"ServerStorage";
					"ServerScriptStorage";
					"ReplicatedStorage";
				}
				
				local function checkSafeObject(object)
					if table.find(protectedClasses, object.ClassName) then
						return false
					end
					
					for i, area in pairs(protectedAreas) do
						if area == object or object:IsDescendantOf(area) then
							return false
						end
					end
					
					return true
				end
				
				local Remote = server.Remote
				
				local dexNetwork = Remote.newSubNetwork("DexNetwork")
				dexNetwork.easyFind = true
				dexNetwork.name = "DexNetwork"
				dexNetwork.remoteCall_Allowed = true
				dexNetwork.connectedPlayers = {}
				dexNetwork.securitySettings.canClientDisconnect = true
				--dexNetwork.allowedTriggers = {"@everyone"}
				
				local dexSession = Remote.newSession()
				dexSession.easyFind = true
				dexSession.name = "DexSession"
				dexSession.connectedPlayers = dexNetwork.connectedPlayers
				dexSession.allowedTriggers = dexNetwork.allowedTriggers
				dexSession.network = dexNetwork
				
				local dexManage = dexSession:makeCommand("ManageDex")
				dexManage.allowedTriggers = dexSession.allowedTriggers
				dexManage.connectedPlayers = dexSession.connectedPlayers
				dexManage.execute = function(plr, manageType: string, ...)
					if settings.dexEnabled then				
						local pData = (function()
							local globalData = plr:getPlayerData()
							local defDexData = {
								clipboard = {};
							}
							
							if not globalData then
								return defDexData
							else
								globalData.serverData.dexData = globalData.serverData.dexData or defDexData
								return globalData.serverData.dexData
							end
						end)()
						local args = {...};
						local Suppliments = args[1];

						if (manageType == "Destroy" or manageType == "Delete") and typeof(args[1]) == "Instance" and checkSafeObject(args[1]) then
							args[1]:Destroy();
							return true;
						elseif manageType == "ClearClipboard" then
							pData.clipboard = {};
							return true;
						elseif manageType == "Duplicate" and typeof(args[1]) == "Instance" and (args[2] == nil or typeof(args[2])=="Instance") then
							local obj = args[1];
							local par = args[2];
							
							if checkSafeObject(obj) and (not par or checkSafeObject(par)) then
								local new = obj:Clone()
								if new then
									new.Parent = par;
								end
								
								return new;
							end
						elseif manageType == "Copy" and typeof(args[1]) == "Instance" and checkSafeObject(args[1]) then
							local obj = args[1];
							local new = obj:Clone();
							
							if new then
								table.insert(pData.clipboard, new)
							end
							
							return new;
						elseif manageType == "Paste" and (args[1] == nil or (typeof(args[1])=="Instance" and checkSafeObject(args[1]))) then
							local parent = args[1];

							for i,v in pairs(pData.clipboard) do
								v:Clone().Parent = parent;
							end

							return true;
						elseif manageType == "SetProperty" and args[3] then
							local obj = args[1];
							local prop = args[2];
							local value = args[3];

							if typeof(obj)=='Instance' and type(prop)=='string' and checkSafeObject(obj) then
								obj[prop] = value;
								return true;
							end
						elseif manageType == "InstanceNew" and type(args[1]) == 'string' and (args[2] == nil or (typeof(args[2])=="Instance" and checkSafeObject(args[2]))) then
							return service.New(args[1], args[2]);
						elseif manageType == "CallFunction" then
							local rets = {pcall(function() return (args[1][args[2]](args[1])) end)}
							table.remove(rets,1)
							return rets
						elseif manageType == "CallRemote" and typeof(args[1]) == 'Instance' and checkSafeObject(args[1]) then
							if args[1]:IsA("RemoteFunction") then
								return args[1]:InvokeClient(table.unpack(args[2]))
							elseif args[1]:IsA("RemoteEvent") then
								args[1]:FireClient(table.unpack(args[2]))
							elseif args[1]:IsA("BindableFunction") then
								return args[1]:Invoke(table.unpack(args[2]))
							elseif args[1]:IsA("BindableEvent") then
								args[1]:Fire(table.unpack(args[2]))
							end
						end
					end
				end
				
				server.dexSession = dexSession
				server.dexNetwork = dexNetwork
			end,
		};
		{
			Name = "CMDR";
			Order = 11;
			RunAfterInit = false;
			Runner = function()
				
			end,
		};
	},
}