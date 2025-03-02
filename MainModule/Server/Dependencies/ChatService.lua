--!nocheck
local ChatService = {
    Type = "TextChat"; --// Supported options: TextChat
    TextChannels = {
        Prototype = {};
        _list = {};
    };
    TextSpeakers = {
        Prototype = {};
        _list = {};
    };
    SlashCommands = {
        _list = {};
    };
    Networks = {};

    InternalChatCallbacks = {};
}

local server, settings, service;
local Parser, Process, Remote, Network, Logs, Signal;
local TextChatService = game:GetService("TextChatService")

-- ChatService TextChannel Prototype
ChatService.TextChannels.Prototype.__index = ChatService.TextChannels.Prototype

function ChatService.TextChannels.new(channelName: string, existingChannel: TextChannel?, addedFromChildEvent: boolean?)
    if ChatService.TextChannels._list[channelName] then return ChatService.TextChannels._list[channelName] end
    if existingChannel and ChatService.TextChannels:getFromInstance(existingChannel) then
        return ChatService.TextChannels:getFromInstance(existingChannel)
    end
    
    channelName = if channelName then channelName elseif existingChannel then existingChannel.Name else service.getRandom()
    
    local self = setmetatable({}, ChatService.TextChannels.Prototype)
    ChatService.TextChannels._list[channelName] = self

    self.active = true
    self._channelName = channelName    
    self._events = Signal:createHandler()
    self._addedFromChildEvent = addedFromChildEvent and true or false
    self._object = if existingChannel and typeof(existingChannel) == "Instance" and existingChannel:IsA("TextChannel")
        then existingChannel else (service.New("TextChannel", {
            Name = `{channelName}`;
            Parent = TextChatService:WaitForChild("TextChannels", 30) or
                service.New("Folder", {
                    Name = "TextChannels";
                    Parent = TextChatService;
                });
        })) :: TextChannel

    --// Because Adonis usually runs their callback system instantly after child creation, we will wait 1 second after them
    if not table.find(settings.ChatService_IgnoreChannels, channelName) then
        task.delay(if existingChannel and addedFromChildEvent then 2 else 0, function()
            service.loopTask(`Channel {self._channelName} lock callback`, 1, function()
                self._object.ShouldDeliverCallback = ChatService.internalTextChatPostMessageCallback
            end)
        end)
    end

    --// Collect all the TextSources
    for i, textSource in self._object:GetChildren() do
        if textSource:IsA("TextSource") then
            ChatService.TextSpeakers:registerSourceFromChannel(textSource, self._object)
        end
    end

    local childAdded = self._events.new(`CheckEvent`)
    childAdded:linkRbxEvent(self._object.ChildAdded)
    childAdded:connect(function(child: Instance)
        if child:IsA"TextSource" and child.UserId > 0 then
            ChatService.TextSpeakers:registerSourceFromChannel(child, self._object)
        end
    end)
    self.childAdded = childAdded

    local childRemoved = self._events.new(`CheckEvent`)
    childRemoved:linkRbxEvent(self._object.ChildRemoved)
    childRemoved:connect(function(child: Instance)
        if child:IsA"TextSource" and child.UserId > 0 then
            ChatService.TextSpeakers:deregisterSourceFromChannel(child, self._object)
        end
    end)
    self.childRemoved = childRemoved

    return self
end

function ChatService.TextChannels:getFromInstance(textChannelObject: TextChannel)
    for i, otherTextChannelClass in ChatService.TextChannels._list do
        if otherTextChannelClass._object == textChannelObject then
            return otherTextChannelClass
        end
    end
    
    return nil
end
function ChatService.TextChannels:getFromName(channelName: string)
    for i, otherTextChannelClass in ChatService.TextChannels._list do
        if otherTextChannelClass._channelName == channelName then
            return otherTextChannelClass
        end
    end
    
    return nil
end

function ChatService.TextChannels.Prototype:destroy()
    if not self.active then return self end

    self.active = false
    self._events:killSignals()
    ChatService.TextChannels._list[self._channelName] = nil
    
    service.Delete(self._object)
    service.stopLoop(`Channel {self._channelName} lock callback`)

    return self
end

