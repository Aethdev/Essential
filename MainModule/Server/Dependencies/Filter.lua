local filter = {}
filter.cache = {}

local server, service, settings = nil, nil
local cloneTable = nil
local isStudio = nil

local cacheUpdateTime = {
	phrase = 60,
	message = 30,

	filterAttemptTries = 3,
	filterFunctionReachTries = 1,
}

local function retryFunction(maxTries: number, performer, ...)
	local performerInvokeArgs = { ... }
	local performerReturnArgs = {}
	local currentTries = 0

	while currentTries + 1 <= maxTries do
		currentTries += 1

		local performerRes = { service.nonThreadTask(performer, ...) }
		if performerRes[1] then
			performerReturnArgs = { table.unpack(performerRes) }
			break
		else
			task.wait(0.1)
		end
	end

	return table.unpack(performerReturnArgs)
end

local function filterForStrPattern(text: string): string
	local strResults = {}
	local specialChars = { "(", ")", "%", ".", "+", "-", "*", "[", "]", "?", "^", "$" }

	if #text > 0 then
		local utf8Len = utf8.len(text) or 0

		for i = 1, utf8Len, 1 do
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

function filter:safeString(
	str: string,
	senderId: number,
	targetId: number,
	filteringType: Enum.TextFilterContext? | string?,
	filterKeywords: { [any]: any }?,
	onlyUseCustom: boolean?
)
	local defaultFilterType = Enum.TextFilterContext.PrivateChat
	filteringType = filteringType or defaultFilterType

	local filteringEnum = table.find(Enum.TextFilterContext:GetEnumItems(), filteringType) and filteringType
	local filteringName = (typeof(filteringType) == "Enum" and filteringType.Name)
		or (type(filteringType) == "string" and filteringType)
		or "CustomFilter"

	if not filteringEnum then filteringEnum = defaultFilterType end

	if filterKeywords then filteringName = "CustomFilter-" .. tostring(filterKeywords) end

	if not targetId then targetId = senderId end

	local senderCacheId, targetCacheId = senderId, filteringName .. "-" .. targetId
	local senderCache: { [any]: any } = filter.cache[senderCacheId]
		or filter:registerSenderCache(filter.cache, senderCacheId)
	local targetCache: { [any]: any }? = (senderId == targetId and senderCache) or senderCache.targets[targetCacheId]

	if not targetCache then
		targetCache = filter:registerSenderCache(senderCache.targets, targetCacheId)
		senderCache.targets[targetCacheId] = targetCache
	end

	local delimiter: string = (settings or {}).delimiter or " "

	local dontCacheSentence: boolean = #str <= 1 --or #string.split(str, filterForStrPattern(delimiter)) <= 1
	local dontCacheFilter = server.Studio

	--if dontCacheFilter then
	--	return true, str, str
	--end

	local sentenceCacheChecklist = {}

	if not dontCacheSentence then
		for sentence, sentenceCache in pairs(targetCache.messages) do
			local strPattern = filterForStrPattern(sentence)
			if not sentenceCacheChecklist[sentenceCacheChecklist] and string.find(str, strPattern) then
				sentenceCacheChecklist[sentenceCacheChecklist] = true

				local canUseOldCache = os.time() - sentenceCache.updated < cacheUpdateTime.message
				if canUseOldCache then
					local oldString = str
					local safePattern = sentenceCache.newString
					str = str:gsub(strPattern, safePattern)
					if sentence == oldString then
						return not sentenceCache.filtered, sentenceCache.newString, oldString
					end
				end
			end
		end
	end

	local strPhrases: { [any]: any } = string.split(str, delimiter)

	do
		local dontCachePhrase: boolean = #strPhrases <= 1
		local checkedPhrases: { [any]: any } = {}

		for i, phrase in pairs(strPhrases) do
			-- If it's already filtered, skip
			if string.rep("#", #phrase) == phrase then continue end

			local cache = targetCache.phrases[phrase:lower()]

			if filterKeywords then
				filterKeywords = cloneTable(filterKeywords)
				local keywordData

				for i, keywordD in pairs(filterKeywords) do
					if keywordD.stringMatch then
						local checkKeyword = keywordD.keyword
						if keywordD.lowerCase then checkKeyword = checkKeyword:lower() end

						local safeMatchPhrase = filterForStrPattern(phrase)
						if string.match(safeMatchPhrase, checkKeyword) then keywordData = keywordD end
					else
						if not keywordD.caseSensitive then
							if keywordD.keyword:lower() == phrase:lower() then keywordData = keywordD end
						else
							if keywordD.keyword == phrase then keywordData = keywordD end
						end
					end

					if keywordData then break end
				end

				if keywordData then
					local filteredPhrase = string.rep("#", #phrase)
					strPhrases[i] = filteredPhrase
					if not onlyUseCustom then
						targetCache.phrases[phrase:lower()] = {
							filtered = true,
							updated = os.time(),
						}
					end
					continue
				end
			end

			if not (onlyUseCustom and filterKeywords) then
				local canUpdateCache = not cache or tick() - cache.updated >= cacheUpdateTime.phrase

				if canUpdateCache then
					local phraseCache = {
						filtered = (cache and cache.filtered) or false,
						updated = os.time(),
					}

					if not table.find(checkedPhrases, phraseCache) then table.insert(checkedPhrases, phraseCache) end

					if not dontCachePhrase then targetCache.phrases[phrase:lower()] = phraseCache end

					local fPSuccess: boolean, fpFilterAsync: TextFilterResult = retryFunction(
						cacheUpdateTime.filterFunctionReachTries,
						service.TextService.FilterStringAsync,
						service.TextService,
						phrase:lower(),
						senderId,
						filteringEnum
					)

					local nonChatFPSuccess: boolean?, nonChatFilterPhrase: string

					if fPSuccess then
						nonChatFPSuccess, nonChatFilterPhrase = retryFunction(
							cacheUpdateTime.filterAttemptTries,
							fpFilterAsync.GetNonChatStringForUserAsync,
							fpFilterAsync,
							targetId
						)

						phraseCache.filtered = (not nonChatFPSuccess and true)
							or nonChatFilterPhrase:lower() ~= phrase:lower()
					else
						phraseCache.filtered = true
					end

					--if not nonChatFPSuccess then
					--	warn("nonchatfpsucess failed: "..tostring(nonChatFilterPhrase))
					--end

					if phraseCache.filtered then strPhrases[i] = string.rep("#", #phrase) end
				elseif cache then
					if not table.find(checkedPhrases, cache) then table.insert(checkedPhrases, cache) end

					if cache.filtered then strPhrases[i] = string.rep("#", #phrase) end
				end
			end
		end
	end

	local newString: { [any]: any } = table.concat(strPhrases, delimiter)
	local msgFiltered: boolean = str:lower() ~= newString:lower()
	local msgFilterCache: { [any]: any } = {
		filtered = str:lower() ~= newString:lower(),
		newString = newString,
		updated = os.time(),
	}

	if not dontCacheSentence then
		targetCache.messages[str] = msgFilterCache
		targetCache.messages[str:lower()] = msgFilterCache
	end

	if not msgFiltered and #strPhrases > 1 and not (onlyUseCustom and filterKeywords) then
		local msgFSuccess: boolean, msgFFilterAsync: TextFilterResult = retryFunction(
			cacheUpdateTime.filterFunctionReachTries,
			service.TextService.FilterStringAsync,
			service.TextService,
			newString:lower(),
			senderId
		)

		local nonChatFMsgSuccess: boolean?, nonChatFilterMessage: string

		if msgFSuccess then
			nonChatFMsgSuccess, nonChatFilterMessage = retryFunction(
				cacheUpdateTime.filterAttemptTries,
				msgFFilterAsync.GetNonChatStringForUserAsync,
				msgFFilterAsync,
				targetId
			)

			msgFiltered = not nonChatFMsgSuccess or nonChatFilterMessage:lower() ~= newString:lower()
			if msgFiltered and nonChatFMsgSuccess then newString = nonChatFilterMessage end
		end
	end

	return not msgFilterCache.filtered, newString, str
end

function filter:safeStringForPublic(
	str: string,
	senderId: number,
	filterKeywords: { [any]: any }?,
	onlyUseCustom: boolean?
)
	local senderCache: { [any]: any } = filter.cache[senderId] or filter:registerSenderCache(filter.cache, senderId)

	local delimiter: string = (settings or {}).delimiter or " "

	local dontCacheSentence: boolean = #str <= 1
	local dontCacheFilter = server.Studio

	--if dontCacheFilter then
	--	return true, str, str
	--end

	local sentenceCacheChecklist = {}

	if not dontCacheSentence then
		for sentence, sentenceCache in pairs(senderCache.broadcastMessages) do
			local strPattern = filterForStrPattern(sentence)
			if not sentenceCacheChecklist[sentenceCacheChecklist] and string.find(str, strPattern) then
				sentenceCacheChecklist[sentenceCacheChecklist] = true

				local canUseOldCache = os.time() - sentenceCache.updated < cacheUpdateTime.message
				if canUseOldCache then
					local oldString = str
					str = str:gsub(strPattern, sentenceCache.newString)
					if sentence == oldString then
						return not sentenceCache.filtered, sentenceCache.newString, oldString
					end
				end
			end
		end
	end

	local strPhrases: { [any]: any } = string.split(str, delimiter)

	do
		local dontCachePhrase: boolean = #strPhrases <= 1
		local checkedPhrases: { [any]: any } = {}
		local filterPhrases: { [any]: any } = senderCache.broadcastPhrases

		for i, phrase in pairs(strPhrases) do
			-- If it's already filtered, skip
			if string.rep("#", #phrase) == phrase then continue end

			local checked: boolean = checkedPhrases[phrase]
			local cache: { [any]: any } = filterPhrases[phrase:lower()]

			if filterKeywords then
				filterKeywords = cloneTable(filterKeywords)
				local keywordData

				for i, keywordD in pairs(filterKeywords) do
					if keywordD.stringMatch then
						local checkKeyword = keywordD.keyword
						if keywordD.lowerCase then checkKeyword = checkKeyword:lower() end

						local safeMatchPhrase = filterForStrPattern(phrase)
						if string.match(safeMatchPhrase, checkKeyword) then keywordData = keywordD end
					else
						if not keywordD.caseSensitive then
							if keywordD.keyword:lower() == phrase:lower() then keywordData = keywordD end
						else
							if keywordD.keyword == phrase then keywordData = keywordD end
						end
					end

					if keywordData then
						local filteredPhrase = string.rep("#", #phrase)
						strPhrases[i] = filteredPhrase
						if not onlyUseCustom then
							filterPhrases[phrase:lower()] = {
								filtered = true,
								updated = os.time(),
							}
						end
						break
					end
				end

				if keywordData then
					strPhrases[i] = string.rep("#", #phrase)
					continue
				end
			end

			if not (onlyUseCustom and filterKeywords) then
				local canUpdateCache = not cache or tick() - cache.updated >= cacheUpdateTime.phrase

				if canUpdateCache then
					local phraseCache = {
						filtered = (cache and cache.filtered) or false,
						updated = os.time(),
					}

					if not table.find(checkedPhrases, phraseCache) then table.insert(checkedPhrases, phraseCache) end

					local fPSuccess: boolean, filterPhrase: TextFilterResult = retryFunction(
						cacheUpdateTime.filterFunctionReachTries,
						service.TextService.FilterStringAsync,
						service.TextService,
						phrase:lower(),
						senderId
					)

					local nonChatFBSuccess: boolean?, nonChatFilterPhrase: string

					if fPSuccess then
						nonChatFBSuccess, nonChatFilterPhrase = retryFunction(
							cacheUpdateTime.filterAttemptTries,
							filterPhrase.GetNonChatStringForBroadcastAsync,
							filterPhrase,
							senderId
						)

						phraseCache.filtered = (not nonChatFBSuccess and true)
							or nonChatFilterPhrase:lower() ~= phrase:lower()
					else
						phraseCache.filtered = true
					end

					if phraseCache.filtered then strPhrases[i] = string.rep("#", #phrase) end

					if not dontCachePhrase then filterPhrases[phrase:lower()] = phraseCache end
				elseif cache then
					if not table.find(checkedPhrases, cache) then table.insert(checkedPhrases, cache) end

					if cache.filtered then strPhrases[i] = string.rep("#", #phrase) end
				end
			end
		end
	end

	local newString: { [any]: any } = table.concat(strPhrases, delimiter)
	local msgFiltered: boolean = str:lower() ~= newString:lower()
	local msgFilterCache: { [any]: any } = {
		filtered = msgFiltered,
		newString = newString,
		updated = os.time(),
	}

	if not dontCacheSentence then
		senderCache.broadcastMessages[str] = msgFilterCache
		senderCache.broadcastMessages[str:lower()] = msgFilterCache
	end

	if not msgFiltered and #strPhrases > 1 and not (onlyUseCustom and filterKeywords) then
		local msgFSuccess: boolean, msgFFilterAsync: TextFilterResult = retryFunction(
			cacheUpdateTime.filterFunctionReachTries,
			service.TextService.FilterStringAsync,
			service.TextService,
			newString:lower(),
			senderId
		)

		local nonChatFMsgSuccess: boolean?, nonChatFilterMessage: string

		if msgFSuccess then
			nonChatFMsgSuccess, nonChatFilterMessage = retryFunction(
				cacheUpdateTime.filterAttemptTries,
				msgFFilterAsync.GetNonChatStringForBroadcastAsync,
				msgFFilterAsync,
				senderId
			)

			msgFiltered = not nonChatFMsgSuccess or nonChatFilterMessage:lower() ~= newString:lower()
			if msgFiltered and nonChatFMsgSuccess then newString = nonChatFilterMessage end
		end
	end

	assert(newString, "FILTERED STRING IS EMPTY?")
	return not msgFilterCache.filtered, newString, str
end

function filter:registerSenderCache(cacheTab: { [any]: any }, key: any): { [any]: any }
	local senderCache = {
		phrases = {},
		messages = {},
		targets = {},

		broadcastPhrases = {},
		broadcastMessages = {},
	}
	cacheTab[key] = senderCache
	return senderCache
end

--function filter:registerTargetCache(cacheTab, key)
--	local targetCache = {
--		phrases = {};
--		messages = {};
--	}
--	cacheTab[key] = targetCache
--	return targetCache
--end

function filter.Init(env): boolean
	server = env.server
	service = env.service
	settings = env.settings
	cloneTable = service.cloneTable
	return true
end

return filter
