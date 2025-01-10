
return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service

	local variables = envArgs.variables
	
	local container = variables.pmContainer or client.UI.makeElement("Container")
	variables.pmContainer = container
	
	if not container._frame or container._frame.Parent ~= container then
		if container._frame then
			service.Debris:AddItem(container._frame, 0)
		end
		
		local frame = service.New("Frame",{
			AnchorPoint = Vector2.new(0.5, 0.5);
			BackgroundTransparency = 1;
			Position = UDim2.new(0.5, 0, 0.5, 0);
			Size = UDim2.new(0, 400, 0, 280);
			ClipsDescendants = true;
			
			Parent = container._object;
		})
		
		container._frame = frame
	else
		container._frame.Visible = true
	end
	
	container._object.DisplayOrder = 100
	container.parent = service.playerGui
	if not service.playerGui then
		client.playerGui_Found:connectOnce(function(plrGui)
			container.parent = plrGui
			container:show()
		end)
	end
	
	local privateMessage = client.UI.makeElement("PrivateMessage", {
		title = data.title;
		message = data.message;
		placement = data.placement;
	})
	
	container:show()
	privateMessage.containerData = container	
	privateMessage:show(data.time)
	
	if data.onlyReturn then
		return privateMessage.responded:wait()
	elseif data.publishId then
		privateMessage.responded:wait(nil, data.time)
		client.Network:fire("PrivateMessage", data.publishId, privateMessage.response)
	end
end