function ChatService.TextChannels:syncChannels()
    local TextChannels: Folder = TextChatService:WaitForChild("TextChannels", 30) or service.New(`Folder`, {
        Name = `TextChannels`;
        Parent = TextChatService;
    })

    for i, child: TextChannel in TextChannels:GetChildren() do
        if child:IsA("TextChannel") then
            ChatService.TextChannels.new(`.{child.Name}`, child, false)
        end
    end

    TextChannels.ChildAdded:Connect(function(child)
        if child:IsA("TextChannel") then
            ChatService.TextChannels.new(`.{child.Name}`, child, true)
        end
    end)

    TextChannels.ChildRemoved:Connect(function(child)
        if not child:IsA("TextChannel") then return end
        
        local textChannelClass = ChatService.TextChannels:getFromInstance(child)
        if textChannelClass and textChannelClass.active and textChannelClass._addedFromChildEvent then
            textChannelClass:destroy()
        end
    end)

    return self
end

ChatService.TextSpeakers.Prototype.__index = ChatService.TextSpeakers.Prototype

function ChatService.TextSpeakers.new(playerUserId: number)
    if ChatService.TextSpeakers._list[playerUserId] then return ChatService.TextSpeakers._list[playerUserId] end

    local self = setmetatable({}, ChatService.TextSpeakers.Prototype)
    ChatService.TextSpeakers._list[playerUserId] = self

    self._playerUserId = playerUserId
    self._textSources = {}

    self.muteState = false
    self.shadowMuted = false
    self.deafenState = false

    self.ignoreChannels = {} --// For example: {"RBXGeneral", "ESSComm", etc..}

    return self
end

function ChatService.TextSpeakers:deafenSpeaker(playerUserId: number)
    local textSpeaker = ChatService.TextSpeakers.new(playerUserId)
    textSpeaker:toggleDeafen(true)
    return self
end

function ChatService.TextSpeakers:undeafenSpeaker(playerUserId: number)
    local textSpeaker = ChatService.TextSpeakers.new(playerUserId)
    textSpeaker:toggleDeafen(false)
    return self
end

function ChatService.TextSpeakers.Prototype:toggleDeafen(newState: boolean)
    if newState == nil then newState = not self.deafenState end
    if self.deafenState == newState then return self end

    self.deafenState = newState
    self:toggleMute(newState)

    local realPlayer: Player = service.getPlayer(self._playerUserId)
    if realPlayer then
        realPlayer:SetAttribute("ESSDeafen", newState)
    end

    server.PolicyManager:setPolicyForPlayer(
        Parser:getParsedPlayer(self._playerUserId, true),
        `DEAFENED_PLAYER`,
        newState
    )

    return self
end

function ChatService.TextSpeakers:muteSpeaker(playerUserId: number, includeShadowMute: boolean?)
    local textSpeaker = ChatService.TextSpeakers.new(playerUserId)
    textSpeaker:toggleMute(true, includeShadowMute)
    return self
end

function ChatService.TextSpeakers:unmuteSpeaker(playerUserId: number)
    local textSpeaker = ChatService.TextSpeakers.new(playerUserId)
    textSpeaker:toggleMute(false)
    return self
end

function ChatService.TextSpeakers:toggleMuteForSpeaker(playerUserId: number, newState: boolean?)
    local textSpeaker = ChatService.TextSpeakers.new(playerUserId)
    textSpeaker:toggleMute(newState)
    return self
end

