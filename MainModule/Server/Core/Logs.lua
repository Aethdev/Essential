	
return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service
	local settings = server.Settings
	
	local Filter = server.Filter
	local Network = server.Network
	local Parser = server.Parser
	local Roles = server.Roles
	local Utility = server.Utility
	local Vela = server.Vela
	
	local Base64 = server.Base64
	local Promise = server.Promise
	
	
	local Cmds, Core, Cross, Datastore, Identity, Logs, Moderation, Parser, Process, Remote
	local function Init()
		Core = server.Core
		Cross = server.Cross
		Cmds = server.Commands
		Datastore = server.Datastore
		Identity = server.Identity
		Logs = server.Logs
		Moderation = server.Moderation
		Network = server.Network
		Parser = server.Parser
		Process = server.Process
		Remote = server.Remote
	end
	
	local cloneTable = service.cloneTable
	
	local logDelimiter = " "
	local specialTextSettings = {
		richText = false;
		customReplacements = {
			target = "";
		}
	}
	
	server.Logs = {
		Init = Init;
		
		library = {
			Admin = {};
			Client = {};
			Chat = {};
			Errors = {};
			Exploit = {};
			Script = {};
			Process = {};
			Datastore = {};
			Remote = {};
			Global = {};
			Commands = {};
			PlayerActivity = {};
		};
		
		addLog = function(categories, log, group, customMaxLogs)
			if type(categories) == "string" then
				categories = {Logs.library[categories]}
			elseif type(categories) == "table" then
				--categories = {categories}
			else
				categories = nil
			end
			
			if categories and #categories > 0 then
				local logData
				local logTimestamp = DateTime.now()
				local logUniqueId = Base64.encode(`{logTimestamp.UnixTimestampMillis}-{service.getRandom()}`)
				
				if type(log) == "string" then
					logData = {
						title = log;
						desc = log;
						group = group or nil;
						richText = false;
						data = {};
						sentOs = logTimestamp.UnixTimestamp;
						sent = os.clock();
						id = logUniqueId;
					}
				elseif type(log) == "table" then
					logData = {
						title = log.title or log.desc or nil;
						desc = log.desc or nil;
						group = group or nil;
						richText = log.richText or false;
						data = log.data or {};
						sentOs = logTimestamp.UnixTimestamp;
						sent = os.clock();
						id = logUniqueId;
					}
				end
				
				if logData then
					for i,catg in pairs(categories) do
						local logList
						local catgType = type(catg)
						
						if catgType == "string" then
							logList = Logs.library[catg]
						elseif catgType == "table" then
							logList = catg
						end
						
						if logList then
							local logsCount = #logList

							-- Reset logs for new entry if it reached the max logs count
							if logsCount+1 > (customMaxLogs or settings.MaxLogs) then
								local maxLogsCount = customMaxLogs or settings.MaxLogs
								
								repeat
									table.remove(logList, 1)
								until
									#logList == 0 or #logList+1 <= maxLogsCount
								
							end
							
							table.insert(logList, logData)

							table.sort(logList, function(logA, logB)
								return (logA.sent or 0) > (logB.sent or 0)
							end)
						end
					end
					
					return logData
				end
			end
		end;
		
		addLogForPlayer = function(
			player: ParsedPlayer,
			categories: {[number]: string}|string,
			log: string|{
				title: string?,
				desc: string,
				richText: boolean?,
				data: {[string]: any}?
			},
			group: string?,
			customMaxLogs: number?
		)
			local playerDisplayName = player:toStringDisplay()
			local playerPublicName = player:toStringPublicDisplay()
			
			local specialTextSettings_Public = table.clone(specialTextSettings)
			specialTextSettings_Public.customReplacements = {
				target = playerPublicName;
				targetusername = `U{tostring(player.UserId):sub(1,4)}`;
			}
			
			local specialTextSettings_Private = table.clone(specialTextSettings)
			specialTextSettings_Private.customReplacements = {
				target = playerDisplayName;
				targetusername = player.Name;
			}
			
			if type(log) == "string" then
				local publicLog = Parser:filterStringWithSpecialMarkdown(log, logDelimiter, specialTextSettings_Public)
				local plainLog = Parser:filterStringWithSpecialMarkdown(log, logDelimiter, specialTextSettings_Private)
				
				log = {
					title = publicLog;
					desc = publicLog;
					data = {
						_original = {
							desc = plainLog;
							title = plainLog;
							userId = player.UserId;
						}
					}
				}
				
			else
				log.data = log.data or {}
				log.data._original = {
					desc = Parser:filterStringWithSpecialMarkdown(log.desc, logDelimiter, specialTextSettings_Private);
					title = Parser:filterStringWithSpecialMarkdown(log.title or log.desc, logDelimiter, specialTextSettings_Private);
					userId = player.UserId;
				}
				
				if not log.data._original.title then
					log.data._original.title = log.data._original.desc
				end
				
				log.desc = Parser:filterStringWithSpecialMarkdown(log.desc, logDelimiter, specialTextSettings_Public)
				log.title = Parser:filterStringWithSpecialMarkdown(log.title or log.desc, logDelimiter, specialTextSettings_Public)
			end
			
			return Logs.addLog(categories, log, group, customMaxLogs)
		end;
		
		formatLog = function(log,group)
			if type(log) == "string" then
				log = {
					title = log;
					desc = log;
				}
			end
			
			local logTimestamp = DateTime.now()
			local logUniqueId = Base64.encode(`{logTimestamp.UnixTimestampMillis}-{service.getRandom()}`)
			
			return {
				title = log.title or log.desc or nil;
				desc = log.desc or nil;
				group = group or log.group or nil;
				richText = log.richText or false;
				data = log.data or {};
				sentOs = logTimestamp.UnixTimestamp;
				sent = os.clock();
				id = logUniqueId;
			}
		end;
		
		--addSavedLog = function(category, log, group, customMaxLogs)
		--	category = category:sub(1,50)
			
		--	local logData
		--	local logTimestamp = DateTime.now()
		--	local logUniqueId = Base64.encode(`{logTimestamp.UnixTimestampMillis}-{service.getRandom()}`)

		--	if type(log) == "string" then
		--		logData = {
		--			title = log;
		--			desc = log;
		--			group = group or nil;
		--			richText = false;
		--			data = {};
		--			sentOs = os.time();
		--			sent = os.clock();
		--			id = service.getRandom(30);
		--		}
		--	elseif type(log) == "table" then
		--		logData = {
		--			title = log.title or log.desc or nil;
		--			desc = log.desc or nil;
		--			group = group or nil;
		--			richText = log.richText or false;
		--			data = log.data or {};
		--			sentOs = os.time();
		--			sent = os.clock();
		--			id = service.getRandom(30);
		--		}
		--	end
		--end;
		
		Reporters = {
			Promise = {
				--// similar to error
				issue = function(reportPrefix: string, reportCategories: {[number]: string}|string, chainedHandler: () -> any?)
					assert(type(reportPrefix) == "string", `Report prefix must be a string`)
					assert(type(reportCategories) == "string" or type(reportCategories) == "table", `Report categories must be a string/table`)
					
					return function(err: string|PromiseError)
						if Promise.Error.is(err) then
							Logs.addLog(reportCategories, {
								title = `{reportPrefix} {err.context}`;
								desc = tostring(err);
								group = `ISSUE`;
							})
						else
							Logs.addLog(reportCategories, {
								title = `{reportPrefix} {tostring(err)}`;
								desc = `{reportPrefix} {tostring(err)}`;
								group = `ISSUE`;
							})
						end
						
						if server.Studio then
							warn(`A promise encountered an error:`, tostring(err))
						end
						
						if chainedHandler then
							task.spawn(chainedHandler, err)
						end
					end
				end;
				
				warning = function(reportPrefix: string, reportCategories: {[number]: string}|string, chainedHandler: () -> any?)
					assert(type(reportPrefix) == "string", `Report prefix must be a string`)
					assert(type(reportCategories) == "string" or type(reportCategories) == "table", `Report categories must be a string/table`)

					return function(err: string|PromiseError)
						if Promise.Error.is(err) then
							Logs.addLog(reportCategories, {
								title = `{reportPrefix} {err.context}`;
								desc = tostring(err);
								group = `WARN`;
							})
						else
							Logs.addLog(reportCategories, {
								title = `{reportPrefix} {tostring(err)}`;
								desc = `{reportPrefix} {tostring(err)}`;
								group = `WARN`;
							})
						end

						if chainedHandler then
							task.spawn(chainedHandler, err)
						end
					end
				end;
				
				debug = function(reportPrefix: string, reportCategories: {[number]: string}|string, chainedHandler: () -> any?)
					assert(type(reportPrefix) == "string", `Report prefix must be a string`)
					assert(type(reportCategories) == "string" or type(reportCategories) == "table", `Report categories must be a string/table`)

					return function(err: string|PromiseError)
						if Promise.Error.is(err) then
							Logs.addLog(reportCategories, {
								title = `{reportPrefix} {err.context}`;
								desc = tostring(err);
								group = `DEBUG`;
							})
						else
							Logs.addLog(reportCategories, {
								title = `{reportPrefix} {tostring(err)}`;
								desc = `{reportPrefix} {tostring(err)}`;
								group = `DEBUG`;
							})
						end

						if chainedHandler then
							task.spawn(chainedHandler, err)
						end
					end
				end;
				
				print = function(reportPrefix: string, reportCategories: {[number]: string}|string, chainedHandler: () -> any?)
					assert(type(reportPrefix) == "string", `Report prefix must be a string`)
					assert(type(reportCategories) == "string" or type(reportCategories) == "table", `Report categories must be a string/table`)

					return function(err: string|PromiseError)
						if Promise.Error.is(err) then
							Logs.addLog(reportCategories, {
								title = `{reportPrefix} {err.context}`;
								desc = tostring(err);
								group = `PRINT`;
							})
						else
							Logs.addLog(reportCategories, {
								title = `{reportPrefix} {tostring(err)}`;
								desc = `{reportPrefix} {tostring(err)}`;
								group = `PRINT`;
							})
						end

						if chainedHandler then
							task.spawn(chainedHandler, err)
						end
					end
				end;
			};
		};
		
	}
end