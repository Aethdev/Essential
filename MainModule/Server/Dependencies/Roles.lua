local roles = {}
roles.assignedMembers = {}

local listedRoles = {}
--TODO: CACHE DYNAMIC ROLES

local rolePermissions = {
	-- ADVANCED PERMS

	Manage_Server = false,
	Manage_Game = false,
	Manage_Roles = false,

	-- UTILITY

	Use_Utility = false,
	Use_Donor_Perks = true,
	Mention_Roles = false,
	Use_Fun_Commands = false,
	Use_Console = false,
	Bypass_Chat_Slowmode = false,
	View_Logs = false,
	Send_Polls = false,
	HandTo_Utility = false,
	Hide_Incognito = false,

	-- FUN

	Use_External_Gears = false,

	-- MODERATION

	Kick_Player = false,
	Ban_Player = false,
	Mute_Player = false,
	Warn_Player = false,
	Deafen_Player = false,
	Manage_Map = false,
	Private_Messaging = false,
	Message_Commands = false,
	Manage_Characters = false,
	Help_Assistance = false,
	Manage_Game_Servers = false,
	Manage_Camera = false,

	-- ADMINISTRATION

	Manage_Players = false,
	Manage_Bans = false,
	Ignore_Command_Cooldown = false,
	Execute_Scripts = false,
	Script_Explicit_Safe = true,
	Use_External_Modules = false,

	Admin_Terminal = false,
	Cross_Commands = false,
	Manage_PlayerData_Transfer = false,

	Blacklisted_Script_Access = {
		["script"] = false,
		["newproxy"] = false,
	},
}

local adminPermsIgnore = {
	Script_Explicit_Safe = true,
	Blacklisted_Script_Access = true,
}

local function cloneTable(tab)
	local clone
	clone = function(val)
		if type(val) == "table" then
			local newVal = {}

			for i, v in pairs(val) do
				newVal[i] = clone(v)
			end

			return newVal
		else
			return val
		end
	end

	return clone(tab)
end

local server, service, variables

