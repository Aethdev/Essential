
return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service
	local settings = server.Settings
	local variables = envArgs.variables
	local getEnv = envArgs.getEnv
	local script = envArgs.script
	
	local Signal = server.Signal
	local Promise = server.Promise
	local Filter = server.Filter
	local Network = server.Network
	local Parser = server.Parser
	local Roles = server.Roles
	local Utility = server.Utility
	local Vela = server.Vela
	
	local Cmds = server.Commands
	local Core = server.Core
	local Cross = server.Cross
	local Datastore = server.Datastore
	local Identity = server.Identity
	local Logs = server.Logs
	local Moderation = server.Moderation
	local Process = server.Process
	local Remote = server.Remote
	
	local cmdsList = {
		joinTeam = {
			Prefix = settings.actionPrefix;
			Aliases = {"jointeam"};
			Arguments = {
				{
					argument = 'teamName';
					required = true;
				}	
			};
			Permissions = {"Manage_Players"};
			Roles = {};
			PlayerCooldown = 1;

			Description = "Joins a specified team";

			Function = function(plr, args)
				local teamName = args[1]
				
				for i,team in pairs(service.Teams:GetChildren()) do
					if team:IsA"Team" and team.Name:sub(1,#teamName):lower() == teamName:lower() then
						plr._object.Team = team
						plr:sendData("SendMessage", "Team Management success", "Joined team <b>"..team.Name.."</b>", 8, "Hint")
						break
					end
				end
			end;
		};
		
		leaveTeam = {
			Prefix = settings.actionPrefix;
			Aliases = {"leaveteam", "abandonteam"};
			Arguments = {
				{
					argument = "players";
					type = "players";
					required = true;
				}	
			};
			Permissions = {"Manage_Players"};
			Roles = {};
			PlayerCooldown = 1;

			Description = "Removes specified players' current team";

			Function = function(plr, args)
				local successPlayers = {}
				
				for i,target in pairs(args[1]) do
					if target._object.Team ~= nil then
						target._object.Team = nil
						table.insert(successPlayers, target.Name)
					end
				end
				
				if #successPlayers == 0 then
					plr:sendData("SendMessage", "Team Management failed", "The specified players don't have a team to leave.", 4, "Hint")
				else
					plr:sendData("SendMessage", "Team Management success", table.concat(successPlayers, ", ").." abandoned their current team.", 8, "Hint")
				end
			end;
		};
		
		addPlayersToTeam = {
			Prefix = settings.actionPrefix;
			Aliases = {"team"};
			Arguments = {
				{
					argument = 'players';
					type = "players";
					required = true;
				};
				{
					argument = 'teamName';
					required = true;
				}
			};
			Permissions = {"Manage_Players"};
			Roles = {};
			PlayerCooldown = 1;

			Description = "Adds specified players to a nearest team by a supplied team name";

			Function = function(plr, args)
				local teamName = args[2]
				
				local availableTeam
				for i,team in pairs(service.Teams:GetChildren()) do
					if team:IsA"Team" and team.Name:sub(1,#teamName):lower() == teamName:lower() then
						availableTeam = team
						break
					end
				end
				
				if availableTeam then
					for i, target in pairs(args[1]) do
						target._object.Team = availableTeam
					end
					
					plr:sendData("SendMessage", "Team Management success", "Assigned <b>"..tostring(#args[1]).." players</b> to "..availableTeam.Name, 8, "Hint")
				else
					plr:sendData("SendMessage", "Team Management failed", "There's no team with a name "..teamName, 4, "Hint")
				end
			end;
		};
		
		createTeam = {
			Prefix = settings.actionPrefix;
			Aliases = {"newteam", "createteam", "developteam"};
			Arguments = {
				{
					argument = 'autoAssignable';
					type = "trueOrFalse";
					required = true;
				};
				{
					argument = 'teamName';
					required = true;
					filter = true;
				};
			};
			Permissions = {"Manage_Players"};
			Roles = {};
			PlayerCooldown = 1;

			Description = "Creates a specified team";

			Function = function(plr, args)
				local team = service.New("Team")
				team.AutoAssignable = args[1]
				team.Name = args[2]
				team.Parent = service.Teams
				
				plr:sendData("SendMessage", "Team Management success", "Created team "..args[2], 6, "Hint")
			end;
		};
		
		deleteTeam = {
			Prefix = settings.actionPrefix;
			Aliases = {"deleteteam", "destroyteam"};
			Arguments = {
				{
					argument = 'teamName';
					required = true;
				};
			};
			Permissions = {"Manage_Players"};
			Roles = {};
			PlayerCooldown = 1;

			Description = "Deletes a specified team";

			Function = function(plr, args)
				local teamName = args[1]
				local avTeam
				
				for i,team in pairs(service.Teams:GetChildren()) do
					if team:IsA"Team" and team.Name:sub(1,#teamName):lower() == teamName:lower() then
						avTeam = team
						service.Delete(team)
						break
					end
				end
				
				if avTeam then
					plr:sendData("SendMessage", "Team Management success", "Destroyed team "..avTeam.Name, 6, "Hint")
				else
					plr:sendData("SendMessage", "Team Management failed", "There's no available team to destroy.", 6, "Hint")
				end
			end;
		};
		
		addPlayersToRoles = {
			Prefix = settings.actionPrefix;
			Aliases = {"addplayerstoroles"};
			Arguments = {
				{
					type = "players";
					argument = "players";
					required = true;
					allowFPCreation = true;
				};
				{
					type = "trueOrFalse";
					argument = "saveInData";
					required = true;
				};
				{
					type = "list";
					argument = "rolenames";
					required = true;
				};	
			};
			Permissions = {"Manage_Players"};
			Roles = {};

			PlayerCooldown = 5;

			Description = "Adds players to specific roles";

			Function = function(plr, args)
				local players = args[1]
				local availableRoles = {}
				local highPriority = Roles:getHighestPriority(plr)

				for i,role in pairs(Roles:getAll()) do
					if role.assignable and role.priority < highPriority then
						table.insert(availableRoles, role)
					end
				end

				local listedRoles = {}
				local adminRoles = {}

				local concatListedRoles = ''
				local concatAdminRoles = ''
				
				local saveInData = args[2]
				local specifiedRoles = args[3]
				
				for i,givenName in pairs(specifiedRoles) do
					for d,avRole in pairs(availableRoles) do
						if (givenName:lower()=="all" or avRole.name:sub(1,#givenName):lower() == givenName:lower()) and not table.find(listedRoles, avRole) then
							table.insert(listedRoles, avRole)

							if avRole:hasPermission("Manage_Game") then
								table.insert(adminRoles, avRole)
							end
						end
					end
				end
				
				if saveInData then
					local canSaveRoles = Moderation.checkAdmin(plr) or Roles:hasPermissionFromMember(plr, {"Manage_Roles"})
					if not canSaveRoles then
						plr:sendData("SendMessage", `<b>Roles Management</b> ` .. "You must have permission <b>Manage_Roles</b> to save player roles.", nil, 5, "Context")
						return
					end
					
					local failedToSaveRoles = {}
					
					local filterList; filterList = function()
						for i, targetedRole in ipairs(listedRoles) do
							if not targetedRole.saveable then
								table.insert(failedToSaveRoles, "<b>"..Parser:filterForRichText(targetedRole.name).."</b>")
								table.remove(listedRoles, i)
								filterList()
							end
						end
					end
					
					filterList()
					if #failedToSaveRoles > 0 then
						plr:sendData("SendMessage", `<b>Roles Management</b>: ` .. table.concat(failedToSaveRoles, ", ").." doesn't have the option 'saveable' enabled. You cannot save these roles", nil, 5, "Context")
						wait(5)
						if #listedRoles == 0 then
							return
						end
					end
				end

				for i,givenRole in pairs(listedRoles) do
					if i == #listedRoles then
						if #listedRoles > 1 then
							concatListedRoles = concatListedRoles.." & <b>"..givenRole.name.."</b>"
						else
							concatListedRoles = concatListedRoles.." <b>"..givenRole.name.."</b>"
						end
					else
						concatListedRoles = concatListedRoles.."<b>"..givenRole.name.."</b>, "
					end
				end

				for i,givenRole in pairs(adminRoles) do
					if i == #adminRoles then
						if #adminRoles > 1 then
							concatAdminRoles = concatAdminRoles.." & <b>"..givenRole.name.."</b>"
						else
							concatAdminRoles = concatAdminRoles.." <b>"..givenRole.name.."</b>"
						end
					else
						concatAdminRoles = concatAdminRoles.."<b>"..givenRole.name.."</b>, "
					end
				end

				if #listedRoles > 0 then
					local confirmChoice1 = plr:customGetData(10+30, "MakeUI", "ConfirmationV2", {
						title = "Role Management confirmation";
						description = "Are you sure you would like to assign "..tostring(#players).." player(s) to "..concatListedRoles.."?";
						firstChoice = {
							label = "Yes, I confirm.";
							submissionPage = {
								title = "Role Management Confirmed";
								duration = 2;
							}
						};
						secondChoice = {
							label = "No";
							submissionPage = {
								title = "Role Management Canceled";
								duration = 5;
							}
						};
						returnChoice = true;
						timeDuration = 10;
					})

					if confirmChoice1 ~= 1 then
						plr:sendData("SendMessage", `<b>Roles Management</b>: ` .. "Declined to assign "..tostring(#players).." player(s) to "..concatListedRoles, nil, 5, "Context")
						return
					end

					local assignedRoles = {}
					local concatAssignedRoles = ''
					for i,listedRole in pairs(listedRoles) do
						-- Ignore admin roles
						if not table.find(adminRoles, listedRole) then
							for d,target in pairs(players) do
								if not listedRole:checkTempMember(target) and not listedRole:checkMember(target) then
									listedRole:assign({
										Type = "Players";
										List = {target.UserId};
										Temp = true;
										Given = true;
									})
									
									if saveInData then
										local pData = target:getPData()
										local savedRoles = pData.__savedRoles
										local didFindRoleName = savedRoles._find(listedRole.name)
										
										if not didFindRoleName then
											pData._tableAddToSet("savedRoles", listedRole.name)
											--table.insert(savedRoles, listedRole.name)
											--savedRoles._recognize()
											--task.defer(function()
											--	savedRoles._reviveIfDead()
											--end)
										end
									end

									server.Events.memberAddedInRole:fire(target, listedRole, false, plr)
								end
							end

							table.insert(assignedRoles, listedRole)
						end
					end

					for i,givenRole in pairs(assignedRoles) do
						if i == #assignedRoles then
							if #assignedRoles > 1 then
								concatAssignedRoles = concatAssignedRoles.." & <b>"..Parser:filterForRichText(givenRole.name).."</b>"
							else
								concatAssignedRoles = concatAssignedRoles.." <b>"..Parser:filterForRichText(givenRole.name).."</b>"
							end
						else
							concatAssignedRoles = concatAssignedRoles.."<b>"..Parser:filterForRichText(givenRole.name).."</b>, "
						end
					end

					if #assignedRoles > 0 then
						plr:sendData("SendMessage", `<b>Roles Management</b>: ` .. "Assigned "..tostring(#players).." player(s) to "..concatAssignedRoles, nil, 5, "Context")
						for i, target in pairs(players) do
							target:makeUI("NotificationV2", {
								title = `Role Management`;
								description = `{plr:toStringDisplayForPlayer(target)} assigned you to {#assignedRoles} non-administrator role(s) {if saveInData then `permanently` else `temporarily`}: {concatAssignedRoles}` ..
									`\n\n<i>Note: If you are assigned to the specified roles with dynamic/fixed enlistments in developer settings, the temporary/pdata-permanent status will not affect your assignment.</i>`;
							})
						end
					end
					

					if #adminRoles > 0 then
						local confirmChoice2 = plr:customGetData(10+30, "MakeUI", "ConfirmationV2", {
							title = "Role Management Confirmation";
							description = "Warning! You are giving "..tostring(#players).." access to <font color=\"#de5252\"><b>administrator roles</b></font> such as "..concatAdminRoles..". Are you sure you would perform this action?";
							firstChoice = {
								label = "Yes, I confirm.";
								submissionPage = {
									title = "Role Management Confirmed";
									duration = 2;
								}
							};
							secondChoice = {
								label = "No";
								submissionPage = {
									title = "Role Management Canceled";
									duration = 5;
								}
							};
							returnChoice = true;
							timeDuration = 10;
						})

						if confirmChoice2 ~= 1 then
							plr:sendData("SendMessage", `<b>Roles Management</b>: ` .. "Declined to assign "..tostring(#players).." player(s) to "..concatAdminRoles, nil, 5, "Context")
						else
							for i,adminRole in pairs(adminRoles) do
								for d,target in pairs(players) do
									if not adminRole:checkTempMember(target) then
										adminRole:assign({
											Type = "Players";
											List = {target.UserId};
											Temp = true;
											Given = true;
										})
										
										if saveInData then
											local pData = target:getPData()
											local savedRoles = pData.__savedRoles
											local didFindRoleName = savedRoles._find(adminRole.name)

											if not didFindRoleName then
												pData._tableAddToSet("savedRoles", adminRole.name)
												--table.insert(savedRoles, adminRole.name)
												--savedRoles._recognize()
												--task.defer(function()
												--	savedRoles._reviveIfDead()
												--end)
											end
										end

										server.Events.memberAddedInRole:fire(target, adminRole, true, plr)
									end
								end
							end
							
							plr:sendData("SendMessage", `<b>Roles Management</b>: ` .. "Assigned "..tostring(#players).." player(s) to "..concatAdminRoles, nil, 5, "Context")
							
							for i, target in pairs(players) do
								target:makeUI("NotificationV2", {
									title = `Role Management`;
									description = `{plr:toStringDisplayForPlayer(target)} assigned you to {#adminRoles} administrator role(s) {if saveInData then `permanently` else `temporarily`}: <font color=\"#de5252\">{concatAdminRoles}</font>` ..
										`\n\n<i>Note: If you are assigned to the specified roles with dynamic/fixed enlistments in developer settings, the temporary/pdata-permanent status will not affect your assignment.</i>`;
								})
							end
						end
					end
				else
					plr:sendData("SendMessage", `<b>Roles Management</b>: ` .. "There are no specified assignable roles to give to "..tostring(#players).." player(s)", nil, 5, "Context")
				end
			end;
		};

		removePlayersFromRoles = {
			Prefix = settings.actionPrefix;
			Aliases = {"remplayersfromroles"};
			Arguments = {
				{
					type = "players";
					argument = "players";
					required = true;
					allowFPCreation = true;
				};
				{
					type = "trueOrFalse";
					argument = "saveFromData";
					required = true;
				};	
				{
					type = "list";
					argument = "rolenames";
					required = true;
				};	
			};
			Permissions = {"Manage_Players"};
			Roles = {};

			PlayerCooldown = 5;

			Description = "Removes players from specific roles";

			Function = function(plr, args)
				local players = args[1]
				local availableRoles = {}
				local highPriority = Roles:getHighestPriority(plr)
				local saveFromData = args[2]
				
				for i,role in pairs(Roles:getAll()) do
					if role.assignable and role.priority < highPriority then
						table.insert(availableRoles, role)
					end
				end
				
				if saveFromData then
					local canSaveRoles = Moderation.checkAdmin(plr) or Roles:hasPermissionFromMember(plr, {"Manage_Roles"})
					if not canSaveRoles then
						plr:sendData("SendMessage", "Role Management failed", "You must have permission <b>Manage_Roles</b> to remove saved player roles.", 5, "Hint")
						return
					end

					--local filterList; filterList = function()
					--	for i, targetedRole in ipairs(availableRoles) do
					--		if (not targetedRole.saveable and saveFromData) or not saveFromData then
					--			table.insert(failedToSaveRoles, "<b>"..Parser:filterForRichText(targetedRole.name).."</b>")
					--			table.remove(availableRoles, i)
					--			filterList()
					--		end
					--	end
					--end

					--filterList()
					
				end

				local listedRoles = {}
				local concatListedRoles = ''
				local concatFSRoles = ''
				local failedToSaveRoles = {}
				
				for i,givenName in pairs(args[3]) do
					for d,avRole in pairs(availableRoles) do
						if (givenName:lower()=="all" or avRole.name:sub(1,#givenName):lower() == givenName:lower()) and not table.find(listedRoles, avRole) then
							if not avRole.saveable and saveFromData then
								table.insert(failedToSaveRoles, avRole.name)
								continue
							end
							table.insert(listedRoles, avRole)
						end
					end
				end
				
				if #concatFSRoles > 6 then
					concatFSRoles = #concatFSRoles.." roles"
				else
					concatFSRoles = table.concat(failedToSaveRoles, ", ")
				end
				
				if #failedToSaveRoles > 0 then
					plr:sendData("SendMessage", "Role Management failed", concatFSRoles.." doesn't have the option 'saveable' enabled. You cannot remove these saved roles", 5, "Hint")
					if #availableRoles == 0 then
						return
					end
				end

				for i,givenRole in pairs(listedRoles) do
					if i == #listedRoles then
						if #listedRoles > 1 then
							concatListedRoles = concatListedRoles.." & <b>"..givenRole.name.."</b>"
						else
							concatListedRoles = concatListedRoles.." <b>"..givenRole.name.."</b>"
						end
					else
						concatListedRoles = concatListedRoles..givenRole.name..", "
					end
				end

				if #listedRoles > 0 then
					local confirmChoice1 = plr:makeUIGet("Confirmation", {
						title = "Role Management confirmation";
						desc = "Are you sure you would like to unassign "..tostring(#players).." player(s) from "..concatListedRoles.."?";
						choiceA = "Yes, I confirm.";
						returnOutput = true;
						time = 15;
					})

					if confirmChoice1 ~= 1 then
						plr:sendData("SendMessage", "Role Management failed", "Declined to unassign "..tostring(#players).." player(s) from "..concatListedRoles, 5, "Hint")
						return
					end

					for i,listedRole in pairs(listedRoles) do
						for d,target in pairs(players) do
							if listedRole:checkTempMember(target) then
								for permInd,perm in pairs(listedRole.members) do
									if type(perm) == "table" and perm.Temp and table.find(perm.List or {}, target.UserId) then
										listedRole.members[permInd] = nil
										if saveFromData then
											local pData = target:getPData()
											local savedRoles = pData.__savedRoles
											local didFindRoleName = savedRoles._find(listedRole.name)

											if didFindRoleName then
												pData._tableRemove("savedRoles", listedRole.name)
											end
										end
										server.Events.memberRemovedFromRole:fire(target, listedRole, plr)
									end
								end
							end
						end
					end

					plr:sendData("SendMessage", "Role Management success", "Unassigned "..tostring(#players).." player(s) from "..concatListedRoles, 5, "Hint")
					
					for i, target in pairs(players) do
						target:makeUI("NotificationV2", {
							title = `Role Management`;
							description = `{plr:toStringDisplayForPlayer(target)} unassigned you from {#listedRoles} role(s) {if saveFromData then `permanently` else `temporarily`}: {concatListedRoles}` ..
								`\n\n<i>Note: If you are assigned to the specified roles with dynamic/fixed enlistments in developer settings, the temporary/pdata-permanent status will not affect your assignment.</i>`;
						})
					end
				else
					plr:sendData("SendMessage", "Role Management error", "There are no specified roles to remove from "..tostring(#players).." player(s)", 5, "Hint")
				end
			end;
		};
		
		listRoles = {
			Prefix = settings.actionPrefix;
			Aliases = {"roleslist", "allroles"};
			Arguments = {};
			Permissions = {"Manage_Roles/Manage_Players"};
			Roles = {};

			Description = "Lists all the roles";

			Function = function(plr, args)
				local highPriority = Roles:getHighestPriority(plr)

				local priorityRoles1 = {}
				local priorityRoles2 = {}
				for i,role in pairs(Roles:getAll(true)) do
					local rolePriority = role.priority

					if not role.hiddenfromlist and (not role.hidelistfromlowranks or rolePriority <= highPriority) then
						table.insert(priorityRoles1, role)
					end

					--if rolePriority < highPriority then
					--	priorityRoles1[role] = rolePriority
					--	table.insert(availableRoles, role.name)
					--else
					--	table.insert(availableRoles, "🔒 "..role.name)
					--end
				end

				table.sort(priorityRoles1, function(a,b)
					return a.priority > b.priority
				end)

				for roleInd, role in ipairs(priorityRoles1) do
					local rolePriority = role.priority

					if rolePriority <= highPriority or role.allowlowrankstoviewlist then
						local memberCount = 0
						local checkedUserIds = {}
						local membersList = {}
						for i,otherPlr in ipairs(service.getPlayers(true)) do
							if role:checkMember(otherPlr) then
								memberCount += 1
								checkedUserIds[otherPlr.UserId] = true
								
								if role:checkTempMember(otherPlr) then
									local pData = otherPlr:getPData()
									local savedRoles = pData.__savedRoles
									local isRoleDataSaved = savedRoles._find(role.name)
									
									table.insert(membersList, {
										type = "Label";
										label = `> {if isRoleDataSaved then "🏢" else "🔖"} {tostring(otherPlr)} / {otherPlr.UserId}`;
										labelColor = Color3.fromRGB(185, 216, 27);
									})
								else
									table.insert(membersList, {
										type = "Label";
										label = `> {tostring(otherPlr)} / {otherPlr.UserId}`;
										labelColor = Color3.fromRGB(185, 216, 27);
									})
								end
							end
						end
						
						table.insert(priorityRoles2, {
							type = "Detailed";
							label = `{if rolePriority==highPriority then "🔸 " else ""}({tostring(role.priority or 0)}) <b>{Parser:filterForRichText(role.name)}</b> ({memberCount})`;
							labelColor = role.permissions["Manage_Game"] and Color3.fromRGB(255, 174, 44) or nil;
							description = "Assignable: "..tostring(role.assignable and true or false).." | Saveable: "..tostring(role.saveable and true or false);
							richText = true;
							hideSymbol = true;
						})
						
						local function checkOfflineUser(entryData, isTemporary)
							local userId,userName;
							local entryDataType = type(entryData)
							
							if entryDataType == "number" then
								userId = entryData
								userName = service.playerNameFromId(entryData)
							end
							
							if entryDataType == "string" and not string.match(entryData, "^(.+):(.+)") then
								userId = service.playerIdFromName(entryData)
								userName = entryData
							end

							if (userId and userId > 0) and userName and not checkedUserIds[userId] then
								checkedUserIds[userId] = true
								table.insert(membersList, {
									type = "Label";
									label = `> {if isTemporary then "🔖 " else ""}{Identity.getDisplayName(userId)} (@{userName} / {userId}`;
									labelColor = Color3.fromRGB(152, 152, 152);
								})
							end
						end
						
						if not role.hideofflineplayers then
							for i, entryData in ipairs(role.members) do
								if type(entryData) == "number" or type(entryData) == "string" then
									checkOfflineUser(entryData)
									
									if type(entryData) == "string" then
										
									end
								elseif type(entryData) == "table" then
									if entryData.Type == "Users" or entryData.Type == "Players" then
										for d, entry in ipairs(entryData.List) do
											checkOfflineUser(entry, entryData.Temp)
										end
									end
									
									if entryData.Type == "Group" then
										
									end
								end
							end
						end
						
						for i, memberName in ipairs(membersList) do
							if type(memberName) == "table" then
								table.insert(priorityRoles2, memberName)
							else
								table.insert(priorityRoles2, {
									type = "Label";
									label = "> "..memberName;
									labelColor = Color3.fromRGB(221, 221, 221);
								})
							end
						end
					else
						table.insert(priorityRoles2, {
							type = "Label";
							label = "🔒 "..role.name;
							labelColor = Color3.fromRGB(204, 115, 42);
						})
					end
					
					if roleInd < #priorityRoles1 then
						table.insert(priorityRoles2, {
							type = "Label";
							label = "---------";
						})
					end
				end

				plr:makeUI("List", {
					Title = "E. Roles";
					List = priorityRoles2;
				})
			end;
		};
	}
	
	for cmdName,cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
