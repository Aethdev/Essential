
return function(envArgs, data: {[any]: any})
	local client = envArgs.client
	local service = envArgs.service
	local variables = envArgs.variables
	
	local Network = client.Network
	local Parser = client.Parser
	local UI = client.UI
	
	local Promise = client.Promise
	
	local dataList: {[any]: any} = data.List
	local title = data.Title or `Untitled List`
	local mainSize = data.MainSize
	local minimumSize = data.MinimumSize
	local maximumSize = data.MaximumSize
	local pageSize: number = data.PageSize or 60
	local pageNumber: number = data.PageNumber
	local pageCreationType: "Auto"|"Fixed"|"None"|nil = data.PageCreationType or "Auto"
	local onRefresh = data.OnRefresh
	local liveUpdate = data.LiveUpdate
	local liveUpdateSessionId = data.LiveUpdateSessionId
	local autoUpdate = data.AutoUpdate
	local autoUpdateListData = data.AutoUpdateListData
	local autoUpdateListArgs = data.AutoUpdateListArgs or {}
	
	local listOfList = variables.listOfList or {}
	variables.listOfList = listOfList
	
	local autoUpdateListCache = variables.autoUpdateListCache or {}
	variables.autoUpdateListCache = autoUpdateListCache
	
	local autoUpdateListDataCache;
	if autoUpdateListData then
		autoUpdateListDataCache = autoUpdateListCache[autoUpdateListData]
		if not autoUpdateListDataCache then
			autoUpdateListDataCache = {}
			autoUpdateListCache[autoUpdateListData] = autoUpdateListDataCache
		end
	end
	
	local containerData = UI.makeElement("Container")
	containerData._object.DisplayOrder = 200
	containerData.parent = service.playerGui

	local containerGuiData = client.UI.register(containerData._object)
	
	local globalListRefreshIndex = autoUpdateListData and `globalListRefreshState_{autoUpdateListData}`
	local globalListRefreshWaitColor = Color3.fromRGB(14, 29, 53)
	local globalListRefreshIdleColor = Color3.fromRGB(255, 255, 255)
	
	local listWindow;
	local function isEntryALogType(entryData: {
		type: string;
	})
		if table.find({"Log", "log"}, entryData.type) then
			return true
		end
	end
	
	local function checkIfTableIsPlain(tab: {[any]: any})
		if #tab > 0 then
			for i, str in tab do
				if type(str) ~= "string" then
					return false
				end
			end
		end
		
		return true
	end
	
	
	local function loadListOnWindow(providedList: {[any]: any})
		assert(type(providedList) == "table", `Missing a list`)
		
		if not listWindow._loading then
			listWindow._loading = true
			listWindow:clearOptions()
			
			local timeNowOs = os.time()
			local nowDateTime = os.date("*t", timeNowOs)
			
			for i, optionData in providedList do
				-- Log type: { type: "log/Log"; title: string; desc: string; titleColor: Color3?, descriptionColor: Color3?, sentOs: number;  }
				local optionDataType = type(optionData)
				
				if optionDataType ~= "table" then
					if optionDataType == "string" then
						optionData = {
							type = "Log";
							title = optionData;
							desc = optionData;
						}
					end
					
					continue
				end
				if isEntryALogType(optionData) then
					if optionData._loaded then continue end
					
					local logSentUnixOs = optionData.sentOs or nil
					local showDateAndTime = data.ShowDateAndTime or optionData.showDateAndTime or (function() -- Advanced timestamp
						local logDateTime = os.date("*t", logSentUnixOs)
						
						return not (logDateTime.year == nowDateTime.year and logDateTime.month == nowDateTime.month
							and logDateTime.day == nowDateTime.day)
					end)()
					
					local isLogPlain = optionData.title==optionData.desc or (optionData.title and not optionData.desc)
					local duplicateLogCount = 0
					-- Check for duplicated logs
					for i, otherOptionData in providedList do
						if otherOptionData ~= optionData and logSentUnixOs == otherOptionData.sentOs and optionData.title == otherOptionData.title
							and optionData.desc == otherOptionData.desc and optionData.label == otherOptionData.label and not otherOptionData._loaded then
							otherOptionData._loaded = true
							duplicateLogCount += 1
						end
					end
					
					listWindow:createOption({
						type = if isLogPlain then "Label" else "Detailed";
						label = `{if duplicateLogCount > 0 then `({1+duplicateLogCount}x) ` else ""}[{Parser:osDate(logSentUnixOs, nil, if showDateAndTime then "longdatetime" else "longtime")}]: {optionData.title}`;
						labelColor = optionData.titleColor;
						description = if not isLogPlain then optionData.desc else nil;
						descriptionColor = optionData.descriptionColor;
						hideSymbol = if not isLogPlain then true else nil;
						richText = optionData.richText;
						specialMarkdownSupported = optionData.specialMarkdownSupported;
						selectable = optionData.selectable;
					})
					
					service.RunService.Heartbeat:Wait()
					
					continue
				end
				
				listWindow:createOption(optionData)
				service.RunService.Heartbeat:Wait()
			end
			
			listWindow._loading = false
		end
	end
	
	local function _onRefresh()
		if onRefresh then
			Promise.promisify(onRefresh)
				:catch(function(err)
					UI.construct("NotificationV2", {
						title = "List Window "..title.." encountered an error while retrieving new list data in onRefresh process.";
						description = `Report this error to the game developer or Essential maintenance team\n` ..
						`<font color='#e84646'>{tostring(err)}</font>`;

						richText = true;
						highPriority = false;
						priorityLevel = UI.PriorityLevels.Error;
					})
				end)
		
			return
		end
		
		if not variables[globalListRefreshIndex] and autoUpdateListData and variables.autoUpdatingNumberOfLists+1 <= variables.maxAutoUpdateLists and not listWindow._loading then
			task.defer(function()
				if not variables[globalListRefreshIndex] and variables.autoUpdatingNumberOfLists+1 <= variables.maxAutoUpdateLists then
					variables[globalListRefreshIndex] = true
					variables.autoUpdatingNumberOfLists += 1
					
					if not listWindow.disallowedClose then
						listWindow:toggleCloseDisplay(false)
					end
					
					for i, otherListWindow in listOfList do
						if otherListWindow ~= listWindow and not otherListWindow.hasManualOnRefresh
							and not otherListWindow._refreshing and otherListWindow.autoUpdateListData == autoUpdateListData
						then
							otherListWindow:toggleRefreshDisplay(false)
							if not otherListWindow.disallowedClose then
								otherListWindow:toggleCloseDisplay(false)
							end
						end
					end
					
					Promise.promisify(Network.get, Network, "GetList", autoUpdateListData, unpack(autoUpdateListArgs))()
						:andThen(function(listLogsData)
							if not listLogsData or type(listLogsData) ~= "table" then
								service.tweenCreate(listWindow.topOptions_Refresh._object, 
									TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
									{
										ImageColor3 = globalListRefreshIdleColor;
									}
								)
							else
								local listOptions = {}
								listWindow:clearOptions()

								task.spawn(loadListOnWindow, listLogsData)

								for i, otherListWindow in listOfList do
									if otherListWindow ~= listWindow and not otherListWindow.hasManualOnRefresh
										and not otherListWindow._refreshing and otherListWindow.autoUpdateListData == autoUpdateListData
									then
										task.spawn(otherListWindow.loadListOnWindow, listLogsData)
									end
								end
							end
						end)
						:andThenCall(Promise.delay, 2)
						:andThen(function()
							for i, otherListWindow in listOfList do
								if otherListWindow ~= listWindow and not otherListWindow.hasManualOnRefresh
									and not otherListWindow._refreshing and otherListWindow.autoUpdateListData == autoUpdateListData
								then
									otherListWindow:toggleRefreshDisplay(true)
									if not listWindow.disallowedClose then
										listWindow:toggleCloseDisplay(true)
									end
								end
							end
						end)
						:catch(function(err)
							UI.construct("NotificationV2", {
								title = "List Window "..title.." encountered an error while retrieving new list data in live update process.";
								description = `Report this error to the game developer or Essential maintenance team\n` ..
									`<font color='#e84646'>{tostring(err)}</font>`;

								richText = true;
								highPriority = false;
								priorityLevel = UI.PriorityLevels.Error;
							})
						end)
						:finally(function(status)
							if not listWindow.disallowedClose then
								listWindow:toggleCloseDisplay(true)
							end

							variables[globalListRefreshIndex] = false
							variables.autoUpdatingNumberOfLists -= 1
						end)
				end
			end)
		end
	end
	
	local _loopIndex;
	local _destroyed;
	local function onDestroy()
		_destroyed = true
		listWindow:clearOptions()
		listWindow:toggleRefreshDisplay(false)
		listWindow.events:killSignals()
		service.Debris:AddItem(listWindow._object, 1)
		
		if _loopIndex then
			service.stopLoop(_loopIndex)
		end
		
		if listWindow.heartbeatEvent then
			listWindow.heartbeatEvent:disconnect()
			listWindow.heartbeatEvent = nil
		end
		
		local windowIndex = table.find(listOfList, listWindow)
		if windowIndex then
			table.remove(listOfList, windowIndex)
		end
	end
	
	listWindow = UI.makeElement("ListWindow", {
		title = title;
		containerData = containerData;
		containerGuiData = containerGuiData;
		allowInputRefresh = if autoUpdateListData or onRefresh then true else false;
		onRefresh = _onRefresh;
		mainSize = mainSize;
		
		refreshCooldown = data.refreshCooldown;
		submitCooldown = data.submitCooldown;
		delayCloseButtonVisibility = data.delayCloseButtonVisibility;
		allowInputSearch = data.allowInputSearch;
		allowInputClose = data.allowInputClose;
		allowInputMinimize = data.allowInputMinimize;
		allowInputSubmit = data.allowInputSubmit;
		draggingEnabled = data.draggingEnabled;
		resizingEnabled = data.resizingEnabled;
		wallsEnabled = data.wallsEnabled;
		fullscreenMode = data.fullscreenMode;
		minimumSize = minimumSize;
		maximumSize = maximumSize;
		pageControlsEnabled = data.pageControlsEnabled;
	})
	
	listWindow.refreshCooldown = 0.5
	listWindow.hasManualOnRefresh = if onRefresh then true else false
	listWindow.autoUpdate = autoUpdate and not liveUpdate
	listWindow.autoUpdateListData = autoUpdateListData
	listWindow.liveUpdate = liveUpdate
	listWindow.liveUpdateSessionId = liveUpdateSessionId
	listWindow.loadListOnWindow = loadListOnWindow
	
	listWindow.disallowedClose = data.allowInputClose == false
	

	if not listWindow.heartbeatEvent then
		local heartbeatEvent = client.Signal.new()
		heartbeatEvent:linkRbxEvent(service.RunService.Heartbeat)
		heartbeatEvent:connect(function()
			local isMinimized = if listWindow.fullscreenMode then false else listWindow.minimizeState
			if isMinimized then return end
			if listWindow.windowModifier.resizeData and listWindow.windowModifier.resizeData._resizeState then return end
			
			listWindow:updatePageCanvasSize()
			listWindow:updatePageContents()
		end)
		listWindow.heartbeatEvent = heartbeatEvent
	end
	
	local initialSetup; initialSetup = Promise.promisify(function()
		if dataList then
			listWindow._refreshing = true
			if not listWindow.disallowedClose then
				listWindow:toggleCloseDisplay(false)
			end

			listWindow:toggleRefreshDisplay(false)
			loadListOnWindow(dataList)
			listWindow._refreshing = false

			if not listWindow.disallowedClose then
				listWindow:toggleCloseDisplay(true)
			end

			listWindow:toggleRefreshDisplay((autoUpdateListData or onRefresh) and true or false)
		end
	end)()
	
	--// Multi-line statement warning makes me want to write like this
	initialSetup = initialSetup:andThen(function()
		if autoUpdate and not liveUpdate and (onRefresh or autoUpdateListData) then
			_loopIndex = `{tick()}-{tostring(autoUpdateListData)}`
			return Promise.delay(5)
				:andThen(function()
					if _destroyed then return end
					service.loopTask(_loopIndex, 5, listWindow.refresh, listWindow)
				end)
		end
	end)
		:catch(function(err)
			listWindow:clearOptions()
			listWindow:createOption({
				type = "Label";
				label = `List Window encountered an error during initialization. Report it to the maintenance team or the in-game developers:`;
				selectable = true;
			})
			listWindow:createOption({
				type = "Label";
				label = `<font color='#d93d3b'>{Parser:filterForRichText(tostring(err))}</font>`;
				selectable = true;
				richText = true;
			})
			listWindow:toggleCloseDisplay(true)
			listWindow:toggleRefreshDisplay(false)
			listWindow._refreshing = false
			listWindow.liveUpdate = false
		end)
		
	listWindow.windowFocused:connect(function()
		local shouldPrioritizeWindow = true;
		local targetWindow;
		
		for i, otherListWindow in listOfList do
			if otherListWindow ~= listWindow and otherListWindow.showState and (otherListWindow.fullscreenMode and not otherListWindow.minimizeState) then
				shouldPrioritizeWindow = false
				targetWindow = otherListWindow
				break
			end
		end
		
		if not shouldPrioritizeWindow and targetWindow then
			targetWindow.containerData._object.DisplayOrder = 201
			listWindow.containerData._object.DisplayOrder = 200
		elseif not targetWindow then
			for i, otherListWindow in listOfList do
				if otherListWindow ~= listWindow then
					otherListWindow.containerData._object.DisplayOrder = 200
					break
				end
			end
			listWindow.containerData._object.DisplayOrder = 201
		end
	end)
	listWindow.windowFocusLost:connect(function()
		listWindow.containerData._object.DisplayOrder = 200
	end)
	listWindow.hidden:connectOnce(onDestroy)
	listWindow:show()
	
	table.insert(listOfList, listWindow)
	return listWindow
end