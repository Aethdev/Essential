
return function(envArgs)
	local type, math = type, math
	local mathFloor = math.floor
	
	local client = envArgs.client
	local service = envArgs.service
	local variables = envArgs.variables
	local loadModule = envArgs.loadModule
	local getEnv = envArgs.getEnv
	local script = envArgs.script

	local Remote = client.Remote
	local UI = client.UI
	local Network = client.Network
	
	local Kill = client.Kill
	local Signal = client.Signal
	
	local clientSettings = client.Settings or {}
	client.Settings = clientSettings
	
	local curMuteState = false
	local function toggleMuteOnAFK(bool: boolean, override: boolean?, reason: string?)
		if curMuteState ~= bool or override then
			curMuteState = bool
			
			if reason then
				Remote.sendRemoteLog(`MuteOnAFK :: Status: {bool} | {reason}`)
			end
			
			Network:fire("ToggleMuteOnAFK", bool)
		end
	end
	
	local userInput = service.UserInputService
	userInput.WindowFocused:Connect(function()
		if curMuteState then
			toggleMuteOnAFK(false, nil, `Window regained focus`)
		end
	end)
	
	userInput.WindowFocusReleased:Connect(function()
		if clientSettings.ToggleMuteOnAFK then
			toggleMuteOnAFK(true, nil, `Window lost focus`)
		end
	end)
	
	local idleRbxEvent = service.player.Idled
	
	local idleChEvent = Signal.new()
	local idleCheck = Signal.new()
	local _idleStateWithMOA, _menuStateWithMOA = false, false
	idleCheck:linkRbxEvent(idleRbxEvent)
	idleCheck:connect(function(idleTime)
		if _menuStateWithMOA then return end
		if type(idleTime) ~= "number" or (idleTime > 60 * 20) then
			idleCheck:disconnect()
			Kill("Mute on AFK plugin detected improper idle time")
		else
			idleChEvent:fire(idleTime)
			
			local newIdleTime = idleChEvent:wait(nil, 5)
			if newIdleTime then
				if clientSettings.ToggleMuteOnAFK then
					_idleStateWithMOA = true
					toggleMuteOnAFK(true, nil, "Idle activity detected")
				end
			else
				_idleStateWithMOA = false
				toggleMuteOnAFK(false, nil, "Player is no longer idle")
			end
		end
	end)
	
	local menuOpenedEvent = Signal.new()
	menuOpenedEvent:linkRbxEvent(service.GuiService.MenuOpened)
	menuOpenedEvent:connect(function()
		if clientSettings.ToggleMuteOnAFK and not _idleStateWithMOA then
			_menuStateWithMOA = true
			toggleMuteOnAFK(true, nil, "Pause menu opened")
		end
	end)
	
	local menuClosedEvent = Signal.new()
	menuClosedEvent:linkRbxEvent(service.GuiService.MenuClosed)
	menuClosedEvent:connect(function()
		if clientSettings.ToggleMuteOnAFK and not _idleStateWithMOA then
			_menuStateWithMOA = false
			toggleMuteOnAFK(false, nil, "Pause menu closed")
		end
	end)
	
	toggleMuteOnAFK(false, true)
end