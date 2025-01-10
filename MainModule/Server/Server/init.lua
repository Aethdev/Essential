--=======================================================================
--
--	ESSENTIAL ADMIN
--	 > Made by trzistan
--
--	
--
--	-----------------------------------------------------
--

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
local curEnv = getfenv(1) setfenv(1, setmetatable({}, {__metatable = tostring(math.random(10000000))}))
local server = {}
local service = {}
local serviceSpecific = {}
local envLocals = {}
local locals = {}
local variables = setmetatable({}, {__tostring = function() return "ESS_SHARED" end; __metatable = true;})

local realModule = script.Parent.Parent
local modInit, modUtil = script.Handler, script.Util
local module = realModule:Clone()
local serverFolder, clientFolder = module.Server, module.Client
local sharedFolder = module:FindFirstChild"Shared" or Instance.new("Folder")
local promiseModule = require(sharedFolder.Util.PromiseHelper)

local realWait = wait
local realTypeof = typeof
local realRawset = rawset
local realPrint = print
local realWarn = warn
local wait = task.wait --require(sharedFolder.CustomWait:Clone())
local warn = function(...) warn("_: Essential :_", ...) end
local print = function(...) print("_: Essential :_", ...) end
local message = function(...) game:GetService("TestService"):Message("_: Essential :_ : " .. table.concat({...}, " ")) end
local assertWarn = function(checkMatch: any, message: string): boolean if not checkMatch then warn(message) return false else return true end end
local rawset = function(tab: {[any]: any}, ind: any, val: any)
	assert(type(tab)=="table", "Argument 1 must be a table, got "..type(tab))
	assert(table.find({"string", "number", "userdata", "table", "nil"}, type(ind)), "Argument 2 must be a string/number/userdata/table, got "..type(ind))

	if not table.isfrozen(tab) then
		realRawset(tab, ind, val)
	else
		return -1
	end
end

local getEnv; getEnv = function(typ: string, exemptions: {[any]: any}): {[any]: any}
	local exempts = (type(exemptions)=="table" and exemptions) or {}
	local onlyEnvLocals = rawequal(typ, "EnvLocals")
	local env = (type(typ)=="table" and typ)
	
	local envTab = setmetatable({},{
		__index = function(self, ind)
			local exempt = exempts[ind]
			
			if not rawequal(exempt, nil) then
				return exempt
			end
			
			if not onlyEnvLocals then
				local localInd = locals[ind]
				
				if not rawequal(localInd, nil) then
					return localInd
				end
				
				return curEnv[ind]
			else
				return envLocals[ind]
			end
		end,
		
		__tostring = function() return "EssentialEnv" end;
		__metatable = "EssentialEnv";
	})
	
	return envTab
end

local loadModule = function(module: ModuleScript?, envArgs: {[any]: any}, isThread: boolean, noEnv: boolean, callArgs: {[any]: any}): {[any]: any}
	local func = (type(module) == "function" and module) or require(module)
	func = (type(func)=="function" and func) or nil
	callArgs = (type(callArgs)=="table" and callArgs) or {}
	
	if func then
		--warn("Module "..tostring(module).." loaded")
		table.insert(server.Modules, module)
		
		local modEnv: {[any]: any} = (noEnv and getEnv("EnvLocals")) or getEnv(nil, envArgs)
		local rets: {[any]: any}
		
		if noEnv then
			rets = {service.trackTask(
				"_MODULE-"..tostring(module),
				isThread, setfenv(func, modEnv),
				getEnv(nil, envArgs),
				unpack(callArgs)
			)}
		else
			rets = {service.trackTask(
				"_MODULE-"..tostring(module),
				isThread, setfenv(func, modEnv),
				unpack(callArgs)
			)}
		end
		
		if not rets[1] then
			if #rets == 1 then
				warn("Module "..tostring(module).." encountered an unknown error")
			else
				warn("Module "..tostring(module).." encountered an error:", unpack(rets, 2))
			end
		end
		
		return unpack(rets)
	end
end

local scriptSettings: any = {
	secureRun = true;
}

