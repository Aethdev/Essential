--!nocheck
local TextChatService = game:GetService("TextChatService")
local ChatTagsModule = require(script.ChatTagsModule)

if ChatTagsModule.OverrideChatCallback then
	TextChatService.OnChatWindowAdded = ChatTagsModule.OnChatMessage
else
	TextChatService.MessageReceived:Connect(ChatTagsModule.OnChatMessage)
	TextChatService.SendingMessage:Connect(ChatTagsModule.OnChatMessage)
end