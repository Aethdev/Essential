return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service

	local variables = envArgs.variables

	local container = variables.confirmContainer or client.UI.makeElement "Container"
	variables.confirmContainer = container

	if not container._frame or container._frame.Parent ~= container then
		if container._frame then service.Debris:AddItem(container._frame, 0) end

		local frame = service.New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 600, 0, 150),
			ClipsDescendants = true,

			Parent = container._object,
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

	local confirmation = client.UI.makeElement("Confirmation", {
		title = data.title,
		desc = data.desc,
		choiceA = data.choiceA,
		choiceB = data.choiceB,
	})

	confirmation.containerData = container

	confirmation:show(data.time)

	if data.returnOutput then return confirmation.chosen:wait(nil, data.time) end
end
