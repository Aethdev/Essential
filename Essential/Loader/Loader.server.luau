
local SS = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local loaderScript = script
local model = loaderScript.Parent.Parent
local settings = model:FindFirstChild"Settings"
local startLoad = os.time()

local loadData = {
	Asset = if SS:FindFirstChild("Essential") then SS.Essential:FindFirstChild("MainModule") else model:FindFirstChild("MainModule");
	RojoEnabled = model:GetAttribute("Rojo") == true,
	
	Model = model;
	Loader = loaderScript;
	
	disablePlugins = true; -- DEBUG
}

loadData.Asset.Name = "._."
loadData.Asset.Parent = model

-- Hiding loader
script:Destroy()

-- Checking main assets of the loader model (Commands, Plugins & Themes)
local themes = model:FindFirstChild"Themes"
local plugins = model:FindFirstChild"Plugins"
local uiFolder = model:FindFirstChild"UIs"
local serverPlugins = {}
local clientPlugins = {}
local uiElements = {}
local uiLibrary = {}
if not themes then warn("_EssentialL_ :: Themes folder is missing"); return end
if not plugins then warn("_EssentialL_ :: Plugins folder is missing"); return end
if not uiFolder then warn("_Esssential: :: UI folder is missing"); return end

if not loadData.disablePlugins then
	for i,plug in pairs(plugins.Client:GetChildren()) do
		local clonePlug = plug
		
		if clonePlug then
			table.insert(clientPlugins, clonePlug)
		end
	end

	for i,plug in pairs(plugins.Server:GetChildren()) do
		local clonePlug = plug

		if clonePlug then
			table.insert(serverPlugins, clonePlug)
		end
	end
end

for i,element in pairs(uiFolder.Elements:GetChildren()) do
	local cloneElement = element:Clone()
	
	if element then
		table.insert(uiElements, cloneElement)
	end
end

for i,uiItem in pairs(uiFolder.Library:GetChildren()) do
	local cloneItem = uiItem:Clone()

	if cloneItem then
		table.insert(uiLibrary, cloneItem)
	end
end

loadData.serverPlugins = serverPlugins
loadData.clientPlugins = clientPlugins
loadData.uiLibrary = uiLibrary
loadData.uiElements = uiElements

-- Acquiring settings
if not (function()
	if not settings or not settings:IsA"ModuleScript" then
		warn("_EssentialL_ :: Settings instance is not a ModuleScript or doesn't exist.")
		return
	end
	
	local suc,sets = pcall(require, settings)
	
	if not suc then
		warn("_EssentialL_ :: Settings encountered an error:", sets)
		return
	end
	
	if type(sets) ~= "table" then
		warn("_EssentialL_ :: Settings didn't return a table")
		return
	end
	
	-- Adds settings to loadData
	loadData.Settings = sets
	settings = sets
	
	return true
end)() then -- Checks to see whether it returned properly or not
	return -- Return if it returned false
end 

-- Checking and loading loader
local suc, loader = pcall(require, loadData.Asset)
-- Adds settings to loadData

if not suc then
	warn("_EssentialL_ :: Requiring loader module encountered an error:", loader)
elseif suc and not loader then
	warn("_EssentialL_ :: Loader module didn't return anything?")
elseif suc and loader then
	if type(loader) ~= "userdata" then
		warn("_EssentialL_ :: Loader module didn't return userdata")
	else
		local origName = model.Name
		model.Name = "_LOADING-"..math.random(1000000)
		
		local rets = {pcall(loader, loadData)}
		
		if not rets[1] then
			warn("_EssentialL_ :: Loader module encountered an error:", rets[2])
		elseif rets[2] == "LOADED" then
			if settings.HideLoader or settings.hideLoader then
				model.Parent = nil
			end
			
			loadData.Asset.Parent = nil
			Debris:AddItem(loadData.Asset, 5)
			
			model.Name = origName
			warn("_EssentialL_ :: Loaded ("..(os.time()-startLoad).." seconds)")
		else
			warn("_EssentialL_ :: Didn't return a load status?", rets[2])
		end
	end
end