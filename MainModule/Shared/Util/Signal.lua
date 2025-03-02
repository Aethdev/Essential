--[[
	ESSENTIAL SIGNAL V1.7
	  > Creator: trzistan
	  
	- Main utility for event creation & handling
]]

local Signal = {}
Signal.__index = Signal
Signal.__tostring = function() return "Signal" end

local waitManager = {}
waitManager.waitQueue = {}
do
	local runService = game:GetService "RunService"

	function waitManager:start()
		if not self.heartbeatEv then
			self.heartbeatEv = runService.Heartbeat:Connect(function()
				if #waitManager.waitQueue > 0 then
					for i, waitQue in waitManager.waitQueue do
						if tick() - waitQue.endTick >= 0 and not waitQue.doneWatching then
							waitQue.doneWatching = true
							table.remove(waitManager.waitQueue, i)
							task.spawn(waitQue.callback)
							break
						end
					end
				else
					if self.heartbeatEv.Connected then self.heartbeatEv:Disconnect() end
				end
			end)
		end
	end

	function waitManager:add(waitDelay: number, callback)
		local queData = {
			doneWatching = false,
			callback = callback,
			endTick = tick() + (waitDelay or math.huge),
		}

		function queData:delete()
			if not queData.doneWatching then
				queData.doneWatching = true
				local findQue = table.find(waitManager.waitQueue, queData)
				if findQue then table.remove(waitManager.waitQueue, findQue) end
			end
		end
		queData.cancel = queData.delete

		table.insert(self.waitQueue, queData)
		waitManager:start()

		return queData
	end
end

local type = type
local setmetatable = setmetatable
local taskSpawn = task.spawn
local pairs = pairs
local rawequal = rawequal
local table = table
local coroutine = coroutine
local corotYield, corotResume, corotRunning = coroutine.yield, coroutine.resume, coroutine.running
local corotStatus = coroutine.status
local taskDelay = task.delay
local typeof = typeof
local rawget = rawget
local unpack = unpack
local os = os
local tostring = tostring
local math = math
local delay = delay
local unpack = unpack
local game = game
local error = error
--local warn = warn
local Instance = Instance
local rawequal = rawequal
local tick = tick
local realWait = wait
local runService = game:GetService "RunService"
local isServer = runService:IsServer()
local realWarn = warn
local function warn(...) realWarn(`:: ESS Signal {(isServer and "Server") or "Client"} ::`, ...) end

local wait = function(...): number return (Signal.customWait or realWait)(...) end
local cloneTable = function(tab: { [any]: any }): { [any]: any }
	local clone
	clone = function(val: any)
		if type(val) == "table" then
			local newVal = {}

			for i, v in pairs(val) do
				if rawequal(v, val) then
					newVal[i] = v
					continue
				end

				newVal[i] = clone(v)
			end

			return newVal
		else
			return val
		end
	end

	return clone(tab)
end

local function makeOneTimeRbxConnection(rbxScriptSignal: RBXScriptSignal, func: () -> any): RBXScriptConnection
	local connection
	connection = rbxScriptSignal:Connect(function(...)
		if connection.Connected then connection:Disconnect() end
		taskSpawn(func, ...)
	end)

	return connection
end

local sub = string.sub
local byte = string.byte
local gsub = string.gsub
local osTime = os.time

