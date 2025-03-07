return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service
	local variables = envArgs.variables

	local roundNumber = service.roundNumber
	local osTime = os.time

	local Parser = client.Parser
	local Network = client.Network
	local UI = client.UI

	local constructUI = UI.construct
	local constructElement = UI.makeElement

	local openSpecificCategory = data.openSpecificCategory

	if client.clientSettingsWindow then
		local clientSettingsW = client.clientSettingsWindow
		if openSpecificCategory then clientSettingsW:openCategory(openSpecificCategory) end

		return
	end

	local window = constructUI "SelectionWindow"
	local windowGuiData = window.guiData
	window.guiData.name = "ClientSettings"

	window.guiData.destroyed:connectOnce(function()
		if client.clientSettingsWindow == window then client.clientSettingsWindow = nil end
	end)
	client.clientSettingsWindow = window

	local clientSettings = client.Settings
	local function manageClientSetting(setting: string, value: any) clientSettings[setting] = value end

	local aliasAndShortcutCmdLineCharLimit = 500
	local overrideBackgroundColor = Color3.fromRGB(42, 42, 42)

	do
		local cliSettingsCatg = window:createCategory("Client settings", {
			size = UDim2.new(0, 200, 0, 40),
		})

		--local radioProgress = cliSettingsCatg:makeObject("Progress")
		--radioProgress.label.Text = "Radio volume"
		--radioProgress.progressIncrement = 0.1
		--radioProgress:changeMinimumValue(0)
		--radioProgress:changeMaximumValue(4)

		--local modifiedProgHolder = window:modifyObject({
		--	_object = radioProgress.holder;
		--})

		--local radioHover = modifiedProgHolder:setHover(radioProgress.progressCurrentValue)
		--radioHover.enterCheck = 0

		--radioProgress.progressChanged:connect(function(newValue)
		--	modifiedProgHolder:setHover(roundNumber(newValue, 0.001))
		--end)
		
		do
			local isKeybindsLocked = client.Policies._clientPolicies.CMD_KEYBINDS_ALLOWED.value ~= true

			local keybindsEnabledToggle = cliSettingsCatg:makeObject "Toggle"
			keybindsEnabledToggle.label.Text = "Keybinds Enabled"
			keybindsEnabledToggle._object.Position = UDim2.new(0, 10, 0, 0 * (40 + 10))

			local keybindsEnabledHolder = window:modifyObject {
				_object = keybindsEnabledToggle.toggleObj,
			}

			if isKeybindsLocked then
				keybindsEnabledToggle.lockedState = true
				keybindsEnabledToggle:setToggle(false)
				keybindsEnabledToggle.toggleBar.BackgroundColor3 = overrideBackgroundColor
				keybindsEnabledToggle:setHover "Keybinds is disabled by your client policies"
			else
				keybindsEnabledToggle.toggled:connect(function(state) manageClientSetting("KeybindsEnabled", state) end)
				keybindsEnabledToggle:setToggle(clientSettings.KeybindsEnabled and true or false)
				keybindsEnabledHolder:setHover "Enable keybinds? Keybinds functionality allows you to execute commands by pressing hotkeys"
			end
		end

		do
			local isIcognitoModeLocked = client.Policies._clientPolicies.OVERRIDE_INCOGNITO_MODE.value ~= nil

			local incognitoModeToggle = cliSettingsCatg:makeObject "Toggle"
			incognitoModeToggle.label.Text = "Incognito Mode"
			incognitoModeToggle._object.Position = UDim2.new(0, 10, 0, 1 * (40 + 10))

			local incognitoModeToggleHolder = window:modifyObject {
				_object = incognitoModeToggle.toggleObj,
			}

			if isIcognitoModeLocked then
				incognitoModeToggle.lockedState = true
				incognitoModeToggle:setToggle(
					client.Policies._clientPolicies.OVERRIDE_INCOGNITO_MODE.value and true or false
				)
				incognitoModeToggle.toggleBar.BackgroundColor3 = overrideBackgroundColor
				incognitoModeToggleHolder:setHover "Incognito Mode state is overriden by your client policies"
			else
				incognitoModeToggle:setToggle(clientSettings.IncognitoMode and true or false)
				incognitoModeToggle.toggled:connect(function(state)
					incognitoModeToggle.lockedState = true
					service.debounce("INCOGNITO-TOGGLE", function()
						local newStatus = Network:get("ToggleIncognito", state)
						if type(newStatus) ~= "boolean" then
							incognitoModeToggle:setToggle(not state)
							wait(20)
						else
							--manageClientSetting("IncognitoMode", state)
							wait(120)
						end
					end)
					incognitoModeToggle.lockedState = false
				end)

				incognitoModeToggleHolder:setHover "Incognito Mode redacts your user information and prevents non-admins from targeting you"
			end
		end

		--local hideCommandsInChat = cliSettingsCatg:makeObject("Toggle")
		--hideCommandsInChat.label.Text = "Hide chat commands"
		--hideCommandsInChat._object.Position = UDim2.new(0, 10, 0, 50)

		--hideCommandsInChat.toggled:connect(function(state)

		--end)
	end

	--// Aliases
	do
		local aliasCharLimit = 40
		local createdCmdAliases = Network:get "GetCommandAliases" or {}
		local managingAlias = false

		local aliasSettingsCatg = window:createCategory "Action Aliases"

		local createAliasButton = aliasSettingsCatg:makeObject "Button"
		createAliasButton._object.Position = UDim2.new(0, 10, 0, 0)
		createAliasButton.label.Text = #createdCmdAliases .. " alias(es) created"
		createAliasButton.button.Text = "Create new"

		local deleteAliasButton = aliasSettingsCatg:makeObject "Button"
		deleteAliasButton._object.Position = UDim2.new(0, 10, 0, 40 + 10)
		deleteAliasButton.label.Text = "Delete alias"
		deleteAliasButton.button.Text = "Open prompt"

		aliasSettingsCatg:makeInstance("TextLabel", {
			Text = "Existing aliases",
			TextSize = 16,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(239, 239, 239),
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 10, 0, 50 + deleteAliasButton._object.AbsoluteSize.Y + 10),
			Size = UDim2.new(0, 200, 0, 20),
		})

		local didCreatePrompt = false
		local createPromptData, deletePromptData = nil

		local aliasActionObjs = {}
		local function sortAliasInteractions()
			local num = 0
			for i, aliasActionData in ipairs(aliasActionObjs) do
				aliasActionData._object.LayoutOrder = 3 + i
				aliasActionData._object.Position = UDim2.fromOffset(10, 100 + (i * 40) + (-10 + (i * 10)))
				num += 1
			end

			if num > 3 then
				aliasSettingsCatg:changeSize(UDim2.new(1, 0, 0, 280 + ((num - 3) * 40) + (-10 + ((num - 5) * 10))))
			end
		end

		local function deleteAliasInteraction(aliasAction)
			local actionInd = table.find(aliasActionObjs, aliasAction)
			if actionInd then
				table.remove(aliasActionObjs, actionInd)
				createAliasButton.label.Text = #aliasActionObjs .. " alias(es) created"
				aliasAction:destroy()
				sortAliasInteractions()
			end
		end

		local function createAliasInteraction(aliasName: string, cmdLine: string)
			local aliasActionButton = aliasSettingsCatg:makeObject "Button"
			aliasActionButton._object.Visible = false
			aliasActionButton.label.Text = aliasName
			aliasActionButton.label.TextTruncate = Enum.TextTruncate.AtEnd
			aliasActionButton.button.Text = "Modify"
			aliasActionButton.aliasName = aliasName

			aliasActionButton.clicked:connect(function()
				if not didCreatePrompt then
					didCreatePrompt = true

					local aliasModificationBusy = false

					createPromptData = window:createPrompt "View alias"
					createPromptData.canConfirm = false

					local aliasNameTF = createPromptData:addTextField "Alias name"
					aliasNameTF.charLimit = aliasCharLimit
					aliasNameTF.inputPattern = "^%s*(.-)%s*$"
					aliasNameTF.inputBox.TextEditable = false
					aliasNameTF.inputBox.Text = aliasName
					aliasNameTF:changeHint "<i>* read only</i>"

					local aliasCmdLineTF = createPromptData:addTextField "Execute Input"
					aliasCmdLineTF.charLimit = aliasAndShortcutCmdLineCharLimit
					aliasCmdLineTF.inputBox.Text = cmdLine
					aliasCmdLineTF.inputPattern = "^%s*(.-)$"

					local tempInputChanged
					tempInputChanged = aliasCmdLineTF.inputChanged:connect(function()
						if aliasCmdLineTF.inputBox.Text ~= cmdLine then
							tempInputChanged:disconnect()
							createPromptData:changeCanConfirmState(true)
						end
					end)

					local deleteAliasAction = createPromptData:addButton("Delete alias", "Confirm")
					deleteAliasAction:highlightInput(Color3.fromRGB(255, 66, 66))
					deleteAliasAction.clicked:connect(function()
						if not managingAlias then
							managingAlias = true
							aliasModificationBusy = true
							createPromptData:changeCanConfirmState(false)
							createPromptData:changeCanCloseState(false)
							constructUI("Context", {
								text = "Deleting alias <b>" .. Parser:filterForRichText(aliasName) .. "</b>",
								plainText = "Deleting alias " .. aliasName,
								expireOs = osTime() + 8,
							})
							local deleteRetCode = Network:get("DeleteCommandAlias", aliasName)
							if deleteRetCode == -1 then
								constructUI("Context", {
									text = "Alias <b>"
										.. Parser:filterForRichText(aliasName)
										.. "</b> failed to delete due to non-existence.",
									plainText = "Alias " .. aliasName .. " failed to delete due to non-existence.",
									expireOs = osTime() + 8,
								})
							elseif deleteRetCode == true then
								constructUI("Context", {
									text = "Alias <b>"
										.. Parser:filterForRichText(aliasName)
										.. "</b> successfully deleted.",
									plainText = "Alias " .. aliasName .. " successfully deleted.",
									expireOs = osTime() + 8,
								})
							end
							createPromptData:changeCanConfirmState(true)
							createPromptData:changeCanCloseState(true)
							aliasModificationBusy = false
							managingAlias = false
							createPromptData:destroy()
							deleteAliasInteraction(aliasActionButton)
						else
							constructUI("Context", {
								text = "You can't delete the alias until the other alias has finished managing.",
								expireOs = osTime() + 8,
							})
						end
					end)

					createPromptData.confirmed:connect(function()
						if managingAlias then
							constructUI("Context", {
								text = "Unable to update your custom alias while the other alias is being updated. Please try again later!",
								expireOs = osTime() + 4,
							})
						else
							managingAlias = true

							local updateRetCode =
								Network:get("UpdateCommandAlias", aliasName, aliasCmdLineTF.currentInput)
							if updateRetCode == -1 then
								constructUI("Context", {
									text = "Alias <b>"
										.. Parser:filterForRichText(aliasName)
										.. "</b> failed to update due to non-existence.",
									plainText = "Alias " .. aliasName .. " failed to update due to non-existence.",
									expireOs = osTime() + 8,
								})
								deleteAliasInteraction(aliasActionButton)
							elseif updateRetCode == true then
								constructUI("Context", {
									text = "Alias <b>"
										.. Parser:filterForRichText(aliasName)
										.. "</b> successfully updated.",
									plainText = "Alias " .. aliasName .. " successfully updated.",
									expireOs = osTime() + 8,
								})
								cmdLine = aliasCmdLineTF.currentInput
							end

							task.delay(3, function() managingAlias = false end)
						end
					end)

					createPromptData:show()
					createPromptData.hidden:connectOnce(function()
						didCreatePrompt = false
						createPromptData:destroy()
					end)
				end
			end)

			table.insert(aliasActionObjs, aliasActionButton)
			createAliasButton.label.Text = #aliasActionObjs .. " alias(es) created"
			sortAliasInteractions()

			aliasActionButton._object.Visible = true

			return aliasActionButton
		end

		createAliasButton.clicked:connect(function()
			if not didCreatePrompt and not managingAlias then
				didCreatePrompt = true
				createPromptData = window:createPrompt "Create alias"

				local shortcutTF = createPromptData:addTextField "Alias name"
				shortcutTF.inputPattern = "^%s*(.-)%s*$"
				shortcutTF:changeHint("Up to " .. aliasCharLimit .. " characters")
				shortcutTF.charLimit = aliasCharLimit

				local executeTF = createPromptData:addTextField "Execute Input"
				executeTF.inputBox.PlaceholderText = ":bring all"
				executeTF.inputPattern = "^%s*(.-)$"
				executeTF:changeHint(
					"Command line for the alias (" .. aliasAndShortcutCmdLineCharLimit .. " char limit)"
				)
				executeTF.charLimit = aliasAndShortcutCmdLineCharLimit

				createPromptData:show()
				createPromptData.confirmed:connect(function()
					managingAlias = true
					local aliasName, aliasCommandLine = shortcutTF.currentInput, executeTF.currentInput

					if #aliasName < 2 then
						constructUI("Context", {
							text = "Alias name must have at least two chars.",
							expireOs = osTime() + 6,
						})
					elseif #aliasCommandLine == 0 then
						constructUI("Context", {
							text = "Alias command line must have at least one character.",
							expireOs = osTime() + 6,
						})
					else
						constructUI("Context", {
							text = "Creating alias <b>" .. Parser:filterForRichText(aliasName) .. "</b>..",
							plainText = "Creating alias " .. aliasName .. "..",
							expireOs = osTime() + 8,
						})

						task.wait(1)
						local createRetCode = Network:get("CreateCommandAlias", aliasName, aliasCommandLine)
						if createRetCode == -1 then
							constructUI("Context", {
								text = "Unable to create new alias due to alias roadblock.",
								expireOs = osTime() + 6,
							})
						elseif createRetCode == -2 then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> already exists. Creation canceled.",
								plainText = "Alias " .. aliasName .. " already exists. Creation canceled.",
								expireOs = osTime() + 6,
							})
						elseif createRetCode == -2.5 then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> is not a safe string. Pick different phrase(s) for your alias.",
								plainText = "Alias "
									.. aliasName
									.. " is not a safe string. Pick different phrase(s) for your alias.",
								expireOs = osTime() + 6,
							})
						elseif createRetCode == -3 then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> contains a batch separator. Creation canceled.",
								plainText = "Alias " .. aliasName .. " contains a batch separator. Creation canceled.",
								expireOs = osTime() + 6,
							})
						elseif createRetCode == -4 then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> is similar to another CC alias.",
								plainText = "Alias " .. aliasName .. " is similar to another CC alias.",
								expireOs = osTime() + 6,
							})
						else
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> has successfully been created.",
								plainText = "Alias " .. aliasName .. " has successfully been created.",
								expireOs = osTime() + 8,
							})
							createAliasInteraction(aliasName, aliasCommandLine)
						end
					end
					managingAlias = false
				end)
				createPromptData.hidden:connectOnce(function()
					didCreatePrompt = false
					createPromptData:destroy()
				end)
			end
		end)

		deleteAliasButton.clicked:connect(function()
			if not didCreatePrompt and not managingAlias then
				didCreatePrompt = true
				deletePromptData = window:createPrompt "Delete alias"
				deletePromptData.canConfirm = false

				local shortcutTF = deletePromptData:addTextField "Alias name"
				shortcutTF:changeHint("Up to " .. aliasCharLimit .. " characters")
				shortcutTF.charLimit = aliasCharLimit

				local deleteAliasButton = deletePromptData:addButton("", "Delete alias")
				deleteAliasButton:highlightInput(Color3.fromRGB(255, 66, 66))
				deleteAliasButton.clicked:connect(function()
					local aliasName = Parser:trimString(shortcutTF.currentInput)
					if not managingAlias and #aliasName > 0 then
						managingAlias = true
						deletePromptData:changeCanCloseState(false)
						local deleteRetCode = Network:get("DeleteCommandAlias", aliasName)
						if deleteRetCode == -1 then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> failed to delete due to non-existence.",
								plainText = "Alias " .. aliasName .. " failed to delete due to non-existence.",
								expireOs = osTime() + 8,
							})
						elseif deleteRetCode == true then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> successfully deleted.",
								plainText = "Alias " .. aliasName .. " successfully deleted.",
								expireOs = osTime() + 8,
							})

							local aliasButton = (function()
								for i, aliasButtonData in pairs(aliasActionObjs) do
									if aliasButtonData.aliasName:lower() == aliasName:lower() then
										return aliasButtonData
									end
								end
							end)()

							if aliasButton then deleteAliasInteraction(aliasButton) end
						end
						deletePromptData:changeCanCloseState(true)

						task.delay(3, function() managingAlias = false end)
					end
				end)
				deletePromptData:show()
				deletePromptData.confirmed:connectOnce(function() end)
				deletePromptData.hidden:connectOnce(function()
					didCreatePrompt = false
					deletePromptData:destroy()
				end)
			end
		end)

		for aliasName, cmdLine in pairs(createdCmdAliases) do
			createAliasInteraction(aliasName, cmdLine)
		end
	end

	--// Custom command names
	do
		local aliasCharLimit = 30
		local createdCmdAliases = Network:get "GetCustomCmdAliases" or {}
		local managingAlias = false

		local aliasSettingsCatg = window:createCategory "CC Aliases/Names"

		local createAliasButton = aliasSettingsCatg:makeObject "Button"
		createAliasButton._object.Position = UDim2.new(0, 10, 0, 0)
		createAliasButton.label.Text = #createdCmdAliases .. " alias(es) created"
		createAliasButton.button.Text = "Create new"

		local deleteAliasButton = aliasSettingsCatg:makeObject "Button"
		deleteAliasButton._object.Position = UDim2.new(0, 10, 0, 40 + 10)
		deleteAliasButton.label.Text = "Delete alias"
		deleteAliasButton.button.Text = "Open prompt"

		aliasSettingsCatg:makeInstance("TextLabel", {
			Text = "Existing aliases",
			TextSize = 16,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(239, 239, 239),
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 10, 0, 50 + deleteAliasButton._object.AbsoluteSize.Y + 10),
			Size = UDim2.new(0, 200, 0, 20),
		})

		local didCreatePrompt = false
		local createPromptData, deletePromptData = nil

		local aliasActionObjs = {}
		local function sortAliasInteractions()
			for i, aliasActionData in ipairs(aliasActionObjs) do
				aliasActionData._object.LayoutOrder = 3 + i
				aliasActionData._object.Position = UDim2.fromOffset(10, 100 + (i * 40) + (-10 + (i * 10)))
			end
		end

		local function deleteAliasInteraction(aliasAction)
			local actionInd = table.find(aliasActionObjs, aliasAction)
			if actionInd then
				table.remove(aliasActionObjs, actionInd)
				createAliasButton.label.Text = #aliasActionObjs .. " alias(es) created"
				aliasAction:destroy()
				sortAliasInteractions()
			end
		end

		local function createAliasInteraction(aliasName: string, cmdLine: string)
			local aliasActionButton = aliasSettingsCatg:makeObject "Button"
			aliasActionButton._object.Visible = false
			aliasActionButton.label.Text = aliasName
			aliasActionButton.label.TextTruncate = Enum.TextTruncate.AtEnd
			aliasActionButton.button.Text = "Modify"
			aliasActionButton.aliasName = aliasName

			aliasActionButton.clicked:connect(function()
				if not didCreatePrompt then
					didCreatePrompt = true

					local aliasModificationBusy = false

					createPromptData = window:createPrompt "View alias"
					createPromptData.canConfirm = false

					local aliasNameTF = createPromptData:addTextField "Personal cmd alias"
					aliasNameTF.charLimit = aliasCharLimit
					aliasNameTF.inputPattern = "^%s*(.-)%s*$"
					aliasNameTF.inputBox.TextEditable = false
					aliasNameTF.inputBox.Text = aliasName
					aliasNameTF:changeHint "<i>* read only</i>"

					local aliasCmdLineTF = createPromptData:addTextField "Target Command"
					aliasCmdLineTF.inputBox.Text = cmdLine
					aliasCmdLineTF.inputPattern = "^%s*(.-)$"

					local tempInputChanged
					tempInputChanged = aliasCmdLineTF.inputChanged:connect(function()
						if aliasCmdLineTF.inputBox.Text ~= cmdLine then
							tempInputChanged:disconnect()
							createPromptData:changeCanConfirmState(true)
						end
					end)

					local deleteAliasAction = createPromptData:addButton("Delete alias", "Confirm")
					deleteAliasAction:highlightInput(Color3.fromRGB(255, 66, 66))
					deleteAliasAction.clicked:connect(function()
						if not managingAlias then
							managingAlias = true
							aliasModificationBusy = true
							createPromptData:changeCanConfirmState(false)
							createPromptData:changeCanCloseState(false)
							constructUI("Context", {
								text = "Deleting alias <b>" .. Parser:filterForRichText(aliasName) .. "</b>",
								plainText = "Deleting alias " .. aliasName,
								expireOs = osTime() + 8,
							})
							local deleteRetCode = Network:get("DeleteCustomCmdAlias", aliasName)
							if deleteRetCode == -1 then
								constructUI("Context", {
									text = "Alias <b>"
										.. Parser:filterForRichText(aliasName)
										.. "</b> failed to delete due to non-existence.",
									plainText = "Alias " .. aliasName .. " failed to delete due to non-existence.",
									expireOs = osTime() + 8,
								})
							elseif deleteRetCode == true then
								constructUI("Context", {
									text = "Alias <b>"
										.. Parser:filterForRichText(aliasName)
										.. "</b> successfully deleted.",
									plainText = "Alias " .. aliasName .. " successfully deleted.",
									expireOs = osTime() + 8,
								})
							end
							createPromptData:changeCanConfirmState(true)
							createPromptData:changeCanCloseState(true)
							aliasModificationBusy = false
							managingAlias = false
							createPromptData:destroy()
							deleteAliasInteraction(aliasActionButton)
						else
							constructUI("Context", {
								text = "You can't delete the alias until the other alias has finished managing.",
								expireOs = osTime() + 8,
							})
						end
					end)

					createPromptData.confirmed:connect(function()
						if managingAlias then
							constructUI("Context", {
								text = "Unable to update your custom alias while the other alias is being updated. Please try again later!",
								expireOs = osTime() + 4,
							})
						else
							managingAlias = true

							local updateRetCode =
								Network:get("UpdateCustomCmdAlias", aliasName, aliasCmdLineTF.currentInput)
							if updateRetCode == -1 then
								constructUI("Context", {
									text = "Alias <b>"
										.. Parser:filterForRichText(aliasName)
										.. "</b> failed to update due to non-existence.",
									plainText = "Alias " .. aliasName .. " failed to update due to non-existence.",
									expireOs = osTime() + 8,
								})
								deleteAliasInteraction(aliasActionButton)
							elseif updateRetCode == -2 then
								constructUI("Context", {
									text = "Alias <b>"
										.. Parser:filterForRichText(aliasName)
										.. "</b> failed to update because the command you specified doesn't exist.",
									plainText = "Alias "
										.. aliasName
										.. " failed to update because the command you specified doesn't exist.",
									expireOs = osTime() + 8,
								})
								deleteAliasInteraction(aliasActionButton)
							elseif updateRetCode == true then
								constructUI("Context", {
									text = "Alias <b>"
										.. Parser:filterForRichText(aliasName)
										.. "</b> successfully updated.",
									plainText = "Alias " .. aliasName .. " successfully updated.",
									expireOs = osTime() + 8,
								})
								cmdLine = aliasCmdLineTF.currentInput
							end

							task.delay(3, function() managingAlias = false end)
						end
					end)

					createPromptData:show()
					createPromptData.hidden:connectOnce(function()
						didCreatePrompt = false
						createPromptData:destroy()
					end)
				end
			end)

			table.insert(aliasActionObjs, aliasActionButton)
			createAliasButton.label.Text = #aliasActionObjs .. " alias(es) created"
			sortAliasInteractions()

			aliasActionButton._object.Visible = true

			return aliasActionButton
		end

		createAliasButton.clicked:connect(function()
			if not didCreatePrompt and not managingAlias then
				didCreatePrompt = true
				createPromptData = window:createPrompt "Create alias"

				local shortcutTF = createPromptData:addTextField "Personal cmd alias"
				shortcutTF.inputPattern = "^%s*(.-)%s*$"
				shortcutTF:changeHint("Up to " .. aliasCharLimit .. " characters")
				shortcutTF.charLimit = aliasCharLimit

				local executeTF = createPromptData:addTextField "Target command"
				executeTF.inputPattern = "^%s*(.-)$"
				executeTF:changeHint "Command you want to refer the alias"

				createPromptData:show()
				createPromptData.confirmed:connect(function()
					managingAlias = true
					local aliasName, aliasCommandLine = shortcutTF.currentInput, executeTF.currentInput

					if #aliasName < 2 then
						constructUI("Context", {
							text = "Alias name must have at least two chars.",
							expireOs = osTime() + 6,
						})
					elseif #aliasCommandLine == 0 then
						constructUI("Context", {
							text = "Alias command line must have at least one character.",
							expireOs = osTime() + 6,
						})
					else
						constructUI("Context", {
							text = "Creating alias <b>" .. Parser:filterForRichText(aliasName) .. "</b>..",
							plainText = "Creating alias " .. aliasName .. "..",
							expireOs = osTime() + 8,
						})

						task.wait(1)
						local createRetCode = Network:get("CreateCustomCmdAlias", aliasName, aliasCommandLine)
						if createRetCode == -1 then
							constructUI("Context", {
								text = "Unable to create new alias due to alias roadblock.",
								expireOs = osTime() + 6,
							})
						elseif createRetCode == -2 then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> already exists. Creation canceled.",
								plainText = "Alias " .. aliasName .. " already exists. Creation canceled.",
								expireOs = osTime() + 6,
							})
						elseif createRetCode == -2.5 then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> is not a safe string. Pick different phrase(s) for your alias.",
								plainText = "Alias "
									.. aliasName
									.. " is not a safe string. Pick different phrase(s) for your alias.",
								expireOs = osTime() + 6,
							})
						elseif createRetCode == -3 then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> contains a batch separator. Creation canceled.",
								plainText = "Alias " .. aliasName .. " contains a batch separator. Creation canceled.",
								expireOs = osTime() + 6,
							})
						elseif createRetCode == -4 then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> is similar to another CC alias.",
								plainText = "Alias " .. aliasName .. " is similar to another CC alias.",
								expireOs = osTime() + 6,
							})
						elseif createRetCode == -5 then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> didn't refer to an existant command.",
								plainText = "Alias " .. aliasName .. " didn't refer to an existant command.",
								expireOs = osTime() + 6,
							})
						else
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> has successfully been created.",
								plainText = "Alias " .. aliasName .. " has successfully been created.",
								expireOs = osTime() + 8,
							})
							createAliasInteraction(aliasName, aliasCommandLine)
						end
					end
					managingAlias = false
				end)
				createPromptData.hidden:connectOnce(function()
					didCreatePrompt = false
					createPromptData:destroy()
				end)
			end
		end)

		deleteAliasButton.clicked:connect(function()
			if not didCreatePrompt and not managingAlias then
				didCreatePrompt = true
				deletePromptData = window:createPrompt "Delete alias"
				deletePromptData.canConfirm = false

				local shortcutTF = deletePromptData:addTextField "Alias name"
				shortcutTF:changeHint("Up to " .. aliasCharLimit .. " characters")
				shortcutTF.charLimit = aliasCharLimit

				local deleteAliasButton = deletePromptData:addButton("", "Delete alias")
				deleteAliasButton:highlightInput(Color3.fromRGB(255, 66, 66))
				deleteAliasButton.clicked:connect(function()
					local aliasName = Parser:trimString(shortcutTF.currentInput)
					if not managingAlias and #aliasName > 0 then
						managingAlias = true
						deletePromptData:changeCanCloseState(false)
						local deleteRetCode = Network:get("DeleteCustomCmdAlias", aliasName)
						if deleteRetCode == -1 then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> failed to delete due to non-existence.",
								plainText = "Alias " .. aliasName .. " failed to delete due to non-existence.",
								expireOs = osTime() + 8,
							})
						elseif deleteRetCode == true then
							constructUI("Context", {
								text = "Alias <b>"
									.. Parser:filterForRichText(aliasName)
									.. "</b> successfully deleted.",
								plainText = "Alias " .. aliasName .. " successfully deleted.",
								expireOs = osTime() + 8,
							})

							local aliasButton = (function()
								for i, aliasButtonData in pairs(aliasActionObjs) do
									if aliasButtonData.aliasName:lower() == aliasName:lower() then
										return aliasButtonData
									end
								end
							end)()

							if aliasButton then deleteAliasInteraction(aliasButton) end
						end
						deletePromptData:changeCanCloseState(true)

						task.delay(3, function() managingAlias = false end)
					end
				end)
				deletePromptData:show()
				deletePromptData.confirmed:connectOnce(function() end)
				deletePromptData.hidden:connectOnce(function()
					didCreatePrompt = false
					deletePromptData:destroy()
				end)
			end
		end)

		for aliasName, cmdLine in pairs(createdCmdAliases) do
			createAliasInteraction(aliasName, cmdLine)
		end
	end

	--// Keybinds
	do
		local keybindNameCharLimit = 30
		local createdCmdKeybinds = Network:get "GetCmdKeybinds" or {}
		local managingKeybind = false

		local keybindSettingsCatg = window:createCategory "Keybinds"

		local createKeybindButton = keybindSettingsCatg:makeObject "Button"
		createKeybindButton._object.Position = UDim2.new(0, 10, 0, 0)
		createKeybindButton.label.Text = #createdCmdKeybinds .. " keybind(s) created"
		createKeybindButton.button.Text = "Create new"

		local deleteKeybindButton = keybindSettingsCatg:makeObject "Button"
		deleteKeybindButton._object.Position = UDim2.new(0, 10, 0, 40 + 10)
		deleteKeybindButton.label.Text = "Delete keybind"
		deleteKeybindButton.button.Text = "Open prompt"

		keybindSettingsCatg:makeInstance("TextLabel", {
			Text = "Existing Keybinds",
			TextSize = 16,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(239, 239, 239),
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 10, 0, 50 + deleteKeybindButton._object.AbsoluteSize.Y + 10),
			Size = UDim2.new(0, 200, 0, 20),
		})

		local didCreatePrompt = false
		local createPromptData, deletePromptData = nil

		local keybindActionObjs = {}
		local function sortKeybindInteractions()
			local num = 0
			for i, keybindActionData in ipairs(keybindActionObjs) do
				keybindActionData._object.LayoutOrder = 3 + i
				keybindActionData._object.Position = UDim2.fromOffset(10, 100 + (i * 40) + (-10 + (i * 10)))
				num += 1
			end

			if num > 3 then
				keybindSettingsCatg:changeSize(UDim2.new(1, 0, 0, 280 + ((num - 3) * 40) + (-10 + ((num - 5) * 10))))
			end
		end

		local function deleteKeybindInteraction(keybindAction)
			local actionInd = table.find(keybindActionObjs, keybindAction)
			if actionInd then
				table.remove(keybindActionObjs, actionInd)
				createKeybindButton.label.Text = #keybindActionObjs .. " keybind(s) created"
				keybindAction:destroy()
				sortKeybindInteractions()
			end
		end

		local function createKeybindInteraction(
			keybindName: string,
			interactOptions: {
				commandLine: string?,
				duration: number?,

				description: string?,

				enabled: boolean?,
				defaultHotkeys: { [number]: Enum.KeyCode },
				hotkeys: { [number]: Enum.KeyCode },

				saveId: string?,
				locked: boolean?, --// Makes the keybinds not editable
				commandKeybindId: string?, --// Command keybind id
			}
		)
			interactOptions.hotkeys = interactOptions.hotkeys or {}
			interactOptions.duration = interactOptions.duration or 0
			interactOptions.saveId = if interactOptions.saveId then interactOptions.saveId:upper() else nil

			local isKeybindLocked = interactOptions.locked

			local keybindActionButton = keybindSettingsCatg:makeObject "Button"
			local defaultKeybindActionLabelColor = keybindActionButton.label.TextColor3
			keybindActionButton._object.Visible = false

			keybindActionButton.label.Text = keybindName
			keybindActionButton.label.TextTruncate = Enum.TextTruncate.AtEnd
			keybindActionButton.button.Text = if isKeybindLocked then `View` else "Modify"
			keybindActionButton.keybindName = keybindName

			keybindActionButton.label.TextColor3 = if not interactOptions.enabled
				then Color3.fromRGB(113, 113, 113)
				else defaultKeybindActionLabelColor

			keybindActionButton.clicked.debugError = true
			keybindActionButton.clicked:connect(function()
				if not didCreatePrompt then
					didCreatePrompt = true

					local keybindModificationBusy = false

					createPromptData = window:createPrompt "View keybind"
					createPromptData.canConfirm = false

					local keybindNameTF = createPromptData:addTextField "Keybind Name"
					keybindNameTF.inputPattern = "^%s*(.-)%s*$"
					keybindNameTF.inputBox.Text = interactOptions.commandKeybindId or keybindName
					keybindNameTF.currentInput = interactOptions.commandKeybindId or keybindName
					keybindNameTF.inputBox.TextEditable = false
					keybindNameTF.minimumCharLength = 2
					keybindNameTF.charLimit = keybindNameCharLimit
					keybindNameTF:changeHint(
						interactOptions.description
							or `This is a {if interactOptions.commandKeybindId then `command` else `custom`} keybind`
					)

					local keybindsRec = createPromptData:addButton("Keybinds", nil, `KeybindListener`)
					keybindsRec:changeHint(
						if isKeybindLocked
							then `* <i>read only</i>`
							elseif
								not (interactOptions.commandKeybindId or interactOptions.saveId)
							then `* <i>not persistent to save after leaving the server</i>`
							else "Up to three hotkeys in one keybind register"
					)
					keybindsRec.keybindsLocked = if isKeybindLocked then true else false
					keybindsRec.defaultHotkeys = interactOptions.defaultHotkeys or nil
					keybindsRec.savedHotkeys = service.cloneTable(interactOptions.hotkeys)
					keybindsRec:updateKeyCodeText()

					if not isKeybindLocked then
						keybindsRec.hotkeysChanged:connectOnce(
							function() createPromptData:changeCanConfirmState(true) end
						)
					end

					local keybindsDuration = createPromptData:addTextField("Hold Duration", "integer")
					keybindsDuration.inputBox.PlaceholderText = "0"
					keybindsDuration.minimumNumber = 0
					keybindsDuration.maximumNumber = 60
					keybindsDuration.inputBox.Text = tostring(interactOptions.duration)
					keybindsDuration.inputBox.TextEditable = interactOptions.commandKeybindId and not isKeybindLocked
					keybindsDuration.currentInput = tostring(interactOptions.duration)
					keybindsDuration:changeHint(
						if not interactOptions.commandKeybindId or isKeybindLocked
							then `* <i>read only</i>`
							else "* Determines the hold duration of the keybind in seconds to trigger (Maximum: 60 seconds) (Default: 0 seconds)"
					)

					if not isKeybindLocked then
						local durationChanged
						durationChanged = keybindsDuration.inputChanged:connect(function()
							if keybindsDuration.inputBox.Text ~= tostring(interactOptions.duration) then
								durationChanged:disconnect()
								createPromptData:changeCanConfirmState(true)
							end
						end)
					end

					local executeTF
					local enabledBF
					local changeKeybindType: "Update" | "Delete" = if interactOptions.commandKeybindId
						then `Delete`
						else `Update`

					if interactOptions.commandKeybindId and interactOptions.commandLine then
						executeTF = createPromptData:addTextField "Execute Input"
						executeTF.inputBox.Text = interactOptions.commandLine
						executeTF.currentInput = interactOptions.commandLine
						executeTF.inputPattern = "^%s*(.-)$"
						executeTF:changeHint "List all the command executions to bind"
						executeTF.charLimit = aliasAndShortcutCmdLineCharLimit

						local tempInputChanged
						tempInputChanged = executeTF.inputChanged:connect(function()
							if executeTF.inputBox.Text ~= interactOptions.commandLine then
								tempInputChanged:disconnect()
								createPromptData:changeCanConfirmState(true)
							end
						end)

						enabledBF = createPromptData:addButton(`Hotkey Enabled`, nil, "Toggle")

						enabledBF:toggleSwitch(interactOptions.enabled or false)
						enabledBF.clicked:connectOnce(function() createPromptData:changeCanConfirmState(true) end)
					elseif interactOptions.commandKeybindId and not interactOptions.commandLine then
						warn(`Command keybind {interactOptions.commandKeybindId} is missing a command line`)
					end

					if not isKeybindLocked then
						local deleteKeybindAction = createPromptData:addButton(
							if changeKeybindType == "Update" then `Restore default keybinds` else `Delete Keybind`,
							"Confirm"
						)
						deleteKeybindAction:highlightInput(
							if changeKeybindType == "Update"
								then Color3.fromRGB(255, 137, 33)
								else Color3.fromRGB(255, 66, 66)
						)

						deleteKeybindAction.clicked:connect(function()
							if managingKeybind then
								constructUI("Context", {
									text = `You can't {changeKeybindType:lower()} the keybind until the other keybind has finished managing.`,
									expireOs = osTime() + 8,
								})
								return
							end

							managingKeybind = true
							keybindModificationBusy = true

							createPromptData:changeCanConfirmState(false)
							createPromptData:changeCanCloseState(false)

							if changeKeybindType == "Update" then
								Network:get("UpdateCustomKeybind", interactOptions.saveId, nil)
								local keybindData = client.Utility.Keybinds:find(keybindName)

								--warn("did reset keybinddata?")
								--warn(`keybind keys match to default: {if keybindData then service.tableMatch(keybindData.keys, keybindData.defaultKeys) else `Unknown`}`)
								if
									keybindData and not service.tableMatch(keybindData.keys, keybindData.defaultKeys)
								then
									interactOptions.hotkeys = table.clone(keybindData.defaultKeys)
									keybindData.keys = table.clone(keybindData.defaultKeys)
									keybindData:cancelTrigger()
								elseif not keybindData then
									deleteKeybindInteraction(keybindActionButton)
								end

								constructUI("Context", {
									text = `Restored default keybinds for keybind {Parser:filterForRichText(
										keybindName
									)}`,
									plainText = `Restored default keybinds for keybind {keybindName}`,
									expireOs = osTime() + 8,
								})

								keybindModificationBusy = false
								managingKeybind = false
								createPromptData:destroy()

								return
							end

							local deleteRetCode = Network:get("DeleteCmdKeybind", interactOptions.commandKeybindId)
							if deleteRetCode == -1 then
								constructUI("Context", {
									text = "Keybind <b>"
										.. Parser:filterForRichText(keybindName)
										.. "</b> failed to delete due to non-existence.",
									plainText = "Keybind " .. keybindName .. " failed to delete due to non-existence.",
									expireOs = osTime() + 8,
								})
								createPromptData:destroy()
								deleteKeybindInteraction(keybindActionButton)
								return
							elseif deleteRetCode == true then
								constructUI("Context", {
									text = "Keybind <b>"
										.. Parser:filterForRichText(keybindName)
										.. "</b> successfully deleted.",
									plainText = "Keybind " .. keybindName .. " successfully deleted.",
									expireOs = osTime() + 8,
								})
							end

							client.Utility.Keybinds:deregister(`CommandKeybind.{keybindName}`)
							--createPromptData:changeCanConfirmState(true)
							--createPromptData:changeCanCloseState(true)
							keybindModificationBusy = false
							managingKeybind = false
							createPromptData:destroy()
							deleteKeybindInteraction(keybindActionButton)
						end)
					end

					--// Updating the keybinds
					createPromptData.confirmed.debugError = true
					createPromptData.confirmed:connect(function()
						if managingKeybind then
							constructUI("Context", {
								text = "Unable to update your custom keybind while the other keybind is being updated. Please try again later!",
								expireOs = osTime() + 4,
							})
							return
						end

						managingKeybind = true

						local newDuration = tonumber(keybindsDuration.currentInput) or interactOptions.duration
						local newHotkeys = service.cloneTable(keybindsRec.savedHotkeys)

						if changeKeybindType == "Update" then
							if interactOptions.saveId then
								local isHotkeysSameAsDefault =
									service.tableMatch(newHotkeys, keybindsRec.defaultHotkeys)
								Network:get(
									"UpdateCustomKeybind",
									interactOptions.saveId,
									if isHotkeysSameAsDefault then nil else newHotkeys
								)

								variables.savedCustomKeybinds[interactOptions.saveId] = if isHotkeysSameAsDefault
									then nil
									else newHotkeys
							end

							local keybindData = client.Utility.Keybinds:find(keybindName)
							if keybindData then
								keybindData.keys = table.clone(newHotkeys)
								keybindData:cancelTrigger()
							end

							interactOptions.hotkeys = table.clone(newHotkeys)

							constructUI("Context", {
								text = `Successfully updated Keybind {keybindName}`,
								expireOs = osTime() + 4,
							})

							task.delay(3, function() managingKeybind = false end)

							return
						end

						local newExecuteInput = executeTF.currentInput

						local updateRetCode = Network:get(
							"UpdateCmdKeybind",
							interactOptions.commandKeybindId,
							newHotkeys,
							newDuration,
							newExecuteInput,
							if enabledBF then enabledBF.switchState else true
						)
						if updateRetCode == -1 then
							constructUI("Context", {
								text = "Keybind <b>"
									.. Parser:filterForRichText(keybindName)
									.. "</b> failed to update due to non-existence.",
								plainText = "Keybind " .. keybindName .. " failed to update due to non-existence.",
								expireOs = osTime() + 8,
							})
							deleteKeybindInteraction(keybindActionButton)
						elseif updateRetCode == -2 then
							constructUI("Context", {
								text = "Keybind <b>"
									.. Parser:filterForRichText(keybindName)
									.. "</b> failed to update because the keybind name you specified doesn't exist.",
								plainText = "Keybind "
									.. keybindName
									.. " failed to update because the keybind name you specified doesn't exist.",
								expireOs = osTime() + 8,
							})
							deleteKeybindInteraction(keybindActionButton)
						elseif updateRetCode == true then
							constructUI("Context", {
								text = "Keybind <b>"
									.. Parser:filterForRichText(keybindName)
									.. "</b> successfully updated.",
								plainText = "Keybind " .. keybindName .. " successfully updated.",
								expireOs = osTime() + 8,
							})
							interactOptions.enabled = if enabledBF
								then enabledBF.switchState
								else interactOptions.enabled
							interactOptions.duration = newDuration
							interactOptions.hotkeys = newHotkeys
							interactOptions.commandLine = newExecuteInput

							local cliKeybindData = client.Utility.Keybinds:find(`{keybindName}`)
							if cliKeybindData then
								local toggleKeybindState = if enabledBF then enabledBF.switchState else true

								keybindActionButton.label.TextColor3 = if not toggleKeybindState
									then Color3.fromRGB(113, 113, 113)
									else defaultKeybindActionLabelColor

								cliKeybindData.enabled = toggleKeybindState
								cliKeybindData.hotkeys = newHotkeys
								cliKeybindData.holdDuration = newDuration
								cliKeybindData:cancelTrigger()
							end
						end

						task.delay(3, function() managingKeybind = false end)
					end)

					createPromptData:show()
					createPromptData.hidden:connectOnce(function()
						didCreatePrompt = false
						createPromptData:destroy()
					end)
				end
			end)

			table.insert(keybindActionObjs, keybindActionButton)
			createKeybindButton.label.Text = #keybindActionObjs .. " keybind(s) created"
			sortKeybindInteractions()

			keybindActionButton._object.Visible = true

			return keybindActionButton
		end

		createKeybindButton.clicked:connect(function()
			if not didCreatePrompt and not managingKeybind then
				didCreatePrompt = true
				createPromptData = window:createPrompt "Create keybind"

				local keybindNameTF = createPromptData:addTextField "Keybind Name"
				keybindNameTF.inputPattern = "^%s*(.-)%s*$"
				keybindNameTF:changeHint("Up to " .. keybindNameCharLimit .. " characters")
				keybindNameTF.minimumCharLength = 2
				keybindNameTF.charLimit = keybindNameCharLimit

				local keybindsRec = createPromptData:addButton("Keybinds", nil, true)
				keybindsRec.requireKeybinds = true
				keybindsRec:changeHint "Up to three hotkeys in one keybind register"

				local keybindsDuration = createPromptData:addTextField("Hold Duration", "integer")
				keybindsDuration.currentInput = "0"
				keybindsDuration.inputBox.PlaceholderText = "0"
				keybindsDuration.minimumNumber = 0
				keybindsDuration.maximumNumber = 60
				keybindsDuration:changeHint "Determines the hold duration of the keybind in seconds to trigger (Maximum: 60 seconds) (Default: 0 seconds)"

				local executeTF = createPromptData:addTextField "Execute Input"
				executeTF.inputBox.PlaceholderText = ":bring all"
				executeTF.inputPattern = "^%s*(.-)$"
				executeTF.minimumCharLength = 3
				executeTF:changeHint "List all the command executions to bind"
				executeTF.charLimit = aliasAndShortcutCmdLineCharLimit

				local enabledBF = createPromptData:addButton(`Hotkey Enabled`, nil, "Toggle")
				enabledBF:toggleSwitch(true)

				createPromptData:show()
				createPromptData.confirmed:connect(function()
					managingKeybind = true
					local keybindName, keybindCommandLine = keybindNameTF.currentInput, executeTF.currentInput
					keybindName = keybindName:lower()

					keybindsRec.keybindsLocked = true

					if #keybindName == 0 then
						constructUI("Context", {
							text = `The keybind name must have at least 2 characters.`,
							plainText = `The keybind name must have at least 2 characters.`,
							expireOs = osTime() + 8,
						})
						managingKeybind = false
						return
					end

					constructUI("Context", {
						text = "Creating keybind <b>" .. Parser:filterForRichText(keybindName) .. "</b>..",
						plainText = "Creating keybind " .. keybindName .. "..",
						expireOs = osTime() + 8,
					})

					task.wait(1)
					local createRetCode = Network:get(
						"CreateCmdKeybind",
						keybindName,
						keybindsRec.savedHotkeys,
						tonumber(keybindsDuration.currentInput) or 0,
						keybindCommandLine,
						enabledBF.switchState
					)
					if createRetCode == -1 then
						constructUI("Context", {
							text = "Unable to create new keybind due to keybind roadblock.",
							expireOs = osTime() + 6,
						})
					elseif createRetCode == -2 then
						constructUI("Context", {
							text = "Keybind <b>"
								.. Parser:filterForRichText(keybindName)
								.. "</b> already exists. Creation canceled.",
							plainText = "Keybind " .. keybindName .. " already exists. Creation canceled.",
							expireOs = osTime() + 6,
						})
					elseif createRetCode == -2.5 then
						constructUI("Context", {
							text = "Keybind <b>"
								.. Parser:filterForRichText(keybindName)
								.. "</b> is not a safe string. Pick different phrase(s) for your keybind.",
							plainText = "Keybind "
								.. keybindName
								.. " is not a safe string. Pick different phrase(s) for your keybind.",
							expireOs = osTime() + 6,
						})
					elseif createRetCode == -3 then
						constructUI("Context", {
							text = "Keybind <b>"
								.. Parser:filterForRichText(keybindName)
								.. "</b> doesn't contain valid hotkeys.",
							plainText = "Keybind " .. keybindName .. " doesn't contain valid hotkeys.",
							expireOs = osTime() + 6,
						})
					elseif createRetCode == -4 then
						constructUI("Context", {
							text = "Keybind <b>"
								.. Parser:filterForRichText(keybindName)
								.. "</b> doesn't have hotkeys.",
							plainText = "Keybind " .. keybindName .. " doesn't have	 hotkeys.",
							expireOs = osTime() + 6,
						})
					else
						constructUI("Context", {
							text = "Keybind <b>"
								.. Parser:filterForRichText(keybindName)
								.. "</b> has successfully been created.",
							plainText = "Keybind " .. keybindName .. " has successfully been created.",
							expireOs = osTime() + 8,
						})

						createKeybindInteraction(`CommandKeybind.{keybindName}`, {
							enabled = enabledBF.switchState,
							hotkeys = service.shallowCloneTable(keybindsRec.savedHotkeys),
							defaultHotkeys = service.shallowCloneTable(keybindsRec.savedHotkeys),
							duration = tonumber(keybindsDuration.currentInput) or 0,
							commandLine = keybindCommandLine,
							commandKeybindId = keybindName,
						})

						client.Utility.Keybinds:register(`CommandKeybind.{keybindName}`, {
							trigger = "CommandKeybind",
							commandKeybindId = keybindName,
							holdDuration = tonumber(keybindsDuration),
							keys = keybindsRec.savedHotkeys,
						})
					end

					managingKeybind = false
				end)
				createPromptData.hidden:connectOnce(function()
					didCreatePrompt = false
					createPromptData:destroy()
				end)
			end
		end)

		deleteKeybindButton.clicked:connect(function()
			if not didCreatePrompt and not managingKeybind then
				didCreatePrompt = true
				deletePromptData = window:createPrompt "Delete keybind"
				deletePromptData.canConfirm = false

				local keybindNameTF = deletePromptData:addTextField "Keybind name"
				keybindNameTF:changeHint("Up to " .. keybindNameCharLimit .. " characters")
				keybindNameTF.minimumCharLength = 2
				keybindNameTF.charLimit = keybindNameCharLimit

				local deleteKeybindButton = deletePromptData:addButton("", "Delete keybind")
				deleteKeybindButton:highlightInput(Color3.fromRGB(255, 66, 66))
				deleteKeybindButton.clicked:connect(function()
					local keybindName = Parser:trimString(keybindNameTF.currentInput)
					keybindName = keybindName:lower()

					if not managingKeybind and #keybindName > 0 then
						managingKeybind = true
						deletePromptData:changeCanCloseState(false)
						local deleteRetCode = Network:get("DeleteCmdKeybind", keybindName)
						if deleteRetCode == -1 then
							constructUI("Context", {
								text = "Keybind <b>"
									.. Parser:filterForRichText(keybindName)
									.. "</b> failed to delete due to non-existence.",
								plainText = "Keybind " .. keybindName .. " failed to delete due to non-existence.",
								expireOs = osTime() + 8,
							})
						elseif deleteRetCode == true then
							client.Utility.Keybinds:deregister(`CommandKeybind.{keybindName}`)

							constructUI("Context", {
								text = "Keybind <b>"
									.. Parser:filterForRichText(keybindName)
									.. "</b> successfully deleted.",
								plainText = "Keybind " .. keybindName .. " successfully deleted.",
								expireOs = osTime() + 8,
							})

							local keybindButton = (function()
								for i, keybindButtonData in pairs(keybindActionObjs) do
									if keybindButtonData.keybindName:lower() == keybindName:lower() then
										return keybindButtonData
									end
								end
							end)()

							if keybindButton then deleteKeybindInteraction(keybindButton) end
						end
						deletePromptData:changeCanCloseState(true)

						task.delay(3, function() managingKeybind = false end)
					end
				end)
				deletePromptData:show()
				deletePromptData.hidden:connectOnce(function()
					didCreatePrompt = false
					deletePromptData:destroy()
				end)
			end
		end)

		-- Client keybinds
		for
			i,
			keybindData: {
			_name: string,
			_saveId: string?,
			holdDuration: number,
			locked: boolean?,
			hidden: boolean?,
			keys: { [number]: Enum.KeyCode },
			_priority: number,
		}
		in client.Utility.Keybinds.registeredKeybinds do
			if keybindData.hidden then continue end
			createKeybindInteraction(keybindData._name, {
				hotkeys = keybindData.keys,
				duration = keybindData.holdDuration,
				defaultHotkeys = keybindData.defaultKeys,
				saveId = keybindData._saveId,
				enabled = keybindData.enabled,
				locked = keybindData.locked,
				commandLine = keybindData.commandLine,
				commandKeybindId = keybindData.commandKeybindId,
				description = keybindData.description,
			})
		end
	end

	--// Buttons
	do
		local buttonCharLimit = 40
		local createdCmdShortcuts = Network:get "GetCommandButtons" or {}
		local buttonsSettingsCatg = window:createCategory "Shortcuts"

		local shortcutTopbarIcons = variables.shortcutTopbarIcons or {}
		variables.shortcutTopbarIcons = shortcutTopbarIcons

		local createActionButton = buttonsSettingsCatg:makeObject "Button"
		createActionButton._object.Position = UDim2.new(0, 10, 0, 0)
		createActionButton.label.Text = "0 shortcuts created"
		createActionButton.button.Text = "Create new"

		local deleteActionButton = buttonsSettingsCatg:makeObject "Button"
		deleteActionButton._object.Position = UDim2.new(0, 10, 0, 40 + 10)
		deleteActionButton.label.Text = "Delete shortcut"
		deleteActionButton.button.Text = "Open prompt"

		local didCreatePrompt = false
		local createPromptData, deletePromptData = nil
		local managingButton = false

		local buttonActionObjs = {}
		local function sortButtonInteractions()
			local num = 0
			for i, buttonActionData in ipairs(buttonActionObjs) do
				buttonActionData._object.LayoutOrder = 3 + i
				buttonActionData._object.Position = UDim2.fromOffset(10, 100 + (i * 40) + (-10 + (i * 10)))
				num += 1
			end

			if num > 3 then
				buttonsSettingsCatg:changeSize(UDim2.new(1, 0, 0, 280 + ((num - 3) * 40) + (-10 + ((num - 5) * 10))))
			end
		end

		local function deleteButtonInteraction(buttonAction)
			local actionInd = table.find(buttonActionObjs, buttonAction)
			if actionInd then
				table.remove(buttonActionObjs, actionInd)
				createActionButton.label.Text = #buttonActionObjs .. " shortcut(s) created"
				buttonAction:destroy()

				local topbarIcon = shortcutTopbarIcons[buttonAction.buttonName]

				if topbarIcon then
					shortcutTopbarIcons[buttonAction.buttonName] = nil
					topbarIcon:destroy()
				end

				local topbarIconCount = service.tableCount(shortcutTopbarIcons)

				if topbarIconCount == 0 then
					if client.shortcutsIcon and client.Policies._clientPolicies.SHORTCUTS_ALLOWED.value == true then
						client.shortcutsIcon:setEnabled(false)
					end
				end

				sortButtonInteractions()
			end
		end

		local function createButtonInteraction(buttonName: string, cmdLine: string)
			local buttonTopbarIcon = constructElement "TopbarIcon"
			buttonTopbarIcon:setTheme(client.TopbarIconTheme.Base)
			buttonTopbarIcon:setImage "rbxassetid://9030162754"
			buttonTopbarIcon:setLeft()
			buttonTopbarIcon:setOrder(10)
			buttonTopbarIcon:setLabel(buttonName)
			buttonTopbarIcon.selected:Connect(function()
				buttonTopbarIcon:deselect()
				if client.Policies._clientPolicies.SHORTCUTS_ALLOWED.value ~= true then return end
				Network:fire("RunCommandButton", buttonName)
			end)
			if client.shortcutsIcon and not shortcutTopbarIcons[buttonName] then
				buttonTopbarIcon:joinDropdown(client.shortcutsIcon, "dropdown")
				shortcutTopbarIcons[buttonName] = buttonTopbarIcon
			else
				buttonTopbarIcon:destroy()
			end

			local buttonActionButton = buttonsSettingsCatg:makeObject "Button"
			buttonActionButton._object.Visible = false
			buttonActionButton.label.Text = buttonName
			buttonActionButton.label.TextTruncate = Enum.TextTruncate.AtEnd
			buttonActionButton.button.Text = "Modify"
			buttonActionButton.buttonName = buttonName

			buttonActionButton.clicked:connect(function()
				if not didCreatePrompt then
					didCreatePrompt = true

					local buttonModificationBusy = false

					createPromptData = window:createPrompt "View shortcut"
					createPromptData.canConfirm = false

					local buttonNameTF = createPromptData:addTextField "Button name"
					buttonNameTF.charLimit = buttonCharLimit
					buttonNameTF.inputPattern = "^%s*(.-)%s*$"
					buttonNameTF.inputBox.TextEditable = false
					buttonNameTF.inputBox.Text = buttonName
					buttonNameTF:changeHint "<i>* read only</i>"

					local buttonCmdLineTF = createPromptData:addTextField "Execute Input"
					buttonCmdLineTF.charLimit = aliasAndShortcutCmdLineCharLimit
					buttonCmdLineTF.inputBox.Text = cmdLine
					buttonCmdLineTF.inputPattern = "^%s*(.-)$"

					local tempInputChanged
					tempInputChanged = buttonCmdLineTF.inputChanged:connect(function()
						if buttonCmdLineTF.inputBox.Text ~= cmdLine then
							tempInputChanged:disconnect()
							createPromptData:changeCanConfirmState(true)
						end
					end)

					local deleteButtonAction = createPromptData:addButton("Delete button", "Confirm")
					deleteButtonAction:highlightInput(Color3.fromRGB(255, 66, 66))
					deleteButtonAction.clicked:connect(function()
						if not managingButton then
							managingButton = true
							buttonModificationBusy = true
							createPromptData:changeCanConfirmState(false)
							createPromptData:changeCanCloseState(false)
							constructUI("Context", {
								text = "Deleting button <b>" .. Parser:filterForRichText(buttonName) .. "</b>",
								plainText = "Deleting button " .. buttonName,
								expireOs = osTime() + 8,
							})
							local deleteRetCode = Network:get("DeleteCommandButton", buttonName)
							if deleteRetCode == -1 then
								constructUI("Context", {
									text = "Button <b>"
										.. Parser:filterForRichText(buttonName)
										.. "</b> failed to delete due to non-existence.",
									plainText = "Button " .. buttonName .. " failed to delete due to non-existence.",
									expireOs = osTime() + 8,
								})
							elseif deleteRetCode == true then
								constructUI("Context", {
									text = "Button <b>"
										.. Parser:filterForRichText(buttonName)
										.. "</b> successfully deleted.",
									plainText = "Button " .. buttonName .. " successfully deleted.",
									expireOs = osTime() + 8,
								})
							end
							createPromptData:changeCanConfirmState(true)
							createPromptData:changeCanCloseState(true)
							buttonModificationBusy = false
							managingButton = false
							createPromptData:destroy()
							deleteButtonInteraction(buttonActionButton)
						else
							constructUI("Context", {
								text = "You can't delete the button until the other button has finished managing.",
								expireOs = osTime() + 8,
							})
						end
					end)

					createPromptData.confirmed:connect(function()
						if managingButton then
							constructUI("Context", {
								text = "Unable to update your custom button while the other is being updated. Please try again later!",
								expireOs = osTime() + 4,
							})
						else
							managingButton = true

							local updateRetCode =
								Network:get("UpdateCommandButton", buttonName, buttonCmdLineTF.currentInput)
							if updateRetCode == -1 then
								constructUI("Context", {
									text = "Button <b>"
										.. Parser:filterForRichText(buttonName)
										.. "</b> failed to update due to non-existence.",
									plainText = "Button " .. buttonName .. " failed to update due to non-existence.",
									expireOs = osTime() + 8,
								})
								deleteButtonInteraction(buttonActionButton)
							elseif updateRetCode == true then
								constructUI("Context", {
									text = "Button <b>"
										.. Parser:filterForRichText(buttonName)
										.. "</b> successfully updated.",
									plainText = "Button " .. buttonName .. " successfully updated.",
									expireOs = osTime() + 8,
								})
								cmdLine = buttonCmdLineTF.currentInput
							end

							task.delay(3, function() managingButton = false end)
						end
					end)

					createPromptData:show()
					createPromptData.hidden:connectOnce(function()
						didCreatePrompt = false
						createPromptData:destroy()
					end)
				end
			end)

			table.insert(buttonActionObjs, buttonActionButton)
			createActionButton.label.Text = #buttonActionObjs .. " shortcut(s) created"
			sortButtonInteractions()

			warn('did show shortcut?')
			if client.shortcutsIcon and not client.shortcutsIcon.enabled then
				warn("fr?")
				client.shortcutsIcon:deselect()
				if client.Policies._clientPolicies.SHORTCUTS_ALLOWED.value == true then
					warn("so did?")
					client.shortcutsIcon:setEnabled(true)
				end
			end

			buttonActionButton._object.Visible = true

			return buttonActionButton
		end

		createActionButton.clicked:connect(function()
			if not didCreatePrompt and not managingButton then
				didCreatePrompt = true
				createPromptData = window:createPrompt "Create button"

				local shortcutTF = createPromptData:addTextField "Button name"
				shortcutTF.inputPattern = "^%s*(.-)%s*$"
				shortcutTF:changeHint("Up to " .. buttonCharLimit .. " characters")
				shortcutTF.charLimit = buttonCharLimit

				local executeTF = createPromptData:addTextField "Execute Input"
				executeTF.inputBox.PlaceholderText = ":bring all"
				executeTF.inputPattern = "^%s*(.-)$"
				executeTF:changeHint(
					"Command line for the button (" .. aliasAndShortcutCmdLineCharLimit .. " char limit)"
				)
				executeTF.charLimit = aliasAndShortcutCmdLineCharLimit

				createPromptData:show()
				createPromptData.confirmed:connect(function()
					managingButton = true
					local buttonName, buttonCommandLine = shortcutTF.currentInput, executeTF.currentInput

					if #buttonName < 2 then
						constructUI("Context", {
							text = "Button name must have at least two chars.",
							expireOs = osTime() + 6,
						})
					elseif #buttonCommandLine == 0 then
						constructUI("Context", {
							text = "Button command line must have at least one character.",
							expireOs = osTime() + 6,
						})
					else
						constructUI("Context", {
							text = "Creating button <b>" .. Parser:filterForRichText(buttonName) .. "</b>..",
							plainText = "Creating button " .. buttonName .. "..",
							expireOs = osTime() + 8,
						})

						task.wait(1)
						local createRetCode = Network:get("CreateCommandButton", buttonName, buttonCommandLine)
						if createRetCode == -1 then
							constructUI("Context", {
								text = "Unable to create new button due to button roadblock.",
								expireOs = osTime() + 6,
							})
						elseif createRetCode == -2 then
							constructUI("Context", {
								text = "Button <b>"
									.. Parser:filterForRichText(buttonName)
									.. "</b> already exists. Creation canceled.",
								plainText = "Button " .. buttonName .. " already exists. Creation canceled.",
								expireOs = osTime() + 6,
							})
						elseif createRetCode == -2.5 then
							constructUI("Context", {
								text = "Button <b>"
									.. Parser:filterForRichText(buttonName)
									.. "</b> is not a safe string. Pick different phrase(s) for your button.",
								plainText = "Button "
									.. buttonName
									.. " is not a safe string. Pick different phrase(s) for your button.",
								expireOs = osTime() + 6,
							})
						else
							constructUI("Context", {
								text = "Button <b>"
									.. Parser:filterForRichText(buttonName)
									.. "</b> has successfully been created.",
								plainText = "Button " .. buttonName .. " has successfully been created.",
								expireOs = osTime() + 8,
							})
							warn(pcall(function() createButtonInteraction(buttonName, buttonCommandLine) end))
							-- if windowGuiData.active then warn(pcall(function() createButtonInteraction(buttonName, buttonCommandLine) end)) end
						end
					end
					managingButton = false
				end)
				createPromptData.hidden:connectOnce(function()
					didCreatePrompt = false
					createPromptData:destroy()
				end)
			end
		end)

		deleteActionButton.clicked:connect(function()
			if not didCreatePrompt and not managingButton then
				didCreatePrompt = true
				deletePromptData = window:createPrompt "Delete button"
				deletePromptData.canConfirm = false

				local shortcutTF = deletePromptData:addTextField "Button name"
				shortcutTF:changeHint("Up to " .. buttonCharLimit .. " characters")
				shortcutTF.charLimit = buttonCharLimit

				local deleteButtonButton = deletePromptData:addButton("", "Delete button")
				deleteButtonButton:highlightInput(Color3.fromRGB(255, 66, 66))
				deleteButtonButton.clicked:connect(function()
					local buttonName = Parser:trimString(shortcutTF.currentInput)
					if not managingButton and #buttonName > 0 then
						managingButton = true
						deletePromptData:changeCanCloseState(false)
						local deleteRetCode = Network:get("DeleteCommandButton", buttonName)
						if deleteRetCode == -1 then
							constructUI("Context", {
								text = "Button <b>"
									.. Parser:filterForRichText(buttonName)
									.. "</b> failed to delete due to non-existence.",
								plainText = "Button " .. buttonName .. " failed to delete due to non-existence.",
								expireOs = osTime() + 8,
							})

							local buttonButton = (function()
								for i, buttonButtonData in pairs(buttonActionObjs) do
									if buttonButtonData.buttonName:lower() == buttonName:lower() then
										return buttonButtonData
									end
								end
							end)()

							if buttonButton then deleteButtonInteraction(buttonButton) end
						elseif deleteRetCode == true then
							constructUI("Context", {
								text = "Button <b>"
									.. Parser:filterForRichText(buttonName)
									.. "</b> successfully deleted.",
								plainText = "Button " .. buttonName .. " successfully deleted.",
								expireOs = osTime() + 8,
							})

							local buttonButton = (function()
								for i, buttonButtonData in pairs(buttonActionObjs) do
									if buttonButtonData.buttonName:lower() == buttonName:lower() then
										return buttonButtonData
									end
								end
							end)()

							if buttonButton then deleteButtonInteraction(buttonButton) end
						end
						deletePromptData:changeCanCloseState(true)

						task.delay(3, function() managingButton = false end)
					end
				end)
				deletePromptData:show()
				deletePromptData.confirmed:connectOnce(function() end)
				deletePromptData.hidden:connectOnce(function()
					didCreatePrompt = false
					deletePromptData:destroy()
				end)
			end
		end)

		for buttonName, cmdLine in pairs(createdCmdShortcuts) do
			createButtonInteraction(buttonName, cmdLine)
		end
	end

	if client.Network:get "HasAdmin" then
		local gameSettingsCatg = window:createCategory "Game"

		local clockTimeProg = gameSettingsCatg:makeObject "Progress"
		clockTimeProg.label.Text = "Clock time"
		clockTimeProg.progressIncrement = 0.001
		clockTimeProg:changeMinimumValue(0)
		clockTimeProg:changeMaximumValue(24)

		local clockTimeProgHolder = window:modifyObject {
			_object = clockTimeProg.holder,
		}

		local clockHover = clockTimeProgHolder:setHover(clockTimeProg.progressCurrentValue)
		clockTimeProg.progressChanged:connect(
			function(newValue) clockHover.text = tostring(roundNumber(newValue, 0.001)) end
		)

		clockTimeProg.progressConfirmed:connect(
			function(confirmValue) client.Network:fire("ManageLighting", "ClockTime", confirmValue) end
		)

		window.guiData.bindEvent(
			service.Lighting:GetPropertyChangedSignal "ClockTime",
			function() clockTimeProg:changeProgressByNumber(service.Lighting.ClockTime) end
		)

		-- local musicVolProg = gameSettingsCatg:makeObject "Progress"
		-- musicVolProg._object.Position = UDim2.new(0, 10, 0, 50)
		-- musicVolProg.label.Text = "Music volume"
		-- musicVolProg.progressIncrement = 0.1
		-- musicVolProg:changeMinimumValue(0)
		-- musicVolProg:changeMaximumValue(10)

		-- local musicVolHover = musicVolProg.modifiedHolder:setHover(musicVolProg.progressCurrentValue)

		-- musicVolProg.progressConfirmed:connect(function(newValue)
		-- 	musicVolProg.progressLocked = true
		-- 	local didProcess = client.Network:get("ManageMusicPlayer", "Volume", newValue)

		-- 	if not didProcess then
		-- 		local prevColor = musicVolProg.progressColor
		-- 		musicVolProg:changeColor(Color3.fromRGB(255, 55, 55))
		-- 		wait(2)
		-- 		musicVolProg:changeColor(prevColor)
		-- 		musicVolProg:changeProgressByNumber(musicVolProg.progressPreviousValue)
		-- 		wait(1)
		-- 	else
		-- 		musicVolProg:changeProgressByNumber(newValue)
		-- 	end

		-- 	musicVolProg.progressLocked = false
		-- end)

		-- musicVolProg.progressChanged:connect(function(newValue) musicVolHover.text = tostring(newValue) end)

		local onUseShutdownPrompt = false

		local shutdownServerButton = gameSettingsCatg:makeObject "Button"
		shutdownServerButton._object.Position = UDim2.new(0, 10, 0, 100)
		shutdownServerButton.label.Text = "Shutdown server"
		shutdownServerButton.button.Text = "Open prompt"

		shutdownServerButton.clicked:connect(function()
			if not onUseShutdownPrompt then
				onUseShutdownPrompt = true

				local shutdownPrompt = window:createPrompt "Shutdown server"
				shutdownPrompt.canConfirm = false

				local reasonTF = shutdownPrompt:addTextField "Reason"
				reasonTF:changeHint "Up to 200 characters (<i>* optional</i>)"
				reasonTF.charLimit = 200

				local confirmButtonButton = shutdownPrompt:addButton("", "Confirm")
				confirmButtonButton:highlightInput(Color3.fromRGB(255, 66, 66))
				confirmButtonButton.clicked:connectOnce(function()
					Network:fire(
						"ManageServer",
						"Shutdown",
						(#reasonTF.currentInput > 0 and reasonTF.currentInput) or nil
					)
					shutdownPrompt:destroy()
				end)

				shutdownPrompt:show()
				shutdownPrompt.hidden:connectOnce(function() onUseShutdownPrompt = false end)
			end
		end)
	end

	if openSpecificCategory then window:openCategory(openSpecificCategory) end

	window:ready()
end
