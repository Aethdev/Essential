local realMethods = {}
local checkMethod
checkMethod = function(ins, meth, ...)
	local suc, class = pcall(function() return ins.ClassName end)
	local ret = ins[meth]

	if suc and class and type(ret) == "function" then
		local exClass = realMethods[class]

		if not exClass then
			local new = {}
			realMethods[class] = new
			exClass = new
		end

		local existingMeth = realMethods[class][meth]

		if existingMeth and type(existingMeth) == "function" then
			return existingMeth(ins, ...)
		elseif not existingMeth then
			realMethods[class][meth] = ins[meth]
			return ins[meth](ins, ...)
		end
	end

	return ins[meth](ins, ...)
end

return function(specificTab, errHandler, Promise)
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
	local delay = delay
	local assert = assert
	local corotCreate, corotResume, corotYield = coroutine.create, coroutine.resume, coroutine.yield
	local wait = task.wait

	local queues = {}
	local existingTasks = {}
	local onGoingThreads = {}
	local wrappedItems = {}
	local reverseWrapItems = {}
	local specialWrappedItems = {}
	local onGoingLoops = {}
	local rbxEvents = {}
	local cacheServices = {}
	local userIdCache = {}
	local passOwnershipCache = {}
	local assetOwnershipCache = {}
	local subscriptionOwnershipCache = {}
	local assetInsertionCache = {}
	local assetInfoCache = {}
	local subscriptionInfoCache = {}
	local groupInfoCache = {}
	local debounceFuncs = {}
	local encryptCache = {}
	local decryptCache = {}
	local serviceSpecific = specificTab or {}
	local specificLocked = not serviceSpecific.__CanChange
	local service = {}

	local runService = game:GetService "RunService"

	local osTime = os.time
	local getService = game.GetService
	local getFullName = game.GetFullName
	local getAttribute = game.GetAttribute
	local isLoaded = game.IsLoaded
	local objIsA = game.IsA
	local onStudio = runService:IsStudio()
	local fireServer = Instance.new("RemoteEvent").FireServer
	local invokeServer = Instance.new("RemoteFunction").InvokeServer
	local connectEvent = game.DescendantAdded.Connect
	local disconnectEvent = connectEvent(game.DescendantAdded, function() end).Disconnect
	local destroy = game.Destroy
	local startOs = osTime()
	local function tick() return osTime() - startOs end

	local delayFunc = delay
	local toBoolean = function(stat: any): boolean
		if stat then
			return true
		else
			return false
		end
	end
	local function hasTheGivenType(value: any, givenType: string) return type(value):lower() == givenType:lower() end

	local function checkExistingTask(name)
		for i, taskTab in pairs(existingTasks) do
			if taskTab.Name == name then return taskTab end
		end
	end

	local function getRandom(pLen)
		local Len = (type(pLen) == "number" and pLen) or math.random(6, 10) --// reru
		local Res = {}
		for Idx = 1, Len do
			Res[Idx] = string.format("%02x", math.random(126))
		end
		return table.concat(Res)
	end

	local function getRandomV3(pLen, maxBytes)
		local ActualMaxBytes = 16000
		local Len = (type(pLen) == "number" and pLen) or math.random(6, 10)
		local MaxBytes = (type(maxBytes) == "number" and math.clamp(maxBytes, 1, ActualMaxBytes)) or 4000
		local Res = {}
		for Idx = 1, Len do
			Res[Idx] = utf8.char(math.random(MaxBytes))
		end
		return table.concat(Res)
	end

	local function generatePassphrases(wordCount: number, doCamelCase: boolean?)
		local realWCount = (type(wordCount) == "number" and wordCount > 0 and math.floor(wordCount))
			or math.random(8, 10)
		local listOfWords = {
			"moon",
			"cake",
			"sun",
			"frappe",
			"cow",
			"dog",
			"hotel",
			"cat",
			"rust",
			"elephant",
			"moose",
			"noob",
			"pro",
			"warrior",
			"zebra",
			"vase",
			"van",
			"car",
			"queen",
			"king",
			"hen",
			"bus",
			"nectar",
			"sunny",
			"sea",
			"ocean",
			"waves",
			"potion",
			"lamp",
			"lamb",
			"goat",
			"gallop",
			"chocolate",
			"euphoria",
			"terrain",
			"valley",
			"mountain",
			"grass",
			"water",
			"fire",
			"air",
			"ground",
			"dirt",
			"race",
			"ace",
			"obby",
			"parkour",
			"cold",
			"hot",
			"snake",
			"ram",
			"trace",
			"train",
			"aqua",
			"kangaraoo",
			"party",
			"dance",
			"drums",
			"flute",
			"guitar",
			"piano",
		}
		local Res = {}

		for i = 1, realWCount do
			local chosenWord = listOfWords[math.random(1, #listOfWords)]
			if i > 1 and doCamelCase then chosenWord = chosenWord:sub(1):upper() .. chosenWord:sub(2) end
			table.insert(Res, chosenWord)
		end

		return table.concat(Res, " ")
	end

	local function trimString(str: string) return string.match(string.match(str, "^%s*(.-)%s*$"), "^\9*(.-)\9*$") end

	local function isTableCircular(tab, includeOtherValues)
		local isPrimitive = function(value) return table.find({ "boolean", "nil" }, type(value)) and true or false end
		local checkedValues = {}
		local function tableCheck(target)
			for index, value in pairs(target) do
				if not isPrimitive(value) then
					if rawequal(value, tab) or (checkedValues[value] and includeOtherValues) then
						return true
					else
						checkedValues[value] = true
						if type(value) == "table" then
							if tableCheck(value) then return true end
						end
					end
				end
			end

			return false
		end

		return tableCheck(tab)
	end

	local function cloneTable(tab, ignoreList, errIfCircular, applyMetatable)
		ignoreList = (type(ignoreList) == "table" and ignoreList) or {}
		assert(not errIfCircular or not isTableCircular(tab), "Given table is circular")

		local tabMetatable = getmetatable(tab)
		assert(
			not applyMetatable or (hasTheGivenType(tabMetatable, "nil") or hasTheGivenType(tabMetatable, "table")),
			"Table metatable isn't valid (expected nil/table)"
		)

		local doubleClone = {}
		local doubleItem = {}
		local cacheItem = {}
		local isValueNil = function(value) return type(value) == "nil" end
		local clone
		clone = function(cloneTarget)
			if type(cloneTarget) ~= "table" then return cloneTarget end

			local newVal = {}

			-- Adds clone target to double item list. This prevents cloning the same table again inside the same table.
			doubleItem[cloneTarget] = newVal

			for i, v in pairs(cloneTarget) do
				if table.find(ignoreList, v) then continue end

				local isValueATable = type(v) == "table"
				if isValueATable then
					if (rawequal(v, cloneTarget) or rawequal(v, tab)) and doubleItem[v] then
						if rawequal(v, cloneTarget) then
							newVal[i] = newVal
						else
							newVal[i] = tab
						end
						continue
					end

					if not doubleItem[v] then
						local newSetTab = clone(v)

						newVal[i] = newSetTab
						doubleItem[v] = newSetTab
					else -- Double item
						--warn("Found double item in index", i, "->", cloneTarget)
						newVal[i] = doubleItem[v]
					end
				else
					newVal[i] = v
				end
			end

			return newVal
		end

		if not table.find(ignoreList, tab) then table.insert(ignoreList, tab) end

		local tableCloned = clone(tab)
		return tableCloned
	end

	local tasks, events, wrappers, misc =
		{
			createTask = function(name, isThread, func, errorFunc)
				local name = name or getRandom(math.random(15, 20))

				local threadFunc = function(...) return func(...) end
				local taskTab
				taskTab = {
					Name = name,
					Function = (not isThread and function(...)
						local rets = { func(...) }
						return unpack(rets)
					end) or coroutine.create(threadFunc),
					Thread = isThread,
					Active = true,
					Running = false,
					Created = osTime(),
					ErrorCount = 0,
					RanCount = 0,
					LastError = nil,

					Resume = function(...)
						if isThread and taskTab.Active and not taskTab.Running then
							taskTab.RanCount += 1
							taskTab.Running = true

							local rets = { corotResume(taskTab.Function, taskTab, ...) }
							local suc = rets[1]

							if not suc then
								taskTab.Running = false
								taskTab.ErrorCount = taskTab.ErrorCount + 1
								taskTab.LastError = rets[2]

								if errorFunc then errorFunc(rets[2], osTime()) end
							end

							return suc, unpack(rets, 2)
						elseif not isThread and taskTab.Active and not taskTab.Running then
							taskTab.RanCount += 1
							taskTab.Running = true

							local rets = { pcall(taskTab.Function, ...) }

							taskTab.Running = false

							if not rets[1] then
								taskTab.ErrorCount = taskTab.ErrorCount + 1
								taskTab.LastError = rets[2]

								if errorFunc then errorFunc(rets[2], osTime()) end
							end

							return rets[1], unpack(rets, 2)
						end
					end,

					Close = function()
						if isThread and taskTab.Active and taskTab.Running then
							local taskFunc = taskTab.Function
							if coroutine.status(taskFunc) == "normal" then
								repeat
									pcall(coroutine.close, taskFunc)
									task.wait()
								until coroutine.status(taskFunc) == "dead" or coroutine.status(taskFunc) == "suspended"
							end

							taskTab.Running = false
							taskTab.Function = corotCreate(threadFunc)
						end
					end,
				}

				table.insert(existingTasks, taskTab)

				return taskTab
			end,

			trackTask = function(name, isThread, func, ...)
				local parameters = { ... }
				local newTask
				newTask = service.createTask("_TTASK-" .. tostring(name or func) .. "-" .. getRandom(), isThread, function() return func(unpack(parameters)) end)

				if isThread then
					local threadRets = { corotResume(newTask.Function, ...) }

					if not threadRets[1] then threadRets[3] = select(1, debug.traceback(newTask.Function)) end

					return unpack(threadRets)
				else
					local errTrace = ""
					local errMessage = nil
					local funcRets = {
						xpcall(function()
							newTask.Tracking = true
							newTask.Running = true
							local rets = { func(unpack(parameters)) }
							newTask.Running = false
							return unpack(rets)
						end, function(errM)
							newTask.errorTrace = debug.traceback(nil, 2)
							errMessage = errM
							errTrace = newTask.errorTrace
							--errTrace = debug.traceback(nil, 2)
						end),
					}

					if errMessage then funcRets[2] = errMessage end

					if #errTrace > 0 then funcRets[3] = errTrace end

					return unpack(funcRets)
				end
			end,

			runTask = function(name, isThread, func, ...)
				local parameters = { ... }
				local newTask
				newTask = service.createTask("_TTASK-" .. tostring(name or func) .. "-" .. getRandom(), isThread, function()
					newTask.Running = true
					func(unpack(parameters))
					newTask.Running = false
				end)
				newTask.Function(...)
			end,

			triggerTask = function(name, isThread, func)
				return function(...)
					local rets = { service.trackTask("_TRIGGERTASK-" .. tostring(func) .. "-" .. getRandom(), isThread, func, ...) }
					if not rets[1] then warn(`TrackTask {tostring(name)} encountered an error: {tostring(rets[2])}\n{tostring(rets[3])}`) end
					return unpack(rets, 2)
				end
			end,

			threadTask = function(func, ...) return service.trackTask(nil, true, func, ...) end,

			nonThreadTask = function(func, ...) return service.trackTask(nil, false, func, ...) end,

			loopTask = function(name, delay, func, ...)
				local runService = service.RunService
				local taskIndex = tostring(tick() + math.random() ^ 3 + math.random())
				local loopInfo
				loopInfo = {
					index = taskIndex,
					name = name,
					active = false,
					created = osTime(),
				}

				local arguments = { ... }

				local function manageRegistry(typ)
					if typ == "Register" then
						loopInfo.active = true
						loopInfo.registered = osTime()
						onGoingLoops[taskIndex] = loopInfo
					elseif typ == "UnRegister" then
						if onGoingLoops[taskIndex] == loopInfo then onGoingLoops[taskIndex] = nil end
						if loopInfo.task then task.defer(task.cancel, loopInfo.task) end
					end
				end

				local function checkLoop() return onGoingLoops[taskIndex] == loopInfo and loopInfo.active end

				local function oneTimeEvent(event: RBXScriptSignal, func): RBXScriptConnection
					local eventCon
					eventCon = event:Connect(function(...)
						if eventCon.Connected then
							eventCon:Disconnect()
							task.defer(func, ...)
						end
					end)

					return eventCon
				end

				local source = debug.traceback(nil, 2)
				local function startLoop()
					if delay == "Heartbeat" then
						local heartbeat = service.RunService.Heartbeat
						manageRegistry "Register"

						local function doLoop()
							if runService:IsRunning() and checkLoop() then
								func(unpack(arguments))
								loopInfo.lastLooped = osTime()
								oneTimeEvent(heartbeat, doLoop)
							end
							--until
							--	not loopInfo.active or not checkRegistry()
						end

						doLoop()
					--manageRegistry("UnRegister")
					elseif delay == "Stepped" then
						local stepped = service.RunService.Stepped
						manageRegistry "Register"

						local function doLoop()
							if runService:IsRunning() and checkLoop() then
								func(unpack(arguments))
								loopInfo.lastLooped = osTime()
								oneTimeEvent(stepped, doLoop)
							else
								manageRegistry "UnRegister"
							end
						end

						doLoop()
					--manageRegistry("UnRegister")
					elseif delay == "RenderStepped" then
						local rstepped = service.RunService.RenderStepped
						manageRegistry "Register"

						local function doLoop()
							if runService:IsRunning() and checkLoop() then
								func(unpack(arguments))
								loopInfo.lastLooped = osTime()
								oneTimeEvent(rstepped, doLoop)
							else
								manageRegistry "UnRegister"
							end
						end

						doLoop()
					--manageRegistry("UnRegister")
					elseif tonumber(delay) then
						local delayNum = tonumber(delay)
						manageRegistry "Register"

						local function doLoop()
							if runService:IsRunning() and checkLoop() then
								func(unpack(arguments))
								loopInfo.lastLooped = osTime()
								if runService:IsRunning() then task.delay(delayNum, doLoop) end
							else
								manageRegistry "UnRegister"
							end
						end

						doLoop()
					--manageRegistry("UnRegister")
					else
						loopInfo.active = false
					end
				end

				loopInfo.task = task.defer(startLoop)
				return loopInfo.task, loopInfo
			end,

			startLoop = function(...) return service.loopTask(...) end,

			stopLoop = function(name)
				local str = type(name) == "string"
				local stoppedLoops = 0
				local runService = service.RunService
				local stopperTrace = debug.traceback(nil, 2)

				if str then
					for i, loop in pairs(onGoingLoops) do
						if i == name or loop.name == name then
							loop.active = false
							pcall(task.cancel, loop.task)
							stoppedLoops = stoppedLoops + 1
							onGoingLoops[i] = nil
						end
					end

					return stoppedLoops
				end
			end,

			oneTimeLoop = function(name, isThread, delay, func, ...)
				service.stopLoop(name)
				return service.loopTask(name, isThread, delay, func, ...)
			end,
		}, {
			createQueue = function(name, delay, isThread, func, errorFunc)
				local origName = name or "__QUEUE-" .. getRandom(math.random(14, 20))
				local queueTab
				queueTab = {
					TaskName = "__QUEUE-" .. (name or getRandom(math.random(20))),
					Name = origName,
					Function = func,
					Thread = isThread,
					ProcessCount = 0,
					ErrorCount = 0,
					QueueCount = 0,
					LastError = nil,
					ErrorFunc = errorFunc,
					Delay = delay or 0,

					Queue = {},

					Errored = Instance.new "BindableEvent",

					Process = function()
						if not queueTab.__Processing then
							queueTab.__Processing = true

							local delay = queueTab.Delay or 0
							delay = math.abs(delay)

							for i, que in pairs(queueTab.Queue) do
								if delay > 0 then wait(delay) end

								local list = que.Arguments or {}

								local rets = { service.trackTask(queueTab.TaskName .. "-" .. tostring(i), queueTab.Thread, func, unpack(list)) }

								if not rets[1] then
									que.LastError = rets[2]
									queueTab.LastError = rets[2]
									que.Errored:Fire(unpack(rets, 2))
									queueTab.Errored:Fire(que.QueuePos, unpack(rets, 2))
								end

								que.Returned:Fire(que.QueuePos, cloneTable(rets))
								queueTab.Queue[i] = nil
							end

							queueTab.__Processing = false
						end
					end,
				}

				table.insert(queues, queueTab)

				return queueTab
			end,

			processQueue = function(name)
				for i, queue in pairs(queues) do
					local isProcessing = queue.__Processing

					if queue.Name == name and not isProcessing then service.trackTask("__QUEUEPROCESSING-" .. queue.Name, true, queue.Process) end
				end
			end,

			addQueue = function(name, ...)
				local existingQue = {
					Arguments = { ... },
					Added = osTime(),
					LastError = nil,

					Returned = service.New "BindableEvent",
					Errored = service.New "BindableEvent",
				}

				local queueDirectory = (function()
					for i, v in pairs(queues) do
						if v.Name == name then return v end
					end
				end)()

				if queueDirectory then
					local queTab = queueDirectory.Queue
					local index = #queTab + 1
					local actualIndex = queueDirectory.QueueCount + 1

					queueDirectory.QueueCount = queueDirectory.QueueCount + 1

					existingQue.ActualIndex = actualIndex
					existingQue.QueuePos = actualIndex
					existingQue.Index = index
					existingQue.Pos = index
					table.insert(queTab, existingQue)

					if not queueDirectory.__Processing then service.trackTask("_QUEUE_RUN_PROCESSOR-" .. queueDirectory.Name, true, queueDirectory.Process) end

					return existingQue
				end
			end,

			waitQueue = function(name, ...)
				local queue = service.addQueue(name, ...)

				if queue then return queue.Returned.Event:Wait() end
			end,

			rbxEvent = function(event, func, noPcall)
				local eventName = tostring(event)
				local unWrap = service.unWrap
				local eventCon = connectEvent(unWrap(event), function(...)
					if noPcall then
						return func(...)
					else
						local suc, ers = pcall(func, ...)

						if not suc then warn("Event " .. tostring(eventName) .. " function encountered an error: " .. tostring(ers)) end
					end
				end)

				table.insert(rbxEvents, eventCon)
				return eventCon
			end,

			selfEvent = function(event, func)
				local eventCon
				eventCon = service.rbxEvent(event, function(...) return func(eventCon, ...) end)

				return eventCon
			end,
		}, {
			newProxy = function(proxTab)
				local prox = newproxy(true)
				local meta = getmetatable(prox)

				meta.__metatable = "Essential"

				for i, v in pairs(proxTab or {}) do
					meta[i] = v
				end

				return prox
			end,

			newProxyWithMeta = function(proxTab)
				local prox = newproxy(true)
				local meta = getmetatable(prox)

				meta.__metatable = "Essential"

				for i, v in pairs(proxTab or {}) do
					meta[i] = v
				end

				return prox, meta
			end,

			metaFunc = function(func, noPcall)
				if type(func) == "function" then
					return service.newProxy {
						__call = function(self, ...)
							if noPcall then
								return func(...)
							else
								local rets = { service.nonThreadTask(func, ...) }

								if not rets[1] then
									warn("Meta function encountered an error: " .. tostring(rets[2]), "\n", rets[3])
								else
									return unpack(rets, 2)
								end
							end
						end,
						__tostring = function() return "Essential-" .. getRandom() end,
					}
				else
					return func
				end
			end,

			metaTable = function(tab, name)
				return service.newProxy {
					__index = function(self, ind) return tab[ind] end,
					__iter = function(self) return pairs, tab end,
					__tostring = function() return name or "Essential-" .. getRandom() end,
				}
			end,

			metaRead = function(tab, exemptions, errorMessage, checkCall)
				local exempts = exemptions or {}
				local errMessage = errorMessage or "Attempting to overwrite an index in a read only table"
				local noError = rawequal(errMessage, "Mute") or rawequal(errMessage, "Silent") or nil
				local checkCall = checkCall or function() return true end
				local debugTrace = debug.traceback
				return service.newProxy {
					__index = function(self, ind)
						local check = checkCall("Index", tab, ind, getfenv(2), debugTrace(nil, 2) or "[unknown trace]")

						if check then
							local selected = tab[ind]
							local selectTyp = type(selected)

							if selectTyp == "table" then
								return service.metaRead(selected)
							elseif selectTyp == "function" then
								return service.metaFunc(selected)
							else
								return selected
							end
						end
					end,

					__newindex = function(self, ind, val)
						local check = checkCall("NewIndex", tab, ind, val, getfenv(2), debugTrace(nil, 2) or "[unknown trace]")

						if check then
							local allowedToOverwrite = exempts[ind]

							if allowedToOverwrite then
								tab[ind] = val
							elseif not noError then
								error(errMessage, 0)
							end
						end
					end,

					--// DO NOT USE PAIRS METHOD. IT WILL CRASH.
					__iter = function(self)
						local list = {}

						for ind, value in pairs(tab) do
							local check = checkCall("Index", tab, ind, getfenv(2))

							if check then
								local selected = tab[ind]
								local selectTyp = type(selected)

								if selectTyp == "table" then
									list[ind] = service.metaRead(selected)
								elseif selectTyp == "function" then
									list[ind] = service.metaFunc(selected)
								else
									list[ind] = selected
								end
							end
						end

						return next, list
					end,

					__tostring = function() return "Essential-ReadOnly" end,
					__metatable = "ReadOnly",
				}
			end,

			tableRead = function(tab, doWrap)
				if type(tab) == "table" then
					if not doWrap then
						return table.freeze(cloneTable(tab))
					else
						return table.freeze(service.wrap(cloneTable(tab), true))
					end
				else
					return tab
				end
			end,

			symbolicTable = function(tab, tabMetatable, isReadOnly)
				local symbolicMeta = {
					__index = function(self, ind)
						local val = tab[ind]
						if not isReadOnly or type(val) ~= "table" then
							return val
						else
							return service.tableRead(val)
						end
					end,
					__newindex = function(self, ind, val)
						if isReadOnly then
							error(`Symbolic Table is read only`, 0)
							return
						end
						tab[ind] = val
					end,
					__call = function(self, ...) return tab(...) end,
					__concat = function(self, value) return end,

					__iter = function(self) return next, tab end,
					__add = function(self, value) return tab + value end,
					__sub = function(self, value) return tab - value end,
					__mul = function(self, value) return tab * value end,
					__div = function(self, value) return tab / value end,
					__idiv = function(self, value) return tab // value end,
					__mod = function(self, value) return tab % value end,
					__pow = function(self, value) return tab ^ value end,
					__eq = function(self, value) return tab == value end,
					__lt = function(self, value) return tab < value end,
					__le = function(self, value) return tab < -value end,
					__len = function(self) return #tab end,

					__mode = "kv",
					__tostring = function() return `Symbolic Table {tostring(tab)}` end,
					__metatable = `Symbolic Table`,
				}

				if tabMetatable then
					if tabMetatable.__unm then symbolicMeta.__unm = function(self) return tabMetatable.__unm[symbolicMeta](tab) end end

					if tabMetatable.__iter then symbolicMeta.__iter = tabMetatable.__iter end
				end

				return setmetatable({}, symbolicMeta)
			end,

			wrap = function(item, fullWrap)
				if getmetatable(item) == "EssentialW" or table.find(wrappedItems, item) then
					return item
				elseif reverseWrapItems[item] then
					return item
				elseif wrappedItems[item] then
					return wrappedItems[item]
				elseif type(item) == "table" then
					local clone = cloneTable(item)
					local wrap = service.wrap

					local function startWrap(selected)
						for i, v in pairs(selected) do
							if type(v) == "table" then
								startWrap(v)
							else
								selected[i] = wrap(v)
							end
						end
					end

					if fullWrap then startWrap(clone) end

					setmetatable(clone, {
						__index = function(self, ind)
							if ind == "UnWrap" then
								return service.metaFunc(function(self) return item end)
							else
								return rawget(clone, ind)
							end
						end,

						__metatable = "EssentialW",
					})

					return clone
				elseif typeof(item) == "Instance" or typeof(item) == "RBXScriptSignal" or typeof(item) == "RBXScriptConnection" then
					local itemInstance = typeof(item) == "Instance"
					local itemSignal = typeof(item) == "RBXScriptSignal"
					local itemConnection = typeof(item) == "RBXScriptConnection"
					local unWrap = service.unWrap
					local wrap = service.wrap
					local metaFunc = service.metaFunc
					local proxy = newproxy(true)

					local descAdded = itemInstance and item.DescendantAdded
					local descRem = itemInstance and item.DescendantRemoving
					local childAdded = itemInstance and item.ChildAdded
					local childRem = itemInstance and item.ChildRemoved

					local proxMeta = getmetatable(proxy)
					local proxData
					proxData = {
						SetAttribute = function(self, prop, val)
							if itemInstance then item:SetAttribute(prop, val) end
						end,

						GetAttribute = function(self, prop)
							if itemInstance then item:GetAttribute(prop) end
						end,

						UnWrap = function() return item end,

						--GetProxyData = function()
						--	return proxData
						--end;

						GetProxyMeta = function() return proxMeta end,

						SetProxy = function(self, prox, val) proxData[prox] = val end,

						Clone = function(self, noWrap)
							local clone = item:Clone()

							return (fullWrap and not noWrap and service.wrap(clone)) or clone
						end,

						Disconnect = function(self)
							if itemConnection and item.Disconnect then item:Disconnect() end
						end,

						Connect = function(self, func)
							if itemSignal then
								return wrap(connectEvent(item, function(...) return func(unpack(wrap { ... })) end))
							end
						end,

						IsA = function(self, className) return objIsA(item, className) end,

						Wait = function(self, ...) return wrap(item.Wait)(item, ...) end,

						ChildAdded = function(self, func)
							local event = wrap(connectEvent(childAdded, function(...) return func(unpack(wrap { ... })) end))

							return (fullWrap and wrap(event)) or event
						end,

						ChildRemoved = function(self, func)
							local event = wrap(connectEvent(childRem, function(...) return func(unpack(wrap { ... })) end))

							return (fullWrap and wrap(event)) or event
						end,

						DescendantAdded = function(self, func)
							local event = wrap(connectEvent(descAdded, function(...) return func(unpack(wrap { ... })) end))

							return (fullWrap and wrap(event)) or event
						end,

						DescendantRemoving = function(self, func)
							local event = wrap(connectEvent(descRem, function(...) return func(unpack(wrap { ... })) end))

							return (fullWrap and wrap(event)) or event
						end,
					}

					proxData.wait = proxData.Wait
					proxData.connect = proxData.Connect
					proxData.disconnect = proxData.Disconnect

					proxMeta.__metatable = "EssentialW"
					proxMeta.__index = function(self, ind)
						local proxSelection = proxData[ind]

						if type(proxSelection) == "function" then
							return function(_, ...) return proxSelection(proxData, ...) end
						elseif not rawequal(proxSelection, nil) then
							return proxSelection
						end

						local selection = item[ind]

						if type(selection) == "table" then
							return wrap(selection, fullWrap)
						elseif type(selection) == "function" then
							return function(ignore, ...) return unpack(wrap { checkMethod(item, ind, unpack(unWrap { ... })) }) end
						else
							return wrap(selection, fullWrap)
						end
					end

					proxMeta.__newindex = function(self, ind, val) item[ind] = unWrap(val) end

					proxMeta.__eq = rawequal
					proxMeta.__gc = function()
						if wrappedItems[item] then wrappedItems[item] = nil end
					end
					proxMeta.__tostring = function() return proxData.Tostring or proxData.Name or tostring(item) end

					wrappedItems[item] = proxy
					reverseWrapItems[proxy] = item

					return proxy
				else
					return item
				end
			end,
			Wrap = function(...) return service.wrap(...) end,

			specialWrap = function(item, hardWrap, readOnly)
				local itemType = type(item)

				if itemType == "userdata" or (itemType == "table" and hardWrap) then
					local unWrap = service.unWrap
					local proxy = service.newProxy {
						__call = function(_, ...) return item(unpack(unWrap { ... })) end,

						__newindex = function(_, ind, val) item[ind] = unWrap(val) end,

						__index = function(_, ind)
							local selected = item[ind]

							if typeof(selected) == "Instance" then
								return service.wrap(selected, hardWrap)
							elseif type(selected) == "function" then
								return service.metaFunc(function(ignore, ...) return selected(item, unpack(unWrap { ... })) end)
							else
								return selected
							end
						end,

						__tostring = function() return tostring(item) end,
						__metatable = "ESWRAP-" .. tostring(getmetatable(item)),
					}

					specialWrappedItems[proxy] = item

					return proxy
				elseif itemType == "table" then
					return (readOnly and service.metaRead(item)) or service.wrap(item)
				else
					return item
				end
			end,

			unWrap = function(item, removeCycle)
				if getmetatable(item) == "EssentialW" and reverseWrapItems[item] then
					return item:UnWrap()
				elseif getmetatable(item) == "ReadOnly" then
					return item
				--elseif table.find({"table", "userdata"}, type(item)) and reverseWrapItems[item] then
				--	return item:UnWrap()
				elseif type(item) == "userdata" and specialWrappedItems[item] then
					return specialWrappedItems[item]
				elseif type(item) == "table" then
					local item = cloneTable(item) -- Clone first to remove duplicated tables
					local clone = {}
					local cycled = {}
					local unWrap = service.unWrap

					for i, v in pairs(item) do
						if rawequal(v, item) then
							--clone[i] =
							continue
						else
							clone[i] = unWrap(v)
						end
					end

					return clone
				else
					return item
				end
			end,
		}, {
			setSpecific = function(ind, val)
				if not specificLocked then rawset(serviceSpecific, ind, val) end
			end,

			removeSpecific = function(ind, val)
				if not specificLocked then rawset(serviceSpecific, ind, nil) end
			end,

			isTableCircular = function(...) return isTableCircular(...) end,

			cloneTable = function(tab, deepCopy)
				local suc, clone = pcall(cloneTable, tab, deepCopy)
				if not suc then
					warn("Clone table failed:", tostring(clone))
					warn("Traceback:", debug.traceback(nil, 2))
				else
					return clone
				end
			end,

			cloneTableWithIgnore = function(tab, ignoreList)
				local cloned = cloneTable(tab, ignoreList)

				return cloned
			end,

			shallowCloneTable = function(tab)
				local new = table.clone(tab)
				setmetatable(new, nil)

				return new
			end,

			stringTable = function(tab)
				local new = {}

				for i, v in pairs(tab) do
					new[i] = tostring(v)
				end

				return new
			end,

			compactTable = function(tab)
				local new = {}
				local rawlen = function(t: { [any]: any }): number
					local count = 0
					for i, v in ipairs(t) do
						count += 1
					end

					return count
				end

				local rawCount = rawlen(tab)
				local isTableAllNumeric = rawCount > 0 and rawCount == service.tableCount(tab)

				for i, v in (isTableAllNumeric and ipairs or pairs)(tab) do
					table.insert(new, v)
				end

				return new
			end,

			mergeTables = function(numIndex, ...)
				local newTab = {}

				if #{ ... } > 0 then
					for i, tab in ipairs { ... } do
						for ind, val in pairs(tab) do
							if numIndex then
								table.insert(newTab, val)
							else
								newTab[ind] = val
							end
						end
					end
				end

				return newTab
			end,

			tableCount = function(tab)
				local len = 0

				for i, v in pairs(tab) do
					len += 1
				end

				return len
			end,

			New = function(class, propsTab, doWrap)
				local object = Instance.new(class)

				if object then
					local props = propsTab or {}

					if typeof(props) == "Instance" then
						object.Parent = props
					else
						for i, v in pairs(props) do
							object[i] = service.unWrap(v)
						end
					end

					return (doWrap and service.wrap(object, true)) or object
				end
			end,

			new = function(...) return service.New(...) end,

			isPlayerUserIdValid = function(userId: number)
				if type(userId) == "number" and userId > 0 then
					local blankName = "[unknown]"
					local existCache = (function()
						for cacheUserId, cacheTab in pairs(userIdCache) do
							if userId == cacheUserId then return cacheTab end
						end
					end)()

					if existCache then
						return existCache.possibleNames[1] ~= nil
					else
						service.playerNameFromId(userId)
						local existCache = userIdCache[userId]
						return existCache and existCache.possibleNames[1] ~= nil or false
					end
				else
					return false
				end
			end,

			--[[
			TODO: USER ID CACHE
			
			{
				userId: number,
				possibleNames: string{}
			}
		]]

			playerNameFromId = function(num: number)
				if type(num) ~= "number" then return "[unknown]" end

				num = math.floor(num)

				if num == 0 then
					return "[system]"
				elseif num < 0 then
					return `Player{math.floor(math.abs(num))}`
				end

				local existCache = (function()
					for name, cacheInfo in pairs(userIdCache) do
						if cacheInfo.userId == num then return cacheInfo end
					end
				end)()
				local initialCacheIndex = if existCache then num else nil

				if existCache and (os.time() - existCache.updated < 300) then
					return existCache.possibleNames[1] or "[unknown]"
				else
					if not existCache then
						existCache = {
							userId = num,
							updated = os.time(),
							possibleNames = {},
							temporary = true,
							finished = false,
						}
						userIdCache[num] = existCache
					else
						existCache.updated = os.time()
					end

					local suc, foundName = pcall(function() return service.Players:GetNameFromUserIdAsync(num) end)

					if suc and foundName then
						foundName = foundName:lower()
						if not table.find(existCache.possibleNames, foundName) then table.insert(existCache.possibleNames, foundName) end

						if userIdCache[foundName] then userIdCache[foundName] = nil end

						return foundName
					else
						return existCache.possibleNames[1] or "[unknown]"
					end
				end
			end,

			playerIdFromName = function(str)
				if not (type(str) == "string" and #str >= 3) then return 0 end
				if str:lower() == "[system]" then return 0 end

				if str:match "^Player(%d+)$" and onStudio then
					local player = service.getPlayer(str)
					if player then return player.UserId end
				end

				local existingCache

				do
					for userId, otherCache in userIdCache do
						if table.find(otherCache.possibleNames, str:lower()) then
							existingCache = otherCache
							break
						end
					end

					if not existingCache then
						existingCache = userIdCache[str:lower()]

						if not existingCache then
							existingCache = {
								userId = 0,
								updated = os.time(),
								possibleNames = { str:lower() },
								temporary = true,
								finished = false,
							}

							userIdCache[str:lower()] = existingCache
						end
					end
				end

				if existingCache and (os.time() - existingCache.updated < 300 or (existingCache.temporary and not existingCache.finished)) then
					local suc, ers = pcall(function() return service.Players:GetUserIdFromNameAsync(str) end)

					existingCache.finished = true

					if suc and ers then
						existingCache.userId = ers
						if userIdCache[ers] then
							if not table.find(userIdCache[ers].possibleNames, str:lower()) then table.insert(userIdCache[ers].possibleNames, str:lower()) end
						else
							existingCache.temporary = false

							userIdCache[ers] = existingCache
							userIdCache[str:lower()] = nil
						end

						return ers
					end

					return existingCache.userId
				elseif existingCache then
					return existingCache.userId
				end

				return 0
			end,

			debounce = function(name, func, ...)
				func = not func and name or func

				if not debounceFuncs[name] then
					debounceFuncs[name] = func
					local errTrace = ""
					local errMessage = ""
					local rets = { xpcall(func, function(errM)
						errMessage = errM
						errTrace = debug.traceback(nil, 2)
					end, ...) }

					if #errMessage > 0 then rets[2] = errMessage end

					if #errTrace > 0 then rets[3] = errTrace end

					if not rets[1] then
						warn("Debounce " .. tostring(name) .. " encountered an error: " .. tostring(rets[2]))

						if service.RunService:IsStudio() then warn(errTrace) end
					end

					debounceFuncs[name] = nil
					return true, unpack(rets, 2)
				else
					return false
				end
			end,
			Debounce = function(...) return service.debounce(...) end,

			getSubscriptionInfo = function(subscriptionId: string)
				local cache = subscriptionInfoCache[subscriptionId]

				if not cache then
					cache = {
						results = {
							IsCreated = false,
						},
					}
					subscriptionInfoCache[subscriptionId] = cache
				end

				local canUpdateCache = not cache.lastUpdated or os.clock() - cache.lastUpdated > 120

				if canUpdateCache then
					cache.lastUpdated = os.clock()
					local suc, info = pcall(service.Marketplace.GetSubscriptionProductInfoAsync, service.Marketplace, subscriptionId)

					if suc and type(info) == "table" then
						info.IsCreated = true
						cache.results = info
					else
						cache.results.IsCreated = false
					end
				end

				return cloneTable(cache.results)
			end,

			getProductInfo = function(assetId, infoType)
				assetId = tonumber(assetId) or 0
				infoType = infoType or Enum.InfoType.Asset

				if assetId > 0 then
					local cache = assetInfoCache[tostring(assetId) .. "-" .. tostring(infoType.Name)]

					if not cache then
						cache = {
							results = {
								IsCreated = false,
							},
						}
						assetInfoCache[tostring(assetId) .. "-" .. tostring(infoType.Name)] = cache
					end

					local canUpdateCache = not cache.lastUpdated or os.clock() - cache.lastUpdated > 120

					if canUpdateCache then
						cache.lastUpdated = os.clock()
						local suc, info = pcall(service.Marketplace.GetProductInfo, service.Marketplace, assetId, infoType)

						if suc and type(info) == "table" then
							info.IsCreated = true
							cache.results = info
						else
							cache.results.IsCreated = false
						end
					end

					return cloneTable(cache.results)
				end
			end,

			checkActiveSubscription = function(player, subscriptionId)
				local cacheIndex = player.UserId .. `-` .. subscriptionId
				local currentCache = subscriptionOwnershipCache[cacheIndex]

				if not currentCache then
					currentCache = {
						owned = false,
						renewing = false,
						lastUpdated = os.time(),
					}
					subscriptionOwnershipCache[cacheIndex] = currentCache
				end

				local canUpdateCache = not currentCache.lastUpdated or os.time() - currentCache.lastUpdated > 180

				if canUpdateCache then
					currentCache.lastUpdated = os.time()

					local suc, subscriptionInfo = pcall(service.Marketplace.GetUserSubscriptionStatusAsync, service.Marketplace, player, subscriptionId)

					if suc then
						currentCache.owned = subscriptionInfo.IsSubscribed
						currentCache.renewing = subscriptionInfo.IsRenewing
					end
				end

				return currentCache.owned, currentCache.renewing
			end,

			checkPassOwnership = function(userId, gamepassId)
				local cacheIndex = tonumber(userId) .. "-" .. tonumber(gamepassId)
				local currentCache = passOwnershipCache[cacheIndex]

				if currentCache and currentCache.owned then
					return true
				elseif (currentCache and (os.time() - currentCache.lastUpdated > 120)) or not currentCache then
					local cacheTab = {
						owned = (currentCache and currentCache.owned) or false,
						lastUpdated = os.time(),
					}
					passOwnershipCache[cacheIndex] = cacheTab

					local suc, ers = pcall(function() return service.Marketplace:UserOwnsGamePassAsync(userId, gamepassId) end)

					if suc then
						cacheTab.owned = toBoolean(ers)
						return toBoolean(ers)
					else
						return cacheTab.owned
					end
				elseif currentCache then
					return currentCache.owned
				end
			end,

			checkAssetOwnership = function(player, assetId)
				local cacheIndex = tonumber(player.UserId) .. "-" .. tonumber(assetId)
				local currentCache = assetOwnershipCache[cacheIndex]

				if currentCache and currentCache.owned then
					return true
				elseif (currentCache and (os.time() - currentCache.lastUpdated > 120)) or not currentCache then
					local cacheTab = {
						owned = (currentCache and currentCache.owned) or false,
						lastUpdated = os.time(),
					}
					passOwnershipCache[cacheIndex] = cacheTab

					local suc, ers = pcall(function() return service.Marketplace:PlayerOwnsAsset(player, assetId) end)

					if suc then cacheTab.owned = toBoolean(ers) end

					return cacheTab.owned
				elseif currentCache then
					return currentCache.owned
				end
			end,

			getGroupInfo = function(groupId)
				groupId = tonumber(groupId) or 0

				if groupId > 0 then
					local existingCache = groupInfoCache[groupId]
					local canUpdate = not existingCache or os.time() - existingCache.lastUpdated > 120

					if canUpdate then
						existingCache = {
							results = (existingCache and existingCache.results) or {},
							lastUpdated = os.time(),
						}
						groupInfoCache[groupId] = existingCache

						local suc, info = pcall(service.GroupService.GetGroupInfoAsync, service.GroupService, groupId)

						if suc and type(info) == "table" then
							existingCache.results = info
						else
							existingCache.results.Failed = true
						end
					end

					return cloneTable(existingCache.results)
				end
			end,

			getGroupCreatorId = function(groupId)
				groupId = tonumber(groupId) or 0

				if groupId > 0 then
					local groupInfo = service.getGroupInfo(groupId)

					if groupInfo and groupInfo.Created then return groupInfo.Owner.Id end
				end

				return 0
			end,

			insertAsset = function(assetId, bundleAssets)
				local assetCache = assetInsertionCache[assetId]
				local canUpdate = not assetCache or (os.time() - assetCache.lastUpdated > 120)

				if canUpdate then
					assetCache = {
						success = false,
						lastUpdated = os.time(),
						contents = (assetCache and assetCache.contents) or {},
					}
					assetInsertionCache[assetId] = assetCache

					local suc, actualAsset = pcall(function() return service.InsertService:LoadAsset(assetId) end)

					if suc and actualAsset then assetCache.contents = { unpack(actualAsset:GetChildren()) } end

					assetCache.success = suc
				end

				if bundleAssets then
					local container = service.New("Folder", {
						Name = "Asset-" .. tostring(assetId),
					})

					local cloneContents = {}
					for i, content in pairs(assetCache.contents) do
						local cl = content:Clone()
						cl.Parent = container
					end

					return assetCache.success, container
				else
					local cloneContents = {}
					for i, content in pairs(assetCache.contents) do
						table.insert(cloneContents, content:Clone())
					end

					return assetCache.success, cloneContents
				end
			end,

			iterPageItems = function(pages)
				return coroutine.wrap(function()
					local pagenum = 1
					while true do
						for _, item in ipairs(pages:GetCurrentPage()) do
							corotYield(item, pagenum)
						end
						if pages.IsFinished then break end
						pages:AdvanceToNextPageAsync()
						pagenum = pagenum + 1
					end
				end)
			end,

			tweenCreate = function(object, tweenInfo: TweenInfo, propData)
				assert(typeof(tweenInfo) == "TweenInfo", "Argument 2 is not a TweenInfo")
				assert(type(propData) == "table", "Argument 3 is not a table")

				local unWrapTab = service.unWrap
				local tweenAnim = service.wrap(service.TweenService:Create(unWrapTab(object), tweenInfo, propData))
				local tweenPlay = tweenAnim.Play

				tweenAnim:SetProxy("Play", function(...)
					local wrapObj = service.wrap(object)
					if object:IsDescendantOf(game) then
						local unWrapObj = unWrapTab(tweenAnim)
						local sucessTween = service.threadTask(unWrapObj.Play, unWrapObj, unWrapTab { ... })

						if not sucessTween then
							for prop, val in pairs(propData) do
								object[prop] = val
							end
						end
					else
						for prop, val in pairs(propData) do
							object[prop] = val
						end
					end
				end)

				return tweenAnim
			end,

			tableMatch = function(tab1, tab2)
				local function doCheck(t1, t2)
					local definitelyMatched = true

					for i, v in pairs(t1) do
						local match = true
						local firstTabValue = v
						local secondTabValue = rawget(t2, i)
						local firstTabValueType = type(firstTabValue)
						local secTabValueType = type(secondTabValue)

						-- Check the type first
						if firstTabValueType ~= secTabValueType then match = false end

						if firstTabValueType == "table" and match then --// Table
							local checkBothTabs = service.tableMatch(firstTabValue, secondTabValue)

							if not checkBothTabs then
								match = false
							else
								for d, e in pairs(firstTabValue) do
									local insideMatch = true

									insideMatch = service.checkEquality(e, rawget(secondTabValue, d))

									if not insideMatch then
										match = false
										break
									end
								end
							end
						elseif firstTabValueType ~= "table" and firstTabValueType ~= "userdata" and firstTabValue ~= secondTabValue and match then -- Primitives
							match = false
						elseif firstTabValueType == "userdata" and match then
							match = rawequal(firstTabValue, secondTabValue)
						end

						if not match then
							definitelyMatched = false
							break
						end
					end

					return definitelyMatched
				end

				return (doCheck(tab1, tab2) and doCheck(tab2, tab1)) or false
			end,

			checkTableIndexes = function(tab, indexType)
				local sortCount = 0

				for ind, val in pairs(tab) do
					if type(ind) ~= indexType then return false end

					sortCount += 1
				end

				return true
			end,

			isTableAnArray = function(tab: { [any]: any }): boolean
				local initialIndex = 0

				for i, v in tab do
					initialIndex += 1
					if type(i) ~= "number" then return false end
					if math.floor(i) ~= i then return false end
					if initialIndex ~= i then return false end
				end

				return true
			end,

			getInitialIndex = function(tab)
				for i, v in ipairs(tab) do
					return i
				end
			end,

			checkEquality = function(a, b)
				local equal = rawequal(a, b)

				if equal then
					return true
				elseif type(a) == "table" and type(b) == "table" then
					return service.tableMatch(a, b)
				elseif (type(a) == "string" and type(b) == "string") and a:lower() == b:lower() then
					return true
				else
					return false
				end
			end,

			shallowCopy = function(inst)
				local function doFunc(obj)
					local clone = obj:Clone()

					for i, child in pairs(obj:GetChildren()) do
						local descCopy = doFunc(child)

						if descCopy then descCopy.Parent = child end
					end

					if clone then
						return clone
					else
						obj.Archivable = true
						clone = obj:Clone()
						obj.Archivable = false

						return obj or nil
					end
				end

				return doFunc(inst)
			end,

			fireServer = function(obj, ...) fireServer(obj, ...) end,
			invokeServer = function(obj, ...) return invokeServer(obj, ...) end,

			objIsA = function(obj, class)
				if typeof(obj) ~= "Instance" then return false end
				return objIsA(obj, class)
			end,

			getAttribute = function(obj, attribute) return getAttribute(obj, attribute) end,

			safeFunction = function(func)
				local corotCreate = coroutine.create
				local corotResume = corotResume

				local thread = corotCreate(func)

				return function(...) return unpack({ corotResume(thread, ...) }, 2) end
			end,

			getPlayer = function(idOrName)
				local typ = type(idOrName)
				local idOnly = (typ == "number" and true) or false
				local nameOnly = (typ == "string" and true) or false

				for i, plr in pairs(service.getPlayers()) do
					if idOnly and plr.UserId == idOrName then
						return plr
					elseif nameOnly and plr.Name:lower() == idOrName:lower() then
						return plr
					end
				end
			end,

			getPlayers = function()
				local tab = {}

				for i, plr in pairs(service.Players:GetPlayers()) do
					if rawequal(typeof(plr), "Instance") and objIsA(plr, "Player") then table.insert(tab, plr) end
				end

				return tab
			end,
			GetPlayers = function(...) return service.getPlayers(...) end,

			convertUserIdsToPlayers = function(userIdList)
				local tab = {}

				for i, userid in pairs(userIdList) do
					if type(userid) == "number" and userid > 0 then
						local plr = service.getPlayer(userid)

						if plr and not table.find(tab, plr) then table.insert(tab, plr) end
					end
				end

				return tab
			end,

			getCSR = function()
				local SSS = service.ServerScriptService

				if SSS then
					local found

					for i, child in pairs(SSS:children()) do
						if child.ClassName == "Script" and child.Name == "ChatServiceRunner" then
							found = child
							break
						end
					end

					return found
				end
			end,

			roundNumber = function(number, increment, numOfDecimalDigits)
				numOfDecimalDigits = numOfDecimalDigits or 5
				local rounded = math.floor(number / increment + 0.5) * increment
				return tonumber(string.format("%."..numOfDecimalDigits.."f", rounded))
			end,


			-- Adonis's encrypt function (@Sceleratis)
			--// Modifier: trzistan
			encryptStr = function(str, key, cache)
				cache = cache or encryptCache or {}

				if not key or not str then
					return str
				elseif cache[key] and cache[key][str] then
					return cache[key][str]
				else
					local byte = string.byte
					local sub = string.sub
					local char = string.char

					local keyCache = cache[key] or {}
					local endStr = {}

					local success, err = service.nonThreadTask(function()
						for i = 1, #str do
							local keyPos = (i % #key) + 1
							endStr[i] = char(((byte(sub(str, i, i)) + byte(sub(key, keyPos, keyPos))) % 126) + 1)
						end
					end)

					if not success then
						cache[key] = keyCache
						keyCache[str] = "-1"
						return "-1"
					end

					endStr = table.concat(endStr)
					cache[key] = keyCache
					keyCache[str] = endStr
					return endStr
				end
			end,

			--// Adonis's decrypt function (@Sceleratis)
			--// Modifier: trzistan
			decryptStr = function(str, key, cache)
				cache = cache or decryptCache or {}

				if not key or not str then
					return str
				elseif cache[key] and cache[key][str] then
					return cache[key][str]
				else
					local keyCache = cache[key] or {}
					local byte = string.byte
					local sub = string.sub
					local char = string.char
					local endStr = {}

					local success = service.nonThreadTask(function()
						for i = 1, #str do
							local keyPos = (i % #key) + 1
							endStr[i] = char(((byte(sub(str, i, i)) - byte(sub(key, keyPos, keyPos))) % 126) - 1)
						end
					end)

					if not success then
						cache[key] = keyCache
						keyCache[str] = "-1"
						return "-1"
					end

					endStr = table.concat(endStr)
					cache[key] = keyCache
					keyCache[str] = endStr
					return endStr
				end
			end,

			base64Encode = function(data)
				local sub = string.sub
				local byte = string.byte
				local gsub = string.gsub

				return (gsub(gsub(data, ".", function(x)
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
				})[#data % 3 + 1])
			end,

			base64Decode = function(data)
				local sub = string.sub
				local gsub = string.gsub
				local find = string.find
				local char = string.char

				local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

				data = gsub(data, "[^" .. b .. "=]", "")
				return (gsub(
					gsub(data, ".", function(x)
						if x == "=" then return "" end
						local r, f = "", (find(b, x) - 1)
						for i = 6, 1, -1 do
							r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
						end
						return r
					end),
					"%d%d%d?%d?%d?%d?%d?%d?",
					function(x)
						if #x ~= 8 then return "" end
						local c = 0
						for i = 1, 8 do
							c = c + (sub(x, i, i) == "1" and 2 ^ (8 - i) or 0)
						end
						return char(c)
					end
				))
			end,

			typeof = function(item)
				local realTypeof = typeof(service.unWrap(item))
				return realTypeof
			end,

			convertPlayerCharacterToRig = function(plr, rigType)
				rigType = rigType or Enum.HumanoidRigType.R15

				local Humanoid = plr.Character and (plr.Character:FindFirstChildOfClass "Humanoid" or service.New "Humanoid")

				local HumanoidDescription = Humanoid:GetAppliedDescription() or service.Players:GetHumanoidDescriptionFromUserId(plr.UserId)
				local newCharacterModel = service.Players:CreateHumanoidModelFromDescription(HumanoidDescription, rigType)
				local Animate = newCharacterModel:FindFirstChild "Animate"

				newCharacterModel.Humanoid.DisplayName = Humanoid.DisplayName
				newCharacterModel.Name = plr.Name

				local oldCFrame = plr.Character and plr.Character:GetPivot()

				if plr.Character then
					plr.Character:Destroy()
					plr.Character = nil
				end
				plr.Character = newCharacterModel

				newCharacterModel.Parent = service.Workspace

				if oldCFrame then newCharacterModel:SetPrimaryPartCFrame(oldCFrame) end

				-- hacky way to fix other people being unable to see animations.
				for _ = 1, 2 do
					if Animate then Animate.Disabled = not Animate.Disabled end
				end

				return newCharacterModel
			end,

			extractLines = function(str)
				local strs = {}
				local new = ""
				for i = 1, #str + 1 do
					if string.byte(str:sub(i, i)) == 10 or i == #str + 1 then
						table.insert(strs, new)
						new = ""
					else
						local char = str:sub(i, i)
						if string.byte(char) < 32 then char = "" end
						new = new .. char
					end
				end
				return strs
			end,

			immutable = function(...)
				local rotCreate = coroutine.create
				local rotWrap = coroutine.wrap
				local rotYield = corotYield
				local coRot = rotWrap(function(...)
					while true do
						rotYield(...)
					end
				end, ...)
				coRot(...)
				return coRot
			end,

			immutableEvent = function(event, func)
				local loopTask = service.loopTask
				local nonThreadTask = service.nonThreadTask
				local threadTask = service.threadTask
				local endLoop = service.stopLoop
				local getRandom = getRandom
				local connectRbxEvent = connectEvent
				local discRbxEvent = disconnectEvent
				local eventNameAndId = getRandom(60) .. tostring(event)
				local eventLoopInd = "_IMM-" .. eventNameAndId .. getRandom(10)
				local eventInfo
				eventInfo = {
					active = true,
					updated = tick(),

					disconnect = function() eventInfo.active = false end,

					connection = nil,
				}

				local function createSafeFunc()
					return function(...)
						if eventInfo.active then
							local rets = { nonThreadTask(func, ...) }

							if not rets[1] then
								return nil
							else
								return unpack(rets, 2)
							end
						end
					end
				end

				loopTask(eventLoopInd, true, 0.1, function()
					if eventInfo.active then
						if eventInfo.connection then nonThreadTask(discRbxEvent, eventInfo.connection) end
						eventInfo.connection = connectRbxEvent(event, createSafeFunc())
					else
						endLoop()
					end
				end)

				return eventInfo
			end,
		}

	service = setmetatable({
		Marketplace = game:GetService "MarketplaceService",

		Delete = function(obj, delay, deleteFunc)
			obj = service.unWrap(obj)

			if typeof(obj) == "userdata" then
				task.delay(delay or 0, function()
					if obj.Destroy then pcall(obj.Destroy, obj) end
				end)
			else
				service.Debris:AddItem(obj, delay or 0)
			end

			if deleteFunc and type(deleteFunc) == "function" then
				local checking = false
				local parCheck
				parCheck = connectEvent(obj:GetPropertyChangedSignal "Parent", function(par)
					local parent = obj.Parent

					if not checking and parent == nil then
						checking = true
						if parCheck.Disconnect then parCheck:Disconnect() end

						local suc, ers = service.trackTask("_DELETEFUNC-" .. obj.Name, true, deleteFunc, obj, osTime())

						if not suc then
							if errHandler then errHandler("DeleteFunc Failed", obj, ers, osTime()) end
						end
					end
				end)

				if obj.Parent == nil then
					checking = true

					if parCheck.Disconnect then parCheck:Disconnect() end

					local suc, ers = service.trackTask("_DELETEFUNC-" .. obj.Name, true, deleteFunc, obj, osTime())

					if not suc then
						if errHandler then errHandler("DeleteFunc Failed", obj, ers, osTime()) end
					end
				end
			end
		end,
		Destroy = function(obj) destroy(obj) end,
		GetRandom = function(...) return getRandom(...) end,
		getRandom = function(...) return getRandom(...) end,
		getRandomV2 = function(...) return generatePassphrases(...) end,
		getRandomV3 = function(...) return getRandomV3(...) end,
		generatePassphrases = function(...) return generatePassphrases(...) end,
		generatePassPhrases = function(...) return generatePassphrases(...) end,

		Routine = function(func, ...) return corotResume(coroutine.create(func), ...) end,
	}, {
		__index = function(self, ind) -- Used to index game services (i.g. ServerStorage) and specific table
			local match = serviceSpecific[ind]
				or tasks[ind]
				or events[ind]
				or wrappers[ind]
				or misc[ind]
				or cacheServices[ind]

			if match then return match end

			local suc, ers = pcall(getService, game, ind)

			if suc and ers then
				local realService = ers
				cacheServices[ind] = realService
				return realService
			end
		end,
	})

	if runService:IsServer() then
		service.Marketplace.PromptPurchaseFinished:Connect(
			function(player: Player, assetId: number, wasPurchased: boolean)
				if not wasPurchased then return end
				local existingCache = assetOwnershipCache[`{player.UserId}-{assetId}`]

				if not existingCache then
					existingCache = {
						owned = true,
						lastUpdated = os.time(),
					}
					assetOwnershipCache[`{player.UserId}-{assetId}`] = existingCache
				else
					existingCache.owned = true
					existingCache.lastUpdated = os.time()
				end
			end
		)

		service.Marketplace.PromptGamePassPurchaseFinished:Connect(
			function(player: Player, gamepassId: number, wasPurchased: boolean)
				if not wasPurchased then return end
				local existingCache = passOwnershipCache[`{player.UserId}-{gamepassId}`]

				if not existingCache then
					existingCache = {
						owned = true,
						lastUpdated = os.time(),
					}
					passOwnershipCache[`{player.UserId}-{gamepassId}`] = existingCache
				else
					existingCache.owned = true
					existingCache.lastUpdated = os.time()
				end
			end
		)

		service.Marketplace.PromptSubscriptionPurchaseFinished:Connect(
			function(player: Player, subscriptionId: number, didTryPurchasing: boolean)
				if not didTryPurchasing then return end
				local existingCache = subscriptionOwnershipCache[`{player.UserId}-{subscriptionId}`]

				if not existingCache then
					existingCache = {
						owned = false,
						renewing = false,
						lastUpdated = os.time(),
					}
					subscriptionOwnershipCache[`{player.UserId}-{subscriptionId}`] = existingCache
				else
					existingCache.owned = true
					existingCache.renewing = true
					existingCache.lastUpdated = os.time()
				end
			end
		)
	end

	return service
end
