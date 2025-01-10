
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
local debug = debug
local delay = delay
local assert = assert
local task = task
local Random = Random
local utf8 = utf8
local curEnv = getfenv(1) setfenv(1, setmetatable({}, {__metatable = tostring(math.random(10000000))}))
local client = {}
local service = {}
local serviceSpecific = {}
local envLocals = {}
local locals = {}
local variables = {}

local clientFolder = script.Parent
local sharedFolder = clientFolder:FindFirstChild"Shared" or Instance.new("Folder")
local player = game:GetService("Players").LocalPlayer
local kickPlayer = player.Kick

local topbarIconTheme = require(clientFolder.Assets.TopbarIconTheme)

clientFolder = (clientFolder and clientFolder:Clone()) or nil
sharedFolder = (sharedFolder and sharedFolder:Clone()) or nil
local promiseModule = require(sharedFolder.Util.PromiseHelper)

local realWait = wait
local realTypeof = typeof
local realInstNew = Instance.new
local realRequire = require
local realRawset = rawset
local wait = task.wait -- require(sharedFolder.CustomWait:Clone())
local corotWrap = coroutine.wrap
local warn = function(...) warn("_: ESSC :_", ...) end
local print = function(...) print("_: ESSC :_", ...) end
local message = function(...) game:GetService("TestService"):Message("_: ESSC :_ " .. table.concat({...}, " ")) end
local pCall = function(func, ...) local rets = {pcall(func,...)} if not rets[1] then end return unpack(rets) end
local cPCall = function(func, ...) local rets = {pcall(coroutine.wrap(func), ...)} return unpack(rets) end
local routine = function(func, ...) return coroutine.resume(coroutine.create(func), ...) end
local rawset = function(tab, ind, val)
	assert(type(tab)=="table", "Argument 1 must be a table, got "..type(tab))
	assert(table.find({"string", "number", "userdata", "table"}, type(ind)), "Argument 2 must be a string/number/userdata/table, got "..type(ind))

	if not table.isfrozen(tab) then
		realRawset(tab, ind, val)
	else
		return -1
	end
end

local getEnv; getEnv = function(typ, exemptions)
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

