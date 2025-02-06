--!nocheck
local utility = {}
local server, service, variables
local hashLib
local Promise, Signal

local DateTimeNow = DateTime.now

function utility:getPlayersCount(): number return #service.getPlayers() end

function utility:lockdown() server.Core.lockdown = true end

function utility:shutdown(reason: string?, secsTillShutdown: number?, moderatorId: number?): boolean
	reason = reason or "Unknown reason"

	if not (utility.shuttingDownState or utility.shutdownState) then
		utility.shuttingDownState = true

		local shutdownTime = math.clamp(tonumber(secsTillShutdown) or 5, 0, 18000)

		if shutdownTime > 0 then
			local start = os.time()

			repeat
				if not utility.shuttingDownState then break end

				local secsTillShutdown = math.floor(shutdownTime) - (os.time() - start)

				for i, plr in pairs(service.getPlayers(true)) do
					plr:sendData(
						"SendMessage",
						"Shutdown Alert",
						"Shutting down in " .. math.floor(secsTillShutdown) .. "...",
						1,
						"Hint"
					)
				end

				wait(1)
			until os.time() - start > shutdownTime

			if not utility.shuttingDownState then return end
		end

		server.Events.serverShutdown:fire(reason, moderatorId)
		utility.shutdownState = true
		utility.shutdownModeratorId = moderatorId
		utility.shutdownBeganOs = os.time()
		utility.shutdownReason = tostring(reason)

		task.defer(function()
			for attempt = 1, 3 do
				for i, plr in pairs(service.getPlayers(true)) do
					plr:sendData("SendMessage", "Shutdown Alert", "Shutting down the server..", 10, "Hint")

					task.delay(2, function()
						local modName = (moderatorId and service.playerNameFromId(moderatorId))
						plr._object:Kick(
							server.Parser:replaceStringWithDictionary(tostring(server.Settings.shutdownMessage), {
								["{reason}"] = tostring(reason),
								["{user}"] = (moderatorId and modName .. " #" .. moderatorId) or nil,
								["{userid}"] = moderatorId or nil,
								["{startTime}"] = server.Parser:osDate(os.time()),
							})
						)
					end)
				end
				task.wait(1)
			end
		end)

		return true
	else
		return false
	end
end

function utility:setupClient(plr: Player, config: { [any]: any }?)
	config = (type(config) == "table" and config)
		or {
			idleTimeout = 600,
			idleResultType = "Kick", -- Supported actions: Kick, Crash
			idleResultLog = false, -- Log the idle result
			Type = "Init",
			--> Init:	Only used to load players via GUI
			--> RF:		Only used to load new players loading in from RF
		}

	local client = server.Core.clients[plr] or {}
	local loader = (config.Type == "Init" and server.Assets.ClientInit:Clone()) or nil

	if client and client.loaded then
		warn(`CLIENT LOADER RAN TWICE:`, debug.traceback(nil, 2))
		return
	end

	if client and loader then
		client.loaded = true

		local holder = service.New("ScreenGui", {
			Name = "\0",
			DisplayOrder = math.huge,
			ResetOnSpawn = false,
			Enabled = false,
		})

		client.verifyId = service.getRandom(20)

		loader:SetAttribute("VerifyId", (client and client.verifyId) or "[unknown]")
		loader.Parent = holder

		--holder:SetAttribute("Id", client.id)
		--holder:SetAttribute("Registered", server.Parser:osDate(os.clock()))

		local folder = server.Client:Clone()
		folder.Name = service.getRandom()
		folder.Parent = loader

		-- Disable screenguis inside folder
		for i, desc in pairs(folder:GetDescendants()) do
			if desc:IsA "ScreenGui" then desc.Enabled = false end
		end

		local sharedFolder = server.SharedFolder:Clone()
		sharedFolder.Parent = folder

		local folderContents = folder:GetDescendants()
		local contents_fullNames = (function()
			local list = {}

			for i, desc in pairs(folderContents) do
				table.insert(list, desc:GetFullName())
			end

			return list
		end)()

		local secure1, secure2, secure3, secure4, secure5, secure6, secure7
		local secureCheck_Cons = {}
		local function stopSecuring()
			if secure6 then
				secure6:Disconnect()
				secure6 = nil
			end

			if secure5 then
				secure5:Disconnect()
				secure5 = nil
			end

			if secure4 then
				secure4:Disconnect()
				secure4 = nil
			end

			if secure3 then
				secure3:Disconnect()
				secure3 = nil
			end

			if secure2 then
				secure2:Disconnect()
				secure2 = nil
			end

			if secure1 then
				secure1:Disconnect()
				secure1 = nil
			end

			for i, con in pairs(secureCheck_Cons) do
				secureCheck_Cons[i] = nil
				con:Disconnect()
			end
		end

		local function kill(res)
			stopSecuring()

			if plr.Parent == service.Players then
				plr:Kick("ESSC Detection:\n" .. tostring(res or "Tampering with client folder's components"))
			end
		end

		secure1 = folder.DescendantAdded:Connect(function(desc)
			if table.find(contents_fullNames, desc:GetFullName()) then
				client.tamperedFolder = true
				client.tamperedFolderReason = "Tampering with client folder (Duplicated item?)"
				stopSecuring()
				--kill("Tampering with client folder (Duplicated item?)")
			elseif desc:IsA "Script" then
				client.tamperedFolder = true
				client.tamperedFolderReason = "Tampering with client folder (Suspicious script?)"
				stopSecuring()
				--kill("Tampering with client folder (Suspicious script?)")
			end
		end)

		secure2 = folder.DescendantRemoving:Connect(function(desc)
			if table.find(folderContents, desc) then
				client.tamperedFolder = true
				client.tamperedFolderReason = "Tampering with client folder (" .. desc:GetFullName() .. " was removed)"
				stopSecuring()
				--kill("Tampering with client folder ("..desc:GetFullName().." was removed)")
			end
		end)

		secure3 = script.ChildRemoved:Connect(function(child)
			if child == folderContents then
				client.tamperedFolder = true
				client.tamperedFolderReason = "Client folder was removed"
				stopSecuring()
				--kill("Client folder was removed")
			end
		end)

		secure4 = server.Events.playerRemoved:Connect(function(playerLeft)
			if playerLeft == plr then stopSecuring() end
		end)

		secure5 = server.Events.playerVerified:Connect(function(playerVerified)
			if playerVerified._object == plr then
				stopSecuring()
				service.Debris:AddItem(holder, 0)
			end
		end)

		secure6 = server.Events.playerRemoved:Connect(function(removedPlr)
			if removedPlr == plr then
				stopSecuring()
				service.Debris:AddItem(holder, 0)
			end
		end)

		secure7 = holder.AttributeChanged:Connect(function(attr)
			local attrVal = holder:GetAttribute(attr)

			if attr == "VerifyId" then
				client.tamperedFolder = true
				client.tamperedFolderReason = "Verify Id was tampered"
				stopSecuring()
				--kill("Client holder was tampered")
				service.Debris:AddItem(holder, 0)
			end
		end)

		for i, desc in ipairs(folderContents) do
			if desc ~= holder then
				local lockArchivable = false
				desc.Archivable = lockArchivable
				table.insert(
					secureCheck_Cons,
					desc:GetPropertyChangedSignal("Archivable"):Connect(function()
						desc.Archivable = lockArchivable
						--client.tamperedFolder = true
						--client.tamperedFolderReason = "Archivable property from object "..tostring(attrName).." was maliciously changed"
						----warn("Tampered remote")
						--stopSecuring()
						--service.Debris:AddItem(holder, 0)
					end)
				)
				table.insert(
					secureCheck_Cons,
					desc.AttributeChanged:Connect(function(attrName)
						client.tamperedFolder = true
						client.tamperedFolderReason = "Attribute "
							.. tostring(attrName)
							.. " from object "
							.. desc:GetFullName()
							.. " was tampered"
						--warn("Tampered remote")
						stopSecuring()
						service.Debris:AddItem(holder, 0)
					end)
				)
			end
		end

		--local ignoreChangeTypes = {
		--	IsLoaded = true;
		--	TimeLength = true;
		--}
		--for i,desc in pairs(folderContents) do
		--	local oldParent = desc.Parent
		--	table.insert(secureCheck_Cons, desc.Changed:Connect(function(changeType)
		--		if changeType == "Parent" then
		--			local newParent = desc.Parent
		--			if oldParent ~= newParent then
		--				kill("Tampering with client folder ("..desc.Name.." changed parent)")
		--				server.Events.securityCheck:fire("TamperedClient", plr, "FileChanged", desc, "Parent", newParent)
		--			end
		--		elseif not ignoreChangeTypes[changeType] then
		--			kill("Tampering with client folder ("..desc.Name.." "..tostring(changeType).." changed)")
		--			server.Events.securityCheck:fire("TamperedClient", plr, "FileChanged", desc, changeType, tostring(desc[changeType]))
		--		end
		--	end))
		--end

		local playerGui = plr:FindFirstChildOfClass "PlayerGui"

		if not playerGui then
			local guiAdded = server.Signal.new()

			local childAdded
			childAdded = plr.ChildAdded:connect(function(child)
				if child:IsA "PlayerGui" then
					childAdded:Disconnect()
					guiAdded:fire(child)
				end
			end)

			guiAdded:connectOnce(function(gui) holder.Parent = gui end)
		else
			holder.Parent = playerGui
		end

		--client.verified = server
	end
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

