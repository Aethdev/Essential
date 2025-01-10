
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

	local Parser = server.Parser
	local Roles = server.Roles
	local Filter = server.Filter
	local Utility = server.Utility
	
	local Signal = server.Signal
	
	--local allowedTransferIndexes = {
	--	aliases = true;
	--	customCmdAliases = true;
	--	cmdKeybinds = true;
	--	messages = true;
	--	shortcuts = true;
	--	clientSettings = true;
	--	activityLogs = true;
	--}
	local blockedDeleteAndTransferIndexes = {
		joined = true;
		serverData = true;
		banCase = true;
		banInfo = true;
		_transferredDataSince = true;
		_transferTo = true;
		_transferFrom = true;
	}
	
	local pDataTransferCooldown = 60*60*24*5 -- 5 days
	local pDataDeletionCooldown = 60*60*24 -- 1 day
	
	local cmdsList = {
		--downloadPData = {
		--	Disabled = not settings.playerData_AllowTransfer;
		--	Prefix = settings.playerPrefix;
		--	Aliases = {"downloadpdata"};
		--	Arguments = {};
		--	Permissions = {"Use_Utility"};
		--	Roles = {};

		--	Description = "Downloads your player data";
		--	PlayerCooldown = 5;
		--	PlayerDebounce = true;

		--	Function = function(plr, args)
		--		plr:sendData("MakeUI", "ResponseEntry", {
		--			title = "PData Download";
		--			placement = server.LuaParser.Encode({plr:getPData()._table});
		--			resizeAllowed = true;	
		--		})
		--	end,
		--};
		
		startPDataTransfer = {
			Disabled = not settings.playerData_AllowTransfer;
			Prefix = settings.playerPrefix;
			Aliases = {"transferpdata"};
			Arguments = {
				{
					argument = "receiver";
					type = "players";
					required = true;
					ignoreSelf = true;
				};
			};
			Permissions = {"Use_Utility"};
			Roles = {};

			Description = "Prompts the specified player to transfer data with them";
			PlayerCooldown = 5;
			PlayerDebounce = true;

			Function = function(plr, args)
				local target = args[1][1]
				local targetPData = target:getPData()
				local playerPData = plr:getPData()
				
				local targetSData = targetPData.serverData
				local playerSData = playerPData.serverData
				
				plr:sendData("SendMessage",
					"To continue transferring your player data to another player, please agree to the one-time confirmation",
					nil, 5, "Context"
				)
				
				local allowedTransferIndexes = {}
				for i,v in pairs(playerPData._table) do
					if not blockedDeleteAndTransferIndexes[i] then
						allowedTransferIndexes[i] = true
					end
				end
				
				local checkConfirm = plr:customGetData(120+10, "MakeUI", "PrivateMessageV2", {
					title = "PData Transfer Confirmation";
					desc = `Agreement before transferring your player data`;
					bodyDetail = table.concat({
						"Upon transferring your player data, please note that the data below are only allowed for transfer:";
						(function()
							local list = {}
							for i,v in allowedTransferIndexes do
								table.insert(list, `- {i}`)
							end
							
							return table.concat(list, "\n")
						end)();
						`After the transfer of your player data, we will prohibit you from transferring and deleting your new player data.`;
						"<b>To confirm the transfer of your player data, please type in your full username (case-sensitive).</b>"
					}, "\n");
					--placement = plr.Name;
					onlyReturn = true;
					time = 120;
				})
				
				if checkConfirm ~= plr.Name then
					plr:sendData("SendMessage",
						`<b>PData Transfer</b>: Failed to transfer. You did not properly type in your username correctly or you had included spaces or extra symbols after/before your input.`,
						nil, 10, "Context"
					)
					return
				end
				
				local cleanPlayerPData = false
				local confirmClean = plr:customGetData(20+10, "MakeUI", "Confirmation", {
					title = "PData Transfer Confirmation";
					desc = `Would you like to clear your player data after transfer? <i>Please note that this action is irreversible.</i>`;
					choiceA = "Yes, I confirm.";
					returnOutput = true;
					time = 20;
				})
				
				if not plr:isInGame() then
					return
				elseif confirmClean == 1 then
					cleanPlayerPData = true
				end
				
				if targetSData._pDataTransfer or (targetPData._transferredDataSince and os.time()-targetPData._transferredDataSince < pDataTransferCooldown) then
					plr:sendData("SendMessage",
						`<b>PData Transfer</b>: Unable to initiate a transfer with {tostring(target)} if they are currently transferring player data with someone else or`..
							`their transfer has not reached the end of the cooldown.`,
						nil, 10, "Context"
					)
					return
				elseif (playerPData._transferredDataSince and os.time()-playerPData._transferredDataSince < pDataTransferCooldown) then
					plr:sendData("SendMessage",
						`<b>PData Transfer</b>: Unable to initiate a transfer. Your recent Player data transfer has not reached the end of the cooldown.`,
						nil, 10, "Context"
					)
					return
				elseif not target:isInGame() then
					plr:sendData("SendMessage",
						`<b>PData Transfer</b>: Unable to initiate a transfer with {tostring(target)}. They are not in the server.`,
						nil, 10, "Context"
					)
					return
				end
				
				plr:sendData("SendMessage",
					`<b>PData Transfer</b>: Prompting {tostring(target)} to confirm your transfer with them..`,
					nil, 12, "Context"
				)
				
				target:sendData("SendMessage",
					`<b>PData Transfer</b>: Agree to the one-time confirmation if you wish to allow {plr:toStringDisplayForPlayer(target)}'s player data to merge with yours.`,
					nil, 12, "Context"
				)
				
				local checkTargetConfirm = target:customGetData(60+10, "MakeUI", "Confirmation", {
					title = "PData Transfer Confirmation";
					desc = `Would you allow {plr:toStringDisplayForPlayer(target)} to merge their player data with yours? <i>Please note that transfers cannot` ..
						` be undone unless overriden by an in-game administrator. Each transfer has a cooldown of {Parser:relativeTimestamp(os.time()+pDataTransferCooldown)}.</i>`;
					choiceA = "Yes, I confirm.";
					returnOutput = true;
					time = 60;
				})
				
				if checkTargetConfirm ~= 1 or not target:isInGame() then
					plr:sendData("SendMessage",
						`<b>PData Transfer</b>: {tostring(target)} has declined your transfer request.`,
						nil, 12, "Context"
					)
					return
				end
				
				playerSData._pDataTransfer = true
				targetSData._pDataTransfer = true
				
				plr:sendData("SendMessage",
					`<b>PData Transfer</b>: Transferring your player data to {tostring(target)}..`,
					nil, 12, "Context"
				)
				
				local savedRoles = playerPData.savedRoles or {}
				local importedContents = {}
				
				for i,v in pairs(allowedTransferIndexes) do
					importedContents[i] = playerPData[i]
				end
				
				for i, v in pairs(importedContents) do
					targetPData[i] = v
				end
				
				if cleanPlayerPData then
					for i,v in pairs(playerPData._table) do
						playerPData[i] = nil
					end
					
					local defaultData = Core.defaultPlayerData()
					for i, v in pairs(defaultData) do
						playerPData[i] = v
					end
				end
				
				if #savedRoles > 0 then
					for i, role in pairs(Roles:getTemporaryRolesFromMember(plr)) do
						if role.saveable and table.find(savedRoles, role.name) then
							role:tempUnAssignWithMemberId(plr.UserId)
							role:tempAssignWithMemberId(target.UserId)
						end
					end
				end
				
				local transferOs = os.time()
				playerPData._transferTo = target.UserId
				playerPData._transferFrom = nil
				playerPData._transferredDataSince = transferOs
				targetPData._transferTo = nil
				targetPData._transferFrom = plr.UserId
				targetPData._transferredDataSince = transferOs
				
				task.delay(30, function()
					playerSData._pDataTransfer = false
					targetSData._pDataTransfer = false
				end)
				
				plr:sendData("SendMessage",
					`<b>PData Transfer</b>: Successfully transferred your player data to {tostring(target)}. Rejoin the server to see the changes.`,
					nil, 6, "Context"
				)
				
				plr:sendData("MakeUI", "NotificationV2", {
					title = "Player Data Transfer";
					desc = `You recently transferred your player data to {target:toStringDisplayForPlayer(plr)}. `
						.. `Keep in mind that some important data like the date of your player data transfer are not erasable nor transferrable.`;
					highPriority = true;
					priorityLevel = math.huge;
					allowInputClose = false;
					time = 30;
				})
				
				target:sendData("SendMessage",
					`<b>PData Transfer</b>: Successfully merged your player data from {tostring(plr)}'s player data. Rejoin the server to see the changes.`,
					nil, 6, "Context"
				)
				
				target:sendData("MakeUI", "NotificationV2", {
					title = "Player Data Transfer";
					desc = `You recently transferred your player data to {plr:toStringDisplayForPlayer(target)}. `
						.. `Keep in mind that some important data like the date of your player data transfer are not erasable nor transferrable.`;
					highPriority = true;
					priorityLevel = math.huge;
					allowInputClose = false;
					time = 30;
				})
			end;
		};
		
		viewTransferInfo = {
			Disabled = not settings.playerData_AllowTransfer;
			Prefix = settings.actionPrefix;
			Aliases = {"viewtransferpdata"};
			Arguments = {
				{
					argument = "user";
					type = "players";
					required = true;
					allowFPCreation = true;
				};
			};
			Permissions = {"Manage_Players/Manage_Game"; "Manage_PlayerData_Transfer";};
			Roles = {};

			Description = "Views the pData transfer data of the specified player (offline usernames are supported)";
			PlayerCooldown = 5;
			PlayerDebounce = true;

			Function = function(plr, args)
				local target = args[1][1]
				local targetPData = target:getPData()
				
				if not targetPData._transferredDataSince then
					plr:sendData("SendMessage",
						`<b>PData Transfer</b>: Unable to view transferred pData from {tostring(target)}. They may not have transferred their player data yet.`,
						nil, 5, "Context"
					)
					return
				end
				
				local transferToName = targetPData._transferTo and service.playerNameFromId(targetPData._transferTo) or "[not available]"
				local transferFromName = targetPData._transferFrom and service.playerNameFromId(targetPData._transferFrom) or "[not available]"
				
				local targetInfo = {
					"<b>Transfer Details</b>";
					`To: {transferToName} ({tostring(targetPData._transferTo or "0")})`;
					`From: {transferFromName} ({tostring(targetPData._transferFrom or "0")})`;
					``;
					`Started since <i>{Parser:osDate(targetPData._transferredDataSince)} UTC</i>`;
				}
				
				plr:makeUI("PrivateMessageV2", {
					title = target.Name.."'s transfer PData information";
					desc = "";
					message = table.concat(targetInfo, "\n");
					readOnly = true;
				})
			end;
		};
		
		forcePDataTransfer = {
			Disabled = not settings.playerData_AllowTransfer;
			Prefix = settings.actionPrefix;
			Aliases = {"forcetransferpdata"};
			Arguments = {
				{
					argument = "user";
					type = "players";
					required = true;
					allowFPCreation = true;
				};
				{
					argument = "receiver";
					type = "players";
					required = true;
				};
			};
			Permissions = {"Manage_Players/Manage_Game"; "Manage_PlayerData_Transfer";};
			Roles = {};

			Description = "Forces user to merge player data with the target (Requires Manage_Game role permission to select offline users)";
			PlayerCooldown = 5;
			PlayerDebounce = true;

			Function = function(plr, args)
				local user = args[1][1]
				local target = args[2][1]
				local targetPData = target:getPData()
				local userPData = user:getPData()

				local targetSData = targetPData.serverData
				local userSData = userPData.serverData
				
				local creatorRole = Roles:get("creator")
				local isPlayerCreator = creatorRole:checkMember(plr)

				local canIgnorePriorityCheck = isPlayerCreator or Roles:hasPermissionsFromMember(plr, {"Manage_Game"})
				local allowOfflineUser = isPlayerCreator or canIgnorePriorityCheck
				
				if user.UserId == target.UserId then
					plr:sendData("SendMessage",
						"PData Transfer requires a different user and a different target to initiate process.",
						nil, 5, "Context"
					)
					return
				else
					local userPriority = Roles:getHighestPriority(user)
					local targetPriority = Roles:getHighestPriority(target)
					
					if not isPlayerCreator and (creatorRole:checkMember(user) or creatorRole:checkMember(target)) then
						plr:sendData("SendMessage",
							"PData Transfer cannot forcibly initiate if the user or target is a creator (unless you're a creator).",
							nil, 5, "Context"
						)
						return
					elseif not user:isInGame() and not allowOfflineUser then
						plr:sendData("SendMessage",
							"PData Transfer cannot forcibly initiate if the user is not in the server.",
							nil, 5, "Context"
						)
						return
					elseif not canIgnorePriorityCheck and userPriority >= targetPriority then
						plr:sendData("SendMessage",
							`PData Transfer cannot forcibly initiate (due to your lack of admin permission) if user {tostring(user)} has a higher/equal priority to {tostring(target)}. Confirmation has been requested to the user and target.`,
							nil, 5, "Context"
						)
						
						local userReadySignal, targetReadySignal = Signal.new(), Signal.new()
						local userResp, targetResp = nil, nil;
						
						for i, selector in {target, user} do
							task.spawn(function()
								local checkAgree = selector:customGetData(20+10, "MakeUI", "Confirmation", {
									title = "PData Transfer Confirmation";
									desc = `Are you sure you would like merge player data with {tostring(if selector == target then user else target)}'s player data?` ..
										` <i>This action is irreversible</i>.`;
									choiceA = "Yes, I confirm.";
									returnOutput = true;
									time = 20;
								})
								
								;(selector == target and targetReadySignal or userReadySignal):fire(checkAgree)
							end)
						end
						
						Signal:waitOnMultipleEvents({userReadySignal, targetReadySignal}, nil, 30+10)
						
						if not (userResp == 1 and targetResp == 1) then
							plr:sendData("SendMessage",
								`PData Transfer failed to initate if either {tostring(target)} or {tostring(user)} declines to merge.`,
								nil, 5, "Context"
							)
							return
						end
					end
				end
				
				local checkConfirm = plr:customGetData(20+10, "MakeUI", "Confirmation", {
					title = "PData Transfer Confirmation";
					desc = `Are you sure you would like merge {tostring(user)}'s player data with {tostring(target)}'s player data?` ..
						` <i>This action is irreversible</i>.`;
					choiceA = "Yes, I confirm.";
					returnOutput = true;
					time = 20;
				})

				if checkConfirm ~= 1 then
					plr:sendData("SendMessage",
						"PData Transfer confirmation was canceled upon your request.",
						nil, 5, "Context"
					)
					return
				end

				local cleanPlayerPData = false
				local confirmClean = plr:customGetData(20+10, "MakeUI", "Confirmation", {
					title = "PData Transfer Confirmation";
					desc = `Would you like to clear {tostring(user)}'s player data after transfer? <i>Please note that this action is irreversible.</i>`;
					choiceA = "Yes, I confirm.";
					returnOutput = true;
					time = 20;
				})

				if not plr:isInGame() then
					return
				elseif confirmClean == 1 then
					cleanPlayerPData = true
				end
				
				if not ((user:isInGame() or allowOfflineUser) and target:isInGame()) then
					plr:sendData("SendMessage",
						`<b>PData Transfer</b>: The user or the target has left the server. Unable to merge player data.`,
						nil, 5, "Context"
					)
					return
				end

				if targetSData._pDataTransfer or userSData._pDataTransfer then
					plr:sendData("SendMessage",
						`<b>PData Transfer</b>: Unable to initiate a transfer from {tostring(user)} to {tostring(target)} if one of them is currently transferring player data with someone else.`,
						nil, 10, "Context"
					)
					return
				end

				userSData._pDataTransfer = true
				targetSData._pDataTransfer = true

				plr:sendData("SendMessage",
					`<b>PData Transfer</b>: Transferring {tostring(user)}'s player data to {tostring(target)}..`,
					nil, 12, "Context"
				)

				local importedContents = {}
				local savedRoles = userPData.savedRoles or {}
				
				local allowedTransferIndexes = {}
				for i,v in pairs(targetPData._table) do
					if not blockedDeleteAndTransferIndexes[i] then
						allowedTransferIndexes[i] = true
					end
				end
				
				for i,v in pairs(allowedTransferIndexes) do
					importedContents[i] = userPData[i]
				end

				for i, v in pairs(importedContents) do
					targetPData[i] = v
				end

				if cleanPlayerPData then
					for i,v in pairs(userPData._table) do
						userPData[i] = nil
					end

					local defaultData = Core.defaultPlayerData()
					for i, v in pairs(defaultData) do
						userPData[i] = v
					end
				end
				
				if #savedRoles > 0 then
					for i, role in pairs(Roles:getTemporaryRolesFromMember(user)) do
						if role.saveable and table.find(savedRoles, role.name) then
							role:tempUnAssignWithMemberId(user.UserId)
							role:tempAssignWithMemberId(target.UserId)
						end
					end
				end

				local transferOs = os.time()
				userPData._transferTo = target.UserId
				userPData._transferFrom = nil
				userPData._transferredDataSince = transferOs
				targetPData._transferTo = nil
				targetPData._transferFrom = user.UserId
				targetPData._transferredDataSince = transferOs
				
				task.delay(30, function()
					userSData._pDataTransfer = false
					targetSData._pDataTransfer = false
				end)

				user:sendData("SendMessage",
					`<b>PData Transfer</b>: An in-game administrator, {tostring(plr)}, has transferred your player data to {tostring(target)}.`
						..`Rejoin to see the new changes.`,
					nil, 10, "Context"
				)
				target:sendData("SendMessage",
					`<b>PData Transfer</b>: An in-game administrator, {tostring(plr)}, has merged your player data with {tostring(user)}.`
						..`Rejoin to see the new changes.`,
					nil, 10, "Context"
				)
				plr:sendData("SendMessage",
					`<b>PData Transfer</b>: Successfully merged {tostring(user)}'s player data with {tostring(target)}.`,
					nil, 10, "Context"
				)
			end;
		};
		
		clearSelfPlayerData = {
			Prefix = settings.playerPrefix;
			Aliases = {"clearpdata"; "deletemydata"};
			Arguments = {};
			Permissions = {"Use_Utility"};
			Roles = {};

			Description = "[GDPR Compliance] You are allowed to clear your player data upon your request with this command";
			PlayerCooldown = 5;
			PlayerDebounce = true;

			Function = function(plr, args)
				local pData = plr:getPData()
				
				if pData.serverData._pDataTransfer or (pData._transferredDataSince and os.time()-pData._transferredDataSince < pDataTransferCooldown) then
					plr:sendData("SendMessage",
						`<b>PData Deletion</b>: You recently transferred your player data or currently in a process of transferring your player data with someone else. Unable to delete your player data.`,
						nil, 10, "Context"
					)
					return
				elseif pData.serverData._pDataDeletion or (pData._deletedDataSince and os.time()-pData._deletedDataSince < pDataDeletionCooldown) then
					plr:sendData("SendMessage",
						`<b>PData Deletion</b>: You recently deleted your player data or in the process of pData deletion.`,
						nil, 10, "Context"
					)
					return
				end
				
				local allowedTransferIndexes = {}
				for i,v in pairs(pData._table) do
					allowedTransferIndexes[i] = true
				end
				
				local confirmWaitTime = 120
				local response = plr:customGetData(confirmWaitTime+10, "MakeUI", "PrivateMessageV2", {
					title = "PData Deletion Confirmation";
					desc = `Agreement before resetting your player data`;
					bodyDetail = table.concat({
						"Upon deleting your player data, please note that the data below will be cleared and reset to the default:";
						(function()
							local list = {}
							for i,v in allowedTransferIndexes do
								if not blockedDeleteAndTransferIndexes[i] then
									table.insert(list, `- {i}`)
								end
							end
							return table.concat(list, "\n")
						end)();
						"<i>+ other hidden data..</i>";
						"On the other hand, the data below is not allowed for transfer nor deletion and will remain in your current player data:";
						(function()
							local list = {}
							for i,v in blockedDeleteAndTransferIndexes do
								table.insert(list, `- {i}`)
							end
							return table.concat(list, "\n")
						end)();
						"";
						`After the clearance of your player data, we will prohibit you from transferring and deleting your new player data.`;
						"<b>To confirm the deletion of your player data, please type in your full username (case-sensitive).</b>"
					}, "\n");
					--placement = plr.Name;
					onlyReturn = true;
					time = confirmWaitTime;
				})
				
				if response ~= plr.Name then
					plr:sendData("SendMessage",
						`<b>PData Deletion</b>: Failed to confirm. You did not properly type in your username correctly or you had included spaces or extra symbols after/before your input.`,
						nil, 10, "Context"
					)
					return
				end
				
				local deletedOs = os.time()
				
				local defaultData = Core.defaultPlayerData()
				for i, v in pairs(pData._table) do
					if not blockedDeleteAndTransferIndexes[i] then
						pData[i] = nil
					end
				end
				for i, v in pairs(defaultData) do
					if not blockedDeleteAndTransferIndexes[i] then
						pData[i] = v
					end
				end
				
				pData._transferTo = nil
				pData._transferFrom = nil
				pData._transferredDataSince = deletedOs
				pData._deletedDataSince = deletedOs
				
				plr:sendData("SendMessage",
					`<b>PData Deletion</b>: Successfully deleted your player data`,
					nil, 10, "Context"
				)
				
				plr:sendData("MakeUI", "NotificationV2", {
					title = "Player Data Clearance";
					desc = `You recently deleted your player data. Keep in mind that some important data like the date of your player data transfer are not erasable nor transferrable.`;
					highPriority = true;
					priorityLevel = math.huge;
					allowInputClose = false;
					time = 30;
				})
				
				task.delay(30, function()
					pData.serverData._pDataDeletion = false
					pData.serverData._pDataTransfer = false
				end)
			end;
		};
	}

	for cmdName,cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end