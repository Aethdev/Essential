
return function(envArgs)
	local client = envArgs.client
	local service = envArgs.service
	local base64 = client.Base64
	
	local Remote = client.Remote
	local Signal = client.Signal
	
	local isClientAlive = client.IsAlive
	local kill = client.Kill
	
	local ExploitTests = {
		TamperTextboxCheck = true;
		SuspiciousLogger = true;
	}
	
	local WordTamperDetections = {
		-- Admin commands
		"c2h1dGRvd24="; "YWRtaW4="; "a2lsbA=="; "c2NyaXB0"; "ZXhwbG9pdA==";
		"YWRtaW4=";
	}
	
	local function addClientLog(res: string)
		Remote.sendRemoteLog(`SecureProtect :: {res}`)
	end
	
	if ExploitTests.TamperTextboxCheck then
		local tamperLoopName = `_SECUREPROTECT-TEST0001`
		local _testFailed = false
		local function initiateTamperTest()
			if not isClientAlive() then return end
			if _testFailed then return end
			
			local _testComplete = false
			local _testEvents = {}
			
			local function killEvents()
				for i, event in _testEvents do
					event:Disconnect()
					_testEvents[i] = nil
				end
				
				if next(_testEvents) then
					killEvents()
				end
			end
			
			local function failTest(res)
				if not _testFailed and not _testComplete then
					task.defer(function()
						if not _testFailed and not _testComplete then
							_testFailed = true
							killEvents()
							task.spawn(service.stopLoop, tamperLoopName)
							task.delay(2, kill(), `SecureProtect Test 0001: {res or "No reason specified"}`)
							addClientLog(`Test 0001 failed. {res or "No reason specified"}`)
						end
					end)
				end
			end
			
			local function completeTest()
				if not _testComplete then
					_testComplete = true
					killEvents()
				end
			end
			
			local function protectElement(object, focusProps)
				focusProps = focusProps or nil
				
				local objectChanged = Signal.new()
				objectChanged:linkRbxEvent(object.Changed)
				objectChanged:connect(function(property)
					if #focusProps > 0 and not table.find(focusProps, property) then return end
					if _testComplete then return end
					
					failTest(`Object {tostring(object:GetFullName())} was modified while the test was not finished`)
					warn(`Object {tostring(object:GetFullName())} was modified while the test was not finished`, property)
				end)
				table.insert(_testEvents, objectChanged)
			end
			
			local tempScreenGui = service.New("ScreenGui", {
				Name = service.getRandomV3();
				ResetOnSpawn = false;
				Enabled = true;
				AutoLocalize = false;
			})
			
			tempScreenGui.Parent = service.playerGui
			protectElement(tempScreenGui)
			
			local textBox = service.New("TextBox", {
				Text = "";
				TextEditable = false;
				Visible = false;
				TextTransparency = 1;
				BackgroundTransparency = 1;
				Position = UDim2.new(1,0,0,0);
				Size = UDim2.new(0,1,0,1);
				BorderSizePixel = 0;
				Parent = tempScreenGui;
			})
			
			protectElement(textBox, {"Parent", "Visible", "Size", "Position"})
			
			local _testInput = ""
			for i, encodedWord in WordTamperDetections do
				local realWord = base64.decode(encodedWord)
				_testInput = realWord
				textBox.Text = _testInput
				
				local waitEvent = Signal.new()
				waitEvent.debug = true
				waitEvent:linkRbxEvent(textBox:GetPropertyChangedSignal"Text")
				waitEvent:wait(nil, 1)
				
				if textBox.Text ~= _testInput then
					failTest(`Text {realWord} was suspiciously filtered?`)
					return
				end
			end
			
			if _testFailed then return end
			completeTest()
			service.Debris:AddItem(tempScreenGui, 1)
			service.Debris:AddItem(textBox, 1)
			addClientLog(`Test 0001 successfully passed`)
		end
		
		initiateTamperTest()
		task.delay(120, function()
			if not _testFailed then
				service.loopTask(tamperLoopName, 120, initiateTamperTest)
			end
		end)
	end
end