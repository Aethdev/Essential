return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service

	local variables = envArgs.variables

	local msgType = "Message"
	local msgContainerName = msgType .. "Container2"
	local msgListName = msgType .. "-Messages2"

	local container = variables[msgContainerName] or client.UI.makeElement("Container", { type = "Messages" })
	variables[msgContainerName] = container

	local msgList = variables[msgListName]

	if not msgList then
		msgList = {}
		variables[msgListName] = msgList
	end

	if not container._frame or container._frame.Parent ~= container._object then
		container._frame = service.New("Frame", {
			Parent = container._object,

			Name = service.getRandom(),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 600, 0, 400),
		})
	end

	container._object.DisplayOrder = 100
	container.parent = service.playerGui
	if not service.playerGui then
		client.playerGui_Found:connectOnce(function(plrGui)
			container.parent = plrGui
			container:show()
		end)
	end

	container:show()

	local message = client.UI.makeElement("MessageV2", {
		title = data.title,
		descrip = data.descrip,
		time = data.time,
		container = container,
	})

	message.hidden:connectOnce(function()
		local messageInd = table.find(msgList, message)

		if messageInd then table.remove(msgList, messageInd) end
	end)

	for i, msg in pairs(msgList) do
		coroutine.wrap(msg.hide)(msg)
		msgList[i] = nil
	end

	table.insert(msgList, message)
	message:show(data.time, data.hideTimer)
end
