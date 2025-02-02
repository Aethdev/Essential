--!nocheck
local utility, sounds = {}, {}
local Promise

local client = nil
local service = nil
local variables = nil
local getEnv = nil

local function waitForChild(instance, childName, timeout)
	return Promise.defer(function(resolve, reject)
		local child = instance:WaitForChild(childName, timeout);
		(child and resolve or reject)(child)
	end)
end

function utility:deferCheckRate(rateLimit: { [any]: any }, rateKey: string | number | userdata | table)
	return utility:checkRate(rateLimit, rateKey, true)
end

function utility:readRate(rateLimit: { [any]: any }, rateKey: string | number | userdata | table)
	local Caches: { [any]: {
		Rate: number,
		Throttle: number,
		LastUpdated: number?,
		LastThrottled: number?,
	} } = rateLimit.Caches
		or {}
	local rateData: {
		Rate: number,
		Throttle: number,
		LastUpdated: number?,
		LastThrottled: number?,
	} =
		Caches[rateKey]

	if not rateData then
		return false, 0, false, 0, false, 0
	else
		local currentOs = os.time()
		local maxRate = math.abs(rateLimit.Rates) -- Max requests per traffic
		local resetInterval = math.floor(math.abs(rateLimit.Reset or 1)) -- Interval seconds since the cache last updated to reset

		local canThrottle = rateLimit.ThrottleEnabled
		local throttleReset = rateLimit.ThrottleReset
		local throttleMax = math.floor(math.abs(rateLimit.ThrottleMax or 1))

		local didReset = currentOs - rateData.LastUpdated >= resetInterval
		local didPassRL = if didReset then true else rateData.Rate <= maxRate
		local didThrottleReset = if canThrottle
				and not didPassRL
				and rateData.LastThrottled
			then currentOs - rateData.LastThrottled >= throttleReset
			else false
		local didThrottleRL = if canThrottle
				and not didPassRL
				and not didThrottleReset
				and rateData.Throttle
			then rateData.Throttle <= throttleMax
			else false

		return didPassRL, rateData.Rate, didThrottleRL, rateData.Throttle, rateData.LastUpdated
	end
end

function utility:checkRate(
	rateLimit: {
		Rates: number,
		Reset: number,

		ThrottleEnabled: boolean?,
		ThrottleReset: number?,
		ThrottleMax: number?,
	},
	rateKey: string | number | userdata | table,
	deferCheck: boolean?
) -- Rate limit check
	-- Ratelimit: {[any]: any}
	-- Ratekey: string or number
	local function doCheckRate()
		-- Ratelimit: {[any]: any}
		-- Ratekey: string or number

		local rateData = (type(rateLimit) == "table" and rateLimit) or nil

		if not rateData then
			error "Rate data doesn't exist (unable to check)"
		else
			-- RATELIMIT TABLE
			--[[
				
				Table:
					{
						Rates = 100; 	-- Max requests per traffic
						Reset = 1; 		-- Interval seconds since the cache last updated to reset
						
						ThrottleEnabled = false/true; -- Whether throttle can be enabled
						ThrottleReset = 10; -- Interval seconds since the cache last throttled to reset
						ThrottleMax = 10; -- Max interval count of throttles
						
						Caches = {}; -- DO NOT ADD THIS. IT WILL AUTOMATICALLY BE CREATED ONCE RATELIMIT TABLE IS CHECKING-
						--... FOR RATE PASS AND THROTTLE CHECK.
					}
				
			]]

			-- RATECACHE TABLE
			--[[
				
				Table:
					{
						Rate = 0;
						Throttle = 0; 		-- Interval seconds since the cache last updated to reset
						
						LastUpdated = 0; -- Last checked for rate limit
						LastThrottled = nil or 0; -- Last checked for throttle (only changes if rate limit failed)
					}
				
			]]
			local maxRate = math.abs(rateData.Rates) -- Max requests per traffic
			local resetInterval = math.floor(math.abs(rateData.Reset or 1)) -- Interval seconds since the cache last updated to reset

			local rateExceeded = rateLimit.Exceeded or rateLimit.exceeded
			local ratePassed = rateLimit.Passed or rateLimit.passed

			local canThrottle = rateLimit.ThrottleEnabled
			local throttleReset = rateLimit.ThrottleReset
			local throttleMax = math.floor(math.abs(rateData.ThrottleMax or 1))

			-- DEBUG SETTINGS
			local debugLogRates = rateLimit.DebugLogRates
			local debugMaxLogs = 100

			-- Ensure minimum requirement is followed
			maxRate = (maxRate > 1 and maxRate) or 1
			-- Max rate must have at least one rate else anything below 1 returns false for all rate checks

			local resetOsTime

			local cacheLib = rateData.Caches

			if not cacheLib then
				cacheLib = {}
				rateData.Caches = cacheLib
			end

			-- Check cache
			local nowOs = tick()
			local rateCache = cacheLib[rateKey]
			
			if not rateCache then
				rateCache = {
					Rate = 0,
					Throttle = 0,
					LastUpdated = nowOs,
					LastThrottled = nil,
				}

				resetOsTime = nowOs + resetInterval

				cacheLib[rateKey] = rateCache
			end

			if nowOs - rateCache.LastUpdated >= resetInterval then
				rateCache.LastUpdated = nowOs
				rateCache.Rate = 0
				resetOsTime = nowOs + resetInterval
			else
				resetOsTime = nowOs + (resetInterval - (nowOs - rateCache.LastUpdated))
			end

			local ratePass = rateCache.Rate + 1 <= maxRate

			local didThrottle = canThrottle and rateCache.Throttle + 1 <= throttleMax
			local throttleResetOs = rateCache.ThrottleReset
			local canResetThrottle = throttleResetOs and nowOs - throttleResetOs <= throttleReset

			rateCache.Rate += 1

			-- DEBUG
			if ratePass and debugLogRates then
				local rateDebugLogs = rateLimit.DebugRateLogs

				if not rateDebugLogs then
					rateDebugLogs = {}
					rateLimit.DebugRateLogs = rateDebugLogs
				end

				if #rateDebugLogs + 1 > debugMaxLogs and debugMaxLogs > 1 then
					repeat
						table.remove(rateDebugLogs, 1)
					until #rateDebugLogs <= debugMaxLogs
				end

				table.insert(rateDebugLogs, rateCache.Rate)
			end

			-- Check can throttle and whether throttle could be reset
			if canThrottle and canResetThrottle then rateCache.Throttle = 0 end

			-- If rate failed and can also throttle, count tick
			if canThrottle and (not ratePass and didThrottle) then
				rateCache.Throttle += 1
				rateCache.LastThrottled = nowOs

				-- Check whether cache time expired and replace it with a new one or set a new one
				if not throttleResetOs or canResetThrottle then rateCache.ThrottleReset = nowOs end
			elseif canThrottle and ratePass then
				rateCache.Throttle = 0
			end

			if rateExceeded and not ratePass then rateExceeded:Fire(rateKey, rateCache.Rate, maxRate) end

			if ratePassed and ratePass then ratePassed:Fire(rateKey, rateCache.Rate, maxRate) end

			return ratePass, didThrottle, canThrottle, rateCache.Rate, maxRate, throttleResetOs, resetOsTime
		end
	end

	if deferCheck then
		local currentThread = coroutine.running()
		local stuff = {}

		task.spawn(function()
			rateLimit.deferWaitLevel = (rateLimit.deferWaitLevel or 0) + 1

			wait(rateLimit.deferWaitLevel * 0.1)
			stuff = { doCheckRate() }
			task.spawn(currentThread)

			rateLimit.deferWaitLevel -= 1
		end)

		coroutine.yield()
		return unpack(stuff)
	else
		return doCheckRate()
	end
