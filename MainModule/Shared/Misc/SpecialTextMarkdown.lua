return table.freeze{
	{"Timestamp", {"t:(%d+)", "t:(%d+):(%a+)"}, function(textMatches: {[number]: string}, textSettings: {startedSince: number}, parser)
		local timestampOption = if textMatches[2] == "st" then "shorttime"
			elseif textMatches[2] == "lt" then "longtime"
			elseif textMatches[2] == "sd" then "shortdate"
			elseif textMatches[2] == "ld" then "longdate"
			elseif textMatches[2] == "sdt" then "shortdatetime"
			elseif textMatches[2] == "ldt" then "longdatetime"
			elseif textMatches[2] == "rt" or textMatches[2] == "rtnp" then "relativetime"
			else "longdatetime"
		
		local text;
		
		if timestampOption == "relativetime" then
			text = parser:relativeTimestamp(tonumber(textMatches[1]), textMatches[2] == "rtnp")
		else
			text = parser:osDate(tonumber(textMatches[1]), "*t", timestampOption)
		end
		
		if textSettings.richText then
			return `<font color='#0088f0'>{text}</font>`
		end
		
		return text
	end};
	
	{"CustomReplacements", {"%$(%w+)"}, function(textMatches: {[number]: string}, textSettings: {startedSince: number}, parser)
		local customReplacements = textSettings.customReplacements
		
		if customReplacements then
			return tostring(customReplacements[textMatches[1]] or "-unknown-")
		end

		return 0
	end};
	
	{"Tag-IfStatement", {"if"}, function(textMatches: {[number]: string}, textSettings: {startedSince: number}, parser)
		local customReplacements = textSettings.customReplacements

		if customReplacements then
			return tostring(customReplacements[textMatches[1]] or "-unknown-")
		end

		return 0
	end};
}