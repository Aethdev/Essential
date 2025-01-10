
return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service
	local Signal = client.Signal

	local variables = envArgs.variables
	
	local Parser = client.Parser
	local Network = client.Network
	local UI = client.UI

	local constructUI = UI.construct
	local constructElement = UI.makeElement
	
	local guiName = data.customName or "_RESP-"..service.getRandom()
	
	local guiContainer = constructElement("Container")
	guiContainer._object.DisplayOrder = 100
	guiContainer.parent = service.playerGui
	
	local responseEntry = constructElement("ResponseEntry", data)
	responseEntry.containerData = guiContainer
	
	local registUI =  UI.register(guiContainer._object, guiName)
	if data.allowRemoteClose then
		registUI.allowRemoteClose = true
		registUI.destroyed:connectOnce(function()
			responseEntry:hide()
		end)
	end
	
	
	if data.submitSessionId and data.submitEntryId then
		responseEntry.canSubmitInput = true
		local event; event = responseEntry.submitted:connect(function()
			client.Network:fire("ManageSession", data.submitSessionId, "RunCommand", data.submitEntryId, responseEntry.currentInput)
			
			if data.closeAfterSubmission then
				event:Disconnect()
				responseEntry:hide()
				registUI:destroy()
			end
		end)
	end
	
	responseEntry:setup()
	responseEntry:show()
	
	if data.time then
		task.delay(data.time, function()
			responseEntry:submit()
			responseEntry:hide()
		end)
	end
	
	if responseEntry.canSubmitInputOnReturn and not (responseEntry.canSubmitInput or responseEntry.canSubmitInputOnClose) then
		responseEntry.canSubmitInput = true
		responseEntry.guiTopSave.Visible = true
		local resp = Signal:waitOnSingleEvents({ responseEntry.submitted, responseEntry.hidden })
		responseEntry:hide()
		return resp
	else
		return responseEntry
	end
end