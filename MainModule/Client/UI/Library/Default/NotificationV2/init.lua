return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service
	local getEnv = envArgs.getEnv
	local variables = envArgs.variables
	local notifContainer = variables.notifV2Container
	
	local Signal = client.Signal

	if not notifContainer then
		notifContainer = client.UI.construct "Handlers.Notifications"
		variables.notifV2Container = notifContainer
	end

	local notification = client.UI.makeElement("NotifV2", data)
	notification.containerData = notifContainer

	notifContainer:add(notification)
	
	if data.returnStateOnInteraction then
		local didOpen = Signal:waitOnSingleEvents({notification.opened}, nil, 300)
		if notification.showState then
			task.defer(notification.hide, notification)
		end
		
		return didOpen or false
	end

	return notification
end
