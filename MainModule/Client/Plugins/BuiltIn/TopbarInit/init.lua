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
	
	local makeUIElement = UI.makeElement

	local cliSettings = client.Network:get(
		"GetSettings",
		{ "helpEnabled", "helpIconImage", "consoleEnabled", "consoleIconImage", "hotkeys" }
	) or {}
	local hotkeys = (cliSettings.hotkeys or {}).quickActions or {}

	local quickAction
	local topbarIconTheme = client.TopbarIconTheme

	quickAction = makeUIElement("TopbarIcon")
		:setEnabled(true)
		:setTheme(topbarIconTheme.Base)
		:setName(service.getRandom())
		:setLabel("E")
		:setCaption("Essential Quick Menu")
		:setOrder(5)
		:setRight()
		:setMenu({
			
			--// About Me
			makeUIElement("TopbarIcon")
			:modifyTheme(topbarIconTheme.Base)
			:setName(service.getRandom())
			:setImage("rbxassetid://8099668652")
			:setCaption("About Me")
			:setOrder(5)
			:setDropdown({
				makeUIElement("TopbarIcon")
					:modifyTheme(topbarIconTheme.Dropdown)
					:setName(service.getRandom())
					:setLabel("👤 " .. if service.player.DisplayName == service.player.Name then
						service.player.Name else string.format("%s (@%s)", service.player.DisplayName, service.player.Name)
					)
					:lock(),
				makeUIElement("TopbarIcon")
					:modifyTheme(topbarIconTheme.Dropdown)
					:setName(service.getRandom())
					:setLabel(`🪪 UserId: {service.player.UserId}`)
					:lock(),
				makeUIElement("TopbarIcon")
					:modifyTheme(topbarIconTheme.Dropdown)
					:setName(service.getRandom())
					:setLabel(`🏓 Ping: 0ms`)
					:lock()
					:call(function(pingIcon)
						service.loopTask("Check network ping", if client.Studio then 15 else 60, function()
							local networkPingMs = client.Network:getPing(15)
							pingIcon:setLabel(string.format("Ping: %sms", networkPingMs))
						end)
					end)
			})
			:call(function(thisIcon)
				task.spawn(function()
					local canRejoinServer = client.Network:get "CanRejoinServer"
					
					if canRejoinServer then
						makeUIElement("TopbarIcon")
							:joinDropdown(thisIcon)
							:setOrder(1)
							:modifyTheme(topbarIconTheme.Dropdown)
							:setName(service.getRandom())
							:setLabel("Rejoin server")
							:modifyTheme({
								{"IconButton", "BackgroundColor3", Color3.fromRGB(144, 144, 144), "Deselected"},
								{"IconButton", "BackgroundColor3", Color3.fromRGB(255, 74, 74), "Selected"},
							})
							:oneClick(true)
							:call(function(thisSubIcon)
								thisSubIcon.selected:Connect(function()
									service.debounce("Rejoin server", function()
										thisSubIcon:deselect()
										thisSubIcon:lock()
										
										thisSubIcon:modifyTheme({
											{"IconButton", "BackgroundColor3", Color3.fromRGB(255, 184, 41), "Deselected"},
										})
					
										client.UI.construct("Bubble", {
											title = "Ongoing teleportation..",
											descrip = "Rejoining the server. Please wait.",
											time = 180,
										})
										
										local teleportSuccess = client.Network:get "RejoinServer"
										
										if not teleportSuccess then
											thisSubIcon:unlock()
											client.UI.construct("Bubble", {
												title = "Ongoing Teleportation",
												descrip = "Failed to rejoin the server. Please try again later.",
												time = 5,
											})
										end
										
										thisSubIcon:modifyTheme({
											{"IconButton", "BackgroundColor3", Color3.fromRGB(144, 144, 144), "Deselected"},
										})
									end)
								end)
							end)
					end
				end)
			end),

			--// Client settings
			makeUIElement("TopbarIcon")
				:modifyTheme(topbarIconTheme.Base)
				:setImage("rbxassetid://106238053502876")
				:setCaption("Client Settings")
				:setOrder(6)
				:oneClick(true)
				:call(function(thisIcon)
					thisIcon.selected:Connect(function()
						client.UI.construct "ClientSettings"
					end)
				end),

			--// Quick Actions
			makeUIElement("TopbarIcon")
				:setName(service.getRandom())
				:setImage("rbxassetid://113013292490496")
				:setCaption("Quick Actions")
				:setOrder(7)
				:setDropdown({
					makeUIElement("TopbarIcon")
						:setEnabled(false)
						:modifyTheme(topbarIconTheme.Dropdown)
						:setName(service.getRandom())
						:setLabel(`Console Bar`)
						:oneClick(true)
						:call(function(consoleIcon)
							if cliSettings.consoleEnabled then
								consoleIcon:setEnabled(true)
								client.Utility:setupConsole()
								
								consoleIcon.selected:Connect(function()
									client.Utility.makeConsole()
								end)

								if #(cliSettings.consoleIconImage or "") > 0 then
									consoleIcon:setImage(cliSettings.consoleIconImage)
								end
							end
						end),
					makeUIElement("TopbarIcon")
						:setEnabled(false)
						:modifyTheme(topbarIconTheme.Dropdown)
						:setName(service.getRandom())
						:setLabel(`CommandX`)
						:oneClick(true)
						:call(function(consoleIcon)
							if cliSettings.consoleEnabled then
								consoleIcon:setEnabled(true)

								consoleIcon.selected:Connect(function()
									client.UI.construct("CmdX")
								end)

								if #(cliSettings.consoleIconImage or "") > 0 then
									consoleIcon:setImage(cliSettings.consoleIconImage)
								end
							end
						end),
					makeUIElement("TopbarIcon")
						:setEnabled(false)
						:modifyTheme(topbarIconTheme.Dropdown)
						:setName(service.getRandom())
						:setLabel(`✋ Get Admin Help`)
						:oneClick(true)
						:call(function(assistIcon)
							if cliSettings.helpEnabled then
								assistIcon:setEnabled(true)
								if #(cliSettings.helpIconImage or "") > 0 then assistIcon:setImage(cliSettings.helpIconImage) end
						
								assistIcon.selected:Connect(function()
									client.Network:fire("HelpAssist", "Setting")
								end)
							end
						end)

				})
				:call(function(thisIcon)
					-- makeUIElement("TopbarIcon")
					-- :modifyTheme(topbarIconTheme.Dropdown)
					-- :setName(service.getRandom())
					-- :setLabel(if service.player.DisplayName == service.player.Name then
					-- 	service.player.Name else string.format("%s (@%s)", service.player.DisplayName, service.player.Name)
					-- 	)
					-- 	:lock()
					end),
					
			--// Shortcuts
			makeUIElement("TopbarIcon")
				:setEnabled(false)
				:setName(service.getRandom())
				:setImage("rbxassetid://9030162754")
				-- :modifyChildTheme({
				-- 	{ "Widget", "MinimumWidth", 25, "Deselected" },
				-- 	{ "Widget", "MinimumHeight", 25, "Deselected" },
				-- })
				:setCaption("Shortcuts")
				:setOrder(8)
				:call(function(thisIcon)
					task.spawn(function()
						local createdCmdShortcuts = client.Network:get "GetCommandButtons" or {}
						if type(createdCmdShortcuts) ~= "table" then
							warn("Shortcuts isn't a table?", createdCmdShortcuts)
							createdCmdShortcuts = {}
						end

						local shortcutTopbarIcons = variables.shortcutTopbarIcons or {}
						variables.shortcutTopbarIcons = shortcutTopbarIcons

						for buttonName, cmdLine in pairs(createdCmdShortcuts) do
							if not thisIcon.enabled and client.Policies._clientPolicies.SHORTCUTS_ALLOWED.value == true then
								thisIcon:setEnabled(true)

								if not shortcutTopbarIcons[buttonName] then
									local buttonTopbarIcon = makeUIElement("TopbarIcon")
										:joinDropdown(thisIcon)
										:setTheme(client.TopbarIconTheme.Base)
										:setImage("rbxassetid://9030162754")
										:setLabel(buttonName)
										:oneClick(true)

									buttonTopbarIcon.selected:Connect(function()
										if client.Policies._clientPolicies.SHORTCUTS_ALLOWED.value ~= true then return end
										Network:fire("RunCommandButton", buttonName)
									end)

									buttonTopbarIcon:joinDropdown(client.shortcutsIcon, "dropdown")
									shortcutTopbarIcons[buttonName] = buttonTopbarIcon
								end
								
								break;
							end
						end

					end)

					client.Policies:connectPolicyChangeEvent(
						"SHORTCUTS_ALLOWED",
						function(state: boolean, enforce_type: string)
							if state and variables.shortcutTopbarIcons and next(variables.shortcutTopbarIcons) then
								thisIcon:setEnabled(true)
							elseif not state and thisIcon.enabled then
								thisIcon:deselect()
								thisIcon:setEnabled(false)
							end
						end
					)

					client.shortcutsIcon = thisIcon
				end),
		})

	local quickActionsKeybind = client.Utility.Keybinds:register(`System.EssentialIcon`, {
		keys = hotkeys,
		--holdDuration = 1;
		description = `Toggles the visiblity of the E Toopbar Icon`,
		locked = false,
		saveId = "SKE", --// SK ackronym for System Keybind
	})

	quickActionsKeybind._event:connect(function(event: "Triggered" | "OnHold" | "RateLimited" | "Canceled")
		if event == `Triggered` then
			if quickAction.isSelected then
				quickAction:deselect()
			else
				quickAction:select()
			end
		end
	end)

	if client.Utility.Notifications.TopbarIcon then
		client.Utility.Notifications.TopbarIcon:joinMenu(quickAction)
	end

	quickAction.selected:Connect(function() client.Events.quickActionShown:fire() end)
	quickAction.deselected:Connect(function() client.Events.quickActionHidden:fire() end)

	client.quickAction = quickAction
	client.Events.quickActionReady:fire(quickAction)

	message(
		`Game settings may require minimized player view. Players with MINIMIZED_TOPBARICONS policy enabled cannot view EC Topbar utility icons.`
	)

	client.Policies:connectPolicyChangeEvent(
		`MINIMIZED_TOPBARICONS`,
		function(policyValue: boolean, enforcementType: string)
			if policyValue then
				if quickAction.enabled then
					quickAction:deselect()
				end

				quickAction:setEnabled(false)
				return
			end

			quickAction:setEnabled(true)
		end
	)
end