function utility:readRateInPlayerData(
	rateLimit: {
		DataId: string,

		Rates: number,
		Reset: number,

		ThrottleEnabled: boolean?,
		ThrottleReset: number?,
		ThrottleMax: number?,
	},
	playerDataRateLimits: {
		[string]: {
			DataMaxRates: number,
			DataMaxRatesReset: number,

			Rate: number,
			Throttle: number,
			LastUpdated: number,
			LastThrottled: number?,
		},
	}
)
end

function utility:checkRateInPlayerData(
	rateLimit: {
		DataId: string,

		Rates: number,
		Reset: number,

		ThrottleEnabled: boolean?,
		ThrottleReset: number?,
		ThrottleMax: number?,
	},
	playerDataRateLimits: {
		[string]: {
			DataMaxRates: number,
			DataMaxRatesReset: number,

			Rate: number,
			Throttle: number,
			LastUpdated: number,
			LastThrottled: number?,
		},
	},
	deferCheck: boolean?,
	ignoreRateDataCleanup: boolean?
)
	assert(type(rateLimit.DataId) == "string" and #rateLimit.DataId > 0, `Rate Limit Id must be supplied in string`)

	local function doCheckRate()
		local hashedRateLimitId = hashLib.sha1(rateLimit.DataId)

		local maxRate = math.abs(rateLimit.Rates) -- Max requests per traffic
		local resetInterval = math.floor(math.abs(rateLimit.Reset or 1)) -- Interval seconds since the cache last updated to reset

		local rateExceeded = rateLimit.Exceeded or rateLimit.exceeded
		local ratePassed = rateLimit.Passed or rateLimit.passed

		local canThrottle = rateLimit.ThrottleEnabled
		local throttleReset = rateLimit.ThrottleReset
		local throttleMax = math.floor(math.abs(rateLimit.ThrottleMax or 1))

		local resetOsTime

		-- Check cache
		local nowOs = DateTimeNow().UnixTimestampMillis
		local rateCache: {
			DataMaxRates: number,
			DataMaxRatesReset: number,

			Rate: number,
			Throttle: number,
			LastUpdated: number,
			LastThrottled: number?,
		} | nil =
			playerDataRateLimits[hashedRateLimitId]
		
		if not rateCache then
			rateCache = {
				Rate = 0,
				--DataMaxRates = maxRate;
				--DataMaxRatesReset = resetInterval;
				Throttle = 0,
				LastUpdated = nowOs,
				LastThrottled = nil,
			}

			resetOsTime = nowOs + resetInterval

			playerDataRateLimits[hashedRateLimitId] = rateCache
		end

		rateCache.DataMaxRates = maxRate
		rateCache.DataMaxRatesReset = resetInterval

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

		if rateExceeded and not ratePass then rateExceeded:Fire(`PLAYERDATA`, rateCache.Rate, maxRate) end

		if ratePassed and ratePass then ratePassed:Fire(`PLAYERDATA`, rateCache.Rate, maxRate) end

		-- 5 second delay to clear unused rate limits
		if not ignoreRateDataCleanup then
			local clearPlayerDataThreads = rateLimit.PDataCleanups
			if not clearPlayerDataThreads then
				clearPlayerDataThreads = {}
				rateLimit.PDataCleanups = clearPlayerDataThreads
			end

			if clearPlayerDataThreads[playerDataRateLimits] then
				if coroutine.status(clearPlayerDataThreads[playerDataRateLimits]) == "suspended" then
					task.cancel(clearPlayerDataThreads[playerDataRateLimits])
				end
				clearPlayerDataThreads[playerDataRateLimits] = nil
			end

			local clearListThread
			clearListThread = task.delay(5, function()
				if clearPlayerDataThreads[playerDataRateLimits] == clearListThread then
					local currentOs = DateTimeNow().UnixTimestampMillis
					local didUpdate = false

					for i, rateData in playerDataRateLimits do
						if type(rateData) == "table" then
							local DataMaxRates = rateData.DataMaxRates
							local DataMaxRatesReset = rateData.DataMaxRatesReset

							local rateLastUpdatedDuration = currentOs - rateData.LastUpdated
							local didRateReset = rateLastUpdatedDuration <= DataMaxRatesReset

							-- Remove the rate limit data if it's been 30 seconds or more after the reset
							if didRateReset and rateLastUpdatedDuration >= DataMaxRatesReset + 30 then
								playerDataRateLimits[i] = nil
								didUpdate = true
							end
						end
					end

					clearPlayerDataThreads[playerDataRateLimits] = nil

					if didUpdate then
						warn "Cleared unnecessary rate limit data"

						if playerDataRateLimits._reviveIfDead then playerDataRateLimits._reviveIfDead() end
					end
				end
			end)

			clearPlayerDataThreads[playerDataRateLimits] = clearListThread
		end

		return ratePass, didThrottle, canThrottle, rateCache.Rate, maxRate, throttleResetOs, resetOsTime
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

function utility:getMainSound(createIfNotAdded: boolean): Sound
	local soundName = server.soundName
	local mainSound = utility.mainSound
	local soundData = utility.soundData

	if (not mainSound and createIfNotAdded) or (mainSound and mainSound.Parent ~= workspace) then
		if mainSound then
			service.Debris:AddItem(mainSound, 0)

			if soundData then
				for i, event in pairs(soundData.events) do
					if event.Disconnect then event:Disconnect() end

					soundData.events[i] = nil
				end
			end
		end

		if not soundData then
			soundData = {
				stopped = server.Signal.new(),
				paused = server.Signal.new(),
				resumed = server.Signal.new(),
				played = server.Signal.new(),
				ended = server.Signal.new(),
				volChanged = server.Signal.new(),
				destroyed = server.Signal.new(),

				volume = 0.5,
				pitch = 1,

				changePitch = function(self, newPitch)
					self.pitch = newPitch

					local soundObj = self:getObject()
					if soundObj then soundObj.PlaybackSpeed = newPitch end
				end,

				changeVolume = function(self, newVolume)
					newVolume = math.clamp(newVolume or 0, 0, 4)
					self.volume = newVolume

					local soundObj = self:getObject()
					if soundObj then soundObj.Volume = newVolume end
				end,

				stop = function()
					local soundObj = utility.mainSound

					if soundObj then soundObj:Stop() end
				end,

				resume = function()
					local soundObj = utility.mainSound

					if soundObj then soundObj:Resume() end
				end,

				pause = function()
					local soundObj = utility.mainSound

					if soundObj then soundObj:Pause() end
				end,

				play = function()
					local soundObj = utility.mainSound

					if soundObj then soundObj:Play() end
				end,

				getObject = function() return utility.mainSound end,

				events = {},
			}

			utility.soundData = soundData
		end

		mainSound = service.New("Sound", {
			Name = server.soundName,
			Archivable = false,
			Parent = workspace,
			Volume = soundData.volume,
			PlaybackSpeed = soundData.pitch,
		})

		utility.mainSound = mainSound

		table.insert(soundData.events, mainSound.Ended:Connect(function(...) soundData.ended:fire(...) end))

		table.insert(soundData.events, mainSound.Paused:Connect(function(...) soundData.paused:fire(...) end))

		table.insert(soundData.events, mainSound.Played:Connect(function(...) soundData.played:fire(...) end))

		table.insert(soundData.events, mainSound.Resumed:Connect(function(...) soundData.resumed:fire(...) end))

		table.insert(soundData.events, mainSound.Stopped:Connect(function(...) soundData.stopped:fire(...) end))

		table.insert(
			soundData.events,
			mainSound:GetPropertyChangedSignal("Volume"):Connect(function(...)
				local curVolume = mainSound.Volume

				curVolume = math.clamp(curVolume, 0, 4)
				if mainSound.Volume ~= curVolume then
					mainSound.Volume = curVolume
				else
					soundData.volChanged:fire(curVolume)
				end
			end)
		)

		table.insert(
			soundData.events,
			mainSound:GetPropertyChangedSignal("Parent"):Connect(function()
				local curParent = mainSound.Parent

				if curParent == nil then
					soundData.destroyed:fire()

					for i, event in pairs(soundData.events) do
						if event.Disconnect then event:Disconnect() end

						soundData.events[i] = nil
					end
				end
			end)
		)
	end

	return mainSound, soundData
end

function utility:isMuted(playerName: string): boolean
	local mainChannel = (server.chatService and server.chatService:GetChannel "All")
	local playerId = service.playerIdFromName(playerName) or 0

	local existingPlr = service.getPlayer(playerName)
	if existingPlr then
		local parsed = server.Parser:apifyPlayer(existingPlr)
		if parsed:getVar "MuteChat" then return true end
	end

	return variables.mutelist[playerId] or (mainChannel and mainChannel:IsSpeakerMuted(playerName)) or false
end

function utility:isDeafened(playerName: string): boolean
	local playerId = service.playerIdFromName(playerName) or 0

	return variables.deaflist[playerId]
end

function utility:mutePlayer(playerName: string, durationInSeconds: number?, silent: boolean?)
	local playerId = service.playerIdFromName(playerName)

	if not self:isMuted(playerName) and not self:isDeafened(playerName) then
		local mainChannel = (server.chatService and server.chatService:GetChannel "All")
		local playerId = service.playerIdFromName(playerName) or 0

		if mainChannel then
			mainChannel:MuteSpeaker(playerName, nil, durationInSeconds)

			if not silent then
				local speaker = (server.chatService and server.chatService:GetSpeaker(playerName))

				if speaker then
					speaker:SendSystemMessage("You have been muted", "All", {
						ChatColor = Color3.fromRGB(62, 62, 62),
						Font = Enum.Font.SourceSansItalic,
					})
				end
			end
		end

		local parsedPlayer = server.Parser:apifyPlayer(service.getPlayer(playerName))
		if parsedPlayer then parsedPlayer:sendData("SetCore", "ChatBarDisabled", true) end

		variables.mutelist[playerId] = true
	end
end

function utility:deafenPlayer(playerName: string, duration: duration?)
	if not self:isDeafened(playerName) then
		local playerId = service.playerIdFromName(playerName) or 0

		self:mutePlayer(playerName, duration)

		local parsedPlayer = server.Parser:apifyPlayer(service.getPlayer(playerName))
		if parsedPlayer then parsedPlayer:sendData("SetCoreGuiEnabled", Enum.CoreGuiType.Chat, false) end

		variables.deaflist[playerId] = true
	end
end

function utility:unmutePlayer(playerName: string, silent: boolean?): boolean
	if self:isMuted(playerName) then
		local mainChannel = (server.chatService and server.chatService:GetChannel "All")
		local playerId = service.playerIdFromName(playerName) or 0

		if mainChannel then
			pcall(mainChannel.UnmuteSpeaker, mainChannel, playerName)
			--mainChannel:UnmuteSpeaker(playerName)
		end

		local parsedPlayer = server.Parser:apifyPlayer(service.getPlayer(playerName))
		if parsedPlayer then
			parsedPlayer:sendData("SetCore", "ChatBarDisabled", false)

			local pData = parsedPlayer:getPData()
			if pData.serverData.ToggleMuteOnAFK then pData.serverData.ToggleMuteOnAFK = false end
		end

		if variables.deaflist[playerId] then
			if parsedPlayer then parsedPlayer:sendData("SetCoreGuiEnabled", Enum.CoreGuiType.Chat, true) end

			variables.deaflist[playerId] = false
		end

		variables.mutelist[playerId] = false
		return true
	else
		return false
	end
end

function utility:makeMapBackup(
	slotName: string,
	slotInd: number,
	exceptions: { [any]: any },
	dataTab: { [any]: any }
): { [any]: any }
	dataTab = dataTab or variables.mapBackups

	local backups: { [any]: any } = dataTab.backups
		or (function()
			local tab = {}
			dataTab.backups = tab
			return tab
		end)()

	local newIndex = slotInd or #backups + 1
	local exceptions = (type(exceptions) == "table" and exceptions) or {}

	local ignoreCharacters = exceptions.ignoreChars

	if not (dataTab.loadingMap or dataTab.backingUpMap) then
		dataTab.backingUpMap = true

		local children = {}
		local descendants = {}
		local backupData = (function()
			for i, data in pairs(backups) do
				if data.name == slotName or i == slotInd then return data end
			end
		end)() or {
			name = slotName or service.getRandom(),
			children = children,
			descendants = descendants,

			lastLoad = nil,
			lastSave = nil,
			created = os.clock(),
			createdOs = os.time(),
		}

		local function cloneObject(obj)
			local clone = obj:Clone()

			if clone then
				return clone
			else
				obj.Archivable = true
				clone = obj:Clone()
				obj.Archivable = false
				return clone
			end
		end

		-- Clone workspace
		for i, child in pairs(workspace:GetChildren()) do
			if not child:IsA "Terrain" then
				if child:IsA "Model" and ignoreCharacters then
					local playerFromChild = service.Players:GetPlayerFromCharacter(child)

					if playerFromChild then continue end
				end

				local clone = cloneObject(child)

				if clone then table.insert(children, clone) end
			end
		end

		-- Count descendants
		for i, child in pairs(children) do
			table.insert(descendants, child)

			for d, desc in pairs(child:GetDescendants()) do
				table.insert(descendants, desc)
			end
		end

		backups[newIndex] = backupData
		backupData.lastSave = os.time()

		coroutine.wrap(function() dataTab.backingUpMap = false end)()

		return backupData
	end
end

function utility:loadMapBackup(
	slotName: string,
	slotInd: number,
	exceptions: { [any]: any },
	dataTab: { [any]: any },
	savedBackup: { [any]: any }?
)
	dataTab = dataTab or variables.mapBackups
	slotInd = slotInd or #(dataTab.backups or {})

	local backups = dataTab.backups or (function()
		local tab = {}
		dataTab.backups = tab
		return tab
	end)()

	local backupData = savedBackup
		or (function()
			for ind, backup in pairs(backups) do
				if slotInd and slotInd == ind then
					return backup
				elseif slotName and slotName == backup.name then
					return backup
				end
			end
		end)()

	local exceptions = (type(exceptions) == "table" and exceptions) or {}
	local ignoreChars = exceptions.ignoreChars

	if not (self.loadingMap or dataTab.loadingMap or dataTab.backingUpMap) and backupData then
		dataTab.loadingMap = true
		self.loadingMap = true

		-- Freeze player characters
		if not ignoreChars then
			for i, plr in pairs(service.getPlayers()) do
				local char = plr.Character

				if char then
					for d, desc in pairs(char:GetDescendants()) do
						if desc:IsA "BasePart" then desc.Anchored = true end
					end
				end
			end
		end

		self:purgeMap()

		for i, child in pairs(backupData.children) do
			local clone = child:Clone()

			if clone then
				clone.Parent = workspace
				service.RunService.Heartbeat:Wait()
			end
		end

		-- UnFreeze player characters
		if not ignoreChars then
			for i, plr in pairs(service.getPlayers()) do
				local char = plr.Character

				if char then
					for d, desc in pairs(char:GetDescendants()) do
						if desc:IsA "BasePart" then desc.Anchored = false end
					end
				end
			end
		end

		dataTab.loadingMap = false
		self.loadingMap = false

		return true
	end
end

function utility:purgeMap()
	if not self.purgingMap then
		self.purgingMap = true

		local workSChildren = workspace:GetChildren()
		local workSDescs = workspace:GetDescendants()

		-- Remove terrain from descendants
		for i, desc in pairs(workSChildren) do
			if desc:IsA "Terrain" then table.remove(workSChildren, i) end
		end

		--for i,desc in pairs(workSDescs) do
		--	if desc:IsA"Terrain" and not desc:IsDescendantOf(workspace:FindFirstChild()) then
		--		table.remove(workSDescs, i)
		--	end
		--end

		-- Ignore players
		for i, plr in pairs(service.getPlayers()) do
			local char = plr.Character

			if char then
				local charFromChildren = table.find(workSChildren, char)
				local charFromDescs = table.find(workSDescs, char)

				if charFromChildren then table.remove(workSChildren, charFromChildren) end

				if charFromDescs then table.remove(workSDescs, charFromDescs) end

				for d, desc in pairs(char:GetDescendants()) do
					local descFromChildren = table.find(workSChildren, desc)
					local descFromDescs = table.find(workSDescs, desc)

					if descFromChildren then table.remove(workSChildren, descFromChildren) end

					if descFromDescs then table.remove(workSDescs, descFromDescs) end
				end
			end
		end

		for i, child in pairs(workSChildren) do
			service.Debris:AddItem(child, 0)
			service.RunService.Heartbeat:Wait()
		end

		for i, desc in pairs(workSDescs) do
			if desc:IsDescendantOf(workspace) then
				service.Debris:AddItem(desc, 0)
				service.RunService.Heartbeat:Wait()
			end
		end

		self.purgingMap = false
		self.purgedMap:fire()
	end
end

utility.PlayerContainment = {}

function utility:jailPlayer(player: Player | ParsedPlayer?): boolean
	local jailIndex = tostring(player.UserId)

	if not variables.jailedPlayers[jailIndex] then
		local loopCheckInd = "_JAIL-" .. service.getRandom(20)
		local jailEventHandler = Signal:createHandler()


		local jailInfo = {
			active = true,

			started = tick(),
			items = {},
			expireOs = nil,
			loopCheckInd = loopCheckInd,

			eventHandler = jailEventHandler,

			freed = jailEventHandler.new(),
			refreshed = jailEventHandler.new(),
			restrained = jailEventHandler.new(),
			suspectLeft = jailEventHandler.new(),
			suspectJoined = jailEventHandler.new(),

			suspectActive = true,
			suspectId = player.UserId,

			_playerCharacterAdded = nil,
			_playerAddedListener = nil,
			_childAddedInCharacter = nil,
		}

		variables.jailedPlayers[jailIndex] = jailInfo

		jailInfo._setupProcess = Promise.promisify(function()
			if not utility.PlayerContainment.ContainerFolder then
				utility.PlayerContainment.ContainerFolder = service.New("Folder", {
					Name = "Essential_PlayerContainmentItems",
					Archivable = false,
					Parent = service.ReplicatedStorage,
				})
			end

			local playerContainedItemsFolder = service.New("Folder", {
				Name = player.UserId,
				Archivable = false,
				Parent = utility.PlayerContainment.ContainerFolder,
			})
			jailInfo.containedItemsFolder = playerContainedItemsFolder

			local backpack = player:FindFirstChildOfClass "Backpack"

			if backpack then
				for d, item in pairs(backpack:GetChildren()) do
					if item:IsA "Tool" then
						table.insert(jailInfo.items, item)
						item.Parent = playerContainedItemsFolder
					end
				end
			end
		end)()
			:andThen(function()
				return Promise.new(function(resolve, reject, onCancel)
					local locationCF, characterAddedEvent

					local function characterAdded(character)
						local mainHrp = character
							and (character:FindFirstChild "HumanoidRootPart" or character:FindFirstChild "Torso")

						if not mainHrp or not mainHrp:IsA "BasePart" then
							character:BreakJoints()
						else
							if characterAddedEvent then characterAddedEvent:disconnect() end

							locationCF = mainHrp.CFrame
							resolve(locationCF)
						end
					end

					if
						not onCancel(function()
							if characterAddedEvent then characterAddedEvent:disconnect() end
						end)
					then
						if player.Character then
							characterAdded(player.Character)
							if locationCF then return end
						end

						characterAddedEvent = player.CharacterAdded:connect(characterAdded)
					end
				end):unWrap()
			end)
			:tap(function(locationCF)
				player:sendData("SetCoreGuiEnabled", Enum.CoreGuiType.Backpack, false)

				local mainChar = player.Character
				local currentItem = mainChar and mainChar:FindFirstChildOfClass "Tool"

				if currentItem then
					table.insert(jailInfo.items, currentItem)
					currentItem.Parent = jailInfo.containedItemsFolder
				end

				if player:FindFirstChildOfClass("Backpack") then
					local backpackChildAdded = jailEventHandler.new()
					backpackChildAdded:linkRbxEvent(player:FindFirstChildOfClass("Backpack").ChildAdded)
					backpackChildAdded:connect(function(child)
						if child:IsA "Tool" then
							if not table.find(jailInfo.items, child) then
								table.insert(jailInfo.items, child);
							end
							task.delay(0.5, function() child.Parent = jailInfo.containedItemsFolder end)
						end
					end)
					
					jailInfo.backpackChildAdded = backpackChildAdded
				end

				local function characterAdded(newChar)
					if jailInfo._childAddedInCharacter then
						jailInfo._childAddedInCharacter:Disconnect()
						jailInfo._childAddedInCharacter = nil
					end

					jailInfo._childAddedInCharacter = newChar.ChildAdded:Connect(function(child)
						if child:IsA "Tool" then
							if not table.find(jailInfo.items, child) then
								table.insert(jailInfo.items, child);
							end
							task.delay(0.5, function() child.Parent = jailInfo.containedItemsFolder end)
						end
					end)
				end

				jailInfo._playerCharacterAdded = player.CharacterAdded:Connect(characterAdded)

				if mainChar then
					task.defer(characterAdded, mainChar)
				end

				local function makeExile()
					if jailInfo.active then
						if jailInfo.exileInfo then
							local oldInfo = jailInfo.exileInfo

							oldInfo.propertyChanged:Disconnect()
							jailInfo.exileInfo = nil
						end

						if jailInfo.exileBox then service.Delete(jailInfo.exileBox, 1) end

						local exileInfo = {
							created = os.time(),
						}

						local exileBox = server.Assets.ExileBox:Clone()
						exileBox.Name = "_JAIL-" .. service.getRandom()
						exileBox.CanTouch = false
						exileBox.CanCollide = jailInfo.suspectActive
						exileBox.CFrame = locationCF
						exileBox.Archivable = false
						exileBox.Locked = true
						exileBox.Parent = workspace

						local exileSelection: SelectionBox = exileBox:FindFirstChildOfClass "SelectionBox"
						exileSelection.Transparency = if jailInfo.suspectActive then 0 else 0.9
						exileInfo.selection = exileSelection

						local checkProperties = {
							"CanTouch",
							"Transparency",
							"CFrame",
							"Archivable",
							"Locked",
							"CanCollide",
							"Anchored",
							"Parent",
						}
						local savedProperties = {}

						for i, checkProp in pairs(checkProperties) do
							savedProperties[checkProp] = exileBox[checkProp]
						end

						exileInfo.propertyChanged = exileBox.Changed:Connect(function(prop)
							if table.find(checkProperties, prop) and savedProperties[prop] ~= exileBox[prop] then
								makeExile()
								exileBox[prop] = savedProperties[prop]
							end
						end)

						exileInfo._object = exileBox

						jailInfo.exileBox = exileBox
						jailInfo.exileInfo = exileInfo
						jailInfo.refreshed:fire(exileInfo)
					end
				end

				local function setupPlayerAdded(playerWhoJoined)
					if playerWhoJoined.UserId == jailInfo.suspectId then
						jailInfo.suspectActive = true
						jailInfo.suspectJoined:fire(playerWhoJoined)

						if jailInfo.active and jailInfo.exileInfo then
							jailInfo.exileInfo.selection.Transparency = 0
							jailInfo.exileBox.CanCollide = true
						end

						if jailInfo.disconnectCheck then
							jailInfo.disconnectCheck:disconnect()
							jailInfo.disconnectCheck = nil
						end

						jailInfo.disconnectCheck = playerWhoJoined.disconnected:connectOnce(function()
							jailInfo.suspectActive = false
							jailInfo.suspectLeft:fire(playerWhoJoined)

							pcall(function()
								if jailInfo.active and jailInfo.exileInfo then
									jailInfo.exileInfo.selection.Transparency = 0.9
									jailInfo.exileBox.CanCollide = false
								end
							end)
						end)
					end
				end

				makeExile()

				jailInfo._playerAddedListener = server.Events.playerAdded:connect(setupPlayerAdded)
				setupPlayerAdded(player)
			end)
			:andThen(function(locationCF)
				service.loopTask(loopCheckInd, 0.5, function()
					local inGameTarget = service.getPlayer(player.UserId)

					if inGameTarget then
						local curCharacter = inGameTarget.Character
						local curHrp = curCharacter
							and (curCharacter:FindFirstChild "HumanoidRootPart" or curCharacter:FindFirstChild "Torso")

						if curCharacter and not curHrp then
							curCharacter:BreakJoints()
						elseif curCharacter and curHrp then
							local maxDistance = 3
							if (curHrp.Position - locationCF.Position).magnitude > maxDistance then
								jailInfo.restrained:fire()
								curHrp.CFrame = locationCF

								if (curHrp.Position - locationCF.Position).magnitude > maxDistance then
									curCharacter:BreakJoints()
								end
							end
						end
					end
				end)
			end)

		return jailInfo
	end

	return variables.jailedPlayers[jailIndex]
end

function utility:unJailPlayer(player: { [any]: any }?, fakePlayer: boolean): boolean
	local jailIndex = tostring(player.UserId)
	--local jailInfo = {
	--	active = true;

	--	started = os.time();
	--	items = {};
	--	expireOs = nil;
	--	loopCheckInd = loopCheckInd;

	--	freed = Signal.new();
	--	refreshed = Signal.new();
	--	restrained = Signal.new();
	--	suspectLeft = Signal.new();
	--	suspectJoined = Signal.new();

	--	suspectId = target.UserId;

	--	_playerCharacterAdded = nil;
	--	_playerAddedListener = nil;
	--	_childAddedInCharacter = nil;
	--}

	if variables.jailedPlayers[jailIndex] then
		local jailInfo = variables.jailedPlayers[jailIndex]

		jailInfo.active = false
		if jailInfo._setupProcess then jailInfo._setupProcess:cancel() end

		if jailInfo._playerAddedListener then jailInfo._playerAddedListener:disconnect() end

		if jailInfo._childAddedInCharacter then jailInfo._childAddedInCharacter:Disconnect() end

		if jailInfo._playerCharacterAdded then jailInfo._playerCharacterAdded:Disconnect() end

		jailInfo.refreshed:disconnect()
		jailInfo.restrained:disconnect()
		jailInfo.suspectJoined:disconnect()
		jailInfo.suspectLeft:disconnect()

		jailInfo.eventHandler:killSignals()

		local exileInfo = jailInfo.exileInfo

		if exileInfo then
			exileInfo.propertyChanged:Disconnect()

			if exileInfo._object then service.Delete(exileInfo._object, 0.5) end
		end

		local backpack = player:FindFirstChildOfClass "Backpack"

		if backpack then
			local failedItems = 0

			Promise.each(jailInfo.items, function(item: Tool, index)
				return Promise.promisify(function() item.Parent = backpack end)():catch(function(err)
					failedItems += 1
				end) --// Catch silent error
			end)
				:andThen(function()
					if failedItems > 0 then
						player:makeUI("NotificationV2", {
							title = "Jail Management Error",
							desc = `Unfortunately, {failedItems} item(s) didn't safely return to your backpack due to one of the following reasons:\n- Permanently destroyed\n- Roblox Locked`,
						})
					end
				end)
				:finally(function()
					if jailInfo.containedItemsFolder then service.Delete(jailInfo.containedItemsFolder, 1) end
				end)
		end

		service.stopLoop(jailInfo.loopCheckInd)
		jailInfo.freed:fire()

		player:sendData("SetCoreGuiEnabled", Enum.CoreGuiType.Backpack, true)

		variables.jailedPlayers[jailIndex] = nil
		return true
	else
		return false
	end
end

function utility:createClone(character: Model): Model
	local humanoid = character:FindFirstChildOfClass "Humanoid"

	if humanoid then
		local clone = character:Clone()

		if not clone then
			character.Archivable = true
			clone = character:Clone()
			character.Archivable = false
		end

		if clone then
			local specialChar = clone:FindFirstChild "Chest" and true
			local clHumanoid = clone:FindFirstChildOfClass "Humanoid"

			if clHumanoid then
				--clHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

				for a, b in pairs(clone:GetDescendants()) do
					--if b:IsA("Humanoid") then
					--	b.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					if b:IsA "BillboardGui" then
						b:Destroy()
					elseif b:IsA "Weld" and b.Part1 ~= nil then
						b.Part0 = b.Parent
						if clone:FindFirstChild(b.Part1.Name) then
							b.Part1 = clone[b.Part1.Name]
						elseif not specialChar then
							b:Destroy()
						end
					end
				end

				clone.Parent = workspace

				local tracks = {}
				local desc = humanoid:GetAppliedDescription()
				local animate = clone:FindFirstChild "Animate"
				if animate then
					for i, v in pairs(clone.Animate:GetChildren()) do
						local anim = v:GetChildren()[1]
						if anim then
							--anim.Parent = clone
							tracks[v.Name] = clHumanoid:LoadAnimation(anim)
						end
					end
					tracks.idle:Play()
				end

				return clone, tracks
			end

			return clone
		end
	end
end

function utility:isMutedByMOA(player: ParsedPlayer) --// Is Muted by Mute On Afk
	local sData = player:getPData().serverData
	return sData.ToggleMuteOnAFK and utility:isMuted(player.Name) or false
end

function utility:toggleMuteOnAfk(player: ParsedPlayer, state: boolean)
	local sData = player:getPData().serverData
	if state == nil then state = not sData.ToggleMuteOnAFK end

	if state then
		if not utility:isMuted(player.Name) and not sData.ToggleMuteOnAFK then
			server.Events.playerMuteOnAfkStatusChanged:fire(player, true)
			sData.ToggleMuteOnAFK = true
			utility:mutePlayer(player.Name, nil, true)
		end
	else
		if sData.ToggleMuteOnAFK then
			server.Events.playerMuteOnAfkStatusChanged:fire(player, false)
			sData.ToggleMuteOnAFK = false
			utility:unmutePlayer(player.Name, true)
		end
	end
end

-- RESERVED SERVER FUNCTIONS

function utility:createReserveServer(publicName: string?, creatorId: number?, createOpts: {}?)
	createOpts = createOpts or {}

	local Datastore = server.Datastore
	local reserveListName = variables.serverCreationSettings.reserveListName
	local reservedAccessId, reservedServerId = service.TeleportService:ReserveServer(game.PlaceId)

	local serverDetails = {
		creatorId = creatorId or 0,
		serverAccessId = reservedAccessId,
		serverId = reservedServerId,
		created = os.time(),
	}

	local serverProfile = {
		closed = false,
		adminLock = createOpts.adminLock or false,
		inviteOnly = createOpts.inviteOnly or false,
		hostOnlyInvite = createOpts.hostOnlyInvite or false,
		hostControls = createOpts.hostControls or false,
		publicJoin = createOpts.publicJoin or false,
		creatorId = creatorId or 0,
		maxPlayers = math.huge,
		details = serverDetails,
		whitelist = {},
		banlist = {},

		temporary = createOpts.temporary or false,
	}

	Datastore.write("PrivateServerProfile", reservedServerId, serverProfile)

	if creatorId then Datastore.addUserIdToData("PrivateServerProfile", reservedServerId, creatorId) end

	if publicName then Datastore.tableUpdate(nil, reserveListName, "Index", publicName, serverDetails) end

	return serverDetails, serverProfile
end

function utility:getReserveServer(privateServerId: string?, publicName: string?)
	local Datastore = server.Datastore
	local reserveListName = variables.serverCreationSettings.reserveListName

	local privateServerProfile = privateServerId and Datastore.read("PrivateServerProfile", privateServerId)
	if not privateServerProfile and publicName then
		local reserveList = Datastore.read(nil, reserveListName)
		if type(reserveList) == "table" then
			local serverDetails = reserveList[publicName]
			if serverDetails then
				privateServerProfile = Datastore.read("PrivateServerProfile", serverDetails.serverId)
			end
		end
	end

	return privateServerProfile
end

function utility:deleteReserveServer(privateServerId: string?, publicName: string?)
	local Datastore = server.Datastore
	local reserveListName = variables.serverCreationSettings.reserveListName

	local privateServerProfile = privateServerId and Datastore.read("PrivateServerProfile", privateServerId)
	if not privateServerProfile and publicName then
		local reserveList = Datastore.read(nil, reserveListName)
		if type(reserveList) == "table" then
			local serverDetails = reserveList[publicName]
			if serverDetails then
				Datastore.tableUpdate(nil, reserveListName, "Index", publicName, nil)
				Datastore.tableRemove(nil, reserveListName, "value", privateServerProfile.details)
				server.Cross.sendToSpecificServers(
					{ serverDetails.serverId },
					"Shutdown",
					"Private server was deleted."
				)
				Datastore.remove("PrivateServerProfile", serverDetails.serverId)
				return true
			end
		end

		return false
	elseif privateServerProfile then
		Datastore.tableRemove(nil, reserveListName, "value", privateServerProfile.details)
		Datastore.remove("PrivateServerProfile", privateServerId)

		server.Cross.sendToSpecificServers(
			{ privateServerProfile.details.serverId },
			"Shutdown",
			"Private server was deleted."
		)

		return true
	else
		return false
	end
end

function utility:addWhitelistUserToReserveServer(publicName: string, userId: number)
	local Datastore = server.Datastore
	local reserveListName = variables.serverCreationSettings.reserveListName
	local reserveData = utility:getReserveServer(nil, publicName)

	if reserveData then
		local players = service.mergeTables(true, { reserveData.creatorId }, reserveData.whitelist)
		if
			not table.find(players, userId)
			and #reserveData.whitelist + 1 <= variables.serverCreationSettings.reserveMaxWhitelistsAndBlacklists
		then
			Datastore.tableUpdate(nil, reserveListName, "tableAdd", "whitelist", userId)
			return true
		end
	end

	return false
end

function utility:removeWhitelistUserFromReserveServer(publicName: string, userId: number)
	local Datastore = server.Datastore
	local reserveListName = variables.serverCreationSettings.reserveListName
	local reserveData = utility:getReserveServer(nil, publicName)

	if reserveData then
		local players = service.mergeTables(true, { reserveData.creatorId }, reserveData.whitelist)
		if table.find(players, userId) then
			Datastore.tableUpdate(nil, reserveListName, "tableRemove", "whitelist", userId)
			if not reserveData.closed and not reserveData.publicJoin then
				server.Cross.sendToSpecificServers(
					{ reserveData.details.serverId },
					"KickPlayers",
					{ userId },
					"You've been removed from the reserved server"
				)
			end

			return true
		end
	end

	return false
end

function utility:addBlacklistUserToReserveServer(publicName: string, userId: number)
	local Datastore = server.Datastore
	local reserveListName = variables.serverCreationSettings.reserveListName
	local reserveData = utility:getReserveServer(nil, publicName)

	if reserveData then
		local players = service.mergeTables(true, { reserveData.creatorId }, reserveData.banlist)
		if
			not table.find(players, userId)
			and #reserveData.banlist + 1 <= variables.serverCreationSettings.reserveMaxWhitelistsAndBlacklists
		then
			Datastore.tableUpdate(nil, reserveListName, "tableAdd", "banlist", userId)
			if not reserveData.closed then
				server.Cross.sendToSpecificServers(
					{ reserveData.details.serverId },
					"KickPlayers",
					{ userId },
					"You've been blacklisted from the reserved server"
				)
			end
			return true
		end
	end

	return false
end

function utility:removeBlacklistUserFromReserveServer(publicName: string, userId: number)
	local Datastore = server.Datastore
	local reserveListName = variables.serverCreationSettings.reserveListName
	local reserveData = utility:getReserveServer(nil, publicName)

	if reserveData then
		local players = service.mergeTables(true, { reserveData.creatorId }, reserveData.banlist)
		if table.find(players, userId) then
			Datastore.tableUpdate(nil, reserveListName, "tableRemove", "banlist", userId)

			return true
		end
	end

	return false
end

-- ENCRYPT FUNCTIONS
utility.teleportCompressConfig = {
	level = 3,
	strategy = "dynamic",
}

function utility:encryptDataForTeleport(userId: number, data: {}, dataName: string?): {}
	dataName = dataName or "data"
	
	local base64 = server.Base64
	local luaParser = server.LuaParser
	local tulirAES = server.TulirAES
	local compression = server.Compression

	local encryptKey = tostring(userId) .. "_TeleportData-" .. dataName
	local encryptedValue1 = luaParser.Encode { data }
	local encryptedValue2 = tulirAES.encrypt(encryptKey, encryptedValue1)
	local compressedValue = compression.Deflate.Compress(encryptedValue2, self.teleportCompressConfig)
	local encryptedValue3 = base64.encode(compressedValue)

	return encryptedValue3
end

function utility:decryptDataForTeleport(userId: number, encryptedData: string, dataName: string?): {}
	dataName = dataName or "data"
	
	local base64 = server.Base64
	local luaParser = server.LuaParser
	local tulirAES = server.TulirAES
	local compression = server.Compression

	local encryptKey = tostring(userId) .. "_TeleportData-" ..  dataName
	local decryptValue1 = base64.decode(encryptedData)
	local decompressedValue = compression.Deflate.Decompress(decryptValue1, self.teleportCompressConfig)
	local decryptValue2 = tulirAES.decrypt(encryptKey, decompressedValue)
	local decryptValue3 = decryptValue2 and luaParser.Decode(decryptValue2)[1]

	return decryptValue3
end

function utility:getVRPlayers()
	local list = {}

	for i, player in service.getPlayers(true) do
		local cliData = server.Core.clients[player]
		if cliData and cliData.deviceType == "VR" then table.insert(list, player) end
	end

	return list
end

-- MESSAGES
utility.Notices = {
	_globalNotices = {},
	_globalMessages = {},
}

function utility.Notices:createGlobalNotice(constructData: {
	priorityLevel: number?,

	title: string,
	description: string,
	actionText: string?,

	timeDuration: number,
	richText: boolean?,
	highPriority: boolean?,

	iconUrl: string?,
	showSoundUrl: string?,
})
	local noticeData = {
		_created = tick(),
		_id = `GlobalNotice_` .. service.getRandom(),

		title = constructData.title,
		description = constructData.description,
		actionText = constructData.actionText or `An important notice from the system`,

		timeDuration = constructData.timeDuration,
		priorityLevel = constructData.priorityLevel,
		highPriority = constructData.highPriority,

		richText = constructData.richText,
		iconUrl = constructData.iconUrl,
		showSoundUrl = constructData.showSoundUrl,
	}

	table.insert(self._globalNotices, noticeData)

	for i, parsedPlayer in service.getPlayers(true) do
		if parsedPlayer:isInGame() and parsedPlayer:isVerified() then
			parsedPlayer:makeUI("NotificationV2", {
				title = noticeData.title,
				description = noticeData.description,
				timeDuration = noticeData.timeDuration,
				priorityLevel = noticeData.priorityLevel,
				highPriority = noticeData.highPriority,

				richText = noticeData.richText,
				iconUrl = noticeData.iconUrl,
				showSoundUrl = noticeData.showSoundUrl,

				handlerId = noticeData._id,
			})
		end
	end

	return noticeData
end

function utility.Notices:clearGlobalNoticeById(noticeId: string)
	for i, globalNotice in self._globalNotices do
		if globalNotice._id == noticeId then
			table.remove(self._globalNotices, i)
			break
		end
	end

	return self
end

function utility.Notices:clearGlobalNotices()
	table.clear(self._globalNotices)

	return self
end

-- INIT; DO NOT TOUCH

function utility.Init(env): boolean
	server = env.server
	service = env.service
	variables = env.variables

	hashLib = server.HashLib
	Promise = server.Promise
	Signal = server.Signal

	utility.purgedMap = env.server.Signal.new()
	return true
end

return utility
