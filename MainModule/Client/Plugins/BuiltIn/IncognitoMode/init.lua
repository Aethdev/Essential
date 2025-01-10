
return function(envArgs)
	local type, math = type, math
	local mathFloor = math.floor
	
	local client = envArgs.client
	local service = envArgs.service
	local variables = envArgs.variables
	local loadModule = envArgs.loadModule
	local getEnv = envArgs.getEnv
	local script = envArgs.script

	local Remote = client.Remote
	local UI = client.UI
	local Network = client.Network
	
	local Kill = client.Kill
	local Signal = client.Signal
	
	local localPlayer = service.player
	
	client.Policies:connectPolicyChangeEvent(`HIDDEN_PLAYERS`, function(policyValue: boolean, enforcementType: string)
		if type(policyValue) == "table" then
			for i, userId in policyValue do
				local targetPlayer: Player = service.getPlayer(userId)
				if targetPlayer and localPlayer ~= targetPlayer then
					targetPlayer.Parent = nil
				end
			end
		end
	end)
	
	client.Policies:connectPolicyChangeEvent(`INCOGNITO_PLAYERS`, function(policyValue: boolean, enforcementType: string)
		if type(policyValue) == "table" then
			for i, userId in policyValue do
				local targetPlayer: Player = service.getPlayer(userId)
				if targetPlayer and localPlayer ~= targetPlayer then
					targetPlayer.Parent = nil
					
					client.Utility.Tracking:stopTrackingPlayer(targetPlayer.UserId)
				end
			end
		end
	end)
end