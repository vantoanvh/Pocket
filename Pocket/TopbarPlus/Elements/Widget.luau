-- I named this 'Widget' instead of 'Icon' to make a clear difference between the icon *object* and
-- the icon (aka Widget) instance.
-- This contains the core components of the icon such as the button, image, label and notice. It's
-- also responsible for handling the automatic resizing of the widget (based upon image visibility and text length)

return function(icon, Icon)

	const widget = Instance.new("Frame")
	widget:SetAttribute("WidgetUID", icon.UID)
	widget.Name = "Widget"
	widget.BackgroundTransparency = 1
	widget.Visible = true
	widget.ZIndex = 20
	widget.Active = false
	widget.ClipsDescendants = true

	const button = Instance.new("Frame")
	button.Name = "IconButton"
	button.Visible = true
	button.ZIndex = 2
	button.BorderSizePixel = 0
	button.Parent = widget
	button.ClipsDescendants = true
	button.Active = false -- This is essential for mobile scrollers to work when dragging
	icon.deselected:Connect(function()
		button.ClipsDescendants = true
		task.delay(0.2, function()
			if icon.isSelected then
				button.ClipsDescendants = false
			end
		end)
	end)

	-- Account for PreferredTransparency which can be set by every player
	const GuiService = game:GetService("GuiService")
	icon:setBehaviour("IconButton", "BackgroundTransparency", function(value)
		const preference = GuiService.PreferredTransparency
		const newValue = value * preference
		if value == 1 then
			return value
		end
		return newValue
	end)
	icon.janitor:add(GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(function()
		icon:refreshAppearance(button, "BackgroundTransparency")
	end))

	const iconCorner = Instance.new("UICorner")
	iconCorner:SetAttribute("Collective", "IconCorners")
	iconCorner.Name = "UICorner"
	iconCorner.Parent = button

	const menu = require(script.Parent.Menu)(icon)
	const menuUIListLayout = menu.MenuUIListLayout
	const menuGap = menu.MenuGap
	menu.Parent = button

	const iconSpot = Instance.new("Frame")
	iconSpot.Name = "IconSpot"
	iconSpot.BackgroundColor3 = Color3.fromRGB(225, 225, 225)
	iconSpot.BackgroundTransparency = 0.9
	iconSpot.Visible = true
	iconSpot.AnchorPoint = Vector2.new(0, 0.5)
	iconSpot.ZIndex = 5
	iconSpot.Parent = menu

	const iconSpotCorner = iconCorner:Clone()
	iconSpotCorner.Parent = iconSpot

	const overlay = iconSpot:Clone()
	overlay.UICorner.Name = "OverlayUICorner"
	overlay.Name = "IconOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	overlay.ZIndex = iconSpot.ZIndex + 1
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.AnchorPoint = Vector2.zero
	overlay.Visible = false
	overlay.Parent = iconSpot

	const clickRegion = Instance.new("TextButton")
	clickRegion:SetAttribute("CorrespondingIconUID", icon.UID)
	clickRegion.Name = "ClickRegion"
	clickRegion.BackgroundTransparency = 1
	clickRegion.Visible = true
	clickRegion.Text = ""
	clickRegion.ZIndex = 20
	clickRegion.Selectable = true
	clickRegion.SelectionGroup = true
	clickRegion.Parent = iconSpot
	
	const Gamepad = require(script.Parent.Parent.Features.Gamepad)
	Gamepad.registerButton(clickRegion)

	const clickRegionCorner = iconCorner:Clone()
	clickRegionCorner.Parent = clickRegion

	const contents = Instance.new("Frame")
	contents.Name = "Contents"
	contents.BackgroundTransparency = 1
	contents.Size = UDim2.fromScale(1, 1)
	contents.Parent = iconSpot

	const contentsList = Instance.new("UIListLayout")
	contentsList.Name = "ContentsList"
	contentsList.FillDirection = Enum.FillDirection.Horizontal
	contentsList.VerticalAlignment = Enum.VerticalAlignment.Center
	contentsList.SortOrder = Enum.SortOrder.LayoutOrder
	contentsList.VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly
	contentsList.Padding = UDim.new(0, 3)
	contentsList.Parent = contents

	const paddingLeft = Instance.new("Frame")
	paddingLeft.Name = "PaddingLeft"
	paddingLeft.LayoutOrder = 1
	paddingLeft.ZIndex = 5
	paddingLeft.BorderColor3 = Color3.fromRGB(0, 0, 0)
	paddingLeft.BackgroundTransparency = 1
	paddingLeft.BorderSizePixel = 0
	paddingLeft.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	paddingLeft.Parent = contents

	const paddingCenter = Instance.new("Frame")
	paddingCenter.Name = "PaddingCenter"
	paddingCenter.LayoutOrder = 3
	paddingCenter.ZIndex = 5
	paddingCenter.Size = UDim2.new(0, 0, 1, 0)
	paddingCenter.BorderColor3 = Color3.fromRGB(0, 0, 0)
	paddingCenter.BackgroundTransparency = 1
	paddingCenter.BorderSizePixel = 0
	paddingCenter.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	paddingCenter.Parent = contents

	const paddingRight = Instance.new("Frame")
	paddingRight.Name = "PaddingRight"
	paddingRight.LayoutOrder = 5
	paddingRight.ZIndex = 5
	paddingRight.BorderColor3 = Color3.fromRGB(0, 0, 0)
	paddingRight.BackgroundTransparency = 1
	paddingRight.BorderSizePixel = 0
	paddingRight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	paddingRight.Parent = contents

	const iconLabelContainer = Instance.new("Frame")
	iconLabelContainer.Name = "IconLabelContainer"
	iconLabelContainer.LayoutOrder = 4
	iconLabelContainer.ZIndex = 3
	iconLabelContainer.AnchorPoint = Vector2.new(0, 0.5)
	iconLabelContainer.Size = UDim2.new(0, 0, 0.5, 0)
	iconLabelContainer.BackgroundTransparency = 1
	iconLabelContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconLabelContainer.Parent = contents

	const iconLabel = Instance.new("TextLabel")
	const viewportX = workspace.CurrentCamera.ViewportSize.X+200
	iconLabel.Name = "IconLabel"
	iconLabel.LayoutOrder = 4
	iconLabel.ZIndex = 15
	iconLabel.AnchorPoint = Vector2.zero
	iconLabel.Size = UDim2.new(0, viewportX, 1, 0)
	iconLabel.ClipsDescendants = false
	iconLabel.BackgroundTransparency = 1
	iconLabel.Position = UDim2.fromScale(0, 0)
	iconLabel.RichText = true
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.TextXAlignment = Enum.TextXAlignment.Left
	iconLabel.Text = ""
	iconLabel.TextWrapped = true
	iconLabel.TextScaled = false
	iconLabel.Active = false
	iconLabel.AutoLocalize = true
	iconLabel.Parent = iconLabelContainer

	const iconImage = Instance.new("ImageLabel")
	iconImage.Name = "IconImage"
	iconImage.LayoutOrder = 2
	iconImage.ZIndex = 15
	iconImage.AnchorPoint = Vector2.new(0, 0.5)
	iconImage.Size = UDim2.new(0, 0, 0.5, 0)
	iconImage.BackgroundTransparency = 1
	iconImage.Position = UDim2.new(0, 11, 0.5, 0)
	iconImage.ScaleType = Enum.ScaleType.Stretch
	iconImage.Active = false
	iconImage.Parent = contents

	const iconImageCorner = iconCorner:Clone()
	iconImageCorner:SetAttribute("Collective", nil)
	iconImageCorner.CornerRadius = UDim.new(0, 0)
	iconImageCorner.Name = "IconImageCorner"
	iconImageCorner.Parent = iconImage

	const TweenService = game:GetService("TweenService")
	local resizingCount = 0
	const function handleLabelAndImageChangesUnstaggered(forceUpdateString)

		-- We defer changes by a frame to eliminate all but 1 requests which
		-- could otherwise stack up to 20+ requests in a single frame
		-- We then repeat again once to account for any final changes
		-- Deferring is also essential because properties are set immediately
		-- afterwards (therefore calculations will use the correct values)
		task.defer(function()
			const indicator = icon.indicator
			const usingIndicator = indicator and indicator.Visible
			const usingText = usingIndicator or iconLabel.Text ~= ""
			const usingImage = iconImage.Image ~= "" and iconImage.Image ~= nil
			local _alignment = Enum.HorizontalAlignment.Center
			const NORMAL_BUTTON_SIZE = UDim2.fromScale(1, 1)
			const buttonSize = NORMAL_BUTTON_SIZE
			if usingImage and not usingText then
				iconLabelContainer.Visible = false
				iconImage.Visible = true
				paddingLeft.Visible = false
				paddingCenter.Visible = false
				paddingRight.Visible = false
			elseif not usingImage and usingText then
				iconLabelContainer.Visible = true
				iconImage.Visible = false
				paddingLeft.Visible = true
				paddingCenter.Visible = false
				paddingRight.Visible = true
			elseif usingImage and usingText then
				iconLabelContainer.Visible = true
				iconImage.Visible = true
				paddingLeft.Visible = true
				paddingCenter.Visible = not usingIndicator
				paddingRight.Visible = not usingIndicator
				_alignment = Enum.HorizontalAlignment.Left
			end
			button.Size = buttonSize

			const function getItemWidth(item)
				const targetWidth = item:GetAttribute("TargetWidth") or item.AbsoluteSize.X
				return targetWidth
			end
			const contentsPadding = contentsList.Padding.Offset
			local initialWidgetWidth = contentsPadding --0
			const textWidth = iconLabel.TextBounds.X
			iconLabelContainer.Size = UDim2.new(0, textWidth, iconLabel.Size.Y.Scale, 0)
			for _, child in contents:GetChildren() do
				if child:IsA("GuiObject") and child.Visible == true then
					const itemWidth = getItemWidth(child)
					initialWidgetWidth += itemWidth + contentsPadding
				end
			end
			const widgetMinimumWidth = widget:GetAttribute("MinimumWidth")
			const widgetMinimumHeight = widget:GetAttribute("MinimumHeight")
			const widgetBorderSize = widget:GetAttribute("BorderSize")
			local widgetWidth = math.clamp(initialWidgetWidth, widgetMinimumWidth, viewportX)
			const menuIcons = icon.menuIcons
			local additionalWidth = 0
			const hasMenu = #menuIcons > 0
			const showMenu = hasMenu and icon.isSelected
			if showMenu then
				for _, frame in menu:GetChildren() do
					if frame ~= iconSpot and frame:IsA("GuiObject") and frame.Visible then
						additionalWidth += getItemWidth(frame) + menuUIListLayout.Padding.Offset
					end
				end
				if not iconSpot.Visible then
					widgetWidth -= (getItemWidth(iconSpot) + menuUIListLayout.Padding.Offset*2 + widgetBorderSize)
				end
				additionalWidth -= (widgetBorderSize*0.5)
				widgetWidth += additionalWidth - (widgetBorderSize*0.75)
			end
			menuGap.Visible = showMenu and iconSpot.Visible
			const desiredWidth = widget:GetAttribute("DesiredWidth")
			if desiredWidth and widgetWidth < desiredWidth then
				widgetWidth = desiredWidth
			end

			icon.updateMenu:Fire()
			const preWidth = math.max(widgetWidth-additionalWidth, widgetMinimumWidth)
			const spotWidth = preWidth-(widgetBorderSize*2)
			const menuWidth = menu:GetAttribute("MenuWidth")
			local totalMenuWidth = menuWidth and menuWidth + spotWidth + menuUIListLayout.Padding.Offset + 10
			if totalMenuWidth then
				const maxWidth = menu:GetAttribute("MaxWidth")
				if maxWidth then
					totalMenuWidth = math.max(maxWidth, widgetMinimumWidth)
				end
				menu:SetAttribute("MenuCanvasWidth", widgetWidth)
				if totalMenuWidth < widgetWidth then
					widgetWidth = totalMenuWidth
				end
			end

			const style = Enum.EasingStyle.Quint
			const direction = Enum.EasingDirection.Out
			const spotWidthMax = math.max(spotWidth, getItemWidth(iconSpot), iconSpot.AbsoluteSize.X)
			const widgetWidthMax = math.max(widgetWidth, getItemWidth(widget), widget.AbsoluteSize.X)
			const SPEED = 750
			const spotTweenInfo = TweenInfo.new(spotWidthMax/SPEED, style, direction)
			const widgetTweenInfo = TweenInfo.new(widgetWidthMax/SPEED, style, direction)
			TweenService:Create(iconSpot, spotTweenInfo, {
				Position = UDim2.new(0, widgetBorderSize, 0.5, 0),
				Size = UDim2.new(0, spotWidth, 1, -widgetBorderSize*2),
			}):Play()
			TweenService:Create(clickRegion, spotTweenInfo, {
				Size = UDim2.new(0, spotWidth, 1, 0),
			}):Play()
			const newWidgetSize = UDim2.fromOffset(widgetWidth, widgetMinimumHeight)
			const updateInstantly = widget.Size.Y.Offset ~= widgetMinimumHeight
			if updateInstantly then
				widget.Size = newWidgetSize
			end
			widget:SetAttribute("TargetWidth", newWidgetSize.X.Offset)
			const movingTween = TweenService:Create(widget, widgetTweenInfo, {
				Size = newWidgetSize,
			})
			movingTween:Play()
			resizingCount += 1
			for i = 1, widgetTweenInfo.Time * 100 do
				task.delay(i/100, function()
					Icon.iconChanged:Fire(icon)
				end)
			end
			task.delay(widgetTweenInfo.Time-0.2, function()
				resizingCount -= 1
				task.defer(function()
					if resizingCount == 0 then
						icon.resizingComplete:Fire()
					end
				end)
			end)
			icon:updateParent()
		end)
	end
	const Utility = require(script.Parent.Parent.Utility)
	const handleLabelAndImageChanges = Utility.createStagger(0.01, handleLabelAndImageChangesUnstaggered)
	local firstTimeSettingFontFace = true
	icon:setBehaviour("IconLabel", "Text", handleLabelAndImageChanges)
	icon:setBehaviour("IconLabel", "FontFace", function(value)
		const previousFontFace = iconLabel.FontFace
		if previousFontFace == value then
			return
		end
		task.spawn(function()
			--[[
			local fontLink = value.Family
			if string.match(fontLink, "rbxassetid://") then
				local ContentProvider = game:GetService("ContentProvider")
				local assets = {fontLink}
				ContentProvider:PreloadAsync(assets)
			end--]]

			-- Afaik there's no way to determine when a Font Family has
			-- loaded (even with ContentProvider), so we just have to try
			-- a few times and hope it loads within the refresh period
			handleLabelAndImageChanges()
			if firstTimeSettingFontFace then
				firstTimeSettingFontFace = false
				for i = 1, 10 do
					task.wait(1)
					handleLabelAndImageChanges()
				end
			end
		end)
	end)
	const function updateBorderSize()
		task.defer(function()
			const borderOffset = widget:GetAttribute("BorderSize")
			const alignment = icon.alignment
			const alignmentOffset = (iconSpot.Visible == false and 0) or (alignment == "Right" and -borderOffset) or borderOffset
			menu.Position = UDim2.new(0, alignmentOffset, 0, 0)
			menuGap.Size = UDim2.fromOffset(borderOffset, 0)
			menuUIListLayout.Padding = UDim.new(0, 0)
			handleLabelAndImageChanges()
		end)
	end
	icon:setBehaviour("Widget", "BorderSize", updateBorderSize)
	icon:setBehaviour("IconSpot", "Visible", updateBorderSize)
	icon.startMenuUpdate:Connect(handleLabelAndImageChanges)
	icon.updateSize:Connect(handleLabelAndImageChanges)
	icon:setBehaviour("ContentsList", "HorizontalAlignment", handleLabelAndImageChanges)
	icon:setBehaviour("Widget", "Visible", handleLabelAndImageChanges)
	icon:setBehaviour("Widget", "DesiredWidth", handleLabelAndImageChanges)
	icon:setBehaviour("Widget", "MinimumWidth", handleLabelAndImageChanges)
	icon:setBehaviour("Widget", "MinimumHeight", handleLabelAndImageChanges)
	icon:setBehaviour("Indicator", "Visible", handleLabelAndImageChanges)
	icon:setBehaviour("IconImageRatio", "AspectRatio", handleLabelAndImageChanges)
	icon:setBehaviour("IconImage", "Image", function(value)
		const textureId = (tonumber(value) and "http://www.roblox.com/asset/?id="..value) or value or ""
		if iconImage.Image ~= textureId then
			handleLabelAndImageChanges()
		end
		return textureId
	end)
	icon.alignmentChanged:Connect(function(newAlignment)
		if newAlignment == "Center" then
			newAlignment = "Left"
		end
		menuUIListLayout.HorizontalAlignment = Enum.HorizontalAlignment[newAlignment]
		updateBorderSize()
	end)

	-- Localization support (refresh icon size whenever player changes language changes in-game)
	const Players = game:GetService("Players")
	const localPlayer = Players.LocalPlayer
	local lastLocaleId = localPlayer.LocaleId
	icon.janitor:add(localPlayer:GetPropertyChangedSignal("LocaleId"):Connect(function()
		task.delay(0.2, function()
			const newLocaleId = localPlayer.LocaleId
			if newLocaleId ~= lastLocaleId then
				lastLocaleId = newLocaleId
				icon:refresh()
				task.wait(0.5)
				icon:refresh()
			end
		end)
	end))
	
	const iconImageScale = Instance.new("NumberValue")
	iconImageScale.Name = "IconImageScale"
	iconImageScale.Parent = iconImage
	iconImageScale:GetPropertyChangedSignal("Value"):Connect(function()
		iconImage.Size = UDim2.new(iconImageScale.Value, 0, iconImageScale.Value, 0)
	end)

	const UIAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
	UIAspectRatioConstraint.Name = "IconImageRatio"
	UIAspectRatioConstraint.AspectType = Enum.AspectType.FitWithinMaxSize
	UIAspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
	UIAspectRatioConstraint.Parent = iconImage

	const iconGradient = Instance.new("UIGradient")
	iconGradient.Name = "IconGradient"
	iconGradient.Enabled = true
	iconGradient.Parent = button

	const iconSpotGradient = Instance.new("UIGradient")
	iconSpotGradient.Name = "IconSpotGradient"
	iconSpotGradient.Enabled = true
	iconSpotGradient.Parent = iconSpot

	return widget
end
