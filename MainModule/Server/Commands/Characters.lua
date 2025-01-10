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
	local Parser = server.Parser

	local cmdsList = {
		setDisplayName = {
			--Disabled = settings.Anti_DisplayNameMatch;
			Prefix = settings.actionPrefix,
			Aliases = { "setnick", "setdisplayname" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "nickname",
					required = true,
					filter = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Changes display name to specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then humanoid.DisplayName = args[2] end
					end
				end
			end,
		},

		addTitle = {
			Prefix = settings.actionPrefix,
			Aliases = { "title" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "title",
					required = true,
					filter = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Adds/changes specified player characters' title to specified name",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local mainPart = char:FindFirstChild "Head"

						if mainPart and mainPart:IsA "BasePart" then
							if mainPart:FindFirstChild "TITLE" then
								service.Debris:AddItem(mainPart:FindFirstChild "TITLE", 0)
							end

							local Rank_1 = service.New "BillboardGui"
							local Frame = service.New "Frame"
							local Rank_2 = service.New "TextLabel"
							local Rank_3 = service.New "TextLabel"
							local CompactUser = service.New "TextLabel"

							Rank_1.Name = "TITLE"
							Rank_1.Enabled = true
							Rank_1.Size = UDim2.new(6, 0, 4, 0)
							Rank_1.SizeOffset = Vector2.new(0, 1)

							Frame.Parent = Rank_1
							Frame.AnchorPoint = Vector2.new(0.5, 1)
							Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
							Frame.BackgroundTransparency = 1
							Frame.BorderSizePixel = 0
							Frame.Position = UDim2.new(0.5, 0, 1, 0)
							Frame.Size = UDim2.new(1, 0, 1, 0)

							Rank_2.Name = "Label"
							Rank_2.Parent = Frame
							Rank_2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
							Rank_2.BackgroundTransparency = 1
							Rank_2.Size = UDim2.new(1, 0, 0.5, 0)
							Rank_2.Font = Enum.Font.SourceSansBold
							Rank_2.Text = args[2]
							Rank_2.TextColor3 = Color3.fromRGB(255, 255, 255)
							Rank_2.TextScaled = true
							Rank_2.TextSize = 14
							Rank_2.TextStrokeTransparency = 0.9
							Rank_2.TextWrapped = true
							Rank_2.Visible = true

							--Rank_2.Name = "Rank"
							--Rank_2.Parent = Frame
							--Rank_2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
							--Rank_2.BackgroundTransparency = 1
							--Rank_2.Position = UDim2.new(0, 0, 0.5, 0)
							--Rank_2.Size = UDim2.new(1, 0, 0.3, 0)
							--Rank_2.Visible = false
							--Rank_2.Font = Enum.Font.SourceSansBold
							--Rank_2.Text = ""
							--Rank_2.TextColor3 = Color3.fromRGB(255, 255, 255)
							--Rank_2.TextScaled = true
							--Rank_2.TextSize = 14
							--Rank_2.TextStrokeTransparency = 0.900
							--Rank_2.TextWrapped = true

							--CompactUser.Name = "CompactUser"
							--CompactUser.Parent = Frame
							--CompactUser.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
							--CompactUser.BackgroundTransparency = 1
							--CompactUser.Position = UDim2.new(0, 0, 0.5, 0)
							--CompactUser.Size = UDim2.new(1, 0, 0.3, 0)
							--CompactUser.Visible = false
							--CompactUser.Font = Enum.Font.SourceSansBold
							--CompactUser.Text = args[2]
							--CompactUser.TextColor3 = Color3.fromRGB(255, 255, 255)
							--CompactUser.TextScaled = true
							--CompactUser.TextSize = 14.000
							--CompactUser.TextStrokeTransparency = 0.900
							--CompactUser.TextWrapped = true

							Rank_1.Parent = mainPart
						end
					end
				end
			end,
		},

		unTitle = {
			Prefix = settings.actionPrefix,
			Aliases = { "untitle" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Removes specified player characters'",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local mainPart = char:FindFirstChild "Head"

						if mainPart and mainPart:IsA "BasePart" then
							if mainPart:FindFirstChild "TITLE" then
								service.Debris:AddItem(mainPart:FindFirstChild "TITLE", 0)
							end
						end
					end
				end
			end,
		},

		jailPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "jail" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Inserts specified player characters' jail",
			PlayerCooldown = 2,

			Function = function(player, args)
				--for i,p in pairs(args[1]) do
				--	if not variables.jailedPlayers[tostring(p.UserId)] then
				--		local exilebox = server.Assets.ExileBox:Clone()
				--		local hrp = p.Character and (p.Character:FindFirstChild"HumanoidRootPart" or p.Character:FindFirstChild"Torso")

				--		local backpack = p:FindFirstChildOfClass"Backpack"

				--		local ind = tostring(p.UserId)
				--		local jinfo = {
				--			Player = p;
				--			Ind = ind;
				--			Start = tick();
				--			ExileBox = exilebox;
				--			Inventory = {};
				--		}

				--		if backpack then
				--			for i,v in next, backpack:children() do
				--				table.insert(jinfo.Inventory, v)
				--				v.Parent = nil
				--			end
				--		end

				--		if not hrp then
				--			p:LoadCharacter()
				--			p.CharacterAdded:Wait()
				--			hrp = p.Character and (p.Character:FindFirstChild"HumanoidRootPart" or p.Character:FindFirstChild"Torso")
				--		end

				--		if hrp then
				--			variables.jailedPlayers[ind] = jinfo
				--			p:sendData("SetCoreGuiEnabled", Enum.CoreGuiType.Backpack, false)

				--			local cf = hrp.CFrame
				--			local pos = cf.Position
				--			local oldchar = p.Character

				--			exilebox.CFrame = cf
				--			exilebox.Locked = true

				--			exilebox.Parent = workspace

				--			task.spawn(function()
				--				while wait() and p.Parent == service.Players and variables.jailedPlayers[ind] == jinfo do
				--					local curhrp = p.Character and (p.Character:FindFirstChild"HumanoidRootPart" or p.Character:FindFirstChild"Torso")
				--					local char = p.Character

				--					if curhrp then
				--						if curhrp ~= hrp then
				--							local hrpCheck1 = p.Character and (p.Character:FindFirstChild"HumanoidRootPart" or p.Character:FindFirstChild"Torso")
				--							wait(.5)
				--							local hrpCheck2 = p.Character and (p.Character:FindFirstChild"HumanoidRootPart" or p.Character:FindFirstChild"Torso")
				--							if (hrpCheck1 and hrpCheck2) and hrpCheck1 == hrpCheck2 then
				--								hrp = hrpCheck1
				--							else
				--								continue
				--							end
				--						end
				--						if (curhrp.Position-pos).magnitude > 4 then
				--							curhrp.Position = pos
				--						end
				--					end

				--					if variables.jailedPlayers[ind] ~= jinfo then
				--						exilebox:Destroy()
				--						break
				--					end
				--				end

				--				if not p:isInGame() or variables.jailedPlayers[ind] ~= jinfo then
				--					exilebox:Destroy()
				--				end
				--			end)()
				--		end
				--	end
				--end

				for i, target in pairs(args[1]) do
					task.spawn(function() Utility:jailPlayer(target) end)
				end
			end,
		},

		jailedPlayersList = {
			Prefix = settings.actionPrefix,
			Aliases = { "jails", "playerjails" },
			Arguments = {},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Lists all active player jails",

			Function = function(plr, args)
				local jailList = {}

				for userId, jailInfo in pairs(variables.jailedPlayers) do
					if jailInfo.active then
						local targetName = service.playerNameFromId(jailInfo.suspectId)

						table.insert(jailList, {
							type = "Detailed",
							label = targetName .. " | " .. Parser:osDate(jailInfo.started) .. " UTC",
							description = "Duration: "
								.. Parser:formatTime(tick() - jailInfo.started)
								.. " | Items: "
								.. tostring(#jailInfo.items),
						})
					end
				end

				plr:makeUI("List", {
					Title = "E. Jailed Players",
					List = jailList,
				})
			end,
		},

		unJailPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "unjail" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Removes specified player characters' jail",

			Function = function(player, args)
				for i, target in pairs(args[1]) do
					Utility:unJailPlayer(target)
				end
			end,
		},

		removeJails = {
			Prefix = settings.actionPrefix,
			Aliases = { "removejails" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Removes specified players' jail or everyone's jails",

			Function = function(player, args)
				local jailCount = 0
				for userId, jailInfo in pairs(variables.jailedPlayers) do
					if not args[1] or (args[1] and args[1]("getPlayer", jailInfo.suspectId)) then
						local targetId = jailInfo.suspectId
						local targetName = service.playerNameFromId(targetId)
						local target = Parser:getParsedPlayer(targetId)
							or Parser:apifyPlayer({
								Name = targetName,
								UserId = targetId,
							}, true)

						Utility:unJailPlayer(target)
						jailCount += 1
					end
				end

				if jailCount > 0 then
					player:sendData(
						"SendMessage",
						"Jail Management",
						"Removed " .. tostring(jailCount) .. " jail(s).",
						8,
						"Hint"
					)
				end
			end,
		},

		walkSpeed = {
			Prefix = settings.actionPrefix,
			Aliases = { "wspeed", "walkspeed" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "walkSpeed",
					type = "number",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Changes specified player characters' walk speed",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then humanoid.WalkSpeed = math.clamp(args[2], 0, math.huge) end
					end
				end
			end,
		},

		jumpPower = {
			Prefix = settings.actionPrefix,
			Aliases = { "jpower", "jumppower" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "jumpPower",
					type = "number",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Changes specified player characters' jump power",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then humanoid.JumpPower = math.clamp(args[2], 0, math.huge) end
					end
				end
			end,
		},

		damageHealth = {
			Prefix = settings.actionPrefix,
			Aliases = { "damage" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "healthLoss",
					type = "number",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Damages specified player characters (not effective with forcefield)",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then humanoid:TakeDamage(args[2]) end
					end
				end
			end,
		},

		setCurrentHealth = {
			Prefix = settings.actionPrefix,
			Aliases = { "setcurrenthealth" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "newHealth",
					type = "number",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Sets specified player characters' current health to specified health",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then humanoid.Health = math.clamp(args[2], 0, math.huge) end
					end
				end
			end,
		},

		setMaxHealth = {
			Prefix = settings.actionPrefix,
			Aliases = { "setmaxhealth" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "maxHealth",
					type = "number",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Sets specified player characters' max health to specified max health",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then humanoid.MaxHealth = math.clamp(args[2], 0, math.huge) end
					end
				end
			end,
		},

		godHealth = {
			Prefix = settings.actionPrefix,
			Aliases = { "invulnerable" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Makes specified player characters' invulnerable to damages",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then
							humanoid.Health = math.huge
							humanoid.MaxHealth = math.huge
						end

						for d, charPart in pairs(char:GetChildren()) do
							if charPart:IsA "ForceField" then service.Debris:AddItem(charPart, 0.5) end
						end

						service.New("ForceField", {
							Name = "_ESS_INVULNERABLEFF",
							Visible = false,
							Parent = char,
						})
					end
				end
			end,
		},

		vulnerableChar = {
			Prefix = settings.actionPrefix,
			Aliases = { "vulnerable" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Makes specified player characters vulnerable",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then
							humanoid.Health = 100
							humanoid.MaxHealth = 100
						end

						for d, charPart in pairs(char:GetChildren()) do
							if charPart:IsA "ForceField" then service.Debris:AddItem(charPart, 0.5) end
						end
					end
				end
			end,
		},

		heal = {
			Prefix = settings.actionPrefix,
			Aliases = { "heal" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Maxes player characters' health",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then humanoid.Health = humanoid.MaxHealth end
					end
				end
			end,
		},

		killPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "kill" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},
			ServerCooldown = 2,

			Description = "Kills specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local character = target.Character

					if character then character:BreakJoints() end
				end
			end,
		},

		jumpPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "jump" },
			Arguments = { "players" },
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Forces player characters' to jump",

			Function = function(plr, args)
				for i, target in pairs(server.Parser:getPlayers(args[1], plr)) do
					local humanoid = (target.Character and target.Character:FindFirstChildOfClass "Humanoid")

					if humanoid then humanoid.Jump = true end
				end
			end,
		},

		sitPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "sit" },
			Arguments = { "players" },
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Forces player characters' to sit",

			Function = function(plr, args)
				for i, target in pairs(server.Parser:getPlayers(args[1], plr)) do
					local humanoid = (target.Character and target.Character:FindFirstChildOfClass "Humanoid")

					if humanoid and not humanoid.Sit then humanoid.Sit = true end
				end
			end,
		},

		respawnPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "re", "respawn", "reload", "res" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,
				},
				{
					type = "trueOrFalse",
					argument = "saveItems",
					required = false,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Respawns specified players",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					target:respawn(false, args[2])
				end
			end,
		},

		refreshPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "ref", "refresh" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Refreshes specified players",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					target:refresh(true)
				end
			end,
		},

		removeTools = {
			Prefix = settings.actionPrefix,
			Aliases = { "removetools", "cleartools", "clearbackpack", "notools" },
			Arguments = { "players" },
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Deletes specified players' current tool and existing backpack items",

			Function = function(plr, args)
				for i, target in pairs(server.Parser:getPlayers(args[1], plr)) do
					local backpack = target:FindFirstChildOfClass "Backpack"

					if backpack then
						for _, item in pairs(backpack:GetChildren()) do
							service.Debris:AddItem(item, 0)
						end
					end

					local char = target.Character

					if char then
						for _, item in pairs(char:GetChildren()) do
							if item:IsA "Tool" then service.Debris:AddItem(item, 0) end
						end
					end
				end
			end,
		},

		explode = {
			Prefix = settings.actionPrefix,
			Aliases = { "explode", "boom" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
				{
					argument = "blastPressure",
					type = "integer",
				},
				{
					argument = "blastRadius",
					type = "integer",
				},
				{
					argument = "craters",
					type = "trueOrFalse",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Inserts an explosion with modified arguments provided to specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local torso = char:FindFirstChild "HumanoidRootPart"
							or char:FindFirstChild "Torso"
							or char:FindFirstChild "UpperTorso"

						if torso then
							local expl = service.New "Explosion"
							expl.Position = torso.Position

							if args[2] then expl.BlastPressure = math.abs(args[2]) end

							if args[3] then expl.BlastRadius = math.abs(args[3]) end

							expl.ExplosionType = (args[4] and Enum.ExplosionType.Craters)
								or Enum.ExplosionType.NoCraters
							expl.Parent = torso
						end
					end
				end
			end,
		},

		forceField = {
			Prefix = settings.actionPrefix,
			Aliases = { "ff", "forcefield", "shield" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
				{
					argument = "hidden",
					type = "trueOrFalse",
				},
				{
					argument = "duration",
					type = "duration",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Inserts a forcefield with modified arguments provided to specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						for i, obj in pairs(char:GetChildren()) do
							if obj:IsA "ForceField" then service.Debris:AddItem(obj, 0) end
						end

						local ff = service.New "ForceField"
						ff.Name = "_ESS_FORCEFIELD"

						if args[2] then ff.Visible = false end

						if args[3] then service.Debris:AddItem(ff, args[3].total) end

						ff.Parent = char
					end
				end
			end,
		},

		unForceField = {
			Prefix = settings.actionPrefix,
			Aliases = { "unff", "unforcefield", "noshield", "unshield" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Removes forcefield from specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						for i, obj in pairs(char:GetChildren()) do
							if obj:IsA "ForceField" then service.Debris:AddItem(obj, 0) end
						end
					end
				end
			end,
		},

		teleport = {
			Prefix = settings.actionPrefix,
			Aliases = { "tp", "teleport" },
			Arguments = {
				{
					argument = "senders",
					type = "players",
					required = true,
				},
				{
					argument = "toPlayer",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Teleports senders to toPlayer",

			Function = function(plr, args)
				local fromPlayer = (args[2] or {})[1]

				if not fromPlayer or not fromPlayer.Character then
					if plr then
						plr:sendData(
							"SendMessage",
							"Teleportation Error",
							"Teleporting to the player doesn't exist or has no character",
							3,
							"Hint"
						)
					end

					return
				end

				local mainHrp = fromPlayer.Character:FindFirstChild "HumanoidRootPart"

				if not mainHrp or not mainHrp:IsA "BasePart" then
					if plr then
						plr:sendData(
							"SendMessage",
							"Teleportation Error",
							"Teleporting to the player doesn't have HumanoidRootPart",
							3,
							"Hint"
						)
					end

					return
				end

				local function resetHumanoidState(char)
					local humanoid = char:FindFirstChildOfClass "Humanoid"
					local charHrp = char:FindFirstChild "HumanoidRootPart"

					if humanoid then
						if humanoid.SeatPart then
							for i, weld in pairs(humanoid.SeatPart:GetChildren()) do
								if weld:IsA "Weld" and weld.Part1 and weld.Part1 == charHrp then
									weld.Part1 = nil
									weld.Part0 = nil
									service.Debris:AddItem(weld, 2)
								end
							end
						end

						if humanoid.Sit then humanoid.Sit = false end
					end
				end

				for i, sender in pairs(args[1]) do
					local char = sender.Character

					if char then
						local hrp = char:FindFirstChild "HumanoidRootPart"

						if hrp then
							resetHumanoidState(char)
							hrp.CFrame = mainHrp.CFrame
						end
					end
				end
			end,
		},

		bringPlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "bring", "pull" },
			Arguments = {
				{
					argument = "senders",
					type = "players",
					required = true,
				},
				{
					argument = "faceFront",
					type = "trueOrFalse",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Teleports senders to you",

			Function = function(plr, args)
				local mainHrp = plr.Character and plr.Character:FindFirstChild "HumanoidRootPart"

				if not mainHrp or not mainHrp:IsA "BasePart" then return end

				local function resetHumanoidState(char)
					local humanoid = char:FindFirstChildOfClass "Humanoid"
					local charHrp = char:FindFirstChild "HumanoidRootPart"

					if humanoid then
						if humanoid.SeatPart then
							for i, weld in pairs(humanoid.SeatPart:GetChildren()) do
								if weld:IsA "Weld" and weld.Part1 and weld.Part1 == charHrp then
									weld.Part1 = nil
									weld.Part0 = nil
									service.Debris:AddItem(weld, 2)
								end
							end
						end

						if humanoid.Sit then humanoid.Sit = false end
					end
				end

				local mainCF = (mainHrp.CFrame + (mainHrp.CFrame.LookVector * 2))

				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local hrp = char:FindFirstChild "HumanoidRootPart"

						if hrp and hrp:IsA "BasePart" then
							resetHumanoidState(char)
							hrp.CFrame = (args[2] and mainCF * CFrame.Angles(0, math.rad(180), 0)) or mainCF
						end
					end
				end
			end,
		},

		toPlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "to", "goto" },
			Arguments = {
				{
					argument = "senders",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Teleports you to the player",

			Function = function(plr, args)
				local mainHrp = plr.Character and plr.Character:FindFirstChild "HumanoidRootPart"

				if not mainHrp or not mainHrp:IsA "BasePart" then return end

				local function resetHumanoidState(char)
					local humanoid = char:FindFirstChildOfClass "Humanoid"
					local charHrp = char:FindFirstChild "HumanoidRootPart"

					if humanoid then
						if humanoid.SeatPart then
							for i, weld in pairs(humanoid.SeatPart:GetChildren()) do
								if weld:IsA "Weld" and weld.Part1 and weld.Part1 == charHrp then
									weld.Part1 = nil
									weld.Part0 = nil
									service.Debris:AddItem(weld, 2)
								end
							end
						end

						if humanoid.Sit then humanoid.Sit = false end
					end
				end

				local target = args[1][1]

				if target then
					local targetHrp = target.Character and target.Character:FindFirstChild "HumanoidRootPart"

					if targetHrp and targetHrp:IsA "BasePart" then
						resetHumanoidState(target.Character)
						mainHrp.CFrame = (targetHrp.CFrame + (targetHrp.CFrame.LookVector * 2))
							* CFrame.Angles(0, math.rad(180), 0)
					end
				end
			end,
		},

		characterize = {
			Prefix = settings.actionPrefix,
			Aliases = { "char", "morph" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "morphUsername",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Morphs specified player characters' to a different player",

			Function = function(plr, args)
				local morphUserId = service.playerIdFromName(args[2] or plr.Name) or 0
				local success, desc =
					pcall(service.Players.GetHumanoidDescriptionFromUserId, service.Players, morphUserId)

				if not success then
					if plr then
						plr:sendData(
							"SendMessage",
							"Characterization failure",
							"Unable to get morph data for " .. morphUserId .. "'s character"
						)
					end
					return
				end

				for i, target in pairs(args[1]) do
					target.CharacterAppearanceId = morphUserId

					local humanoid = target.Character and target.Character:FindFirstChildOfClass "Humanoid"

					if humanoid then humanoid:ApplyDescription(desc:Clone()) end
				end
			end,
		},

		unCharacterize = {
			Prefix = settings.actionPrefix,
			Aliases = { "unchar" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Morphs specified player characters' back to their original",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local morphUserId = service.playerIdFromName(target.Name) or 0
					local success, desc =
						pcall(service.Players.GetHumanoidDescriptionFromUserId, service.Players, morphUserId)

					if not success then continue end

					target.CharacterAppearanceId = morphUserId

					local humanoid = target.Character and target.Character:FindFirstChildOfClass "Humanoid"

					if humanoid then humanoid:ApplyDescription(desc:Clone()) end
				end
			end,
		},

		shirt = {
			Prefix = settings.actionPrefix,
			Aliases = { "shirt", "changeshirt" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "id",
					type = "integer",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Modifies specified player characters' shirt to a supplied one",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then
							local descrip = humanoid:GetAppliedDescription()

							if descrip then
								descrip.Shirt = args[2]
								humanoid:ApplyDescription(descrip)
							end
						end
					end
				end
			end,
		},

		pants = {
			Prefix = settings.actionPrefix,
			Aliases = { "pants", "changepants" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "id",
					type = "integer",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Modifies specified player characters' pants to a supplied one",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then
							local descrip = humanoid:GetAppliedDescription()

							if descrip then
								descrip.Pants = args[2]
								humanoid:ApplyDescription(descrip)
							end
						end
					end
				end
			end,
		},

		face = {
			Prefix = settings.actionPrefix,
			Aliases = { "face", "changeface" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "id",
					type = "integer",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Modifies specified player characters' face to a supplied one",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then
							local descrip = humanoid:GetAppliedDescription()

							if descrip then
								descrip.Face = args[2]
								humanoid:ApplyDescription(descrip)
							end
						end
					end
				end
			end,
		},

		invisiblePlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "invisible", "hidechar" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Hides specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						for d, desc in pairs(char:GetDescendants()) do
							if desc:IsA "Decal" or desc:IsA "Texture" or
								(desc:IsA "BasePart" and not (desc.Name == "HumanoidRootPart"))
							then
								desc.Transparency = 1
							end
						end
					end
				end
			end,
		},

		visiblePlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "visible", "showchar" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Unhides specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						for d, desc in pairs(char:GetDescendants()) do
							if desc:IsA "Decal" or desc:IsA "Texture" or
								(desc:IsA "BasePart" and not (desc.Name == "HumanoidRootPart"))
							then
								desc.Transparency = 0
							end
						end
					end
				end
			end,
		},

		deleteCharacter = {
			Prefix = settings.actionPrefix,
			Aliases = { "deletechar" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Deletes specified player characters",
			PlayerCooldown = 5,

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then service.Delete(char) end
				end
			end,
		},

		particleCharacters = {
			Prefix = settings.actionPrefix,
			Aliases = { "particles" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "lightEmission",
					type = "number",
				},
				{
					argument = "lightInfluence",
					type = "number",
				},
				{
					argument = "color",
					type = "color",
				},
				{
					argument = "texture",
					type = "number",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Inserts specified player characters ParticleEmitters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local torso = char:FindFirstChild "HumanoidRootPart" or char:FindFirstChild "Torso"

						if torso then
							if torso:FindFirstChildOfClass "ParticleEmitter" then
								service.Delete(torso:FindFirstChildOfClass "ParticleEmitter")
							end

							local particleEmitter = service.New("ParticleEmitter", {
								Parent = torso,
							})

							particleEmitter.LightEmission = args[2] or 1

							particleEmitter.LightInfluence = args[3] or 1

							if tonumber(args[5]) then
								local assetId = tonumber(args[5])
								local assetInfo = service.getProductInfo(assetId)

								if assetInfo and assetInfo.AssetTypeId == 13 then
									local didFetch, assetContents = service.insertAsset(assetId)
									if didFetch then particleEmitter.Texture = assetContents[1].Texture end
								end
							else
								particleEmitter.Texture = args[5] or "rbxasset://textures/particles/sparkles_main.dds"
							end

							particleEmitter.Color = ColorSequence.new {
								ColorSequenceKeypoint.new(0, args[4] or Color3.fromRGB(255, 255, 255)),
								ColorSequenceKeypoint.new(1, args[4] or Color3.fromRGB(255, 255, 255)),
							}
						end
					end
				end
			end,
		},

		unParticleCharacters = {
			Prefix = settings.actionPrefix,
			Aliases = { "unparticles" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Removes specified player characters ParticleEmitters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local torso = char:FindFirstChild "HumanoidRootPart" or char:FindFirstChild "Torso"

						if torso then
							if torso:FindFirstChildOfClass "ParticleEmitter" then
								service.Delete(torso:FindFirstChildOfClass "ParticleEmitter")
							end
						end
					end
				end
			end,
		},

		-- DEBUG COMMANDS
		debugOutlineCharacter = {
			Disabled = not settings.debugCommands,
			Prefix = settings.actionPrefix,
			Aliases = { "debugOutline" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "[USED FOR DEBUGGING] Outlines specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local charColor = Color3.fromRGB(38, 125, 255)
						local outlineColor = Color3.fromRGB(245, 255, 51)
						local motorPartColor = Color3.fromRGB(255, 135, 79)

						if char:FindFirstChild "_DEBUG_OUTLINE" then char._DEBUG_OUTLINE:Destroy() end

						local mainOutline = service.New "SelectionBox"
						mainOutline.Name = "_DEBUG_OUTLINE"
						mainOutline.LineThickness = 0.01
						mainOutline.Color3 = charColor
						mainOutline.Adornee = char
						mainOutline.Parent = char

						for d, part in pairs(char:GetDescendants()) do
							if part:IsA "BasePart" then
								-- Ignore tool parts
								if part:FindFirstAncestorOfClass "Tool" then continue end

								if part:FindFirstChild "_DEBUG_OUTLINE" then part._DEBUG_OUTLINE:Destroy() end

								local partOutline = service.New "SelectionBox"
								partOutline.Name = "_DEBUG_OUTLINE"
								partOutline.LineThickness = 0.01
								partOutline.Color3 = (part:FindFirstChildOfClass "Motor6D" and motorPartColor)
									or outlineColor
								partOutline.Adornee = part
								partOutline.Parent = part
							end
						end
					end
				end
			end,
		},

		unDebugOutlineCharacter = {
			Disabled = not settings.debugCommands,
			Prefix = settings.actionPrefix,
			Aliases = { "undebugOutline" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "[USED FOR DEBUGGING] Removes outlines from specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local charColor = Color3.fromRGB(38, 125, 255)
						local outlineColor = Color3.fromRGB(245, 255, 51)
						local motorPartColor = Color3.fromRGB(255, 135, 79)

						if char:FindFirstChild "_DEBUG_OUTLINE" then char._DEBUG_OUTLINE:Destroy() end

						for d, part in pairs(char:GetDescendants()) do
							if part:IsA "BasePart" then
								-- Ignore tool parts
								if part:FindFirstAncestorOfClass "Tool" then continue end

								if part:FindFirstChild "_DEBUG_OUTLINE" then part._DEBUG_OUTLINE:Destroy() end
							end
						end
					end
				end
			end,
		},

		freezePlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "freeze", "anchor" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Freezes specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						for d, charPart in pairs(char:GetDescendants()) do
							if charPart:IsA "BasePart" and not charPart:FindFirstAncestorOfClass "Tool" then
								charPart.Anchored = true
							end
						end
					end
				end
			end,
		},

		unFreezePlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "unfreeze", "unanchor" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "UnFreezes specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						for d, charPart in pairs(char:GetDescendants()) do
							if charPart:IsA "BasePart" and not charPart:FindFirstAncestorOfClass "Tool" then
								charPart.Anchored = false
							end
						end
					end
				end
			end,
		},

		addSoundToCharacters = {
			Prefix = settings.actionPrefix,
			Aliases = { "soundChar" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
				{
					type = "number",
					required = true,
				},
				{
					type = "trueOrFalse",
					argument = "looped",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Adds sound to specified player characters",

			Function = function(plr, args)
				local musicId = args[2]
				local assetInfo = service.getProductInfo(musicId) or {}

				if not assetInfo or assetInfo.AssetTypeId ~= 3 then
					plr:sendData(
						"SendMessage",
						"Asset collection error",
						"<b>" .. musicId .. "</b> isn't an audio",
						6,
						"Hint"
					)

					return
				end

				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local charHrp = char:FindFirstChild "HumanoidRootPart" or char:FindFirstChild "Torso"

						if charHrp and charHrp:IsA "BasePart" then
							if charHrp:FindFirstChild "_ESS_SOUND" then
								service.Debris:AddItem(charHrp:FindFirstChild "_ESS_SOUND", 1)
							end

							service
								.New("Sound", {
									Name = "_ESS_SOUND",
									Looped = true,
									SoundId = "rbxassetid://" .. musicId,
									RollOffMinDistance = 10,
									RollOffMaxDistance = 60,
									Parent = charHrp,
								})
								:Play()
						end
					end
				end
			end,
		},

		remSoundToCharacters = {
			Prefix = settings.actionPrefix,
			Aliases = { "removeSoundChar" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Removes sound from specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local charHrp = char:FindFirstChild "HumanoidRootPart" or char:FindFirstChild "Torso"

						if charHrp and charHrp:IsA "BasePart" then
							if charHrp:FindFirstChild "_ESS_SOUND" then
								service.Debris:AddItem(charHrp:FindFirstChild "_ESS_SOUND", 1)
							end
						end
					end
				end
			end,
		},

		removeHats = {
			Prefix = settings.actionPrefix,
			Aliases = { "removeHats" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Removes hats from specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						for d, charPart in pairs(char:GetChildren()) do
							if charPart:IsA "Accoutrement" then service.Debris:AddItem(charPart, 0.5) end
						end
					end
				end
			end,
		},

		clonePlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "clone" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
				{
					argument = "invulnerable",
					type = "trueOrFalse",
				},
				{
					argument = "hideNametag",
					type = "trueOrFalse",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Clones specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local clone = Utility:createClone(char)

						if clone then
							local clHumanoid = clone:FindFirstChildOfClass "Humanoid"

							if clHumanoid then
								clHumanoid.Died:Connect(function() service.Debris:AddItem(clone, 5) end)

								if args[2] then
									clHumanoid.Health = math.huge
									clHumanoid.MaxHealth = math.huge

									service.New("ForceField", {
										Visible = false,
										Parent = clone,
									})
								end

								if args[3] then
									clHumanoid.DisplayName = ""
									clHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
									clHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
								end
							end

							clone.Parent = workspace
							clone:MoveTo(char:GetModelCFrame().p)
						end
					end
				end
			end,
		},

		lockPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "lockchar", "lockplayer" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Locks specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						for d, charPart in pairs(char:children()) do
							if charPart:IsA "BasePart" then charPart.Locked = true end
						end
					end
				end
			end,
		},

		unlockPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "unlockchar", "unlockplayer" },
			Arguments = {
				{
					argument = "players",
					type = "players",
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Unlocks specified player characters",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						for d, charPart in pairs(char:children()) do
							if charPart:IsA "BasePart" then charPart.Locked = false end
						end
					end
				end
			end,
		},

		sizePlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "size" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "multiplier",
					type = "number",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Sizes specified player characters (Size limit: " .. tostring(
				tonumber(settings.sizeLimit) or 10
			) .. ")",

			Function = function(plr, args)
				local sizeLimit = tonumber(settings.sizeLimit) or 10
				local sizedCharacters = variables.sizedCharacters
				local multiplier = args[2]

				local failedPlayers = {}

				for i, target in pairs(args[1]) do
					local char = target.Character

					if char then
						local humanoid = char:FindFirstChildOfClass "Humanoid"

						if humanoid then
							local sizedCharData = sizedCharacters[char]

							if sizedCharData then
								if sizedCharData * multiplier < sizeLimit then
									sizedCharacters[char] = sizedCharData * multiplier
								else
									table.insert(failedPlayers, target.Name)
									continue
								end
							end

							if humanoid.RigType == Enum.HumanoidRigType.R15 then
								for k, val in next, humanoid:GetChildren() do
									if val:IsA "NumberValue" and val.Name:match ".*Scale" then
										val.Value = val.Value * multiplier
									end
								end
							elseif humanoid.RigType == Enum.HumanoidRigType.R6 then
								local Motors = {}
								local Percent = multiplier

								local humanoidRootPart = char:FindFirstChild "HumanoidRootPart"
								local rootJoint = humanoidRootPart and humanoidRootPart:FindFirstChild "RootJoint"

								if rootJoint then
									table.insert(Motors, char.HumanoidRootPart.RootJoint)

									for i, Motor in pairs(char.Torso:GetChildren()) do
										if Motor:IsA "Motor6D" == false then continue end
										table.insert(Motors, Motor)
									end

									for i, v in pairs(Motors) do
										v.C0 = CFrame.new((v.C0.Position * Percent)) * (v.C0 - v.C0.Position)
										v.C1 = CFrame.new((v.C1.Position * Percent)) * (v.C1 - v.C1.Position)
									end

									for i, Part in pairs(char:GetChildren()) do
										if Part:IsA "BasePart" == false then continue end
										Part.Size = Part.Size * Percent
									end

									for i, Accessory in pairs(char:GetChildren()) do
										if Accessory:IsA "Accessory" == false then continue end

										Accessory.Handle.AccessoryWeld.C0 = CFrame.new(
											(Accessory.Handle.AccessoryWeld.C0.Position * Percent)
										) * (Accessory.Handle.AccessoryWeld.C0 - Accessory.Handle.AccessoryWeld.C0.Position)
										Accessory.Handle.AccessoryWeld.C1 = CFrame.new(
											(Accessory.Handle.AccessoryWeld.C1.Position * Percent)
										) * (Accessory.Handle.AccessoryWeld.C1 - Accessory.Handle.AccessoryWeld.C1.Position)

										if Accessory.Handle:FindFirstChildOfClass "SpecialMesh" then
											Accessory.Handle:FindFirstChildOfClass("SpecialMesh").Scale *= Percent
										end
									end
								end
							end
						end
					end
				end

				if #failedPlayers > 0 then
					plr:sendData(
						"SendMessage",
						"Failed to size players due to exceeding size limit: "
							.. (
								#failedPlayers > 5 and #failedPlayers .. " players" or table.concat(failedPlayers, ", ")
							),
						nil,
						10,
						"Context"
					)
				end
			end,
		},

		r6Players = {
			Prefix = settings.actionPrefix,
			Aliases = { "r6", "rig6" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Converts specified player characters into R6",
			PlayerCooldown = 2,

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					if target.Character then task.defer(service.convertPlayerCharacterToRig, target._object, "R6") end
				end
			end,
		},

		r15Players = {
			Prefix = settings.actionPrefix,
			Aliases = { "r15", "rig15", "rthro" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Manage_Characters" },
			Roles = {},

			Description = "Converts specified player characters into R15",
			PlayerCooldown = 2,

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					if target.Character then task.defer(service.convertPlayerCharacterToRig, target._object, "R15") end
				end
			end,
		},

		--flingPlayers = {
		--	Prefix = settings.actionPrefix;
		--	Aliases = {"fling"};
		--	Arguments = {
		--		{
		--			argument = "players";
		--			type = "players";
		--		};
		--		{
		--			argument = "number";
		--			type = "throwPower (1-10)";
		--			min = 1;
		--			max = 10;
		--		}
		--	};
		--	Permissions = {"Manage_Characters";};
		--	Roles = {};

		--	Description = "Flings specified player characters";

		--	Function = function(plr, args)
		--		for i,target in pairs(args[1]) do
		--			local char = target.Character

		--			if char then
		--				local charHrp = char:FindFirstChild"HumanoidRootPart"

		--				if charHrp then
		--					if charHrp:FindFirstChildOfClass"BodyForce" then
		--						service.Debris:AddItem(charHrp:FindFirstChildOfClass"BodyForce", 0.5)
		--					end

		--					local throwPower = args[2] or 10
		--					local forceX, forceZ = math.random(-5000, 10000), math.random(-5000, 10000)
		--					local bodyPos = service.New("BodyPosition", {
		--						MaxForce = Vector3.new(10000000, 10000000, 10000000);
		--						Name = "_ESS_FLINGBP";
		--						D = throwPower*60;
		--						P = 10000;
		--						Position = (charHrp.CFrame * CFrame.new(forceX, 1, forceX)).p;
		--						Parent = charHrp;
		--					})

		--					service.Debris:AddItem(bodyPos, .1)
		--				end
		--			end
		--		end
		--	end;
		--};
	}

	for cmdName, cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
