return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service
	local variables = envArgs.variables

	local UI = client.UI
	local Signal = client.Signal

	local container = UI.makeElement "Container"

	--if not container._frame or container._frame.Parent ~= container then
	--	if container._frame then
	--		service.Debris:AddItem(container._frame, 0)
	--	end

	--	local frame = service.New("Frame",{
	--		--AnchorPoint = Vector2.new(0.5, 0.5);
	--		BackgroundTransparency = 1;
	--		Position = UDim2.new(0, 0, 0, 0);
	--		Size = UDim2.new(0, 450, 0, 244);
	--		ClipsDescendants = true;

	--		Parent = container._object;
	--	})

	--	container._frame = frame
	--end

	container._object.DisplayOrder = 100
	container.parent = service.playerGui
	if not service.playerGui then
		client.playerGui_Found:connectOnce(function(plrGui)
			container.parent = plrGui
			container:show()
		end)
	end

	local containerGuiData = UI.register(container._object)
	local privateMessage = UI.makeElement("PrivateMessageV2", {
		title = data.title,
		desc = data.desc,
		bodyDetail = data.message or data.bodyDetail,
		placement = data.placement,
		guiData = containerGuiData,
		readOnly = data.readOnly or false,
	})

	local containerFrameModifier = UI.modifyObject(privateMessage.mainFrame, containerGuiData)
	containerFrameModifier:enableDrag(false, true)
	containerFrameModifier.dragObject = privateMessage.topFrame

	containerFrameModifier:enableResize {
		minimumSize = Vector2.new(450, privateMessage.mainFrame.AbsoluteSize.Y),
		wallsEnabled = true,
	}

	privateMessage.containerFrameModifier = containerFrameModifier

	privateMessage.containerData = container
	privateMessage:show(data.time)

	if data.onlyReturn then
		return Signal:waitOnSingleEvents({ privateMessage.replied, privateMessage.hidden }, nil, data.time)
	elseif data.publishId then
		privateMessage.replied:connectOnce(
			function(dataResponse) client.Network:fire("PrivateMessage", data.publishId, dataResponse) end
		)
	else
		return privateMessage
	end
end
