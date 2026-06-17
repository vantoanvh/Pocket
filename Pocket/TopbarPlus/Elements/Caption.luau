const CAPTION_COLOR = Color3.fromRGB(39, 41, 48)
const TEXT_SIZE = 15
return function(icon)

	-- Credit to lolmansReturn and Canary Software for
	-- retrieving these values
	const clickRegion = icon:getInstance("ClickRegion")
	const caption = Instance.new("CanvasGroup")
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.BackgroundTransparency = 1
	caption.BorderSizePixel = 0
	caption.GroupTransparency = 1
	caption.Position = UDim2.fromOffset(0, 0)
	caption.Visible = true
	caption.ZIndex = 30
	caption.Parent = clickRegion

	const box = Instance.new("Frame")
	box.Name = "Box"
	box.AutomaticSize = Enum.AutomaticSize.XY
	box.BackgroundColor3 = CAPTION_COLOR
	box.Position = UDim2.fromOffset(4, 7)
	box.ZIndex = 12
	box.Parent = caption

	const header = Instance.new("TextLabel")
	header.Name = "Header"
	header.FontFace = Font.new(
		"rbxasset://fonts/families/BuilderSans.json",
		Enum.FontWeight.Medium,
		Enum.FontStyle.Normal
	)
	header.Text = "Caption"
	header.TextColor3 = Color3.fromRGB(255, 255, 255)
	header.TextSize = TEXT_SIZE
	header.TextTruncate = Enum.TextTruncate.None
	header.TextWrapped = false
	header.AutomaticSize = Enum.AutomaticSize.X
	header.BackgroundTransparency = 1
	header.LayoutOrder = 1
	header.Size = UDim2.fromOffset(0, 16)
	header.ZIndex = 18
	header.Parent = box

	const layout = Instance.new("UIListLayout")
	layout.Name = "Layout"
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = box

	const UICorner = Instance.new("UICorner")
	UICorner.Name = "CaptionCorner"
	UICorner.Parent = box

	const padding = Instance.new("UIPadding")
	padding.Name = "Padding"
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 12)
	padding.Parent = box

	const hotkeys = Instance.new("Frame")
	hotkeys.Name = "Hotkeys"
	hotkeys.AutomaticSize = Enum.AutomaticSize.Y
	hotkeys.BackgroundTransparency = 1
	hotkeys.LayoutOrder = 3
	hotkeys.Size = UDim2.fromScale(1, 0)
	hotkeys.Visible = false
	hotkeys.Parent = box

	const layout1 = Instance.new("UIListLayout")
	layout1.Name = "Layout1"
	layout1.Padding = UDim.new(0, 6)
	layout1.FillDirection = Enum.FillDirection.Vertical
	layout1.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout1.HorizontalFlex = Enum.UIFlexAlignment.None
	layout1.ItemLineAlignment = Enum.ItemLineAlignment.Automatic
	layout1.VerticalFlex = Enum.UIFlexAlignment.None
	layout1.SortOrder = Enum.SortOrder.LayoutOrder
	layout1.Parent = hotkeys

	const keyTag1 = Instance.new("ImageLabel")
	keyTag1.Name = "Key1"
	keyTag1.Image = "rbxasset://textures/ui/Controls/key_single.png"
	keyTag1.ImageTransparency = 0.7
	keyTag1.ScaleType = Enum.ScaleType.Slice
	keyTag1.SliceCenter = Rect.new(5, 5, 23, 24)
	keyTag1.AutomaticSize = Enum.AutomaticSize.X
	keyTag1.BackgroundTransparency = 1
	keyTag1.LayoutOrder = 1
	keyTag1.Size = UDim2.fromOffset(0, 30)
	keyTag1.ZIndex = 15
	keyTag1.Parent = hotkeys

	const inset = Instance.new("UIPadding")
	inset.Name = "Inset"
	inset.PaddingLeft = UDim.new(0, 8)
	inset.PaddingRight = UDim.new(0, 8)
	inset.Parent = keyTag1

	const labelContent = Instance.new("TextLabel")
	labelContent.AutoLocalize = false
	labelContent.Name = "LabelContent"
	labelContent.FontFace = Font.new(
		"rbxasset://fonts/families/GothamSSm.json",
		Enum.FontWeight.Medium,
		Enum.FontStyle.Normal
	)
	labelContent.Text = ""
	labelContent.TextColor3 = Color3.fromRGB(189, 190, 190)
	labelContent.TextSize = TEXT_SIZE
	labelContent.AutomaticSize = Enum.AutomaticSize.X
	labelContent.BackgroundTransparency = 1
	labelContent.Position = UDim2.fromOffset(0, -1)
	labelContent.Size = UDim2.fromScale(1, 1)
	labelContent.ZIndex = 16
	labelContent.Parent = keyTag1
	
	const caret = Instance.new("ImageLabel")
	caret.Name = "Caret"
	caret.Image = "rbxassetid://101906294438076"
	caret.ImageColor3 = CAPTION_COLOR
	caret.AnchorPoint = Vector2.new(0, 0.5)
	caret.BackgroundTransparency = 1
	caret.Position = UDim2.new(0, 0, 0, 4)
	caret.Size = UDim2.fromOffset(16, 8)
	caret.ZIndex = 12
	caret.Parent = caption

	const dropShadow = Instance.new("ImageLabel")
	dropShadow.Visible = true
	dropShadow.Name = "DropShadow"
	dropShadow.Image = "rbxassetid://124920646932671"
	dropShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	dropShadow.ImageTransparency = 0.45
	dropShadow.ScaleType = Enum.ScaleType.Slice
	dropShadow.SliceCenter = Rect.new(12, 12, 13, 13)
	dropShadow.BackgroundTransparency = 1
	dropShadow.Position = UDim2.fromOffset(0, 5)
	dropShadow.Size = UDim2.new(1, 0, 0, 48)
	dropShadow.Parent = caption
	box:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		dropShadow.Size = UDim2.new(1, 0, 0, box.AbsoluteSize.Y + 8)
	end)
	
	-- It's important we match the sizes as this is not
	-- handles within clipOutside (as it assumes the sizes
	-- are already the same)
	const captionJanitor = icon.captionJanitor
	local _, captionClone = icon:clipOutside(caption)
	captionClone.AutomaticSize = Enum.AutomaticSize.None
	const function matchSize()
		const absolute = caption.AbsoluteSize
		captionClone.Size = UDim2.fromOffset(absolute.X, absolute.Y)
	end
	captionJanitor:add(caption:GetPropertyChangedSignal("AbsoluteSize"):Connect(matchSize))
	matchSize()
	
	
	
	-- This handles the appearing/disappearing/positioning of the caption
	local isCompletelyEnabled = false
	const captionHeader = caption.Box.Header
	const UserInputService = game:GetService("UserInputService")
	const function updateHotkey(keyCodeEnum)
		const hasKeyboard = UserInputService.KeyboardEnabled
		const text = caption:GetAttribute("CaptionText") or ""
		const hideHeader = text == "_hotkey_"
		if not hasKeyboard and hideHeader then
			icon:setCaption()
			return
		end
		captionHeader.Text = text
		captionHeader.Visible = not hideHeader
		if keyCodeEnum then
			labelContent.Text = keyCodeEnum.Name
			hotkeys.Visible = true
		end
		if not hasKeyboard then
			hotkeys.Visible = false
		end
	end
	caption:GetAttributeChangedSignal("CaptionText"):Connect(updateHotkey)

	const EASING_STYLE = Enum.EasingStyle.Quad
	const TWEEN_SPEED = 0.2
	const TWEEN_INFO_IN = TweenInfo.new(TWEEN_SPEED, EASING_STYLE, Enum.EasingDirection.In)
	const TWEEN_INFO_OUT = TweenInfo.new(TWEEN_SPEED, EASING_STYLE, Enum.EasingDirection.Out)
	const TweenService = game:GetService("TweenService")
	const RunService = game:GetService("RunService")
	const function getCaptionPosition(customEnabled)
		const enabled = if customEnabled ~= nil then customEnabled else isCompletelyEnabled
		const yOut = 2
		const yIn = yOut + 8
		const yOffset = if enabled then yIn else yOut
		return UDim2.new(0.5, 0, 1, yOffset)
	end
	const function updatePosition(forcedEnabled)
		
		-- Ignore changes if not enabled to reduce redundant calls
		if not isCompletelyEnabled then
			return
		end
		
		-- Currently the one thing which isn't accounted for are the bounds of the screen
		-- This would be an issue if someone sets a long caption text for the left or
		-- right most icon
		const enabled = if forcedEnabled ~= nil then forcedEnabled else isCompletelyEnabled
		const startPosition = getCaptionPosition(not enabled)
		const endPosition = getCaptionPosition(enabled)
		
		-- It's essential we reset the carets position to prevent the x sizing bounds
		-- of the caption from infinitely scaling up
		if enabled then
			const caretY = caret.Position.Y.Offset
			caret.Position = UDim2.fromOffset(0, caretY)
			caption.AutomaticSize = Enum.AutomaticSize.XY
			caption.Size = UDim2.fromOffset(32, 53)
		else
			const absolute = caption.AbsoluteSize
			caption.AutomaticSize = Enum.AutomaticSize.Y
			caption.Size = UDim2.fromOffset(absolute.X, absolute.Y)
		end
		
		-- We initially default to the opposite state
		local previousCaretX
		const function updateCaret()
			const caretX = clickRegion.AbsolutePosition.X - caption.AbsolutePosition.X + clickRegion.AbsoluteSize.X/2 - caret.AbsoluteSize.X/2
			const caretY = caret.Position.Y.Offset
			const newCaretPosition = UDim2.fromOffset(caretX, caretY)
			if previousCaretX ~= caretX then
				-- Again, it's essential we reset the caret if
				-- a difference in X position is detected otherwise
				-- a slight quirk with AutomaticCanvas can cause
				-- the caption to infinitely scale
				previousCaretX = caretX
				caret.Position = UDim2.fromOffset(0, caretY)
				task.wait()
			end
			caret.Position = newCaretPosition
		end
		captionClone.Position = startPosition
		updateCaret()
		
		-- Now we tween into the new state
		const tweenInfo = (enabled and TWEEN_INFO_IN) or TWEEN_INFO_OUT
		const tween = TweenService:Create(captionClone, tweenInfo, {Position = endPosition})
		const updateCaretConnection = RunService.PostSimulation:Connect(updateCaret)
		tween:Play()
		tween.Completed:Once(function()
			updateCaretConnection:Disconnect()
		end)
		
	end
	captionJanitor:add(clickRegion:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		updatePosition()
	end))
	updatePosition(false)
	
	captionJanitor:add(icon.toggleKeyAdded:Connect(updateHotkey))
	for keyCodeEnum, _ in icon.bindedToggleKeys do
		updateHotkey(keyCodeEnum)
		break
	end
	captionJanitor:add(icon.fakeToggleKeyChanged:Connect(updateHotkey))
	const fakeToggleKey = icon.fakeToggleKey
	if fakeToggleKey then
		updateHotkey(fakeToggleKey)
	end

	const function setCaptionEnabled(enabled)
		if isCompletelyEnabled == enabled then
			return
		end
		const joinedFrame = icon.joinedFrame
		if joinedFrame and string.match(joinedFrame.Name, "Dropdown") then
			enabled = false
		end
		isCompletelyEnabled = enabled
		const newTransparency = (enabled and 0) or 1
		const tweenInfo = (enabled and TWEEN_INFO_IN) or TWEEN_INFO_OUT
		const tweenTransparency = TweenService:Create(caption, tweenInfo, {
			GroupTransparency = newTransparency
		})
		tweenTransparency:Play()
		if enabled then
			captionClone:SetAttribute("ForceUpdate", true)
		end
		updatePosition()
		updateHotkey()
	end
	
	const WAIT_DURATION = 0.5
	const RECOVER_PERIOD = 0.3
	const Icon = require(icon.iconModule)
	captionJanitor:add(icon.stateChanged:Connect(function(stateName)
		if stateName == "Viewing" then
			const lastClock = Icon.captionLastClosedClock
			const clockDifference = (lastClock and os.clock() - lastClock) or 999
			const waitDuration = (clockDifference < RECOVER_PERIOD and 0) or WAIT_DURATION
			task.delay(waitDuration, function()
				if icon.activeState == "Viewing" then
					setCaptionEnabled(true)
				end
			end)
		else
			Icon.captionLastClosedClock = os.clock()
			setCaptionEnabled(false)
		end
	end))
	
	return caption
end
