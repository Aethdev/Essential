local StarterPlayer = game:GetService("StarterPlayer")
--=======================================================================
--
--	ESSENTIAL ADMIN CLIENT LOADER
--	 > Made by trzistan
--
--		- Handles the client loading files
--	-----------------------------------------------------
--

--// Localize services
local GetService = game.GetService
local TestService: TestService = GetService(game, "TestService")
local RunService: RunService = GetService(game, "RunService")
local ReplicatedStorage: ReplicatedStorage = GetService(game, "ReplicatedStorage")
local ReplicatedFirst: ReplicatedFirst = GetService(game, "ReplicatedFirst")
local Players: Players = GetService(game, "Players")

--[[ SETUP EXISTING PLAYERS ]]
if script.Name == `QuickSetupECLI` then
	local otherScript = StarterPlayer.StarterPlayerScripts:WaitForChild("ESSCLI")
	otherScript.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerScripts")
	otherScript.Disabled = false

	return
end

if _G._ESSCLILOAD then return end
_G._ESSCLILOAD = true

--// Important variables
local script: Script = script
local _G = _G
local DateTime = DateTime

--// Important functions
local realError = error
local realPrint = print
local realWarn = warn
local freezeTable = table.freeze

local debugAllowed = script:GetAttribute("Debug") == true or RunService:IsStudio()
local loaderLogs = {}
local function print(isDebug: boolean, ...)
	if not isDebug or isDebug and debugAllowed then
		realPrint("_: ESSC LOADER :_", ...)
	end

	table.insert(loaderLogs, {
		Started = DateTime.now();
		Type = "Print";
		Debug = isDebug and true or false;
		Arguments = table.freeze{...};
	})
	
	return nil
end
local function warn(isDebug: boolean, ...)
	if not isDebug or isDebug and debugAllowed then
		realWarn("_: ESSC LOADER :_", ...)
	end

	table.insert(loaderLogs, {
		Started = DateTime.now();
		Type = "Warn";
		Debug = isDebug and true or false;
		Arguments = table.freeze{...};
	})
	
	return nil
end
local function error(isDebug: boolean, ...)
	table.insert(loaderLogs, {
		Started = DateTime.now();
		Type = "Error";
		Debug = isDebug and true or false;
		Arguments = table.freeze{...};
	})

	if not isDebug or isDebug and debugAllowed then
		return realError("_: ESSC LOADER :_", ...)
	end
	
	return nil
end

local function testError(isDebug: boolean, ...)
	table.insert(loaderLogs, {
		Started = DateTime.now();
		Type = "Error";
		Debug = isDebug and true or false;
		Arguments = table.freeze{...};
	})

	if not isDebug or isDebug and debugAllowed then
		return TestService:Error("_: ESSC LOADER :_ " .. tostring(({...})[1]))
	end
	
	return nil
end

local EssentialFolder = ReplicatedStorage:FindFirstChild("EssentialClient")
local copyOfEssentialFolder;
if not EssentialFolder then
	testError(false, `Essential Client folder is missing!`)
	return
end

--// Make sure all the assets in Essential folder are archivable
do
	for i, part in pairs(EssentialFolder:GetDescendants()) do
		part.Archivable = true
		if not part.Archivable then
			testError(false, `Essential Folder is not safe for use due to an interference with a third party script.`)
			return
		end
	end

	copyOfEssentialFolder = EssentialFolder:Clone()
	if not copyOfEssentialFolder then
		testError(false, `Essential Folder is not safe for use due to an interference with a third party script.`)
		return
	end
end

wait(0.5)
EssentialFolder.Parent = nil
script:Destroy()

local Initializer = copyOfEssentialFolder:FindFirstChild("Runner")
if not Initializer or not Initializer:IsA("ModuleScript") then
	testError(false, `Initializer is missing!`)
	return
end

local runSuccess, runResult = pcall(require, Initializer)

if not runSuccess then
	testError(false, `Initializer encountered an error: {runResult}`)
	return
elseif type(runResult) ~= "userdata" or getmetatable(runResult) ~= "ESSC" then
	testError(false, `Initializer returned a user data that isn't signed by Essential Client. Tampered?`)
	return
end

do
	local errorTrace, errorMessage = "", ""
	local loadSuccess, loadResult = xpcall(runResult, function(failMsg)
		errorTrace = debug.traceback(nil, 2)
		errorMessage = failMsg
	end, {
		VerifyId = Players.LocalPlayer:GetAttribute("ESSVerifyId") or "",
	})

	if not loadSuccess then
		testError(false, `Initializer encountered an error in the process of loading: {loadResult}`)
		testError(true, `Initializer encountered an error: {errorMessage}\n{errorTrace}`)
	end
end