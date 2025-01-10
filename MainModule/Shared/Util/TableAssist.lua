--!nonstrict
--TODO: When to use this?

local TableAssist = {}
TableAssist.prototype = {}
TableAssist.__index = TableAssist.prototype

local _rawlen = rawlen
	or function(tab: { [any]: any }): number
		local count: number = 0
		for i, v in ipairs(tab) do
			count += 1
		end
		return count
	end

local _isTableAListOf = function(tab: { [any]: any }, valueType: string): boolean
	local isValid = true

end

function TableAssist.prototype:at(): number return _rawlen(self.linkedTable) end

function TableAssist.prototype:concat(otherTableAssist): number return _rawlen(self.linkedTable) end

return TableAssist