function ChatService.TextSpeakers.Prototype:toggleMute(newState: boolean?, includeShadowMute: boolean?)
    if newState == nil then newState = not self.muteState end
    if self.muteState == newState then return self end

    self.muteState = newState
    if newState and includeShadowMute then
        self.shadowMuted = true
    elseif not newState then
        self.shadowMuted = false
    end
    
    if not newState or newState then
        if not includeShadowMute then
            server.PolicyManager:setPolicyForPlayer(
                Parser:getParsedPlayer(self._playerUserId, true),
                `MUTED_PLAYER`,
                newState
            )
        end
    
        if not settings.ChatService_OverrideChatCallback then
            for i, textSourceAndChannel: {textChannel: TextChannel, textSource: TextSource} in self._textSources do
                if newState then
                    local currentCanSendState = textSourceAndChannel.textSource.CanSend
                    textSourceAndChannel.textSource:SetAttribute("OriginCanSend", currentCanSendState)
                    textSourceAndChannel.textSource.CanSend = false
                else
                    local previousCanSendState = textSourceAndChannel.textSource:GetAttribute("OriginCanSend")
                    if previousCanSendState ~= nil and type(previousCanSendState) == "boolean" then
                        textSourceAndChannel.textSource.CanSend = previousCanSendState
                    end
    
                    textSourceAndChannel.textSource:SetAttribute("OriginCanSend", nil)
                end

                -- Adonis attribute check
                if textSourceAndChannel.textSource:GetAttribute("OriginalCanSend") ~= nil then
                    warn(`WARNING! TextSource {textSourceAndChannel.textSource:GetFullName()} OriginalCanSend attribute is not nil. Adonis mute system may interfere.`)
                end
            end
        end
    end

    return self
end

function ChatService.TextSpeakers.Prototype:mute() return self:toggleMute(true) end
function ChatService.TextSpeakers.Prototype:unMute() return self:toggleMute(false) end

function ChatService.TextSpeakers:isSpeakerMuted(playerUserId: number, channelName: string?)
    local textSpeaker = ChatService.TextSpeakers.new(playerUserId)

    if channelName and table.find(textSpeaker.ignoreChannels, channelName) then
        return true
    end

    return textSpeaker.muteState
end

function ChatService.TextSpeakers:registerSourceFromChannel(textSource: TextSource, channelObject: TextChannel)
    local textSpeaker = ChatService.TextSpeakers.new(textSource.UserId)

    local canAddSource = true
    for i, textSourceAndChannel: {textChannel: TextChannel, textSource: TextSource} in textSpeaker._textSources do
        if textSourceAndChannel.textChannel == channelObject then
            canAddSource = false
            break;
        end
    end
    
    if canAddSource then
        table.insert(textSpeaker._textSources, {
            textChannel = channelObject;
            textSource = textSource;
        })
    end

    return self
end

function ChatService.TextSpeakers:deregisterSourceFromChannel(textSource: TextSource, channelObject: TextChannel)
    local textSpeaker = ChatService.TextSpeakers.new(textSource.UserId)

    for i, textSourceAndChannel: {textChannel: TextChannel, textSource: TextSource} in textSpeaker._textSources do
        if textSourceAndChannel.textChannel == channelObject then
            table.remove(textSpeaker._textSources, i)
            break;
        end
    end

    return self
end

function ChatService.internalTextChatPostMessageCallback(chatMessage: TextChatMessage, chatSource: TextSource)
    if chatMessage.Status == Enum.TextChatMessageStatus.Success or chatMessage.Status == Enum.TextChatMessageStatus.Sending then
        -- warn(`Processed internal post message callback`)

        for i, internalCallback: {name: string, priority: number, execute: () -> any} in ChatService.InternalChatCallbacks do
            local waitSignal = Signal.new()
            local success, result = true, nil;
            
            task.spawn(function()
                success, result = service.trackTask(`ChatService: Internal Callback {internalCallback.name}`, false, internalCallback.execute,
                    chatMessage, chatSource    
                )   
                waitSignal:fire()

                if not success then
                    Logs.addLog("Process",  `ChatService: Internal Callback {internalCallback.name} encountered an error: {tostring(result)}`)
                end
            end)

            waitSignal:wait(nil, 0.2)
            waitSignal:disconnect()

            if success and result == false then
                return false
            elseif success and result == 1 then
                return true
            elseif success and result ~= nil and type(result) ~= "boolean" then
                warn(`ChatService: Internal Callback {internalCallback.name} did not return a boolean value: {type(result)}`)
            end
        end


        return true
    end

    return false
end

function ChatService:getInternalPostMessageCallback(callbackName: string)
    for i, internalCallback: {name: string, priority: number, execute: () -> any} in ChatService.InternalChatCallbacks do
        if internalCallback.name == callbackName then
            return internalCallback
        end
    end

    return nil
end