end

function utility:checkHoldingKey(keycode, duration)
	duration = duration or 0

	local uis = service.UserInputService
	local started = os.clock()
	local status

	if not uis:IsKeyDown(keycode) then return false end

	if duration > 0 then
		repeat
			if not uis:IsKeyDown(keycode) then
				status = false
				break
			end
			wait(0.1)
		until (os.clock() - started > duration) or status ~= nil
	else
		status = not uis:IsKeyDown(keycode) or nil
	end

	if status == nil then
		return true
	else
		return false
	end
end

utility.inputListeners = {}
function utility:setupInputListener(object)
	if self.inputListeners[object] then
		return self.inputListeners[object]
	else
		local userInputS = service.UserInputService
		local Signal = client.Signal.new()
		local inputListener = {
			pressedKeyCodes = {},
			keyCodePressed = Signal.new(),
			keyCodeEnded = Signal.new(),

			inputTypes = {},
			inputTypeBegan = Signal.new(),
			inputTypeEnded = Signal.new(),

			mouseEnter = false,
			mouseEntered = Signal.new(),
			mouseLeave = Signal.new(),
		}

		function inputListener:isKeyCodePressed(keyCode) return inputListener.pressedKeyCodes[keyCode] or false end

		function inputListener:isInputTypeEnabled(inputType) return inputListener.inputTypes[inputType] or false end

		object.Active = true

		inputListener._inputBeganEvent = service.rbxEvent(object.InputBegan, function(input, gameProcessed)
			local inputKeyCode = input.KeyCode
			local inputType = input.UserInputType

			if inputKeyCode ~= Enum.KeyCode.Unknown and not inputListener.pressedKeyCodes[inputKeyCode] then
				inputListener.pressedKeyCodes[inputKeyCode] = true
				inputListener.keyCodePressed:fire(inputKeyCode)
			end

			if inputType and not inputListener.inputTypes[inputType] then
				inputListener.inputTypes[inputType] = true
				inputListener.inputTypeBegan:fire(inputType)
			end
		end)

		inputListener._inputEndedEvent = service.rbxEvent(object.InputEnded, function(input, gameProcessed)
			local inputKeyCode = input.KeyCode
			local inputType = input.UserInputType

			if inputKeyCode ~= Enum.KeyCode.Unknown and inputListener.pressedKeyCodes[inputKeyCode] then
				inputListener.pressedKeyCodes[inputKeyCode] = nil
				inputListener.keyCodeEnded:fire(inputKeyCode)
			end

			if inputType and inputListener.inputTypes[inputType] then
				inputListener.inputTypes[inputType] = nil
				inputListener.inputTypeEnded:fire(inputType)
			end
		end)

		inputListener._mouseEnterEvent = service.rbxEvent(object.MouseEnter, function()
			if not inputListener.mouseEnter then
				inputListener.mouseEnter = true
				inputListener.mouseEntered:fire()
			end
		end)

		inputListener._mouseLeaveEvent = service.rbxEvent(object.MouseLeave, function()
			if inputListener.mouseEnter then
				inputListener.mouseEnter = false
				inputListener.mouseLeave:fire()
			end
		end)

		self.inputListeners[object] = inputListener
		return inputListener
	end
end

function utility:playSound(name, id, loop, pitch, volume)
	utility:stopSound(name)

	local holder = (utility.soundFolder and utility.soundFolder.Parent == workspace and utility.soundFolder)
		or service.New("Folder", {
			Name = "_MUSIC_" .. service.getRandom(),
			Archivable = false,
		})
	utility.soundFolder = holder

	local object = service.New("Sound", {
		Name = "SOUND",
		Parent = holder,
	})

	local soundData = {
		Object = object,
		holder = holder,
	}

	object.SoundId = "rbxassetid://" .. tostring(id)

	if loop then object.Looped = loop end

	if pitch then object.PlaybackSpeed = pitch end

	if volume then object.Volume = volume end

	holder.Parent = service.Workspace
	object:Play()

	sounds[name] = soundData
end

function utility:stopSound(name)
	if sounds[name] then
		sounds[name].holder:Destroy()
		sounds[name] = nil
	end
