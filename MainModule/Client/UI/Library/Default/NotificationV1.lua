return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service
	local getEnv = envArgs.getEnv
	local variables = envArgs.variables
	local notifContainer = variables.notifContainer

	if not notifContainer then notifContainer = client.UI.construct "NotifHandler" end

	local notif = client.UI.makeElement "Notif"
	notif.title = data.title
	notif.desc = data.desc
	notif.container = notifContainer

	local time = tonumber(data.time)
	local openFunc = data.openFunc
	local closeFunc = data.closeFunc
	local runType = data.runType or data.executeType

	if runType == "session" then
		local sessionId, openNotifId, closeNotifId = data.sessionId, data.openNotifId, data.closeNotifId

		if sessionId and (openNotifId or closeNotifId) then
			if openNotifId then
				notif.opened:connectOnce(
					function(selectedOpts) client.Network:fire("ManageSession", sessionId, "RunCommand", openNotifId) end
				)
			end

			if closeNotifId then
				notif.closed:connectOnce(
					function(selectedOpts) client.Network:fire("ManageSession", sessionId, "RunCommand", closeNotifId) end
				)
			end
		end
	end

	if type(openFunc) == "string" then
		openFunc = client.Loadstring(openFunc, getEnv(nil, { notif = notif, ui = client.UI, player = service.player }))
	elseif type(openFunc) == "function" then
		openFunc = openFunc
	else
		openFunc = nil
	end

	if type(closeFunc) == "string" then
		closeFunc =
			client.Loadstring(closeFunc, getEnv(nil, { notif = notif, ui = client.UI, player = service.player }))
	elseif type(closeFunc) == "function" then
		closeFunc = closeFunc
	else
		closeFunc = nil
	end

	if openFunc then notif.opened:connect(openFunc) end

	if closeFunc then notif.closed:connect(closeFunc) end

	local openedState
	local closedState

	notif.opened:connectOnce(function() openedState = true end)

	notif.closed:connectOnce(function() closedState = true end)

	notifContainer:add(notif)

	notif:show(time)
	if not (data.noYield or data.noWait) then notif.hidden:wait() end
	return openedState, closedState
end
