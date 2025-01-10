local policyManager = {}
policyManager._playerPolicies = {}

local server, service, getEnv, settings = nil
local cloneTable, getRandom = nil
local luaParser, tulirAES, hashLib, base64, base64Encode, base64Decode, compression

local BOOL_TRUE = true
local BOOL_FALSE = false
local BOOL_EMPTY = nil
local DEFAULT_CLIENT_POLICIES = {
	MINIMIZED_TOPBARICONS = BOOL_FALSE;
	HIDDEN_PLAYERS = {};
	INCOGNITO_PLAYERS = {};
	USE_COMMANDS = BOOL_TRUE;
	CMD_KEYBINDS_ALLOWED = BOOL_TRUE;
	SHORTCUTS_ALLOWED = BOOL_TRUE;
	ALIASES_ALLOWED = BOOL_TRUE;
	CONSOLE_ALLOWED = BOOL_TRUE;
	TARGETSELECTORS_ONLYSELF = BOOL_FALSE;
	TARGETSELECTORS_ALLOWLIST = {};
	TARGETSELECTORS_IGNORELIST = {};
	TRUSTED_CODE_SIGNATURES = {};
	IGNORE_INCOGNITO_PLAYERS = BOOL_FALSE;
	OVERRIDE_INCOGNITO_MODE = BOOL_EMPTY;
	--MINIMIZED_TOPBARICONS = BOOL_TRUE;
}
local GLOBAL_CLIENT_POLICIES = { -- OVERRIDES OTHER POLICIES
	
}

local function trimString(str: string): string
	return string.match(str, "^%s*(.-)%s*$")
end

function policyManager:getClientPolicies(player: ParsedPlayer)
	return service.symbolicTable(self:_getClientPolicies(player), nil, true)
end


function policyManager:_getClientPolicies(player: ParsedPlayer)
	if self._playerPolicies[player.UserId] then return self._playerPolicies[player.UserId] end

	local inheritedPolicies = setmetatable({}, {
		__index = function(self, index)
			if GLOBAL_CLIENT_POLICIES[index] ~= nil then
				return {
					type = "GLOBAL";
					value = GLOBAL_CLIENT_POLICIES[index];
				}
			end
			
			return {
				type = "DEFAULT";
				value = nil;
			}
		end;
	})
	self._playerPolicies[player.UserId] = inheritedPolicies
	
	-- SET DEFAULT POLICIES FOR THE FIRST TIME
	for policyName, policyValue in DEFAULT_CLIENT_POLICIES do
		inheritedPolicies[policyName:upper()] = {
			type = "DEFAULT";
			value = policyValue;
		}
	end
	
	for policyName, policyValue in GLOBAL_CLIENT_POLICIES do
		inheritedPolicies[policyName:upper()] = {
			type = "DEFAULT";
			value = policyValue;
		}
	end
	
	self:_updateClientPolicies(player, inheritedPolicies)
	
	return inheritedPolicies
end

function policyManager:getPolicyFromPlayer(player: ParsedPlayer, policyName: string)
	return self:_getClientPolicies(player)[policyName]
end

function policyManager:_updateClientPolicies(player: ParsedPlayer, inheritedPolicies: {[string]: string|boolean|{[any]: any}}?)
	inheritedPolicies = inheritedPolicies or self:_getClientPolicies(player)
	
	policyManager:_updatePlayerDataClientPolicies(player)
	policyManager:_updateDynamicClientPolicies(player)
	
	return policyManager
end

function policyManager:_updatePlayerDataClientPolicies(player: ParsedPlayer, inheritedPolicies: {[string]: string|boolean|{[any]: any}}?)
	inheritedPolicies = inheritedPolicies or self:_getClientPolicies(player)
	
	task.spawn(function()
		local playerPData = player:getPData()
		
		policyManager
			:setPoliciesForPlayer(player, {
				{"USE_COMMANDS", not playerPData.systemBlacklist, `PLAYERDATA`, true};
			})
	end)
	
	return policyManager
end

function policyManager:_updateDynamicClientPolicies(player: ParsedPlayer, inheritedPolicies: {[string]: string|boolean|{[any]: any}}?)
	inheritedPolicies = inheritedPolicies or self:_getClientPolicies(player)
	
	policyManager
		:setPoliciesForPlayer(player, {
			{"MINIMIZED_TOPBARICONS", if settings.minimizedPlayerView then not server.Roles:hasPermissionFromMember(player, {"Use_Utility"}) else DEFAULT_CLIENT_POLICIES.MINIMIZED_TOPBARICONS, "DYNAMIC"};
			{"CONSOLE_ALLOWED", if settings.consoleEnabled then (settings.consolePublic==true or server.Roles:hasPermissionFromMember(player, {"Use_Console", "Manage_Game"}, true)) else DEFAULT_CLIENT_POLICIES.CONSOLE_ALLOWED, "DYNAMIC"};
			{"IGNORE_INCOGNITO_PLAYERS", server.Moderation.checkAdmin(player) and true or false, "DYNAMIC"};
		})

	return policyManager
end

