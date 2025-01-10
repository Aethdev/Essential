
return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service
	
	local variables = envArgs.variables
	
	local msgType = (data.type=="Message" and "Message") or "Hint"
	local msgContainerName = msgType.."Container"
	local msgListName = msgType.."-Messages"
	
	local container = variables[msgContainerName] or client.UI.makeElement("Container",{type = "Messages";})
	variables[msgContainerName] = container
	
	local msgList = variables[msgListName]
	
	if not msgList then
		msgList = {}
		variables[msgListName] = msgList
	end
	
	if not container._frame or container._frame.Parent ~= container._object then
		container._frame = service.New("Frame",{
			Parent = container._object;
			
			Name = service.getRandom();
			AnchorPoint = (data.type=="Message" and Vector2.new(0.5, 0.5)) or Vector2.new(0.5, 0);
			BackgroundTransparency = 1;
			Position = (data.type=="Message" and UDim2.new(0.5, 0, 0.5, 0)) or UDim2.new(0.5, 0, 0, 20);
			Size = (data.type=="Message" and UDim2.new(0, 600, 0, 300)) or UDim2.new(0, 600, 0, 76);
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
	
	local message = client.UI.makeElement("Message",{
		title = data.title;
		descrip = data.descrip;
		time = data.time;
		container = container;
		type = msgType;
	})
	
	message.hidden:connectOnce(function()
		local messageInd = table.find(msgList, message)
		
		if messageInd then
			table.remove(msgList, messageInd)
		end
	end)
	
	for i,msg in pairs(msgList) do
		coroutine.wrap(msg.hide)(msg)
		msgList[i] = nil
	end
	
	table.insert(msgList, message)
	message:show(data.time)
end