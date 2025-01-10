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

	local getRandom = service.getRandom

	local cmdsList = {
		beginPoll = {
			Prefix = settings.actionPrefix,
			Silent = true,
			Disabled = true,
			NoEnableAndDisable = true,
			Aliases = { "vote", "poll" },
			Arguments = {
				{
					argument = "players",
					type = "players",
					required = true,
				},
				{
					argument = "options",
					type = "list",
					filter = true,
					required = true,
				},
				{
					argument = "time",
					type = "duration",
					required = true,
					minDuration = 5,
					maxDuration = 600,
				},
				{
					argument = "canSelectMultiple",
					type = "trueOrFalse",
					required = true,
				},
				{
					argument = "publicResults",
					type = "trueOrFalse",
					required = true,
				},
				{
					argument = "topic",
					filter = true,
					required = true,
				},
			},
			Permissions = { "Send_Polls" },
			Roles = {},

			Description = "Sends a poll to specified players",
			PlayerCooldown = 2,

			Function = function(plr, args)
				local pollOptions = {}

				for i, optText in pairs(args[2]) do
					table.insert(pollOptions, {
						text = optText,
					})
				end

				local pollSession = Remote.makePoll(
					args[1],
					"Poll - " .. args[6] .. " (" .. plr.Name .. ")",
					(args[4] and "Select multiple options") or "Select one option",
					pollOptions,
					args[4],
					true,
					args[5],
					os.time() + args[3].total
				)
				local listUpdateId = "PollResults-" .. getRandom(20)

				Remote.ListData[listUpdateId] = {
					Whitelist = { plr.UserId },
					Permissions = {},
					Function = function(plr)
						local tab = {}

						table.insert(tab, "Topic: ")
						table.insert(tab, "> " .. args[6])
						table.insert(tab, "Description: ")
						table.insert(tab, "> " .. pollSession.desc)

						table.insert(tab, " ")
						table.insert(tab, "Players (" .. tostring(#args[1]) .. ")")

						local concatPlayers = {}
						for i, target in pairs(args[1]) do
							local confirmData = pollSession.confirmPlayers[target]
							local selectedOpts = {}

							for _, optData in pairs(confirmData or {}) do
								table.insert(selectedOpts, optData.text)
							end

							table.insert(tab, {
								Text = target.Name .. " (" .. target.DisplayName .. ") - " .. tostring(
									confirmData
											and "responded (" .. #selectedOpts .. "): " .. table.concat(
												selectedOpts,
												", "
											)
										or "not responded"
								),
								Desc = "UserId: " .. tostring(target.UserId),
								RichText = true,
							})
						end

						table.insert(tab, "----")

						table.insert(tab, "Results:")
						table.insert(tab, " ")

						for i, optData in ipairs(pollSession.options) do
							local resultId = optData.uniqueId
							local resultsData = pollSession.results[resultId]
							local playersCount = #resultsData.players
							local confirmPlayersCount = service.tableCount(pollSession.confirmPlayers)
							local percent = (
								(playersCount == 0 and confirmPlayersCount == 0 and 0)
								or playersCount / confirmPlayersCount
							) * 100

							table.insert(tab, {
								Text = optData.text
									.. ": "
									.. tostring(math.round(percent))
									.. "% answered ("
									.. playersCount
									.. " player(s))",
								Desc = "Id: " .. tostring(resultId),
							})
						end

						table.insert(tab, " ")
						table.insert(tab, "----")

						return tab
					end,
				}

				plr:makeUI("ADONIS_LIST", {
					Title = "E. Poll " .. pollSession.id,
					Table = Remote.ListData[listUpdateId].Function(plr),
					Size = { 500, 400 },
					Update = true,
					UpdateArg = listUpdateId,
					AutoUpdate = 2,
				})
			end,
		},
	}

	for cmdName, cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
