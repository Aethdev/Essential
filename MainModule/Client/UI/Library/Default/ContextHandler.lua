
return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service

	local variables = envArgs.variables
	local contextContainer = variables.contextContainer
	
	local Promise = client.Promise

	if not contextContainer then
		contextContainer = client.UI.makeElement("Container")
		
		local pcEnabled = client.pcDevice or client.consoleDevice
		
		local screenSize = client.ScreenSize
		local frame = service.New("Frame", {
			AnchorPoint = Vector2.new(.5, 0);
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new(0.5, 0, 0, 30);
			Size = UDim2.new(0, 250, 0, 290);
			--ClipsDescendants = true;
			Parent = contextContainer._object;
		})
		
		frame.Parent = contextContainer._object
		contextContainer.frame = frame
		
		contextContainer._elements = {}
		contextContainer._subscribedElements = {}
		
		contextContainer.tweenTime = 0.6
		contextContainer.easingStyle = Enum.EasingStyle.Bounce
		
		contextContainer.maxElements = (pcEnabled and 4) or 2
		
		function contextContainer:checkFrame()
			if not self.frame or self.frame.Parent ~= self._object then
				if self.frame then
					service.Delete(self.frame)
				end
				
				self.frame = service.New("Frame", {
					AnchorPoint = Vector2.new(.5, 0);
					BackgroundTransparency = 1;
					BorderSizePixel = 0;
					Position = UDim2.new(0.5, 0, 0, 30);
					Size = UDim2.new(0, 250, 0, 290);
					--ClipsDescendants = true;
					Parent = contextContainer._object;
				})
			end
		end
		
		function contextContainer:getActiveElements()
			local results = {}
			local stackElements = 0
			
			for i,element in pairs(self._elements) do
				if element.active and (element.forceHide or element.showState) then
					table.insert(results, element)
				end
			end
			
			return results
		end
		
		function contextContainer:getFrameSize()
			local highestSizeX = 0
			local frameSizeY = 0
			local countedElements = 0
			
			for i,element in pairs(self._elements) do
				if element.active and (element.forceHide or element.showState) and countedElements+1 <= self.maxElements then
					frameSizeY = (frameSizeY+(element.expectedSize.Y))+5
					countedElements += 1
					
					if highestSizeX < element.expectedSize.X then
						highestSizeX = element.expectedSize.X
					end
				end
			end
			
			return Vector2.new(highestSizeX, frameSizeY)
		end
		
		function contextContainer:clearElements()
			for i, element in pairs(self._elements) do
				self._elements[i] = nil
				element:destroy()
			end
		end
		
		function contextContainer:adjustFrameSize()
			local expectedSize = self:getFrameSize()
			self.frame.Size = UDim2.new(0, expectedSize.X, 0, expectedSize.Y)
		end
		
		function contextContainer:sort()
			local len = #self._elements
			local index = len
			
			local stackSize = 0
			local maxElements = self.maxElements
			local stopIndex = index-maxElements
			local checkElements = {}
			
			self:checkFrame()
			self:adjustFrameSize()
			
			table.sort(self._elements, function(elementA, elementB)
				return elementA._priority > elementB._priority or (elementA._priority == elementB._priority and elementA._joinedGroup < elementB._joinedGroup)
			end)
			
			while index > 0 and (stopIndex < index) do
				local element = self._elements[index]
				
				if element.active and (element.forceHide or element.showState) then
					local expectedPos = UDim2.new(0.5, 0, 0, stackSize)
					
					if element.forceHide then
						element.forceHide = false
						element._object.Position = expectedPos
						
						local expireOs = element.expireOs
						local expireTime = element.time
						
						if (expireOs and expireOs-os.time() > 0) or (not expireOs) then
							if not element.showState then
								coroutine.wrap(element.show)(element, (expireOs and expireOs-os.time()) or expireTime or nil)
							end
						else
							element.forceRemove = true
							if element.showState then
								coroutine.wrap(element.hide)(element)
							end
							
							self:remove(element)
							return
						end
					end
					
					element._object.Visible = true
					
					if element._object.Parent == element.containerData.frame and element.containerData._object.Parent == service.playerGui then
						element._object:TweenPosition(expectedPos, "Out", "Quint", 0.4, true)
					else
						element._object.Position = expectedPos
					end
					
					checkElements[element] = true
					stackSize = (stackSize+(element.expectedSize.Y))+5
				else
					stopIndex -= 1
				end
				
				index = index - 1
			end
			
			if len > 0 then
				for i, element in pairs(self._elements) do
					if (element.active and element.showState and not element.forceHide) and not checkElements[element] then
						coroutine.wrap(element.hide)(element)
						element.forceHide = true
					end
				end
				
				local activeElements = self:getActiveElements()
				local expectedSize = self:getFrameSize()
				
				if #activeElements == 0 then
					wait(1)
					if self:getFrameSize() == expectedSize then
						self:hide()
						return
					end
				end
				
				self:adjustFrameSize()
			end
		end
		
		function contextContainer:add(element)
			local elemIndex = table.find(self._elements, element)

			if not elemIndex then
				element._priority = element._priority or 0
				element._joinedGroup = tick()
				
				table.insert(self._elements, element)
				
				local subscribedEvents = {
					hidden = element.hidden:connect(function()
						wait(1)
						if not element.forceRemove and not element.showState then
							local activeNotifs_count = #self:getActiveElements()
							
							if activeNotifs_count == 0 then
								self:startInactivityDelay()
							else
								self:sort()
							end
						end
					end);
					
					--shown = element.shown:connect(function()
					--	self:sort()
					--end)
				}
				
				self._subscribedElements[element] = subscribedEvents
				self:stopInactivityDelay()
				self:autoUpdate()
			end
		end
		
		function contextContainer:remove(element)
			local elemIndex = table.find(self._elements, element)
			
			if elemIndex then
				table.remove(self._elements, elemIndex)
				
				if element.showState then
					self:sort()
				end
				
				local subscribedEvents = self._subscribedElements[element]
				
				if subscribedEvents then
					for i,event in pairs(subscribedEvents) do
						event:Disconnect()
					end
					
					self._subscribedElements[element] = nil
				end
			end
		end
		
		function contextContainer:autoUpdate()
			if self.autoUpdateSignal then return self end
			
			local autoUpdateSignal = client.Signal.new()
			autoUpdateSignal:linkRbxEvent(service.RunService.Heartbeat)
			autoUpdateSignal:connect(function()
				for index, element in self._elements do
					if (element.active and element.showState) then
						Promise.promisify(element.updateDisplayContent)(element)
							:andThenCall(element.updateDisplaySize, element)
							:catch(function(err)
								task.spawn(element.hide, element)
								warn(`Context container encountered an error with Context during update display content: {tostring(err)}`)
							end)
					end
				end
				
				if not self.autoUpdateFrameSize or (tick()-self.autoUpdateFrameSize >= 3) then
					self.autoUpdateFrameSize = tick()
					self:adjustFrameSize()
				end
			end)
			
			self.autoUpdateSignal = autoUpdateSignal
			
			return self
		end
		
		function contextContainer:stopAutoUpdate()
			if self.autoUpdateSignal then
				task.spawn(self.autoUpdateSignal.disconnect, self.autoUpdateSignal)
				self.autoUpdateSignal = nil
			end
			
			return self
		end
		
		function contextContainer:startInactivityDelay()
			self:stopInactivityDelay()
			
			self.inactivityCheck = Promise.delay(3)
				:andThenCall(self.hide, self)
				:andThenCall(self.stopAutoUpdate, self)
				:catch(function(err)
					warn(`Context container encountered an error during inactivity check: {tostring(err)}`)
				end)
		end
		
		function contextContainer:stopInactivityDelay()
			if self.inactivityCheck then
				task.defer(self.inactivityCheck.cancel, self.inactivityCheck)
				self.inactivityCheck = nil
			end
		end
		
		contextContainer._object.DisplayOrder = 300
		
		local playerGui = service.playerGui
		
		contextContainer.parent = playerGui
		if not playerGui then
			client.playerGui_Found:connectOnce(function(plrGui)
				contextContainer.parent = plrGui
				contextContainer:show()
			end)
		end
		
		variables.contextContainer = contextContainer
		
		return contextContainer
	end
end