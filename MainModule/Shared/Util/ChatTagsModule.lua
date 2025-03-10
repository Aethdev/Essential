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
local LocalPlayer = Players.LocalPlayer


local function CorrectValue(expectedValueType: string, defaultValue: any, givenValue: any)
	local isGivenValueCorrect = type(givenValue) == expectedValueType or typeof(givenValue) == expectedValueType

	if not isGivenValueCorrect then return defaultValue end
	return givenValue
end

local function FilterStringWithDictionary(str: string, dictionary: { [number]: {} })
	assert(type(str) == "string", "Argument 1 must be a string")
	assert(type(dictionary) == "table", "Argument 2 must be a table")

	local newString = str
	local function filterPattern(selected: string, entryArray: {})
		local matchPattern: string = entryArray[1]
		local substitution: string = entryArray[2]
		local substitutionType: string | (...any) -> any = type(substitution)
		local isOneCharacter: boolean = entryArray[4]

		if isOneCharacter then
			local newSelected = {}

			for i = 1, utf8.len(selected), 1 do
				local letter = selected:sub(i, i)

				if letter == matchPattern then
					table.insert(newSelected, substitution)
				else
					table.insert(newSelected, letter)
				end
			end

			return table.concat(newSelected)
		end

		return select(1, string.gsub(selected, matchPattern, substitution))
	end

	for i, strMatchArray in dictionary do
		newString = filterPattern(newString, strMatchArray)
	end

	return newString
end

local function FilterForRichText(str: string): string
	return FilterStringWithDictionary(str, {
		{ "&", "&amp;" },
		{ "<", "&lt;" },
		{ ">", "&gt;" },
		{ '"', "&quot;" },
		{ "'", "&apos;" },
	})
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

			local tagFont = CorrectValue("Font", Font.fromEnum(Enum.Font.Gotham), if chatTag:GetAttribute("Font") then Font.fromEnum(chatTag:GetAttribute("Font")) else nil)
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
			
			newPrefixText = newPrefixText .. (if i == 1 then "" else " ") .. `<font{if chatGradientColor and chatTag.chatGradientColor == chatTag.GradientColor then "" else " color='#"..chatTag.Color:ToHex().."'"} family='{chatTag.TagFont.Family}'>{FilterForRichText(chatTag.Text)}</font>`
		end
	end
	
	local DisplayName = CorrectValue("string", messagePlayer.DisplayName, messagePlayer:GetAttribute("DisplayName") or messagePlayer:GetAttribute("ChatTag"))
	local DisplayNameColor = CorrectValue("Color3", if messagePlayer.Neutral then TextChatModule:GetSpeakerNameColor(DisplayName) else messagePlayer.TeamColor.Color,
		messagePlayer:GetAttribute("DisplayNameColor") or messagePlayer:GetAttribute("ChatNameColor"))
	local MessageTextColor = CorrectValue("Color3", TextChatService.ChatWindowConfiguration.TextColor3,
		messagePlayer:GetAttribute("MessageColor") or messagePlayer:GetAttribute("ChatTagColor"))
	
	local PrefixText = (if #newPrefixText > 0 then newPrefixText.." " else "") .. "<font color='#"..DisplayNameColor:ToHex().."'>"..DisplayName.."</font>:"

	local newProperties: ChatWindowMessageProperties | nil = if TextChatModule.OverrideChatCallback then TextChatService.ChatWindowConfiguration:DeriveNewMessageProperties() else nil

	if message.TextChannel.Name:match("^RBXWhisper:(%d+)_(%d+)$") then
		local playerUserId1, playerUserId2 = message.TextChannel.Name:match("^RBXWhisper:(%d+)_(%d+)$") 
		playerUserId1, playerUserId2 = tonumber(playerUserId1), tonumber(playerUserId2)

		local otherTarget = Players:GetPlayerByUserId(if LocalPlayer.UserId == playerUserId1 then
			playerUserId2 else playerUserId1)

		local otherTargetDisplayName = if not otherTarget then `{otherTarget.UserId}` else
			CorrectValue("string", otherTarget.DisplayName, otherTarget:GetAttribute("DisplayName") or otherTarget:GetAttribute("ChatTag"))
		PrefixText = `[To {otherTargetDisplayName}] ` .. PrefixText
	end

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