function policyManager:setPolicyForPlayer(player: ParsedPlayer, policyName: string, value: string|boolean|{[any]: any}|nil, enforcementType: string?)
	assert(type(policyName) == "string" and trimString(policyName:upper()) == policyName, `Policy name {tostring(policyName)} is not valid`)
	assert(type(value) == "string" or type(value) == "boolean" or type(value) == "table" or type(value) == "nil", `Policy value must be a string/boolean/table/nil`)
	assert((type(enforcementType) == "string" and trimString(enforcementType:upper()) == enforcementType) or type(enforcementType) == "nil", `Enforcement type must be a string/nil`)
	assert(GLOBAL_CLIENT_POLICIES[policyName] == nil, `Unable to enforce policy {policyName} for this player {tostring(player)} due to a current global policy`)
	assert(enforcementType ~= `GLOBAL`, `Enforcement type is not allowed as GLOBAL`)
	
	if type(value) == "table" then
		assert(not service.isTableCircular(value), `Policy value is circular`)
		value = service.cloneTable(value)
	end
	 
	local inheritedPolicies = self:_getClientPolicies(player)
	
	if not (inheritedPolicies[policyName] and inheritedPolicies[policyName].value == value) then
		inheritedPolicies[policyName] = {
			type = if enforcementType then enforcementType:upper() else `MANDATORY`;
			value = value;
		}
		
		if player:isVerified() then
			self.networkPolicyChanged:fireToSpecificPlayers({player}, policyName, value, if enforcementType then enforcementType:upper() else `MANDATORY`)
		end
	end
	
	return policyManager
end

function policyManager:setPoliciesForPlayer(player: ParsedPlayer, listOfPolicies: {[number]: {policyName: string, policyValue: string|boolean|{[any]: any}|nil, enforcementType: string?}})
	local isPlayerVerified = player:isVerified()
	local inheritedPolicies = self:_getClientPolicies(player)
	
	local appliedPolicies = {}
	
	for i, policyInfo in listOfPolicies do
		local policyName, value, enforcementType, onlyChangeWithMatchingEnforcement = policyInfo[1], policyInfo[2], policyInfo[3], policyInfo[4]
		
		assert(type(policyName) == "string" and trimString(policyName:upper()) == policyName, `Policy name is not valid`)
		assert(type(value) == "string" or type(value) == "boolean" or type(value) == "table" or type(value) == "nil", `Policy value must be a string/boolean/table/nil`)
		assert((type(enforcementType) == "string" and trimString(enforcementType:upper()) == enforcementType) or type(enforcementType) == "nil", `Enforcement type must be a string/nil`)
		assert(enforcementType ~= `GLOBAL`, `Enforcement type is not allowed as GLOBAL`)
		
		if GLOBAL_CLIENT_POLICIES[policyName] ~= nil then
			if server.Studio then warn(`An attempt occurred in PolicyManager bulk change to modify a policy over the overriden policy.`) end
			continue
		end
		
		policyName = trimString(policyName:upper())
		if type(value) == "table" then
			assert(not service.isTableCircular(value), `Policy value is circular`)
			value = service.cloneTable(value)
		end
		
		if not (inheritedPolicies[policyName] and inheritedPolicies[policyName].value == value) and (not onlyChangeWithMatchingEnforcement or inheritedPolicies[policyName].type ==  enforcementType) then
			appliedPolicies[policyName] = {
				type = if enforcementType then enforcementType else `MANDATORY`;
				value = value;
			}
			inheritedPolicies[policyName] = appliedPolicies[policyName]
		end
	end
	
	self.networkPolicyChanged:fireToSpecificPlayers({player}, `_BULK_`, appliedPolicies)

	return policyManager
end

function policyManager:setPolicyForPlayers(players: {[number]: ParsedPlayer}, policyName: string, value: string|boolean|{[any]: any}|nil, enforcementType: string?)
	for i, target in players do
		self:setPolicyForPlayer(target, policyName, value, enforcementType)
	end
	
	return policyManager
end

function policyManager:setPoliciesForPlayers(players: {[number]: ParsedPlayer}, listOfPolicies: {[number]: {policyName: string, policyValue: string|boolean|{[any]: any}|nil, enforcementType: string?}})
	for i, target in players do
		self:setPoliciesForPlayer(target, listOfPolicies)
	end

	return policyManager
end

function policyManager:setDefaultPolicy(policyName: string, value: string|boolean|{[any]: any}|nil)
	assert(type(policyName) == "string" and trimString(policyName:upper()) == policyName, `Policy name is not valid`)
	assert(type(value) == "string" or type(value) == "boolean" or type(value) == "table" or type(value) == "nil", `Policy value must be a string/boolean/table/nil`)
	
	if DEFAULT_CLIENT_POLICIES[policyName] ~= value then
		DEFAULT_CLIENT_POLICIES[policyName] = value
		
		for userId, playerPolicies in self._playerPolicies do
			local parsedPlayer = server.Parser:apifyPlayer(service.getPlayer(userId))
			local policyInfo = playerPolicies[policyName]
			
			if policyInfo.type == "DEFAULT" then
				policyInfo.value = value
				
				if parsedPlayer then
					self.networkPolicyChanged:fireToSpecificPlayers({parsedPlayer}, policyName, value, `DEFAULT`)
				end
			end
		end
	end
