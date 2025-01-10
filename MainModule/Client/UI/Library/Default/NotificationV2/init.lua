
return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service
	local getEnv = envArgs.getEnv
	local variables = envArgs.variables
	local notifContainer = variables.notifV2Container
	
	if not notifContainer then
		notifContainer = client.UI.construct("Handlers.Notifications")
		variables.notifV2Container = notifContainer
	end
	
	local notification = client.UI.makeElement("NotifV2", data)
	notification.containerData = notifContainer
	
	notifContainer:add(notification)
	
	return notification
end