local base64Encode = function(data)
	return (
		gsub(gsub(data, ".", function(x)
			local r, b = "", byte(x)
			for i = 8, 1, -1 do
				r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0")
			end
			return r
		end) .. "0000", "%d%d%d?%d?%d?%d?", function(x)
			if #x < 6 then return "" end
			local c = 0
			for i = 1, 6 do
				c = c + (sub(x, i, i) == "1" and 2 ^ (6 - i) or 0)
			end
			return sub("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", c + 1, c + 1)
		end) .. ({
			"",
			"==",
			"=",
		})[#data % 3 + 1]
	)
end

function Signal.is(anything: any): boolean return getmetatable(anything) == Signal end

function Signal.new(exemptions: { [any]: any }?): { [any]: any }
	local self = setmetatable({}, Signal)

	self.active = true
	self.debugError = false
	self.links = {}
	self.rbxLinks = {}
	self.signalLinks = {}
	self.otherSignalLinks = {}
	self.disconnectOnLinks = {}
	self.functions = {}
	self.errors = {}
	self.fired = {}
	self.exemptions = (type(exemptions) == "table" and exemptions) or {}
	self.id = base64Encode(`{tick()}-{osTime()}`)

	return self
end

function Signal:linkRbxEvent(rbxEvent: RBXScriptSignal): RBXScriptConnection
	if self.active then
		local eventCon = rbxEvent:Connect(function(...)
			if self.active then self:fire(...) end
		end)

		table.insert(self.rbxLinks, eventCon)
		return eventCon
	end
end

function Signal:linkSignal(otherSignal: { [any]: any }): { [any]: any }
	if self.active and otherSignal.active then
		local existingSignalLink = self:getSignalLinkWithSignal(otherSignal)
		if existingSignalLink then return existingSignalLink end

		local signalLink = otherSignal:connect(function(...) self:fire(...) end)

		if signalLink ~= "cannot_connect" then
			signalLink._otherSignalId = otherSignal.id
			signalLink._linkedSignal = self
			table.insert(self.signalLinks, signalLink)

			if not otherSignal.__wrapped then table.insert(otherSignal.otherSignalLinks, signalLink) end
		end

		return signalLink
	end
end

function Signal:unlinkSignal(otherSignal: { [any]: any })
	if self.active then
		for i, otherSignalLink in otherSignal.otherSignalLinks do
			if rawequal(otherSignalLink._linkedSignal, self) then otherSignalLink:disconnect() end
		end
	end
end

function Signal:getSignalLinkWithSignal(otherSignal)
	if self.active then
		local foundSignalLink
		local otherSignalId = otherSignal.id
		for i, signalLink in self.signalLinks do
			if signalLink._otherSignalId == otherSignalId then return signalLink end
		end

		for i, otherLink in self.disconnectOnLinks do
			if otherLink.signalId == otherSignal.id then return otherLink end
		end
	end
end

function Signal:removeSignalLink(signalLink)
	if self.active then
		local linkIndex = table.find(self.signalLinks, signalLink)
		if linkIndex then
			table.remove(self.signalLinks, linkIndex)
			signalLink._linkedSignal = nil

			if signalLink.active then signalLink:disconnect() end
		end
	end

	return self
end

function Signal:stopRbxEvents(): boolean
	if self.active then
		for i, rbxLink in self.rbxLinks do
			if rbxLink.Disconnect then rbxLink:Disconnect() end

			self.rbxLinks[i] = nil
		end
	end

	return self
end

function Signal:stopSignalLinks(): boolean
	if self.active then
		for i, otherSignalLink in self.signalLinks do
			if otherSignalLink.Disconnect then otherSignalLink:Disconnect() end

			self.signalLinks[i] = nil
		end
	end

	return self
end

function Signal:stopLinks(): boolean
	if self.active then
		for i, link in self.links do
			link:disconnect()
			self.links[i] = nil
		end
	end

	return self
end

function Signal:disconnect(delay: number, force): boolean
	if self.active then
		local function doDisconnect()
			if not self.disconnecting then
				self.active = false
				self.disconnecting = true

				for i, link in self.links do
					link:disconnect()
					self.links[i] = nil
				end

				for i, rbxLink in self.rbxLinks do
					if rbxLink.Disconnect then rbxLink:Disconnect() end

					self.rbxLinks[i] = nil
				end

				for i, otherSignalLink in self.signalLinks do
					if otherSignalLink.Disconnect then otherSignalLink:Disconnect() end

					self.signalLinks[i] = nil
				end

				for i, otherSignalLink in self.otherSignalLinks do
					if otherSignalLink.Disconnect then otherSignalLink:Disconnect() end

					self.otherSignalLinks[i] = nil
				end

				if self.unlinkFunc then task.defer(self.unlinkFunc, self) end
			end
		end

		if delay then
			taskDelay(math.abs(delay), doDisconnect)
		else
			task.defer(doDisconnect)
		end

		return true
	end
end
Signal.Disconnect = Signal.disconnect
Signal.stop = Signal.disconnect
Signal.destroy = Signal.disconnect

function Signal:disconnectOn(otherSignal)
	assert(Signal.is(otherSignal), `The provided Signal is not a Signal`)
	assert(otherSignal ~= self or otherSignal.id ~= self.id, `Cannot create a disconnect event on itself`)
	assert(
		not self:getSignalLinkWithSignal(otherSignal),
		`The provided signal has an existing signal link to this signal`
	)

	for i, otherLink in self.disconnectOnLinks do
		if otherLink.signalId == otherSignal.id then return otherLink end
	end

	local disconnectLink = otherSignal:connectOnce(function() self:disconnect() end)

	table.insert(self.disconnectOnLinks, disconnectLink)
	return disconnectLink
end

function Signal:connect(func: Function, deferred: boolean?): { [any]: any }
	if not rawequal(type(func), "function") then return "invalid_function" end

	if self.active then
		local signal = self
		local signalId = Signal.id
		local link = {}

		link.active = true
		link.deferred = not not deferred
		link.id = `{signalId}-{base64Encode(`{tick()}.{osTime()}`)}`
		link.signalId = signalId
		link.errors = {}

		function link:disconnect(delay)
			if self.active and not self.disconnecting then
				self.active = false
				self.disconnecting = true

				if delay and delay > 0 and runService:IsRunning() then wait(delay) end

				if self._linkedSignal then self._linkedSignal:removeSignalLink(self) end

				if link.allowFireOnDisconnect then
					taskSpawn(function()
						local exitThread = coroutine.create(func)
						local suc, ret = corotResume(exitThread, nil)

						if not suc then
							local debugTrace = debug.traceback(exitThread)
							if signal.debugError or link.debugError then
								warn(
									"Signal "
										.. signal.id
										.. " link "
										.. self.id
										.. " encountered an error while running:",
									ret,
									debugTrace
								)
							end

							table.insert(signal.errors, {
								func = tostring(func),
								result = ret,
								time = os.time(),
								trace = debugTrace,
							})
							table.insert(self.errors, {
								result = ret,
								time = os.time(),
								debugTrace = debugTrace,
							})
						end
					end)
				end

				--self.disconnect = nil
				local foundLink = table.find(signal.links, link)

				if foundLink then table.remove(signal.links, foundLink) end

				self.disconnecting = false
			end
		end
		link.Disconnect = link.disconnect

		function link:fire(isDeferred: boolean?, ...)
			if self.active then
				if self.debugArguments or signal.debugArguments then
					table.insert(signal.fired, {
						arguments = { ... },
						time = os.time(),
					})
				end
				(if isDeferred or self.deferred then task.defer else taskSpawn)(function(...)
					local thread = coroutine.create(func)
					local suc, ret = corotResume(thread, ...)

					if not suc then
						local debugTrace = debug.traceback(thread)
						if signal.debugError or link.debugError then
							warn(
								"Signal " .. signal.id .. " link " .. self.id .. " encountered an error while running:",
								ret,
								debugTrace
							)
						end

						table.insert(signal.errors, {
							func = tostring(func),
							result = ret,
							time = os.time(),
							trace = debugTrace,
						})
						table.insert(self.errors, {
							result = ret,
							time = os.time(),
							debugTrace = debugTrace,
						})
					end
				end, ...)
			end
		end
		link.Fire = link.fire

		table.insert(self.links, link)

		return link
	else
		return "cannot_connect"
	end
end
Signal.Connect = Signal.connect

function Signal:deferConnect(func: () -> any) return Signal:connect(func, true) end
Signal.DeferConnect = Signal.deferConnect

function Signal:selfConnect(func: FunctionalTest): { [any]: any }
	if not rawequal(type(func), "function") then return "invalid_function" end

	if self.active then
		local eventCon
		eventCon = self:connect(function(...) return func(eventCon, ...) end)

		return eventCon
	end
end
Signal.SelfConnect = Signal.selfConnect

function Signal:connectOnce(func: FunctionalTest): { [any]: any }
	if self.active then
		local traceback = debug.traceback(nil, 2)
		local link
		link = self:connect(function(...)
			if link.active then
				link:disconnect()
				if type(func) == "function" then func(...) end
			end
		end)

		if type(link) == "table" then return link end
	end
end
Signal.connectonce = Signal.connectOnce
Signal.ConnectOnce = Signal.connectOnce

function Signal:_fire(deferred: boolean?, ...): any
	if self.active then
		local params = { ... }

		for i, param in params do
			local typ = type(param)
			local typOf = typeof(param)

			if rawget(self.exemptions, typ) or rawget(self.exemptions, typOf) then -- Check whether parameter was part of the exemption
				table.remove(params, i) -- Remove it if found
			end
		end

		params = { unpack(params) }
		for i, link in table.clone(self.links) do
			link:fire(deferred, unpack(params))
		end
	else
		return "inactive/not_allowed"
	end
end

function Signal:fire(...) return self:_fire(false, ...) end
Signal.Fire = Signal.fire

function Signal:deferFire(...) return self:_fire(true, ...) end
Signal.DeferFire = Signal.deferFire

function Signal:wait(delay: number?, idleTimeout: number?): any
	delay = (type(delay) == "number" and math.abs(delay)) or 0
	idleTimeout = (type(idleTimeout) == "number" and math.abs(idleTimeout)) or nil
	idleTimeout = (idleTimeout and idleTimeout < 1 and 1) or idleTimeout or nil

	if self.active then
		--if runService:IsServer() and not (delay > 0 or idleTimeout) then
		--	warn("Infinite wait possible from source")
		--	warn(debug.traceback(nil, 2))
		--end

		local fired
		local started = os.clock()
		local error
		local event = self:connectOnce(function(...) fired = { ... } end)

		if not runService:IsRunning() then return end

		-- NOTE: Due to the nature of some functions that are sensitive to yieldable threads, it is not possible to allow
		repeat
			--wait(0.01)
			runService.Heartbeat:Wait()
		until not runService:IsRunning()
			or not (event.active and self.active)
			or fired ~= nil
			or (idleTimeout and os.clock() - started > idleTimeout)

		fired = fired or {}

		if delay > 0 then task.wait(delay) end

		if not fired then return nil end
		return unpack(fired)
	else
		return "Inactive_Signal"
	end
end

function Signal:waitOnThread(delay: number?, idleTimeout: number?): any
	delay = (type(delay) == "number" and math.abs(delay)) or 0
	idleTimeout = (type(idleTimeout) == "number" and math.abs(idleTimeout)) or nil
	idleTimeout = (idleTimeout and idleTimeout < 1 and 1) or idleTimeout or nil

	assert(coroutine.isyieldable(), `Signal:wait() is not allowed in this thread due to lack of thread yieldability`)

	if self.active then
		--if runService:IsServer() and not (delay > 0 or idleTimeout) then
		--	warn("Infinite wait possible from source")
		--	warn(debug.traceback(nil, 2))
		--end

		if not runService:IsRunning() then return end

		local corotThread = coroutine.running()
		local cleanUp
		local eventLink
		eventLink = self:connectOnce(function(...)
			if self.debug then warn "Event called" end
			if cleanUp then taskSpawn(cleanUp) end
			if corotStatus(corotThread) == "suspended" then taskSpawn(corotThread, ...) end
		end)
		eventLink.allowFireOnDisconnect = true

		local gameCloseConnection = makeOneTimeRbxConnection(game.Close, function()
			if self.debug then warn "Game close called" end
			if cleanUp then taskSpawn(cleanUp) end
			if corotStatus(corotThread) == "suspended" then taskSpawn(corotThread) end
		end)
		local idleTimeoutThread: thread? = if idleTimeout and idleTimeout > 0
			then taskDelay(idleTimeout, function()
				if self.debug then warn "Idle timeout called" end
				if cleanUp then taskSpawn(cleanUp) end
				if corotStatus(corotThread) == "suspended" then taskSpawn(corotThread) end
			end)
			else nil

		cleanUp = function()
			if idleTimeoutThread and corotStatus(idleTimeoutThread) == "suspended" then
				task.cancel(idleTimeoutThread)
			end
			--if gameCloseConnection.Connected then task.defer(gameCloseConnection.Disconnect, gameCloseConnection) end
			--if eventLink.active then eventLink:disconnect() end
		end

		return corotYield()
	else
		return "Inactive_Signal"
	end
end

function Signal:waitOnMultipleEvents(events: { [any]: any }, delay: number?, idleTimeout: number?): { [any]: any }
	if rawequal(Signal, self) then
		delay = (type(delay) == "number" and math.abs(delay)) or 0
		idleTimeout = (type(idleTimeout) == "number" and math.abs(idleTimeout)) or nil
		idleTimeout = (idleTimeout and idleTimeout < 1 and 1) or idleTimeout

		local eventCons = {}
		local eventsCount = #events
		local results = {}

		if eventsCount > 0 then
			if not runService:IsRunning() then return results end

			for i, event in events do
				local eventType = tostring(event)

				if eventType == "Signal" or eventType == "SignalWrap" then -- Essential signals
					table.insert(eventCons, event:connectOnce(function(...) table.insert(results, { ... }) end))
				elseif string.match(eventType, "Signal (.+)") then -- Roblox script signals
					local eventCon
					eventCon = event:connect(function(...)
						eventCon:Disconnect()
						table.insert(results, { ... })
					end)

					table.insert(eventCons, eventCon)
				end
			end

			local stWait = os.time()
			repeat
				wait()
			until not runService:IsRunning()
				or (idleTimeout and os.time() - stWait > idleTimeout)
				or (#results == eventsCount)
				or not self.active

			-- Disconnect events after completion or idle timeout
			for i, eventCon in eventCons do
				if eventCon.Disconnect then eventCon:Disconnect() end
			end

			if delay > 0 then wait(delay) end
		end

		return results
	end
end

function Signal:waitOnSingleEvents(events: { [any]: any }, delay: number?, idleTimeout: number?): any
	if rawequal(Signal, self) then
		delay = (type(delay) == "number" and math.abs(delay)) or 0
		idleTimeout = (type(idleTimeout) == "number" and math.abs(idleTimeout)) or nil
		idleTimeout = (idleTimeout and idleTimeout < 1 and 1) or idleTimeout

		if not runService:IsRunning() then return nil end

		local eventCons = {}
		local eventsCount = #events
		local results = {}
		local readyToPass = false
		local readyToReturn = false

		if eventsCount > 0 then
			for i, event in events do
				local eventType = tostring(event)

				if eventType == "Signal" or eventType == "SignalWrap" or eventType == "SignalConnect" then -- Essential signals
					table.insert(
						eventCons,
						event:connectOnce(function(...)
							if not readyToPass then
								readyToPass = true

								for _, param in { ... } do
									table.insert(results, param)
								end

								readyToReturn = true
							end
						end)
					)
				elseif string.match(eventType, "Signal (.+)") then -- Roblox script signals
					local eventCon
					eventCon = event:connect(function(...)
						eventCon:Disconnect()
						if not readyToPass then
							readyToPass = true

							for _, param in { ... } do
								table.insert(results, param)
							end

							readyToReturn = true
						end
					end)

					table.insert(eventCons, eventCon)
				end
			end

			local stWait = os.time()
			repeat
				wait()
			until not runService:IsRunning() or (idleTimeout and os.time() - stWait > idleTimeout) or readyToReturn

			-- Disconnect events after completion or idle timeout
			for i, eventCon in eventCons do
				if eventCon.Disconnect then eventCon:Disconnect() end
			end

			if delay > 0 then wait(delay) end
		else
			error("There were no events listed to register a wait listener", 0)
		end

		return unpack(results)
	end
end

function Signal:processAfterSingleEvent(events: { [any]: any }, idleTimeout: number?, callback, endCallback): any
	if rawequal(Signal, self) then
		idleTimeout = (type(idleTimeout) == "number" and math.abs(idleTimeout)) or nil
		idleTimeout = (idleTimeout and idleTimeout < 1 and 1) or nil

		assert(type(callback) == "function", "Callback must become a function")
		assert(not endCallback or type(endCallback) == "function", "End Callback must become a function")

		local eventCons = {}
		local eventsCount = #events
		local results = {}
		local readyToPass = false
		local readyToReturn = false

		local processData = {
			active = true,
		}

		function processData:stopEvents()
			for i, eventCon in eventCons do
				if eventCon.Disconnect then eventCon:Disconnect() end
				eventCons[i] = nil
			end
		end

		function processData:stop() self.active = false end

		local waitCallbackData
		local function doCallback(...)
			task.defer(function(...)
				if not readyToPass then
					readyToPass = true

					if waitCallbackData then waitCallbackData:delete() end

					-- Disconnect events after completion or idle timeout
					processData:stopEvents()

					if callback and processData.active then taskSpawn(callback, ...) end
				end
			end, ...)
		end

		if endCallback then
			waitCallbackData = waitManager:add(idleTimeout, function()
				processData:stop()
				processData:stopEvents()
				if endCallback then taskSpawn(endCallback) end
			end)
		end

		if eventsCount > 0 then
			for i, event in events do
				local eventType = tostring(event)

				if eventType == "Signal" or eventType == "SignalWrap" or eventType == "SignalConnect" then -- Essential signals
					table.insert(eventCons, event:connectOnce(doCallback))
				elseif string.match(eventType, "Signal (.+)") then -- Roblox script signals
					local eventCon
					eventCon = event:connect(function(...)
						eventCon:Disconnect()
						task.defer(doCallback)
					end)

					table.insert(eventCons, eventCon)
				end
			end
		else
			error("There were no events listed to register a wait listener", 0)
		end

		return processData
	end
end

function Signal:wrap(): { [any]: any }
	if self.active then
		local selfSignal = self
		local wrap = setmetatable({}, {
			__index = function(this, ind)
				if rawequal(ind, "__wrapped") then return true end
				local chosen = (rawequal(ind, "wrap") and -1) or selfSignal[ind]
				local choseType = type(chosen)

				if choseType == "function" then
					return function(self, ...) return chosen(selfSignal, ...) end
				else
					return chosen
				end
			end,

			__newindex = function(this, ind, val) selfSignal[ind] = val end,

			__tostring = function() return "SignalWrap" end,
		})

		return wrap
	end
end

function Signal:wrapConnect(): { [any]: any }
	if self.active then
		local selfSignal = self
		local wrap
		wrap = setmetatable({}, {
			__index = function(this, ind)
				if rawequal(ind, "__wrapped") then return true end

				local chosen = (rawequal(ind, "connect") and selfSignal.connect)
					or (rawequal(ind, "Connect") and selfSignal.connect)
					or (rawequal(ind, "connectOnce") and selfSignal.connectOnce)
					or (rawequal(ind, "ConnectOnce") and selfSignal.connectOnce)
					or (rawequal(ind, "selfConnect") and selfSignal.selfConnect)
					or (rawequal(ind, "SelfConnect") and selfSignal.selfConnect)

				if not chosen and rawequal(ind, "id") then return selfSignal.id end
				if chosen then
					return function(self, ...)
						--assert(rawequal(self, wrap))
						return chosen(selfSignal, ...)
					end
				end
			end,

			__newindex = function(this, ind, val)
				-- Do nothing
			end,

			__tostring = function() return "SignalConnect" end,
		})

		return wrap
	end
end

function Signal:createHandler(): { [any]: any }
	if rawequal(Signal, self) then
		local handler = {}
		handler._signals = {}

		function handler.new(catg)
			catg = catg or "_"

			local catgList = handler._signals[catg]
			if not catgList then
				catgList = {}
				handler._signals[catg] = catgList
			end

			local sigObject = Signal.new()
			sigObject.handleCateg = tostring(catg)

			table.insert(catgList, sigObject)
			return sigObject
		end

		function handler:findSignal(catg: string?, name: string?, collectMultiple: boolean?)
			catg = catg or "_"

			local catgList = handler._signals[catg]
			if not catgList then
				catgList = {}
				handler._signals[catg] = catgList
			end

			local results = {}
			for i, signal in catgList do
				if not name or (name and signal.name and signal.name == name) then
					if collectMultiple then
						table.insert(results, signal)
					else
						return signal
					end
				end
			end

			return results
		end

		function handler:killSignals(specificCatg)
			for catgName, catgList in handler._signals do
				if not specificCatg or specificCatg == catgName then
					for d, catgSignal in catgList do
						catgList[d] = nil
						task.defer(function() catgSignal:disconnect() end)
					end
				end
			end
		end

		return handler
	end
end

return Signal
