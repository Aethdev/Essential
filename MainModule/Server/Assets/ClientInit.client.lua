local parent = script.Parent
local fromLoading = rawequal(parent, game:GetService("ReplicatedFirst")) or false
local fromGui = (parent and parent:IsA"ScreenGui") or nil
local script = script
local folder = script:FindFirstChildOfClass"Folder" or nil

local testService = game:GetService("TestService")
local testError = testService.Error
--local error = function(...) testError(testService, ...) end
local type = type
local pcall = pcall
local require = require
local getAttribute = script.GetAttribute
local wait = wait
local spawn = spawn

if folder then
	local oldFolder = folder
	for i, part in pairs(folder:GetDescendants()) do
		part.Archivable = true
	end
	folder = folder:Clone()
	task.defer(oldFolder.Destroy, oldFolder)
	if not folder then
		error("Folder failed to clone")
		return
	end
end

local players = game:GetService("Players")
local player = players.LocalPlayer
local plrKick = player.Kick

if fromLoading then
	script:Destroy()
elseif not (fromLoading or fromGui) then
	error("ESSC: Init failed to detect the location")
	return;
elseif fromGui then
	wait(.5)
	script:Destroy()
end

if not player then
	error("Unknown location executed", 0)
	return
end

do
	if not folder then
		error("ESSC: Init failed to find directory")
		return;
	end
	
	local runner = folder:FindFirstChild"Runner" or folder:FindFirstChild"Client"
	
	if not (runner or (runner and runner:IsA"ModuleScript")) then
		error("ESSC: Missing runner")
	else
		local suc,ret = pcall(require, runner)
		local retType = type(ret)
		
		if not suc or retType ~= "userdata" then
			error("ESSC Runner encountered an error: ("..retType..") "..tostring(ret))
		else
			local trace = ''
			local errMsg = ''
			local ran,ret = xpcall(ret, function(failMsg)
				trace = debug.traceback(nil, 2)
				errMsg = failMsg
			end, {
				VerifyId = (fromGui and getAttribute(script, "VerifyId")) or nil;
			} )
			
			if not ran then
				--pcall(plrKick or function() end, player, "ESSCL encountered an error: "..tostring(ret).."\n"..trace)
				--wait(.2)
				--while true do spawn(function() warn(math.random()) end) end
				error("Essential client encountered an error: "..tostring(ret).."\n"..tostring(errMsg).."\n"..tostring(trace), 0)
			end
		end
	end
end