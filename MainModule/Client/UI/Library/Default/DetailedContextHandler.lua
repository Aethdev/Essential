return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service

	local variables = envArgs.variables
	local detailedContextContainer = variables.detailedContextContainer

	if not detailedContextContainer then
		detailedContextContainer = client.UI.makeElement "Container"

		local pcEnabled = client.pcDevice or client.consoleDevice

		local screenSize = client.ScreenSize
		local frame = service.New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0, 30),
			Size = UDim2.new(0, 250, 0, 290),
			ClipsDescendants = true,
			Parent = detailedContextContainer._object,
		})

		frame.Parent = detailedContextContainer._object
		detailedContextContainer.frame = frame

		detailedContextContainer._elements = {}
		detailedContextContainer._subscribedElements = {}

		detailedContextContainer.maxElements = (pcEnabled and 4) or 2

		function detailedContextContainer:checkFrame()
			if not self.frame or self.frame.Parent ~= self._object then
				if self.frame then service.Delete(self.frame) end

				self.frame = service.New("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.new(0.5, 0, 0, 30),
					Size = UDim2.new(0, 250, 0, 160),
					ClipsDescendants = false,
					Parent = detailedContextContainer._object,
				})
			end
		end

		function detailedContextContainer:getActiveElements()
			local results = {}
			local stackElements = 0

			for i, element in pairs(self._elements) do
				if element.active and (element.forceHide or element.showState) then table.insert(results, element) end
			end

			return results
		end

		function detailedContextContainer:getFrameSize()
			local highestSizeX = 0
			local frameSizeY = 0
			local countedElements = 0

			for i, element in pairs(self._elements) do
				if
					element.active
					and (element.forceHide or element.showState)
					and countedElements + 1 <= self.maxElements
				then
					frameSizeY = (frameSizeY + element.expectedSize.Y) + 5
					countedElements += 1

					if highestSizeX < element.expectedSize.X then highestSizeX = element.expectedSize.X end
				end
			end

			return Vector2.new(highestSizeX, frameSizeY)
		end

		function detailedContextContainer:clearElements()
			for i, element in pairs(self._elements) do
				self._elements[i] = nil
				element:destroy()
			end
		end

		function detailedContextContainer:adjustFrameSize()
			local expectedSize = self:getFrameSize()
			self.frame.Size = UDim2.new(0, expectedSize.X, 0, expectedSize.Y)
		end

		function detailedContextContainer:sort()
			local len = #self._elements
			local index = len

			local stackSize = 0
			local maxElements = self.maxElements
			local stopIndex = index - maxElements
			local checkElements = {}

			self:checkFrame()
			self:adjustFrameSize()

			while index > 0 and (stopIndex < index) do
				local element = self._elements[index]

				if element.active and (element.forceHide or element.showState) then
					local expectedPos = UDim2.new(0.5, 0, 0, stackSize)

					if element.forceHide then
						element.forceHide = false
						element._object.Position = expectedPos

						local expireOs = element.expireOs
						local expireTime = element.time

						if (expireOs and expireOs - os.time() > 0) or not expireOs then
							if not element.showState then
								coroutine.wrap(element.show)(
									element,
									(expireOs and expireOs - os.time()) or expireTime or nil
								)
							end
						else
							element.forceRemove = true
							if element.showState then coroutine.wrap(element.hide)(element) end

							self:remove(element)
							return
						end
					end

					element._object.Visible = true

					if
						element._object.Parent == element.containerData.frame
						and element.containerData._object.Parent == service.playerGui
					then
						element._object:TweenPosition(expectedPos, "Out", "Quint", 0.4, true)
					else
						element._object.Position = expectedPos
					end

					checkElements[element] = true
					stackSize = (stackSize + element.expectedSize.Y) + 5
				else
					stopIndex -= 1
				end

				index = index - 1
			end

			if len > 0 then
				for i, element in pairs(self._elements) do
					if
						(element.active and element.showState and not element.forceHide) and not checkElements[element]
					then
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

		function detailedContextContainer:add(element)
			local elemIndex = table.find(self._elements, element)

			if not elemIndex then
				table.insert(self._elements, element)

				local subscribedEvents = {
					hidden = element.hidden:connect(function()
						wait(1)
						if not element.forceRemove then
							local activeNotifs_count = #self:getActiveElements()

							if activeNotifs_count == 0 then
								self:hide()
							else
								self:sort()
							end
						end
					end),

					--shown = element.shown:connect(function()
					--	self:sort()
					--end)
				}

				self._subscribedElements[element] = subscribedEvents
			end
		end

		function detailedContextContainer:remove(element)
			local elemIndex = table.find(self._elements, element)

			if elemIndex then
				table.remove(self._elements, elemIndex)

				if element.showState then self:sort() end

				local subscribedEvents = self._subscribedElements[element]

				if subscribedEvents then
					for i, event in pairs(subscribedEvents) do
						event:Disconnect()
					end

					self._subscribedElements[element] = nil
				end
			end
		end

		detailedContextContainer._object.DisplayOrder = 300

		local playerGui = service.playerGui

		detailedContextContainer.parent = playerGui
		if not playerGui then
			client.playerGui_Found:connectOnce(function(plrGui)
				detailedContextContainer.parent = plrGui
				detailedContextContainer:show()
			end)
		end

		variables.detailedContextContainer = detailedContextContainer

		return detailedContextContainer
	end
end
