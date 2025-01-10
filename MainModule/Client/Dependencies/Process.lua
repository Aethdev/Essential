return function(env)
	local _G, game, script, getfenv, setfenv, workspace, getmetatable, setmetatable, loadstring, coroutine, rawequal, typeof, print, math, warn, error, pcall, xpcall, select, rawset, rawget, ipairs, pairs, next, Rect, Axes, os, tick, Faces, unpack, string, Color3, newproxy, tostring, tonumber, Instance, TweenInfo, BrickColor, NumberRange, ColorSequence, NumberSequence, ColorSequenceKeypoint, NumberSequenceKeypoint, PhysicalProperties, Region3int16, Vector3int16, elapsedTime, require, table, type, wait, Enum, UDim, UDim2, Vector2, Vector3, Region3, CFrame, Ray, spawn =
		_G,
		game,
		script,
		getfenv,
		setfenv,
		workspace,
		getmetatable,
		setmetatable,
		loadstring,
		coroutine,
		rawequal,
		typeof,
		print,
		math,
		warn,
		error,
		pcall,
		xpcall,
		select,
		rawset,
		rawget,
		ipairs,
		pairs,
		next,
		Rect,
		Axes,
		os,
		tick,
		Faces,
		unpack,
		string,
		Color3,
		newproxy,
		tostring,
		tonumber,
		Instance,
		TweenInfo,
		BrickColor,
		NumberRange,
		ColorSequence,
		NumberSequence,
		ColorSequenceKeypoint,
		NumberSequenceKeypoint,
		PhysicalProperties,
		Region3int16,
		Vector3int16,
		elapsedTime,
		require,
		table,
		type,
		wait,
		Enum,
		UDim,
		UDim2,
		Vector2,
		Vector3,
		Region3,
		CFrame,
		Ray,
		spawn

	local client = env.client
	local service = env.service

	local Process, Network, Remote
	local function Init()
		Network = client.Network
		Remote = client.Remote
		Process = client.Process
	end

	client.Process = {
		Init = Init,

		remoteCall_RateLimit = {
			Rates = 500,
			Reset = 120,
		},

		remoteCall = function(invoke, key, ...)
			local rateData = Process.remoteCall_RateLimit
			local rateKey = "Server"
			local ratePass, didThrottle, canThrottle, curRate, maxRate, throttleResetOs =
				client.Utility:checkRate(rateData, rateKey)

			if ratePass then
				local keyType = type(key)
				local isKeyValidType = keyType == "string"

				if isKeyValidType and Network.serverToClientRemoteKey then
					local realKey = if Network:isEndToEndEncrypted()
						then client.HashLib.sha1(Network.serverToClientRemoteKey)
						else Network.serverToClientRemoteKey

					if realKey ~= key then return end

					local params = service.wrap({ ... }, true)

					local cmdName = params[1]
					cmdName = (table.find({ "number", "string" }, type(cmdName)) and cmdName) or nil

					if cmdName then
						local cmd = Remote.Commands[cmdName]

						if cmd and not cmd.Disabled then
							local lockdown = client.lockdown

							if not lockdown or (lockdown and cmd.Lockdown_Allowed) then
								local cmdFunction = cmd.Function or cmd.Run or cmd.Execute or cmd.Call
								cmdFunction = (type(cmdFunction) == "function" and cmdFunction) or nil

								if not (cmd.Can_Invoke or cmd.Can_Fire) then cmd.Can_Fire = true end

								local rL_Enabled = cmd.RL_Enabled
								local rL_Rates = cmd.RL_Rates or 1
								local rL_Reset = cmd.RL_Reset or 0.01
								local rL_Error = cmd.RL_Error
								local rL_Data = cmd.RL_Data
									or (function()
										local data = {}

										rL_Rates = math.floor(math.abs(rL_Rates))
										rL_Reset = math.abs(rL_Reset)

										rL_Rates = (rL_Rates < 1 and 1) or rL_Rates

										cmd.RL_Rates = rL_Rates
										cmd.RL_Reset = rL_Reset

										data.Rates = rL_Rates
										data.Rest = rL_Reset

										cmd.RL_Data = data
										return data
									end)()

								local canUseCommand = (invoke and cmd.Can_Invoke)
									or (not invoke and cmd.Can_Fire)
									or false

								if canUseCommand and cmdFunction then
									if rL_Enabled then
										local passCmdRateCheck, curRemoteRate, maxRemoteRate =
											client.Utility:checkRate(rL_Data, rateKey)

										if not passCmdRateCheck then
											return (type(rL_Error) == "string" and rL_Error) or nil
										end
									end

									local rets = {
										service.trackTask(
											"_REMCOMMAND-"
												.. cmdName
												.. "-Invoke:"
												.. tostring(invoke)
												.. "-"
												.. service.getRandom(),
											false,
											cmdFunction,
											{ unpack(params, 2) }
										),
									}

									if not rets[1] then
										warn(
											"Remote command "
												.. cmdName
												.. " encountered an error while running: "
												.. tostring(rets[2])
										)
									else
										if invoke then return unpack(rets, 2) end
									end
								elseif canUseCommand and not cmdFunction then
									error("Unable to call a remote command without a function", 0)
								end
							end
						end
					end
				end
			else
			end
		end,
	}
end