function roles:create(
	name: string,
	priority: number?,
	color: Color3?,
	members: { [any]: any }?,
	permList: { [any]: any }?
): { [any]: any }
	permList = (type(permList) == "table" and cloneTable(permList)) or {}
	members = (type(members) == "table" and cloneTable(members)) or {}

	if listedRoles[name] then
		return "ROLE_ALREADY_EXIST"
	else
		local Signal = (server and server.Signal) or {}
		local roleTab = {
			name = (type(name) == "string" and name) or "new role-" .. service.getRandom(15),
			id = service.getRandom(40),
			priority = (type(priority) == "number" and priority) or 0,
			members = {},
			color = (typeof(color) == "Color3" and color) or Color3.fromRGB(149, 165, 166),
			created = os.time(),
			permissions = cloneTable(rolePermissions),
			adminPermsIgnore = cloneTable(adminPermsIgnore),

			hiddenfromlist = false,
			hidelistfromlowranks = false,
			allowlowrankstoviewlist = false,
			hideofflineplayers = false,
			showchattag = false,

			mentionable = true, -- Permitted to mention this role? (ignore perm: Mention_Roles)
			assignable = false, -- Permitted to give role by players?
			destroyed = Signal.new(),
			memberAdded = Signal.new(),
			memberRemoved = Signal.new(),
		}

		if permList and type(permList) == "table" then
			for perm, bool in pairs(permList) do
				local boolType = type(bool)

				if boolType == "boolean" or boolType == "table" then
					local existPerm = roleTab.permissions[perm]

					if existPerm ~= nil then
						local ePermType = type(existPerm)

						if ePermType == "table" and boolType == "table" then
							for ind, val in pairs(bool) do
								if type(val) == "boolean" then existPerm[ind] = val end
							end
						elseif ePermType == "boolean" and boolType == "boolean" then
							roleTab.permissions[perm] = bool
						end
					end
				end
			end
		end

		if members and type(members) == "table" then
			for i, member in pairs(members) do
				local typ = type(member)

				if typ == "table" or typ == "string" or typ == "number" then table.insert(roleTab.members, member) end
			end
		end

		function roleTab:destroy()
			if self._destroyed then return end

			for i, member in pairs(self.members) do
				self.members[i] = nil
			end

			listedRoles[name] = nil
			self.permissions = {}
			self.destroyed:fire()
			self._destroyed = true
		end

		-- Aliases for destroy
		roleTab.kill = roleTab.destroy
		roleTab.remove = roleTab.destroy
		roleTab.delete = roleTab.destroy

		function roleTab:assign(member)
			if not table.find(self.members, member) then
				table.insert(self.members, member)
				self.memberAdded:fire(member)
			else
				return "ALREADY_ASSIGNED"
			end
		end

		function roleTab:tempAssignWithMemberId(memberId: number)
			local doesExist = (function()
				for i, member in pairs(self.members) do
					if type(member) == "table" then
						local memberTemp = rawget(member, "temp") or rawget(member, "Temp")

						if member.Type == "Player" and memberTemp and server.Identity.checkMatch(memberId, member) then
							return true
						end
					end
				end

				return false
			end)()

			if not doesExist then
				self:assign {
					Type = "Player",
					PlayerUserId = memberId,
					Temp = true,
				}
			end
		end

		function roleTab:tempUnAssignWithMemberId(memberId: number)
			local existData = (function()
				for i, member in pairs(self.members) do
					if type(member) == "table" then
						local memberTemp = rawget(member, "temp") or rawget(member, "Temp")

						if member.Type == "Player" and memberTemp and server.Identity.checkMatch(memberId, member) then
							return member
						end
					end
				end
			end)()

			if existData then self:unassign(existData) end
		end

		function roleTab:unassign(member)
			local foundMember = table.find(self.members, member)

			if foundMember then
				table.remove(self.members, foundMember)
				self.memberRemoved:fire(member)
			else
				return "ALREADY_UNASSIGNED"
			end
		end

		function roleTab:checkPermissions(perms)
			local permsType = type(perms)
			perms = (permsType == "table" and perms) or {}

			local check = true
			local checkList = {}

			if #perms > 0 then
				for ind, perm in pairs(perms) do
					if type(perm) == "string" then
						if not checkList[perm] and self:checkPermission(perm) then checkList[perm] = true end
					end
				end

				for ind, perm in pairs(perms) do
					if type(perm) == "string" then
						if not checkList[perm] then
							check = false
							break
						end
					end
				end

				return check
			end
		end

		function roleTab:checkPermission(perm)
			perm = (type(perm) == "string" and perm) or nil

			if perm then
				if self.permissions[perm] or (self.permissions["Manage_Game"] and not self.adminPermsIgnore[perm]) then
					return true
				else
					return false
				end
			end
		end
		roleTab.hasPermission = roleTab.checkPermission

		function roleTab:setPermission(perm, bool)
			if type(perm) == "string" and type(bool) == "boolean" then self.permissions[perm] = bool end
		end

		function roleTab:checkMember(member) return server.Identity.checkTable(member, self.members) end

		function roleTab:checkTempMember(tempMember)
			local temp = false

			for i, member in pairs(self.members) do
				if type(member) == "table" then
					local memberTemp = rawget(member, "temp") or rawget(member, "Temp")

					if memberTemp and server.Identity.checkMatch(tempMember, member) then
						temp = true
						break
					end
				end
			end

			return temp
		end

		function roleTab:getMemberCount() return #self.members end

		-- Add this role to the listed roles
		listedRoles[roleTab.name] = roleTab

		return roleTab
	end
end

function roles:get(name: string): { [any]: any }?
	if name then
		for i, role in pairs(listedRoles) do
			if rawequal(role.name, name) or rawequal(role.id, name) then return role end
		end
	end
end

function roles:getRolesFromColor(color: Color3): { [any]: any }
	if typeof(color) ~= "Color3" then return "Invalid_Color" end

	local results = {}

	for i, role in pairs(listedRoles) do
		if rawequal(role.color, color) then table.insert(results, role) end
	end

	return results
end

function roles:getRolesFromMember(member: any): { [any]: any }
	local list = {}

	for i, role in pairs(listedRoles) do
		if role:checkMember(member) then table.insert(list, role) end
	end

	return list
end

function roles:checkMemberInRoles(member: any, memberRoles: { [any]: any }, acceptOnlyOne: boolean?): boolean | table?
	memberRoles = (type(memberRoles) == "string" and { memberRoles })
		or (type(memberRoles) == "table" and memberRoles)
		or {}

	if #memberRoles > 0 then
		local checkList = {}

		for i, role in pairs(roles:getRolesFromMember(member)) do
			checkList[role.name] = true
		end

		local didPassCheckList = true
		local failChecklist = {}

		for i, memberRoleName in pairs(memberRoles) do
			if not checkList[memberRoleName] then
				if not acceptOnlyOne then
					for d, missingRole in pairs(memberRoles) do
						if not checkList[missingRole] then table.insert(failChecklist, missingRole) end
					end

					return false, failChecklist
				else
					table.insert(failChecklist, memberRoleName)
				end
			elseif checkList[memberRoleName] and acceptOnlyOne then
				return true
			end
		end

		if #failChecklist > 0 then
			return false, failChecklist
		else
			return true
		end
	end
