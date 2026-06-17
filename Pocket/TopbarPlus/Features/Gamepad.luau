-- As the name suggests, this handles everything related to gamepads
-- (i.e. Xbox or Playstation controllers) and their navigation
-- I created a separate module for gamepads (and not touchpads or
-- keyboards) because gamepads are greatly more unqiue and require
-- additional tailored programming



-- SERVICES
const GamepadService = game:GetService("GamepadService")
const UserInputService = game:GetService("UserInputService")
const GuiService = game:GetService("GuiService")



-- LOCAL
const DEFAULT_HIGHLIGHT_KEY = Enum.KeyCode.DPadUp -- The default key to highlight the topbar icon
const GAMEPAD_INPUT = Enum.PreferredInput.Gamepad
const Gamepad = {}
local Icon



-- FUNCTIONS
-- This is called upon the Icon initializing
function Gamepad.start(incomingIcon)
	
	-- Public variables
	Icon = incomingIcon
	Icon.highlightKey = if Icon.highlightKey ~= nil then Icon.highlightKey else DEFAULT_HIGHLIGHT_KEY -- What controller key to highlight the topbar (or set to false to disable)
	Icon.highlightIcon = false -- Change to a specific icon if you'd like to highlight a specific icon instead of the left-most
	
	-- We defer so the developer can make changes before the
	-- gamepad controls are initialized
	task.delay(1, function()
		-- Some local utility
		const iconsDict = Icon.iconsDictionary
		const function getIconFromSelectedObject()
			const clickRegion = GuiService.SelectedObject
			const iconUID = clickRegion and clickRegion:GetAttribute("CorrespondingIconUID")
			const icon = iconUID and iconsDict[iconUID]
			return icon
		end
		
		-- This enables users to instantly open up their last selected icon
		local previousHighlightedIcon
		local usedIndicatorOnce = DEFAULT_HIGHLIGHT_KEY ~= Icon.highlightKey
		local usedBOnce = DEFAULT_HIGHLIGHT_KEY ~= Icon.highlightKey
		const Selection = require(script.Parent.Parent.Elements.Selection)
		const function updateSelectedObject()
			const icon = getIconFromSelectedObject()
			const isUsingGamepad = UserInputService.PreferredInput == GAMEPAD_INPUT
			if icon then
				if isUsingGamepad then
					const clickRegion = icon:getInstance("ClickRegion")
					local selection = icon.selection
					if not selection then
						selection = icon.janitor:add(Selection(Icon))
						selection:SetAttribute("IgnoreVisibilityUpdater", true)
						selection.Parent = icon.widget
						icon.selection = selection
						icon:refreshAppearance(selection) --icon:clipOutside(selection)
					end
					clickRegion.SelectionImageObject = selection.Selection
				end
				if previousHighlightedIcon and previousHighlightedIcon ~= icon then
					previousHighlightedIcon:setIndicator()
				end
				const newIndicator = if isUsingGamepad and not usedBOnce and not icon.parentIconUID then Enum.KeyCode.ButtonB else nil
				previousHighlightedIcon = icon
				Icon.lastHighlightedIcon = icon
				icon:setIndicator(newIndicator)
			else
				const newIndicator = if isUsingGamepad and not usedIndicatorOnce then Icon.highlightKey else nil
				if not previousHighlightedIcon then
					previousHighlightedIcon = Gamepad.getIconToHighlight()
				end
				if newIndicator == Icon.highlightKey then
					-- We only display the highlightKey once to show
					-- the user how to highlight the topbar icon
					usedIndicatorOnce = true
				else
					--usedBOnce = true
				end
				if previousHighlightedIcon then
					previousHighlightedIcon:setIndicator(newIndicator)
				end
			end
		end
		GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(updateSelectedObject)

		-- This listens for a gamepad being present/added/removed
		const function preferredInputChanged()
			const preferredInput = UserInputService.PreferredInput
			const isUsingGamepad = preferredInput == GAMEPAD_INPUT

			if not isUsingGamepad then
				usedIndicatorOnce = false
				usedBOnce = false
			end
			updateSelectedObject()
		end
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(preferredInputChanged)
		preferredInputChanged()

		-- This allows for easy highlighting of the topbar when the
		-- when ``Icon.highlightKey`` (i.e. DPadUp) is pressed.
		-- If you'd like to disable, do ``Icon.highlightKey = false``
		UserInputService.InputBegan:Connect(function(input, touchingAnObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				-- Sometimes the Roblox gamepad glitches when combined with a cursor
				-- This fixes that by unhighlighting if the cursor is pressed down
				-- (i.e. a mouse click)
				const icon = getIconFromSelectedObject()
				if icon then
					GuiService.SelectedObject = nil
				end
				return
			end
			if input.KeyCode ~= Icon.highlightKey then
				return
			end
			const iconToHighlight = Gamepad.getIconToHighlight()
			if iconToHighlight then
				if GamepadService.GamepadCursorEnabled then
					task.wait(0.2)
					GamepadService:DisableGamepadCursor()
				end
				const clickRegion = iconToHighlight:getInstance("ClickRegion")
				GuiService.SelectedObject = clickRegion
			end
		end)
	end)
end

function Gamepad.getIconToHighlight()
	-- If an icon has already been selected, returns the last selected icon
	-- Else if more than 0 icons, it selects the left-most icon
	const iconsDict = Icon.iconsDictionary
	local iconToHighlight = Icon.highlightIcon or Icon.lastHighlightedIcon
	if not iconToHighlight then
		local currentX
		for _, icon in iconsDict do
			if icon.parentIconUID then
				continue
			end
			const thisX = icon.widget.AbsolutePosition.X
			if not currentX or thisX < currentX then
				iconToHighlight = icon
				currentX = iconToHighlight.widget.AbsolutePosition.X
			end
		end
	end
	return iconToHighlight
end

-- This called when the icon's ClickRegion is created
function Gamepad.registerButton(buttonInstance)
	-- This provides a basic level of support for controllers by making
	-- the icons easy to highlight via the virtual cursor, then
	-- when selected, focuses in on the selected icon and hops
	-- between other nearby icons simply by toggling the joystick
	local inputBegan = false
	buttonInstance.InputBegan:Connect(function(input)
		-- Two wait frames required to ensure inputBegan is detected within
		-- UserInputService.InputBegan. We do this because object.InputBegan
		-- does not return the correct input objects (unlike the service)
		inputBegan = true
		task.wait()
		task.wait()
		inputBegan = false
	end)
	const connection = UserInputService.InputBegan:Connect(function(input)
		task.wait()
		if input.KeyCode == Enum.KeyCode.ButtonA and inputBegan then
			-- We focus on an icon when selected via the virtual cursor
			task.wait(0.2)
			GamepadService:DisableGamepadCursor()
			GuiService.SelectedObject = buttonInstance
			return
		end
		const isSelected = GuiService.SelectedObject == buttonInstance
		const unselectKeyCodes = {"ButtonB", "ButtonSelect"}
		const keyName = input.KeyCode.Name
		if table.find(unselectKeyCodes, keyName) and isSelected then
			-- We unfocus when back button is pressed, but ignore
			-- if the virtual cursor is disabled otherwise it will be
			-- impossible to select the topbar
			if not(keyName == "ButtonSelect" and not GamepadService.GamepadCursorEnabled) then
				GuiService.SelectedObject = nil
			end
		end
	end)
	buttonInstance.Destroying:Once(function()
		connection:Disconnect()
	end)
end



return Gamepad