function ChatService:deregisterInternalPostMessageCallback(callbackName: string)
    for i, internalCallback: {name: string, priority: number, execute: () -> any} in ChatService.InternalChatCallbacks do
        if internalCallback.name == callbackName then
            table.remove(ChatService.InternalChatCallbacks, i)
            table.sort(ChatService.InternalChatCallbacks, function(newest, oldest)
                return if oldest.priority == newest.priority then oldest._created > newest._created
                    else oldest.priority < newest.priority
            end)
            
            break
        end
    end

    return self
end

function ChatService:sendSystemMessage(message: string, listOfPlayers: {[number]: ParsedPlayer}?)
    if not ChatService.Networks.SendSystemMessage then return self end

    if not listOfPlayers then
        ChatService.Networks.SendSystemMessage:fire(message)
    else
        ChatService.Networks.SendSystemMessage:fireToSpecificPlayers(listOfPlayers, message)
    end
    
    return self
end

function ChatService:sendBubbleMessage(partOrCharacter: Instance, message: string, listOfPlayers: {[number]: ParsedPlayer}?)
    if not ChatService.Networks.SendBubble then return self end

    assert(typeof(partOrCharacter) == "Instance", `Argument 1 must be an Instance`)
    assert(type(message) == "string", `Argument 2 must be a string`)

    if not listOfPlayers then
        ChatService.Networks.SendBubble:fire(partOrCharacter, message)
    else
        ChatService.Networks.SendBubble:fireToSpecificPlayers(listOfPlayers, partOrCharacter, message)
    end
    
    return self
end

function ChatService:registerInternalPostMessageCallback(callbackName: string, priorityLevel: number, callbackFunction: (chatMessage: TextChatMessage) -> any)
    assert(type(callbackName) == "string", `Callback name must be a string`)
    assert(type(priorityLevel) == "number" and math.floor(priorityLevel) == priorityLevel and priorityLevel > 0, `Priority level must be an integer`)
    assert(type(callbackFunction) == "function", `Callback function must be a function`)

    local existingCallback = ChatService:getInternalPostMessageCallback(callbackName)
    if existingCallback then return existingCallback end

    table.insert(ChatService.InternalChatCallbacks, table.freeze{
        name = callbackName;
        priority = priorityLevel;
        execute = callbackFunction;
        _created = tick();
    })

    table.sort(ChatService.InternalChatCallbacks, function(newest, oldest)
        return if oldest.priority == newest.priority then oldest._created > newest._created
            else oldest.priority < newest.priority
    end)

    return self
end

ChatService.SlashCommands.__index = ChatService.SlashCommands

function ChatService.SlashCommands.new(slashCommandName: string, firstAlias: string, onTrigger: () -> any)
    if ChatService.SlashCommands._list[slashCommandName] then return ChatService.SlashCommands._list[slashCommandName] end

    local TextChatCommands: Folder = TextChatService:WaitForChild("TextChatCommands", 10) or service.New("Folder", {
        Name = `TextChatCommands`;
        Parent = TextChatService;
    })
    
    local self = setmetatable({
        _name = slashCommandName;
        _triggerCount = 0;
        _object = service.New("TextChatCommand", {
            Name = `ESS{slashCommandName}`,
            PrimaryAlias = "/"..firstAlias;
            Enabled = true;
            Parent = TextChatCommands;
        });

        onTrigger = onTrigger or function() end;

        enabled = true;
    }, ChatService.SlashCommands)

    self._triggerEvent = self._object.Triggered:Connect(function(originTextSource, unfilteredText)
        if not self.enabled then return end
        self._triggerCount += 1
        self.onTrigger(originTextSource, unfilteredText)
    end)

    ChatService.SlashCommands._list[slashCommandName] = self

    return self
end

function ChatService.SlashCommands:enable() self._object.Enabled = true; self.enabled = true; return self end
function ChatService.SlashCommands:disable() self._object.Enabled = false; self.enabled = false; return self end

function ChatService.SlashCommands:destroy()
    if not self.enabled then return self end
    
    self.enabled = false
    pcall(function()
        self._triggerEvent:Disconnect()
    end)

    service.Debris:AddItem(self._object, 0)

    ChatService.SlashCommands._list[self._name] = nil

    return self
