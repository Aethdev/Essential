local vela = {}

local scripts = {}

-- Built-in modules
vela.environment = require(script.Environment)
vela.loadstring = require(script.Loadstring)

server = nil
service = nil

function vela:create(scrType, source, data)
	data = data or {}
	
	if scrType == "Server" or scrType == "Module" then
		local scr = (scrType == "Server" and script.Scripts.LBI_Server:Clone()) or script.Scripts.LBI_Module:Clone()
		local bytecode = select(2, self.loadstring(source))
		
		local scriptFiOne = script.Loadstring.FiOne:Clone()
		local scriptHandler = scr.Handler
		local scriptEnv,envTable = self.environment.create()
		local handlerProxy = require(scriptHandler)
		
		local scrData; scrData = {
			Id = game:GetService("HttpService"):GenerateGUID();
			Source = source;
			Bytecode = bytecode;
			Type = scrType;
			Active = true;
			Created = tick();
			
			Kill = function(self)
				scrData.Active = false
				game:GetService("Debris"):AddItem(scr, 0)

				scrData.Kill = nil
			end;

			Script = scr;
			Handler = scriptHandler;
			FiOne = scriptFiOne;
			
			Errored = server.Signal.new();
			
			EnvTable = envTable;
		}
		
		-- Manages handler's meta
		do
			local handlerData; handlerData = {
				Access = function(self)
					if scrData.Active then
						handlerData.Access = nil
						
						return scriptFiOne,bytecode,scriptEnv
					end
				end;
			}
			
			local handlerMeta = getmetatable(handlerProxy)
			handlerMeta.__metatable = "The metatable is locked"
			handlerMeta.__index = function(self, ind)
				if scrData.Active then
					local chosen = rawget(handlerData, ind)
					local typ = type(chosen)
					
					if chosen~=nil then
						if typ == "function" then
							return service.metaFunc(chosen)
						elseif typ == "table" then
							return service.metaTable(chosen)
						else
							return chosen
						end
					end
				end
			end
			
			handlerMeta.__newindex = function(self, ind, val)
				error("Attempting to write a read only userdata", 0)
			end
		end
		
		local errorCount = 0
		local errorEv; errorEv = service.ScriptContext.Error:connect(function(msg, trace, failedScr)
			if failedScr == scr then
				scrData.Errored:fire(msg, trace)
				
				local newCount = errorCount+1
				
				if newCount > 30 then
					errorEv:Disconnect()
					service.Delete(scr)
				end
				
				errorCount = newCount
			end
		end)
		
		table.insert(scripts, scrData)
		
		scr.Name = "Server"
		scr.Archivable = false
		
		envTable:set("script", (scr.ClassName=="ModuleScript" and Instance.new("Script")) or scr)
		envTable:set("_ENV", scriptEnv)
		
		for ind,val in pairs(data.env or data.environment or {}) do
			envTable:set(ind, val)
		end
		
		-- Script attributes
		scr:SetAttribute("Source", tostring((data.publicSource and source) or "[VELA Script] This script has a private source."))
		scr:SetAttribute("Created", scrData.Created)
		
		return scr,scrData
	elseif scrType == "Client" then
		local scr = script.Scripts.LBI_Client:Clone()
		local bytecode = select(2, self.loadstring(source))

		local scriptFunc = scr.Function
		local scriptFiOne = script.Loadstring.FiOne:Clone()
		scriptFiOne.Parent = scr
		
		local scrData; scrData = {
			Id = game:GetService("HttpService"):GenerateGUID();
			Source = source;
			Bytecode = bytecode;
			Type = scrType;
			Active = true;

			Kill = function(self)
				scrData.Active = false
				game:GetService("Debris"):AddItem(scr, 0)

				scrData.Kill = nil
			end;

			Script = scr;
			FiOne = scriptFiOne;
		}
		
		local onInvoke = function()
			scriptFunc.OnServerInvoke = nil
			game:GetService("Debris"):AddItem(scriptFunc, 1)
			
			if scrData.Active then
				return bytecode
			end
		end
		
		scriptFunc.OnServerInvoke = onInvoke
		
		return scr,scrData
	end
end

return vela
