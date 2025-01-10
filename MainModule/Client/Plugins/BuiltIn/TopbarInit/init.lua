message = nil

return function(envArgs)
	local client = envArgs.client
	local variables = envArgs.variables
	local service = envArgs.service
	local loadModule = envArgs.loadModule
	local getEnv = envArgs.getEnv
	local message: (str: string) -> nil = envArgs.message
	local script = envArgs.script

	local Remote = client.Remote
	local UI = client.UI
	local Network = client.Network

	local cliSettings = client.Network:get(
		"GetSettings",
		{ "helpEnabled", "helpIconImage", "consoleEnabled", "consoleIconImage", "hotkeys", "allowClientGlobal" }
	) or {}
	local hotkeys = (cliSettings.hotkeys or {}).quickActions or {}

	local quickAction, aboutMeIcon
	local topbarIconTheme = client.TopbarIconTheme

	quickAction = client
		.UI
		.makeElement("TopbarIcon")
		:setEnabled(false)
		--quickAction:setTheme(topbarIconTheme)
		:setName(service.getRandom())
		:setLabel("E")
		:setCaption("Quick actions")
		:setOrder(5)
		:setRight()
	--:set("dropdownMinWidth", 120, "other")
	--:set("dropdownMaxIconsBeforeScroll", 5, "other")

	quickAction.selected:Connect(function()
		if aboutMeIcon.isSelected then aboutMeIcon:deselect() end
	end)

	local dropdown = {}

	-- Help button
	if cliSettings.helpEnabled then
		local helpIcon =
			client.UI.makeElement("TopbarIcon"):setEnabled(false):setName(service.getRandom()):setLabel "Get help"

		if #(cliSettings.helpIconImage or "") > 0 then helpIcon:setImage(cliSettings.helpIconImage) end

		helpIcon.selected:Connect(function()
			quickAction:deselect()
			client.Network:fire("HelpAssist", "Setting")
			helpIcon:deselect()
		end)

		table.insert(dropdown, helpIcon)
	end

	if cliSettings.consoleEnabled then
		client.Utility:setupConsole()

		local consoleIcon =
			client.UI.makeElement("TopbarIcon"):setEnabled(false):setName(service.getRandom()):setLabel "Console bar"

		consoleIcon.selected:Connect(function()
			quickAction:deselect()
			consoleIcon:lock()
			client.Utility.makeConsole()
			consoleIcon:unlock()
			consoleIcon:deselect()
		end)
		client.consoleOpened:connect(function() quickAction:deselect() end)

		local consoleBoxIcon =
			client.UI.makeElement("TopbarIcon"):setEnabled(false):setName(service.getRandom()):setLabel "CommandX"
		consoleBoxIcon.selected:Connect(function()
			quickAction:deselect()
			consoleBoxIcon:lock()
			client.UI.construct "CmdX"
			consoleBoxIcon:unlock()
			consoleBoxIcon:deselect()
		end)
		client.consoleOpened:connect(function() quickAction:deselect() end)

		if #(cliSettings.consoleIconImage or "") > 0 then
			consoleIcon:setImage(cliSettings.consoleIconImage)
			consoleBoxIcon:setImage(cliSettings.consoleIconImage)
		end

		table.insert(dropdown, consoleIcon)
		table.insert(dropdown, consoleBoxIcon)
	end

	local cliSettingsIcon =
		client.UI.makeElement("TopbarIcon"):setEnabled(false):setName(service.getRandom()):setLabel "Client settings"

	cliSettingsIcon.selected:Connect(function()
		quickAction:deselect()
		cliSettingsIcon:lock()
		client.UI.construct "ClientSettings"
		cliSettingsIcon:unlock()
		cliSettingsIcon:deselect()
	end)
	table.insert(dropdown, cliSettingsIcon)

	if #dropdown == 0 then
		quickAction:lock()
		quickAction:setTip "No options available"
	else
		quickAction:setDropdown(dropdown)
		for i, dropdownIcon in dropdown do
			dropdownIcon:setEnabled(true)
		end
	end
	--warn("Dropdown:", dropdown)

	aboutMeIcon = client.UI
		.makeElement("TopbarIcon")
		:modifyTheme(topbarIconTheme.Base)
		:setEnabled(false)
		:setName(service.getRandom())
		:setImage("rbxassetid://8099668652")
		:setCaption("About Me")
		:setOrder(7)
		:setRight()
	--:set("dropdownMinWidth", 120, "other")
	--:set("dropdownMaxIconsBeforeScroll", 5, "other")

	aboutMeIcon.selected:Connect(function()
		if quickAction.isSelected then quickAction:deselect() end
	end)

	local aboutMeDropdown = {}

	local aboutUserIdIcon = client.UI
		.makeElement("TopbarIcon")
		:joinDropdown(aboutMeIcon)
		:modifyTheme(topbarIconTheme.Dropdown)
		:setName(service.getRandom())
		:setLabel("UserId: " .. tostring(service.player.UserId))
		:lock()

	table.insert(aboutMeDropdown, aboutUserIdIcon)

	local aboutDisplayNameIcon = client.UI
		.makeElement("TopbarIcon")
		:joinDropdown(aboutMeIcon)
		:modifyTheme(topbarIconTheme.Dropdown)
		:setName(service.getRandom())
		:setLabel("Full name: " .. string.format("%s (@%s)", service.player.DisplayName, service.player.Name))
		:lock()

	table.insert(aboutMeDropdown, aboutDisplayNameIcon)

	local aboutPingIcon = client.UI
		.makeElement("TopbarIcon")
		:joinDropdown(aboutMeIcon)
		:modifyTheme(topbarIconTheme.Dropdown)
		:setName(service.getRandom())
		:setLabel("Ping: 0ms")
		:lock()

	table.insert(aboutMeDropdown, aboutPingIcon)

	local aboutFPSIcon = client.UI
		.makeElement("TopbarIcon")
		:joinDropdown(aboutMeIcon)
		:modifyTheme(topbarIconTheme.Dropdown)
		:setName(service.getRandom())
		:setLabel("FPS: " .. tostring(workspace:GetRealPhysicsFPS()))
		:lock()

	table.insert(aboutMeDropdown, aboutFPSIcon)

	local aboutRejoinServerIcon = client
		.UI
		.makeElement("TopbarIcon")
		:joinDropdown(aboutMeIcon)
		:modifyTheme(topbarIconTheme.Dropdown)
		:setName(service.getRandom())
		:setLabel("Rejoin server")
		--:set("iconBackgroundColor", Color3.fromRGB(144, 144, 144), "deselected")
		--:set("iconBackgroundColor", Color3.fromRGB(144, 144, 144), "selected")
		:lock()

	service.threadTask(function()
		local canRejoinServer = client.Network:get "CanRejoinServer"

		if not canRejoinServer then
			--aboutRejoinServerIcon:set("iconBackgroundColor", Color3.fromRGB(255, 74, 74), "deselected")
			--aboutRejoinServerIcon:set("iconBackgroundColor", Color3.fromRGB(255, 74, 74), "selected")
			aboutRejoinServerIcon:lock()
		else
			aboutRejoinServerIcon:unlock()
			--aboutRejoinServerIcon:set("iconBackgroundColor", Color3.fromRGB(98, 197, 31), "deselected")
			--aboutRejoinServerIcon:set("iconBackgroundColor", Color3.fromRGB(98, 197, 31), "selected")

			aboutRejoinServerIcon.selected:Connect(function()
				service.debounce("Rejoin server", function()
					aboutRejoinServerIcon:deselect()
					aboutRejoinServerIcon:lock()

					local oldBackgroundColor = aboutRejoinServerIcon:get "iconBackgroundColor"
					--aboutRejoinServerIcon:set("iconBackgroundColor", Color3.fromRGB(255, 184, 41), "deselected")
					--aboutRejoinServerIcon:set("iconBackgroundColor", Color3.fromRGB(255, 184, 41), "selected")

					client.UI.construct("Bubble", {
						title = "Ongoing teleportation..",
						descrip = "Rejoining the server. Please wait.",
						time = 180,
					})

					local teleportSuccess = client.Network:get "RejoinServer"

					if not teleportSuccess then
						aboutRejoinServerIcon:unlock()
						--aboutRejoinServerIcon:set("iconBackgroundColor", oldBackgroundColor, "deselected")
						--aboutRejoinServerIcon:set("iconBackgroundColor", oldBackgroundColor, "selected")

						client.UI.construct("Bubble", {
							title = "Ongoing Teleportation",
							descrip = "Failed to rejoin the server. Please try again later.",
							time = 5,
						})
					end
				end)
			end)
		end
	end)

	table.insert(aboutMeDropdown, aboutRejoinServerIcon)

	--// Shortcuts
	local createdCmdShortcuts = client.Network:get "GetCommandButtons" or {}
	if type(createdCmdShortcuts) ~= "table" then
		warn("Shortcuts isn't a table?", createdCmdShortcuts)
		createdCmdShortcuts = {}
	end

	local shortcutTopbarIcons = variables.shortcutTopbarIcons or {}
	variables.shortcutTopbarIcons = shortcutTopbarIcons

	local shortcutTopbar = client.UI
		.makeElement("TopbarIcon")
		:setTheme(topbarIconTheme.Base)
		:setName(service.getRandom())
		:setImage("rbxassetid://9030162754")
		:setCaption("My Shortcuts")
		:setOrder(8)
		:setRight()
		:modifyChildTheme {
			{ "Widget", "MinimumWidth", 25, "Deselected" },
			{ "Widget", "MinimumHeight", 25, "Deselected" },
		}
	--shortcutTopbar:set("dropdownMinWidth", 120, "other")
	--shortcutTopbar:set("dropdownMaxIconsBeforeScroll", 4, "other")

	shortcutTopbar:setEnabled(false)
	shortcutTopbar.selected:Connect(function()
		if quickAction.isSelected then quickAction:deselect() end
		if aboutMeIcon.isSelected then aboutMeIcon:deselect() end
	end)

	for buttonName, cmdLine in pairs(createdCmdShortcuts) do
		if not shortcutTopbar.enabled and client.Policies._clientPolicies.SHORTCUTS_ALLOWED.value == true then
			shortcutTopbar:setEnabled(true)
		end

		local buttonTopbarIcon = client.UI
			.makeElement("TopbarIcon")
			:joinDropdown(shortcutTopbar, "dropdown")
			:modifyTheme(topbarIconTheme.Dropdown)
			:setImage("rbxassetid://9030162754")
			:setLeft()
			:setOrder(10)
			:setLabel(buttonName)

		buttonTopbarIcon.selected:Connect(function()
			buttonTopbarIcon:deselect()
			client.Network:fire("RunCommandButton", buttonName)
		end)
		shortcutTopbarIcons[buttonName] = buttonTopbarIcon
	end

	client.Policies:connectPolicyChangeEvent(
		"SHORTCUTS_ALLOWED",
		function(state: boolean, enforce_type: string) shortcutTopbar:setEnabled(state) end
	)

	--local testUIIcon = client.UI.makeElement("TopbarIcon")
	--testUIIcon:setName(service.getRandom())
	--testUIIcon:setLabel("Notepad")
	--testUIIcon.selected:Connect(function()
	--	testUIIcon:deselect()
	--	testUIIcon:lock()
	--	client.UI.construct("ResponseEntry", {
	--		title = "Notepad";
	--		charLimit = 100;
	--	})
	--end)

	--table.insert(aboutMeDropdown, aboutServerIdIcon)

	service.loopTask("Check network ping", 60, function()
		local networkPingMs = client.Network:getPing(15)
		aboutPingIcon:setLabel(string.format("Ping: %sms", networkPingMs))
	end)

	service.loopTask("Check FPS", 5, function()
		if aboutFPSIcon.enabled then aboutFPSIcon:setLabel("FPS: " .. tostring(workspace:GetRealPhysicsFPS())) end
	end)

	client.Utility:makeKeybinds("Open quick actions", hotkeys, "Function", function()
		if quickAction.isSelected then
			quickAction:deselect()
		else
			quickAction:select()
		end
	end)

	quickAction.selected:Connect(function() client.Events.quickActionShown:fire() end)

	quickAction.deselected:Connect(function() client.Events.quickActionHidden:fire() end)

	client.aboutMeIcon = aboutMeIcon
	client.quickAction = quickAction
	client.shortcutsIcon = shortcutTopbar
	client.Events.quickActionReady:fire(quickAction)

	message(
		`Game settings may require minimized player view. Players with MINIMIZED_TOPBARICONS policy enabled cannot view EC Topbar utility icons.`
	)

	client.Policies:connectPolicyChangeEvent(
		`MINIMIZED_TOPBARICONS`,
		function(policyValue: boolean, enforcementType: string)
			if policyValue then
				if quickAction.enabled or aboutMeIcon.enabled then
					quickAction:deselect()
					aboutMeIcon:deselect()
				end

				quickAction:setEnabled(false)
				aboutMeIcon:setEnabled(false)
				return
			end

			quickAction:setEnabled(true)
			aboutMeIcon:setEnabled(true)
		end
	)
end

--:m test "oof lol"
