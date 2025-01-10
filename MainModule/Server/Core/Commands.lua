return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service
	local settings = server.Settings
	local variables = envArgs.variables
	local getEnv = envArgs.getEnv

	local HashLib = server.HashLib
	local Signal = server.Signal

	local CmdCache = {}
	local CmdWithoutPrefixCache = {}

	local Signal = server.Signal
	local Promise = server.Promise
	local Filter = server.Filter
	local Network = server.Network
	local Parser = server.Parser
	local Roles = server.Roles
	local Utility = server.Utility
	local Vela = server.Vela

	local Cmds, Core, Cross, Datastore, Identity, Logs, Moderation, Process, Remote
	local function Init()
		Core = server.Core
		Cross = server.Cross
		Cmds = server.Commands
		Datastore = server.Datastore
		Identity = server.Identity
		Logs = server.Logs
		Moderation = server.Moderation
		Network = server.Network
		Process = server.Process
		Remote = server.Remote

		local loadModule = envArgs.loadModule

		for i, obj in pairs(server.Folder.Commands:GetChildren()) do
			local function scan(plug)
				local plugEnabled = plug:GetAttribute "Enabled"
				local plugDisabled = (plugEnabled ~= nil and plugEnabled == false) or plug:GetAttribute "Disabled"

				if not plugDisabled then loadModule(plug, { script = plug }, false, true) end
			end

			if obj:IsA "Folder" or obj:IsA "Model" then
				for d, otherObj in pairs(obj:GetChildren()) do
					if otherObj:IsA "ModuleScript" then scan(otherObj) end
				end
			elseif obj:IsA "ModuleScript" then
				scan(obj)
			end
		end

		Cmds.cacheAll()
	end

	server.Commands = {
		Init = Init,

		cacheAll = function()
			for i, cmd in pairs(Cmds.Library) do
				if not cmd.Aliases or #cmd.Aliases == 0 then
					if server.Studio then warn("Missing aliases:", i, cmd) end
				else
					if not cmd.Id then cmd.Id = HashLib.sha1(`{cmd.Aliases[1] or "-."}-{tick()}`) end

					for d, alias in cmd.Aliases do
						CmdCache[(cmd.Prefix .. alias):lower()] = cmd
						CmdWithoutPrefixCache[alias:lower()] = cmd
					end
				end
			end
		end,

		create = function(cmdName: string, cmdTab)
			assert(not Cmds.Library[cmdName], `Command {cmdName} already exists`)

			cmdTab.Aliases = cmdTab.Aliases or {}

			for i, alias in cmdTab.Aliases do
				CmdCache[(cmdTab.Prefix .. alias):lower()] = cmdTab
				CmdWithoutPrefixCache[alias:lower()] = cmdTab
			end

			cmdTab.Id = HashLib.sha1(`{cmdTab.Aliases[1] or "-."}-{DateTime.now().UnixTimestampMillis}`)

			Cmds.Library[cmdName] = cmdTab

			return cmdTab
		end,

		get = function(str, index, noPrefix, cmdLib)
			if index then
				if cmdLib then return cmdLib[str] end

				return Cmds.Library[str]
			end

			for cmd, tab in pairs((noPrefix and CmdWithoutPrefixCache) or CmdCache) do
				local strMatch = str:lower():match "^(%S+)"

				if strMatch then
					if strMatch:lower() == cmd:lower() then return tab, cmd end
				end
			end
		end,

		getIdFromCommand = function(inputCommandMatch: string)
			local targetCommand = Cmds.get(inputCommandMatch)

			if targetCommand then return targetCommand.Id end

			return ""
		end,

		getFromId = function(id: string)
			for cmd, tab in pairs(CmdCache) do
				if tab.Id and tab.Id == id then return tab, cmd end
			end
		end,

		getName = function(cmdTable) return table.find(Cmds.Library, cmdTable) or "Command-" .. service.getRandom() end,

		ifStatementChecks = {
			serverName = {
				check = {},
				stringMatch = true,
				Function = function(plr, match) end,
			},
		},

		CoreCommands = {
			wait = {
				Match = settings.playerPrefix .. "wait([%d%p]+)",
				StringMatch = true,
				Public = true,
				Permissions = {},
				Roles = {},

				Function = function(plr, args)
					local number = tonumber(args[1])

					if number and number > 0 then wait(number) end
				end,
			},

			ifStatement = {
				Match = settings.playerPrefix .. "if%((.+)%) {(.+)}",
				StringMatch = true,
				Public = true,
				Permissions = {},
				Roles = {},

				Function = function(plr, args, data)
					local function getStatementCheck(statement)
						for statName, stat in pairs(Cmds.ifStatementChecks) do
							-- Check listed checks
							for d, check in pairs(stat.check) do
								if stat.stringMatch then
									if statement:match(check) then return stat, { statement:match(check) } end
								else
									if statement:lower() == check:lower() then return stat end
								end
							end
						end
					end

					-- Equal statement
					local equalMatch = { string.match(args[1], "(.+)==(.+)") }

					if #equalMatch == 2 then
						local check = equalMatch[1]
						local otherCheck = equalMatch[2]
						local runCmds = args[2]
						local passCheck = false

						return
					end
				end,
			},

			startMuteOnAFK = {
				Match = settings.playerPrefix .. "startmuteonafk",
				StringMatch = false,
				Public = true,
				KeybindAndShortcutOnly = true,
				Permissions = {},
				Roles = {},

				Function = function(plr, args, data)
					if not plr:getPData().__clientSettings.ToggleMuteOnAFK then
						plr:sendData(
							"SendMessage",
							"<b>Unable to start mute on AFK because you disabled Mute on AFK via client settings.</b>",
							nil,
							2,
							"Context"
						)
						return 0
					end

					if Utility:isMuted(plr.Name) and not Utility:isMutedByMOA(plr) then
						plr:sendData(
							"SendMessage",
							"<b>Unable to start mute on AFK because of your current muted state.</b>",
							nil,
							2,
							"Context"
						)
						return 0
					end

					Utility:toggleMuteOnAfk(plr, true)
					plr:sendData("SendMessage", "<b>You are now muted via Mute on AFK system</b>", nil, 2, "Context")
				end,
			},

			endMuteOnAFK = {
				Match = settings.playerPrefix .. "endmuteonafk",
				StringMatch = false,
				Public = true,
				KeybindAndShortcutOnly = true,
				Permissions = {},
				Roles = {},

				Function = function(plr, args, data)
					if not plr:getPData().__clientSettings.ToggleMuteOnAFK then
						plr:sendData(
							"SendMessage",
							"<b>Unable to end mute on AFK because you disabled Mute on AFK via client settings.</b>",
							nil,
							2,
							"Context"
						)
						return 0
					end

					if Utility:isMuted(plr.Name) and not Utility:isMutedByMOA(plr) then
						plr:sendData(
							"SendMessage",
							"<b>Unable to end mute on AFK because of your current muted state.</b>",
							nil,
							2,
							"Context"
						)
						return 0
					end

					Utility:toggleMuteOnAfk(plr, false)
					plr:sendData("SendMessage", "<b>You are now unmuted via Mute on AFK system</b>", nil, 2, "Context")
				end,
			},

			toggleMuteOnAFK = {
				Match = settings.playerPrefix .. "togglemuteonafk",
				StringMatch = false,
				Public = true,
				KeybindAndShortcutOnly = true,
				Permissions = {},
				Roles = {},

				Function = function(plr, args, data)
					if not plr:getPData().__clientSettings.ToggleMuteOnAFK then
						plr:sendData(
							"SendMessage",
							"<b>Unable to toggle mute on AFK because you disabled Mute on AFK via client settings.</b>",
							nil,
							2,
							"Context"
						)
						return 0
					end

					if Utility:isMuted(plr.Name) and not Utility:isMutedByMOA(plr) then
						plr:sendData(
							"SendMessage",
							"<b>Unable to toggle mute on AFK because of your current muted state.</b>",
							nil,
							2,
							"Context"
						)
						return 0
					end

					Utility:toggleMuteOnAfk(plr)
					plr:sendData("SendMessage", "<b>Toggled mute state by Mute on AFK system</b>", nil, 2, "Context")
				end,
			},

			breakStatement = {
				Match = settings.playerPrefix .. "break",
				StringMatch = false,
				Public = true,
				Permissions = {},
				Roles = {},

				Function = function(plr, args, data) return 0 end,
			},
		},

		Library = {
			showCommands = {
				Prefix = settings.actionPrefix,
				Aliases = { "cmds", "commands", "showcommands" },
				Arguments = {},
				Permissions = { "Use_Utility" },
				Roles = {},
				PlayerCooldown = 4,
				NoRepeatedUseInBatch = true,
				NoRepeatedUseInLoop = true,

				Description = "Show available commands",

				Function = function(plr, args)
					local availableCmds = {}
					local delimiter = settings.delimiter

					local playerPriority = Roles:getHighestPriority(plr)

					for i, cmd in pairs(Cmds.Library) do
						if
							not (cmd.Disabled or (cmd.Hidden and not cmd.DontHideFromList))
							and Core.checkCommandUsability(plr, cmd, true)
						then
							if #cmd.Aliases == 0 then continue end

							local copiedCmd = service.cloneTable(cmd)
							local cmdPrefix = cmd.Prefix

							local concatArguments = {}
							for i, arg in pairs(cmd.Arguments) do
								if type(arg) == "table" then
									table.insert(
										concatArguments,
										Parser:filterForRichText("<" .. tostring(arg.argument or i) .. ">")
									)
								else
									table.insert(concatArguments, Parser:filterForRichText("<" .. tostring(arg) .. ">"))
								end
							end
							concatArguments = table.concat(concatArguments, settings.delimiter)

							copiedCmd.Function = nil

							local mainCommand = cmd.Aliases[1]
							local concatAliases = {}
							if #cmd.Aliases > 1 then
								for i = 2, #cmd.Aliases, 1 do
									local alias = cmd.Aliases[i]
									if not alias then continue end

									local cmdNameWithPrefix = (cmdPrefix .. alias):lower()
									table.insert(concatAliases, Parser:filterForRichText(cmdNameWithPrefix))
								end
							end

							concatAliases = table.concat(concatAliases, ", ")

							local concatRoles = {}
							for i, roleName in (cmd.Roles or {}) do
								local actualRole = Roles:get(roleName)
								if actualRole then
									local hiddenFromList = actualRole.hiddenfromlist
									local hiddenFromLowerRank = actualRole.hidelistfromlowranks

									table.insert(
										concatRoles,
										if not hiddenFromList
												and (not hiddenFromLowerRank or playerPriority >= actualRole.priority)
											then Parser:filterForRichText(roleName)
											else '<i><font color="#4E4D50">hidden</font></i>'
									)
								end
							end
							concatRoles = table.concat(concatRoles, ", ")

							table.insert(availableCmds, {
								type = "Detailed",
								label = `{Parser:filterForRichText(cmdPrefix .. mainCommand)} {concatArguments}`,
								description = table.concat({
									`{Parser:filterForRichText(tostring(cmd.Description))}`,
									`<b>Category</b>: {if cmd.Category
										then Parser:filterForRichText(cmd.Category)
										else "<i>none</i>"}`,
									`<b>Aliases ({#cmd.Aliases - 1})</b>: {if #concatAliases == 0
										then `<i>none</i>`
										else concatAliases}`,
									`<b>Permissions ({#cmd.Permissions})</b>: {table.concat(cmd.Permissions, ", ")}`,
									`<b>Roles ({#cmd.Roles})</b>: {concatRoles}`,
								}, "\n"),
								hideSymbol = false,
								richText = true,
							})
						end
					end

					if #availableCmds == 0 then
						plr:sendData(
							"SendMessage",
							"<b>Commands list</b>: There are no commands to provide.",
							nil,
							6,
							"Context"
						)
					else
						plr:makeUI("List", {
							Title = "Essential Commands",
							List = availableCmds,
							AutoUpdateListData = "Commands",
							MainSize = Vector2.new(290, 280),
							MinimumSize = Vector2.new(290, 280),
						})
					end
				end,
			},

			chat_mutePlayer = {
				Prefix = settings.actionPrefix,
				Aliases = { "mute" },
				Arguments = {
					{
						argument = "players",
						type = "players",
						--ignoreSelf = true;
						required = true,
					},
					{
						argument = "duration",
						type = "duration",
						--ignoreSelf = true;
					},
				},
				Permissions = { "Mute_Player" },
				Roles = {},

				Description = "Mutes specified players (cannot mute if they were deafened or already muted)",

				Function = function(plr, args)
					for i, target in pairs(args[1]) do
						Utility:mutePlayer(target.Name, (args[2] and args[2].total) or nil)
						Utility:toggleMuteOnAfk(target, false)

						if args[2] and args[2].total > 0 then
							coroutine.wrap(function()
								local totalSecs = args[2].total

								for i = 1, totalSecs, 1 do
									if not Utility:isMuted(target.Name) then return end

									wait(1)
								end

								Utility:unmutePlayer(target.Name)
							end)()
						end
					end
				end,
			},

			chat_unmutePlayer = {
				Prefix = settings.actionPrefix,
				Aliases = { "unmute" },
				Arguments = {
					{
						argument = "players",
						type = "players",
						--ignoreSelf = true;
						required = true,
					},
				},
				Permissions = { "Mute_Player" },
				Roles = {},

				Description = "Undeafens/unmutes specified players",

				Function = function(plr, args)
					for i, target in pairs(args[1]) do
						Utility:unmutePlayer(target.Name)
					end
				end,
			},

			chat_deafenPlayer = {
				Prefix = settings.actionPrefix,
				Aliases = { "deafen" },
				Arguments = {
					{
						argument = "players",
						type = "players",
						--ignoreSelf = true;
						required = true,
					},
					{
						argument = "duration",
						type = "duration",
					},
				},
				Permissions = { "Deafen_Player" },
				Roles = {},

				Description = "Deafens specified players",

				Function = function(plr, args)
					for i, target in pairs(args[1]) do
						Utility:deafenPlayer(target.Name, (args[2] and args[2].total) or nil)

						if args[2] and args[2].total > 0 then
							coroutine.wrap(function()
								local totalSecs = args[2].total

								for i = 1, totalSecs, 1 do
									if not Utility:isDeafened(target.Name) then return end

									wait(1)
								end

								Utility:unmutePlayer(target.Name)
							end)()
						end
					end
				end,
			},

			chat_undeafenPlayer = {
				Prefix = settings.actionPrefix,
				Aliases = { "undeafen" },
				Arguments = {
					{
						argument = "players",
						type = "players",
						--ignoreSelf = true;
						required = true,
					},
				},
				Permissions = { "Deafen_Player" },
				Roles = {},

				Description = "Undeafens specified players",

				Function = function(plr, args)
					for i, target in pairs(args[1]) do
						if Utility:isDeafened(target.Name) then Utility:unmutePlayer(target.Name) end
					end
				end,
			},

			chatSystem_slowmode = {
				Prefix = settings.actionPrefix,
				Aliases = { "slowmode" },
				Arguments = {
					{
						argument = "seconds/enable/disable/view",
					},
				},
				Permissions = { "Manage_Game" },
				Roles = {},

				Description = "Enables slowmode for chat",

				Function = function(plr, args)
					if args[1] and args[1]:lower() == "disable" then
						server.Events.modChangedSlowmode:fire(
							plr:getInfo(),
							"Status",
							(settings.chatSlowmode_Enabled and true),
							false
						)
						settings.chatSlowmode_Enabled = false
						plr:sendData(
							"SendMessage",
							"Slowmode success",
							"<b>Disabled slowmode</b>. Players can now chat without slowmode.",
							5,
							"Hint"
						)
					elseif args[1] and args[1]:lower() == "enable" then
						server.Events.modChangedSlowmode:fire(
							plr:getInfo(),
							"Status",
							(settings.chatSlowmode_Enabled and true),
							true
						)
						settings.chatSlowmode_Enabled = true
						plr:sendData(
							"SendMessage",
							"Slowmode success",
							"<b>Enabled slowmode</b>. Players without permission 'Manage_Game' or 'Bypass_Chat_Slowmode' are affected by slowmode.",
							5,
							"Hint"
						)
					elseif args[1] and args[1]:lower() == "view" then
						plr:sendData(
							"SendMessage",
							"Slowmode stats",
							"Seconds: "
								.. tostring(settings.chatSlowmode_Interval)
								.. " | Status: "
								.. tostring(settings.chatSlowmode_Enabled),
							10,
							"Hint"
						)
					elseif args[1] then
						local number = tonumber(string.match(args[1], "^[%d%p]+$"))

						if not number then
							plr:sendData(
								"SendMessage",
								"Slowmode error",
								"Unknown option/seconds supplied for slowmode",
								5,
								"Hint"
							)
						else
							server.Events.modChangedSlowmode:fire(
								plr:getInfo(),
								"Interval",
								settings.chatSlowmode_Interval,
								number
							)
							settings.chatSlowmode_Interval = number
							plr:sendData(
								"SendMessage",
								"Slowmode success",
								"Set seconds to " .. tostring(number),
								5,
								"Hint"
							)
						end
					end
				end,
			},

			-- SCRIPT COMMANDS
			--executeScript = {
			--	Prefix = settings.actionPrefix;
			--	Chattable = false;
			--	Silent = true;
			--	Aliases = {"script"};
			--	Arguments = {
			--		{
			--			argument = "code";
			--			required = true;
			--		}
			--	};
			--	Permissions = {"Execute_Scripts";};
			--	Roles = {};

			--	Description = "Executes a regular script to the game";

			--	Function = function(plr, args)
			--		local codeBytecode = Core.bytecode(args[1], {})

			--		if not codeBytecode then
			--			plr:sendData("SendMessage", "Missing bytecode", "Unable to run a script with no bytecode", 20, "Hint")
			--			return
			--		end

			--		local script,scrData = server.Vela:create("Module", args[1])
			--		if server.Roles:hasPermissionFromMember(plr, {"Script_Explicit_Safe"}) then
			--			scrData.EnvTable:set("loadstring", false)
			--			scrData.EnvTable:set("require", false)
			--			scrData.EnvTable:set("shared", {})
			--			scrData.EnvTable:set("_G", {})
			--			scrData.EnvTable:set("gcinfo", false)
			--			scrData.EnvTable:set("getfenv", false)
			--			scrData.EnvTable:set("setfenv", false)
			--		elseif server.Roles:hasPermissionFromMember(plr, {"Use_External_Modules"}) then
			--			local error = error
			--			local type = type
			--			local typeof = typeof
			--			local require = require
			--			local pcall = pcall

			--			scrData.EnvTable:set("require", setfenv(function(asset)
			--				if type(asset) == "number" then
			--					error("Attempt to require a number, expected Instance", 0)
			--				elseif typeof(asset) == "Instance" then
			--					local suc,ers = pcall(require, asset)

			--					if suc then
			--						return ers
			--					end
			--				else
			--					error("Invalid require", 0)
			--				end
			--			end, scrData.EnvTable.env))
			--		end

			--		if server.Roles:hasPermissionFromMember(plr, {"Script_Explicit_Safe"}) then
			--			local customScr = service.newProxy{
			--				__index = function(self, ind)
			--					local chosen = script[ind]

			--					if type(chosen) == "function" then
			--						return function(_, ...)
			--							return chosen(script, ...)
			--						end
			--					else
			--						return chosen
			--					end
			--				end;

			--				__newindex = function(self, ind, val)
			--					if rawequal(ind, "Parent") then
			--						if typeof(val) == "Instance" then
			--							if not val:IsDescendantOf(game) then
			--								error("Unable to parent script to a void", 0)
			--							else
			--								script.Parent = val
			--							end
			--						else
			--							error("Unable to parent script to a void", 0)
			--						end
			--					else
			--						script[ind] = val
			--					end
			--				end;

			--				__tostring = function() return script.Name end;
			--				__metatable = "The metatable is locked";
			--			}
			--		end

			--		local blacklistedFuncs = {}
			--		for i,role in pairs(server.Roles:getRolesFromMember(plr)) do
			--			local blacklistedAccess = role.permissions["Blacklisted_Script_Access"] or {}

			--			if blacklistedAccess then
			--				for userdata,statTrue in pairs(blacklistedAccess) do
			--					if statTrue then
			--						scrData.EnvTable:set(tostring(userdata), -1)
			--					end
			--				end
			--			end
			--		end

			--		require(script)

			--		plr:sendData("SendMessage", "Executed script", "Script ran successfully", 5, "Hint")
			--	end;
			--};

			--executeLocalScript = {
			--	Prefix = settings.actionPrefix;
			--	Chattable = false;
			--	Silent = true;
			--	Aliases = {"lscript"};
			--	Arguments = {
			--		{
			--			argument = "players";
			--			type = "players";
			--			required = true;
			--		};
			--		{
			--			argument = "code";
			--			required = true;
			--		};
			--	};
			--	Permissions = {"Execute_Scripts";};
			--	Roles = {};

			--	Description = "Executes a local script to specified players";

			--	Function = function(plr, args)
			--		local codeBytecode = Core.bytecode(args[2], {})

			--		if not codeBytecode then
			--			plr:sendData("SendMessage", "Missing bytecode", "Unable to run a script with no bytecode", 20, "Hint")
			--			return
			--		end

			--		for i,target in pairs(args[1]) do
			--			local container = service.New("ScreenGui", {
			--				Name = service.getRandom();
			--				Archivable = false;
			--				ResetOnSpawn = false;
			--			})

			--			local script,scrData = server.Vela:create("Client", args[2])
			--			script.Disabled = false
			--			script.Parent = container
			--			container.Parent = target:FindFirstChildOfClass"PlayerGui"
			--		end

			--		plr:sendData("SendMessage", "Executed script", "Local Script ran to "..tostring(#args[1]).." players", 5, "Hint")
			--	end;
			--};

			repeatCmds = {
				Prefix = settings.actionPrefix,
				Aliases = { "repeat", "loop" },
				Arguments = {
					{
						argument = "interval",
						type = "interval",
						required = true,
						max = 80,
						min = 1,
					},
					{
						argument = "delay",
						type = "number",
						required = true,
						max = 300,
						min = 0.1,
					},
					{
						argument = "command line",
						required = true,
					},
				},
				Permissions = { "Manage_Game" },
				Roles = {},
				PlayerCooldown = 5,
				ServerCooldown = 2,

				Description = "Repeats the specified command for the amount of interval and delay",

				Function = function(plr, args, data)
					local curInt = 0
					local goBreak = false
					local loopInd = "LOOP-" .. service.getRandom()
					local playerUserId = plr.UserId
					local loopData = {
						UserId = playerUserId,
						Ind = loopInd,
					}
					local curCreatedLoops = (function()
						local count = 0

						for i, otherLoop in pairs(variables.loopingCmds) do
							if otherLoop.UserId == playerUserId then
								count += 1
							end
						end

						return count
					end)()

					if curCreatedLoops + 1 > 10 then
						plr:sendData("SendMessage", "You cannot create more than 10 loop commands.", nil, 5, "Context")
						return
					end

					table.insert(variables.loopingCmds, loopData)
					service.startLoop(loopInd, args[2], function()
						if curInt + 1 <= args[1] and plr:isInGame() and not goBreak then
							if
								not Process.playerCommand(
									plr,
									args[3],
									setmetatable(service.cloneTable(data), { __index = { loop = true } })
								)
							then
								goBreak = true
							else
								curInt += 1
							end
						else
							if table.find(variables.loopingCmds, loopData) then
								table.remove(variables.loopingCmds, table.find(variables.loopingCmds, loopData))
							end
							service.stopLoop(loopInd)
						end
					end)
				end,
			},

			stopRepeat = {
				Prefix = settings.actionPrefix,
				Aliases = { "endrepeat", "abortloop", "endloop" },
				Arguments = {
					{
						argument = "players",
						type = "list",
					},
				},
				Permissions = { "Manage_Game" },
				Roles = {},
				PlayerCooldown = 1,

				Description = "Stops the ongoing looped commands by specified players or all",

				Function = function(plr, args, data)
					if not args[1] then
						for i, loop in pairs(variables.loopingCmds) do
							service.stopLoop(loop.Ind)
							variables.loopingCmds[i] = nil
						end
					else
						local avUserIds = {}

						for i, plrName in pairs(args[1]) do
							local uId = service.playerIdFromName(plrName) or 0

							if uId > 0 then table.insert(avUserIds, uId) end
						end

						for _, uId in pairs(avUserIds) do
							for i, loop in pairs(variables.loopingCmds) do
								if loop.UserId == uId then
									service.stopLoop(loop.Ind)
									variables.loopingCmds[i] = nil
								end
							end
						end
					end
				end,
			},
		},
	}
end
