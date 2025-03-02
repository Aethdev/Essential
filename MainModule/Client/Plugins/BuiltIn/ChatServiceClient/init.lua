--!nocheck
local shared = shared

return function(envArgs)
	local client = envArgs.client
	local service = envArgs.service
	local variables = envArgs.variables

	local getEnv = envArgs.getEnv
	local script = envArgs.script

	local Remote = client.Remote
	local UI = client.UI
	local Network = client.Network
	local Policies = client.Policies

	local Promise = client.Promise
	local Kill = client.Kill
	local Signal = client.Signal

	local localPlayer: Player = service.player
    local TextChatService: TextChatService = service.TextChatService

	local ChatClient = {
		Internals = {};
		Events = {};
		Settings = {
			maxNetworkConnectAttempts = 5;
			maxNetworkConnectAttemptDelay = 5;

			maxSessionConnectAttempts = 6;
			maxSessionConnectAttemptDelay = 5;
		};

		_muteState = false;
		_deafenState = false;
	}

	function ChatClient.Internals:setupNetwork()
		--// Connecting to the subnetwork
		Promise.retryWithDelay(
			function()
				return Promise.new(function(resolve, reject)
					ChatClient.SubNetwork = Network:connectSubNetwork("ChatService")
					if not ChatClient.SubNetwork then
						reject(true)
						return
					end
					
					resolve(true)
				end)
					:unWrap()
					:andThen(function(value) return value end)
			end,
			ChatClient.Settings.maxNetworkConnectAttempts,
			ChatClient.Settings.maxNetworkConnectAttemptDelay
		)
			:catch(function(err)
				UI.construct("Notification", {
					title = "Chat Client";
					description = "Failed to connect to the ChatService subnetwork."
						..(if err == true then "" else `<i>{tostring(err)}</i>`);
					time = 20;
				})

				return false
			end)
			:andThen(function(didConnectToSubNetwork: boolean)
				if not didConnectToSubNetwork then return end

				UI.construct("Notification", {
					title = "Chat Client";
					description = "Connected to the ChatService subnetwork successfully.";
					time = 10;
				})
				
				return Promise.retryWithDelay(
					function()
						return Promise.new(function(resolve, reject)
							local chatSessionId = ChatClient.SubNetwork:get("FindSession", "ChatSession")

							-- warn("remote session id:", chatSessionId)
							ChatClient.RemoteSession = chatSessionId and Remote.makeSession(chatSessionId, ChatClient.SubNetwork)
							-- warn("remote session:", ChatClient.RemoteSession)

							if not ChatClient.RemoteSession then
								reject(true)
								return
							end

							resolve(true)
						end)
							:unWrap()
							:andThen(function(value) return value end)
					end, 
					ChatClient.Settings.maxSessionConnectAttempts,
					ChatClient.Settings.maxSessionConnectAttemptDelay
				)
					:catch(function(err)
						UI.construct("Notification", {
							title = "Chat Client";
							description = "Failed to connect to the ChatService session."
								..(if err == true then "" else `<i>{tostring(err)}</i>`);
							time = 20;
						})

						return false
					end)
					:andThen(function(didConnectToSession)
						if not didConnectToSession then return end
						UI.construct("Notification", {
							title = "Chat Client";
							description = "Connected to the ChatService session successfully.";
							time = 10;
						})

						ChatClient.Internals:connectNetwork()
					end)
			end)	

		return self
	end

	function ChatClient.Internals:connectNetwork()
		if not (ChatClient.SubNetwork and ChatClient.RemoteSession) then return self end

		ChatClient.Events.SendSystemMessage = ChatClient.RemoteSession:connectEvent("SendSystemMessage")
		ChatClient.Events.SendSystemMessage:connect(function(remoteOs: number, message, channelName, customMetadata)
			ChatClient:sendSystemMessage(message, channelName, customMetadata)
		end)

		ChatClient.Events.SendBubble = ChatClient.RemoteSession:connectEvent("SendBubble")
		ChatClient.Events.SendBubble:connect(function(remoteOs: number, partOrCharacter: Instance, message: string)
			ChatClient:sendBubbleMessage(partOrCharacter, message)
		end)

		return self
	end

	function ChatClient.Internals:isNetworkActive(): boolean
		return ((ChatClient.SubNetwork and ChatClient.RemoteSession) and true) or false
	end

	function ChatClient.Internals:getChannel(channelName: string): TextChannel?
		local TextChannels = TextChatService:FindFirstChild("TextChannels")
		
		if TextChannels then
			local foundChannel = TextChannels:FindFirstChild(channelName)
			if foundChannel and foundChannel:IsA("TextChannel") then
				return foundChannel
			end
		end

		return nil
	end
	function ChatClient.Internals:getSelfSourceFromChannel(channelNameOrObject: string|TextChannel): TextSource?
		local textChannel = if type(channelNameOrObject) == "string" then
			ChatClient.Internals:getChannel(channelNameOrObject) else channelNameOrObject
		
		if textChannel then
			for i, textSource in textChannel:GetChildren() do
				if textSource:IsA("TextSource") and textSource.UserId == localPlayer.UserId then
					return textSource
				end
			end
		end

		return nil
	end

	function ChatClient.Internals:getChannels(): {[number]: TextChannel}
		local list = {}

		local TextChannels = TextChatService:FindFirstChild("TextChannels") or service.New("Folder", {
			Name = `TextChannels`;
			Parent = TextChatService;
		})

		for i, textChannel in TextChannels:GetChildren() do
			if textChannel:IsA("TextChannel") then
				table.insert(list, textChannel)
			end
		end

		return list
	end

	function ChatClient:toggleDeafen(newState: boolean?)
		if newState == nil then newState = not ChatClient._deafenState end
		if ChatClient._deafenState == newState then return self end

		ChatClient._deafenState = newState 

		local StarterGui: StarterGui = service.StarterGui
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not newState)
		
		local ChatWindowConfiguration = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if ChatWindowConfiguration then
			ChatWindowConfiguration.Enabled = not newState
		end
		
		ChatClient:toggleMute(newState)
		
		return self
	end
	
	function ChatClient:toggleMute(newState: boolean?)
		if newState == nil then newState = not ChatClient._muteState end
		if ChatClient._muteState == newState then return self end
		
		ChatClient._muteState = newState 
		
		local ChatInputBarConfiguration = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if ChatInputBarConfiguration then
			ChatInputBarConfiguration.Enabled = not newState
		end
		
		return self
	end

	function ChatClient:sendBubbleMessage(partOrCharacter: Instance, message: string)
		TextChatService:DisplayBubble(partOrCharacter, message)
		return self
	end

	function ChatClient:sendSystemMessage(systemMessage: string, channelName: string?, customMetadata: string?)
		local ChatInputBarConfiguration: ChatInputBarConfiguration =
			TextChatService:FindFirstChild("ChatInputBarConfiguration") or
			service.New("ChatInputBarConfiguration", {Parent = TextChatService;})

		local focusedChannel = (channelName and ChatClient.Internals:getChannel(channelName)) or
			ChatClient.Internals:getChannel("ESSComm") or
			ChatInputBarConfiguration.TargetTextChannel

		if focusedChannel then
			focusedChannel:DisplaySystemMessage(systemMessage, customMetadata or "Essential")
			return self
		end

		-- for i, textChannel: TextChannel in ChatClient.Internals:getChannels() do
		-- 	local textSource = ChatClient.Internals:getSelfSourceFromChannel(textChannel)
		-- 	if textSource then
		-- 		textChannel:DisplaySystemMessage(systemMessage, customMetadata or "Essential")
		-- 	end
		-- end

		return self
	end

	client.ChatClient = ChatClient

	
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then return end

	-- ChatClient:sendSystemMessage("<b>Welcome to Test Development 3</b>")
	
	local ServerSettings = client.Network:get(
		"GetSettings", 
		{ 
			"ChatService_Enabled", "ChatService_FilterSupport",
			"ChatService_SecureInput", "ChatService_OverrideChatCallback"
		}
	) or {}
	
    if not ServerSettings.ChatService_Enabled then return end
	ChatClient.Internals:setupNetwork()
	
	if ServerSettings.ChatService_SecureInput then
		local ChatInputBarConfiguration = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if ChatInputBarConfiguration and Policies._clientPolicies.MUTED_PLAYER.value ~= true then
			ChatInputBarConfiguration.Enabled = true
		end
	end

	do
		local ChatTagsModule = client.ChatTagsModule
		ChatTagsModule.OverrideChatCallback = ServerSettings.ChatService_OverrideChatCallback

		if ChatTagsModule.OverrideChatCallback then
			TextChatService.OnChatWindowAdded = ChatTagsModule.OnChatMessage
		else
			TextChatService.MessageReceived:Connect(ChatTagsModule.OnChatMessage)
			TextChatService.SendingMessage:Connect(ChatTagsModule.OnChatMessage)
		end

		local basicTextChat = service.player:FindFirstChildOfClass("PlayerScripts")
			and service.player:FindFirstChildOfClass("PlayerScripts"):FindFirstChild("BasicTextChat")
			or service.ReplicatedFirst:FindFirstChild("BasicTextChat")

		if basicTextChat then
			basicTextChat.Disabled = true
			service.Debris:AddItem(basicTextChat, 1)
		end
	end
	
	do
		local currentlyDeafened = Policies._clientPolicies.DEAFENED_PLAYER.value == true
		if currentlyDeafened then
			ChatClient:toggleDeafen(true)
		end
		
		Policies:connectPolicyChangeEvent("DEAFENED_PLAYER", function(state)
			ChatClient:toggleDeafen(state)
		end)
	end

	do
		local currentlyMuted = Policies._clientPolicies.MUTED_PLAYER.value == true
		if currentlyMuted then
			ChatClient:toggleMute(true)
		end

		Policies:connectPolicyChangeEvent("MUTED_PLAYER", function(state)
			ChatClient:toggleMute(state)
		end)
	end
end
