
return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service
	local variables = envArgs.variables
	
	local getEnv = envArgs.getEnv
	
	local container = client.UI.makeElement("Container")
	
	
	container._object.DisplayOrder = 200
	container.parent = service.playerGui
	if not service.playerGui then
		client.playerGui_Found:connectOnce(function(plrGui)
			container.parent = plrGui
			container:show()
		end)
	end
	
	local responseType = data.responseType or data.respType or "default"
	local responseOptions = data.options or {}
	
	local multiChoice = client.UI.makeElement("MultipleChoice", data)
	multiChoice.containerData = container
	multiChoice._object.Name = service.getRandom()
	
	multiChoice.responseType = responseType
	
	if responseType == "vote" then
		local voteCheck = data.voteCheck
		
		if type(voteCheck) == "string" then
			voteCheck = client.Loadstring(voteCheck, getEnv(nil, {player = service.player;}))
		elseif type(voteCheck) == "function" then
			voteCheck = voteCheck
		elseif type(voteCheck) == "table" then
			local checkType = voteCheck.type
			
			if checkType == "Session" then
				local sessionId,submitResultsId,checkResultsId = voteCheck.sessionId, voteCheck.submitResultsId, voteCheck.checkResultsId
				warn("Results id:", checkResultsId)
				
				multiChoice.submitted:connectOnce(function(selectedOpts)
					client.Network:fire("ManageSession", sessionId, "RunCommand", submitResultsId, selectedOpts)
				end)
				
				multiChoice.voteCheck = function(selectedOpts)
					warn("vote check 1")
					warn("selected opts:", selectedOpts)
					local ee = client.Network:get("ManageSession", sessionId, "RunCommand", checkResultsId, selectedOpts)
					warn("vote checK:", ee)
					return ee
				end
				
				voteCheck = nil
			end
		else
			voteCheck = nil
		end
		
		if voteCheck then
			multiChoice.voteCheck = voteCheck
		end
	else
		local publishData = data.publishData
		local publishFunc = data.publishFunc
		
		if type(publishFunc) == "string" then
			publishFunc = client.Loadstring(publishFunc, getEnv(nil, {player = service.player;}))
		elseif type(publishFunc) == "function" then
			publishFunc = publishFunc
		else
			publishFunc = nil
		end
		
		
		if publishFunc then
			multiChoice.submitted:connectOnce(publishFunc)
		else
			if type(publishData) == "table" then
				local publishDataType = publishData.type
				
				if publishDataType == "Session" then
					local sessionId,submitId = publishData.sessionId, publishData.submitId
					
					multiChoice.submitted:connectOnce(function(selectedOpts)
						client.Network:fire("ManageSession", sessionId, "RunCommand", submitId, selectedOpts)
					end)
				end
			end
		end
	end
	
	local respTime = math.clamp(math.round(tonumber(data.time) or 0), 0, math.huge)
	multiChoice:show(responseOptions, (respTime>0 and respTime) or nil)
	
	if data.returnGui then
		return multiChoice
	elseif not data.noYield then
		return client.Signal:waitOnSingleEvents({multiChoice.submitted, multiChoice.hiding}, nil, (respTime>0 and respTime) or nil)
	end
end