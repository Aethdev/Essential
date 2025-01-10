--[[
	ESSENTIAL QUEUE V1.4
	  > Creator: trzistan
	  
	- Main utility for queue handling
]]

local Queue = {}
Queue.__index = Queue
Queue.__tostring = function() return "Queue" end

Queue.customEvent = nil
Queue.customWait = nil

local serverRunning = true
if game:GetService("RunService"):IsServer() then
	game:BindToClose(function()
		serverRunning = false
	end)
end

local waitManager = {}
waitManager.active = true
waitManager.waitQueue = {}
do
	local runService = game:GetService("RunService")

	function waitManager:start()
		if not self.heartbeatEv then
			self.heartbeatEv = runService.Heartbeat:Connect(function()
				if #waitManager.waitQueue > 0 then
					for i, waitQue in ipairs(waitManager.waitQueue) do
						if tick()-waitQue.endTick >= 0 and not waitQue.doneWatching then
							waitQue.doneWatching = true
							table.remove(waitManager.waitQueue, i)
							task.spawn(waitQue.callback)
							break
						end
					end
				else
					if self.heartbeatEv.Connected then
						self.heartbeatEv:Disconnect()
					end
					self.heartbeatEv = nil
				end
			end)
		end
	end

	function waitManager:add(waitDelay: number, callback)
		local queData = {
			doneWatching = false;
			callback = callback;
			endTick = tick()+(waitDelay or math.huge);
		}

		function queData:delete()
			if not queData.doneWatching then
				queData.doneWatching = true
				local findQue = table.find(waitManager.waitQueue, queData)
				if findQue then
					table.remove(waitManager.waitQueue, findQue)
				end
			end
		end
		queData.cancel = queData.delete

		table.insert(self.waitQueue, queData)
		waitManager:start()

		return queData
	end
	
	if runService:IsServer() then
		game:BindToClose(function()
			if #waitManager.waitQueue > 0 then
				for i, waitQue in pairs(waitManager.waitQueue) do
					if not waitQue.doneWatching then
						waitQue.doneWatching = true
						task.spawn(waitQue.callback)
					end
				end
			end
		end)
	end
end

local type = type
local setmetatable = setmetatable
local pairs = pairs
local rawequal = rawequal
local table = table
local coroutine = coroutine
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
local warn = warn
local Instance = Instance
local isStudio = function()
	return game:GetService("RunService"):IsStudio()
end
local realWait = wait
local wait = function(...)
	if ({...})[1] and ({...})[1] < 0 then return 0,0 end
	if not serverRunning then
		return 0,0
	end
	return (Queue.customWait or realWait)(...)
end

local httpServ = game:GetService("HttpService")
local generateGUID = httpServ.GenerateGUID

