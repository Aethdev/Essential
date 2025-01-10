return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service
	local settings = server.Settings
	local variables = envArgs.variables
	local getEnv = envArgs.getEnv
	local script = envArgs.script

	local Cmds = server.Commands
	local Core = server.Core
	local Cross = server.Cross
	local Datastore = server.Datastore
	local Identity = server.Identity
	local Logs = server.Logs
	local Moderation = server.Moderation
	local Process = server.Process
	local Remote = server.Remote

	local Utility = server.Utility
	local Roles = server.Roles
	local Parser = server.Parser

	local LuaParser = server.LuaParser

	local cmdsList = {
		gravity = {
			Prefix = settings.actionPrefix,
			Aliases = { "gravity" },
			Arguments = { "number/fix" },
			Permissions = { "Manage_Map" },
			Roles = {},

			Description = "Modifies environment gravity to a specified gravity",

			Function = function(plr, args)
				local newGravity = tonumber(string.match(args[1] or "", "^%d+$"))

				if args[1] and args[1]:lower() == "fix" then newGravity = variables.savedEnvironment.gravity end

				workspace.Gravity = newGravity
			end,
		},

		gameTime = {
			Prefix = settings.actionPrefix,
			Aliases = { "time" },
			Arguments = {
				{
					argument = "number",
					type = "number",
					required = true,
				},
			},
			Permissions = { "Manage_Map" },
			Roles = {},

			Description = "Modifies environment time to a specified one",

			Function = function(plr, args) service.Lighting.ClockTime = args[1] end,
		},

		restoreLighting = {
			Prefix = settings.actionPrefix,
			Aliases = { "restorelighting", "fixlighting" },
			Arguments = {},
			Permissions = { "Manage_Map" },
			Roles = {},

			Description = "Resets lighting environment",
			PlayerCooldown = 2,

			Function = function(plr, args)
				service.Lighting.ClockTime = variables.savedEnvironment.gameTime
				service.Lighting.Brightness = variables.savedEnvironment.brightness
				service.Lighting.OutdoorAmbient = variables.savedEnvironment.outdoorAmbient
				service.Lighting.Ambient = variables.savedEnvironment.ambient

				for i, child in pairs(service.Lighting:GetDescendants()) do
					service.Delete(child)
				end

				local lightingObjects = variables.lightingObjects
				for i, object in pairs(lightingObjects) do
					object:Clone().Parent = service.Lighting
				end
			end,
		},

		btools = {
			Prefix = settings.actionPrefix,
			Aliases = { "btools", "buildingtools", "f3x" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Map" },
			Roles = {},

			Description = "Inserts F3x Building Tools to specified players",

			Function = function(plr, args)
				local btools = server.Assets.BTools:Clone()

				plr:sendData(
					"SendMessage",
					"<b>Disclaimer</b: You are using an unofficial build of Building Tools, created by trzistan."
						.. " In the open-source version, this tool will be replaced with the original building tools from GigsD4X.",
					nil,
					5,
					"Context"
				)

				for i, target in args[1] do
					local backpack = target:FindFirstChildOfClass "Backpack"

					if backpack then
						local clone = btools:Clone()

						clone.Name = "Building Tools"
						clone.Parent = backpack
					end
				end
			end,
		},

		unlockMap = {
			Prefix = settings.actionPrefix,
			Aliases = { "unlockmap" },
			Arguments = {},
			Permissions = { "Manage_Map" },
			Roles = {},

			Description = "Unlocks map/workspace descendants",

			Function = function(plr, args)
				for i, desc in pairs(workspace:GetDescendants()) do
					if desc:IsA "BasePart" then desc.Locked = false end
				end
			end,
		},

		lockMap = {
			Prefix = settings.actionPrefix,
			Aliases = { "lockmap" },
			Arguments = {},
			Permissions = { "Manage_Map" },
			Roles = {},

			Description = "Locks map/workspace descendants",

			Function = function(plr, args)
				for i, desc in pairs(workspace:GetDescendants()) do
					if desc:IsA "BasePart" then desc.Locked = true end
				end
			end,
		},

		restoreMap = {
			Prefix = settings.actionPrefix,
			Aliases = { "restoremap" },
			Arguments = {
				{
					argument = "mapName",
					filter = true,
					requireSafeString = true,
				},
			},
			Permissions = { "Manage_Map" },
			Roles = {},
			PlayerCooldown = 5,

			Description = "Restore the latest backup",

			Function = function(plr, args)
				local backups = (variables.mapBackups.backups or {})
				local latest = (function()
					for i, backup in pairs(backups) do
						if (args[1] and backup.name == args[1]) or (not args[1] and i == #backups) then
							return backup
						end
					end
				end)()

				if latest then
					plr:sendData("SendMessage", "Map Management", "Restoring map. Please hold on..", 6, "Hint")
					local didLoad = Utility:loadMapBackup(args[1] or nil, not args[1] and #backups or nil)

					if didLoad then
						plr:sendData("SendMessage", "Map Management", "Successfully restored the map.", 6, "Hint")
					else
						plr:sendData(
							"SendMessage",
							"Map Management",
							"There was no map backups available to load. Please try again later!",
							6,
							"Hint"
						)
					end
				else
					plr:sendData(
						"SendMessage",
						"Map Management",
						"Unable to restore map without a latest/specified backup. Backup the map before performing a map restore.",
						6,
						"Hint"
					)
				end
			end,
		},

		backupMap = {
			Prefix = settings.actionPrefix,
			Aliases = { "backupmap", "savemap" },
			Arguments = {
				{
					argument = "saveCharacters",
					type = "trueOrFalse",
				},
				{
					argument = "backupName",
					filter = true,
					requireSafeString = true,
				},
			},
			Permissions = { "Manage_Map" },
			Roles = {},
			PlayerCooldown = 5,

			Description = "Backups the map",

			Function = function(plr, args)
				if args[2] then
					if string.match(args[2], "%p") then
						plr:sendData("SendMessage", "Map Management", "Backup name cannot have punctuations", 4, "Hint")
						return
					end

					if #args[2] > 60 then
						plr:sendData(
							"SendMessage",
							"Map Management",
							"Backup name cannot exceed 60 characters",
							8,
							"Hint"
						)
						return
					end
				end

				local backupData = Utility:makeMapBackup(args[2] or nil, nil, { ignoreChars = not args[1] })

				if backupData then
					backupData.creatorId = plr.UserId
					backupData.creatorFullName = plr.Name .. " #" .. plr.UserId
					plr:sendData(
						"SendMessage",
						"Map Management",
						"Backed up map successfully. You can load this backup <b>" .. backupData.name .. "</b>.",
						12,
						"Hint"
					)
				end
			end,
		},

		loadFirstBackup = {
			Prefix = settings.actionPrefix,
			Aliases = { "loadinitialbackup" },
			Arguments = {},
			Permissions = { "Manage_Map" },
			Roles = {},
			PlayerCooldown = 5,

			Description = "Loads the initial map backup",

			Function = function(plr, args)
				local backups = (variables.mapBackups.backups or {})
				local backupData = backups[1]

				if backupData then
					plr:sendData("SendMessage", "Map Management", "Loading first map backup..", 6, "Hint")
					local didLoad = Utility:loadMapBackup(nil, 1)

					if didLoad then
						plr:sendData("SendMessage", "Map Management", "Initial backup loaded successfully", 4, "Hint")
					else
						plr:sendData(
							"SendMessage",
							"Map Management",
							"Initial backup couldn't load due to an on going backup/restoration process.",
							6,
							"Hint"
						)
					end
				else
					plr:sendData("SendMessage", "Map Management", "There is no map backup to load.", 4, "Hint")
				end
			end,
		},

		viewMapBackups = {
			Prefix = settings.actionPrefix,
			Aliases = { "mapbackups" },
			Arguments = {},
			Permissions = { "Manage_Map" },
			Roles = {},
			PlayerCooldown = 2,

			Description = "Views map backups",

			Function = function(plr, args)
				local backups = (variables.mapBackups.backups or {})

				if #backups == 0 then
					plr:sendData(
						"SendMessage",
						"Map Management",
						"There are no backups available to be seen. Make sure to backup the map to see one.",
						4,
						"Hint"
					)
				else
					local viewMBSession = plr:getVar "ViewMBSession"
					local viewBEvent
					local loadBEvent

					if not viewMBSession then
						viewMBSession = Remote.newSession()
						viewMBSession.connectedPlayers[plr] = true

						loadBEvent = viewMBSession:makeEvent "LoadBackup"
						loadBEvent.connectedPlayers = viewMBSession.connectedPlayers
						loadBEvent._event:Connect(function(caller, backupName)
							if
								caller == plr
								and Roles:hasPermissionFromMember(plr, { "Manage_Map" })
								and type(backupName) == "string"
							then
								local backup = (function()
									for i, bData in pairs(backups) do
										if bData.name == backupName then return bData end
									end
								end)()

								if backup then
									plr:sendData(
										"SendMessage",
										"Map Management",
										"Loading backup <b>" .. backupName .. "</b>..",
										4,
										"Hint"
									)
									Utility:loadMapBackup(backupName)
									plr:sendData(
										"SendMessage",
										"Map Management",
										"Successfully loaded backup",
										4,
										"Hint"
									)
								end
							end
						end)

						viewBEvent = viewMBSession:makeEvent "ViewBackup"
						viewBEvent.connectedPlayers = viewMBSession.connectedPlayers
						viewBEvent._event:Connect(function(caller, backupName)
							if
								caller == plr
								and Roles:hasPermissionFromMember(plr, { "Manage_Map" })
								and type(backupName) == "string"
							then
								local foundBackup = (function()
									for i, bData in pairs(backups) do
										if bData.name == backupName then return bData end
									end
								end)()

								if foundBackup then
									plr:makeUI("List", {
										Title = `Map Backup {backupName}`,
										MainSize = Vector2.new(500, 200),
										MinimumSize = Vector2.new(350, 200),
										List = {
											{
												type = "Label",
												label = `Created on \{\{t:{foundBackup.createdOs}:lt\}\}`,
												specialMarkdownSupported = true,
											},
											{
												type = "Label",
												label = `Creator: <b>{tostring(
													foundBackup.creatorFullName or "-SYSTEM-"
												)}</b>`,
												richText = true,
												selectable = true,
											},
											{
												type = "Action",
												label = ``,

												options = {
													{
														label = "Load",
														onExecute = `sessionevent://main:{viewMBSession.id}-{loadBEvent.id}||{LuaParser.Encode {
															foundBackup.name,
														}}`,
													},
												},
											},
										},
									})

									--plr:makeUI("ADONIS_WINDOW", {
									--	Name = "MBSESSION";
									--	Title = "MB - "..foundBackup.name;
									--	Size  = {500, 200};
									--	MinSize = {350, 200};
									--	Content = {
									--		{
									--			Class = "TextLabel";
									--			Size = UDim2.new(1, -10, 0, 30);
									--			Position = UDim2.new(0, 5, 0, 30*1);
									--			BackgroundTransparency = 1;
									--			TextXAlignment = "Left";
									--			Text = " Created:";
									--			Children = {
									--				{
									--					Class = "TextBox";
									--					Size = UDim2.new(0, 300, 1, -4);
									--					Position = UDim2.new(1, -302, 0, 2);
									--					BackgroundTransparency = .4;
									--					BackgroundColor3 = Color3.fromRGB(77, 77, 77);
									--					TextColor3 = Color3.fromRGB(222, 222, 222);
									--					Text = Parser:osDate(foundBackup.created);
									--					TextEditable = false;
									--					ClearTextOnFocus = false;
									--				}
									--			};
									--		};
									--		{
									--			Class = "TextLabel";
									--			Size = UDim2.new(1, -10, 0, 30);
									--			Position = UDim2.new(0, 5, 0, 30*2);
									--			BackgroundTransparency = 1;
									--			TextXAlignment = "Left";
									--			Text = " Creator:";
									--			Children = {
									--				{
									--					Class = "TextBox";
									--					Size = UDim2.new(0, 300, 1, -4);
									--					Position = UDim2.new(1, -302, 0, 2);
									--					BackgroundTransparency = .4;
									--					BackgroundColor3 = Color3.fromRGB(77, 77, 77);
									--					TextColor3 = Color3.fromRGB(222, 222, 222);
									--					Text = tostring(foundBackup.creatorFullName or "-SYSTEM-");
									--					TextEditable = false;
									--					ClearTextOnFocus = false;
									--				}
									--			};
									--		};
									--		{
									--			Class = "TextButton";
									--			Size = UDim2.new(1, -10, 0, 30);
									--			Position = UDim2.new(0, 5, 0, 30*3);
									--			BackgroundTransparency = .4;
									--			BackgroundColor3 = Color3.fromRGB(77, 77, 77);
									--			TextColor3 = Color3.fromRGB(222, 222, 222);
									--			TextXAlignment = "Center";
									--			Text = "Load backup";
									--			OnClick = Core.bytecode([[
									--					client.Network:fire("ManageSession", "]]..viewMBSession.id..[[", "FireEvent", "]]..loadBEvent.id..[[", "]]..foundBackup.name..[[")
									--				]]);
									--		};
									--	};
									--	Ready = true;
									--})
								end
							end
						end)

						plr:setVar("ViewMBSession", viewMBSession)
					else
						viewBEvent = viewMBSession:findEvent "ViewBackup"
						loadBEvent = viewMBSession:findEvent "LoadBackup"
					end

					local tabList = {}

					for i, backup in pairs(backups) do
						table.insert(tabList, {
							type = "Action",
							optionsLayoutStyle = "Log",
							label = `[\{\{t:{backup.createdOs}\:lt}\}] {backup.name}`,
							selectable = true,
							specialMarkdownSupported = true,

							options = {
								{
									label = "View",
									backgroundColor = Color3.fromRGB(111, 111, 111),
									onExecute = `sessionevent://main:{viewMBSession.id}-{viewBEvent.id}||{LuaParser.Encode {
										backup.name,
									}}`,
								},
								{
									label = "Load",
									backgroundColor = Color3.fromRGB(36, 168, 34),
									onExecute = `sessionevent://main:{viewMBSession.id}-{loadBEvent.id}||{LuaParser.Encode {
										backup.name,
									}}`,
								},
							},
						})
					end

					plr:makeUI("List", {
						Title = "Map Backups",
						MainSize = Vector2.new(500, 400),
						MinimumSize = Vector2.new(350, 210),
						List = tabList,
					})
				end
			end,
		},

		purgeMap = {
			Prefix = settings.actionPrefix,
			Aliases = { "purgemap", "cleanmap" },
			Arguments = {
				{
					argument = "removeParticles",
					type = "trueOrFalse",
				},
				{
					argument = "removeSound",
					type = "trueOrFalse",
				},
				{
					argument = "removeNPCs",
					type = "trueOrFalse",
				},
			},
			Permissions = { "Manage_Map" },
			Roles = {},
			ServerCooldown = 5,

			Description = "Cleans the workspace/map",

			Function = function(plr, args)
				service.debounce("Map cleanup", function()
					for i, desc in pairs(workspace:GetChildren()) do
						if desc:IsA "Tool" then service.Debris:AddItem(desc, 0) end
					end

					if args[1] then
						for i, desc in pairs(workspace:GetDescendants()) do
							if desc:IsA "ParticleEmitter" then service.Debris:AddItem(desc, 0) end
						end
					end

					if args[2] then
						for i, desc in pairs(workspace:GetDescendants()) do
							if desc:IsA "Sound" then service.Debris:AddItem(desc, 0) end
						end
					end

					if args[3] then
						for i, desc in pairs(workspace:GetDescendants()) do
							if desc:IsA "Model" then
								local humanoid = desc:FindFirstChildOfClass "Humanoid"

								if humanoid then
									local playerFromChar = service.Players:GetPlayerFromCharacter(desc)

									if not playerFromChar then
										desc:BreakJoints()
										service.Debris:AddItem(desc, 0)
									end
								end
							end
						end
					end

					wait(1)
				end)
			end,
		},

		disco = {
			Prefix = settings.actionPrefix,
			Aliases = { "disco" },
			Arguments = {},
			Permissions = { "Manage_Map" },
			Roles = {},
			PlayerCooldown = 0.8,

			Description = "Plays disco in the server",

			Function = function(plr, args)
				service.stopLoop "DiscoMap"

				local colorC = variables.lightingObjects["Disco"]
				if not colorC or colorC.Parent ~= service.Lighting then
					if colorC then service.Delete(colorC) end

					colorC = service.New("ColorCorrectionEffect", {
						Name = "Disco-" .. service.getRandom(),
						Parent = service.Lighting,
					})

					variables.lightingObjects["Disco"] = colorC
				end

				local tweenTime = 0.6
				service.startLoop("DiscoMap", 0.1, function()
					if colorC.Parent == service.Lighting then
						local tween =
							service.TweenService:Create(colorC, TweenInfo.new(tweenTime, Enum.EasingStyle.Quint), {
								--Brightness = math.random(0, 100)/100;
								--Contrast = math.random(0, 100)/100;
								TintColor = BrickColor.Random().Color,
							})

						colorC.Enabled = true
						tween:Play()
						wait(tweenTime)
					end
				end)
			end,
		},

		unDisco = {
			Prefix = settings.actionPrefix,
			Aliases = { "undisco" },
			Arguments = {},
			Permissions = { "Manage_Map" },
			Roles = {},
			PlayerCooldown = 0.8,

			Description = "Stops disco in the server",

			Function = function(plr, args)
				service.stopLoop "DiscoMap"

				local colorC = variables.lightingObjects["Disco"]
				if colorC then
					service.Delete(colorC)
					variables.lightingObjects["Disco"] = nil
				end
			end,
		},
	}

	for cmdName, cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