local loadModule = function(module, envArgs, thread, noEnv, callArgs)
	local func = (type(module) == "function" and module) or require(module)
	func = (type(func)=="function" and func) or nil
	callArgs = (type(callArgs)=="table" and callArgs) or {}

	if func then
		--warn("Module "..tostring(module).." loaded")
		table.insert(client.Modules, module)

		local modEnv = (noEnv and getEnv("EnvLocals")) or getEnv(nil, envArgs)
		local rets

		if noEnv then
			rets = {service.trackTask(
				"_MODULE-"..tostring(module),
				thread, setfenv(func, modEnv),
				getEnv(nil, envArgs),
				unpack(callArgs)
				)}
		else
			rets = {service.trackTask(
				"_MODULE-"..tostring(module),
				thread, setfenv(func, modEnv),
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

service = setfenv(require(sharedFolder.Service), getEnv(nil, {script = sharedFolder.Service;}))(serviceSpecific, function(typ, ...)

end, promiseModule)

client = {
	Player = player;

	CodeId = service.getRandom(30);
	Started = os.time();
	
	Settings = {};
	ServerSettings = {};

	Events = {};
	Dependencies = {};
	Modules = {};
	DepsFolder = clientFolder.Dependencies;
	AssetsFolder = clientFolder.Assets;

	Disconnect = service.triggerTask(service.getRandom(), true, function(res)
		service.safeFunction(function()
			kickPlayer(player, res)
		end)()
	end);

	IsAlive = function()
		local NetworkClient = service.NetworkClient
		local replicator = NetworkClient:FindFirstChildOfClass"ClientReplicator"

		return if not replicator then false else true
	end,
}

do
	local Kill

	Kill = service.immutable(function(res)
		if client.Killed then
			task.spawn(client.Killed.Fire, client.Killed, res)	
		end

		if client.Network then
			task.spawn(client.Network.fire, client.Network, `Disconnect`, `Kill: {tostring(res)}`)
		end

		local Kill; Kill = function()
			pcall(corotWrap(function() kickPlayer(player, "ESSC: "..(res or "Killed client")) end))
			while true do
				pcall(task.spawn, function()
					pcall(task.spawn, function()
						pcall(task.spawn, function()
							while true do task.spawn(pcall, Kill()) end
						end)
					end)
				end)
			end
		end

		Kill()
	end);

	client.Kill = Kill;
end

client.Folder = clientFolder
client.Deps = client.Dependencies
client.ModuleCreator = sharedFolder.Util.ModuleCreator
client.TulirAES = require(sharedFolder.Crypto.TulirAES)
client.HashLib = require(sharedFolder.Crypto.HashLib)
client.Base64 = require(sharedFolder.Crypto.Base64)
client.LuaParser = require(sharedFolder.Crypto.LuaParser)
client.Compression = require(sharedFolder.Crypto.Compression)

client.Promise = promiseModule
client.Janitor = require(sharedFolder.Util.Janitor)
client.Signal = require(sharedFolder.Util.Signal)
client.Queue = require(sharedFolder.Util.Queue)
client.MaterialIcons = require(sharedFolder.Misc.MaterialIcons)
client.SpecialTextMarkdown = require(sharedFolder.Misc.SpecialTextMarkdown)

client.Killed = client.Signal.new()

-- Setup queue custom event
client.Queue.customEvent = client.Signal

client.FiOne = client.AssetsFolder.FiOne
client.Loadstring = function(bytecode, env)
	return require(client.FiOne:Clone())(bytecode, env or getEnv("EnvLocals"))
end

client.ScreenSize = Vector2.new(100, 100)
client.ScreenSizeUpdated = client.Signal.new()
client.TopbarIconTheme = service.cloneTable(topbarIconTheme)
topbarIconTheme = service.cloneTable(topbarIconTheme)

client.Ready = client.Signal.new()
client.Studio = service.RunService:IsStudio()

variables = {
	messages = {};
	lightingObjects = {};
	connectedSessions = {};
	effectUIs = {};

	userKeybinds = {};
	savedCustomKeybinds = {};
	
	maxAutoUpdateLists = 4;
	autoUpdatingNumberOfLists = 0;
	
	players = {
		admins = {};
		everyone = {};
	};
}

locals = {
	client = client;
	service = service;
	Settings = client.Settings;
	settings = client.Settings;
	clientStart = client.Started;
	print = print;
	warn = warn;
	variables = variables;
	loadModule = loadModule;
	getEnv = getEnv;
	message = message;
	pCall = pCall;
	cPCall = cPCall;
	routine = routine;
	Routine = routine;
	realWait = realWait;
}

os 						= service.specialWrap(os)
math 					= service.specialWrap(math)
table 					= service.specialWrap(table)
string 					= service.specialWrap(string)
coroutine 				= service.specialWrap(coroutine)
Instance 				= service.specialWrap(Instance)
Vector2 				= service.specialWrap(Vector2)
Vector3 				= service.specialWrap(Vector3)
CFrame 					= service.specialWrap(CFrame)
UDim2 					= service.specialWrap(UDim2)
UDim 					= service.specialWrap(UDim)
Ray 					= service.specialWrap(Ray)
Rect 					= service.specialWrap(Rect)
Faces 					= service.specialWrap(Faces)
Color3 					= service.specialWrap(Color3)
NumberRange 			= service.specialWrap(NumberRange)
NumberSequence 			= service.specialWrap(NumberSequence)
NumberSequenceKeypoint 	= service.specialWrap(NumberSequenceKeypoint)
ColorSequenceKeypoint 	= service.specialWrap(ColorSequenceKeypoint)
PhysicalProperties 		= service.specialWrap(PhysicalProperties)
ColorSequence 			= service.specialWrap(ColorSequence)
Region3int16 			= service.specialWrap(Region3int16)
Vector3int16 			= service.specialWrap(Vector3int16)
BrickColor 				= service.specialWrap(BrickColor)
TweenInfo 				= service.specialWrap(TweenInfo)
Axes 					= service.specialWrap(Axes)
game 					= service.specialWrap(game)
workspace 				= service.specialWrap(workspace)

Instance = {
	new = function(objType, parent, doWrap)
		return (doWrap and service.wrap(realInstNew(objType, service.unWrap(parent) or nil))) or realInstNew(objType, parent and service.unWrap(parent) or nil)
	end;
}

require = function(obj)
	local ret = realRequire(service.unWrap(obj))
	local retType = type(ret)

	if typeof(ret) == "Instance" then
		return service.wrap(ret, true)
	else
		return ret
	end
end

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
	DateTime = DateTime;
	MTI = client.MaterialIcons;
} do envLocals[ind] = loc locals[ind] = loc end

return service.newProxy{
	__metatable = "ESSC";
	__tostring = function() return "ESSC" end;
	__call = function(self, data)
		if type(data) ~= "table" then
			return "Invalid_Data"
		end
		
		local loadData = service.cloneTable(data)	
		client.LoadData = loadData
		
		local function screenSizeUpdate()
			if client.DynScreenSizeGui then
				local screenAbsoluteSize: Vector2 = client.DynScreenSizeGui.AbsoluteSize
				client.ScreenSize = screenAbsoluteSize
				client.ScreenSizeUpdated:fire(screenAbsoluteSize)
			end
		end
		
		local _setupDynamicSSDebounce = false;
		local function setupDynamicScreenSizeCheck()
			if not _setupDynamicSSDebounce then
				task.defer(function()
					if not _setupDynamicSSDebounce then
						_setupDynamicSSDebounce = true
						
						if client.DynScreenSizeGui then
							local dynGuiData = client.UI.getGuiData(client.DynScreenSizeGui)
							if dynGuiData then
								dynGuiData.unRegister()
							end
							
							service.Delete(client.DynScreenSizeGui, 1)
							client.DynScreenSizeGui = nil
						end

						if not client.DynScreenSizeGuiEvents then
							client.DynScreenSizeGuiEvents = client.Signal:createHandler()
						else
							client.DynScreenSizeGuiEvents:killSignals(`ObjectEvent`)
						end

						local dynGuiEvents = client.DynScreenSizeGuiEvents

						local dynScreenSizeGui = service.New("ScreenGui", {
							Name = "[E._.E]";
							ResetOnSpawn = false;
							Enabled = true;
						})
						dynScreenSizeGui:SetAttribute("Note", `THIS GUI IS INDESTRUCTIBLE. IT IS USED FOR CHECKING THE USER'S SCREEN SIZE`)
						
						local dynGuiData = client.UI.register(dynScreenSizeGui)
						dynGuiData.ignoreAloneState = true
						
						client.DynScreenSizeGui = dynScreenSizeGui
						
						local parentChange = dynGuiEvents.new(`ObjectEvent`)
						parentChange:linkRbxEvent(dynScreenSizeGui:GetPropertyChangedSignal"Parent")
						parentChange:connectOnce(function()
							if dynScreenSizeGui.Parent ~= service.playerGui then
								setupDynamicScreenSizeCheck()
							end
						end)
						
						local childAdded = dynGuiEvents.new(`ObjectEvent`)
						childAdded:linkRbxEvent(dynScreenSizeGui.ChildAdded)
						childAdded:linkRbxEvent(dynScreenSizeGui:GetPropertyChangedSignal"IgnoreGuiInset")
						childAdded:linkRbxEvent(dynScreenSizeGui:GetPropertyChangedSignal"ResetOnSpawn")
						childAdded:linkRbxEvent(dynScreenSizeGui:GetPropertyChangedSignal"Name")
						childAdded:linkRbxEvent(dynScreenSizeGui:GetPropertyChangedSignal"Enabled")
						childAdded:connectOnce(setupDynamicScreenSizeCheck)
						
						local absoluteSizeChanged = dynGuiEvents.new(`ObjectEvent`)
						absoluteSizeChanged:linkRbxEvent(dynScreenSizeGui:GetPropertyChangedSignal"AbsoluteSize")
						absoluteSizeChanged:connect(function()
							if dynScreenSizeGui.AbsoluteSize ~= client.ScreenSize then
								screenSizeUpdate()
							end
						end)
						
						dynScreenSizeGui.Parent = service.playerGui
						if dynScreenSizeGui.AbsoluteSize ~= client.ScreenSize then
							screenSizeUpdate()
						end
						
						_setupDynamicSSDebounce = false
					end
				end)
			end
		end

		local playerGui = player:FindFirstChildOfClass"PlayerGui"
		if not playerGui then
			local childAdded
			local eventTask = service.triggerTask("PlayerGui finder", true, function(child)
				if typeof(child) == "Instance" and service.objIsA(child, "PlayerGui") then
					playerGui = child
					serviceSpecific.playerGui = playerGui
					client.playerGui_Found:fire(child)
					childAdded:Disconnect()

					setupDynamicScreenSizeCheck()
				end
			end)

			childAdded = player.ChildAdded:connect(eventTask)
			client.playerGui_Found = client.Signal.new()
		else
			serviceSpecific.playerGui = playerGui

			setupDynamicScreenSizeCheck()
		end

		serviceSpecific.player = service.Players.LocalPlayer
		serviceSpecific.MaxPlayers = service.Players.MaxPlayers
		
		do
			local deviceType = nil
			local UIS = service.UserInputService

			if UIS.VREnabled then
				deviceType = "VR"
				client.vrDevice = true
				client.pcDevice = true
			elseif UIS.GamepadEnabled and service.GuiService:IsTenFootInterface() then
				deviceType = "Console"
				client.consoleDevice = true
			elseif UIS.TouchEnabled then
				deviceType = "Mobile"
				client.mobileDevice = true
			elseif UIS.KeyboardEnabled then
				deviceType = "PC"
				client.pcDevice = true
			else
				deviceType = "Unknown"
			end

			client.deviceType = deviceType
		end

		local dependencies = (function()
			local registered = {}

			for i,dep in pairs(client.DepsFolder:GetChildren()) do
				local ignore = dep:GetAttribute"Ignore"

				if not ignore then
					if dep:IsA"ModuleScript" then
						local name = dep:GetAttribute("Name") or dep.Name
						local ret = require(dep)

						if type(ret) == "function" then
							loadModule(dep, getEnv(nil, {script = dep}), false, true)

							if client[name] then
								registered[name] = client[name]
							end
						elseif type(ret) == "table" then
							client[name] = setmetatable({},{
								__index = function(self, ind)
									local selected = rawget(ret, ind)

									if type(selected) == "function" then
										local funcWithclientEnv = setfenv(selected, getEnv(nil, {script = dep}))

										return funcWithclientEnv
									else
										return selected
									end
								end;

								__newindex = function(self, ind, val)
									rawset(ret, ind, val)
								end;

								__metatable = name;
							})

							registered[name] = client[name]
						end
					end
				end
			end

			return registered
		end)()

		for dep,ret in pairs(dependencies) do
			if type(ret) == "table" then
				if ret.Init then
					ret.Init(getEnv())
					ret.Init = nil
				end
			end

			client.Dependencies[dep] = ret
		end

		for i,event in pairs({
			-- Player events
			"quickActionShown";
			"quickActionHidden";
			"quickActionReady";
		}) do
			local sigEvent = client.Signal.new()
			client.Events[event] = service.metaRead(sigEvent:wrap())
		end

		local function scanPlugin(plug, override: boolean?)
			local moduleName = plug:GetAttribute("PluginName") or string.match(plug.Name, "[^%a]+")
			
			local plugEnabled = plug:GetAttribute"Enabled"
			local plugDisabled = (plugEnabled~=nil and plugEnabled==false) or plug:GetAttribute"Disabled"
			local plugRunDelayTime = if type(plug:GetAttribute"RunDelay") == "number" then plug:GetAttribute"RunDelay" else 0
			local noEnvironment = plug:GetAttribute"NoEnvironment" or plug:GetAttribute"NoEnv"
			local afterNetworkConnection = plug:GetAttribute"RunAfterNetworkEstablished"

			if (not plugDisabled) or override then
				if afterNetworkConnection and not override then
					client.Network.Joined:connectOnce(service.triggerTask(`PLUG_${moduleName}`, false, function() scanPlugin(plug, true) end))
					return
				end

				task.delay(math.clamp(plugRunDelayTime, 0, 1200), function()
					local retPlug = loadModule(plug, {script = plug}, true, (noEnvironment and true))

					if retPlug and moduleName then
						client["_"..moduleName] = retPlug
					end
				end)
			end
		end
		
		for i,obj in pairs(clientFolder.Plugins:GetChildren()) do
			if obj:IsA"Folder" or obj:IsA"Model" then
				for d,otherObj in pairs(obj:GetChildren()) do
					if otherObj:IsA"ModuleScript" then
						scanPlugin(otherObj)
					end
				end
			elseif obj:IsA"ModuleScript" then
				scanPlugin(obj)
			end
		end

		-- Get Client Settings
		service.threadTask(function()
			local Settings, ProxySettingsTable = client.Settings, {}
			local ProxySettings = service.newProxy{
				__index = function(self, index)
					return ProxySettingsTable[index]
				end;

				__newindex = function(self, index, val)
					rawset(ProxySettingsTable, index, val)
					task.defer(function()
						client.Network:fire("ManageClientSettings", index, val)
					end)
				end,
			}

			client.ProxySettings = ProxySettings
			client.ProxySettingsTable = ProxySettingsTable

			setmetatable(Settings, {
				__index = function(self, ind)
					return ProxySettingsTable[ind]
				end,

				__newindex = function(self, ind, val)
					ProxySettings[ind] = val
				end,

				__tostring = function() return "Client settings" end;
				__metatable = "Client Settings";
			})

			local savedCliSettings = client.Remote.getClientSettings()
			for ind, val in pairs(savedCliSettings) do
				rawset(ProxySettingsTable, ind, val)
			end
			
			local savedServerSettings = client.Remote.getServerSettings({
				"Delimiter"
			})
			
			for ind, val in pairs(savedServerSettings) do
				rawset(client.ServerSettings, ind, val)
			end
		end)

		-- Thread trust check task
		service.threadTask(function()
			client.Network:trustCheck()

			-- Report device type to the server
			client.Network:fire("EditDeviceType", client.deviceType)
			
			-- Setup client policies
			client.Policies:setup()
			
			-- Warn client about disabled aliases, keybinds or shortcuts
			if client.Policies._clientPolicies.ALIASES_ALLOWED.value == false or client.Policies._clientPolicies.SHORTCUTS_ALLOWED.value == false or client.Policies._clientPolicies.CMD_KEYBINDS_ALLOWED.value == false then
				client.UI.construct("Context", {
					text = "Aliases, Shortcuts, and/or Keybinds may be disallowed according to your client policies.";
					expireOs = os.time()+6;
				})
			end
		end)

		-- Keybind listener
		service.threadTask(function()
			local userInputS: UserInputService = service.UserInputService

			userInputS.InputBegan:connect(function(inp,g)
				if not userInputS:GetFocusedTextBox() then
					if inp.UserInputType then
						for i,keybindData in pairs(variables.userKeybinds) do
							if keybindData.active and table.find(keybindData.keybinds, inp.UserInputType) then
								task.spawn(function()
									if keybindData:checkTrigger() then
										keybindData.triggered:fire()
									else
										--warn("can't trigger:", keybindData)
									end
								end)
							end
						end
					end

					if inp.KeyCode ~= Enum.KeyCode.Unknown then
						for i,keybindData in pairs(variables.userKeybinds) do
							if keybindData.active and table.find(keybindData.keybinds, inp.KeyCode) then
								task.spawn(function()
									if keybindData:checkTrigger() then
										keybindData.triggered:fire()
									else
										--warn("can't trigger:", keybindData)
									end
								end)
							end
						end
					end
				end
			end)
			
			client.Network.Joined:connectOnce(function()
				local createdCmdKeybinds = client.Network:get("GetCmdKeybinds") or {}
				for keybindName, keybindData in pairs(createdCmdKeybinds) do
					local keyCodeStringsToEnums = {}
					for i, hotkeyName in ipairs(keybindData.hotkeys) do
						table.insert(keyCodeStringsToEnums, Enum.KeyCode[hotkeyName])
					end

					--local cliKeybindData = client.Utility:makeKeybinds(`_PERSONALKEYBIND-{keybindName:lower()}`, keyCodeStringsToEnums, "PersonalKeybind", keybindName:lower())
					--cliKeybindData.holdDuration = keybindData.holdDuration or 0
					client.Utility.Keybinds:register(`CommandKeybind.{keybindName}`, {
						enabled = if keybindData.enabled == nil then true else keybindData.enabled or false;
						trigger = "CommandKeybind";
						commandKeybindId = keybindName;
						commandLine = keybindData.commandLine;
						holdDuration = keybindData.holdDuration or 0;
						keys = keyCodeStringsToEnums;
					})
				end
				
				local createdCustomKeybinds = client.Network:get("GetCustomKeybinds") or {}
				--warn('original:', createdCustomKeybinds)
				do
					for keybindId, hotkeys in createdCustomKeybinds do
						local newHotkeys = {}
						for i, hotkeyName in hotkeys do
							newHotkeys[i] = Enum.KeyCode[hotkeyName]
						end
						createdCustomKeybinds[keybindId] = newHotkeys
					end
				end
				
				variables.savedCustomKeybinds = createdCustomKeybinds
				--warn(`Saved custom keybinds:`, createdCustomKeybinds)
				
				for i, keybindData in client.Utility.Keybinds.registeredKeybinds do
					if keybindData._saveId and createdCustomKeybinds[keybindData._saveId] then
						local keyCodeNamesToEnum = {}
						for i, keyCodeName in ipairs(createdCustomKeybinds[keybindData._saveId]) do
							table.insert(keyCodeNamesToEnum, Enum.KeyCode[keyCodeName])
						end
						
						--warn(`keycodenamestoenum for custom keybind {keybindData._name}:`, keyCodeNamesToEnum)
						
						keybindData.keys = keyCodeNamesToEnum
						keybindData:cancelTrigger()
					end
				end
			end)
		end)

		-- Topbar check
		do
			local taskRets = {service.nonThreadTask(function()
				local getRandom = service.getRandom
				local tpIcon = client.UI.makeElement("TopbarIcon")
				tpIcon:setName(getRandom())
				tpIcon:setLabel(getRandom())
				tpIcon:setCaption(getRandom())
				tpIcon:destroy()
			end)}
			
			if not taskRets[1] then
				client.Kill()("FAILED TO CREATE TOPBAR ICONS. WHAT?")
				return
			end

			local topbarGui = (function()
				for i, item in pairs(service.playerGui:GetChildren()) do
					if item:IsA"ScreenGui" and item.Name == "TopbarStandard" then
						return item
					end
				end
			end)()

			if not topbarGui then
				client.Kill()("TOPBAR GUI IS MISSING. NO!")
			else
				local threadTask, nonThreadTask = service.threadTask, service.nonThreadTask
				local changeSig = client.Signal.new()
				local parentCheck = function()
					if not changeSig:wait(nil, 0.5) then
						if not topbarGui.Parent or topbarGui.Parent ~= service.playerGui then
							local didChange = changeSig:wait(nil, 120)
							if not didChange then
								local success, err = nonThreadTask(function()
									topbarGui.Parent = service.playerGui
								end)

								if not success then
									client.Kill()("TOPBAR GUI LOCKED? WHY?")
								end
							end
						end
					end
				end

				topbarGui:GetPropertyChangedSignal"Parent":Connect(function()
					changeSig:fire(true)
					threadTask(parentCheck)
				end)
				topbarGui:GetPropertyChangedSignal"Enabled":Connect(function()
					if not topbarGui.Enabled then
						topbarGui.Enabled = true
					end
				end)
				
				--for i = 1,25 do
				--	client.Utility.Notifications:create({
				--		title = `Notification {i}`;
				--		desc = "Okay";
				--		time = 300;
				--	})
				--	wait(math.random(1,5))
				--end
			end
		end

		client.Network.Abandoned:connect(function()
			local stOs = os.clock()
			repeat
				wait(.5)
			until
			client.Network:isReady() or (os.clock()-stOs > 120)

			if not client.Network:isReady() then
				client.Kill()("Main network disconnected")
			end
		end)

		client.Ready:fire(true)
		
		-- Watermark
		message(
			`\n------\n` ..
			`✔️ Essential Client successfully loaded.\n` ..	
			`Welcome {player.Name}! Essential founded by @trzistan in 2021.` ..
				`\n------`
		)
	end;
}