end

function utility:setupConsole()
	if utility._setupedConsole then return end
	utility._setupedConsole = true

	local UIS = service.UserInputService

	local lastChecked = nil
	local checkAllowed = false
	local function checkPerm()
		-- can update
		--local canUpdate = not lastChecked or (os.clock()-lastChecked >= 60)

		--if canUpdate then
		--	lastChecked = os.clock()
		--	checkAllowed = (client.Network:get("GetSettings", {"consolePublic"}) or {}).consolePublic or client.Network:get("HasPermissions", {"Use_Console"})
		--end

		--return checkAllowed
		return client.Policies:get("CONSOLE_ALLOWED").value == true
	end

	local cliSettings
	local cmdBarIcon
	local openedConsole
	local function makeConsole()
		if not openedConsole then
			openedConsole = true

			--if cmdBarIcon then
			--	cmdBarIcon:select()
			--	cmdBarIcon:lock()
			--end

			local networkReady = client.Network:isReady()

			if networkReady and checkPerm() then
				client.UI.construct "Console"
			elseif not networkReady then
				service.debounce("Console-Warn-Missing-Network", function()
					client.UI.construct("Notification", {
						title = "Cannot open console",
						desc = "Client network is <b>not connected to main network</b>. Please try again later!",
						time = 6,
						noWait = true,
					})

					wait(3)
				end)
			end

			--if cmdBarIcon then
			--	cmdBarIcon:unlock()
			--	cmdBarIcon:deselect()
			--end

			openedConsole = false
		end
	end

	local function setupHotkey()
		cliSettings = client.Network:get("GetSettings", { "hotkeys", "consoleEnabled" }) or {}
		local consoleKeybinds = (cliSettings.hotkeys or {}).console or { Enum.KeyCode.LeftBracket }

		for i, key in pairs(consoleKeybinds) do
			if type(key) == "string" then
				consoleKeybinds[i] = Enum.KeyCode[key]
			elseif tostring(key):sub(1, 13) == "Enum.KeyCode." then
				-- do nothing
			else
				consoleKeybinds[i] = nil
			end
		end

		--service.ContextActionService:BindActionAtPriority("ConsoleHotkey-"..service.getRandom(), makeConsole, false, 50, unpack(consoleKeybinds))
		local consoleKeybind = utility.Keybinds:register(`System.Console`, {
			keys = consoleKeybinds,
			--holdDuration = 1;
			description = `Toggles the visiblity of the legacy Console bar`,
			locked = false,
			saveId = "SKC", --// SK ackronym for System Keybind
		})

		consoleKeybind._event:connect(function(event: "Triggered" | "OnHold" | "RateLimited" | "Canceled")
			if event == `Triggered` then task.delay(0.4, makeConsole) end
		end)
	end

	client.consoleOpened = client.Signal.new()

	if client.Network:isReady() then
		cliSettings = client.Network:get("GetSettings", { "helpEnabled", "consoleEnabled" }) or {}
		setupHotkey()
	else
		client.Network.Joined:connectOnce(setupHotkey)
	end

	--cmdBarIcon = client.UI.makeElement("TopbarIcon")
	--cmdBarIcon:setName(service.getRandom())
	--cmdBarIcon:setLabel("E")
	--cmdBarIcon:setCaption("E. Command bar")
	--cmdBarIcon:setRight()

	--cmdBarIcon.selected:Connect(function()""
	--	cmdBarIcon:lock()
	--	makeConsole()
	--	cmdBarIcon:unlock()
	--	cmdBarIcon:deselect()
	--end)
	utility.makeConsole = makeConsole
end