end

function ChatService.SlashCommands:syncCommands()
    local SlashCommandPrefix = settings.ChatService_SlashCommandsPrefix

    task.delay(5, function()
        for commandName, commandTab in server.Commands.Library do
            local ignoreCommand = commandTab.Chattable==false or commandTab.NoSlashCommand==true
            local slashCommandAlias = SlashCommandPrefix..commandTab.Aliases[1]

            if ignoreCommand then continue end
            
            ChatService.SlashCommands.new(commandName, slashCommandAlias, function(originTextSource: TextSource, unfilteredText: string)
                if commandTab.Disabled then return end

                local parsedPlayer = Parser:getParsedPlayer(originTextSource.UserId)
                if not parsedPlayer then return end
                
                if settings.ChatService_SlashCommandsConfirmation then
                    local approveSlashCommandUse = parsedPlayer:customGetData(10+10, "MakeUI", "Confirmation", {
                        title = "Slash Command Confirmation",
                        desc = `Would you approve the use of this slash command <b>{Parser:filterForRichText(slashCommandAlias)}</b>?`
                            .. `\n<font face="Montserrat">{Parser:filterForRichText(unfilteredText)}</font>`,

                        choiceA = "Yes, I confirm.",
                        returnOutput = true,
                        time = 10,
                    })

                    if approveSlashCommandUse ~= 1 then return end
                end
                
                Process.playerCommand(parsedPlayer, nil, {
                    commandId = commandTab.Id,
                    commandInputArgs = Parser:getArguments(
                        unfilteredText:sub(utf8.len("/"..slashCommandAlias) + 1),
                        settings.delimiter,
                        {
                            maxArguments = math.max(#commandTab.Arguments, 1),
                        }
                    )
                })
            end)
        end
    end)
end

ChatService.Networks.Commands = {
    Test = { -- Disconnect from network
        Disabled = false, -- Is this remote command disabled? Enabling this will block all requests' call indexing this command
        Public = true, -- Allow this command to run publicly? This ignores whitelist and permissions.

        RL_Enabled = false,

        Permissions = {}, -- (optional) (table) List of user permissions the player must have to call this command
        Whitelist = {}, -- (table) List of users allowed to call this command
        Blacklist = {}, -- (table) List of users denied to call this command

        Lockdown_Allowed = false, -- (boolean) Allow this remote command to run during lockdown?

        Can_Invoke = true, -- (boolean) Allow invoke for this command? This command can work on RemoteFunctions if enabled.
        Can_Fire = false, -- (boolean) Allow fire for this command? This command can work on RemoteEvents if enabled.
        --> SIDE NOTE: IF NEITHER CAN_INVOKE AND CAN_FIRE ARE ENABLED, CAN_FIRE WILL BE ENABLED BY DEFAULT
        Function = function(plr, args, remoteData)
            
        end,
    },
}

function ChatService.Networks:setupNetwork()
    if self._setup then return self end

    self._setup = true
    
    local chatSubNetwork = Remote.newSubNetwork(`ChatService`, {
        joinable = true;
        easyFind = true;
        name = `ChatService`;
        securitySettings = {
            -- endToEndEncrypted = true;
        };
    })

    chatSubNetwork.processRLEnabled = true
    chatSubNetwork.processRateLimit = {
        Rates = 120,
        Reset = 120,
    }
    
    -- chatSubNetwork.securitySettings.endToEndEncrypted = true
    ChatService.Networks.Main = chatSubNetwork

    local chatSession = Remote.newSession()
    chatSession.allowedTriggers = {function() return true end}
    chatSession.easyFind = true
    chatSession.network = chatSubNetwork
    chatSession.name = "ChatSession"
    ChatService.Networks.Session = chatSession

    local SendSystemMessage = chatSession:makeEvent("SendSystemMessage")
    SendSystemMessage.canFire = false
    SendSystemMessage.canConnect = true
    SendSystemMessage.allowedTriggers = chatSession.allowedTriggers
    SendSystemMessage.maxPlayerConnections = 1
    ChatService.Networks.SendSystemMessage = SendSystemMessage

    local SendBubble = chatSession:makeEvent("SendBubble")
    SendBubble.canFire = false
    SendBubble.canConnect = true
    SendBubble.allowedTriggers = chatSession.allowedTriggers
    SendBubble.maxPlayerConnections = 1
    ChatService.Networks.SendBubble = SendBubble
    
    return self
end

function ChatService.Init(env)
    server, settings, service = env.server, env.settings, env.service
    Parser = server.Parser
    Process = server.Process
    Remote = server.Remote
    Network = server.Network
    Logs = server.Logs
    Signal = server.Signal
    
    if not settings.ChatService_Enabled then return end
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        ChatService.Networks:setupNetwork()

        if settings.ChatService_SlashCommandsEnabled then
            task.defer(ChatService.SlashCommands.syncCommands, ChatService.SlashCommands)
        end

        if settings.ChatService_SecureInput then
            local ChatInputBarConfiguration = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
            if ChatInputBarConfiguration then
                ChatInputBarConfiguration.Enabled = false
            end

            -- local ChatWindowConfiguration = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
            -- if ChatWindowConfiguration then
            --     ChatWindowConfiguration.Enabled = false
            -- end
        end

        ChatService:registerInternalPostMessageCallback("MUTE CHECK", 20_000, function(chatMessage: TextChatMessage, targetChatSource: TextSource)
            warn(`Mute check [{chatMessage.TextSource.UserId} -> {targetChatSource.UserId}]`)
            if table.find(settings.ChatService_IgnoreChannels, chatMessage.TextChannel.Name) then return true end
            if ChatService.TextSpeakers:isSpeakerMuted(chatMessage.TextSource.UserId, chatMessage.TextChannel.Name) then
                local sourceSpeaker = ChatService.TextSpeakers.new(chatMessage.TextSource.UserId)
                
                if targetChatSource.UserId == chatMessage.TextSource.UserId then
                    if sourceSpeaker.shadowMuted then
                        warn(`Shadow muted for player {targetChatSource.UserId}`)
                        return 1
                    end
                    
                    ChatService:sendSystemMessage(`You do not have permission to speak in this channel. Your message is not visible to other players.`, {Parser:getParsedPlayer(chatMessage.TextSource.UserId)})   
                end
                
                return false
            end

            return true
        end)
        
        if settings.ChatService_FilterSupport then
            ChatService:registerInternalPostMessageCallback("FILTER CHECK", 10_000, function(chatMessage: TextChatMessage, targetChatSource: TextSource)
                warn(`Filter check [{chatMessage.TextSource.UserId} -> {targetChatSource.UserId}]`)
                local isSafeString, filteredString = server.Filter:safeString(Parser:reverseFilterForRichText(chatMessage.Text),
                    chatMessage.TextSource.UserId,
                    targetChatSource.UserId,
                    if chatMessage.TextChannel.Name == `RBXGeneral` then
                        Enum.TextFilterContext.PublicChat else Enum.TextFilterContext.PrivateChat
                )

                if not isSafeString then
                    local targetParsedPlayer = Parser:getParsedPlayer(targetChatSource.UserId)
                    local sourceParsedPlayer = Parser:getParsedPlayer(chatMessage.TextSource.UserId, true)
                    if targetChatSource.UserId ~= chatMessage.TextSource.UserId then
                        ChatService:sendSystemMessage(chatMessage.PrefixText..` {filteredString}`, {targetParsedPlayer})
                        if sourceParsedPlayer and sourceParsedPlayer.Character then
                            ChatService:sendBubbleMessage(sourceParsedPlayer.Character, filteredString, {targetParsedPlayer})
                        end
                    else
                        return true
                    end
                    

                    return false
                end

                return true
            end)
        end

        ChatService.TextChannels:syncChannels()

        -- Create Essential's System Channel
        local essSystemChannel = ChatService.TextChannels.new(`ESSComm`)
        ChatService.essSystemChannel = essSystemChannel
    else
        warn(`LEGACY CHAT IS NO LONGER SUPPORTED SINCE VERSION 0.9.0. UPDATE TO TEXTCHATSERVICE FOR FULL FUNCTIONALITY.`)
    end
end

return ChatService