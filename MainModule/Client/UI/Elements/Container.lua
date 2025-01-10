local container = {}
container.__index = container

local client = nil
local service = nil

function container.new(data)
	data = data or {}
	local self = setmetatable({}, container)
	
	self._object = data.object or Instance.new("ScreenGui")
	self._object.ResetOnSpawn = false
	self._object.Name = `ESSCU-{service.getRandom(12)}`
	self._object.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.savedItems = {}
	self.loadedSavedItems = {}
	self.guiTags = {}
	
	if data.type == "Messages" then
		self._messages = {}

		function self:hideMessages()
			for i,msg in pairs(self._messages) do
				msg:hide()
			end
		end
	end
	
	self.active = true
	
	self._shown = client.Signal.new()
	self._hidden = client.Signal.new()
	
	return self
end

function container:save()
	for i,child in pairs(self.savedItems) do
		service.Delete(child)
	end
	
	table.clear(self.savedItems)
	
	local shallowCopy = service.shallowCopy
	
	for i,gui in pairs(self._object:GetChildren()) do
		local copy = shallowCopy(gui)
		
		if copy then
			table.insert(self.savedItems, gui)
		end
	end
end

function container:loadSave()
	for i,child in pairs(self.loadedSavedItems) do
		service.Delete(child)
	end
	table.clear(self.loadedSavedItems)
	
	local children = self._object:children()
	
	for i,child in pairs(children) do
		service.Delete(child)
	end
	
	for i,gui in pairs(self.savedItems) do
		local copy = gui:Clone()

		if copy then
			gui.Parent = self._object
			table.insert(self.loadedSavedItems, gui)
		end
	end
end

function container:hasSavedItemsLoaded()
	if #self.loadedSavedItems > 0 then
		for i,child in pairs(self.loadedSavedItems) do
			if child.Parent ~= self._object then
				return false
			end
		end
		
		return true
	end
end

function container:isShown()
	if self.active and self.parent then
		return self._object.Parent == self.parent
	end
end

function container:show()
	if self.active and self.parent and not self.shown and not self:isShown() then
		if not coroutine.resume(coroutine.create(function()
			self._object.Enabled = true
			self._object.Parent = self.parent
		end)) then
			self.shown = false
			
			self._object = Instance.new("ScreenGui")
			self._object.ResetOnSpawn = false
			self._object.Name = service.getRandom()
			
			if #self.savedItems > 0 then
				self:loadSave()
			end
			
			return self:show()
		end
	
		self.shown = true
		self._shown:fire()
	end
end

function container:hide()
	if self.active and self.parent and self:isShown() then
		self.shown = false
		self._object.Enabled = false
		self._object.Parent = nil
		self._hidden:fire()
	end
end

function container:reConstruct()
	if self.active and self.parent then
		if self.shown then
			self.shown = false
			self._hidden:fire()
		end
		
		local objClassName = self._object.ClassName
		if self._object then
			service.Debris:AddItem(self._object, 0)
		end
		
		self._object = service.New(objClassName)
		self._object.ResetOnSpawn = false
		self._object.Name = service.getRandom()
		self._object.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	end
end

function container:destroy()
	if self.active then
		pcall(function() self._object:Destroy() end)
		self.active = false
	end
end

function container.Init(env)
	client = env.client
	service = env.service
end

return container
