
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
	
	local cmdsList; cmdsList = {
		createDex = {
			Prefix = settings.actionPrefix;
			Aliases = {"dex"};
			Arguments = {};
			Permissions = settings.dexAccessPerms or {"Manage_Game_Explorer"};
			Roles = settings.dexAccessRoles or {};
			
			Description = "Opens dex explorer";
			PlayerCooldown = 10;
			PlayerDebounce = true;
			NoPermissionsBypass = true;
			NoDisableAndEnable = true;
			
			Function = function(plr, args)
				if server.dexNetwork and server.dexSession then
					if not (server.dexNetwork.connectedPlayers[plr] and server.dexNetwork:getPlayerKey(plr)) then
						server.dexNetwork.connectedPlayers[plr] = true
						server.dexNetwork:createPlayerKey(plr)
						plr:sendData("SendMessage", "Successfully connected you to dex network. Now creating Dex. <i>This may take a while..</i>", nil, 8, "Context")
						local dexCode = plr:getData("OpenDex")
						if dexCode == -1 then
							plr:sendData("SendMessage", "Your dex UI has already been made. Oops!", nil, 4, "Context")
						elseif dexCode == -2 or dexCode == -3 then
							plr:sendData("SendMessage", "Dex creation ran in a roadblock due to network/session unauthorization. Failed to initiate. (error code: "..tostring(dexCode)..")", nil, 4, "Context")
						else
							plr:sendData("SendMessage", "Your dex UI has successfully been created.", nil, 6, "Context")
						end
					else
						plr:sendData("SendMessage", "You've already connected to the dex network. No need to connect again.", nil, 5, "Context")
					end
				else
					cmdsList.createDex.Disabled = true
					cmdsList.createDex.NoDisableAndEnable = true
					cmdsList.removeDex.Disabled = true
					cmdsList.removeDex.NoDisableAndEnable = true
					plr:sendData("SendMessage", "Dex network or/and session are missing. Unable to create dex without them.", nil, 8, "Context")
				end
			end;
		};
		
		removeDex = {
			Prefix = settings.actionPrefix;
			Aliases = {"removedex"};
			Arguments = {
				{
					argument = 'players';
					type = "players";
					required = true;
				};
			};
			Permissions = settings.dexAccessPerms or {"Manage_Game_Explorer"};
			Roles = settings.dexAccessRoles or {};

			Description = "Removes dex explorer from specified players (process can take 1-5 minutes)";
			ServerCooldown = 8;
			NoPermissionsBypass = true;
			NoDisableAndEnable = true;
			
			Function = function(plr, args)
				if server.dexNetwork and server.dexSession then
					local successPlrs = {}
					local dexNetwork = server.dexNetwork
					
					for i, target in pairs(args[1]) do
						if dexNetwork.connectedPlayers[target] then
							local targetKey = dexNetwork:getPlayerKey(target)
							
							if not targetKey then
								dexNetwork.connectedPlayers[target] = nil
							else
								if targetKey:isActive() and not targetKey.onDexRemoval then
									targetKey.onDexRemoval = true
									
									local function startDelayTask()
										task.delay(30-math.min(os.time()-targetKey.verifiedSince, 30), function()
											plr:sendData("DeleteDex")
											targetKey.expireOs = os.time()+80
										end)
										dexNetwork.connectedPlayers[target] = nil
									end
									
									if targetKey:isVerified() then
										startDelayTask()
									else
										targetKey.verified:connectOnce(startDelayTask)
									end
								end
							end
							--dexNetwork.connectedPlayers[target] = nil
							table.insert(successPlrs, tostring(target))
						end
					end
					
					if #successPlrs > 0 then
						plr:sendData("SendMessage", "Successfully removed dex from "..(#successPlrs <= 4 and table.concat(successPlrs, ", ") or #successPlrs.." players."), nil, 8, "Context")
					else
						plr:sendData("SendMessage", "There was no targets to remove dex.", nil, 4, "Context")
					end
				else
					cmdsList.createDex.Disabled = true
					cmdsList.createDex.NoDisableAndEnable = true
					cmdsList.removeDex.Disabled = true
					cmdsList.removeDex.NoDisableAndEnable = true
					plr:sendData("SendMessage", "Dex network or/and session are missing. Unable to delete dex without them.", nil, 8, "Context")
				end
			end;
		};
	}
	
	for cmdName,cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
