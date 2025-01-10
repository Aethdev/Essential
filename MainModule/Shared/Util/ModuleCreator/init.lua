--!nocheck

local Init = {}
local table = table

setfenv(1, setmetatable({}, { __metatable = "The metatable is locked" }))

function Init:Create(oneVariable: any)
	if table.isfrozen(Init) then return end
	Init.Variable = oneVariable
	Init.Created = true
	Init.Create = nil
end

function Init:Run()
	local Var = Init.Variable
	Init.Ran = true
	Init.Variable = nil
	table.freeze(Init)
	return Var
end

return Init
