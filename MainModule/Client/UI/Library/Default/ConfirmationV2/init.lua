
return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service
	local variables = envArgs.variables
	
	local Promise = client.Promise
	
	local container = variables.confirmV2Container or client.UI.construct("ConfirmationHandler")

	container._object.DisplayOrder = 200
	container.parent = service.playerGui
	
	local confirmation = client.UI.makeElement("ConfirmationV2", data)
	confirmation.containerData = container
	
	container:add(confirmation)
	confirmation:show()
	
	if data.returnChoice or data.returnOutput then
		local timeoutDuration = 1200 
		local expectedTimeoutDuration = math.clamp(if confirmation.timeDuration and confirmation.timeDuration > 0 then confirmation.timeDuration+10 else timeoutDuration, 10, timeoutDuration)
		local returnValues = {client.Signal:waitOnSingleEvents({confirmation.submitted, confirmation.hidden}, nil, expectedTimeoutDuration)}
		
		if not returnValues[1] then
			confirmation.submissionPage = {
				title = "Return Value timeout";
				description = "Confirmation timed out after "..client.Parser:relativeTime(expectedTimeoutDuration);
				duration = 5;
			}
			
			if confirmation.showState then
				if confirmation._showTask then
					confirmation._showTask:cancel()
					confirmation._showTask = nil
				end
				
				confirmation:cancelInputEvents()
				
				Promise.promisify(confirmation.showSubmission)(confirmation, true)
					:andThenCall(Promise.delay, 5+1)
					:andThenCall(confirmation.hide, confirmation)
			end
		end
		
		return returnValues[1]
	end
	
	return confirmation
end