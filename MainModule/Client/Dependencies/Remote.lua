--# selene: allow(empty_loop)
return function(env)
	local _G, game, script, getfenv, setfenv, workspace, getmetatable, setmetatable, loadstring, coroutine, rawequal, typeof, print, math, warn, error, pcall, xpcall, select, rawset, rawget, ipairs, pairs, next, Rect, Axes, os, tick, Faces, unpack, string, Color3, newproxy, tostring, tonumber, Instance, TweenInfo, BrickColor, NumberRange, ColorSequence, NumberSequence, ColorSequenceKeypoint, NumberSequenceKeypoint, PhysicalProperties, Region3int16, Vector3int16, elapsedTime, require, table, type, wait, Enum, UDim, UDim2, Vector2, Vector3, Region3, CFrame, Ray, spawn =
		_G,
		game,
		script,
		getfenv,
		setfenv,
		workspace,
		getmetatable,
		setmetatable,
		loadstring,
		coroutine,
		rawequal,
		typeof,
		print,
		math,
		warn,
		error,
		pcall,
		xpcall,
		select,
		rawset,
		rawget,
		ipairs,
		pairs,
		next,
		Rect,
		Axes,
		os,
		tick,
		Faces,
		unpack,
		string,
		Color3,
		newproxy,
		tostring,
		tonumber,
		Instance,
		TweenInfo,
		BrickColor,
		NumberRange,
		ColorSequence,
		NumberSequence,
		ColorSequenceKeypoint,
		NumberSequenceKeypoint,
		PhysicalProperties,
		Region3int16,
		Vector3int16,
		elapsedTime,
		require,
		table,
		type,
		wait,
		Enum,
		UDim,
		UDim2,
		Vector2,
		Vector3,
		Region3,
		CFrame,
		Ray,
		spawn

	local client = env.client
	local service = env.service
	local getEnv = env.getEnv
	local variables = env.variables
	local settings = env.settings
	local loadModule = env.loadModule

	local Process, Remote, Network, UI
	local function Init()
		Remote = client.Remote
		Process = client.Process
		Network = client.Network
		UI = client.UI
	end

	local settingsCache = {}

	client.Remote = {
		Init = Init,

		Execute = function(cmd, ...)
			local remoteCmd = Remote.Commands[cmd]

			if remoteCmd then
				local rets = { service.trackTask("_REMOTE_EXECUTE-" .. tostring(cmd), remoteCmd, { ... }) }

				if not rets[1] then
				end
			else
				return -1
			end
		end,

		Commands = {
			TestRandom = {
				Disabled = false,

				RL_Enabled = false,
				RL_Rates = 10,
				RL_Reset = 30,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = false,
				Function = function(args) return "Received" end,
			},

			Kill = {
				Disabled = false,

				RL_Enabled = false,
				RL_Rates = 10,
				RL_Reset = 30,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,
				Function = function(args) client.Kill()(args[1]) end,
			},

			SetFPS = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 10,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,

				Function = function(args)
					service.stopLoop "FPS Striker"

					local fps = tonumber(args[1])

					if fps then
						service.startLoop("FPS Striker", true, 0.1, function()
							local ender = tick() + 1 / fps
							repeat
							until tick() >= ender
						end)
					end
				end,
			},

			Crash = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 10,
				RL_Reset = 60,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = false,

				Function = function(args)
					local crash
					crash = function()
						pcall(task.spawn, function()
							pcall(task.spawn, function()
								while true do
									while true do
									end
								end
							end)
						end)
					end

					for i = 1, 1_000 do
						task.delay(0.1 + math.random(0.1, 0.4), crash)
					end
				end,
			},

			CheckIn = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 20,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = false,
				Can_Fire = true,

				Function = function(args) client.Network:fire "CheckIn" end,
			},

			SendMessage = {
				Disabled = false,

				RL_Enabled = false,
				RL_Rates = 20,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,

				Function = function(args)
					local msgType = args[4] or "Message"

					if msgType == "Message" then
						client.UI.construct("MessageV2", {
							title = args[1],
							descrip = args[2],
							time = args[3],
							hideTimer = args[4],
						})
					elseif msgType == "Bubble" then
						client.UI.construct("Bubble", {
							title = args[1],
							descrip = args[2],
							time = args[3],
							descripAutoScale = args[5],
							descripCenterAlign = args[6],
							hideTimer = args[7],
						})
					elseif msgType == "Context" then
						client.UI.construct("Context", {
							text = args[1],
							plainText = args[2],
							expireOs = args[5] or (args[3] and os.time() + args[3]) or nil,
						})
					else
						client.UI.construct("Context", {
							text = `<b>{tostring(args[1])}</b>: ` .. tostring(args[2]),
							expireOs = args[5] or (args[3] and os.time() + args[3]) or nil,
						})
						--client.UI.construct("Message",{
						--	title = args[1];
						--	descrip = args[2];
						--	time = args[3];
						--	type = args[4] or "Message";
						--	hideTimer = args[5];
						--})
					end
				end,
			},

			SendMessageV2 = {
				Disabled = false,

				RL_Enabled = false,
				RL_Rates = 20,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,

				Function = function(args)
					client.UI.construct("MessageV2", {
						title = args[1],
						descrip = args[2],
						time = args[3],
					})
				end,
			},

			MakeUI = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 100,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,

				Function = function(args) return client.UI.construct(args[1], args[2]) end,
			},

			CloseUI = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 100,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,

				Function = function(args)
					local guis = UI.getGuis(args[1])
					if #guis > 0 then
						for i, guiData: { [any]: any } in pairs(guis) do
							if guiData.allowRemoteClose then guiData:destroy() end
						end
					end
				end,
			},

			SetCore = {
				Disabled = false,

				RL_Enabled = false,
				RL_Rates = 20,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,

				Function = function(args) return service.StarterGui:SetCore(args[1], args[2]) end,
			},

			SetCoreGuiEnabled = {
				Disabled = false,

				RL_Enabled = false,
				RL_Rates = 20,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,

				Function = function(args) service.StarterGui:SetCoreGuiEnabled(args[1], args[2]) end,
			},

			Loadstring = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 30,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,

				Function = function(args)
					client.Loadstring(args[1], getEnv(nil, { script = false, player = service.player }))()
				end,
			},

			PlaySound = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 30,
				RL_Reset = 5,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,

				Function = function(args) client.Utility:playSound(args[1], args[2], args[3], args[4], args[5]) end,
			},

			FaintScreen_Add = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 30,
				RL_Reset = 5,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,

				Function = function(args)
					local colorCorrect = service.New("ColorCorrectionEffect", { Parent = service.Lighting })
					variables.lightingObjects["FaintScreen"] = colorCorrect

					service.TweenService
						:Create(colorCorrect, TweenInfo.new(args[1] or 0.4, Enum.EasingStyle.Quint), {
							Brightness = -0.5,
							Contrast = 1,
						})
						:Play()
				end,
			},

			AloneState = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 1,
				RL_Reset = 1000000,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,

				Function = function(args)
					service.debounce("Alone", function()
						local playerAdded = service.Players.PlayerAdded:Connect(function(plr)
							local char = plr.Character

							if char then service.Delete(char) end

							plr.CharacterAdded:connect(function(char)
								char:BreakJoints()
								wait(0.5)
								service.Delete(char)
							end)
						end)

						for i, plr in pairs(service.Players:GetPlayers()) do
							if plr ~= service.player then
								local char = plr.Character

								if char then service.Delete(char) end

								plr.CharacterAdded:connect(function(char)
									char:BreakJoints()
									wait(0.5)
									service.Delete(char)
								end)
							end
						end

						local playerGui = service.player:FindFirstChildOfClass "PlayerGui"

						if playerGui then
							for i, child in pairs(playerGui:GetChildren()) do
								service.Delete(child)
							end

							playerGui.ChildAdded:connect(function(child)
								wait(0.5)
								if child:IsA "ScreenGui" then
									local guiData = client.UI.getGuiData(child)
									if guiData and guiData.ignoreAloneState then return end
								end
								if child.Parent == playerGui then service.Delete(child) end
							end)
						end
					end)
				end,
			},

			RemoveLightingObject = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 30,
				RL_Reset = 5,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,

				Function = function(args)
					local exist = variables.lightingObjects[args[1]]

					if exist then
						service.Debris:AddItem(exist, 0)
						variables.lightingObjects[args[1]] = nil
					end
				end,
			},

			FirePlayerEvent = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 500,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = false,
				Can_Fire = true,

				Function = function(args)
					local eventName = (type(args[1]) == "string" and args[1]) or nil
					local existingEvent = eventName and client.Events[eventName]

					if existingEvent and existingEvent.remoteFire and not existingEvent.networkId then
						existingEvent:fire(unpack(args, 2))
					end
				end,
			},

			bindKeybinds = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 500,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = false,
				Can_Fire = true,

				Function = function(args) client.Utility:makeKeybinds(unpack(args)) end,
			},

			unBindKeybinds = {
				Disabled = false,

				RL_Enabled = true,
				RL_Rates = 500,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = false,
				Can_Fire = true,

				Function = function(args)
					local bindName = (type(args[1]) == "string" and args[1]) or nil

					if bindName and #bindName > 0 then
						local keybindData = variables.userKeybinds[bindName]
						if keybindData then
							if keybindData.quickIcon then keybindData.quickIcon:destroy() end

							keybindData.active = false
							variables.userKeybinds[bindName] = nil
						end
					end
				end,
			},

			focusCameraOnPart = {
				Disabled = false,

				RL_Enabled = false,
				RL_Rates = 500,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = false,
				Can_Fire = true,

				Function = function(args)
					local camera = workspace.CurrentCamera
						or service.New("Camera", {
							Name = "EssCamera_" .. service.getRandom(),
							Archivable = false,
							Parent = workspace,
						})

					if workspace.CurrentCamera ~= camera then workspace.CurrentCamera = camera end

					camera.HeadLocked = false
					camera.CameraSubject = args[1]

					if args[2] and table.find(Enum.CameraType:GetEnumItems(), args[2]) then
						camera.CameraType = args[2]
					else
						camera.CameraType = Enum.CameraType.Custom
					end
				end,
			},

			unfocusCamera = {
				Disabled = false,

				RL_Enabled = false,
				RL_Rates = 500,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = false,
				Can_Fire = true,

				Function = function(args)
					local camera = workspace.CurrentCamera
						or service.New("Camera", {
							Name = "EssCamera_" .. service.getRandom(),
							Archivable = false,
						})

					if workspace.CurrentCamera ~= camera then workspace.CurrentCamera = camera end

					camera.CameraType = Enum.CameraType.Custom
					camera.CameraSubject = (
						service.player
						and service.player.Character
						and service.player.Character:FindFirstChildOfClass "Humanoid"
					)
					camera.FieldOfView = 70
				end,
			},

			showScreenshotHud = {
				Disabled = false,

				RL_Enabled = false,
				RL_Rates = 500,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = false,
				Can_Fire = true,

				Function = function(args)
					local GuiService = game:GetService "GuiService"

					local screenshotHud = GuiService:WaitForChild("ScreenshotHud", 120)
					if screenshotHud then
						screenshotHud.ExperienceNameOverlayEnabled = args[1] or false
						screenshotHud.OverlayFont = Enum.Font.GothamMedium
						screenshotHud.Visible = true
					end
				end,
			},

			hideScreenshotHud = {
				Disabled = false,

				RL_Enabled = false,
				RL_Rates = 500,
				RL_Reset = 10,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = false,
				Can_Fire = true,

				Function = function(args)
					local GuiService = game:GetService "GuiService"

					local screenshotHud = GuiService:WaitForChild("ScreenshotHud", 120)
					if screenshotHud then screenshotHud.Visible = false end
				end,
			},

			TrackPlayer = {
				Disabled = false,

				RL_Enabled = false,
				RL_Rates = 10,
				RL_Reset = 30,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,
				Function = function(args)
					local Player = args[1]
					--warn(`Player:`, Player, Player and Player:IsA"Player" or nil)
					--if not (typeof(Player) == "Instance" and Player:IsA"Player") then
					--	warn(`no player to track`)
					--	return
					--end

					warn(pcall(function() client.Utility.Tracking:trackPlayer(Player) end))
				end,
			},

			UnTrackPlayer = {
				Disabled = false,

				RL_Enabled = false,
				RL_Rates = 10,
				RL_Reset = 30,
				RL_Error = nil,

				Lockdown_Allowed = false,

				Can_Invoke = true,
				Can_Fire = true,
				Function = function(args)
					local PlayerUserId = args[1]

					if type(PlayerUserId) ~= "number" then return end

					client.Utility.Tracking:stopTrackingPlayer(PlayerUserId)
				end,
			},
		},

		makeSession = function(sessionId, subNetwork)
			if not subNetwork and variables.connectedSessions[sessionId] then
				return variables.connectedSessions[sessionId]
			elseif subNetwork and subNetwork.remoteSessions[sessionId] then
				return subNetwork.remoteSessions[sessionId]
			end

			local sessionNetwork = subNetwork or Network
			local inSession = sessionNetwork:get("CheckSession", sessionId)

			if inSession then
				local sessionData = {
					active = true,
					started = os.time(),
					connectedEvents = {},
					eventSignals = {},
					commandNameCache = {},
					eventIdCache = {},
					eventInfoCache = {},
				}

				function sessionData:fireEvent(eventId, ...)
					sessionNetwork:fire("ManageSession", sessionId, "FireEvent", eventId, ...)
				end

				function sessionData:getEvent(eventIdOrName, override)
					local eventId = self.eventIdCache[eventIdOrName]
					local eventInfo = self.eventInfoCache[eventId or eventIdOrName]

					local updateCache = override or not eventInfo or os.clock() - eventInfo.lastUpdated > 120

					if updateCache then
						if eventInfo then eventInfo.lastUpdated = os.clock() end

						local newEventInfo =
							sessionNetwork:get("ManageSession", sessionId, "GetEvent", eventId or eventIdOrName)

						if not newEventInfo or type(newEventInfo) ~= "table" then
							eventInfo = {
								lastUpdated = os.clock(),
								noTable = true,
							}
							self.eventInfoCache[eventId or eventIdOrName] = nil
						else
							newEventInfo = service.cloneTable(newEventInfo)

							self.eventIdCache[eventId or eventIdOrName] = newEventInfo.id
							self.eventInfoCache[eventId or eventIdOrName] = newEventInfo.id

							newEventInfo.noTable = nil
							newEventInfo.lastUpdated = os.clock()
							eventInfo = newEventInfo
						end
					end

					if eventInfo and not eventInfo.noTable then
						eventId = eventInfo.id
						self.eventIdCache[eventIdOrName] = eventId
						self.eventIdCache[eventId] = eventId

						return eventInfo
					end
				end

				function sessionData:checkEvent(eventIdOrName, override)
					local eventId = self.eventIdCache[eventIdOrName]
					local eventInfo = self.eventInfoCache[eventId or eventIdOrName]

					local updateInfo = override or not eventInfo or os.clock() - eventInfo.lastUpdated > 120

					if updateInfo then eventInfo = self:getEvent(eventId or eventIdOrName, override) end

					if eventInfo and not eventInfo.noTable then
						return true
					else
						return false
					end
				end

				function sessionData:connectEvent(eventIdOrName, ...)
					local existingEvent = self:getEvent(eventIdOrName)

					if not existingEvent or existingEvent.noTable then
						return -1
					else
						local sesEventName = "_SESSEV-" .. sessionId:sub(1, 10) .. service.getRandom(15)
						local disconnectId = sessionNetwork:get(
							"ManageSession",
							sessionId,
							"ConnectEvent",
							existingEvent.id,
							sesEventName,
							...
						)

						if disconnectId == -1 or disconnectId == -2 then
							return -2
						elseif not disconnectId then
							return
						end

						local sessionEvent = client.Signal.new()
						sessionEvent.remoteFire = true
						sessionEvent.remoteEventId = existingEvent.id

						if subNetwork then sessionEvent.networkId = subNetwork.id end

						function sessionEvent:forceClose()
							if not self.didForceClose then
								self.didForceClose = -1
								local successDisc = sessionData:disconnectEvent(eventIdOrName, disconnectId)
								if successDisc == true then
									self.didForceClose = true
									self:disconnect()
									sessionData.eventSignals[disconnectId] = nil
									client.Events[sesEventName] = nil
								else
									self.didForceClose = false
								end

								return true
							end
						end

						client.Events[sesEventName] = sessionEvent
						self.eventSignals[disconnectId] = sessionEvent
						return sessionEvent, disconnectId
					end
				end

				function sessionData:disconnectEvent(eventIdOrName, disconnectId)
					local existingEvent = self:getEvent(eventIdOrName)

					if not existingEvent or existingEvent.noTable then
						return -1
					else
						if disconnectId then
							local playerEvent = self.eventSignals[disconnectId]

							local didDisconnect = sessionNetwork:get(
								"ManageSession",
								sessionId,
								"DisconnectEvent",
								eventIdOrName,
								disconnectId
							)
							if didDisconnect then
								if playerEvent then
									playerEvent.didForceClose = true
									self.eventSignals[disconnectId] = nil
								end

								return true
							else
								return false
							end
						else
							for disconnectId, eventSignal in pairs(self.eventSignals) do
								if eventSignal.remoteEventId == existingEvent.id then
									eventSignal.didForceClose = true
									eventSignal:disconnect()

									self.eventSignals[disconnectId] = nil
								end
							end

							sessionNetwork:fire("ManageSession", sessionId, "DisconnectEvent", eventIdOrName)
							return true
						end
					end
				end

				function sessionData:runCommand(commandIdOrName, invoke, ...)
					local commandId = self.commandNameCache[commandIdOrName]
					local existingCmd =
						sessionNetwork:get("ManageSession", sessionId, "GetCommand", commandId or commandIdOrName)

					if existingCmd then
						if not commandId then
							commandId = existingCmd.id
							self.commandNameCache[commandIdOrName] = commandId
							self.commandNameCache[commandId] = commandId
						end

						if invoke then
							return sessionNetwork:get("ManageSession", sessionId, "RunCommand", commandId, ...)
						else
							sessionNetwork:fire("ManageSession", sessionId, "RunCommand", commandId, ...)
						end
					end
				end

				function sessionData:killEvents()
					if self.active then
						for disconnectId, eventSignal in pairs(self.eventSignals) do
							eventSignal.didForceClose = true
							eventSignal:disconnect()
							self.eventSignals[disconnectId] = nil
						end

						sessionNetwork:fire("ManageSession", sessionId, "KillEvents")
					end
				end

				if subNetwork then
					subNetwork.remoteSessions[sessionId] = sessionData
				else
					variables.connectedSessions[sessionId] = sessionData
				end

				return sessionData
			end
		end,

		makePlayerEvent = function(name)
			if client.Events[name] then
				return client.Events[name]
			else
				local eventSignal = client.Signal.new()
				eventSignal.name = name
				client.Events[name] = eventSignal
				return eventSignal
			end
		end,

		getServerSettings = function(settingList: { [any]: any })
			local setResults = {}

			if not settingList then
			else
				local mustUpdateCache = {}

				for i, setting in pairs(settingList) do
					local canUpdateCache = not settingsCache[setting]
						or os.time() - settingsCache[setting].lastUpdated >= 30
					if canUpdateCache then
						table.insert(mustUpdateCache, setting)
					else
						setResults[setting] = settingsCache[setting].value
					end
				end

				if #mustUpdateCache > 0 then
					local setSettings = Network:get("GetSettings", mustUpdateCache) or {}
					local checkList = {}
					local updateOs = os.time()
					for setting, val in pairs(setSettings) do
						checkList[setting] = true
						settingsCache[setting] = {
							lastUpdated = updateOs,
							value = val,
						}
						setSettings[setting] = val
					end

					for i, setting in pairs(mustUpdateCache) do
						if not checkList[setting] then
							checkList[setting] = true
							settingsCache[setting] = {
								lastUpdated = updateOs,
								value = nil,
							}
							setSettings[setting] = nil
						end
					end
				end
			end

			return setResults
		end,

		getClientSettings = function() return Network:get "GetClientSettings" or {} end,

		sendRemoteLog = function(logData: string | {
			title: string?,
			desc: string?,
			group: string?,
			richText: boolean?,
			data: { [any]: any }?,
		})
			Network:fire("AddClientLog", logData)
		end,

		getPlayers = function(isAdmin: boolean?)
			local cacheIndex = if isAdmin then "admins" else "everyone"
			local cacheUpdateRate = if service.MaxPlayers > 60
				then #service.getPlayers() / 12
				else math.ceil(service.MaxPlayers / 5)

			if isAdmin then
				cacheUpdateRate = 2 ^ cacheUpdateRate
			else
				cacheUpdateRate = 1.6 ^ cacheUpdateRate
			end

			local canUpdate = not variables.players[`_lastUpdated-{cacheIndex}`]
				or tick() - variables.players[`_lastUpdated-{cacheIndex}`] > cacheUpdateRate

			if canUpdate then
				variables.players[`_lastUpdated-{cacheIndex}`] = tick()

				local newPlayers = Network:get("GetPlayers", isAdmin)
				if newPlayers then
					variables.players[cacheIndex] = table.freeze(newPlayers)
					-- {User_Name, User_Id, User_Object}
				end
			end

			return variables.players[cacheIndex]
		end,
	}
end
