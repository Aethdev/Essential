local parser = {}
local client, getEnv, message

local _knownQuoteCharacters = { '"', "'" }

type getArgumentsFilterTemplate = {
	maxArguments: number?,
	reduceDelimiters: boolean?,

	ignoreQuotes: boolean?,
	includeQuotesInArgs: boolean?,
	includeDelimiter: boolean?,
	debugInfo: boolean?,
}

local defaultGetArgumentsFilterOptions: getArgumentsFilterTemplate = {
	ignoreQuotes = false,
	includeQuotesInArgs = false,
	includeDelimiter = false,
	debugInfo = false,
}

function parser:getArguments(str: string, delimiter: string, filterOptions: getArgumentsFilterTemplate): { [any]: any }
	delimiter = delimiter or " "

	if not filterOptions then filterOptions = defaultGetArgumentsFilterOptions end

	if utf8.len(str) == 0 then return {} end
	if table.find(_knownQuoteCharacters, delimiter) and not filterOptions.ignoreQuotes then
		error("Delimiter contains one of the known quote characters", 0)
	end

	local results = {}
	--local splitedArgs = string.split(str, delimiter)

	--for i,part in pairs(splitedArgs) do
	--	if #part > 0 then
	--		local trimmedPart = parser:trimString(part)

	--		if #trimmedPart > 0 then -- Make sure the trimmed string doesn't have nothing like ""
	--			table.insert(results, trimmedPart)
	--		end
	--	end
	--end
	local currentArg = ""
	local argumentInQuote = ""
	local targetQuoteChar = ""
	local inQuotationArg, inDelimiter = false, false
	local useDebugInfo = filterOptions.debugInfo
	local includeDelimiter = filterOptions.includeDelimiter
	local reduceDelimiters = filterOptions.reduceDelimiters
	local maxArguments = if filterOptions.maxArguments then math.max(filterOptions.maxArguments, 1) else math.huge

	local delimiterMatchCount = 0
	local delimiterLen = utf8.len(delimiter)
	local stringLen = utf8.len(str)

	local _numOfRealMatches = 0
	local lastIndexOfRealMatch = 0
	local canMergeArguments = function() return maxArguments <= _numOfRealMatches end
	local function addResultToTable(matchResult: string, isDelimiter: boolean, startIndex: number, endIndex: number)
		if isDelimiter and (not filterOptions.includeDelimiter and not canMergeArguments()) then return end

		if canMergeArguments() then
			local lastResult

			for i = #results, 1, -1 do
				if i == lastIndexOfRealMatch then lastResult = results[i] end
			end

			if lastResult and useDebugInfo then
				lastResult.match = lastResult.match .. matchResult
				lastResult.endIndex = endIndex
				lastResult.matchLength = utf8.len(lastResult.match .. matchResult)
				return
			elseif lastResult and not useDebugInfo then
				results[lastIndexOfRealMatch] = lastResult .. matchResult
				return
			end
		end

		if not isDelimiter then
			_numOfRealMatches += 1
		end

		lastIndexOfRealMatch = #results + 1
		table.insert(
			results,
			if not useDebugInfo
				then matchResult
				else {
					startIndex = startIndex,
					endIndex = endIndex,
					match = matchResult,
					matchIndex = if isDelimiter then 0 else _numOfRealMatches,
					matchLength = utf8.len(matchResult),
					isDelimiter = isDelimiter,
				}
		)
	end

	local function checkForNextQuoteMatches(targetQuote: string, startLen: number): boolean
		if startLen > stringLen then return false end
		for i = startLen, stringLen, 1 do
			local char = str:sub(i, i)
			if char == targetQuote then
				local escapeCharCheckPrevious = string.byte(str:sub(i - 1, i - 1)) == 92
				if escapeCharCheckPrevious then continue end

				return true
			end
		end

		return false
	end

	local function checkNextDelimiterMatches(targetStr: string, startLen: number, customLen: number?): number
		if startLen > utf8.len(targetStr) then return 0 end
		local stringLen = customLen or utf8.len(targetStr)
		local subMatches = 0
		local checkMatches = 0
		local lastCharLine

		for i = startLen, stringLen, 1 do
			local char = targetStr:sub(i, i)
			--warn("Target char:", char)
			--warn("Checking delimiter match:", delimiter:sub(initialCount+1, initialCount+1))
			if char == delimiter:sub(subMatches + 1, subMatches + 1) then
				local escapeCharCheckPrevious = string.byte(targetStr:sub(i - 1, i - 1)) == 92
				if escapeCharCheckPrevious then
					lastCharLine = i
					break
				end

				subMatches += 1
				--warn(`Delimiter sub check match found: {initialCount}`)
				subMatches = subMatches % delimiterLen

				if subMatches == 0 then
					checkMatches += 1
				elseif i == stringLen and subMatches > 0 then
					lastCharLine = i - subMatches + 1
				end
			else
				lastCharLine = i - subMatches

				break
			end
		end

		if subMatches > 0 and not lastCharLine then lastCharLine = stringLen end

		--warn("Delimiter matches:", checkMatches)

		return checkMatches, lastCharLine
	end

	local maxLen = utf8.len(str)
	local startFromLastCharLine
	local startLen = 1

	for i = 1, maxLen, 1 do
		if startFromLastCharLine and i < startFromLastCharLine then continue end

		local char = str:sub(i, i)
		if
			not filterOptions.ignoreQuotes
			and table.find(_knownQuoteCharacters, char)
			and (#targetQuoteChar == 0 or targetQuoteChar == char)
		then
			local escapeCharCheckPrevious = string.byte(str:sub(i - 1, i - 1)) == 92
			if escapeCharCheckPrevious then
				if inQuotationArg then
					argumentInQuote = argumentInQuote:sub(1, utf8.len(argumentInQuote) - 1) .. char
				else
					currentArg = currentArg:sub(1, utf8.len(currentArg) - 1) .. char
				end
				continue
			end

			if inDelimiter then
				if includeDelimiter then
					if #currentArg > 0 and delimiterMatchCount >= delimiterLen then
						addResultToTable(currentArg, true, startLen, i - 1)
					end
				end

				startLen = i
				currentArg = ""
			end
			delimiterMatchCount = 0
			inDelimiter = false

			inQuotationArg = not inQuotationArg

			if inQuotationArg then
				targetQuoteChar = char
				if not checkForNextQuoteMatches(char, i + 1) and not filterOptions.includeQuotesInArgs then
					currentArg = currentArg .. char
				end
			else
				targetQuoteChar = ""
			end

			if #argumentInQuote > 0 then
				currentArg = currentArg .. argumentInQuote
				argumentInQuote = ""
			end

			if filterOptions.includeQuotesInArgs then currentArg = currentArg .. char end
		elseif char == delimiter:sub(delimiterMatchCount + 1, delimiterMatchCount + 1) and not inQuotationArg then
			--// Delimiters do not have an escape character check
			--local escapeCharCheckPrevious = string.byte(str:sub(i-1,i-1)) == 92
			--if escapeCharCheckPrevious then
			--	if inQuotationArg then
			--		argumentInQuote = argumentInQuote:sub(1, utf8.len(argumentInQuote)-1) .. delimiter:sub(1, delimiterMatchCount+1)
			--	else
			--		currentArg = currentArg:sub(1,utf8.len(currentArg)-1) .. delimiter:sub(1, delimiterMatchCount+1)
			--	end

			--	continue
			--end
			if not inDelimiter and #currentArg > 0 then addResultToTable(currentArg, inDelimiter, startLen, i - 1) end
			startLen = i

			if not inDelimiter and includeDelimiter then currentArg = "" end
			inDelimiter = true

			local futureMatches, lastCharLine = checkNextDelimiterMatches(str, i, stringLen)

			if futureMatches > 0 then
				if includeDelimiter or canMergeArguments() then
					currentArg = if reduceDelimiters then delimiter else string.rep(delimiter, futureMatches)
					addResultToTable(
						currentArg,
						inDelimiter,
						startLen,
						if lastCharLine then lastCharLine - 1 else stringLen
					)
				end

				currentArg = ""
				delimiterMatchCount = 0

				startFromLastCharLine = lastCharLine
				if not lastCharLine then break end
			else
				if includeDelimiter then currentArg = currentArg .. char end
				inDelimiter = false
				startFromLastCharLine = nil
				delimiterMatchCount = 0
			end

			--if currentArg ~= "" then
			--	addResultToTable(currentArg, inDelimiter, startLen, lastCharLine-1)
			--	currentArg = ""
			--	delimiterMatchCount = 0
			--end

			startLen = startFromLastCharLine or startLen + 1
		else
			delimiterMatchCount = 0
			if inDelimiter and includeDelimiter and #currentArg > 0 then
				addResultToTable(currentArg, inDelimiter, startLen, i - 1)
				startLen = i
				currentArg = ""
			end
			inDelimiter = false

			if inQuotationArg then
				local delimiterMatches, endOfDelimiterLine = checkNextDelimiterMatches(str, i)
				if delimiterMatches > 0 then
					argumentInQuote = argumentInQuote
						.. (if reduceDelimiters then delimiter else string.rep(delimiter, delimiterMatches))
					if not endOfDelimiterLine or endOfDelimiterLine == stringLen then
						if not includeDelimiter then argumentInQuote = "" end
					else
						startFromLastCharLine = endOfDelimiterLine
					end
				else
					argumentInQuote = argumentInQuote .. char
				end
			else
				currentArg = currentArg .. char
			end
		end
	end

	if inQuotationArg and #argumentInQuote > 0 then
		currentArg = currentArg .. argumentInQuote
		addResultToTable(currentArg, inDelimiter, startLen, maxLen)
		--table.insert(results, argumentInQuote)
	elseif currentArg ~= "" then
		addResultToTable(currentArg, inDelimiter, startLen, maxLen)
		--table.insert(results, currentArg)
	end

	if filterOptions.debugInfo then
		local resultsWithoutDelimiter = {}

		for i, result in
			results :: {
				[number]: {
					startIndex: number,
					endIndex: number,
					match: string,
					matchIndex: number,
					isDelimiter: boolean,
				},
			}
		do
			if not result.isDelimiter then resultsWithoutDelimiter[result.matchIndex] = result.match end
		end

		return results, resultsWithoutDelimiter, inQuotationArg
	end

	return results, inQuotationArg
end

function parser:getMaxArguments(
	str: string,
	delimiter: string,
	maxArguments: number,
	ignoreQuotes: boolean?,
	includeQuotesInArgs: boolean?
): { [any]: any }
	delimiter = delimiter or " "
	maxArguments = math.max(maxArguments or 0, 1)

	local stringArguments = parser:getArguments(str, delimiter, {
		ignoreQuotes = ignoreQuotes,
		includeQuotesInArgs = includeQuotesInArgs,
		maxArguments = maxArguments,
	})

	if #stringArguments > maxArguments then
		local lastArgument = stringArguments[maxArguments]
		for i = maxArguments + 1, #stringArguments, 1 do
			lastArgument = lastArgument .. delimiter .. stringArguments[i]
		end
		for i = maxArguments + 1, #stringArguments, 1 do
			stringArguments[i] = nil
		end
		stringArguments[maxArguments] = lastArgument
	end

	--local firstResults = {}
	--local secondResults = {}
	--local splitedArgs = string.split(str, delimiter)

	--for i,part in ipairs(splitedArgs) do
	--	if #part > 0 then
	--		local trimmedPart = string.match(part, "^%s*(.-)%s*$")

	--		if #trimmedPart > 0 then -- Make sure the trimmed string doesn't have nothing like ""
	--			table.insert(firstResults, trimmedPart)
	--		end
	--	end
	--end

	--local argumentLen = 0
	--for i, arg in ipairs(firstResults) do
	--	argumentLen += 1
	--	if argumentLen <= maxArguments then
	--		table.insert(secondResults, table.concat({table.unpack(firstResults, argumentLen, (argumentLen==maxArguments and #firstResults) or argumentLen)}, delimiter))
	--	end
	--	--table.concat({table.unpack(msgArguments, processArgLen, (processArgLen==argsCount and #msgArguments) or processArgLen)}, delimiter)
	--end

	--if #secondResults > maxArguments then
	--	secondResults[maxArguments+1] = table.concat({table.unpack(secondResults, maxArguments+1)}, delimiter)
	--end

	return stringArguments
end

function parser:getDuration(number)
	local justSecs = tonumber(number) or 0

	justSecs = math.clamp(justSecs, 0, math.huge)

	local years = math.floor(justSecs / 31556952)
	justSecs = justSecs - (years * 31556952)

	local months = math.floor(justSecs / 2629746)
	justSecs = justSecs - (months * 2629746)

	local weeks = math.floor(justSecs / 604800)
	justSecs = justSecs - (weeks * 604800)

	local days = math.floor(justSecs / 86400)
	justSecs = justSecs - (days * 86400)

	local hours = math.floor(justSecs / 3600)
	justSecs = justSecs - (hours * 3600)

	local minutes = math.floor(justSecs / 60)
	justSecs = justSecs - (minutes * 60)

	return {
		years = years,
		months = months,
		weeks = weeks,
		days = days,
		hours = hours,
		mins = minutes,
		secs = justSecs,
	}
end

function parser:getTime(seconds: number)
	local remaining = seconds

	local hours = math.floor(remaining / 3600)
	remaining = remaining - (hours * 3600)

	local mins = math.floor(remaining / 60)
	remaining = remaining - (mins * 60)

	remaining = math.floor(remaining)
	if remaining < 0 then remaining = 0 end

	return {
		hours = hours,
		mins = mins,
		secs = remaining,
	}
end

function parser:osDate(
	osTime: number,
	timezone: ("unix" | string)?,
	dateAndTimeFormat: "shorttime" | "longtime" | "shortdate" | "longdate" | "shortdatetime" | "longdatetime" | "relativetime" | nil
): string
	if dateAndTimeFormat == "relativetime" then return parser:relativeTimestamp(osTime) end

	local date = os.date(if timezone == "unix" then "!*t" else timezone or "*t", osTime or os.time())
	if not date then return `unknown` end

	local year, month, day, hour, minute, sec = date.year, date.month, date.day, date.hour, date.min, date.sec

	if hour < 10 then hour = `0{hour}` end
	if minute < 10 then minute = `0{minute}` end
	if sec < 10 then sec = `0{sec}` end

	local monthName = ({
		"January",
		"February",
		"March",
		"April",
		"May",
		"June",
		"July",
		"August",
		"September",
		"October",
		"November",
		"December",
	})[date.month]

	local weekDayName = ({
		"Sunday",
		"Monday",
		"Tuesday",
		"Wednesday",
		"Thursday",
		"Friday",
		"Saturday",
	})[date.wday]

	if dateAndTimeFormat == "shorttime" then
		return `{hour}:{minute}`
	elseif dateAndTimeFormat == "longtime" then
		return `{hour}:{minute}:{sec}`
	elseif dateAndTimeFormat == "shortdate" then
		return `{day}/{month}/{year}`
	elseif dateAndTimeFormat == "longdate" then
		return `{day} {monthName} {year}`
	elseif dateAndTimeFormat == "shortdatetime" then
		return `{day} {monthName} {year} {hour}:{minute}`
	elseif dateAndTimeFormat == "longdatetime" then
		return `{weekDayName} {day} {monthName} {year} {hour}:{minute}`
	else
		-- Default (longdatetime)
		return `{weekDayName} {day} {monthName} {year} {hour}:{minute}`
	end
end

function parser:relativeTime(timeInSeconds: number, simplifyTime: boolean?) --// Similar to discord's timestamp easy readability
	assert(type(timeInSeconds) == "number", `Time in seconds`)
	timeInSeconds = math.floor(math.max(timeInSeconds, 0))

	local remaining = timeInSeconds
	local years = math.floor(remaining / 31536000)
	remaining -= years * 31536000

	local months = math.floor(remaining / 2592000)
	remaining -= months * 2592000

	local weeks = math.floor(remaining / (86400 * 7))
	remaining -= weeks * (86400 * 7)

	local days = math.floor(remaining / 86400)
	remaining -= days * 86400

	local hours = math.floor(remaining / 3600)
	remaining -= hours * 3600

	local minutes = math.floor(remaining / 60)
	remaining -= minutes * 60

	local listToConcat = {}
	if years > 0 then
		if simplifyTime then return `{years}y` end
		table.insert(listToConcat, `{years} year{if years > 1 then "s" else ""}`)
	end
	if months > 0 then
		if simplifyTime then return `{months}mo` end
		table.insert(listToConcat, `{months} month{if months > 1 then "s" else ""}`)
	end
	if weeks > 0 then
		if simplifyTime then return `{weeks}w` end
		table.insert(listToConcat, `{weeks} week{if weeks > 1 then "s" else ""}`)
	end
	if days > 0 then
		if simplifyTime then return `{days}d` end
		table.insert(listToConcat, `{days} day{if days > 1 then "s" else ""}`)
	end
	if hours > 0 then
		if simplifyTime then return `{hours}h` end
		table.insert(listToConcat, `{hours} hour{if hours > 1 then "s" else ""}`)
	end
	if minutes > 0 then
		if simplifyTime then return `{minutes}m` end
		table.insert(listToConcat, `{minutes} minute{if minutes > 1 then "s" else ""}`)
	end
	if remaining > 0 then
		if simplifyTime then return `{remaining}s` end
		table.insert(listToConcat, `{remaining} second{if remaining > 1 then "s" else ""}`)
	else
		if simplifyTime then return `0s` end
		if #listToConcat == 0 then table.insert(listToConcat, `0 seconds`) end
	end

	return table.concat(listToConcat, ", ")
end

function parser:relativeTimestamp(osTime: number, removeIn: boolean?, simplifyTimestamp: boolean?) --// Similar to discord's timestamp easy readability
	local nowOsTime = os.time()
	local minuteInSeconds = 60
	local hourInSeconds = minuteInSeconds * 60
	local weekInSeconds = hourInSeconds * 24 * 7
	local dayInSeconds = hourInSeconds * 24
	local monthInSeconds = dayInSeconds * 30
	local yearInSeconds = dayInSeconds * 365

	local timeDifference = math.abs(nowOsTime - osTime)
	local behindTime = nowOsTime - osTime > 0

	if timeDifference == 0 then
		return "now"
	else
		if timeDifference >= yearInSeconds then
			local years = math.ceil(timeDifference / yearInSeconds)
			if simplifyTimestamp then return `{years}y` end
			return `{if not behindTime and not removeIn then "in " else ""}{years} year{if years > 1 then "s" else ""}{if behindTime
				then " ago"
				else ""}`
		elseif timeDifference >= monthInSeconds then
			local months = math.ceil(timeDifference / monthInSeconds)
			if simplifyTimestamp then return `{months}mo` end

			return `{if not behindTime and not removeIn then "in " else ""}{months} month{if months > 1 then "s" else ""}{if behindTime
				then " ago"
				else ""}`
		elseif timeDifference >= weekInSeconds then
			local weeks = math.ceil(timeDifference / weekInSeconds)
			if simplifyTimestamp then return `{weeks}w` end

			return `{if not behindTime and not removeIn then "in " else ""}{weekInSeconds} week{if weeks > 1
				then "s"
				else ""}{if behindTime then " ago" else ""}`
		elseif timeDifference >= dayInSeconds then
			local days = math.ceil(timeDifference / dayInSeconds)
			if simplifyTimestamp then return `{days}d` end

			return `{if not behindTime and not removeIn then "in " else ""}{days} day{if days > 1 then "s" else ""}{if behindTime
				then " ago"
				else ""}`
		elseif timeDifference >= hourInSeconds then
			local hours = math.ceil(timeDifference / hourInSeconds)
			if simplifyTimestamp then return `{hours}h` end

			return `{if not behindTime and not removeIn then "in " else ""}{hours} hour{if hours > 1 then "s" else ""}{if behindTime
				then " ago"
				else ""}`
		elseif timeDifference >= minuteInSeconds then
			local minutes = math.ceil(timeDifference / minuteInSeconds)
			if simplifyTimestamp then return `{minutes}m` end

			return `{if not behindTime and not removeIn then "in " else ""}{minutes} minute{if minutes > 1
				then "s"
				else ""}{if behindTime then " ago" else ""}`
		else
			if simplifyTimestamp then return `{timeDifference}s` end

			return `{if not behindTime and not removeIn then "in " else ""}{timeDifference} second{if timeDifference
					> 1
				then "s"
				else ""}{if behindTime then " ago" else ""}`
		end
	end
end

function parser:formatTime(hours, mins, secs)
	if hours and not (mins or secs) then
		local timeData = parser:getTime(hours)
		hours, mins, secs = timeData.hours, timeData.mins, timeData.secs
	end

	hours = hours % 24
	hours = (hours < 10 and "0" .. hours) or tostring(hours)
	mins = (mins < 10 and "0" .. mins) or tostring(mins)
	secs = (secs < 10 and "0" .. secs) or tostring(secs)

	return hours .. ":" .. mins .. ":" .. secs
end

function parser:trimString(str: string): string return string.match(string.match(str, "^%s*(.-)%s*$"), "^\9*(.-)\9*$") end

function parser:trimStringForTabSpaces(str: string): string return string.match(str, "^\9*(.-)\9*$") end

function parser:filterForRichText(text)
	return parser:filterStringWithDictionary(text, {
		{ "&", "&amp;" },
		{ "<", "&lt;" },
		{ ">", "&gt;" },
		{ '"', "&quot;" },
		{ "'", "&apos;" },
	})

	--return parser:replaceStringWithDictionary(text, {
	--	["<"] 		= "&lt;";
	--	[">"] 		= "&gt;";
	--	["&"] 		= "&amp;";
	--	["\""]		= "&quot;";
	--	["'"]		= "&apos;";
	--})
end

function parser:filterForSpecialTags(text: string): string
	return parser:filterStringWithDictionary(text, {
		{ "{{", "&dlb;" },
		{ "}}", "&drb;" },
	})

	--return parser:replaceStringWithDictionary(text, {
	--	["<"] 		= "&lt;";
	--	[">"] 		= "&gt;";
	--	["&"] 		= "&amp;";
	--	["\""]		= "&quot;";
	--	["'"]		= "&apos;";
	--})
end

function parser:filterForStrPattern(text: string): string
	local strResults = {}
	local specialChars = { "(", ")", "%", ".", "+", "-", "*", "[", "]", "?", "^", "$" }

	if #text > 0 then
		for i = 1, utf8.len(text) or 0, 1 do
			local oneChar = text:sub(i, i)

			if table.find(specialChars, oneChar) then
				table.insert(strResults, "%" .. oneChar)
			else
				table.insert(strResults, oneChar)
			end
		end
	end

	return table.concat(strResults, "")
end

function parser:removeRichTextTags(str)
	str = str:gsub("<br%s*/>", "\n")
	return (str:gsub("<[^<>]->", ""))
end

-- New replacement for Parser:replaceStringWithDictionary
-- Dictionary array: { matchPattern<string>, substitution<string|function>, isOneCharacter[boolean] }

function parser:filterStringWithDictionary(str: string, dictionary: { [number]: {} })
	assert(type(str) == "string", "Argument 1 must be a string")
	assert(type(dictionary) == "table", "Argument 2 must be a table")

	local newString = str
	local function filterPattern(selected: string, entryArray: {})
		local matchPattern: string = entryArray[1]
		local substitution: string = entryArray[2]
		-- local substitutionType: string|(...any) -> any = type(substitution)
		local isOneCharacter: boolean = entryArray[4]

		if isOneCharacter then
			local newSelected = {}

			for i = 1, utf8.len(selected), 1 do
				local letter = selected:sub(i, i)

				if letter == matchPattern then
					table.insert(newSelected, substitution)
				else
					table.insert(newSelected, letter)
				end
			end

			return table.concat(newSelected)
		end

		return select(1, string.gsub(selected, matchPattern, substitution))
	end

	for i, strMatchArray in dictionary do
		newString = filterPattern(newString, strMatchArray)
	end

	return newString
end

type filterStringTypeSettings = {
	richText: boolean,
	startedSince: number | nil,
}

local defaultTextSettings: filterStringTypeSettings = {
	richText = false,
}

function parser:filterStringWithSpecialMarkdown(
	str: string,
	delimiter: string?,
	textSettings: filterStringTypeSettings?
)
	textSettings = textSettings or defaultTextSettings

	if not textSettings then
		textSettings = table.clone(defaultTextSettings)
		if not textSettings.startedSince then textSettings.startedSince = os.time() end
	else
		textSettings = table.clone(textSettings)
	end

	local specialMarkdownList = client.SpecialTextMarkdown
	local messageArguments = parser:getArguments(str, delimiter or " ", {
		includeQuotesInArgs = true,
		includeDelimiter = true,
	})

	for i, messageArg: string in messageArguments do
		for i, textMarkdown in specialMarkdownList do
			local markdownName, listOfMatches, onMatchDetection =
				tostring(textMarkdown[1]), textMarkdown[2], textMarkdown[3]
			local isRichTextMarkdown = markdownName:sub(1, 9) == `RichText-`

			if isRichTextMarkdown and not textSettings.richText then continue end

			for d, markdownMatch in listOfMatches do
				messageArg = messageArg:gsub(`\{\{{markdownMatch}\}\}`, function(...)
					local detectionResult = onMatchDetection({ ... }, textSettings, parser)
					--// Error code is less than 0

					if type(detectionResult) == "number" and detectionResult < 0 then
						if detectionResult == 0 then return "{{forbidden}}" end
						return "{{unknown}}"
					else
						return detectionResult
					end
				end)
			end
		end

		messageArguments[i] = messageArg
	end

	return table.concat(messageArguments):gsub("&dlb;", "{{"):gsub("&drb;", "}}"):gsub("{", "{"):gsub("};", "}")
end

function parser:formatImageUrl(imageUrl: string)
	imageUrl = tostring(imageUrl)
	if #imageUrl == 0 or imageUrl == "nil" then return "" end

	local endpoint, url = string.match(imageUrl, "^(%w+)://(.+)$")

	if endpoint == "mti" or endpoint == "materialicons" then return client.MaterialIcons[url] end

	-- Number only
	if string.match(imageUrl, "^(%d+)$") then
		local assetId = tonumber(string.match(imageUrl, "^(%d+)$"))
		return `rbxassetid://{assetId}`
	end

	return imageUrl
end

function parser:convertExecutionUrlToFunction(executionUrl: string, customArbitraryEnv)
	if type(executionUrl) ~= "string" then return end

	local endpoint, url = string.match(executionUrl, "^(%w+)://(.+)$")
	local Network = client.Network

	if not (endpoint and url) then return end

	if endpoint == "sessionevent" then
		local PreferredNetwork
		local networkId, sessionId, eventId, luaParserEncodedArray = string.match(url, "(%w+):(%w+)%-(%w+)||(.+)")
		if not networkId then
			networkId, sessionId, eventId = string.match(url, "(%w+):(%w+)%-(%w+)")
		end

		if luaParserEncodedArray then luaParserEncodedArray = client.LuaParser.Decode(luaParserEncodedArray) end
		if not (networkId and sessionId and eventId) then return end

		if networkId == "main" or networkId == "server" then
			PreferredNetwork = Network
		else
			PreferredNetwork = Network:getSubNetwork(networkId) or Network:getSubNetwork(nil, networkId)
		end

		return function(...)
			if luaParserEncodedArray then
				PreferredNetwork:fire("ManageSession", sessionId, "FireEvent", eventId, unpack(luaParserEncodedArray))
				return
			end

			PreferredNetwork:fire("ManageSession", sessionId, "FireEvent", eventId, ...)
		end
	end

	if endpoint == "sessioncommand" then
		local PreferredNetwork
		local networkId, sessionId, commandId, luaParserEncodedArray = string.match(url, "(%w+):(%w+)%-(%w+)||(.+)")
		if not networkId then
			networkId, sessionId, commandId = string.match(url, "(%w+):(%w+)%-(%w+)")
		end

		if luaParserEncodedArray then luaParserEncodedArray = client.LuaParser.Decode(luaParserEncodedArray) end

		if not (networkId and sessionId and commandId) then return end

		if networkId == "main" or networkId == "server" then
			PreferredNetwork = Network
		else
			PreferredNetwork = Network:getSubNetwork(networkId) or Network:getSubNetwork(nil, networkId)
		end

		return function(...)
			if luaParserEncodedArray then
				PreferredNetwork:fire(
					"ManageSession",
					sessionId,
					"RunCommand",
					commandId,
					unpack(luaParserEncodedArray)
				)
				return
			end

			PreferredNetwork:fire("ManageSession", sessionId, "RunCommand", commandId, ...)
		end
	end
	
	if endpoint == "remotecommand" then
		local PreferredNetwork
		local networkId, remoteCommandName, luaParserEncodedArray = string.match(url, "(%w+):(%w+)||(.+)")

		if luaParserEncodedArray then luaParserEncodedArray = client.LuaParser.Decode(luaParserEncodedArray) end

		if not (networkId and luaParserEncodedArray) then return end

		if networkId == "main" or networkId == "server" then
			PreferredNetwork = Network
		else
			PreferredNetwork = Network:getSubNetwork(networkId) or Network:getSubNetwork(nil, networkId)
		end

		return function(...)
			if not luaParserEncodedArray then return end
			PreferredNetwork:fire(
				remoteCommandName,
				unpack(luaParserEncodedArray)
			)
		end
	end

	if endpoint == "playercommand" then
		local commandId, commandInput = string.match(url, "(%w+)||(.*)")
		if not (commandId and commandInput) then return end

		local inputArgs = if #commandInput > 0
			then parser:getArguments(commandInput, client.ServerSettings.Delimiter)
			else nil

		return function(input: string)
			Network:fire(
				"ExecuteConsoleCommandV2",
				commandId,
				inputArgs
					or if not input then {} else parser:getArguments(tostring(input), client.ServerSettings.Delimiter)
			)
		end
	end

	if endpoint == "script" and Network:isEndToEndEncrypted() then
		local scriptId = string.match(url, "(%w+)")
		local listOfScripts = client.Policies:get(`TRUSTED_CODE_SIGNATURES`).value

		if not listOfScripts or not scriptId then return end
		if not listOfScripts[scriptId] then
			message(`Script {scriptId:sub(1, 50)} is not verified in player's policy`)
			return
		end

		local bytecodeFunc = client.Loadstring(listOfScripts[scriptId], customArbitraryEnv or getEnv(nil))
		if not bytecodeFunc then return end

		return function(...) return bytecodeFunc(...) end
	end

	return nil
end

function parser.Init(env)
	client = env.client
	getEnv = env.getEnv
	message = env.message
end

return parser
