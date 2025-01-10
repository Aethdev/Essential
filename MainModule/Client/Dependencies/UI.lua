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

	local variables = env.variables
	local getEnv = env.getEnv
	local getRandom = service.getRandom

	local Signal = client.Signal

	local cloneTable = service.cloneTable
	local roundNumber = service.roundNumber

	local uiSignal = cloneTable(Signal)
	uiSignal.__index = uiSignal

	-- Configurable Options
	local setting_guiNameType = "random" -- Supported name types: random, chosen, hide
	local setting_guiChosenName = "" -- Only used if setting "guiNameType" is set to "chosen"
	local setting_guiPriority = math.huge -- Priority level for Essential's guis in PlayerGui

	local elementsFolder = client.Folder.UI.Elements
	local readyElements = {}
	local initElements = {}

	local libraryFolder = client.Folder.UI.Library

	local createdUIs = {}
	local protectedUIs = {}
	local modifiedObjects = {}

	local UI
	local function Init()
		UI = client.UI

		--for i, element in pairs(elementsFolder:GetChildren()) do
		--	if typeof(element) == "Instance" and element:IsA"ModuleScript" then
		--		local ran,ret = pcall(require, element)
		--	end
		--end

		for i, element in pairs(elementsFolder:GetChildren()) do
			local clElement = element:Clone()

			if clElement and element:IsA "ModuleScript" then
				local success, elementData = pcall(require, clElement)

				if not success then
					warn(
						"UI Element "
							.. element.Name
							.. " cannot be loaded due to an unexpected error: "
							.. tostring(elementData)
					)
				else
					local elementName = element.Name
					elementData.Signal = cloneTable(uiSignal)
					elementData.Signal.__index = elementData.Signal

					if type(elementData.Init) == "function" then
						local elementInit = elementData.Init
						local envArgs = getEnv(nil, { script = clElement })
						local scriptEnv = getEnv("EnvLocals", { script = clElement })

						local initSuccess, initErrorResult, errorTrace = service.trackTask(
							"_UI_ELEMENTLOAD-" .. elementName,
							false,
							setfenv(elementInit, scriptEnv),
							envArgs
						)

						if not initSuccess then
							warn(
								"UI Element "
									.. elementName
									.. " init encountered an error: "
									.. tostring(initErrorResult),
								errorTrace
							)
						end

						rawset(elementData, "Init", nil)
					end

					initElements[elementName] = elementData
					readyElements[elementName] = clElement
				end
			end
		end
	end

	client.UI = {
		Init = Init,

		-- For notification priority levels;
		PriorityLevels = table.freeze {
			Error = 5,
		},

		construct = function(guiName, data, dataTheme)
			data = data or {}

			local themeFolder = libraryFolder:FindFirstChild(dataTheme or variables.guiTheme or "Default")

			if themeFolder then
				local guiObject = themeFolder:FindFirstChild(guiName)
					or UI.findConstructByAlias(guiName, dataTheme)
					or UI.findUIWithCategory(guiName, dataTheme)

				if guiObject then
					local set_disabled = guiObject:GetAttribute "Disabled"
					local set_permanent = guiObject:GetAttribute "Permanent"
					local set_maxPlacement = guiObject:GetAttribute "MaxPlacement"

					set_maxPlacement = (type(set_maxPlacement) == "number" and set_maxPlacement) or nil
					set_maxPlacement = (
						set_maxPlacement and math.clamp(math.floor(math.abs(set_maxPlacement)), 0, math.huge)
					) or nil

					local guiCount = #UI.getGuis(guiName)
					local canConstruct = not set_disabled and (not set_maxPlacement or guiCount + 1 <= set_maxPlacement)

					if not set_disabled and canConstruct then
						local guiClone = guiObject:Clone()

						if guiClone:IsA "ModuleScript" then
							local guiReturn = require(guiClone)
							local guiRetType = type(guiReturn)

							if guiRetType == "table" then
								local loadFunc = guiReturn.load or guiReturn.execute or guiReturn.error

								if type(loadFunc) == "function" then
									local envArgs = getEnv(nil, { script = guiClone })
									local scriptEnv = getEnv("EnvLocals", { script = guiClone })
									local loadRets = {
										service.trackTask(
											"_UI_GUI-" .. guiName,
											false,
											setfenv(loadFunc, scriptEnv),
											envArgs,
											data
										),
									}

									if not loadRets[1] then
										warn("UI " .. guiName .. " encountered an error: " .. tostring(loadRets[2]))
									else
										return unpack(loadRets, 2)
									end
								else
									warn("UI " .. guiName .. " doesn't have a loader to construct")
								end
							elseif guiRetType == "function" then
								local envArgs = getEnv(nil, { script = guiClone })
								local scriptEnv = getEnv("EnvLocals", { script = guiClone })
								local loadRets = {
									service.trackTask(
										"_UI_GUI-" .. guiName,
										false,
										setfenv(guiReturn, scriptEnv),
										envArgs,
										data
									),
								}

								if not loadRets[1] then
									warn(
										"UI " .. guiName .. " encountered an error: " .. tostring(loadRets[2]),
										loadRets[3]
									)
								else
									return unpack(loadRets, 2)
								end
							else
								warn("UI " .. guiName .. " doesn't have a loader to construct")
							end
						elseif guiClone:IsA "ScreenGui" or guiClone:IsA "GuiObject" then
							local source = guiClone:FindFirstChild "Source"

							if source and source:IsA "ModuleScript" then
								local container = (
									guiClone:IsA "ScreenGui" and UI.makeElement("Container", { object = guiClone })
								) or UI.makeElement "Container"
								local guiData = UI.register(guiClone, container)
								local playerGui = service.playerGui

								guiData.Source = source
								guiData._container = container

								if not playerGui then
									client.playerGui_Found:connectOnce(function(child)
										playerGui = child
										container.parent = child
									end)
								else
									container.parent = playerGui
								end

								container._object.Enabled = true
								container._object.DisplayOrder = math.abs(tonumber(setting_guiPriority) or 0)
								container._object.Name = (
									setting_guiNameType == "random" and `ESSCU-{service.getRandom()}`
								)
									or (setting_guiNameType == "chosen" and setting_guiChosenName)
									or (setting_guiNameType == "hide" and "\0")

								local sourceRet = require(source)
								local sourceRetType = type(sourceRet)

								if sourceRetType == "function" then
									local envArgs = getEnv(nil, { script = source })
									local scriptEnv = getEnv("EnvLocals", { script = source })
									local loadRets = {
										xpcall(
											setfenv(sourceRet, scriptEnv),
											function(errMsg) warn(errMsg, debug.traceback(nil, 2)) end,
											envArgs,
											data,
											guiData
										),
									}
									--local loadRets = {service.trackTask("_UI_GUI-"..guiName, false, setfenv(sourceRet, scriptEnv), envArgs, data, guiData)}

									if not loadRets[1] then
										warn("UI " .. guiName .. " encountered an error: " .. tostring(loadRets[2]))
									else
										return unpack(loadRets, 2)
									end
								elseif sourceRetType == "table" then
									local loadFunc = sourceRet.load or sourceRet.execute or sourceRet.error

									if type(loadFunc) == "function" then
										local envArgs = getEnv(nil, { script = source })
										local scriptEnv = getEnv("EnvLocals", { script = source })
										local loadRets = {
											service.trackTask(
												"_UI_GUI-" .. guiName,
												false,
												setfenv(loadFunc, scriptEnv),
												envArgs,
												data,
												guiData
											),
										}

										if not loadRets[1] then
											warn("UI " .. guiName .. " encountered an error: " .. tostring(loadRets[2]))
										else
											return unpack(loadRets, 2)
										end
									else
										warn("UI " .. guiName .. " doesn't have a loader to construct")
									end
								else
									warn("UI " .. guiName .. " cannot construct without a proper source")
								end

								source.Name = service.getRandom(20)
							else
								warn("UI " .. guiName .. " cannot construct without a source")
							end
						end
					end
				end
			end
		end,

		getElement = function(elementName)
			local module = readyElements[elementName]

			if not module or not module:IsA "ModuleScript" then
				warn("UI Element " .. elementName .. " doesn't exist or cannot be loaded")
			else
				return initElements[elementName]
			end
		end,

		makeElement = function(elementName, data)
			data = (type(data) == "table" and data) or {}

			local module = readyElements[elementName]

			if not module or not module:IsA "ModuleScript" then
				warn("UI Element " .. elementName .. " doesn't exist or cannot be loaded")
			else
				local ret = initElements[elementName]
				local retType = type(ret)

				if retType == "table" then
					local createFunc = ret.new or ret.New

					if type(createFunc) == "function" then
						local element = setfenv(createFunc, getEnv(nil, { script = module }))(data)

						if element then return element end
					else
						warn(elementName .. ".new doesn't exist. Unable to create the element.")
					end
				elseif retType == "function" then
					return setfenv(ret, getEnv(nil, { script = module }))(data)
				end
			end
		end,

		register = function(gui, name)
			local wrapObj = (typeof(gui) == "Instance" and service.wrap(gui, true)) or gui
			local guiData
			guiData = {
				name = name or "_UNKNOWN-" .. getRandom(),
				index = getRandom(),
				created = os.time(),
				active = false,
				_events = {},

				bindEvent = function(event, func)
					local eventCon = service.rbxEvent(event, func)

					guiData._events[eventCon] = event
					return eventCon
				end,

				unBindEvent = function(event)
					if event then
						for con, conEvent in pairs(guiData._events) do
							if rawequal(conEvent, event) then
								if con.Disconnect then con:Disconnect() end

								guiData._events[con] = nil
							end
						end
					end
				end,

				stopEvents = function()
					for con, conEvent in pairs(guiData._events) do
						if con.Disconnect then con:Disconnect() end

						guiData._events[con] = nil
					end
				end,

				ready = function()
					if not guiData._ready then
						guiData._ready = true
						guiData.active = true

						if guiData._container then guiData._container:show() end

						if guiData.Source then guiData.Source.Parent = nil end

						guiData.readied:fire(true)
					end
				end,

				_ready = false,
				readied = Signal.new(),

				destroy = function()
					guiData.active = false
					service.Debris:AddItem(gui, 0)
					guiData.stopEvents()
					guiData.unRegister()
					guiData.destroyed:fire(true)
				end,

				unRegister = function()
					local uiIndex = table.find(createdUIs, guiData)

					if uiIndex then table.remove(createdUIs, uiIndex) end
				end,

				_Object = wrapObj,
				_object = wrapObj,

				Object = wrapObj,
				object = wrapObj,

				Signal = uiSignal,

				destroyed = Signal.new(),
			}

			guiData.BindEvent = guiData.bindEvent
			guiData.UnBindEvent = guiData.unBindEvent
			guiData.UnRegister = guiData.unRegister
			guiData.Destroy = guiData.destroy
			guiData.Ready = guiData.ready

			table.insert(createdUIs, guiData)
			return guiData
		end,

		getGuis = function(name)
			local results = {}

			for i, guiData in pairs(createdUIs) do
				if not name or guiData.name == name then table.insert(results, guiData) end
			end

			return results
		end,

		getGuiData = function(object)
			local unWrapObj = service.wrap(object)

			if unWrapObj then
				for i, guiData in pairs(createdUIs) do
					if guiData.object and rawequal(guiData.object, unWrapObj) then return guiData end
				end
			end
		end,

		protectUI = function(guiObj, checkedProps, killIfTampered)
			checkedProps = checkedProps or {}

			local savedProps = {}
			local isATextBox = guiObj:IsA "TextBox"
			local guiProxy, proxyMeta = service.newProxyWithMeta({}, true)
			local guiData
			guiData = {
				active = true,
				id = service.getRandom(30),
				checkedProps = checkedProps,
				savedProps = savedProps,

				unProtect = function(self)
					for i, v in pairs(checkedProps) do
						checkedProps[i] = nil
					end

					if self.secure1 then
						self.secure1:Disconnect()
						self.secure1 = nil
					end

					self.active = false
				end,
			}
			local setfenv, getfenv = setfenv, getfenv

			proxyMeta.__index = function(_, prop)
				local chosenProp = (rawequal(prop, "_object") and guiObj) or guiObj[prop]
				local propType = type(chosenProp)

				if propType == "function" then
					return setfenv(function(ignore, ...) return chosenProp(guiObj, ...) end, getfenv(2))
				else
					return chosenProp
				end
			end

			proxyMeta.__newindex = function(_, prop, val)
				if savedProps[prop] then savedProps[prop] = val end

				guiObj[prop] = val
			end

			proxyMeta.__tostring = function() return "ProtectedGUIObj" end

			for prop, val in pairs(checkedProps) do
				savedProps[prop] = guiObj[prop]
			end

			guiData.secure1 = guiObj.Changed:Connect(function(changeType)
				if guiData.active and type(changeType) == "string" then
					if checkedProps[changeType] then
						local oldProp = savedProps[changeType]
						local newProp = guiObj[changeType]

						if oldProp ~= newProp then
							if
								rawequal(changeType, "Text")
								and isATextBox
								and guiObj.TextEditable
								and guiObj:IsFocused()
							then
								return
							end

							if not killIfTampered then
								guiObj[changeType] = oldProp
							else
								client.Disconnect("Tampered Object " .. tostring(guiObj:GetFullName()))
							end
						end
					end
				end
			end)

			return guiProxy, guiData
		end,

		modifyObject = function(objData, guiData)
			if type(objData) == "userdata" and typeof(service.unWrap(objData)) == "Instance" then
				objData = {
					_object = objData,
				}
			elseif typeof(objData) == "Instance" then
				objData = {
					_object = service.wrap(objData),
				}
			else
				guiData = (type(guiData) == "table" and guiData) or {}
			end

			local object = objData._object

			if modifiedObjects[object] then return modifiedObjects[object] end

			local modifyData = {
				active = true,
				_object = objData._object,
				events = {},
				objects = {},
				eventHandler = Signal:createHandler(),
				guiData = guiData,
			}

			if objData.modifier then return objData.modifier end

			function modifyData:bindEvent(event, func)
				if self.active then
					local eventCon = event:Connect(func)
					table.insert(self.events, eventCon)
					return eventCon
				end
			end

			function modifyData:unBindEvents()
				for i, eventCon in pairs(self.events) do
					if eventCon.Disconnect then eventCon:Disconnect() end
					self.events[i] = nil
				end
			end

			function modifyData:destroy()
				if self.active then
					self.active = false

					self:removeHover()
					self:unBindEvents()
				end
			end

			function modifyData:setHover(
				text: string,
				duration: number,
				enterCheck: number,
				textColor: Color3,
				frameColor: Color3
			)
				if self.active and guiData._object then
					if not guiData.itemContainer or guiData.itemContainer.Parent ~= guiData._object then
						self:removeHover()

						if guiData.itemContainer then service.Delete(guiData.itemContainer) end

						guiData.itemContainer = service.New("Folder", {
							Name = service.getRandom(),
							Archivable = false,
							Parent = guiData._object,
						}, true)
					end

					if not self.hoverData then
						local hoverFrame = service.New("Frame", {
							Name = "Hover",
							Size = UDim2.new(0, 0, 0, 30),
							BackgroundColor3 = Color3.fromRGB(31, 31, 31),
							BorderSizePixel = 0,
							Visible = false,
							Parent = guiData.itemContainer,
						})

						local frameUICorner = service.New("UICorner", {
							CornerRadius = UDim.new(0, 8),
							Parent = hoverFrame,
						})

						local hoverLabel = service.New("TextLabel", {
							Text = "",
							TextSize = 14,
							TextWrapped = true,
							RichText = true,
							ClipsDescendants = true,
							BackgroundTransparency = 1,
							Font = Enum.Font.GothamMedium,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Top,
							Parent = hoverFrame,
							Position = UDim2.new(0, 15, 0, 7),
							Size = UDim2.new(1, -30, 1, -15),
						})

						local hoverData = {
							active = true,
							text = "",
							duration = 0,
							enterCheck = 0.4,
							alignment = "top",
							frameColor = hoverFrame.BackgroundColor3,
							textColor = textColor or Color3.fromRGB(255, 255, 255),
							object = hoverFrame,
							label = hoverLabel,

							_hovering = false,
							_mouseIn = false,
						}

						hoverData.began = Signal.new()
						hoverData.ended = Signal.new()

						hoverData.mouseEntered = modifyData:bindEvent(object.MouseEnter, function()
							if
								hoverData.active
								and not (hoverData._hovering or hoverData._mouseIn)
								and #hoverData.text > 0
							then
								hoverData._mouseIn = true

								if hoverData.enterCheck > 0 then
									local enterCheck = hoverData.enterCheck
									local stCheck = os.clock()

									repeat
										if not hoverData._mouseIn then return end
										wait()
									until not hoverData.active or (os.clock() - stCheck >= enterCheck)
								end

								hoverData._hovering = true
								hoverData.began:fire()

								local playerMouse = service.player:GetMouse()
								local hoverDuration = hoverData.duration
								local hoverAlignment = hoverData.alignment

								if hoverAlignment == "top" then
									hoverData.object.AnchorPoint = Vector2.new(0, 0)
								elseif hoverAlignment == "middle" or hoverAlignment == "center" then
									hoverData.object.AnchorPoint = Vector2.new(0, 0.5)
								else
									hoverData.object.AnchorPoint = Vector2.new(0, 1)
								end

								local stHovering = os.clock()
								repeat
									local frameZIndex = object.ZIndex + 1
									hoverData.object.Visible = true
									hoverData.object.ZIndex = frameZIndex
									hoverData.label.Visible = true
									hoverData.label.ZIndex = frameZIndex

									local expectedPos = UDim2.new(0, playerMouse.X, 0, playerMouse.Y)

									if hoverData.object.Parent == guiData.itemContainer then
										hoverData.object:TweenPosition(expectedPos, "Out", "Quint", 0.2, true)
									else
										hoverData.object.Position = expectedPos
									end

									local hoverLabel = hoverData.label
									local hoverObject = hoverData.object
									local textSize = service.TextService:GetTextSize(
										hoverData.text,
										hoverLabel.TextSize,
										hoverLabel.Font,
										Vector2.new(400, hoverLabel.AbsoluteSize.Y * 3)
									)

									hoverObject.Size = UDim2.new(0, textSize.X + 30, 0, textSize.Y + 16)

									hoverLabel.Text = hoverData.text
									hoverLabel.TextColor3 = hoverData.textColor
									hoverObject.BackgroundColor3 = hoverData.frameColor
									service.RunService.Heartbeat:Wait()
								until not hoverData.active
									or not hoverData._hovering
									or (hoverDuration > 0 and os.clock() - stHovering > hoverDuration)

								hoverData.object.Visible = false
								hoverData._hovering = false
								hoverData.ended:fire()
							end
						end)

						hoverData.mouseLeave = modifyData:bindEvent(object.MouseLeave, function()
							if hoverData.active then
								if hoverData._hovering then hoverData._hovering = false end

								if hoverData._mouseIn then hoverData._mouseIn = false end
							end
						end)

						self.hoverData = hoverData
					end

					self.hoverData.text = tostring(text)
					self.hoverData.duration = roundNumber(duration or 0, 0.001)
					self.hoverData.enterCheck = roundNumber(enterCheck or 0.4, 0.001)
					self.hoverData.textColor = textColor or self.hoverData.textColor
					self.hoverData.frameColor = frameColor or self.hoverData.frameColor

					self.hoverData.object.BackgroundColor3 = self.hoverData.frameColor
					self.hoverData.label.TextColor3 = self.hoverData.textColor

					return self.hoverData
				end
			end

			function modifyData:removeHover()
				if self.hoverData then
					local hoverData = self.hoverData

					if hoverData.mouseEntered and hoverData.mouseEntered.Disconnect then
						hoverData.mouseEntered:Disconnect()
					end

					if hoverData.mouseLeave and hoverData.mouseLeave.Disconnect then
						hoverData.mouseLeave:Disconnect()
					end

					service.Delete(hoverData.object)
					service.Delete(hoverData.label)

					hoverData.active = false
					self.hoverData = nil
				end
			end

			function modifyData:enableResize(customData: {
				minimumSize: Vector2?,
				maximumSize: Vector2?,
				increment: number?,

				doTween: boolean?,
				doScale: boolean?,

				doWalls: boolean?,
				wallsEnabled: boolean?,
			})
				customData = customData or {}

				if self.active then
					if not self.resizeContainer or self.resizeContainer.Parent ~= object then
						self:removeHover()

						if self.resizeContainer then service.Delete(self.resizeContainer) end

						self.resizeContainer = service.New("Folder", {
							Name = service.getRandom(),
							Archivable = false,
							Parent = object,
						}, true)
					end

					if not self.resizeData then
						local playerGui = service.playerGui
						local resizeContainer = self.resizeContainer
						local resizeData = {
							active = true,
							minimumSize = customData.minimumSize or Vector2.new(50, 50),
							maximumSize = customData.maximumSize or Vector2.new(math.huge, math.huge),
							increment = customData.increment or 0.01,
							doTween = customData.doTween,
							doScale = customData.doScale,
							wallsEnabled = customData.doWalls or customData.wallsEnabled,

							_resizeState = false,

							resizeStarted = Signal.new(),
							resizeEnded = Signal.new(),
						}

						local function checkValidInput(input)
							if input.UserInputType == Enum.UserInputType.Touch then
								return true
							elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
								if input.KeyCode == Enum.KeyCode.ButtonA then return true end
							elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
								return true
							end
						end

						if not guiData._container then guiData.doScale = false end

						function resizeData:start(clickName)
							if self.active and not self._resizeState then
								local doScale = guiData.doScale
								local guiObject = guiData._object
								local playerMouse = service.player:GetMouse()
								local startPos = Vector2.new(playerMouse.X, playerMouse.Y)
								local startSize = (doScale and object.Size) or object.AbsoluteSize
								local screenAbsSize = guiObject.AbsoluteSize
								local objectAbsSize = object.AbsoluteSize
								local objectAbsPos = object.AbsolutePosition

								self._resizeState = true
								self.startPos = Vector2.new(playerMouse.X, playerMouse.Y)
								self.startSize = startSize
								self.objectAbsSize = objectAbsSize
								self.objectAbsPos = objectAbsPos
								self.resizeStartedAt = clickName
								self.resizeStarted:fire(clickName)
							end
						end

						function resizeData:stop()
							if self._resizeState then
								local resizeStartedAt = self.resizeStartedAt
								self._resizeState = false
								self.resizeStartedAt = nil
								self.startSize = nil
								self.objectAbsSize = nil
								self.objectAbsPos = nil
								self.resizeStartedAt = nil
								self.resizeEnded:fire(resizeStartedAt)
							end
						end

						function resizeData:update()
							if self._resizeState then
								local roundNumber = service.roundNumber
								local startedAt = self.resizeStartedAt
								local guiObject = guiData._object
								local playerMouse = service.player:GetMouse()
								local startMouse = self.startPos
								local startSize = self.startSize
								local screenAbsSize = guiObject.AbsoluteSize
								local objectAbsSize = self.objectAbsSize
								local objectAbsPos = self.objectAbsPos
								local curObjectAbsSize = object.AbsoluteSize
								local guiIncrement = self.increment

								local mousePos = Vector2.new(playerMouse.X, playerMouse.Y)
								local deltaMouse = mousePos - startMouse
								local newObjPos, newAbsSize = nil, nil

								if startedAt == "bottomRight" then
									local maximumSizeX = math.clamp(
										roundNumber(objectAbsSize.X + deltaMouse.X, guiIncrement),
										self.minimumSize.X,
										self.maximumSize.X
									)
									local maximumSizeY = math.clamp(
										roundNumber(objectAbsSize.Y + deltaMouse.Y, guiIncrement),
										self.minimumSize.Y,
										self.maximumSize.Y
									)

									newAbsSize = Vector2.new(maximumSizeX, maximumSizeY)
								elseif startedAt == "topRight" then
									local realSizeX = objectAbsSize.X + deltaMouse.X
									local realSizeY = objectAbsSize.Y - deltaMouse.Y

									local bottomPosY = objectAbsPos.Y + objectAbsSize.Y
									local maximumSizeX = math.clamp(
										roundNumber(realSizeX, guiIncrement),
										self.minimumSize.X,
										self.maximumSize.X
									)
									local maximumSizeY = math.clamp(
										roundNumber(realSizeY, guiIncrement),
										self.minimumSize.Y,
										self.maximumSize.Y
									)

									newAbsSize = Vector2.new(maximumSizeX, maximumSizeY)
									newObjPos = Vector2.new(
										objectAbsPos.X,
										math.clamp(
											roundNumber(objectAbsPos.Y + deltaMouse.Y, guiIncrement),
											bottomPosY - self.maximumSize.Y,
											bottomPosY - self.minimumSize.Y
										)
									)
								elseif startedAt == "topMiddle" then
									local realSizeY = objectAbsSize.Y - deltaMouse.Y
									local maximumSizeY = math.clamp(
										roundNumber(realSizeY, guiIncrement),
										self.minimumSize.Y,
										self.maximumSize.Y
									)
									local bottomPosY = objectAbsPos.Y + objectAbsSize.Y

									newAbsSize = Vector2.new(objectAbsSize.X, maximumSizeY)
									newObjPos = Vector2.new(
										objectAbsPos.X,
										math.clamp(
											roundNumber(objectAbsPos.Y + deltaMouse.Y, guiIncrement),
											bottomPosY - self.maximumSize.Y,
											bottomPosY - self.minimumSize.Y
										)
									)
								elseif startedAt == "bottomMiddle" then
									local realSizeY = objectAbsSize.Y + deltaMouse.Y
									local maximumSizeY = math.clamp(
										roundNumber(realSizeY, guiIncrement),
										self.minimumSize.Y,
										self.maximumSize.X
									)

									newAbsSize = Vector2.new(objectAbsSize.X, maximumSizeY)
								elseif startedAt == "rightSide" then
									local realSizeX = objectAbsSize.X + deltaMouse.X
									local maximumSizeX = math.clamp(
										roundNumber(realSizeX, guiIncrement),
										self.minimumSize.X,
										self.maximumSize.X
									)

									newAbsSize = Vector2.new(maximumSizeX, objectAbsSize.Y)
								elseif startedAt == "leftSide" then
									local realSizeX = objectAbsSize.X - deltaMouse.X
									local rightPosX = objectAbsPos.X + objectAbsSize.X
									local leftPosX = objectAbsPos.X
									local maximumSizeX = math.clamp(
										roundNumber(realSizeX, guiIncrement),
										self.minimumSize.X,
										self.maximumSize.X
									)

									newAbsSize = Vector2.new(maximumSizeX, objectAbsSize.Y)
									newObjPos = Vector2.new(
										math.clamp(
											roundNumber(objectAbsPos.X + deltaMouse.X, guiIncrement),
											rightPosX - self.maximumSize.X,
											rightPosX - self.minimumSize.X
										),
										objectAbsPos.Y
									)
								elseif startedAt == "topLeft" then
									local realSizeX = objectAbsSize.X - deltaMouse.X
									local realSizeY = objectAbsSize.Y - deltaMouse.Y

									local bottomRightPosX = objectAbsPos.X + objectAbsSize.X
									local bottomLeftPosY = objectAbsPos.Y + objectAbsSize.Y
									local maximumSizeX = math.clamp(
										roundNumber(realSizeX, guiIncrement),
										self.minimumSize.X,
										self.maximumSize.X
									)
									local maximumSizeY = math.clamp(
										roundNumber(realSizeY, guiIncrement),
										self.minimumSize.Y,
										self.maximumSize.Y
									)

									newAbsSize = Vector2.new(maximumSizeX, maximumSizeY)
									newObjPos = Vector2.new(
										math.clamp(
											roundNumber(objectAbsPos.X + deltaMouse.X, guiIncrement),
											bottomRightPosX - self.maximumSize.X,
											bottomRightPosX - self.minimumSize.X
										),
										math.clamp(
											roundNumber(objectAbsPos.Y + deltaMouse.Y, guiIncrement),
											bottomLeftPosY - self.maximumSize.Y,
											bottomLeftPosY - self.minimumSize.Y
										)
									)
								elseif startedAt == "bottomLeft" then
									local realSizeX = objectAbsSize.X - deltaMouse.X
									local realSizeY = objectAbsSize.Y + deltaMouse.Y

									local topRightPosX = objectAbsPos.X + objectAbsSize.X
									local maximumSizeX = math.clamp(
										roundNumber(realSizeX, guiIncrement),
										self.minimumSize.X,
										self.maximumSize.X
									)
									local maximumSizeY = math.clamp(
										roundNumber(realSizeY, guiIncrement),
										self.minimumSize.Y,
										self.maximumSize.X
									)

									newAbsSize = Vector2.new(maximumSizeX, maximumSizeY)
									newObjPos = Vector2.new(
										math.clamp(
											roundNumber(objectAbsPos.X + deltaMouse.X, guiIncrement),
											topRightPosX - self.maximumSize.X,
											topRightPosX - self.minimumSize.X
										),
										objectAbsPos.Y
									)
								end

								if self.doTween then
									service
										.tweenCreate(object, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
											Position = (newObjPos and UDim2.fromOffset(newObjPos.X, newObjPos.Y))
												or nil,
											Size = (newAbsSize and UDim2.fromOffset(newAbsSize.X, newAbsSize.Y)) or nil,
										})
										:Play()
								else
									if newAbsSize then object.Size = UDim2.fromOffset(newAbsSize.X, newAbsSize.Y) end

									if newObjPos then object.Position = UDim2.fromOffset(newObjPos.X, newObjPos.Y) end
								end
							end
						end

						local backgroundTransp = 1
						local iconZIndex = 100
						local topRightCornerHover = service.New("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = backgroundTransp,
							Position = UDim2.new(1, 0, 0, 0),
							Size = UDim2.new(0, 6, 0, 6),
							SizeConstraint = Enum.SizeConstraint.RelativeYY,
							Parent = resizeContainer,
							ZIndex = iconZIndex,
						})

						local topLeftCornerHover = service.New("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = backgroundTransp,
							Position = UDim2.new(0, 0, 0, 0),
							Size = UDim2.new(0, 6, 0, 6),
							SizeConstraint = Enum.SizeConstraint.RelativeYY,
							Parent = resizeContainer,
							ZIndex = iconZIndex,
						})

						local rightSideHover = service.New("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = backgroundTransp,
							Position = UDim2.new(1, 0, 0.5, 0),
							Size = UDim2.new(0, 6, 1, -10),
							SizeConstraint = Enum.SizeConstraint.RelativeYY,
							Parent = resizeContainer,
							ZIndex = iconZIndex,
						})

						local leftSideHover = service.New("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = backgroundTransp,
							Position = UDim2.new(0, 0, 0.5, 0),
							Size = UDim2.new(0, 6, 1, -10),
							SizeConstraint = Enum.SizeConstraint.RelativeYY,
							Parent = resizeContainer,
							ZIndex = iconZIndex,
						})

						local bottomRightCornerHover = service.New("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = backgroundTransp,
							Position = UDim2.new(1, 0, 1, 0),
							Size = UDim2.new(0, 6, 0, 6),
							SizeConstraint = Enum.SizeConstraint.RelativeYY,
							Parent = resizeContainer,
							ZIndex = iconZIndex,
						})

						local bottomLeftCornerHover = service.New("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = backgroundTransp,
							Position = UDim2.new(0, 0, 1, 0),
							Size = UDim2.new(0, 6, 0, 6),
							SizeConstraint = Enum.SizeConstraint.RelativeYY,
							Parent = resizeContainer,
							ZIndex = iconZIndex,
						})

						local topSideHover = service.New("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = backgroundTransp,
							Position = UDim2.new(0.5, 0, 0, 0),
							Size = UDim2.new(1, -10, 0, 6),
							Parent = resizeContainer,
							ZIndex = iconZIndex,
						})

						local bottomSideHover = service.New("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = backgroundTransp,
							Position = UDim2.new(0.5, 0, 1, 0),
							Size = UDim2.new(1, -10, 0, 6),
							Parent = resizeContainer,
							ZIndex = iconZIndex,
						})

						local clickArrays = {
							[bottomRightCornerHover] = "bottomRight",
							[bottomLeftCornerHover] = "bottomLeft",
							[topLeftCornerHover] = "topLeft",
							[topRightCornerHover] = "topRight",
							[topSideHover] = "topMiddle",
							[bottomSideHover] = "bottomMiddle",
							[rightSideHover] = "rightSide",
							[leftSideHover] = "leftSide",
						}

						resizeData.topRightCornerHover = topRightCornerHover
						resizeData.topLeftCornerHover = topLeftCornerHover
						resizeData.rightSideHover = rightSideHover
						resizeData.leftSideHover = leftSideHover
						resizeData.bottomRightCornerHover = bottomRightCornerHover
						resizeData.bottomLeftCornerHover = bottomLeftCornerHover
						resizeData.topSideHover = topSideHover
						resizeData.bottomSideHover = bottomSideHover

						for button, clickName in pairs(clickArrays) do
							local buttonInputBegan = self.eventHandler.new "ResizeUIEvents"
							buttonInputBegan:linkRbxEvent(button.InputBegan)
							buttonInputBegan:connect(function(input)
								local canResize = (
									not modifyData.dragData
									or modifyData.dragData and not modifyData.dragData._started
								) and (resizeData.active and not resizeData._resizeState)

								if
									canResize
									and checkValidInput(input)
									and resizeData.active
									and not resizeData._resizeState
								then
									resizeData:start(clickName)
								end
							end)

							--local buttonInputEnded = self.eventHandler.new("ResizeUIEvents")
							--buttonInputEnded:linkRbxEvent(button.InputEnded)
							--buttonInputEnded:connect(function(input)
							--	if checkValidInput(input) and resizeData.active and resizeData._resizeState then
							--		resizeData:stop()
							--	end
							--end)
						end

						local userInputChanged = self.eventHandler.new "ResizeUIEvents"
						userInputChanged:linkRbxEvent(service.UserInputService.InputChanged)
						userInputChanged:connect(function(input)
							if
								input.UserInputType == Enum.UserInputType.MouseMovement
								or input.UserInputType == Enum.UserInputType.Touch
							then
								if resizeData.active and resizeData._resizeState then resizeData:update() end
							end
						end)

						local userInputEnded = self.eventHandler.new "ResizeUIEvents"
						userInputEnded:linkRbxEvent(service.UserInputService.InputEnded)
						userInputEnded:connect(function(input)
							if checkValidInput(input) and resizeData.active and resizeData._resizeState then
								resizeData:stop()
							end
						end)

						self.resizeData = resizeData
						return resizeData
					end
				end
			end

			function modifyData:disableResize()
				if self.resizeData then
					self.resizeData.active = false
					self.resizeData:stop()
					self.resizeData = nil
				end
			end

			function modifyData:enableDrag(noTween: boolean, walls: boolean)
				if not guiData.itemContainer or guiData.itemContainer.Parent ~= guiData._object then
					self:removeHover()

					if guiData.itemContainer then service.Delete(guiData.itemContainer) end

					guiData.itemContainer = service.New("Folder", {
						Name = service.getRandom(),
						Archivable = false,
						Parent = guiData._object,
					}, true)
				end

				if not self.dragData then
					local dragData = {
						active = true,
						wallsEnabled = walls,
						noTween = noTween,

						_started = false,
						dragIncrement = 0.01,
						dragBegan = Signal.new(),
						dragEnded = Signal.new(),
					}
					local dragObject: GuiObject = modifyData.dragObject or object

					local function checkBoundaries(newPosition)
						local guiObject = guiData._object

						if not guiObject then
							return true
						else
							local absoluteSize = object.AbsoluteSize
							local guiAbsoluteSize = guiObject.AbsoluteSize
							local anchorPoint = object.AnchorPoint

							local topLeftPosition = Vector2.new(
								math.clamp(
									newPosition.X,
									0 + (anchorPoint.X * absoluteSize.X),
									(anchorPoint.X * absoluteSize.X) + (guiAbsoluteSize.X - absoluteSize.X)
								),
								math.clamp(
									newPosition.Y,
									0 + (anchorPoint.Y * absoluteSize.Y),
									(anchorPoint.Y * absoluteSize.Y) + (guiAbsoluteSize.Y - absoluteSize.Y)
								)
							)

							local topRightPosition = Vector2.new(topLeftPosition.X + absoluteSize.X, topLeftPosition.Y)
							local bottomLeftPosition = Vector2.new(newPosition.X, newPosition.Y + absoluteSize.Y)
							local bottomgRightPosition =
								Vector2.new(bottomLeftPosition.X + absoluteSize.X, bottomLeftPosition.Y)

							local topLeftPos1Pass = (topLeftPosition.X >= 0 and topLeftPosition.Y >= 0)
							local topLeftPos2Pass = (
								topLeftPosition.X <= guiAbsoluteSize.X and topLeftPosition.Y <= guiAbsoluteSize.Y
							)
							local topRightPos1Pass = (topRightPosition.X >= 0 and topRightPosition.Y >= 0)
							local topRightPos2Pass = (
								topRightPosition.X <= guiAbsoluteSize.X and topRightPosition.Y <= guiAbsoluteSize.Y
							)
							local bottomLeftPos1Pass = (bottomLeftPosition.X >= 0 and bottomLeftPosition.Y >= 0)
							local bottomLeftPos2Pass = (
								bottomLeftPosition.X <= guiAbsoluteSize.X
								and bottomLeftPosition.Y <= guiAbsoluteSize.Y
							)
							local bottomRightPos1Pass = (bottomgRightPosition.X >= 0 and bottomgRightPosition.Y >= 0)
							local bottomRightPos2Pass = (
								bottomgRightPosition.X <= guiAbsoluteSize.X
								and bottomgRightPosition.Y <= guiAbsoluteSize.Y
							)

							local isWithinBoundary = topLeftPos1Pass
								and topLeftPos2Pass
								and topRightPos1Pass
								and topRightPos2Pass
								and bottomLeftPos1Pass
								and bottomLeftPos2Pass
								and bottomRightPos1Pass
								and bottomRightPos2Pass

							--for i, uiPos in pairs({
							--	topLeftPosition,
							--	topRightPosition,
							--	bottomLeftPosition,
							--	bottomgRightPosition
							--}) do
							--	local frame = service.New("Frame", {
							--		Position = UDim2.fromOffset(uiPos.X, uiPos.Y);
							--		Size = UDim2.new(0, 10, 0, 10);
							--		BackgroundColor3 = Color3.fromRGB(255, 93, 93);
							--		AnchorPoint = Vector2.new(0.5, 0.5);
							--		Parent = guiObject;
							--	})

							--	service.Debris:AddItem(frame, 10)
							--end

							return isWithinBoundary, UDim2.fromOffset(topLeftPosition.X, topLeftPosition.Y)
						end
					end

					function dragData:start()
						if self.active and not self._started then
							self._started = true

							local roundNumber = service.roundNumber
							local playerMouse = service.player:GetMouse()
							local beganMouse = Vector2.new(playerMouse.X, playerMouse.Y)
							local objStartPosition = object.Position
							local dragIncrement = self.dragIncrement

							task.spawn(function()
								self.dragBegan:fire()

								repeat
									local mousePos = Vector2.new(playerMouse.X, playerMouse.Y)
									local offset = mousePos - beganMouse
									local absoluteSize = object.AbsoluteSize
									local guiAbsoluteSize = guiData._object.AbsoluteSize
									local anchorPoint = object.AnchorPoint
									local newPosition = UDim2.new(
										objStartPosition.X.Scale --[[0]],
										roundNumber(objStartPosition.X.Offset + offset.X, dragIncrement),
										objStartPosition.Y.Scale --[[0]],
										roundNumber(objStartPosition.Y.Offset + offset.Y, dragIncrement)
									)
									local newPositionWithoutScale = Vector2.new(
										(newPosition.X.Scale * guiAbsoluteSize.X) + newPosition.X.Offset,
										(newPosition.Y.Scale * guiAbsoluteSize.Y) + newPosition.Y.Offset
									)

									if self.wallsEnabled then
										local boundaryPass, newPos = checkBoundaries(newPositionWithoutScale)

										if self.noTween then
											object.Position = newPos
										else
											service
												.tweenCreate(
													object,
													TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
													{
														Position = newPos,
													}
												)
												:Play()
										end
									else
										if self.noTween then
											object.Position = newPosition
										else
											service
												.tweenCreate(
													object,
													TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
													{
														Position = newPosition,
													}
												)
												:Play()
										end
									end

									service.RunService.Heartbeat:Wait()
								until not (self.active and self._started)
							end)
						end
					end

					function dragData:stop()
						if self._started then
							self._started = false
							self.dragEnded:fire()
						end
					end

					function dragData:destroy()
						if self.active then
							self:stop()
							self.active = false

							local connections = {
								"mouseEntered",
								"mouseLeave",
								"inputBegan",
								"inputEnded",
							}

							for i, conName in pairs(connections) do
								local rbxConnection = self[conName]

								if rbxConnection.Connected then rbxConnection:Disconnect() end
							end
						end
					end

					dragObject.Active = true

					dragData.mouseEntered = modifyData:bindEvent(dragObject.MouseEnter, function()
						if dragData.active and not dragData._mouseIn then dragData._mouseIn = true end
					end)

					dragData.mouseLeave = modifyData:bindEvent(dragObject.MouseLeave, function()
						if dragData.active and dragData._mouseIn then dragData._mouseIn = false end
					end)

					dragData.inputBegan = modifyData:bindEvent(dragObject.InputBegan, function(input)
						if dragData.active and dragData._mouseIn then
							local canDrag = (
								not modifyData.resizeData
								or modifyData.resizeData and not modifyData.resizeData._resizeState
							) and (dragData.active and not dragData._started)

							if canDrag and input.UserInputType == Enum.UserInputType.MouseButton1 then
								dragData:start()
							end

							if canDrag and input.UserInputType == Enum.UserInputType.Touch then dragData:start() end
						end
					end)

					dragData.inputEnded = modifyData:bindEvent(dragObject.InputEnded, function(input)
						if dragData.active and dragData._started then
							if input.UserInputType == Enum.UserInputType.MouseButton1 then dragData:stop() end

							if input.UserInputType == Enum.UserInputType.Touch then dragData:stop() end
						end
					end)

					self.dragData = dragData
					return dragData
				end
			end

			function modifyData:disableDrag()
				if self.dragData then
					self.dragData:destroy()
					self.dragData = nil
				end
			end

			function modifyData:createTextHistory(initialText: string?)
				if object:IsA "TextBox" and not self.textHistory then
					local textHistory = {
						recentIndex = 0,
						recentRecord = nil,
						currentIndex = 0,
						currentRecord = nil,
						prevIndex = 0,
						prevRecord = nil,
						records = {},
						maxRecord = 150,

						locked = false,
						active = true,
						clearAfterFocusLost = false,

						historyUndo = Signal.new(),
						historyRedo = Signal.new(),
					}

					function textHistory:add(tab)
						if not self.locked then
							if tab.inputText then
								local currentRecord = self.records[#self.records]
								if
									currentRecord
									and currentRecord.inputText
									and currentRecord.inputText == tab.inputText
								then
									return
								end
							end

							if self.beforeSaving and type(self.beforeSaving) == "function" then
								local success, allowSaving, errTrace = service.nonThreadTask(self.beforeSaving, tab)
								if not success then
									warn(
										`UI Modifier TextHistory BeforeSaving function for {object:GetFullName()} encountered an error: {allowSaving}\n{errTrace}`
									)
									return
								end

								if type(allowSaving) ~= "boolean" then
									warn "Failed to save text in the TextHistory modifier due to the function returning a non-boolean value"
									return
								end

								if not allowSaving then return end
							end

							local resetRecords = #self.records + 1 > self.maxRecord

							if resetRecords then
								table.clear(self.records)
								self.currentIndex = 0
								self.currentRecord = nil
							end

							local newRecordIndex = self.currentIndex + 1

							table.insert(self.records, tab)
							self.prevIndex = self.currentIndex
							self.prevRecord = self.currentRecord
							self.currentIndex = newRecordIndex
							self.currentRecord = tab
							self.recentIndex = newRecordIndex + 1
							self.recentRecord = self.records[self.recentIndex]
						end
					end

					function textHistory:undo()
						local prevIndex = self.currentIndex - 1
						local prevRecord = self.records[prevIndex]

						if prevRecord then
							local newPrevIndex = prevIndex - 1
							local newPrevRecord = self.records[newPrevIndex]

							self.prevIndex = newPrevIndex
							self.prevRecord = newPrevRecord

							self.currentIndex = prevIndex
							self.currentRecord = prevRecord

							self.recentIndex = prevIndex + 1
							self.recentRecord = self.records[self.recentIndex]

							self.locked = true
							prevRecord:execute()
							self.locked = false

							textHistory.historyUndo:fire()

							return prevRecord
						end
					end

					function textHistory:redo()
						local upIndex = self.currentIndex + 1
						local upRecord = self.records[upIndex]

						if upRecord then
							self.prevIndex = upIndex - 1
							self.prevRecord = self.records[upIndex - 1]

							self.currentIndex = upIndex
							self.currentRecord = upRecord

							self.recentIndex = upIndex + 1
							self.recentRecord = self.records[self.recentIndex]

							self.locked = true
							upRecord:execute()
							self.locked = false

							textHistory.historyRedo:fire()

							return upRecord
						end
					end

					function textHistory:clear()
						table.clear(self.records)

						self.recentIndex = 0
						self.recentRecord = nil
						self.currentIndex = 0
						self.currentRecord = nil
						self.prevIndex = 0
						self.prevRecord = nil
					end

					function textHistory:undoLatest()
						local indexOfLatestRecord = #self.records
						local latestRecord = self.records[indexOfLatestRecord]

						if latestRecord then
							table.remove(self.records, indexOfLatestRecord)

							if self.currentRecord ~= latestRecord then
								local currentRecord = self.currentRecord
								local indexOfCurrentRecord = if currentRecord
									then table.find(self.records, self.currentRecord)
									else nil

								self.currentIndex = indexOfCurrentRecord or 0
								self.currentRecord = currentRecord
							else
								local prevIndex = math.max(#self.records - 1, 0)
								local prevRecord = self.records[prevIndex]

								self.currentIndex = prevIndex
								self.currentRecord = prevRecord

								self.prevIndex = prevIndex - 1
								self.prevRecord = self.records[prevIndex - 1]

								self.recentIndex = prevIndex - 1
								self.recentRecord = self.records[prevIndex - 1]

								if prevRecord then prevRecord:execute() end
							end
						end
					end

					function textHistory:changeTextToCurrentChange()
						if self.locked then return end
						self.locked = true
						local historyData = self.records[self.currentIndex]
						if historyData then object.Text = historyData.inputText end
						self.locked = false
					end

					self.textHistory = textHistory
					textHistory:add {
						inputText = tostring(initialText or object.Text),
						cursorPosition = if self.textHistory.preferLensPosition
							then utf8.len(object.Text) + 1
							else object.CursorPosition,

						execute = function(inputHistory)
							local newInputText = inputHistory.inputText

							self.currentText = newInputText
							object.Text = newInputText
							task.wait(0.1)
							if object.Text == newInputText then
								object.CursorPosition = inputHistory.cursorPosition or utf8.len(newInputText) + 1
							end
						end,
					}

					local textChanged = self.eventHandler.new "TextHistoryEvents"
					local focusLost = self.eventHandler.new "TextHistoryEvents"
					local userInputBegan = self.eventHandler.new "TextHistoryEvents"
					local touchSwipeEvent = self.eventHandler.new "TextHistoryEvents"
					local userInputService = service.UserInputService

					textChanged:linkRbxEvent(object:GetPropertyChangedSignal "Text")
					textChanged:Connect(function()
						if textHistory.active and object:IsFocused() and object.TextEditable then
							textHistory:add {
								inputText = object.Text,
								cursorPosition = if textHistory.preferLensPosition
									then utf8.len(object.Text) + 1
									else object.CursorPosition,

								execute = function(inputHistory)
									local newInputText = inputHistory.inputText

									self.currentText = newInputText
									object.Text = newInputText
									task.wait(0.1)
									if object.Text == newInputText then
										object.CursorPosition = inputHistory.cursorPosition
											or utf8.len(newInputText) + 1
									end
								end,
							}
						end
					end)

					focusLost:linkRbxEvent(object.FocusLost)
					focusLost:Connect(function(didHitEnter, inputThatTrigger)
						if textHistory.clearAfterFocusLost then textHistory:clear() end
					end)

					userInputBegan:linkRbxEvent(userInputService.InputBegan)
					userInputBegan:Connect(function(input, gameProcessed)
						if
							textHistory.active
							and not textHistory.locked
							and not textHistory._ongoingChangeState
							and object.TextEditable
							and object:IsDescendantOf(service.playerGui)
							and object:IsFocused()
							and gameProcessed
						then
							if input.UserInputType == Enum.UserInputType.Keyboard then
								if
									userInputService:IsKeyDown(Enum.KeyCode.LeftControl)
									or userInputService:IsKeyDown(Enum.KeyCode.RightControl)
								then
									if input.KeyCode == Enum.KeyCode.Z then
										--warn("Undo triggered via keyboard")
										textHistory._ongoingChangeState = true
										repeat
											textHistory:undo()
											service.RunService.RenderStepped:Wait()
										--warn("")
										until not (
												userInputService:IsKeyDown(Enum.KeyCode.LeftShift)
												or userInputService:IsKeyDown(Enum.KeyCode.RightShift)
											)
											or not (userInputService:IsKeyDown(Enum.KeyCode.LeftControl) or userInputService:IsKeyDown(
												Enum.KeyCode.RightControl
											))
											or not userInputService:IsKeyDown(Enum.KeyCode.Z)
											or not object:IsFocused()
											or textHistory.currentIndex >= #textHistory.records
										textHistory._ongoingChangeState = false
									elseif input.KeyCode == Enum.KeyCode.Y then
										--warn("Redo triggered via keyboard")
										textHistory._ongoingChangeState = true
										repeat
											textHistory:redo()
											service.RunService.RenderStepped:Wait()
										until not (
												userInputService:IsKeyDown(Enum.KeyCode.LeftShift)
												or userInputService:IsKeyDown(Enum.KeyCode.RightShift)
											)
											or not (userInputService:IsKeyDown(Enum.KeyCode.LeftControl) or userInputService:IsKeyDown(
												Enum.KeyCode.RightControl
											))
											or not userInputService:IsKeyDown(Enum.KeyCode.Y)
											or not object:IsFocused()
											or textHistory.currentIndex <= 1
										textHistory._ongoingChangeState = false
									end
								end
							end
						end
					end)

					touchSwipeEvent:linkRbxEvent(object.TouchSwipe)
					touchSwipeEvent:Connect(function(swipeDir, touchCount)
						if textHistory.active and self.focused and not self.locked and touchCount == 2 then
							if swipeDir == Enum.SwipeDirection.Left then
								textHistory:undo()
								textHistory.historyUndo:fire()
							elseif swipeDir == Enum.SwipeDirection.Right then
								textHistory:redo()
								textHistory.historyRedo:fire()
							end
						end
					end)

					return textHistory
				end
			end

			function modifyData:clearTextHistory(clearInputText: boolean?)
				if self.textHistory then
					self.textHistory:clear()

					if clearInputText then object.Text = "" end
				end
			end

			function modifyData:endTextHistory(clearInputText: boolean?)
				if self.textHistory then
					self.textHistory:clear()
					self.textHistory.active = false
					self.eventHandler:killSignals "TextHistoryEvents"

					if clearInputText then object.Text = "" end

					self.textHistory = nil
				end
			end

			objData.modifier = modifyData
			modifiedObjects[object] = modifyData

			return modifyData
		end,

		clearGuiData = function(guiName: string, guiObject: Instance?)
			local unFinished = false
			local wrapObj = guiObject and service.wrap(guiObject)

			repeat
				unFinished = false

				for i, guiData in ipairs(createdUIs) do
					if (guiName and guiData.name == guiName) or (guiObject and guiData.object == wrapObj) then
						guiData:destroy()
						unFinished = true
						break
					end
				end
			until not unFinished
		end,

		findConstructByAlias = function(aliasName: string, dataTheme: string)
			local themeFolder = libraryFolder:FindFirstChild(dataTheme or variables.guiTheme or "Default")

			if themeFolder then
				for i, constructor in themeFolder:GetChildren() do
					local constructorAliases = constructor:GetAttribute "Aliases"

					if type(constructorAliases) == "string" then
						local listOfAliases = client.Parser:getArguments(constructorAliases, ",", {
							ignoreQuotes = true,
						})

						for i, constructorAlias in listOfAliases do
							if constructorAlias == aliasName then return constructor end
						end
					end
				end
			end
		end,

		findUIWithCategory = function(categoryAndUIConstruct: string, dataTheme: string?)
			local category, constructNameOrAlias = string.match(categoryAndUIConstruct, "^(.+)%.(.+)$")

			if category and constructNameOrAlias then
				local themeFolder = libraryFolder:FindFirstChild(dataTheme or variables.guiTheme or "Default")
				local categoryFolder: Folder = themeFolder:FindFirstChild(category)
				if not categoryFolder then return end

				if categoryFolder:FindFirstChild(constructNameOrAlias) then
					return categoryFolder:FindFirstChild(constructNameOrAlias)
				end

				for i, constructor in categoryFolder:GetChildren() do
					local constructorAliases = constructor:GetAttribute "Aliases"

					if type(constructorAliases) == "string" then
						local listOfAliases = client.Parser:getArguments(constructorAliases, ",", {
							ignoreQuotes = true,
						})

						for i, constructorAlias in listOfAliases do
							if constructorAlias == constructNameOrAlias then return constructor end
						end
					end
				end
			end
		end,

		Converters = {
			convertObjectToTextBox = function(textLabelOrButton: TextButton | TextBox, deleteObjectAfterCopy: boolean?)
				local inheritedProperties = {
					--// Base
					"Name",
					"Position",
					"Rotation",
					"Size",
					"SizeConstraint",
					"Visible",
					"ZIndex",
					"Parent",

					"AutomaticSize",
					"BackgroundColor3",
					"BackgroundTransparency",
					"BorderColor3",
					"BorderMode",
					"BorderSizePixel",
					"Interactable",
					"LayoutOrder",

					"ClipsDescendants",
					"FontFace",
					"LineHeight",
					"MaxVisibleGraphemes",
					"RichText",
					"Text",
					"TextColor3",
					"TextDirection",
					"TextScaled",
					"TextSize",
					"TextStrokeColor3",
					"TextStrokeTransparency",
					"TextTransparency",
					"TextWrapped",
					"TextXAlignment",
					"TextYAlignment",
				}

				local textBox = Instance.new "TextBox"

				for i, prop in inheritedProperties do
					textBox[prop] = textLabelOrButton[prop]
				end

				textBox.TextEditable = false
				textBox.ClearTextOnFocus = false
				textBox.ShowNativeInput = false

				if deleteObjectAfterCopy then
					textLabelOrButton.Visible = false
					service.Delete(textLabelOrButton, 1)
				end

				return textBox
			end,
		},
	}
end
