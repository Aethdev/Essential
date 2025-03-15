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
	local Roles = server.Roles

	local cmdsList = {
		boombox = {
			Disabled = not settings.funCommands,
			Prefix = settings.actionPrefix,
			Aliases = { "boombox" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
			},
			Permissions = { "Use_Fun_Commands" },
			Roles = {},
			PlayerCooldown = 1,

			Description = "Gives boombox to specific players",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local boombox = server.Assets.Boombox:Clone()
					boombox.Archivable = false
					boombox.ToolTip = "Imported from Essential"
					boombox.Parent = target:FindFirstChildOfClass "Backpack"
				end
			end,
		},

		swordPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "sword" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,
				},
			},
			Permissions = { "Use_Fun_Commands" },
			Roles = {},

			Description = "Gives specified players a sword",

			Function = function(plr, args)
				for i, target in pairs(args[1]) do
					local backpack = target:FindFirstChildOfClass "Backpack"

					if backpack then
						local sword = server.Assets.ClassicSword:Clone()
						sword.Name = "Classic Sword"
						sword.ToolTip = "Imported from Essential"

						sword.Parent = backpack
					end
				end
			end,
		},

		gearPlayers = {
			Prefix = settings.actionPrefix,
			Aliases = { "gear" },
			Arguments = {
				{
					type = "players",
					argument = "players",
					required = true,
					noDuplicates = false,
				},
				{
					type = "list",
					argument = "gears",
					required = true,
				},
			},
			Permissions = { "Use_Fun_Commands" },
			Roles = {},

			Description = "Gear specified players with gears",

			Function = function(plr, args)
				local canUseExternal = Roles:hasPermissionsFromMember(plr, { "Use_External_Gears" })

				local listedGears = {}
				local insertedGears = {}
				local bannedGears = {}

				local gearsBanlist = variables.gearBlacklist

				for i, id in pairs(args[2]) do
					local gearId = tonumber(string.match(id, "^(%d+)$"))

					if gearId and gearsBanlist[gearId] then
						if not table.find(bannedGears, gearId) then table.insert(bannedGears, gearId) end
					elseif gearId and gearId > 0 then
						local gearInfo = service.getProductInfo(gearId)
						local externalGear = gearInfo.AssetTypeId == 10

						if gearInfo.AssetTypeId == 10 or gearInfo.AssetTypeId == 19 then
							if externalGear and not canUseExternal then
								if not table.find(bannedGears, gearId) then table.insert(bannedGears, gearId) end
								continue
							end

							local insertSuccess, assetItems = service.insertAsset(gearId)
							local assetTools = {}

							for _, item in pairs(assetItems) do
								if item:IsA "Tool" then table.insert(assetTools, item) end
							end

							if #assetTools > 0 then
								if not table.find(listedGears, gearId) then table.insert(listedGears, gearId) end
								table.insert(insertedGears, assetTools)
							end
						end
					end
				end

				local backpacks = {}
				for i, target in pairs(args[1]) do
					local backpack = target:FindFirstChildOfClass "Backpack"

					if backpack then backpacks[target] = backpack end
				end

				for i, gearItems in pairs(insertedGears) do
					for d, gearItem in pairs(gearItems) do
						for target, backpack in pairs(backpacks) do
							gearItem:Clone().Parent = backpack
						end
					end
				end

				if #bannedGears > 0 then
					plr:sendData(
						"SendMessage",
						"Gear Insertion failed",
						"Gears such as "
							.. table.concat(bannedGears, ", ")
							.. " are banned or not allowed due to insufficient permissions.",
						3,
						"Hint"
					)
					wait(3)
				end

				if #listedGears > 0 then
					plr:sendData(
						"SendMessage",
						"Gear Insertion success",
						"Gears such as " .. table.concat(listedGears, ", ") .. " are inserted successfully.",
						6,
						"Hint"
					)
				else
					plr:sendData(
						"SendMessage",
						"Gear Insertion failed",
						"There were no gears listed to be inserted.",
						6,
						"Hint"
					)
				end
			end,
		},
	}

	for cmdName, cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
