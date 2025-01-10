
return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service

	local variables = envArgs.variables
	local notifContainer = variables.notifContainer

	if not notifContainer then
		notifContainer = client.UI.makeElement("Container")

		local frame = service.New("ScrollingFrame", {
			AnchorPoint = Vector2.new(1, 1);
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new(1, -15, 1, -15);
			Size = UDim2.new(0, 250, 0, 290);
			CanvasSize = UDim2.new(0, 0, 0, 290);
			ScrollBarThickness = 0;
			ScrollingEnabled = false;
			ClipsDescendants = true;
			Parent = notifContainer._object;
		})
		
		frame.Parent = notifContainer._object
		notifContainer.frame = frame
		
		notifContainer._notifs = {}
		notifContainer._subscribedNotifs = {}
		
		notifContainer.tweenTime = 0.4
		notifContainer.easingStyle = Enum.EasingStyle.Quint
		
		function notifContainer:checkFrame()
			if not self.frame or self.frame.Parent ~= self._object then
				if self.frame then
					service.Delete(self.frame)
				end
				
				self.frame = service.New("ScrollingFrame", {
					AnchorPoint = Vector2.new(1, 1);
					BackgroundTransparency = 1;
					BorderSizePixel = 0;
					Position = UDim2.new(1, -15, 1, -15);
					Size = UDim2.new(0, 250, 0, 290);
					CanvasSize = UDim2.new(0, 0, 0, 290);
					ScrollBarThickness = 0;
					ScrollingEnabled = false;
					ClipsDescendants = true;
					Parent = self._object;
				})
			end
			
			local expectedCSize = UDim2.new(0, 0, 0, math.clamp(math.ceil(#self:getActiveElements()/3), 1, 6)*self.frame.Size.Y.Offset)
				
			if self.frame:IsDescendantOf(game) then
				service.TweenService:Create(
					self.frame,
					TweenInfo.new(self.tweenTime, self.easingStyle, Enum.EasingDirection.Out),
					{
						CanvasSize = expectedCSize;
					}
				):Play()
			else
				self.frame.CanvasSize = expectedCSize
			end
			
			if #self:getActiveElements() > 3 then
				--self.frame.CanvasPosition = Vector2.new(0, expectedCSize.Y.Offset/2)
				self.frame.ScrollingEnabled = true
				--self.frame.ScrollBarThickness = 10
			else
				self.frame.CanvasPosition = Vector2.new(0, 0)
				self.frame.ScrollingEnabled = false
				--self.frame.ScrollBarThickness = 0
			end
		end
		
		function notifContainer:getActiveElements()
			local results = {}
			
			for i,notif in pairs(self._notifs) do
				if notif.visible then
					table.insert(results, notif)
				end
			end
			
			return results
		end
		
		function notifContainer:clearElements()
			for i, notif in pairs(self._notifs) do
				self._notifs[i] = nil
				notif:destroy()
			end
		end
		
		function notifContainer:sort()
			local len = #self._notifs
			local index = len
			
			local absoluteSizeY = 90
			local stackSize = absoluteSizeY -- Starts with the default size Y
			
			while index > 0 do
				local notif = self._notifs[index]
				
				if notif.active and notif.visible then
					local expectedPos = UDim2.new(0, 0, 1, -stackSize)
					
					notif._object.Visible = true
					if notif._object:IsDescendantOf(game) then
						notif._object:TweenPosition(expectedPos, "Out", "Quint", 0.4, true)
					else
						notif._object.Position = expectedPos
					end
					
					stackSize = (stackSize+(absoluteSizeY))+10
				end
				
				index = index - 1
			end
			
			if #self:getActiveElements() > 3 then
				self.frame.ScrollingEnabled = true
				self.frame.ScrollBarThickness = 10
			else
				self.frame.ScrollingEnabled = false
				self.frame.ScrollBarThickness = 0
			end
		end
		
		function notifContainer:add(notif)
			local notifIndex = table.find(self._notifs, notif)

			if not notifIndex then
				table.insert(self._notifs, notif)
				
				local subscribedEvents = {
					hidden = notif.hidden:connect(function()
						wait(2)
						if not notif.visible then
							local activeNotifs_count = #self:getActiveElements()
							
							if activeNotifs_count == 0 then
								self:hide()
							end
						end
					end);
					
					shown = notif.shown:connect(function()
						self:sort()
					end)
				}
				
				self._subscribedNotifs[notif] = subscribedEvents
			end
		end
		
		function notifContainer:remove(notif)
			local notifIndex = table.find(self._notifs, notif)
			
			if notifIndex then
				table.remove(self._notifs, notifIndex)
				
				if notif.visible then
					self:sort()
				end
				
				local subscribedEvents = self._subscribedNotifs[notif]
				
				if subscribedEvents then
					for i,event in pairs(subscribedEvents) do
						event:Disconnect()
					end
					
					self._subscribedNotifs[notif] = nil
				end
			end
		end
		
		notifContainer._object.DisplayOrder = 300
		
		local playerGui = service.playerGui
		
		notifContainer.parent = playerGui
		if not playerGui then
			client.playerGui_Found:connectOnce(function(plrGui)
				notifContainer.parent = plrGui
				notifContainer:show()
			end)
		end
		
		variables.notifContainer = notifContainer
		
		return notifContainer
	end
end