end

function roles:getPermissionsFromMember(member: any): { [any]: any }
	local results = {}

	for i, role in pairs(roles:getRolesFromMember(member)) do
		for perm, bool in pairs(role.permissions) do
			if bool then results[perm] = true end
		end
	end

	return results
end

function roles:hasPermissionFromMember(member: any, perms: { [any]: any }, acceptAnyPermission: boolean?): boolean
	perms = (type(perms) == "table" and cloneTable(perms)) or {}

	local checkList = {}
	local permsLen = #perms

	for i, role in pairs(roles:getRolesFromMember(member)) do
		for d, perm in pairs(perms) do
			if checkList[perm] then continue end

			local permFindSlash = string.find(perm, "/")

			if permFindSlash then
				for subPerm in string.gmatch(perm, "[^/]+") do
					if role:checkPermissions { subPerm } then
						checkList[perm] = true

						if acceptAnyPermission then return true end

						break
					end
				end
			else
				if not checkList[perm] and role:checkPermissions { perm } then checkList[perm] = true end
			end
		end
	end

	local didChecked = (function()
		for d, perm in pairs(perms) do
			local permFindSlash = string.find(perm, "/")

			if not checkList[perm] then return false end
		end

		return true
	end)()

	if #perms > 0 and didChecked then
		return true
	else
		return false,
			(function()
				local notChecked = {}

				for i, perm in pairs(perms) do
					if not checkList[perm] then table.insert(notChecked, perm) end
				end

				return notChecked
			end)()
	end
end
roles.hasPermissionsFromMember = roles.hasPermissionFromMember

function roles:getHighestPriorityFromPermission(member: any, rolePerm: string): number
	local latestPriority = 0

	for i, role in pairs(roles:getRolesFromMember(member)) do
		if role:checkPermissions { rolePerm } and role.priority > latestPriority then latestPriority = role.priority end
	end

	return latestPriority
end

function roles:getHighestPriority(member: any): number
	local latestPriority = 0

	for i, role in pairs(roles:getRolesFromMember(member)) do
		if role.priority > latestPriority then latestPriority = role.priority end
	end

	return latestPriority
end

function roles:getHighestRoleFromMember(member: any): Role?
	local rolesList = roles:getRolesFromMember(member)
	local highestPriority = -1
	local highestRole = nil

	for i, role in ipairs(rolesList) do
		if role.priority > highestPriority then
			highestPriority = role.priority
			highestRole = role
		end
	end

	return highestRole
end

function roles:getTemporaryRolesFromMember(member: any)
	local list = {}

	for i, role in roles:getAll() do
		if role:checkTempMember(member) then table.insert(list, role) end
	end

	return list
end

function roles:getAll(cloneList: boolean?): { [any]: any }
	local list = {}

	for i, v in pairs(listedRoles) do
		list[i] = (cloneList and service.cloneTable(v)) or (not cloneList and v) or nil
	end

	return list
end

function roles:getDefaultPermissions(): { [any]: any } return cloneTable(rolePermissions) end

function roles.Init(env)
	server = env.server
	service = env.service
	variables = env.variables

	-- Create "@everyone" role. THIS ROLE MUST NOT BE DELETED TO PREVENT BUGS AND ISSUES WITH CORES AND OTHER COMPONENTS
	local everyoneRole = roles:create("everyone", 0, nil, { "@everyone" })
	everyoneRole.mentionable = false

	local creatorRole = roles:create("creator", math.huge, nil, {
		(game.CreatorId <= 0 and "@everyone")
			or (game.CreatorType == Enum.CreatorType.Group and "Group:" .. game.CreatorId .. ":255")
			or game.CreatorId,
	}, {
		Manage_Game = true,
	})
	creatorRole.mentionable = true
	creatorRole.hiddenfromlist = true

	local donorRole = roles:create("donor", 0.5, nil, {
		"Membership:Donator",
	})
	donorRole.mentionable = true
	donorRole.hiddenfromlist = true

	if variables.privateServerData and variables.privateServerData.creatorId > 0 then
		local serverHostRole = roles:create("esserverHost", 1, nil, { variables.privateServerData.creatorId }, {
			Use_Utility = true,
		})
		serverHostRole.mentionable = true
		serverHostRole.hiddenfromlist = true
	end
end

roles.defaultPerms = rolePermissions

return roles
