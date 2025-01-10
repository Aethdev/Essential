
return function(envArgs)
	local client = envArgs.client
	local service = envArgs.service
	
	local base64 = client.Base64
	
	local Signal = client.Signal
	
	local isClientAlive = client.IsAlive
	local kill = client.Kill
	
	local TopbarIconTheme = client.TopbarIconTheme
	
	local messages = {}
	local messagesTopbar;
	
	local function updateStats()
		local readMessages = 0
		
		if readMessages > 0 then
			messagesTopbar:clearNotices()
			for i = 1, readMessages, 1 do
				messagesTopbar:notify()
			end
		end
	end
	
	local function setupTopbarIcon()
		if messagesTopbar then return end
		messagesTopbar = client.UI.makeElement("TopbarIcon")
		messagesTopbar:setTheme(TopbarIconTheme)
		messagesTopbar:setName(service.getRandom())
		messagesTopbar:setImage("rbxassetid://14428286056")
		messagesTopbar:setCaption("My Messages")
		messagesTopbar:setOrder(10)
		messagesTopbar:setRight()
	end
	
	client.Events.quickActionReady:connectOnce(function()
		setupTopbarIcon()
	end)
end