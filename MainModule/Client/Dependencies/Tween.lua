
return function(env)
	local _G, game, script, getfenv, setfenv, workspace,
		getmetatable, setmetatable, loadstring, coroutine,
		rawequal, typeof, print, math, warn, error,  pcall,
		xpcall, select, rawset, rawget, ipairs, pairs,
		next, Rect, Axes, os, tick, Faces, unpack, string, Color3,
		newproxy, tostring, tonumber, Instance, TweenInfo, BrickColor,
		NumberRange, ColorSequence, NumberSequence, ColorSequenceKeypoint,
		NumberSequenceKeypoint, PhysicalProperties, Region3int16,
		Vector3int16, elapsedTime, require, table, type, wait,
		Enum, UDim, UDim2, Vector2, Vector3, Region3, CFrame, Ray, spawn =
			_G, game, script, getfenv, setfenv, workspace,
		getmetatable, setmetatable, loadstring, coroutine,
		rawequal, typeof, print, math, warn, error,  pcall,
		xpcall, select, rawset, rawget, ipairs, pairs,
		next, Rect, Axes, os, tick, Faces, unpack, string, Color3,
		newproxy, tostring, tonumber, Instance, TweenInfo, BrickColor,
		NumberRange, ColorSequence, NumberSequence, ColorSequenceKeypoint,
		NumberSequenceKeypoint, PhysicalProperties, Region3int16,
		Vector3int16, elapsedTime, require, table, type, wait,
		Enum, UDim, UDim2, Vector2, Vector3, Region3, CFrame, Ray, spawn

	local client = env.client
	local service = env.service
	
	local signal = client.Signal
	
	local tweenService = service.TweenService
	local tweenCreate = tweenService.Create
	
	client.Tween = {
		create = function(obj, tweenInfo, properties)
			properties = (type(properties)=="table" and service.cloneTable(properties)) or {}
			
			local tweenAnim = tweenCreate(tweenService, obj, tweenInfo, properties or {})
			
			local animPlay 		= tweenAnim.Play
			local animStop 		= tweenAnim.Stop
			local animPause 	= tweenAnim.Pause
			local animCancel	= tweenAnim.Cancel
			
			local signal_Delayed 	= signal.new()
			local signal_Playing 	= signal.new()
			local signal_Paused 	= signal.new()
			local signal_Completed 	= signal.new()
			local signal_Canceled 	= signal.new()
			
			local tweenEvents = {
				Delayed 	= signal_Delayed:wrap();
				Playing 	= signal_Playing:wrap();
				Paused		= signal_Paused:wrap();
				Completed 	= signal_Completed:wrap();
				Canceled 	= signal_Canceled:wrap();
			}
			
			tweenAnim:GetPropertyChangedSignal"PlaybackState":Connect(function()
				local playbackState = tweenAnim.PlaybackState
				
				if playbackState == Enum.PlaybackState.Playing then
					tweenEvents.Playing:fire()
				elseif playbackState == Enum.PlaybackState.Delayed then
					tweenEvents.Delayed:fire()
				elseif playbackState == Enum.PlaybackState.Paused then
					tweenEvents.Paused:fire()
				elseif playbackState == Enum.PlaybackState.Completed then
					tweenEvents.Completed:fire()
				elseif playbackState == Enum.PlaybackState.Cancelled then
					tweenEvents.Canceled:fire()
				end
			end)
			
			local triggerPlay = function()
				local canTween = (service.playerGui and obj:IsDescendantOf(service.playerGui)) or
					obj:IsDescendantOf(workspace)
				
				if canTween then
					animPlay(tweenAnim)
				else
					for prop,val in pairs(properties) do
						obj[prop] = val
					end
				end
			end
			
			local triggerPause = function()
				animPause(tweenAnim)
			end
			
			local triggerStop = function()
				animStop(tweenAnim)
			end
			
			local triggerCancel = function()
				animCancel(tweenAnim)
			end
			
			local changeTween = function(props, tweenInfo)
				triggerStop()
				
				props = (type(props)=="table" and service.cloneTable(props)) or properties
				
				local newTween = tweenCreate(tweenService, obj, tweenInfo, props or {})
				
				if newTween then
					tweenAnim = newTween
					return true
				end
			end
			
			local tweenProxy = service.newProxy{
				__index = function(self, ind)
					if ind == "Play" then
						return triggerPlay
					elseif ind == "Pause" then
						return triggerPause
					elseif ind == "Stop" then
						return triggerStop
					elseif ind == "Cancel" then
						return triggerCancel
					elseif ind == "Change" then
						return changeTween
					elseif ind == "Object" or ind == "Instance" then
						return obj
					elseif ind == "PlaybackState" then
						return tweenAnim.PlaybackState
					elseif tweenEvents[ind] then
						return tweenEvents[ind]
					end
				end;
				
				__tostring = function() return "Essential-TweenAnim" end;
				__metatable = "Essential-TweenAnim";
			}
			
			return tweenProxy
		end,
	}
end