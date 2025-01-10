local script = script
local NameGenerator = {
	_loadedList = {},
}

local _defaultGenerateOptions = table.freeze {
	NoSplitNames = false,
	IncludeSurName = false,
	NumberOfSurNames = 1,
}

function NameGenerator:load()
	local Names = script:FindFirstChild "Names"

	if Names then
		for i, module in pairs(Names:GetChildren()) do
			local category = module.Name
			local moduleData = require(module)

			if not moduleData.FirstNames then
				warn(`NameGenerators: Module {category} is missing FirstNames list`)
				continue
			end
			if not moduleData.SurNames then
				warn(`NameGenerators: Module {category} is missing SurNames list`)
				continue
			end

			NameGenerator._loadedList[category] = moduleData

			if module:GetAttribute "Default" == true and not NameGenerator._loadedList["Default"] then
				NameGenerator._loadedList["Default"] = moduleData
			end
		end

		-- if not NameGenerator.Default then
		-- 	local chosenDefault = math.random(1, math.min(#Names:GetChildren(), 1))
		-- 	for i, module: ModuleScript in Names:GetChildren() do
		-- 		if i == chosenDefault then
		-- 			NameGenerator._loadedList["Default"] = NameGenerator._loadedList[module.Name]
		-- 		end
		-- 	end
		-- end
	end
end

function NameGenerator:generate(generateOptions: {
	NoSplitNames: boolean?,
	IncludeSurName: string?,
	Category: string?,
	NumberOfSurNames: number?,
}): string
	generateOptions = generateOptions or _defaultGenerateOptions

	local Category = generateOptions.Category or "Default"
	assert(NameGenerator._loadedList[Category], `Category {Category} doesn't exist`)

	local CategoryModule: { FirstNames: { [number]: string }, SurNames: { [number]: string } } =
		NameGenerator._loadedList[Category]
	local FirstName = CategoryModule.FirstNames[math.random(1, #CategoryModule.FirstNames)]
	local SurName

	if generateOptions.IncludeSurName then
		local NumberOfSurNames = generateOptions.NumberOfSurNames or 1
		assert(
			NumberOfSurNames > 0 or math.floor(NumberOfSurNames) ~= NumberOfSurNames,
			`Number of Sur Names is not an integer or more than zero`
		)

		SurName = ""

		if #CategoryModule.SurNames > 0 then
			local _chosenSurNames = {}
			for i = 1, math.clamp(NumberOfSurNames, 1, #CategoryModule.SurNames), 1 do
				local ChosenSurname
				repeat
					ChosenSurname = CategoryModule.SurNames[math.random(1, #CategoryModule.SurNames)]
				until not table.find(_chosenSurNames, ChosenSurname) or #_chosenSurNames >= #CategoryModule.SurNames

				table.insert(_chosenSurNames, ChosenSurname)
			end

			SurName = if generateOptions.NoSplitNames
				then table.concat(_chosenSurNames, "")
				else ` ` .. table.concat(_chosenSurNames, " ")
		end
	end

	return if FirstName and not SurName then FirstName else `{FirstName}{SurName}`
end

NameGenerator:load()

return NameGenerator
