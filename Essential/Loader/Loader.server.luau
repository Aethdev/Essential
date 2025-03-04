
local SS = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local loaderScript = script
local model: Folder = loaderScript.Parent.Parent
local modelParent = model.Parent
local settings = model:FindFirstChild"Settings"
local startLoad = os.time()

local themes = model:FindFirstChild"Themes"
local plugins = model:FindFirstChild"Plugins"
local uiFolder = model:FindFirstChild"UIs"

-- Checking main assets of the loader model (Commands, Plugins & Themes)
local serverPlugins = {}
local clientPlugins = {}
local uiElements = {}
local uiLibrary = {}

local loadData = {
	Asset = nil;
	RojoEnabled = model:GetAttribute("Rojo") == true,
	RojoCrossCompatibility = model:GetAttribute("RojoCrossCompatibility") == true; -- To be determined after finding the existing Essential
	Model = model;
	Loader = loaderScript;
	
	disablePlugins = false; -- DEBUG
}


-- For cross compatibility between the development Essential and Rojo Essential
loadData.Asset = if SS:FindFirstChild("Essential") then SS.Essential:FindFirstChild("MainModule") else model:FindFirstChild("MainModule")

if not themes then warn("_EssentialL_ :: Themes folder is missing"); return end
if not plugins then warn("_EssentialL_ :: Plugins folder is missing"); return end
if not uiFolder then warn("_Esssential: :: UI folder is missing"); return end

if loadData.RojoEnabled then
	loadData.Asset = if SS:FindFirstChild("RojoEssentialModule") then SS.RojoEssentialModule:FindFirstChild("MainModule") else loadData.Asset

	for i, object in modelParent:GetChildren() do
		if object ~= model and object:IsA"Folder" and object.Name:find("Essential$") and object:GetAttribute("RojoCrossCompatibility") == true then
			local rojoSyncUI = object:GetAttribute("RojoSyncUI")
			local rojoSyncPlugins = object:GetAttribute("RojoSyncPlugins")

			local objectThemes = object:FindFirstChild"Themes"
			local objectPlugins = object:FindFirstChild"Plugins"
			local objectUIFolder = object:FindFirstChild"UIs"

			if not objectThemes then warn("_EssentialL_ :: Rojo Cross Compatibility failed with "..object:GetFullName().." not having a Themes folder."); break end
			if not objectPlugins and rojoSyncPlugins then warn("_EssentialL_ :: Rojo Cross Compatibility failed with "..object:GetFullName().." not having a Plugins folder."); break end
			if not objectUIFolder and rojoSyncUI then warn("_EssentialL_ :: Rojo Cross Compatibility failed with "..object:GetFullName().." not having a UI folder."); break end
			
			if rojoSyncUI then
				for i, objectThemeFolder in objectThemes:GetChildren() do
					if themes:FindFirstChild(objectThemeFolder.Name) then
						for d, objectThemeItem in objectThemeFolder:GetChildren() do
							if not themes[objectThemeFolder.Name]:FindFirstChild(objectThemeItem.Name) then
								objectThemeItem:Clone().Parent = themes[objectThemeFolder.Name]
							end
						end
	
						continue
					end
	
					objectThemeFolder:Clone().Parent = themes
				end

				for i, elementItem in objectUIFolder.Elements:GetChildren() do
					if uiFolder.Elements:FindFirstChild(elementItem.Name) then
						if elementItem:GetAttribute("RojoOverwrite") ~= true then
							warn(
								"_EssentialL_ :: Rojo Cross Compatibility Warning: Element "..elementItem.Name.." found in Rojo cross-compatible Essential " ..
								object:GetFullName() .. " cannot overwrite the existing element in Rojo Essential. Add attribute 'RojoOverwrite' with true statement in the new element to bypass duplication."
							);
							continue
						end

						Debris:AddItem(uiFolder.Elements:FindFirstChild(elementItem.Name), 0)
					end
					
					elementItem:Clone().Parent = uiFolder.Elements
				end

				for i, themeUIFolder in objectUIFolder.Library:GetChildren() do
					local existingFolderInParentModel = uiFolder.Library:FindFirstChild(themeUIFolder.Name) or (function()
						local newFolder = Instance.new("Folder")
						newFolder.Name = themeUIFolder.Name
						newFolder.Parent = uiFolder.Library
						return newFolder
					end)()

					for d, themePart in themeUIFolder:GetChildren() do
						if existingFolderInParentModel:FindFirstChild(themePart.Name) and themePart:GetAttribute("RojoOverwrite") ~= true then
							warn(
								"_EssentialL_ :: Rojo Cross Compatibility Warning: UI "..themePart.Name.." for theme "..themeUIFolder.Name.." found in Rojo cross-compatible Essential " ..
								themePart:GetFullName() .. " cannot overwrite the existing element in Rojo Essential. Add attribute 'RojoOverwrite' with true statement in the new element to bypass duplication."
							);
							continue
						end

						local clonedThemePart = themePart:Clone()
						clonedThemePart.Parent = existingFolderInParentModel
					end
				end
			end

			--TODO: Finish the same for UI Library stuff

			if not loadData.disablePlugins and rojoSyncPlugins then
				for i, pluginModule in objectPlugins.Client:GetChildren() do
					local clonedPlugin = pluginModule:Clone()
					clonedPlugin.Name = `Rojo-Connected: `..clonedPlugin.Name
					clonedPlugin.Parent = plugins.Client
				end

				for i, pluginModule in objectPlugins.Server:GetChildren() do
					local clonedPlugin = pluginModule:Clone()
					clonedPlugin.Name = `Rojo-Connected: `..clonedPlugin.Name
					clonedPlugin.Parent = plugins.Server
				end
			end

			otherEssential = object

			break
		end
	end

	warn(`_EssentialL_ Now using Rojo version`)
	ServerScriptService:SetAttribute("RojoEssential", true)
	task.wait(1)
else
	-- Check if there are Rojo Essential models enabled before running
	for i, object in modelParent:GetChildren() do
		if object ~= model and object:IsA"Folder" and object.Name:find("Essential") and object:GetAttribute("Rojo") == true
			and object:FindFirstChild("Loader") and object.Loader:FindFirstChild("Loader") and object.Loader.Loader:IsA("Script") and not object.Loader.Loader.Disabled
		then
			return
		end
	end

	if ServerScriptService:GetAttribute("RojoEssential") == true then
		return
	end
end

loadData.Asset.Name = "._."
loadData.Asset.Parent = model

-- Hiding loader
script:Destroy()


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
	
	if cloneElement then
		table.insert(uiElements, cloneElement)
	end
end

for i,uiItem in pairs(uiFolder.Library:GetChildren()) do
	local cloneItem = uiItem:Clone()

	if cloneItem then
		table.insert(uiLibrary, cloneItem)
	else
		warn(`Failed to replicate UI Library {uiItem.Name}`)
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
			-- if settings.HideLoader or settings.hideLoader then
			-- 	model.Parent = nil
			-- end
			
			loadData.Asset.Parent = nil
			Debris:AddItem(loadData.Asset, 5)
			
			model.Name = origName
			warn("_EssentialL_ :: Loaded ("..(os.time()-startLoad).." seconds)")
		else
			warn("_EssentialL_ :: Didn't return a load status?", rets[2])
		end
	end
end