-- Keybinds system
do
	utility.Keybinds = {}

	--// Rate limit
	utility.Keybinds.RateLimits = {
		Global = { --// All keybinds regardless of category
			Rates = 80,
			Reset = 60,
		},

		TriggerCommand = { Rates = 40, Reset = 60 },
		TriggerSession = { Rates = 50, Reset = 60 },
	}

	utility.Keybinds.registeredKeybinds = {}
	utility.Keybinds._pressedKeys = {}
	utility.Keybinds._defaultKeybindRegister = {}
	--triggerType: "Loadstring"|"Function"|"Session"|"PersonalKeybind";

	function utility.Keybinds:find(bindName: string)
		for i, keybindData: { _name: string } in self.registeredKeybinds do
			if keybindData._name == bindName then return keybindData end
		end

		return nil
	end

	function utility.Keybinds:deregister(bindName: string)
		local keybind = self:find(bindName)

		if keybind then
			local keybindIndex = table.find(self.registeredKeybinds, keybind)
			if keybindIndex then table.remove(self.registeredKeybinds, keybindIndex) end

			table.sort(self.registeredKeybinds, function(oldest, newest)
				if oldest._priority == newest._priority then return oldest._created > newest._created end

				return oldest.priority > newest._priority
			end)

			self:cancelTrigger()
			self._event:disconnect()
		end

		return self
	end

	--[[
		Keybind hidden setting
	
	]]
	function utility.Keybinds:register(
		bindName: string,
		registerOptions: {
			trigger: "PersonalKeybind", --// Default

			holdDuration: number?,

			keys: { [number]: Enum.KeyCode },

			description: string?,

			saveId: string?,
			priority: number?,
			hidden: boolean?,
			enabled: boolean?,
			locked: boolean?,
		} | {
			trigger: "CommandKeybind",

			commandLine: string?,
			commandKeybindId: string?,

			holdDuration: number?,

			keys: { [number]: Enum.KeyCode },

			description: string?,

			saveId: string?,
			priority: number?,
			hidden: boolean?,
			enabled: boolean?,
			locked: boolean?,
		} | {
			trigger: "Session",

			sessionId: string,
			eventId: string,

			holdDuration: number?,

			keys: { [number]: Enum.KeyCode },

			description: string?,

			saveId: string?, --// Defines the save id for clients to save and load their custom hotkeys onto this keybind
			priority: number?, --// How high is this keybind prioritized over others?
			hidden: boolean?, --// Hides the keybind from the client settings
			enabled: boolean?, --// Is the keybind enabled by default?
			locked: boolean?, --// Prevents the user from modifying the keybind
		}
	)
		--// Keybind name format: {Category}
		assert(not self:find(bindName), `Keybind {bindName} already exists`)
		if not string.match(bindName, `^CommandKeybind%.(.+)$`) then
			assert(
				string.match(bindName, `^%w+$`) == bindName or string.match(bindName, "^%w+%.%w+$") == bindName,
				`Bind name is incorrectly formatted as ACB123 OR ACB123.BCD456`
			)
		else
			assert(
				registerOptions.trigger == `CommandKeybind`,
				`Keybind trigger must be CommandKeybind if the category is listed as CommandKeybind`
			)
		end

		local keybindData = {
			_name = bindName,
			_saveId = registerOptions.saveId,

			enabled = if registerOptions.enabled ~= nil then not not registerOptions.enabled else true,
			hidden = registerOptions.hidden or false,
			locked = registerOptions.locked or false,
			description = registerOptions.description,
			holdDuration = math.clamp(registerOptions.holdDuration or 0, 0, 300),
			keys = table.clone(registerOptions.keys),
			defaultKeys = table.freeze(table.clone(registerOptions.keys)),

			_priority = math.max(registerOptions.priority or 0, 0),
			_created = tick(),
			_event = client.Signal.new(),
		}

		-- CORE FUNCTIONS --
		function keybindData:updateKeys(newKeys: { [number]: Enum.KeyCode })
			if service.tableMatch(self.keys, newKeys) then return self end
			self:cancelTrigger()
			self.keys = table.clone(newKeys)
			return self
		end

		function keybindData:updateHoldDuration(newHoldDuration: number)
			if type(newHoldDuration) ~= "number" then return self end
			self:cancelTrigger()
			self.holdDuration = math.clamp(newHoldDuration, 0, 300)
			return self
		end

		function keybindData:checkTrigger()
			local pressedKeys = utility.Keybinds._pressedKeys

			local firstKey = self.keys[1]
			local keysLen = #self.keys
			if firstKey and table.find(pressedKeys, firstKey) then
				if keysLen == 1 then return true end

				local firstKeyPressedIndex = table.find(pressedKeys, firstKey)
				local highestKeyIndex = firstKeyPressedIndex

				for i = 2, keysLen, 1 do
					local otherKey = self.keys[i]
					local otherKeyPressedIndex = table.find(pressedKeys, otherKey)

					if not otherKeyPressedIndex then return false end
					if highestKeyIndex + 1 ~= otherKeyPressedIndex then return false end

					highestKeyIndex = otherKeyPressedIndex
				end

				return true
			end

			return false
		end

		function keybindData:startTrigger()
			if service.UserInputService:GetFocusedTextBox() then return self end
			if client.clientSettingsWindow then return self end --// Prevents keybinds from being triggered while the client settings window is open
			if not client.Settings.KeybindsEnabled then return self end
			if not self.enabled then return self end

			self:cancelTrigger()

			if not self:checkTrigger() then return self end
			if self.holdDuration <= 0 then
				--warn(`Keybind {bindName} sync triggered`)
				if self._rateLimit then
					local didPassRL = utility:checkRate(self._rateLimit, `Keybind-{bindName}.{self._created}`)
					if not didPassRL then return self end
				end

				local didPassGlobalRL =
					utility:checkRate(utility.Keybinds.RateLimits.Global, `Keybind-{bindName}.{self.created}`)
				if not didPassGlobalRL then return self end

				self._event:fire(`Triggered`)
				self._checkPromise = nil
				return self
			end

			self._checking = true
			self._event:fire(`OnHold`)
			self._checkPromise = Promise.delay(self.holdDuration)
				:andThen(function() --// Check rate limit
					if self._rateLimit then
						local didPassRL = utility:checkRate(self._rateLimit, `Keybind-{bindName}.{self._created}`)
						if not didPassRL then return Promise.reject(`RL_FAIL`) end
					end

					local didPassGlobalRL =
						utility:checkRate(utility.Keybinds.RateLimits.Global, `Keybind-{bindName}.{self.created}`)
					if not didPassGlobalRL then return Promise.reject(`GLOBAL_RL_FAIL`) end
				end)
				:andThenCall(self._event.fire, self._event, `Triggered`)
				:andThen(function()
					self._checkPromise = nil
					self._checking = false
				end)
				:catch(function(err)
					err = tostring(err)
					if err == `RL_FAIL` or err == "GLOBAL_RL_FAIL" then self._event:fire(`RateLimited`, err) end
				end)

			return self
		end

		function keybindData:cancelTrigger()
			if self._checkPromise then
				if self._checkPromise:getStatus() == Promise.Status.Started then self._checkPromise:cancel() end
				self._checkPromise = nil
			end

			if self._checking then
				self._checking = false
				self._event:fire(`Canceled`)
			end

			return self
		end

		--------------------

		if registerOptions.trigger == "CommandKeybind" then
			keybindData.commandLine = registerOptions.commandLine
			keybindData.commandKeybindId = registerOptions.commandKeybindId

			keybindData._event:connect(function(eventType: string)
				if eventType ~= `Triggered` then return end

				if utility:checkRate(utility.Keybinds.RateLimits.TriggerCommand, `command`) then
					client.Network:fire("RunCmdKeybind", keybindData.commandKeybindId)
				end
			end)
		end

		if registerOptions.trigger == "Session" then
			assert(
				type(registerOptions.sessionId) == "string" and #registerOptions.sessionId > 0,
				`Session id must be a string and not empty`
			)
			assert(
				type(registerOptions.eventId) == "string" and #registerOptions.eventId > 0,
				`Event id must be a string and not empty`
			)

			keybindData._event:connect(function(eventType: string)
				if eventType ~= `Triggered` then return end

				if utility:checkRate(utility.Keybinds.RateLimits.TriggerCommand, `command`) then
					client.Network:fire("RunCmdKeybind", keybindData.commandKeybindId)
				end
			end)
			client.Network:fire("ManageSession", registerOptions.sessionId, "FireEvent", registerOptions.eventId)
		end

		if registerOptions.saveId then
			local isSaveIdInConflict = false
			for i, otherKeybind in self.registeredKeybinds do
				if otherKeybind.saveId == registerOptions.saveId then
					warn(
						`Keybind {bindName} save Id is in conflict with {otherKeybind._name}. Keybind save id will not persist.`
					)
					isSaveIdInConflict = true
				end
			end

			if isSaveIdInConflict then
				registerOptions.saveId = nil
				keybindData._saveId = nil
			end

			local savedKeycodes: { [number]: Enum.KeyCode } = variables.savedCustomKeybinds[registerOptions.saveId]
			if savedKeycodes then
				keybindData.keys = savedKeycodes
				keybindData:cancelTrigger()
			end
		end

		table.insert(self.registeredKeybinds, keybindData)
		table.sort(self.registeredKeybinds, function(oldest, newest)
			if oldest._priority == newest._priority then return oldest._created > newest._created end

			return oldest.priority > newest._priority
		end)

		return keybindData
	end

	function utility.Keybinds:setup()
		if self._setup then return self end
		self._setup = true

		local userInputBegan = client.Signal.new()
		userInputBegan:linkRbxEvent(service.UserInputService.InputBegan)
		userInputBegan:connect(function(input: InputObject)
			if input.KeyCode ~= Enum.KeyCode.Unknown and not table.find(self._pressedKeys, input.KeyCode) then
				local inputKeyCode = input.KeyCode
				table.insert(self._pressedKeys, inputKeyCode)

				Promise.each(self.registeredKeybinds, function(keybind)
					if table.find(keybind.keys, inputKeyCode) then
						--warn("keybind triggered?", keybind:checkTrigger())
						if (not keybind:checkTrigger()) or self._checking then return end
						keybind:startTrigger()
					end
				end)
			end
		end)

		local userInputEnded = client.Signal.new()
		userInputEnded:linkRbxEvent(service.UserInputService.InputEnded)
		userInputEnded:connect(function(input: InputObject)
			if input.KeyCode ~= Enum.KeyCode.Unknown and table.find(self._pressedKeys, input.KeyCode) then
				local index = table.find(self._pressedKeys, input.KeyCode)
				table.remove(self._pressedKeys, index)

				Promise.each(self.registeredKeybinds, function(keybind)
					if table.find(keybind.keys, input.KeyCode) then
						if not keybind:checkTrigger() and keybind._checking then keybind:cancelTrigger() end
					end
				end)
			end
		end)

		local userFocusOnTextBox = client.Signal.new()
		userFocusOnTextBox:linkRbxEvent(service.UserInputService.TextBoxFocused)
		userFocusOnTextBox:connect(function(textBox: TextBox)
			Promise.each(self.registeredKeybinds, function(keybind)
				if keybind._checking then keybind:cancelTrigger() end
			end)
		end)

		return self
	end