end

function policyManager:setGlobalPolicy(policyName: string, value: string|boolean|{[any]: any}|nil)
	assert(type(policyName) == "string" and trimString(policyName:upper()) == policyName, `Policy name is not valid`)
	assert(type(value) == "string" or type(value) == "boolean" or type(value) == "table" or type(value) == "nil", `Policy value must be a string/boolean/table/nil`)

	if GLOBAL_CLIENT_POLICIES[policyName] ~= value then
		GLOBAL_CLIENT_POLICIES[policyName] = value

		for userId, playerPolicies in self._playerPolicies do
			local parsedPlayer = server.Parser:apifyPlayer(service.getPlayer(userId))
			local policyInfo = playerPolicies[policyName]

			policyInfo.type = `GLOBAL`
			policyInfo.value = value

			if parsedPlayer then
				self.networkPolicyChanged:fireToSpecificPlayers({parsedPlayer}, policyName, value, `GLOBAL`)
			end
		end
	end
end

function policyManager:crossUpdatePlayerPolicy(playerOrUserId: ParsedPlayer|number, policyName: string, value: string|boolean|{[any]: any}|nil)
	assert(type(policyName) == "string" and trimString(policyName:upper()) == policyName, `Policy name is not valid`)
	assert(type(value) == "string" or type(value) == "boolean" or type(value) == "table" or type(value) == "nil", `Policy value must be a string/boolean/table/nil`)
	assert(server.Parser:isParsedPlayer(playerOrUserId) or (type(playerOrUserId) == "number" and math.floor(playerOrUserId) == playerOrUserId and playerOrUserId > 0), `Player must be specified`)
	
	if server.Parser:isParsedPlayer(playerOrUserId) then
		playerOrUserId = playerOrUserId.UserId
	end
	
	server.Cross.send(`UpdatePlayerPolicy`, playerOrUserId, policyName, value)
end

function policyManager:crossUpdateGlobalPolicy(policyName: string, value: string|boolean|{[any]: any}|nil)
	assert(type(policyName) == "string" and trimString(policyName:upper()) == policyName, `Policy name is not valid`)
	assert(type(value) == "string" or type(value) == "boolean" or type(value) == "table" or type(value) == "nil", `Policy value must be a string/boolean/table/nil`)

	server.Cross.send(`UpdateGlobalPolicy`, policyName, value)
end

function policyManager:setup()
	local networkSession = server.Remote.newSession()
	networkSession.easyFind = true
	networkSession.name = "PolicyManager"
	networkSession.allowedTriggers = {"@everyone"}
	
	local networkRetrievePolicies = networkSession:makeCommand(`GetPolicies`, function(plr)
		return policyManager:_getClientPolicies(plr)
	end)
	networkRetrievePolicies.canInvoke = true
	networkRetrievePolicies.canFire = false
	networkRetrievePolicies.allowedTriggers = {"@everyone"}
	
	local networkPolicyChanged = networkSession:makeEvent(`PolicyChanged`)
	networkPolicyChanged.allowedTriggers = {"@everyone"}
	networkPolicyChanged.canFire = false
	networkPolicyChanged.canConnect = true
	
	policyManager.networkSession = networkSession
	policyManager.networkRetrievePolicies = networkRetrievePolicies
	policyManager.networkPolicyChanged = networkPolicyChanged
	
	-- SET UP CROSS MESSAGING
	
	server.Cross.commands.UpdatePlayerPolicy = function(jobId: string, userId: number, policyName: string, value: string|boolean|{[any]: any}|nil)
		if GLOBAL_CLIENT_POLICIES[policyName] ~= nil then return end
		
		local playerPolicies = policyManager:_getClientPolicies({UserId = userId})
		local parsedPlayer = server.Parser:apifyPlayer(service.getPlayer(userId))
		
		
		if parsedPlayer then
			policyManager:setPolicyForPlayer(parsedPlayer, policyName, value, `CROSS`)
		else
			playerPolicies[policyName] = {
				type = "CROSS";
				value = value;
			}
		end
	end
	
	server.Cross.commands.UpdateGlobalPolicy = function(jobId: string, policyName: string, value: string|boolean|{[any]: any}|nil)
		if GLOBAL_CLIENT_POLICIES[policyName] ~= nil then return end

		policyManager:setGlobalPolicy(policyName, value)
	end
	
	return policyManager
end

--TODO: Insert entry in policy

function policyManager.Init(env: {[any]: any}): boolean
	server = env.server
	service = env.service
	getEnv = env.getEnv
	cloneTable = service.cloneTable
	getRandom = service.getRandom
	settings = server.Settings
	warn = env.warn
	
	luaParser = server.LuaParser
	base64 = server.Base64
	tulirAES = server.TulirAES
	hashLib = server.HashLib

	base64Encode = base64.encode
	base64Decode = base64.decode
	
	compression = server.Compression
	
	return true
end

return policyManager