local cleanUp: nil = function()
	warn("Cleaning up the server and system..")
	
	server.Running = false
	
	local network = server.Network
	
	-- Stop all networks
	if network then
		--network.stopAll()
		
		if server.Core and server.Logs and server.Parser and not server.Studio then
			for i, replicator in pairs(network.getReplicators()) do
				local player = replicator.player
								
				if player then
					local pData = server.Core.getPlayerData(player.UserId)
					local cliData = server.Core.clients[player]
					
					if pData then
						-- Register players abandon activity
						do
							local activityLogs = pData.__activityLogs

							local serverId = (server.Studio and "[studio server]") or game.JobId
							local serverType = (game.PrivateServerOwnerId>0 and "[personal]") or (#game.PrivateServerId>0 and "[private]") or
								(server.Studio and "[studio]") or "[public]"
							
							activityLogs._pushToSet(server.Logs.formatLog({
								title = "Abandoned a closed server "..serverType.." "..serverId;
								desc = "Duration: "..server.Parser:formatTime(os.time()-(pData.serverData.joined or os.time()));
							}))
							activityLogs._recognize()
							--warn("cleanup comes first?")
						end
						
						coroutine.wrap(function()
							pData._forceUpdate()
						end)()
					end
				end
			end
		end
	end
	
	--if variables.serverInfo and variables.serverDataId then
	--	server.Datastore.tableRemove(nil, "runningServers", "entryFromId", variables.serverDataId)
	--end
	
	if server.Closing then
		server.Closing:fire(os.time())
	end
	
	-- Update all datastore sync tables before we end clean up
	--local datastore = server.Datastore
	
	--for i,syncTable in pairs(datastore.sharedTables) do
	--	local backup = syncTable._getBackup() or {}
		
	--	if not service.checkEquality(syncTable, backup) then
	--		syncTable._sync(true)
	--	end
	--end
	
	if server.privateServer_Profile then
		server.privateServer_Profile:Release()
	end
	
	warn("Cleaned up successfully!")
end

service = setfenv(require(sharedFolder.Service), getEnv(nil, {script = sharedFolder.Service;}))(
	serviceSpecific,
	function(typ, ...)

	end,
	promiseModule
)

server = {
	ScriptSettings = service.metaRead(scriptSettings);
	
	Folder = serverFolder;
	Client = clientFolder;
	Started = os.time();

	Cores = {};
	Modules = {};
	Dependencies = {};
	Settings = {};
	Events = {};
	Assets = {};
	AssetFolder = serverFolder.Assets;
	DepsFolder = serverFolder.Dependencies;
	SharedFolder = sharedFolder;
	MainFolder = serverFolder.Main;
	ClientFolder = clientFolder;
	
	Studio = service.RunService:IsStudio();
}

server.TulirAES = require(sharedFolder.Crypto.TulirAES)
server.HashLib = require(sharedFolder.Crypto.HashLib)
server.Base64 = require(sharedFolder.Crypto.Base64)
server.LuaParser = require(sharedFolder.Crypto.LuaParser)
server.Compression = require(sharedFolder.Crypto.Compression)

server.Promise = promiseModule
server.Janitor = require(sharedFolder.Util.Janitor)
server.Signal = require(sharedFolder.Util.Signal)
server.Queue = require(sharedFolder.Util.Queue)
server.MaterialIcons = require(sharedFolder.Misc.MaterialIcons)
server.SpecialTextMarkdown = require(sharedFolder.Misc.SpecialTextMarkdown)

server.NameGeneration = require(server.AssetFolder.NameGeneration)
server.Loadstring = require(server.AssetFolder.Loadstring)
server.LoadstringMod = server.AssetFolder.Loadstring
server.MockDataStoreService = require(server.AssetFolder.MockDataStoreService)


-- Setup queue custom event
server.Queue.customEvent = server.Signal

-- Setup signal and queue custom waits
server.Queue.customWait = wait
server.Signal.customWait = wait

server.Closing = service.metaRead(server.Signal.new():wrap())

variables = {
	donorAssets = {
		{
			Type = "Gamepass";
			Id = 16590430;
		};
		{
			Type = "Asset";
			Id = 7914649578;
		}
	};

	whitelistData = {
		enabled = false;	
		moderator = {
			name = "SYSTEM";
			userid = -1;
		};
		reason = nil;
		whitelisted = {}; -- List of people who are whitelisted
		admins = false; -- Only admins can join
		started = nil;
	};
	
	blockSettings = {
		Permissions = true;
		DefaultRolePermissions = true; 
		BanList = true;
		automatedTasks = true;
		customCommands_List = true;
		
		Datastore_EncryptKeys = true;
		Datastore_ProtectIndex = true;
		Datastore_EncryptKey = true;
		Datastore_Key = true;
		Datastore_Scope = true;
		Datastore_PlayerData = true;
		
		MemoryStore_Key = true;
		MemoryStore_PlayerData = true;
		
		CrossAPI_Key = true;
		globalApi_Tokens = true;
		globalApi_Perms = true;
	};
	
	serverCreationSettings = {
		maxCreation = 50;
		reserveListName = "ReservedServers_2.4";
		reserveMaxWhitelistsAndBlacklists = 20;
	};
	
	-- SAVED GRAVITY SETTINGS
	savedEnvironment = {
		gravity = workspace.Gravity;
		ambient = service.Lighting.Ambient;
		outdoorAmbient = service.Lighting.OutdoorAmbient;
		brightness = service.Lighting.Brightness;
		gameTime = service.Lighting.ClockTime;
	};
	
	-- SERVER KNOWN SETTINGS
	defaultChatEnabled = service.Players.ClassicChat;
	
	mapObjects = {};
	lightingObjects = {};
	
	sizedCharacters = {};
	
	mutelist = {};
	deaflist = {};
	slowmodeCache = {};
	
	gearBlacklist = {};
	commandBlacklist = {};
	
	musicSongs = {};
	musicPlaylists = {};
	
	music_nowPlaying_name = "";
	music_nowPlaying_id = 0;
	
	privateMessages = {};
	pollSessions = {};
	
	customEvents = {};
	crossEvents = {};
	
	jailedPlayers = {};
	
	loopingCmds = {};
	
	mapBackups = {};
	scheduledTasks = {};
}

locals = {
	server = server;
	service = service;
	print = print;
	warn = warn;
	settings = settings;
	message = message;
	assertWarn = assertWarn;
	vars = variables;
	variables = variables;
	loadModule = loadModule;
	realWait = realWait;
	getEnv = getEnv;
	typeof = service.typeof;
	realPrint = realPrint;
	realWarn = realWarn;
}

for ind,loc in next,{
	assert = assert;
	delay = delay;
	_G = _G;
	game = game;
	spawn = spawn;
	debug = debug;
	getfenv = getfenv;
	setfenv = setfenv;
	workspace = workspace;
	getmetatable = getmetatable;
	setmetatable = setmetatable;
	loadstring = loadstring;
	coroutine = coroutine;
	rawequal = rawequal;
	typeof = typeof;
	print = print;
	math = math;
	warn = warn;
	error = error;
	pcall = pcall;
	xpcall = xpcall;
	select = select;
	rawset = rawset;
	rawget = rawget;
	ipairs = ipairs;
	pairs = pairs;
	next = next;
	Rect = Rect;
	Axes = Axes;
	os = os;
	tick = tick;
	Faces = Faces;
	unpack = unpack;
	string = string;
	Color3 = Color3;
	newproxy = newproxy;
	tostring = tostring;
	tonumber = tonumber;
	Instance = Instance;
	TweenInfo = TweenInfo;
	BrickColor = BrickColor;
	NumberRange = NumberRange;
	ColorSequence = ColorSequence;
	NumberSequence = NumberSequence;
	ColorSequenceKeypoint = ColorSequenceKeypoint;
	NumberSequenceKeypoint = NumberSequenceKeypoint;
	PhysicalProperties = PhysicalProperties;
	Region3int16 = Region3int16;
	Vector3int16 = Vector3int16;
	elapsedTime = elapsedTime;
	require = require;
	table = table;
	type = type;
	wait = wait;
	Enum = Enum;
	UDim = UDim;
	UDim2 = UDim2;
	Vector2 = Vector2;
	Vector3 = Vector3;
	Region3 = Region3;
	CFrame = CFrame;
	Ray = Ray;
	task = task;
	RaycastParams = RaycastParams;
	Random = Random;
	utf8 = utf8;
	_VERSION = _VERSION;
	DateTime = DateTime;
	rawlen = rawlen;
} do envLocals[ind] = loc locals[ind] = loc end

return service.newProxy{__metatable = "Essential"; __tostring = function() return "Essential" end; __call = function(self, data)
	assert(type(data) == "table", "Loader data isn't a table ("..type(data).." received)")
	
	local loaderData = service.cloneTable(data)
	local existingG = rawget(_G, "_ESSENTIAL_LOADER")
	
	if existingG and type(existingG) == "string" then
		service.TestService:Message(
			"\n-----------\n"..
			"- ESSENTIAL LOADER\n"..
			" \n"..
			"ESSENTIAL IS ALREADY RUNNING FROM ANOTHER SCRIPT ("..existingG:upper()..")\n"..
			"-----------\n"
		)
		
		return -1
	else
		rawset(_G, "_ESSENTIAL_LOADER", script:GetFullName())
	end
	
	if not service.NetworkServer then
		error("Cannot run server while running in test mode", 0)
		return
	end
	
	-- Utilizating some stuff first
	local serverSettings = service.cloneTable(data.Settings or {})
	--warn("ServerSettings;", serverSettings)
	
	locals.settings = serverSettings
	locals.Settings = serverSettings
	server.Settings = serverSettings
	settings = serverSettings
	server.Running = true
	server.LoaderData = loaderData
	server.soundName = "_ESS_SOUND-"..service.getRandom()
	
	-- Rojo status
	server.RojoEnabled = loaderData.RojoEnabled

	-- Server info
	local serverInfo = {
		id = game.JobId;
		privateId = game.PrivateServerId;
		type = (server.Studio and "[studio]") or (game.PrivateServerOwnerId>0 and "[personal]") or (#game.PrivateServerId>0 and "[private]") or
			"[public]";

		private = (#game.PrivateServerId>0 and true);
		studio = (server.Studio and true);
		started = tick();
	}
	
	serverInfo.detailedName = if server.Studio then `[studio-{game.PlaceId}]` else serverInfo.type.." "..(#serverInfo.privateId > 0 and serverInfo.privateId or serverInfo.id)
	
	variables.serverInfo = serverInfo
	
	-- Service specifics
	if game.GameId == 0 or settings.Datastore_Allow ~= true then
		settings.Datastore_Allow = false
		serviceSpecific.DataStoreService = require(server.MainFolder.MockDataStoreService)
	end
	
	serviceSpecific.getPlayers = function(parsePlayers, includeGhosts)
		local results = {}
		
		for i,plr in pairs(service.Players:GetPlayers()) do
			table.insert(results, plr)
		end
		
		if includeGhosts then
			for i,rep in pairs(server.Network:getReplicators()) do
				local player = rep.player
				if player and not table.find(results, player) then
					table.insert(results, player)
				end
			end
		end
		
		if parsePlayers and server.Parser then
			for i,plr in pairs(results) do
				results[i] = server.Parser:apifyPlayer(plr)
			end
		end
		
		return results
	end
	
	serviceSpecific.getPlayersByList = function(parsePlayers, list)
		local results = {}	

		for i,plr in pairs(service.Players:GetPlayers()) do
			if table.find(list, plr.UserId) or table.find(list, plr.Name) then
				table.insert(results, plr)
			end
		end

		if parsePlayers and server.Parser then
			for i,plr in pairs(results) do
				results[i] = server.Parser:apifyPlayer(plr)
			end
		end

		return results
	end
	
	for i,asset in pairs(server.AssetFolder:GetChildren()) do
		server.Assets[asset.Name] = asset
	end
	
	local initUility = require(modUtil)
	local utilityEnvironment: {[any]: any} = getEnv(nil, {script = initUility})
	
	initUility:Init(utilityEnvironment)
	initUility:Apply(server)
	
	local initPackage: {[any]: any} = require(modInit)
	local initEnvironment: {[any]: any} = getEnv(nil, {script = modInit})
	
	local initDisablePlugins = loaderData.disablePlugins
	
	initPackage:Init(initEnvironment)
	initPackage:LoadDeps()
	initPackage:LoadCores()

	initPackage:RunAfterDeps()	
	initPackage:RunAfterCores()
	
	if not initDisablePlugins then
		initPackage:LoadClientPlugins()
	end
	
	initPackage:LoadInits()	
	
	-- Create Essential global in _G
	if settings.globalApi_Allow then
		server.Core.createGlobal()
		for token,perms in pairs(settings.globalApi_Tokens) do
			local tokenInfo = server.Core.generateGlobalToken(token)
			tokenInfo.accessPerms = service.cloneTable(perms)
			tokenInfo.canAccessPrivateTable = (perms.Default and perms.Default.Access and true)
		end
	end
	
	if not initDisablePlugins then
		initPackage:RunPlugins()
	end
	
	variables.whitelistData.enabled = serverSettings.Whitelist_Enabled
	variables.whitelistData.reason = "No reason specified"
	if serverSettings.Whitelist_Enabled then
		variables.whitelistData.moderator = {
			name = "Developer Setting";
			userid = -1;
		}
		variables.whitelistData.reason = "Developer setting"
		variables.whitelistData.started = os.time() 
	end
	
	variables.serverLock  = serverSettings.ServerLock
	variables.LockMessage = serverSettings.lockMessage
	
	---- Run initializers
	--for i,initModule in pairs(serverFolder.Initializers:GetChildren()) do
	--	if initModule:IsA"ModuleScript" then
	--		initModule = initModule:Clone()
			
	--		if initModule then
	--			loadModule(initModule, {script = initModule}, false, true)
	--		end
	--	end
	--end
	
	-- Load saved settings
	if settings.allowSavedSettings then
		service.threadTask(function()
			local savedSettings = server.Datastore.read(nil, "savedSettings")
			
			if type(savedSettings) ~= "table" then
				savedSettings = {}
				server.Datastore.overWrite(nil, "savedSettings", savedSettings)
			end
			
			server.Core.loadSavedSettings(savedSettings)
		end)
	end
	
	-- Bind to close
	game:BindToClose(cleanUp)
	
	server.Events.loaderFinished:fire(true)
	
	script:Destroy()
	
	return "LOADED"
end;}