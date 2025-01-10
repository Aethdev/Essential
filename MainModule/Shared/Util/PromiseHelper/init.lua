--[[
	ESSENTIAL PROMISE HELPER v1.0.0
		> Developed by trzistan
		 	
	
		Features:
			- Allows Promise compatibility with Signal
			- Signal event fires if the Promise rejects or resolves a value
			- Destroys multiple promises 

]]

local Promise = require(script.Promise)

local PromiseHelper = {}
PromiseHelper.prototype = {}
PromiseHelper.__index = function(_, index)
	--local protoIndexed = PromiseHelper.prototype[index]
	--if protoIndexed ~= nil then
	--	return protoIndexed
	--end
	
	local _promiseIndexed = Promise[index]
	local Typeof = typeof(_promiseIndexed)
	if Typeof == "function" then
		return function(...)
			return _promiseIndexed(...)
		end
	end
	
	return _promiseIndexed
end
PromiseHelper.__tostring = function() return PromiseHelper.ClassName end
PromiseHelper.ClassName = "Ess-PromiseHelper"

setmetatable(PromiseHelper, PromiseHelper)

function PromiseHelper.new(executor, promise): PromiseHelper
	local _promise = nil;
	local self; self = setmetatable({
		_parent = nil;
		_active = true;
		_links = {};
	}, {
		__tostring = function() return "PromiseHelper" end;
		__index = function(_, index)
			local _promiseIndexed = Promise.prototype[index]
			
			if _promiseIndexed ~= nil then
				local Typeof = typeof(_promiseIndexed)
				if Typeof == "function" then
					return function(_self, ...)
						assert(rawequal(_self, self) or rawequal(_self, _promise), `Call method {index} does not belong to {_self}`)
						local promiseOrValue = _promiseIndexed(_promise, ...)
						if Promise.is(promiseOrValue) then
							return PromiseHelper.new(nil, promiseOrValue)
						end
						return promiseOrValue
					end
				elseif Typeof ~= "nil" then
					return _promiseIndexed
				end
			end
			
			return PromiseHelper.prototype[index]
		end,
	})
	
	_promise = promise or Promise.new(function(resolve, reject, onCancel)
		onCancel(function()
			self:_destroy()
		end)
		
		executor(resolve, reject, onCancel)
	end)
	
	self._parent = _promise
	
	return self
end

function PromiseHelper:_destroy()
	if self._active then return self end
	
	self:_fireSignalLinks("Destroyed")
	self._active = false
	
	return self
end

function PromiseHelper:_fireSignalLinks(...): PromiseHelper
	if not self._active then return self end
	
	local currentIndex = 0
	
	while currentIndex >= #self.links do
		currentIndex += 1
		self.links[currentIndex]:fire(...)
	end
	
	return self
end

function PromiseHelper.promisify(func)
	local promisified = Promise.promisify(func)
	return function(...)
		return PromiseHelper.new(nil, promisified(...))
	end
end

function PromiseHelper.rawPromisify(func)
	return Promise.promisify(func)
end

function PromiseHelper.wrapify(promise)
	return PromiseHelper.new(nil, promise)
end

function PromiseHelper.prototype:unWrap()
	return self._parent
end

function PromiseHelper.prototype:hook(executor: (Promise) -> any)
	local parentPromise = self._parent or self
	return self:_andThen(debug.traceback(nil, 2), function()
		return PromiseHelper.new(function(resolve, reject, onCancel)
			executor(parentPromise, resolve, reject, onCancel)
		end)
	end)
end

function PromiseHelper.prototype:waitForSignals(signals: {[number]: signal}, timeoutDelay: number?)
	--[[
	return Promise._new(debug.traceback(nil, 2), function(resolve, reject, onCancel)
		local newPromises = {}
		local finished = false

		local function cancel()
			for _, promise in ipairs(newPromises) do
				promise:cancel()
			end
		end

		local function finalize(callback)
			return function(...)
				cancel()
				finished = true
				return callback(...)
			end
		end

		if onCancel(finalize(reject)) then
			return
		end

		for i, promise in ipairs(promises) do
			newPromises[i] = promise:andThen(finalize(resolve), finalize(reject))
		end

		if finished then
			cancel()
		end
	end)
	]]
	
	timeoutDelay = if not timeoutDelay then nil else math.max(timeoutDelay, 0.1)
	for i, signal in signals do
		assert(signal.active, `Signal {signal.id} isn't active`)
	end
	
	
	--TODO: FIX timeouts
	local promise = self
	return self:_andThen(debug.traceback(nil, 2), function()
		return Promise.new(function(resolve, reject, onCancel)
			--warn("did call promise?")
			local signalPromises = {}
			local finished = false
			
			local timeoutTask;
			local function cancel()
				for _, promise in signalPromises do
					promise:cancel()
				end
			end
			
			local function finish(callback)
				return function(...)
					if timeoutTask then
						timeoutTask:cancel()
						timeoutTask = nil
					end
					
					cancel()
					finished = true
					
					
					return callback(...)
				end
			end
			
			--if onCancel(finish(reject)) then
			--	return
			--end
			
			for i, signal in signals do
				signalPromises[i] = PromiseHelper.new(function(resolve, reject, onCancel)
					--warn(`did signal promise {i} start?`)
					if not signal.active then
						reject(`SIGNAL_INACTIVE`)
						return
					end
					
					local signalLink;
					
					if onCancel(function()
						signalLink:disconnect()
					end) then
						signalLink:disconnect()
						return
					end
				
					signalLink = signal:connectOnce(function(...)
						warn(`signal {i} fired`)
						if select("#", ...) > 0 then
							resolve({...})
						else
							resolve(nil)
						end
						--warn(`SIGNAL FIRED IN WAITFORSIGNAL, DID IT RESOLVE?`)
					end)
				end)
					:andThen(finish(resolve), finish(reject))
			end
			
			--warn("did create signal promises?")
			if timeoutDelay then
				timeoutTask = Promise.delay(timeoutDelay)
					:andThen(function()
						--warn(`SIGNALS TIMED OUT TO IDLE`)
						finish(resolve)(nil)
					end)
			end
		end)
	end)
end

function PromiseHelper.prototype:waitOnSignal(signal: any, timeoutDelay: number?)
	timeoutDelay = if not timeoutDelay then nil else math.max(timeoutDelay, 0.1)
	assert(signal.active, `Signal is not active`)
	
	
	return self:_andThen(debug.traceback(nil, 2), function()
		return PromiseHelper.new(function(resolve, reject, onCancel)
			local timeoutTask;
			local signalLink = signal:connectOnce(function(...)
				if timeoutTask then
					task.cancel(timeoutTask)
				end
				resolve({...})
			end)

			if not signalLink then
				reject(`SIGNAL_INACTIVE`)
				return
			end

			onCancel(function()
				signalLink:disconnect()
				if timeoutTask then
					task.cancel(timeoutTask)
				end
			end)

			if timeoutDelay then
				timeoutTask = task.delay(timeoutDelay, function()
					signalLink:disconnect()
					resolve(nil)
				end)
			end
		end)
	end)
end

function PromiseHelper.prototype:fireSignal(signal: any, ...)
	local callArgs = {...}
	
	return self:_andThen(debug.traceback(nil, 2), function()
		return PromiseHelper.new(function(resolve, reject, onCancel)
			if not signal.active then
				reject(`Signal {signal.id} is not active`)
				return
			end
			
			resolve({signal:fire(unpack(callArgs))})
		end)
	end)
end

return PromiseHelper
