local timer = {}
timer.__index = timer

local client, service = nil

function timer.new(data)
	local self = setmetatable({}, timer)
	local object = script.Timer:Clone()
	
	self.active = true
	self._object = object
	
	self.allowUserCreation = data.allowUserCreation or false
	
	self.closeObj = self._object.Close
	self.iconObj = self._object.Icon
	self.ringerObj = self._object.Ringer
	self.inputObj = self._object.Input
	self.resetObj = self._object.Reset
	self.stopObj = self._object.Stop
	self.titleObj = self._object.Title
	self.countdownObj = self._object.Countdown
	
	self.shown = client.Signal.new()
	self.hidden = client.Signal.new()
	self.timerStarted = client.Signal.new()
	self.timerEnded = client.Signal.new()
	
	return self
end

function timer:show()
	if self.active and self.containerData and not self.showState and not self.showDebounce then
		self.showDebounce = true
		self.showState = true
		
	end
end

function timer.Init(env)
	client = env.client
	service = env.service
end


return timer
