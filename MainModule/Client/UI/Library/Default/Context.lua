return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service
	local getEnv = envArgs.getEnv
	local variables = envArgs.variables
	local DateTime = envArgs.DateTime

	local Promise = client.Promise
	local contextContainer = variables.contextContainer

	if not contextContainer then contextContainer = client.UI.construct "ContextHandler" end

	local time = tonumber(data.time)
	local expireOs = tonumber(data.expireOs)

	if expireOs then
		if expireOs - tick() <= 0 then return end

		data.timelapseFrom = expireOs
	end

	local context = client.UI.makeElement("Context", data)
	context.containerData = contextContainer
	context._id = client.Base64.encode(`{DateTime.now().UnixTimestampMillis}-{tostring(data.plainText or data.text)}`)
	context._priority = data._priority or 0

	contextContainer:add(context)

	if type(data.options) == "table" then
		Promise.each(data.options, function(optionCreationData: {
			label: string;
			labelColor: Color3?;
			backgroundColor: Color3?;
			onExecute: () -> any?|string?;
			
			_priority: number?;
		})
			context:createOption(optionCreationData)
		end)
			:catch(function(err)
				local errMessage = tostring(err)

				warn(`List of options process failed to load: {errMessage}`)
			end)
	end

	context.time = (expireOs and expireOs - os.time()) or time
	context.expireOs = expireOs
	context:show(context.time)

	context.hidden:connectOnce(function()
		if not (context.forceHide or context.forceRemove) then
			wait(1)
			contextContainer:remove(context)
			contextContainer:sort()
		end
	end)

	return context
end
