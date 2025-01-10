return {
	Base = {
		{
			"IconGradient",
			"Color",
			ColorSequence.new {
				ColorSequenceKeypoint.new(0, Color3.fromRGB(143, 158, 179)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(113, 125, 141)),
			},
			"Selected",
		},
		{
			"IconGradient",
			"Color",
			ColorSequence.new {
				ColorSequenceKeypoint.new(0, Color3.fromRGB(143, 158, 179)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(113, 125, 141)),
			},
			"Deselected",
		},
		{ "IconButton", "BackgroundColor3", Color3.fromRGB(33, 41, 54), "Deselected" },
		{ "IconButton", "BackgroundColor3", Color3.fromRGB(69, 86, 113), "Selected" },
		{ "IconButton", "BackgroundTransparency", 0 },
		{ "IconGradient", "Enabled", true },
		{ "IconImage", "Size", UDim2.new(0.6, 0, 0.6, 0) },
	},

	Dropdown = {
		{ "IconLabel", "TextXAlignment", Enum.TextXAlignment.Left },
		{ "IconGradient", "Enabled", true, "Deselected" },
		{ "IconGradient", "Enabled", true, "Selected" },
		{ "Widget", "MinimumWidth", 120 },
		{ "Widget", "MinimumHeight", 25 },
		{ "IconLabel", "TextSize", 15 },
	},

	-- -- Settings which describe how an item behaves or transitions between states
	-- action =  {
	--     toggleTransitionInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	--     resizeInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	--     repositionInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	--     captionFadeInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	--     tipFadeInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	--     dropdownSlideInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	--     menuSlideInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	-- },

	-- -- Settings which describe how an item appears when 'deselected' and 'selected'
	-- toggleable = {
	--     -- How items appear normally (i.e. when they're 'deselected')
	--     deselected = {
	--iconBackgroundColor = Color3.fromRGB(61, 68, 77),
	--         iconBackgroundTransparency = 0,
	--         iconCornerRadius = UDim.new(0.25, 0),
	--iconGradientColor = ColorSequence.new({
	--	ColorSequenceKeypoint.new(0, Color3.fromRGB(143, 158, 179));
	--	ColorSequenceKeypoint.new(1, Color3.fromRGB(113, 125, 141));
	--}),
	--         iconGradientRotation = 90,
	--         iconImage = "",
	--         iconImageColor =Color3.fromRGB(244, 244, 244),
	--         iconImageTransparency = 0,
	--         iconImageYScale = 0.63,
	--         iconImageRatio = 1,
	--         iconLabelYScale = 0.45,
	--         iconScale = UDim2.new(1, 0, 1, 0),
	----forcedIconSize = UDim2.new(0, 32, 0, 32);
	--forcedIconSizeX = 32;
	--forcedIconSizeY = 32;
	--         iconSize = UDim2.new(0, 32, 0, 32),
	--         iconOffset = UDim2.new(0, 0, 0, 0),
	--         iconText = "",
	--         iconTextColor = Color3.fromRGB(232, 232, 232),
	--         iconFont = Enum.Font.GothamSemibold,
	--         noticeCircleColor = Color3.fromRGB(173, 191, 217),
	--         noticeCircleImage = "http://www.roblox.com/asset/?id=4871790969",
	--         noticeTextColor = Color3.fromRGB(221, 221, 221),
	--         baseZIndex = 1,
	--         order = 1,
	--         alignment = "left",
	--clickSoundId = "rbxassetid://5991592592",
	--         clickVolume = 0.05,
	--         clickPlaybackSpeed = 1,
	--         clickTimePosition = 0
	--     },
	--     -- How items appear after the icon has been clicked (i.e. when they're 'selected')
	--     -- If a selected value is not specified, it will default to the deselected value
	--     selected = {
	--iconBackgroundColor = Color3.fromRGB(118, 147, 194),
	--         iconBackgroundTransparency = 0.1,
	--         iconImageColor = Color3.fromRGB(208, 204, 204),
	--         iconTextColor = Color3.fromRGB(196, 207, 223),
	--         clickPlaybackSpeed = 1.5,
	--     }
	-- },

	-- -- Settings where toggleState doesn't matter (they have a singular state)
	-- other = {
	--     -- Caption settings
	--     captionBackgroundColor = Color3.fromRGB(0, 0, 0),
	--     captionBackgroundTransparency = 0.5,
	--     captionTextColor = Color3.fromRGB(255, 255, 255),
	--     captionTextTransparency = 0,
	--     captionFont = Enum.Font.GothamSemibold,
	--     captionOverlineColor = Color3.fromRGB(0, 170, 255),
	--     captionOverlineTransparency = 0,
	--     captionCornerRadius = UDim.new(0.25, 0),
	--     -- Tip settings
	--     tipBackgroundColor = Color3.fromRGB(255, 255, 255),
	--     tipBackgroundTransparency = 0.1,
	--     tipTextColor = Color3.fromRGB(27, 42, 53),
	--     tipTextTransparency = 0,
	--     tipFont = Enum.Font.GothamSemibold,
	--     tipCornerRadius = UDim.new(0.175, 0),
	--     -- Dropdown settings
	--     dropdownAlignment = "auto", -- 'left', 'mid', 'right' or 'auto' (auto is where the dropdown alignment matches the icons alignment)
	--     dropdownMaxIconsBeforeScroll = 3,
	--     dropdownMinWidth = 32,
	--     dropdownSquareCorners = false,
	--     dropdownBindToggleToIcon = true,
	--     dropdownToggleOnLongPress = false,
	--     dropdownToggleOnRightClick = false,
	--     dropdownCloseOnTapAway = false,
	--     dropdownHidePlayerlistOnOverlap = true,
	--     dropdownListPadding = UDim.new(0, 2),
	--     dropdownScrollBarColor = Color3.fromRGB(25, 25, 25),
	--     dropdownScrollBarTransparency = 0.2,
	--     dropdownScrollBarThickness = 4,
	--     -- Menu settings
	--     menuDirection = "auto", -- 'left', 'right' or 'auto' (for auto, if alignment is 'left' or 'mid', menuDirection will be 'right', else menuDirection is 'left')
	--     menuMaxIconsBeforeScroll = 4,
	--     menuBindToggleToIcon = true,
	--     menuToggleOnLongPress = false,
	--     menuToggleOnRightClick = false,
	--     menuCloseOnTapAway = false,
	--     menuScrollBarColor = Color3.fromRGB(25, 25, 25),
	--     menuScrollBarTransparency = 0.2,
	--     menuScrollBarThickness = 4,
	-- },
}
