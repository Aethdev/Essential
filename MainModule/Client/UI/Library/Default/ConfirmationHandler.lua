
return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service
	local variables = envArgs.variables
	
	local Promise = client.Promise
	local Signal = client.Signal
	
	local container = variables.confirmV2Container
	
	if not container then
		container = client.UI.makeElement("Container")
		variables.confirmV2Container = container
	end
	
	container._subscribedElements = {}
	
	function container:checkFrame()
		if not container._frame or container._frame.Parent ~= container then
			if container._frame then
				service.Debris:AddItem(container._frame, 0)
			end

			local frame = service.New("Frame",{
				AnchorPoint = Vector2.new(0.5, 0.5);
				BackgroundTransparency = 1;
				Position = UDim2.new(0.5, 0, 0.5, 0);
				Size = UDim2.new(0, 600, 0, 150);
				--ClipsDescendants = true;

				Parent = container._object;
			})

			container._frame = frame
		else
			container._frame.Visible = true
		end
	end
	
	function container:add(element)
		local newIndex = self:getNumberOfActiveElements() + 1
		
		element.handlerAddedOn = tick()
		element.handlerIndex = newIndex - 1
		
		element._handlerShownEvent = element.shown:connect(function()
			self:stopInactivityCheck()
		end)
		
		element._handlerHiddenEvent = element.hidden:connect(function()
			task.defer(self.startInactivityCheck, self)
			self:sort()
		end)
		
		table.insert(self._subscribedElements, element)
		self:sort()
		
		container:show()
		
		if not self._autoUpdateCheck then
			self:startHeartbeatEvent()
		end
		
		return self
	end
	
	function container:startHeartbeatEvent()
		self._autoUpdateCheck = true
		self:stopHeartbeatEvent()
		
		local onHeartbeat = Signal.new()
		onHeartbeat:linkRbxEvent(service.RunService.Heartbeat)
		onHeartbeat:connect(function()
			for i, element in self._subscribedElements do
				if element.active and element.showState then
					element:updateBodyDisplay()
				end
			end
		end)
		
		self._autoUpdateElements = onHeartbeat
		return self
	end
	
	function container:stopHeartbeatEvent()
		if self._autoUpdateElements then
			self._autoUpdateElements:disconnect()
			self._autoUpdateElements = nil
		end
		
		self._autoUpdateCheck = false
		return self
	end
	
	function container:startInactivityCheck()
		if self:getNumberOfActiveElements() > 0 then return self end
		self:stopInactivityCheck()
		
		self._inactivityCheck = Promise.delay(5)
			:andThenCall(container.hide, container)
			:andThenCall(container.stopHeartbeatEvent, container)
		
		return self
	end
	
	function container:stopInactivityCheck()
		if self._inactivityCheck then
			self._inactivityCheck:cancel()
			self._inactivityCheck = nil
		end
		
		return self
	end
	
	function container:remove(element)
		local foundIndex = table.find(self._subscribedElements, element)
		
		if foundIndex then
			table.remove(self._subscribedElements, foundIndex)
			element.handlerIndex = 0
			
			self:sort()
		end
		
		return self
	end
	
	
	function container:getNumberOfActiveElements(): number
		local count = 0
		
		for i, element in self._subscribedElements do
			if element.active and element.showState then
				count += 1
			end
		end
		
		return count
	end
	
	function container:sort()
		local currentOs = os.time()
		
		table.sort(self._subscribedElements, function(elementA_newest, elementB_oldest)
			local elementAShowState = elementA_newest.showState
			local elementBShowState = elementB_oldest.showState
			
			return (elementA_newest.handlerAddedOn and elementA_newest.showStartedOn == elementB_oldest.showStartedOn and elementA_newest.handlerAddedOn < elementB_oldest.handlerAddedOn)
				or ((elementA_newest.showStartedOn or elementA_newest.handlerAddedOn) < (elementB_oldest.showStartedOn or elementB_oldest.handlerAddedOn))
		end)
		
		local activeIndex = 0
		for i, element in self._subscribedElements do
			if element.active and element.showState then
				element.handlerIndex = activeIndex
				activeIndex += 1
			end
			element._object.Name = `Element{i}`
			element:updateBodyPositionAndSize()
			element:updateBodyDisplay()
		end
		
		return self
	end
		
	
	return container
end