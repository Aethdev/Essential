
return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service

	local variables = envArgs.variables
	local object = data.object
	
	if typeof(object) == "Instance" and object:IsA"GuiObject" then
		local existingZoom = variables.ZoomIn
		
		if existingZoom then
			existingZoom:close()
		end
		
		local playerGui = service.playerGui
		
		if not playerGui then
			return
		end
		
		local zoomIn = {}
		

		local ZoomIn = service.New("ScreenGui")
		local Frame = service.New("Frame")
		local MainObject = service.New"TextLabel")
		local Sign = service.New("TextLabel")

		--Properties:

		ZoomIn.Name = "ZoomIn"
		ZoomIn.Enabled = false
		ZoomIn.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		ZoomIn.ResetOnSpawn = false
		
		Frame.Parent = ZoomIn
		Frame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
		Frame.BackgroundTransparency = 0.4
		Frame.Size = UDim2.new(1, 0, 1, 0)
		
		MainObject.Name = "MainObject"
		MainObject.Parent = Frame
		MainObject.AnchorPoint = Vector2.new(0.5, 0.5)
		MainObject.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		MainObject.BackgroundTransparency = 1
		MainObject.Position = UDim2.new(0.5, 0, 0.5, 0)
		MainObject.Size = UDim2.new(0.6, 0, 0.6, 0)
		MainObject.Font = Enum.Font.SourceSans
		MainObject.Text = "Hello"
		MainObject.TextColor3 = Color3.fromRGB(255, 255, 255)
		MainObject.TextScaled = true
		MainObject.TextSize = 14
		MainObject.TextWrapped = true
		
		Sign.Name = "Sign"
		Sign.Parent = Frame
		Sign.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Sign.BackgroundTransparency = 1
		Sign.Position = UDim2.new(0, 20, 0, 20)
		Sign.Size = UDim2.new(0, 332, 0, 20)
		Sign.Font = Enum.Font.SourceSansSemibold
		Sign.Text = "Press anywhere to close"
		Sign.TextColor3 = Color3.fromRGB(250, 250, 250)
		Sign.TextScaled = true
		Sign.TextSize = 14
		Sign.TextWrapped = true
		Sign.TextXAlignment = Enum.TextXAlignment.Left
		
		function zoomIn:show()
			local tween1 = service.TweenService:create(MainObject, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
				Size = UDim2.new(0.6, 0, 0.6, 0);
			})
			
			tween1:Play()
		end
		
		variables.ZoomIn = zoomIn
	end
end