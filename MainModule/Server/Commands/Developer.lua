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
	local Parser = server.Parser

	local function filterForRichText(text)
		return Parser:replaceStringWithDictionary(text, {
			["<"] = "&lt;",
			[">"] = "&gt;",
			["&"] = "&amp;",
			--['"']		= "&quot;";
			["'"] = "&apos;",
		})
	end

	local function removeTags(str)
		str = str:gsub("<br%s*/>", "\n")
		return (str:gsub("<[^<>]->", ""))
	end

	local cmdsList = {
		--debugCommand = {
		--	Prefix = settings.actionPrefix;
		--	Aliases = {"debugcommand", "debugcmd"};
		--	Arguments = {
		--		{
		--			argument = 'command';
		--			required = true;
		--		}
		--	};
		--	Permissions = {"Manage_Game"};
		--	Roles = {};
		--	PlayerCooldown = 1;

		--	Description = "Debugs a specific command";

		--	Function = function(plr, args)
		--		local specifiedCmd = Cmds.get(args[1])

		--		if not specifiedCmd then
		--			plr:sendData("SendMessage", "Debug command error", "Command <b>"..args[1].."</b> doesn't exist.", 6, "Hint")
		--		else
		--			local tab = {}
		--		end
		--	end;
		--};

		-- TEST COMMANDS (ONLY ON STUDIO)

		testConfirmation = {
			Disabled = not server.Studio,
			Prefix = settings.playerPrefix .. "-",
			Aliases = { "testconfirm" },
			Arguments = { "time" },
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "[TEST COMMAND]",

			Function = function(plr, args)
				local confirmTime = math.random(30, 60)
				local confirm = plr:makeUIGet("Confirmation", {
					title = "Test Confirmation",
					desc = "Are you sure this works?",
					choiceA = "Yes, I confirm.",
					returnOutput = true,
					time = (args[1] and args[1]:lower() == "true" and confirmTime) or nil,
				})

				plr:sendData("SendMessage", "Test confirm complete", "Returned: " .. tostring(confirm), 120, "Hint")
			end,
		},

		testMessage = {
			Disabled = not server.Studio,
			Prefix = settings.playerPrefix .. "-",
			Aliases = { "testmessage" },
			Arguments = {
				{
					argument = "duration",
					type = "duration",
				},
			},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "[TEST COMMAND]",

			Function = function(plr, args)
				local messageInput =
					"Donec pretium vulputate sapien nec sagittis aliquam malesuada. Sed risus pretium quam vulputate dignissim. Ac felis donec et odio. Pellentesque massa placerat duis ultricies lacus. Ac turpis egestas sed tempus urna et. Dolor sed viverra ipsum nunc aliquet bibendum enim. Semper eget duis at tellus at urna condimentum. Lacus laoreet non curabitur gravida arcu ac tortor. Cursus euismod quis viverra nibh cras pulvinar. Commodo viverra maecenas accumsan lacus vel facilisis volutpat est velit. Augue eget arcu dictum varius duis at. Augue eget arcu dictum varius duis at consectetur lorem."
				plr:sendData("SendMessageV2", "Test Message", messageInput, (args[1] and args[1].total) or 30)
			end,
		},

		testBubble = {
			Disabled = not server.Studio,
			Prefix = settings.playerPrefix .. "-",
			Aliases = { "testbubble" },
			Arguments = {
				{
					argument = "duration",
					type = "duration",
				},
			},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "[TEST COMMAND]",

			Function = function(plr, args)
				local messageInput =
					"Donec pretium vulputate sapien nec sagittis aliquam malesuada. Sed risus pretium quam vulputate dignissim. Ac felis donec et odio. Pellentesque massa placerat duis ultricies lacus."
				plr:sendData("SendMessage", "Test Bubble", messageInput, (args[1] and args[1].total) or 30, "Bubble")
			end,
		},

		testHint = {
			Disabled = not server.Studio,
			Prefix = settings.playerPrefix .. "-",
			Aliases = { "testhint" },
			Arguments = {},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "[TEST COMMAND]",

			Function = function(plr, args)
				local messageInput =
					"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
				plr:sendData("SendMessage", "Test Message", messageInput, 10, "Hint")
			end,
		},

		testError = {
			Disabled = not server.Studio,
			Prefix = settings.playerPrefix .. "-",
			Aliases = { "testerror" },
			Arguments = {},
			Permissions = { "Manage_Game" },
			Roles = {},

			Description = "[TEST COMMAND]",

			Function = function(plr, args) error("Test error", 0) end,
		},

		testConfirm = {
			Disabled = not server.Studio,
			Prefix = settings.playerPrefix .. "-",
			Aliases = { "testconfirm" },
			Arguments = { "time" },
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "[TEST COMMAND]",

			Function = function(plr, args)
				local confirmTime = math.random(30, 60)
				local confirm = plr:makeUIGet("Confirmation", {
					title = "Test Confirmation",
					desc = "Are you sure this works?",
					choiceA = "Yes, I confirm.",
					returnOutput = true,
					time = (args[1] and args[1]:lower() == "true" and confirmTime) or nil,
				})

				plr:sendData("SendMessage", "Test confirm complete", "Returned: " .. tostring(confirm), 120, "Hint")
			end,
		},

		testContext = {
			Disabled = not server.Studio,
			Prefix = settings.playerPrefix .. "-",
			Aliases = { "testcontext" },
			Arguments = { "message" },
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "[TEST COMMAND]",

			Function = function(plr, args)
				local messageInput = args[1]
					or "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
				plr:sendData("SendMessage", messageInput, removeTags(messageInput), 10, "Context")
			end,
		},

		testMakeUI = {
			Disabled = not server.Studio,
			Prefix = settings.playerPrefix .. "-",
			Aliases = { "testmakeui" },
			Arguments = {
				{
					argument = "guiName",
					required = true,
				},
			},
			Permissions = { "Use_Utility" },
			Roles = {},

			Description = "[TEST COMMAND]",

			Function = function(plr, args)
				local confirmTime = math.random(30, 60)
				local results = { plr:makeUIGet(args[1]) }

				plr:sendData(
					"SendMessage",
					"UI Construction results",
					"GUI: "
						.. args[1]
						.. " | Return count: "
						.. tostring(#results)
						.. ". View the developer console to see the results.",
					20,
					"Hint"
				)
				warn("UI construction " .. args[1] .. " results:", results)
			end,
		},

		showRolesEnlistedAsPlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "showenlistedroles", "showplayerroles" },
			Arguments = {
				{
					argument = "target",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = {},
			Roles = {},

			Description = "Shows the possible roles the player is enlisted & dynamically assigned",

			Function = function(plr, args)
				local target = args[1][1]

				if not target:isInGame() then
					plr:sendData(
						"SendMessage",
						`{tostring(target)} is not in the server. Some dynamic validation, which roles may include, like asset ownership requires`
							.. ` the presence of the player in the server. Some roles with those dynamic validation will not show up in your view unless the player is in the server.`,
						nil,
						6,
						"Context"
					)
				end

				local updateRemId = "ViewRoles-" .. target.UserId
				local updateRemData = Remote.ListData[updateRemId]
					or {
						Whitelist = {},
						Permissions = { "Manage_Game" },
						Function = function(plr)
							local priorityRoles1 = {}
							local priorityRoles2 = {}
							for i, role in pairs(Roles:getAll(true)) do
								table.insert(priorityRoles1, role)
							end

							table.sort(priorityRoles1, function(a, b) return a.priority > b.priority end)

							for roleInd, role in ipairs(priorityRoles1) do
								local rolePriority = role.priority

								local memberCount = 0
								local checkedUserIds = {}
								local membersList = {}

								local oTarget = target

								local highPriority = Roles:getHighestPriority(target)

								for i, otherPlr in ipairs { target } do
									local pData = otherPlr:getPData()
									local savedRoles = pData.__savedRoles
									local isRoleDataSaved = savedRoles._find(role.name)

									if
										role:checkMember(if otherPlr:isInGame() then otherPlr else otherPlr.UserId)
										or (isRoleDataSaved and role.saveable)
									then
										memberCount += 1
										checkedUserIds[otherPlr.UserId] = true

										if role:checkTempMember(otherPlr) or isRoleDataSaved then
											table.insert(membersList, {
												type = "Detailed",
												label = `> `
													.. (isRoleDataSaved and "🏢" or "🔖")
													.. " "
													.. otherPlr.DisplayName
													.. " (@"
													.. otherPlr.Name
													.. " / "
													.. otherPlr.UserId
													.. ")",
												labelColor = Color3.fromRGB(185, 216, 27),
												description = `Rank Type: Server/PData`,
												hideSymbol = true,
											})
										else
											table.insert(membersList, {
												type = "Label",
												label = `> `
													.. otherPlr.DisplayName
													.. " (@"
													.. otherPlr.Name
													.. " / "
													.. otherPlr.UserId
													.. ")",
												labelColor = Color3.fromRGB(185, 216, 27),
												hideSymbol = true,
											})
										end
									end
								end

								table.insert(priorityRoles2, {
									type = "Label",
									label = (rolePriority == highPriority and "🔸 " or "")
										.. role.name
										.. " ("
										.. memberCount
										.. ")",
									labelColor = role.permissions["Manage_Game"] and Color3.fromRGB(255, 174, 44)
										or nil,
									description = "Priority: "
										.. tostring(role.priority)
										.. " | Assignable: "
										.. tostring(role.assignable or false),
								})

								for i, memberName in ipairs(membersList) do
									if type(memberName) == "table" then
										table.insert(priorityRoles2, memberName)
									else
										table.insert(priorityRoles2, {
											type = "Label",
											label = "> " .. memberName,
											labelColor = Color3.fromRGB(221, 221, 221),
										})
									end
								end

								if roleInd < #priorityRoles1 then table.insert(priorityRoles2, "-----") end
							end

							return priorityRoles2
						end,
					}

				if not Remote.ListData[updateRemId] then Remote.ListData[updateRemId] = updateRemData end

				plr:makeUI("List", {
					Title = "E. " .. target.Name .. "'s Enlisted Roles [Mod view]",
					List = updateRemData.Function(plr),
					Update = true,
					UpdateArg = updateRemId,
				})
			end,
		},

		showUsableCommandsAsPlayer = {
			Prefix = settings.actionPrefix,
			Aliases = { "showusablecmds" },
			Arguments = {
				{
					argument = "target",
					type = "players",
					required = true,
					allowFPCreation = true,
				},
			},
			Permissions = {},
			Roles = {},

			Description = "Shows the specified players' usable commands",

			Function = function(plr, args)
				local target = args[1][1]

				local updateRemId = "UsableCmds-" .. target.UserId .. "-" .. plr.UserId
				local updateRemData = Remote.ListData[updateRemId]
					or {
						Whitelist = { plr.UserId },
						Permissions = {},
						Function = function() return Remote.ListData.Commands.Function(target) end,
					}

				local availableCmds = updateRemData.Function()

				if not Remote.ListData[updateRemId] then Remote.ListData[updateRemId] = updateRemData end

				plr:makeUI("List", {
					Title = "E. " .. target.Name .. "'s Usable Commands [Mod view]",
					List = availableCmds,
					AutoUpdate = true,
				})
			end,
		},

		--showRolePermissions = {
		--	Prefix = settings.actionPrefix;
		--	Aliases = {"showroleperms"};
		--	Arguments = {
		--		{
		--			argument = "roleName";
		--			required = true;
		--		};
		--	};
		--	Permissions = {};
		--	Roles = {};

		--	Description = "Shows the permissions from a specified role";

		--	Function = function(plr, args)
		--		local roleInfo = server.Roles:get(args[1])

		--		if not roleInfo then
		--			plr:sendData("SendMessage", "Role management error", "Role "..args[1].." doesn't exist.", 6, "Hint")
		--			return
		--		end

		--		local tabList = {}
		--		for perm, val in pairs(roleInfo.permissions) do
		--			table.insert(tabList, tostring(perm)..": "..(val and "✔️" or "❌"))
		--		end

		--		plr:makeUI("List", {
		--			Title = "E. Role "..args[1].." permissions";
		--			List = tabList;
		--			Update = true;
		--		})
		--	end;
		--};

		showScriptLogs = {
			Disabled = true,
			NoDisableAndEnable = true,

			Prefix = settings.actionPrefix,
			Aliases = { "scriptlogs" },
			Arguments = {
				{
					type = "trueOrFalse",
					argument = "autoUpdate",
				},
			},
			Permissions = { "View_Logs" },
			Roles = {},
			PlayerCooldown = 2,

			Description = "Show script logs",

			Function = function(plr, args)
				plr:makeUI("List", {
					Title = "E. Script Logs",
					List = Remote.ListData.Client.Function(plr),
					AutoUpdate = args[1] or false,
					AutoUpdateListData = "Script",
				})
			end,
		},

		-- FOR CREATORS ONLY
		executeCode = {
			Prefix = settings.actionPrefix,
			Chattable = false,
			Silent = true,
			Aliases = { "loadstring" },
			Arguments = {
				{
					argument = "code",
					required = true,
				},
			},
			Permissions = {},
			Roles = { "creator" },
			Whitelist = { "trzistan", "TheLegendary_Spark" },
			NoDisableAndEnable = true,
			NoPermissionsBypass = true,

			Description = "Executes an invisible script to the game",

			Function = function(plr, args)
				local func, byte = Core.loadstring(args[1], getEnv(nil, { player = plr, server = server }))

				if type(func) == "function" then
					local errorTrace = ""
					local errMsg = ""
					local suc, ers = xpcall(func, function(errMessage)
						errMsg = tostring(errMessage)
						errorTrace = debug.traceback(nil, 2)
					end)

					if not suc then
						plr:sendData(
							"SendMessage",
							"Loadstring function error",
							tostring(errMsg) .. "\n" .. tostring(errorTrace),
							30
						)
					else
						plr:sendData("SendMessage", "Loadstring function success", "Ran code successfully", 5, "Hint")
					end
				else
					plr:sendData("SendMessage", "Missing line in loadstring", tostring(byte), 20)
				end
			end,
		},
	}

	for cmdName, cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