local base64Encode = function(data)
		local sub = string.sub
		local byte = string.byte
		local gsub = string.gsub

		return (gsub(gsub(data, '.', function(x)
			local r, b = "", byte(x)
			for i = 8, 1, -1 do
				r = r..(b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0')
			end
			return r;
		end) .. '0000', '%d%d%d?%d?%d?%d?', function(x)
			if (#(x) < 6) then
				return ''
			end
			local c = 0
			for i = 1, 6 do
				c = c + (sub(x, i, i) == '1' and 2 ^ (6 - i) or 0)
			end
			return sub('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', c + 1, c + 1)
		end)..({
			'',
			'==',
			'='
		})[#(data) % 3 + 1])
	end;

local function selfEvent(eventSignal, func)
	local eventCon; eventCon = eventSignal:connect(function(...)
		local suc,ers = coroutine.resume(coroutine.create(func), eventCon, ...)
	end)

	return eventCon
end

local function rateLimitCheck(rateLimit, rateKey) -- Rate limit check
	-- Ratelimit: {[any]: any}
	-- Ratekey: string or numberf

	local rateData = (type(rateLimit)=="table" and rateLimit) or nil

	if not rateData then
		error("Rate data doesn't exist (unable to check)")
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

		-- Ensure minimum requirement is followed
		maxRate = (maxRate>1 and maxRate) or 1
		-- Max rate must have at least one rate else anything below 1 returns false for all rate checks
		
		local resetOsTime;
		
		local cacheLib = rateData.Caches

		if not cacheLib then
			cacheLib = {}
			rateData.Caches = cacheLib
		end

		-- Check cache
		local nowOs = tick()
		local rateCache = cacheLib[rateKey]
		local throttleCache
		if not rateCache then
			rateCache = {
				Rate = 0;
				Throttle = 0;
				LastUpdated = nowOs;
				LastThrottled = nil;
			}
			
			resetOsTime = nowOs+resetInterval

			cacheLib[rateKey] = rateCache
		end

		if nowOs-rateCache.LastUpdated >= resetInterval then
			rateCache.LastUpdated = nowOs
			rateCache.Rate = 0
			resetOsTime = nowOs+resetInterval
		else
			resetOsTime = nowOs+(resetInterval-(nowOs-rateCache.LastUpdated))
		end

		local ratePass = rateCache.Rate+1<=maxRate

		local didThrottle = canThrottle and rateCache.Throttle+1<=throttleMax
		local throttleResetOs = rateCache.ThrottleReset
		local canResetThrottle = throttleResetOs and nowOs-throttleResetOs <= 0

		rateCache.Rate += 1

		-- Check can throttle and whether throttle could be reset
		if canThrottle and canResetThrottle then
			rateCache.Throttle = 0
		end

		-- If rate failed and can also throttle, count tick
		if canThrottle and (not ratePass and didThrottle) then
			rateCache.Throttle += 1
			rateCache.LastThrottled = nowOs

			-- Check whether cache time expired and replace it with a new one or set a new one			
			if not throttleResetOs or canResetThrottle then				
				rateCache.ThrottleReset = nowOs
			end
		elseif canThrottle and ratePass then
			rateCache.Throttle = 0
		end

		if rateExceeded and not ratePass then
			rateExceeded:Fire(rateKey, rateCache.Rate, maxRate)
		end

		if ratePassed and ratePass then
			ratePassed:Fire(rateKey, rateCache.Rate, maxRate)
		end

		return ratePass, didThrottle, canThrottle, rateCache.Rate, maxRate, throttleResetOs, resetOsTime
	end
end

function Queue.new(processFunc: FunctionalTest?): {[any]: any}
	local self = setmetatable({}, Queue)

	self.active = true
	self.id = generateGUID(httpServ)
	self._queue = {}
	self._crossQueues = {}
	self.processFunc = processFunc or function()
		return true
	end

	self.maxQueue = 1000
	self.delayPerEntry = 0
	self.lastProcessInd = 0

	self.processQue = (Queue.customEvent and Queue.customEvent.new()) or Instance.new("BindableEvent")
	self.processActive = (Queue.customEvent and Queue.customEvent.new()) or Instance.new("BindableEvent")
	self.processIdle = (Queue.customEvent and Queue.customEvent.new()) or Instance.new("BindableEvent")
	self.destroyed = (Queue.customEvent and Queue.customEvent.new()) or Instance.new("BindableEvent")

	self.processError = (Queue.customEvent and Queue.customEvent.new()) or Instance.new("BindableEvent")

	self.clearFinishedQuesAfterProcess = true
	self.dontClearFailedQues = false
	self.ignoreProcessedQues = true

	self.repeatProcess = true

	self.initialProcessDelay = 0.2
	self.afterProcessDelay = 0

	self.processCooldown = 0
	self.lastProcessOs = nil
	
	self.priorityEnabled = false
	
	if not Queue.warnNoCustomEvent and not Queue.customEvent then
		Queue.warnNoCustomEvent = true
		warn("Queue doesn't have a custom event. It is recommended to have one for processing ques with metadata.\n-\n"..
			"CUSTOM EVENT -> Must be compatible to wait for rbx events and other events"
		)
	end

	return self
end

function Queue:warn(...)
	if self.active then
		warn("Queue "..tostring(self.id), ...)
	end
end

function Queue:addWithPriority(priorityLevel, ...)
	local queData = self:add(...)
	if queData then
		queData.priority = priorityLevel
	end
	return queData
end

function Queue:add(...)
	if self.active then
		-- Check rate limit if listed
		if self.rateLimit then
			local didPass,curRate,maxRate,_,_,_,resetRateOs = rateLimitCheck(self.rateLimit, "QueueEntry")

			if not didPass then
				if self.debug then
					warn("QUEUE "..tostring(self.id).." ENTRY EXCEEDED (> "..tostring(maxRate)..")")
				end

				return false, resetRateOs
			end
		end

		local queueDebug = self.debug
		local queData = {
			id = generateGUID(httpServ);
			arguments = {...};
			returned = {};
			processing = (Queue.customEvent and Queue.customEvent.new()) or Instance.new("BindableEvent");
			processed = (Queue.customEvent and Queue.customEvent.new()) or Instance.new("BindableEvent");
			removed = (Queue.customEvent and Queue.customEvent.new()) or Instance.new("BindableEvent");
			ignored = (Queue.customEvent and Queue.customEvent.new()) or Instance.new("BindableEvent");
			active = true;
			_processState = false;
			created = tick();
			lastError = '';
			priority = 0;
		}

		if self.maxQueue <= 0 or #self._queue+1 <= self.maxQueue then
			table.insert(self._queue, queData)
			
			if self.priorityEnabled then
				table.sort(self._queue, function(queA, queB)
					return queA.priority > queB.priority
				end)
			end
			
			if not self._processing then
				coroutine.wrap(function()
					if serverRunning then
						wait(.1)
					end

					if self._queue[#self._queue] == queData and not self._processing then
						if queueDebug then
							warn("Que "..queData.id.." - Processing queue..")
						end

						local lastProcessInd = self.lastProcessInd or 0
						local nonClearQueue = not self.clearFinishedQuesAfterProcess
						local canContinue = lastProcessInd<#self._queue

						if canContinue then
							self:process(lastProcessInd+1)
						elseif (not canContinue and self.repeatProcess) then
							self:process()
						end
					end
				end)()
			end

			if self.debug then
				warn("Queue "..tostring(self.id).." added new entry "..tostring(queData.id), queData)
			end

			return queData
		end
	end
end

function Queue:remove(queId)
	if self.active then
		for i,que in pairs(self._queue) do
			if que.id == queId then
				table.remove(self._queue, i)
				que.active = false
				que.removed:Fire()
				break
			end
		end
	end
end

function Queue:clear()
	if self.active then
		for i,que in pairs(self._queue) do
			self._queue[i] = nil
			que.active = false
			que.removed:Fire()
		end
	end
end


function Queue:process(startInd: number, override: boolean)
	if self.active and (override or not self._processing) then
		self._processing = true

		local processId = generateGUID(httpServ)

		self.processId = processId

		if self.initialProcessDelay > 0 and not override and serverRunning then
			wait(self.initialProcessDelay)
		end

		if (self.processCooldown > 0 and self.lastProcessOs) and (tick()-self.lastProcessOs < self.processCooldown) and not override then
			local processCooldown = self.processCooldown
			local lastProcessOs = self.lastProcessOs

			if self.debug then
				warn("Queue "..tostring(self.id).." waiting for process cooldown..")
			end

			repeat
				if not serverRunning then
					return
				end

				wait()
			until
			not self.active or self.processId ~= processId or (tick()-lastProcessOs > processCooldown)

			if self.debug and (tick()-lastProcessOs >= processCooldown) then
				warn("Queue "..tostring(self.id).." finished waiting process cooldown..")
			end
		end

		if not self.active or self.processId ~= processId then
			return
		end

		if self.debug then
			warn("Queue "..tostring(self.id).." processing queue..")
		end

		if self.focusingQueTab then
			self.focusingQueTab.ignored:fire()
			self.focusingQueTab._processing = false
		end

		self.focusingQueTab = nil
		self.focusingQueInd = nil

		local clearFinishedQuesAfterProcess = self.clearFinishedQuesAfterProcess
		local ignoreProcessedQues = self.ignoreProcessedQues

		self.processActive:Fire()

		local lastProcessInd = 0
		local dontClearQues = {}
		local processedQues = {}
		local startInd = startInd or 0
		
		--table.sort(self._queue, function(queA, queB)
		--	return queA.priority > queB.priority
		--end)

		for i,que in ipairs(self._queue) do
			if not self.active then
				break
			end

			if self.processId ~= processId then
				return
			end

			if i < startInd then
				continue
			end

			local que = self._queue[i]
			local manualProcess = self.manualProcess
			local manualFunc = self.manualFunc
			local dontClearFailedQues = self.dontClearFailedQues

			local canClearQue = true

			if que then
				if que.active and not que._processing and (not ignoreProcessedQues or not que._processState) then
					if self.debug then
						warn("Queue "..tostring(self.id).." processing entry "..tostring(i)..": "..tostring(que.id), que)
					end

					if not manualProcess then
						que.processing:Fire()
						que._processing = true
					end

					self.focusingQueTab = que
					self.focusingQueInd = i

					lastProcessInd = i
					self.lastProcessInd = i

					local finishedSignal = false

					local processRets = {}
					local processSignal = (self.customEvent and self.customEvent.new()) or Instance.new("BindableEvent")
					local rets = {}

					local quickProcess = nil
					coroutine.wrap(function()
						selfEvent(self.destroyed, function(event)
							event:Disconnect()

							if not finishedSignal then
								processSignal:fire(false)
								quickProcess = false
							end
						end)

						selfEvent(que.ignored, function(event)
							event:Disconnect()

							if not finishedSignal then
								processSignal:fire(false)
								quickProcess = false
							end
						end)

						selfEvent(que.removed, function(event)
							event:Disconnect()

							if not finishedSignal then
								processSignal:fire(false)
								quickProcess = false
							end
						end)

						local errTrace = nil
						local errMsg = nil
						rets = {xpcall(function(...)
							if manualProcess then
								if manualFunc then
									processRets = {manualFunc(...)}
									processSignal:Fire(true)
									quickProcess = true
								else
									error("Missing que function. Unable to run manual process.", 0)
								end
							elseif not manualProcess then
								processRets = {self.processFunc(...)}
								processSignal:Fire(true)
								quickProcess = true
							end
						end, function(errMessage)
							errTrace = debug.traceback(nil, 2)
							errMsg = errMessage
							processSignal:Fire(true)
						end, i, que, unpack(que.arguments))}

						if not rets[1] and errTrace then
							rets[3] = errTrace
						end

						if not rets[1] and errMsg then
							rets[2] = errMsg
						end

						processSignal:Fire(false)
					end)()

					local didProcess

					if quickProcess == nil then
						if processSignal.ClassName == "BindableEvent" then -- If custom event is a bindable event
							didProcess = processSignal.Event:wait()
						else
							didProcess = processSignal:wait()
						end
					else
						didProcess = quickProcess
					end

					finishedSignal = true
					que._processing = false

					if didProcess == true then
						local success,error,errTrace = rets[1] or false, rets[2], rets[3]

						if not success then
							if self.warnError or self.debug then
								warn("Queue "..tostring(que.id).." processor encountered an error while processing "..tostring(que.id)..": "..tostring(error or "[Unknown error - "..generateGUID(httpServ).."]"))
							end

							que.lastError = tostring(error)
							self.processError:fire(i, que, error)

							if not manualProcess then
								que.processed:Fire(false, unpack(que.returned))
							end

							if dontClearFailedQues then
								canClearQue = false
								dontClearQues[que] = true
							end
						else
							table.clear(que.returned)
							for d,ret in pairs(processRets) do
								table.insert(que.returned, ret)
							end

							if not manualProcess then
								que.processed:Fire(true, unpack(que.returned))
							end
						end

						processedQues[que] = true
						que._processState = true

						if self.debug then
							warn("Queue "..tostring(self.id).." successfully processed entry "..tostring(que.id))
						end

						self.processQue:Fire(i, que.id, que, rets[1])
					end

					if self.processId ~= processId then
						return
					end

					self.focusingQueTab = nil
					self.focusingQueInd = nil

					if self.delayPerEntry and self.delayPerEntry > 0 then
						if serverRunning then
							wait(self.delayPerEntry)
						end
					end
				end
			end
		end

		if self.processId ~= processId then
			return
		end

		if clearFinishedQuesAfterProcess then
			local deleteCount = 0

			-- Clear processed ques
			for i,que in pairs(self._queue) do
				if que._processState and processedQues[que] and not dontClearQues[que] then
					self._queue[i] = nil
					deleteCount += 1
				end
			end

			if self.debug and deleteCount > 0 then
				warn("Queue "..tostring(self.id).." cleared "..deleteCount.." processed ques after process")
			end
		end

		if self.active then
			self.processIdle:Fire()
		end

		self.focusingQueTab = nil
		self.focusingQueInd = nil

		self.lastProcessOs = tick()
		self._processing = false

		if self.debug then
			warn("Queue "..tostring(self.id).." finished processing")
		end

		if #self._queue > 0 and self.active then
			local nonClearQueue = not clearFinishedQuesAfterProcess
			local canContinue = lastProcessInd<#self._queue

			if self.debug then
				warn("Queue "..tostring(self.id).." detected non-empty queue. Processing again..")
			end

			if self.afterProcessDelay > 0 and serverRunning then
				if self.debug then
					warn("Queue "..tostring(self.id).." waiting for afterProcessDelay..")
				end

				wait(self.afterProcessDelay)
			end

			if self.processId ~= processId then
				return
			end

			if canContinue then
				return self:process(lastProcessInd+1)
			elseif (not canContinue and self.repeatProcess) then
				return self:process()
			end
		end
	end
end

function Queue:restart(doThread: boolean?)
	if self.active then
		self.processId = nil
		if doThread then
			task.defer(self.process, self)
		else
			self:process()
		end
	end
end

function Queue:destroy()
	if self.active then
		for i,que in pairs(self._queue) do
			table.remove(self._queue, i)
		end
		self.destroyed:Fire()
		self.active = false
	end
end

function Queue:wrap(): {[any]: any}
	if self.active then
		local selfQueue = self
		local wrap = setmetatable({},{
			__index = function(this, ind)
				local chosen = (rawequal(ind, 'wrap') and -1) or selfQueue[ind]
				local choseType = type(chosen)

				if choseType == "function" then
					return function(self, ...)
						return chosen(selfQueue, ...)
					end
				else
					return chosen
				end
			end;

			__newindex = function(this, ind, val)
				selfQueue[ind] = val
			end;

			__tostring = function() return "QueueWrap" end;
		})

		return wrap
	end
end

--// Cross functions
local RunService = game:GetService("RunService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local DataStoreService = game:GetService("DataStoreService")
local GlobalCrossQueueReadRetryAttempts = 5
local GlobalCrossQueueReadRetryCooldown = 10
local GlobalCrossQueueSessionLockDataStoreRetryAttempts = 4
local GlobalCrossQueueSessionLockDeadLockSeconds = 1200 -- 20 minutes
local GlobalCrossQueueRateLimit = {
	AddAndRemove = {
		Rates = 1_000; 	-- Max requests per traffic
		Reset = 60; 		-- Interval seconds since the cache last updated to reset
	};
	Read = {
		Rates = 5_000; 	-- Max requests per traffic
		Reset = 60; 		-- Interval seconds since the cache last updated to reset
	};
	
	SessionLock_DatastoreRL = {
		Rates = 50; 	-- Max requests per traffic
		Reset = 60; 		-- Interval seconds since the cache last updated to reset
	}
}
local DefaultGlobalQueueSettings = {
	MaxItemsToReadFromMemory = 1;
	WaitTimeout = 10;
	FinishTimeout = 15;
	SessionLockItem = false;
}

local DatastoreGetRequestDelay = function(reqType)
	local playersCount = #game:GetService("Players"):GetPlayers()
	local reqPerMin = 60 + playersCount * 10
	local reqBudget = 0

	if reqType == "write" or reqType == "update" then
		reqType = Enum.DataStoreRequestType.UpdateAsync
	elseif reqType == "overwrite" or reqType == "set" then
		reqType = Enum.DataStoreRequestType.SetIncrementAsync
	elseif reqType == "read" or reqType == "get" then
		reqType = Enum.DataStoreRequestType.GetAsync
	elseif reqType == "getSorted" or reqType == "getVersion" then
		reqType = Enum.DataStoreRequestType.GetSortedAsync
		reqPerMin = 5 + playersCount * 2
	elseif reqType == "remove" then
		reqType = Enum.DataStoreRequestType.GetSortedAsync
		reqPerMin = 5 + playersCount * 2
	end

	local reqDelay = 60 / reqPerMin

	repeat
		reqBudget = DataStoreService:GetRequestBudgetForRequestType(reqType);
	until
		reqBudget > 0 and task.wait(1)

	return reqDelay + 0.5
end;

function Queue:linkCrossCommunication(crossQueueName: string, settings: {[string]: any}?)
	assert(RunService:IsServer(), "Cross communication is only allowed in the server side")
	assert(RunService:IsRunning(), "Cross communication is only allowed while the server is running")
	assert(type(crossQueueName) == "string" and #crossQueueName > 0, "Cross queue name cannot be empty")
	
	if self._crossQueues[crossQueueName] then return self._crossQueues[crossQueueName] end
	if self.maxQueue > 1_000_000 then
		self:warn("A cross communication queue can only que 1 million items. Setting max queued items to 1M.")
		self.maxQueue = 1_000_000
	end
	
	local queue: Queue = self
	local crossQueue = {}
	crossQueue._instance = MemoryStoreService:GetQueue(crossQueueName)
	crossQueue._pendingQues = {}
	crossQueue._cacheIgnoredQues = {}
	
	self._crossQueues[crossQueueName] = crossQueue
	
	crossQueue.settings  = {
		Name = crossQueueName;
		MaxItemsToReadFromMemory = DefaultGlobalQueueSettings.MaxItemsToReadFromMemory;
		WaitTimeout = DefaultGlobalQueueSettings.WaitTimeout;
		FinishTimeout = DefaultGlobalQueueSettings.FinishTimeout;
		
		SessionLockItem = DefaultGlobalQueueSettings.SessionLockItem;
	}
	
	if settings then
		for set, val in pairs(settings) do
			crossQueue.settings[set] = val
		end
	end
	
	crossQueue._sessionLockDatastore = crossQueue.settings.SessionLockDatastore or DataStoreService:GetDataStore("EssQueues-SessionLock", base64Encode(crossQueueName))
	
	function crossQueue:add(value: any, expiration, priority)
		assert(not table.find({"userdata","nil"}, type(value)), "Value must be a string/boolean/table")
		assert(table.find({"number","nil"}, type(expiration)), "Wait time must be a number or nil")
		
		expiration = expiration or 60*10 --// 10 minutes
		
		local addRateLimitData = { rateLimitCheck(GlobalCrossQueueRateLimit.AddAndRemove, `{queue.id}-{crossQueueName}`) }
		local addRateLimitPass, addRateResetOsTime = addRateLimitData[1], addRateLimitData[7]

		if not addRateLimitPass then
			wait(addRateResetOsTime-tick())
			return self:add(value, expiration, priority)
		end
		
		local success, error =  pcall(function()
			return self._instance:AddAsync({
				JobId = game.JobId,
				Started = os.time(),
				Value = value
			}, expiration, priority)
		end)
		if not success then
			warn(`CrossQueue {queue.id}-{crossQueueName} error:`, error)
			wait(10)
			return self:add(value, expiration, priority)
		else
			return true
		end
	end
	
	function crossQueue:_removeQueId(itemId: string, currentAttempts: number?)
		if not RunService:IsRunning() then return crossQueue end
		
		local removeRateLimitData = { rateLimitCheck(GlobalCrossQueueRateLimit.AddAndRemove, `{queue.id}-{crossQueueName}`) }
		local removeRateLimitPass, removeResetOsTime = removeRateLimitData[1], removeRateLimitData[7]
		
		if not removeRateLimitPass then
			wait((removeResetOsTime-tick())+math.random(1,2))
			return self:_removeQueId(itemId)
		end
		
		if not pcall(function()
			self._instance:RemoveAsync(itemId)
		end) then
			if currentAttempts and currentAttempts+1 < 5 then
				if not table.find(self._cacheIgnoredQues, itemId) then
					table.insert(self._cacheIgnoredQues, itemId)
				end
				
				return crossQueue
			end
			
			wait(10+math.random(2,5))
			return self:_removeQueId(itemId, currentAttempts or 1)
		end
	
		return crossQueue
	end
	
	function crossQueue:_startQueueCheck()
		if self._startedLoopCheck then return end
		self._startedLoopCheck = true
		
		local function checkValidMemoryQueData(memoryQueData)
			local dataFormat = {
				JobId = "string",
				Started = "number",
				--Value = "any"
			}

			for ind, val in pairs(dataFormat) do
				if type(memoryQueData[ind]) ~= val then
					return false
				end
			end

			return true
		end
		
		local queueDebug = queue.debug or self.debug
		
		local function doCheck()
			if not crossQueue._startedLoopCheck then return end
			if not RunService:IsRunning() then return end
			
			local readRateLimitData = { rateLimitCheck(GlobalCrossQueueRateLimit.Read, `{queue.id}-{crossQueueName}`) }
			local readRatePass, readRateResetOsTime = readRateLimitData[1], readRateLimitData[7]
			
			if not readRatePass then
				wait(readRateResetOsTime-tick())
				--if not crossQueue._startedLoopCheck then return end
				return doCheck()
			end
			
			crossQueue._processing = true
			
			local doSessionLockItem = crossQueue.settings.SessionLockItem
			
			local successToRead, crossQueueItems, itemId = pcall(function()
				return crossQueue._instance:ReadAsync(
					if crossQueue.settings.SessionLockItem then 1 else 1,--math.floor(math.clamp(crossQueue.settings.MaxItemsToReadFromMemory or 1, 1, 6)),
					false, crossQueue.settings.WaitTimeout
				)
			end)
			
			if not RunService:IsRunning() then return end
			
			if successToRead and type(crossQueueItems) == "table" and #crossQueueItems > 0 then
				if queueDebug then
					queue:warn(`Received {#crossQueueItems} queue items`)
				end
				
				if crossQueue.settings.SessionLockItem then
					local function checkValidSessionDataFormat(sessionData)
						local dataFormat = {
							JobId = "string",
							Started = "number"
						}
						
						for ind, val in pairs(dataFormat) do
							if type(sessionData[ind]) ~= val then
								return false
							end
						end
						
						return true
					end
					--[[
						SessionLockData = {
							JobId = string,
							Started = number
						}
					]]
					
					local _sessionLocked, _removeState = false, false;
					local function updateCallback(sessionLockData, dataKeyInfo)
						if _removeState then
							if not checkValidSessionDataFormat(sessionLockData) or (os.time()-sessionLockData.Started < GlobalCrossQueueSessionLockDeadLockSeconds
								or game.JobId == sessionLockData.JobId)
							then
								_sessionLocked = false
								return nil
							else
								return sessionLockData, dataKeyInfo
							end
						else
							if checkValidSessionDataFormat(sessionLockData) and game.JobId ~= sessionLockData.JobId then
								_sessionLocked = true
								return {
									JobId = game.JobId,
									Started = os.time()
								}
							elseif not checkValidSessionDataFormat(sessionLockData) then
								return nil
							else
								return sessionLockData, dataKeyInfo
							end
						end
					end
					
					local function doDSAttempt()
						local sessionLockRateLimitData = { rateLimitCheck(GlobalCrossQueueRateLimit.SessionLock_DatastoreRL, `{queue.id}-{crossQueueName}`) }
						local sessionLockRatePass, sessionLockRateResetOsTime = sessionLockRateLimitData[1], sessionLockRateLimitData[7]

						if not sessionLockRatePass then
							wait(sessionLockRateResetOsTime-tick())
							return doDSAttempt()
						end

						if serverRunning then
							wait(DatastoreGetRequestDelay("write"))
						end

						local success, error = pcall(crossQueue._sessionLockDatastore.UpdateAsync,
							crossQueue._sessionLockDatastore, queue, updateCallback)

						return success, error
					end
					
					--TODO: FIX SESSION LOCK
					local _didDSAttempt = false
					for dataAttempt = 1, GlobalCrossQueueSessionLockDataStoreRetryAttempts do
						if not checkValidMemoryQueData(crossQueueItems[1]) then
							crossQueue:_removeQueId(itemId)
							if not table.find(crossQueue._cacheIgnoredQues, itemId) then
								table.insert(crossQueue._cacheIgnoredQues, itemId)
							end
							
							continue
						end
						
						if queueDebug then
							self:warn(`DS Attempt {dataAttempt} attempting to session lock memory que {itemId}`)
						end
						
						local success, error = doDSAttempt(dataAttempt)
						
						if not success and queueDebug then
							self:warn(`DS Attempt {dataAttempt} failed to session lock memory que {itemId}`)
						end
						
						if success and _sessionLocked then
							if queueDebug then
								self:warn("Successfully session locked memory que "..tostring(itemId)..". Now adding memory que to the queue.")
							end
							
							local failToAddToQueue = true
							
							repeat
								local queData, resetRateTimeOs = queue:add(crossQueueItems[1])
								if queData==nil then
									if not queue.active then return end -- Stop queue loop if queue is deactivated
									if queueDebug then
										self:warn(`Queue is too full to add memory que {itemId}. Waiting for idle queue to add..`)
									end
									
									queue.processIdle:wait()
								elseif rawequal(queData, false) and resetRateTimeOs then
									if queueDebug then
										self:warn(`Memory que {itemId} was rate limited by the queue. Waiting for rate limit to cool down..`)
									end
									
									wait(resetRateTimeOs-tick())
									
									if queueDebug then
										self:warn("Finished rate limit to cool down. Now retrying..")
									end
									
									if not serverRunning then
										break
									end
								else
									failToAddToQueue = false
									_didDSAttempt = true
							
									queData.addedByCrossCommm = true
									queData.processed:Connect(function(wasSuccess)
										if wasSuccess then
											if queueDebug then
												self:warn(`Memory que {itemId} finished processing. Now removing session lock and from queue..`)
											end
											
											_removeState = true
											task.spawn(crossQueue._removeQueId, crossQueue, itemId)
											
											for dataAttempt = 1, GlobalCrossQueueSessionLockDataStoreRetryAttempts do
												local success, error = doDSAttempt()
												if not success then
													wait(dataAttempt*GlobalCrossQueueReadRetryCooldown)
												else
													_sessionLocked = false
													break
												end
											end
											
											if _sessionLocked then
												self:warn(`Failed to remove memory que {itemId}'s session lock.`)
											end
										end
									end)
									
									if queueDebug then
										self:warn(`Memory que {itemId} successfully queued.`)
									end
								end
							until
								not failToAddToQueue
							
							break
						elseif success and not _sessionLocked then
							if queueDebug then
								self:warn(`DS Attempt {dataAttempt} memory que {itemId} is currently session locked. Ignoring memory que..`)
							end
							
							wait(math.random(1,2))
						else
							if queueDebug then
								self:warn(`Failed to session lock memory que {itemId}. Waiting {dataAttempt*GlobalCrossQueueReadRetryCooldown} seconds.`)
							end
							
							wait(dataAttempt*GlobalCrossQueueReadRetryCooldown)
						end
					end
					
					if not _didDSAttempt then
						local finishTimeout = math.min(self.settings.FinishTimeout or 15, 15)
						
						if queueDebug then
							self:warn("Failed to session lock memory que "..tostring(itemId)..`. Halting cross queue check for {finishTimeout} seconds.`)
						end
						
						if queue.active then
							waitManager:add(finishTimeout, doCheck)
						end
						
						return
					end
				else
					for i, item in ipairs(crossQueueItems) do
						if not checkValidMemoryQueData(item) then
							continue
						end
						
						task.defer(queue.add, queue, item.Value)
					end
					
					for i, item in ipairs(crossQueueItems) do
						crossQueue:_removeQueId(itemId)
					end
				end
			elseif not successToRead then
				if queueDebug then
					queue:warn(`MemoryService encountered an error in ReadAsync operation: {tostring(crossQueueItems)}`)
				end
				
				crossQueue._processing = false
				
				if queue.active then
					waitManager:add(math.random(8,15), doCheck)
				end
				
				return
			end
			
			crossQueue._processing = false
			
			if queue.active then
				waitManager:add(math.random(3, 6), doCheck)
			end
		end
		
		task.spawn(doCheck)
	end
	
	function crossQueue:_stopQueueCheck()
		if not self._startedLoopCheck then return end
		self._startedLoopCheck = false
	end
	
	crossQueue:_startQueueCheck()
	
	return crossQueue
end

return Queue