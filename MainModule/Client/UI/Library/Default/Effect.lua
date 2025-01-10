
return function(envArgs, data)
	local client = envArgs.client
	local service = envArgs.service

	local variables = envArgs.variables
	
	local dataType = data.type
	
	if dataType == "FadeIn" then
		local screenGui = service.New("ScreenGui")
		local frame = service.New("Frame", {
			BackgroundTransparency = 1;
			BackgroundColor3 = Color3.fromRGB(0, 0, 0);
			Parent = screenGui;
		})
		
		local blur = service.New("Blur",{
			Size = 24;
			Parent = service.Lighting;
		})
		
		local guiData; guiData = {
			hide = function(self)
				
			end;
		}
		
		table.insert(variables.effectUIs, guiData)
		
	end
end