end

function utility:makeKeybinds(bindName, bindKeys, triggerType, arg2, arg3, arg4)
	local bindData = bindName and variables.userKeybinds[bindName]
	local setupData
	setupData = {
		active = true,
		holdDuration = 0,
		keybinds = {},

		triggered = client.Signal.new(),
	}

	function setupData:checkTrigger()
		if not self.enabled then return false end
		if #self.keybinds == 0 then return false end
		if client.clientSettingsWindow then return false end --// Prevents keybinds from being triggered while the client settings window is open

		local userInputS: UserInputService = service.UserInputService
		local isGamepadEnabled = userInputS.GamepadEnabled
		local availableGamepadKeyCodes = if isGamepadEnabled
			then userInputS:GetSupportedGamepadKeyCodes(Enum.UserInputType.Gamepad1)
			else nil

		local triggered = true
		local function doCheckTrigger()
			for i, key in pairs(self.keybinds) do
				local userInput = tostring(key):sub(1, 19) == "Enum.UserInputType."
				local keycode = tostring(key):sub(1, 13) == "Enum.KeyCode."

				if userInput then
					if not userInputS:IsMouseButtonPressed(key) then
						triggered = false
						break
					end
				elseif keycode then
					if isGamepadEnabled and table.find(availableGamepadKeyCodes, key) then
						if not userInputS:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, key) then
							triggered = false
							break
						end
					elseif not userInputS:IsKeyDown(key) then
						triggered = false
						break
					end
				end
			end
		end

		if self.holdDuration > 0 then
			local started = tick()
			--warn("Checking hold trigger..")
			repeat
				doCheckTrigger()
				service.RunService.Heartbeat:Wait()
			until not triggered or (tick() - started >= self.holdDuration)

			--warn(`Hold trigger finished. Status: {triggered}`)
		else
			doCheckTrigger()
		end

		return triggered
	end

	if bindName and (bindKeys and #bindKeys > 0) and not bindData then
		if triggerType == "Function" then
			local bindFunc = (
				type(arg2) == "string" and client.Loadstring(arg2, getEnv(nil, { player = service.player }))
			)
				or (type(arg2) == "function" and arg2)
				or nil

			if bindFunc then
				setupData.triggered:connect(function()
					if utility:checkRate(utility.Keybinds.RateLimits.Global, `function`) then bindFunc() end
				end)
			end
		elseif triggerType == "Event" then
			local eventId = arg2

			setupData.triggered:connect(function()
				if utility:checkRate(utility.Keybinds.RateLimits.Global, `event`) then
					client.Network:fire("FirePlayerEvent", eventId)
				end
			end)
		elseif triggerType == "Session" then
			local sessionOpts = arg2

			setupData.triggered:connect(function()
				if utility:checkRate(utility.Keybinds.RateLimits.Global, `session`) then
					client.Network:fire("ManageSession", sessionOpts.id, "FireEvent", sessionOpts.eventId)
				end
			end)
		elseif triggerType == "PersonalKeybind" then
			setupData.triggered:connect(function()
				if
					not client.clientSettingsWindow
					and client.Settings.KeybindsEnabled
					and utility:checkRate(utility.Keybinds.RateLimits.TriggerCommand, `command`)
				then
					client.Network:fire("RunCmdKeybind", arg2)
				end
			end)
		end

		if arg3 == "QuickAction" then
			local options = arg4
			local quickIcon = client.UI.makeElement "TopbarIcon"
			quickIcon:joinDropdown(client.quickAction, "dropdown")
			quickIcon:setName(service.getRandom())

			if options.Label then quickIcon:setLabel(options.Label) end

			if options.Caption then quickIcon:setCaption(options.Caption) end

			if options.Tip then quickIcon:setTip(options.Tip) end

			if options.Image then quickIcon:setImage(options.Image) end

			quickIcon.selected:Connect(function()
				if setupData.active then setupData.triggered:fire() end
				quickIcon:deselect()
			end)

			setupData.quickIcon = quickIcon
		end

		for i, key in pairs(bindKeys) do
			if type(key) == "string" then
				if key:sub(1, 14) == "UserInputType-" then
					table.insert(setupData.keybinds, Enum.UserInputType[key:sub(15)])
				end

				if key:sub(1, 8) == "KeyCode-" then table.insert(setupData.keybinds, Enum.KeyCode[key:sub(9)]) end
			elseif typeof(key) == "EnumItem" then
				local keyName = tostring(key)

				if key.EnumType == Enum.UserInputType or key.EnumType == Enum.KeyCode then
					table.insert(setupData.keybinds, key)
				end
			end
		end

		variables.userKeybinds[bindName] = setupData
		return setupData
	end
end

function utility:removeKeybinds(bindName: string)
	local keybindData = variables.userKeybinds[bindName]
	if keybindData then
		if keybindData.quickIcon then keybindData.quickIcon:destroy() end

		keybindData.active = false
		variables.userKeybinds[bindName] = nil
	end
end

-- Notification System
utility.Notifications = {}

function utility.Notifications:setup()
	local TopbarIcon = client.UI
		.makeElement("TopbarIcon")
		:setEnabled(false)
		:modifyTheme(client.TopbarIconTheme.Base)
		-- :joinMenu(client.quickAction)
		:setImage("rbxassetid://83961147818491")
		:setCaption(`Notifications`)
		:setOrder(300)
		:oneClick()

	TopbarIcon.selected:Connect(function()
		local notifHandler = variables.notifV2Container or client.UI.construct(`Handlers.Notifications`)
		notifHandler:toggleFullPanel()
	end)

	-- Construct the Notifications Handler
	client.UI.construct(`Handlers.Notifications`)

	utility.Notifications.TopbarIcon = TopbarIcon
	utility.Notifications.setup = nil
end

function utility.Notifications:create(constructData) return client.UI.construct(`NotificationV2`, constructData) end

function utility.Notifications:clear(notificationId: string)
	local notifHandler = variables.notifV2Container or client.UI.construct(`Handlers.Notifications`)
	local notif = notifHandler:findNotificationById(notificationId)

	if notif then notifHandler:remove(notif) end
	return self
end

function utility.Notifications:clearAll()
	local notifHandler = variables.notifV2Container or client.UI.construct(`Handlers.Notifications`)
	notifHandler:clear()
	return self
end

-- Selection system (get players by mouse)

-- Tracking system
utility.Tracking = {
	_players = {},

	maxPlayersToTrack = 20,
}


function utility.Tracking:trackPlayer(player: Player)
	if self._players[player.UserId] then
		local existingInfo = self._players[player.UserId]
		if existingInfo._player ~= player then existingInfo._player = player end

		existingInfo._events:findSignal(`Disconnect`):stopRbxEvents():linkRbxEvent(player.Destroying)

		existingInfo._events:findSignal(`Character`):stopRbxEvents():linkRbxEvent(player.CharacterAdded)

		existingInfo._events:findSignal(`Character`):linkRbxEvent(service.player.CharacterAdded)

		if player.Character then existingInfo:reConstruct() end

		return existingInfo
	end

	--if service.player == player then return nil end
	if service.tableCount(self._players) + 1 > self.maxPlayersToTrack then
		local firstIndex, firstTrackingInfo = next(self._players)

		utility.Notifications:create {
			title = `Player Tracking exceeded`,
			desc = `You have exceeded the number of players ({self.maxPlayersToTrack}) to track. In addition, one of your tracked players {firstTrackingInfo._player.Name} was removed.`,
			time = 300,
		}

		utility.Tracking:stopTrackingPlayer(firstTrackingInfo)
	end

	local eventHandler = client.Signal:createHandler()
	local obliterator = client.Janitor.new()
	local trackingInfo = {
		userId = player.UserId,
		active = true,

		trackingColor = Color3.fromRGB(math.random(50, 255), math.random(50, 255), math.random(50, 255)),

		_player = player,
		_events = eventHandler,
		_obliterator = obliterator,
	}

	function trackingInfo:reConstruct()
		if not trackingInfo.active then return self end

		if self._reConstructTask then
			self._reConstructTask:cancel()
			self._reConstructTask = nil
		end

		self._obliterator:Cleanup()

		local targetCharacter = self._player.Character
		if not targetCharacter then return self end

		local selfCharacter = service.player.Character
		if not selfCharacter then return self end

		local targetTorso, selfTorso

		self._reConstructTask = Promise.promisify(function()
			targetTorso = targetCharacter:WaitForChild("HumanoidRootPart", 20)
				or targetCharacter:FindFirstChild "Torso"
				or targetCharacter:FindFirstChild "UpperTorso"
			selfTorso = selfCharacter:WaitForChild("HumanoidRootPart", 20)
				or selfCharacter:FindFirstChild "Torso"
				or selfCharacter:FindFirstChild "UpperTorso"
		end)():andThen(function()
			local RankTag = client.AssetsFolder.TrackingTag:Clone()
			RankTag.Enabled = true
			RankTag.Frame.Rank.Text = if self._player.Name == self._player.DisplayName
				then self._player.Name
				else `{self._player.DisplayName} (@{self._player.Name})`
			RankTag.Parent = targetTorso

			self._obliterator:Add(RankTag)

			local selfAttachment = service.New(`Attachment`, {
				Name = `_ESS-TRACK-ATTACHMENT-{self._player.UserId}`,
				Parent = selfTorso,
			})

			self._obliterator:Add(selfAttachment)

			local targetAttachment = service.New(`Attachment`, {
				Name = `_ESS-TRACK-ATTACHMENT-{self._player.UserId}`,
				Parent = targetTorso,
			})

			self._obliterator:Add(targetAttachment)

			local TrackingBeam = client.AssetsFolder.TrackingBeam:Clone()
			TrackingBeam.Color = ColorSequence.new(self.trackingColor)
			TrackingBeam.Name = `_ESS-` .. TrackingBeam.Name .. `_{self._player.UserId}`
			TrackingBeam.Enabled = true
			TrackingBeam.Attachment0 = selfAttachment
			TrackingBeam.Attachment1 = targetAttachment
			TrackingBeam.Parent = targetTorso

			self._obliterator:Add(TrackingBeam)

			local TargetHighlight = service.New("Highlight", {
				Name = `_ESS-TrackingHighlight-{self._player.UserId}`,
				Adornee = targetCharacter,
				Parent = targetCharacter,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
				Enabled = true,
				FillColor = Color3.fromRGB(53, 73, 255),
				FillTransparency = 1,
				OutlineColor = self.trackingColor,
				OutlineTransparency = 0,
			})

			self._obliterator:Add(TargetHighlight)
		end)

		return self
	end

	function trackingInfo:destroy()
		trackingInfo.active = false
		self._events:killSignals()
		self._obliterator:Destroy()
	end

	local onDisconnect = eventHandler.new(`Disconnect`)
	onDisconnect:linkRbxEvent(player.Destroying)
	onDisconnect:connect(function()
		trackingInfo.active = false
		self._obliterator:Cleanup()
	end)

	local onCharacterAdded = eventHandler.new(`Character`)
	onCharacterAdded:linkRbxEvent(player.CharacterAdded)
	onCharacterAdded:linkRbxEvent(service.player.CharacterAdded)
	onCharacterAdded:connect(function(char) trackingInfo:reConstruct() end)

	if player.Character then trackingInfo:reConstruct() end

	-- Setup quick action
	if not utility.Tracking.quickAction then
		local quickIcon = client.UI
			.makeElement("TopbarIcon")
			:joinDropdown(client.quickAction, "dropdown")
			:setLabel(`👀 View tracked users`)
			:setName(service.getRandom())
			:oneClick()

		utility.Tracking.quickAction = quickIcon

		quickIcon.selected:Connect(function()
			local listOfTrack = {}
			local listWindow

			for playerUserId, trackData in self._players do
				table.insert(listOfTrack, {
					_id = tostring(playerUserId),
					type = "Action",
					label = if trackingInfo._player.DisplayName == trackingInfo._player.Name
						then trackingInfo._player.Name
						else `{trackingInfo._player.DisplayName} (@{trackingInfo._player.Name})`,
					selectable = true,

					options = {
						{
							label = "Untrack",
							onExecute = function()
								warn(`did track?`)
								listWindow:deleteOptionById(tostring(playerUserId))
								utility.Tracking:stopTrackingPlayer(playerUserId)
							end,
						},
					},
				})
			end

			listWindow = client.UI.construct("List", {
				Title = `Tracking Users`,
				List = listOfTrack,
			})
		end)
	end

	self._players[player.UserId] = trackingInfo

	return trackingInfo
end

function utility.Tracking:stopTrackingPlayer(playerUserId: number)
	local existingTracker = self._players[playerUserId]
	if existingTracker then
		existingTracker:destroy()
		self._players[playerUserId] = nil
	end

	if not next(self._players) and utility.Tracking.quickAction then
		utility.Tracking.quickAction:destroy()
		utility.Tracking.quickAction = nil
	end
end

--// Adonis fly remake
utility.Fly = {}

function utility:beginFly()
	if not utility.Fly._state then
		utility.Fly._state = true

		if not utility.Fly._handler then utility.Fly._handler = client.Signal:createHandler() end

		local signalHandler = utility.Fly._handler

		local playerChar = service.player and service.player.Character
		local humanoidRootPart = playerChar and playerChar:FindFirstChild "HumanoidRootPart"
		local humanoid = playerChar and playerChar:FindFirstChildOfClass "Humanoid"
		local inputService = service.UserInputService

		local rbxConnections = {}
		local activeDirection = {}
		local activeControls = {}
		local bodyGyro, bodyPos
		local flySpeed = 30
		local deltaSpeed = 1
		local curSpeed = 1
		local maxAccelerationTick = 20
		local clamp = math.clamp

		local function createBodyObjects()
			if not bodyPos or bodyPos.Parent ~= humanoidRootPart then
				if bodyPos then service.Debris:AddItem(bodyPos, 1) end

				bodyPos = service.New("AlignPosition", {
					MaxForce = math.huge,
					Position = humanoidRootPart.Position + Vector3.new(0, (humanoidRootPart.Size.Y / 2) + 0.5, 0),
					Name = "_ESSFLYPOS",
					Parent = humanoidRootPart,
					Archivable = false,
				})
			end

			if not bodyGyro or bodyGyro.Parent ~= humanoidRootPart then
				if bodyGyro then service.Debris:AddItem(bodyGyro, 1) end

				bodyGyro = service.New("AlignOrientation", {
					MaxTorque = 9e9, -- Vector3.new(math.huge, math.huge, math.huge);
					CFrame = humanoidRootPart.CFrame,
					Name = "_ESSFLYGYRO",
					Parent = humanoidRootPart,
					Archivable = false,
				})
			end
		end

		local function addRbxConnection(rbxEvent, func)
			local signal = signalHandler.new(`RbxConnection`)
			signal.debugError = true
			signal:connect(func)
			return signal:linkRbxEvent(rbxEvent)
		end

		local function getCFrame(part, isForZCord)
			local currentCamera = workspace.CurrentCamera

			local partCF = part.CFrame
			local noRotation = CFrame.new(partCF.p)
			local x, y, z = (currentCamera.CoordinateFrame - currentCamera.CoordinateFrame.p):toEulerAnglesXYZ()
			return noRotation * CFrame.Angles(isForZCord and z or x, y, z)
		end

		local function checkInputProcess(input: InputObject, inGameProcess: boolean, started: boolean)
			if
				input.UserInputType == Enum.UserInputType.Keyboard
				or input.UserInputType == Enum.UserInputType.Gamepad1
			then
				if input.KeyCode == Enum.KeyCode.ButtonA then
					activeDirection.Up = started
					activeControls.Up = started
				end

				if not inGameProcess then
					if input.KeyCode == Enum.KeyCode.W then
						activeDirection.Forward = started
						activeControls.Forward = started
					elseif input.KeyCode == Enum.KeyCode.S then
						activeDirection.Backward = started
						activeControls.Backward = started
					elseif input.KeyCode == Enum.KeyCode.A then
						activeDirection.Left = started
						activeControls.Left = started
					elseif input.KeyCode == Enum.KeyCode.D then
						activeDirection.Right = started
						activeControls.Right = started
					elseif
						input.KeyCode == Enum.KeyCode.Q
						or input.KeyCode == Enum.KeyCode.DPadDown
						or input.KeyCode == Enum.KeyCode.ButtonB
					then
						activeDirection.Down = started
						activeControls.Down = started
					elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.DPadUp then
						activeDirection.Up = started
						activeControls.Up = started
					elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonL3 then
						--toggle
					end
				end
			end
		end

		local function checkIdle()
			return not (
				activeDirection.Left
				or activeDirection.Right
				or activeDirection.Up
				or activeDirection.Down
				or activeDirection.Forward
				or activeDirection.Backward
			)
		end

		addRbxConnection(inputService.InputBegan, function(input, inGameProcess)
			warn(pcall(function() checkInputProcess(input, inGameProcess, true) end))
			warn "Input started"
		end)

		addRbxConnection(inputService.InputEnded, function(input, inGameProcess)
			warn(pcall(function() checkInputProcess(input, inGameProcess, false) end))
			warn "Input ended"
		end)

		utility.flyRbxConnections = rbxConnections

		local oldDirection
		service.loopTask("Fly command", 0.1, function()
			playerChar = service.player and service.player.Character
			humanoidRootPart = playerChar and playerChar:FindFirstChild "HumanoidRootPart"
			humanoid = playerChar and playerChar:FindFirstChildOfClass "Humanoid"

			local currentCamera = workspace.CurrentCamera
				or service.New("Camera", {
					Name = service.getRandom(),
					Parent = workspace,
					Archivable = false,
				})
			workspace.CurrentCamera = currentCamera

			if utility.Fly._state and (playerChar and humanoidRootPart) then
				createBodyObjects()

				--local newDirection = humanoid.MoveDirection

				--if oldDirection and newDirection ~= oldDirection then
				--	directFromPart(humanoidRootPart, newDirection)
				--	oldDirection = newDirection
				--end

				local newBodyCF = bodyGyro.CFrame.Rotation + bodyPos.Position
				if checkIdle() then
					deltaSpeed = 1
				else
					if activeDirection.Forward then
						newBodyCF = newBodyCF + currentCamera.CFrame.LookVector * deltaSpeed
						curSpeed += deltaSpeed
					end

					if activeDirection.Backward then
						newBodyCF = newBodyCF - currentCamera.CFrame.LookVector * deltaSpeed
						curSpeed += deltaSpeed
					end

					if activeDirection.Left then
						newBodyCF = newBodyCF + Vector3.new(-deltaSpeed, 0, 0)
						curSpeed += deltaSpeed
					end

					if activeDirection.Right then
						newBodyCF = newBodyCF + Vector3.new(deltaSpeed, 0, 0)
						curSpeed += deltaSpeed
					end

					if activeDirection.Up then
						newBodyCF = newBodyCF * CFrame.new(0, deltaSpeed, 0)
						curSpeed += deltaSpeed
					end

					if activeDirection.Down then
						newBodyCF = newBodyCF * CFrame.new(0, -deltaSpeed, 0)
						curSpeed += deltaSpeed
					end

					if curSpeed > maxAccelerationTick then curSpeed = maxAccelerationTick end
				end

				humanoid.PlatformStand = true
				bodyPos.Position = newBodyCF.Position

				if activeDirection.Forward then
					bodyGyro.CFrame = currentCamera.CFrame * CFrame.Angles(-math.rad(flySpeed * 7.5), 0, 0)
				elseif activeDirection.Backward then
					bodyGyro.CFrame = currentCamera.CFrame * CFrame.Angles(math.rad(flySpeed * 7.5), 0, 0)
				else
					bodyGyro.CFrame = currentCamera.CFrame
				end
			end
		end)
	end
end

function utility:stopFly()
	if utility.Fly._state then utility.Fly._state = false end
end

-- INIT
function utility.Init(env)
	client = env.client
	service = env.service
	variables = env.variables
	getEnv = env.getEnv
	Promise = env.client.Promise

	utility.Keybinds:setup()
	utility.Notifications:setup()

	-- Player Added check

	service.Players.PlayerAdded:Connect(function(player: Player)
		if utility.Tracking._players[player.UserId] then utility.Tracking:trackPlayer(player) end
	end)
end

return utility
