--[[
	Basic TextChatTags module
		> Made by trzistan
		
	
		This module creates chat tags and display text for Text Chat
]]
--!nonstrict

local TextChatModule = {
	OverrideChatCallback = script:GetAttribute("OverrideChatCallback") or false;
}

local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")


local function CorrectValue(expectedValueType: string, defaultValue: any, givenValue: any)
	local isGivenValueCorrect = type(givenValue) == expectedValueType or typeof(givenValue) == expectedValueType

	if not isGivenValueCorrect then return defaultValue end
	return givenValue
end

function TextChatModule:GetSpeakerNameColor(speakerName: string)
	local value = 0
	
	for i = 1, #speakerName do
		local cValue = string.byte(speakerName, i)
		value = value + cValue
	end
	
	local NAME_COLORS = {
		Color3.new(253/255, 41/255, 67/255), Color3.new(1/255, 162/255, 255/255), Color3.new(2/255, 184/255, 87/255),   
		BrickColor.new("Bright violet").Color,
		BrickColor.new("Bright orange").Color,
		BrickColor.new("Bright yellow").Color,
		BrickColor.new("Light reddish violet").Color,
		BrickColor.new("Brick yellow").Color,
	}

	return NAME_COLORS[value % #NAME_COLORS + 1]
end

function TextChatModule:GetChatTags(player: Player): {
	[number]: {
		Text: string,
		TagFont: Font,
		Color: Color3,
		GradientColor: ColorSequence,
		Priority: number
	}
}?
	local ChatTagsFolder = player:FindFirstChild("ChatTags") or player:FindFirstChild("chattags")
	if not ChatTagsFolder then return nil end
	if ChatTagsFolder:GetAttribute("Hidden") == true then return nil end

	local ChatTagResults = {}

	for i, chatTag in ChatTagsFolder:GetChildren() do
		if chatTag:IsA("StringValue") then
			if chatTag:GetAttribute("Enabled") ~= true then continue end

			local tagFont = CorrectValue("Font", Font.fromEnum(Enum.Font.Gotham), chatTag:GetAttribute("Font"))
			local tagColor = CorrectValue("Color3", TextChatService.ChatWindowConfiguration.TextColor3, chatTag:GetAttribute("Color"))
			local tagGradientColor = CorrectValue("ColorSequence", nil, chatTag:GetAttribute("GradientColor"))
			local tagPriority = CorrectValue("number", 0, chatTag:GetAttribute("Priority"))

			table.insert(ChatTagResults, {
				Text = chatTag.Value;
				TagFont = tagFont;
				Color = tagColor;
				GradientColor = tagGradientColor;
				Priority = tagPriority;
			})
		end
	end

	table.sort(ChatTagResults, function (chatTagA, chatTagB)
		return chatTagA.Priority > chatTagB.Priority
	end)

	return ChatTagResults
end

TextChatModule.OnChatMessage = function(message: TextChatMessage)
	if not message.TextSource then return nil end

	local messagePlayer: Player = Players:GetPlayerByUserId(message.TextSource.UserId)
	if not messagePlayer then return nil end


	local newPrefixText = ""
	local playerChatTags = TextChatModule:GetChatTags(messagePlayer)
	local chatGradientColor;

	if playerChatTags and #playerChatTags > 0 then
		chatGradientColor = playerChatTags[1].GradientColor

		for i, chatTag in playerChatTags do
			if chatTag.GradientColor and not chatGradientColor then
				chatGradientColor = chatTag.GradientColor
			end
			newPrefixText = newPrefixText .. (if i == 1 then "" else " ") .. `<font{if chatGradientColor and chatTag.chatGradientColor == chatTag.GradientColor then "" else " color='#"..chatTag.Color:ToHex().."'"} family='{chatTag.TagFont.Family}'>{chatTag.Text}</font>`
		end
	end
	
	local DisplayName = CorrectValue("string", messagePlayer.DisplayName, messagePlayer:GetAttribute("DisplayName"))
	local DisplayNameColor = CorrectValue("Color3", if messagePlayer.Neutral then TextChatModule:GetSpeakerNameColor(DisplayName) else messagePlayer.TeamColor.Color, messagePlayer:GetAttribute("DisplayNameColor"))
	local MessageTextColor = CorrectValue("Color3", TextChatService.ChatWindowConfiguration.TextColor3, messagePlayer:GetAttribute("MessageColor"))
	
	local PrefixText = (if #newPrefixText > 0 then newPrefixText.." " else "") .. "<font color='#"..DisplayNameColor:ToHex().."'>"..DisplayName.."</font>:"

	local newProperties: ChatWindowMessageProperties | nil = if TextChatModule.OverrideChatCallback then TextChatService.ChatWindowConfiguration:DeriveNewMessageProperties() else nil

	if chatGradientColor and newProperties then
		local UIGradient = Instance.new("UIGradient")
		UIGradient.Color = chatGradientColor

		if TextChatModule.OverrideChatCallback then
			newProperties.PrefixTextProperties = TextChatService.ChatWindowConfiguration:DeriveNewMessageProperties()
		end
		
		UIGradient.Parent = newProperties.PrefixTextProperties
	end

	if TextChatModule.OverrideChatCallback then
		if newProperties then
			newProperties.TextColor3 = MessageTextColor
			newProperties.PrefixText = PrefixText
		end

		return newProperties
	end
	
	message.PrefixText = PrefixText


	return message
end

return TextChatModule