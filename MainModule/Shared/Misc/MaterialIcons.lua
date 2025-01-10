local InsertService = game:GetService("InsertService")
local MaterialIcons = {
	--// Google
	UnfoldMore_16dp 		= { aliases = {"maximize"}; url = "rbxassetid://16218785047"; };
	UnfoldLess_16dp 		= { aliases = {"minimize"}; url = "rbxassetid://16218791621"; };
	Minimize_18dp 			= { aliases = {"minimize_dash"}; url = "rbxassetid://16218638759"; };
	KeyboardArrowRight_16dp = { aliases = {"arrow-right", "submit", "send"}; url = "rbxassetid://9614324201"; };
	CommandKey_24dp 		= { aliases = {"command"}; url = "rbxassetid://9030162754"; };
	CloseIcon_18dp 			= { aliases = {"close"}; url = "rbxassetid://9008925352"; };
	Terminal_16dp 			= { aliases = {"terminal"}; url = "rbxassetid://9008897943"; };
	Search_16dp 			= { aliases = {"search"}; url = "rbxassetid://16219120355"; };
	Refresh_16dp 			= { aliases = {"refresh"}; url = "rbxassetid://8808359078"; };
	WaveHand_16dp 			= { aliases = {"wave", "greeting"}; url = "rbxassetid://80934366346341"; };
	GridView_24dp 			= { aliases = {"gridview", "four-square-menu"}; url = "rbxassetid://80054113454199"; };
	FileOpen_24dp 			= { aliases = {"fileopen", "file-open", "openfile"}; url = "rbxassetid://70712681512021"; };
	Info_24dp 				= { aliases = {"info", "error"}; url = "rbxassetid://70712681512021"; };
	Checkmark_30dp 			= { aliases = {"checkmark", "check"}; url = "rbxassetid://106365498845210"; };
	Notification_18dp 		= { aliases = {"notification", "notif"}; url = "rbxassetid://83961147818491"; };
	Mail_24dp 				= { aliases = {"mail", "message"}; url = "rbxassetid://14428286056"; };
	--Refresh_16dp 			= { aliases = {"refresh"}; url = "rbxassetid://8808359078"; };
}

return setmetatable({}, {
	__index = function(self, index)
		local iconUrl = MaterialIcons[index]
		if type(iconUrl) == "table" then
			return iconUrl.url
		elseif type(iconUrl) == "string" then
			return iconUrl
		end
		
		index = if type(index) ~= "string" then tostring(index) else index
		
		for _, iconInfo in MaterialIcons do
			if type(iconInfo) == "table" then
				for d, alias in iconInfo.aliases do
					if alias:lower() == index:lower() then
						return iconInfo.url
					end
				end
			end
		end
		
		--error(string.format("%s is not an alias or member of the Material Icons", index))
	end;
	__metatable = "Material Icons";
})