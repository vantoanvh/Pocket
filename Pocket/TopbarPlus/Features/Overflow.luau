-- When designing your game for many devices and screen sizes, icons may occasionally
-- particularly for smaller devices like phones, overlap with other icons or the bounds
-- of the screen. The overflow handler solves this challenge by moving the out-of-bounds
-- icon into an overflow menu (with a limited scrolling canvas) preventing overlaps occuring



-- LOCAL
const Overflow = {}
const holders = {}
const orderedAvailableIcons = {}
local iconsDict
const currentCamera = workspace.CurrentCamera
const overflowIcons = {}
const overflowIconUIDs = {}
const Utility = require(script.Parent.Parent.Utility)
local beginCheckingCenterIcons = false
local beganSecondaryCenterCheck = false
local Icon



-- FUNCTIONS
-- This is called upon the Icon initializing
function Overflow.start(incomingIcon)
	Icon = incomingIcon
	iconsDict = Icon.iconsDictionary
	local primaryScreenGui
	for _, screenGui in Icon.container do
		if primaryScreenGui == nil and screenGui.ScreenInsets == Enum.ScreenInsets.TopbarSafeInsets then
			primaryScreenGui = screenGui
		end
		for _, holder in screenGui.Holders:GetChildren() do
			if holder:GetAttribute("IsAHolder") then
				holders[holder.Name] = holder
			end
		end
	end

	-- We listen for changes in icons (such as them being added, removed,
	-- the setting of a different alignment, the widget size changing, etc)
	local beginOverflow = false
	const updateBoundaries = Utility.createStagger(0.1, function(ignoreAvailable)
		if not beginOverflow then
			return
		end
		if not ignoreAvailable then
			Overflow.updateAvailableIcons("Center")
		end
		Overflow.updateBoundary("Left")
		Overflow.updateBoundary("Right")
	end)
	task.delay(0.5, function()
		beginOverflow = true
		updateBoundaries()
	end)
	task.delay(2, function()
		-- This is essential to prevent central icons begin added
		-- left or right due to incomplete UIListLayout calculations
		-- within the first few frames
		beginCheckingCenterIcons = true
		updateBoundaries()
	end)
	Icon.iconAdded:Connect(updateBoundaries)
	Icon.iconRemoved:Connect(updateBoundaries)
	Icon.iconChanged:Connect(updateBoundaries)
	currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		updateBoundaries(true)
	end)
	primaryScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		updateBoundaries(true)
	end)
end

function Overflow.getWidth(icon, getMaxWidth)
	const widget = icon.widget
	return widget:GetAttribute("TargetWidth") or widget.AbsoluteSize.X
end

function Overflow.getAvailableIcons(alignment)
	local ourOrderedIcons = orderedAvailableIcons[alignment]
	if not ourOrderedIcons then
		ourOrderedIcons = Overflow.updateAvailableIcons(alignment)
	end
	return ourOrderedIcons
end

function Overflow.updateAvailableIcons(alignment)

	-- We only track items that are directly on the topbar (i.e. not within a parent icon)
	local ourTotal = 0
	const ourOrderedIcons = {}
	for _, icon in iconsDict do
		const parentUID = icon.parentIconUID
		const isDirectlyOnTopbar = not parentUID or overflowIconUIDs[parentUID]
		const isOverflow = overflowIconUIDs[icon.UID]
		if isDirectlyOnTopbar and icon.alignment == alignment and not isOverflow and icon.isEnabled then
			table.insert(ourOrderedIcons, icon)
			ourTotal += 1
		end
	end

	-- Ignore if no icons are available
	if ourTotal <= 0 then
		return {}
	end

	-- This sorts these icons by smallest order, or if equal, left-most position
	-- (even for the right alignment because all icons are sorted left-to-right)
	table.sort(ourOrderedIcons, function(iconA, iconB)
		const orderA = iconA.widget.LayoutOrder
		const orderB = iconB.widget.LayoutOrder
		const hasParentA = iconA.parentIconUID
		const hasParentB = iconB.parentIconUID
		if hasParentA == hasParentB then
			if orderA < orderB then
				return true
			end
			if orderA > orderB then
				return false
			end
			return iconA.widget.AbsolutePosition.X < iconB.widget.AbsolutePosition.X
		elseif hasParentB then
			return false
		elseif hasParentA then
			return true
		end
		return nil
	end)

	-- Finish up
	orderedAvailableIcons[alignment] = ourOrderedIcons
	return ourOrderedIcons

end

function Overflow.getRealXPositions(alignment, orderedIcons)
	-- We calculate the the absolute position of icons instead of reading
	-- directly to determine where they would be if not within an overflow
	const isLeft = alignment == "Left"
	const holder = holders[alignment]
	const holderXPos = holder.AbsolutePosition.X
	const holderXSize = holder.AbsoluteSize.X
	const holderUIList = holder.UIListLayout
	const topbarInset = holderUIList.Padding.Offset
	local absoluteX = (isLeft and holderXPos) or holderXPos + holderXSize
	const realXPositions = {}
	if isLeft then
		Utility.reverseTable(orderedIcons)
	end
	for i = #orderedIcons, 1, -1 do
		const icon = orderedIcons[i]
		const sizeX = Overflow.getWidth(icon)
		if not isLeft then
			absoluteX -= sizeX
		end
		realXPositions[icon.UID] = absoluteX
		if isLeft then
			absoluteX += sizeX
		end
		absoluteX += (isLeft and topbarInset) or -topbarInset
	end
	return realXPositions
end

function Overflow.updateBoundary(alignment)

	-- We only track items that are directly on the topbar (i.e. not within a parent icon) or within an overflow
	const holder = holders[alignment]
	const holderUIList = holder.UIListLayout
	const holderXPos = holder.AbsolutePosition.X
	const holderXSize = holder.AbsoluteSize.X
	const topbarInset = holderUIList.Padding.Offset
	const topbarPadding = holderUIList.Padding.Offset
	const BOUNDARY_GAP = topbarInset
	const ourOrderedIcons = Overflow.updateAvailableIcons(alignment)
	local boundWidth = 0
	local ourTotal = 0
	for _, icon in ourOrderedIcons do
		boundWidth += Overflow.getWidth(icon) + topbarPadding
		ourTotal += 1
	end
	if ourTotal <= 0 then
		return
	end
	
	-- These are the icons with menus which icons will be moved into
	-- when overflowing
	const isCentral = alignment == "Center"
	const isLeft = alignment == "Left"
	const isRight = not isLeft
	local overflowIcon = overflowIcons[alignment]
	if not overflowIcon and not isCentral and #ourOrderedIcons > 0 then
		const order = (isLeft and -9999999) or 9999999
		overflowIcon = Icon.new()--:setLabel(`{alignment}`)
		overflowIcon:setImage(6069276526, "Deselected")
		overflowIcon:setName("Overflow"..alignment)
		overflowIcon:setOrder(order)
		overflowIcon:setAlignment(alignment)
		overflowIcon:autoDeselect(false)
		overflowIcon.isAnOverflow = true
		--overflowIcon:freezeMenu()
		overflowIcon:select("OverflowStart", overflowIcon)
		overflowIcon:setEnabled(false)
		overflowIcons[alignment] = overflowIcon
		overflowIconUIDs[overflowIcon.UID] = true
		if not Icon.closeableOverflowMenus then
			const iconSpot = overflowIcon:getInstance("IconSpot")
			iconSpot.Visible = false
		end
	end

	-- The default boundary is the point where both the left-most-right-icon
	-- and left-most-right-icon meet OR the opposite side of the screen
	const oppositeAlignment = (alignment == "Left" and "Right") or "Left"
	const oppositeOrderedIcons = Overflow.updateAvailableIcons(oppositeAlignment)
	const nearestOppositeIcon = (isLeft and oppositeOrderedIcons[1]) or (isRight and oppositeOrderedIcons[#oppositeOrderedIcons])
	const oppositeOverflowIcon = overflowIcons[oppositeAlignment]
	local boundary = (isLeft and holderXPos + holderXSize) or holderXPos
	if nearestOppositeIcon then
		const oppositeRealXPositions = Overflow.getRealXPositions(oppositeAlignment, oppositeOrderedIcons)
		const oppositeX = oppositeRealXPositions[nearestOppositeIcon.UID]
		const oppositeXSize = Overflow.getWidth(nearestOppositeIcon)
		boundary = (isLeft and oppositeX - BOUNDARY_GAP) or oppositeX + oppositeXSize + BOUNDARY_GAP
	end
	
	-- We get the left-most icon (if left alignment) or right-most-icon (if
	-- right alignment) of the central icons group to see if we need to change
	-- the boundary (if the central icon boundary is smaller than the alignment
	-- boundary then we use the central)
	local totalChecks = 0
	const usingNearestCenter = false
	const function checkToShiftCentralIcon()
		const centerOrderedIcons = Overflow.getAvailableIcons("Center")
		const centerPos = (isLeft and 1) or #centerOrderedIcons
		const nearestCenterIcon = centerOrderedIcons[centerPos]
		const function secondaryCheck()
			if not beganSecondaryCenterCheck then
				beganSecondaryCenterCheck = true
				task.delay(3, Overflow.updateBoundary, alignment)
			end
		end
		if nearestCenterIcon and not nearestCenterIcon.hasRelocatedInOverflow then
			const ourNearestIcon = (isLeft and ourOrderedIcons[#ourOrderedIcons]) or (isRight and ourOrderedIcons[1])
			const centralNearestXPos = nearestCenterIcon.widget.AbsolutePosition.X
			const ourNearestXPos = ourNearestIcon.widget.AbsolutePosition.X
			const ourNearestXSize = Overflow.getWidth(ourNearestIcon)
			const centerBoundary = (isLeft and centralNearestXPos-BOUNDARY_GAP) or centralNearestXPos + Overflow.getWidth(nearestCenterIcon) + BOUNDARY_GAP
			const removeBoundary = (isLeft and ourNearestXPos + ourNearestXSize) or ourNearestXPos
			local hasShifted = false
			if isLeft then
				if centerBoundary < removeBoundary then
					if not beginCheckingCenterIcons then
						secondaryCheck()
						return
					end
					nearestCenterIcon:align("Left")
					nearestCenterIcon.hasRelocatedInOverflow = true
					hasShifted = true
				end
			elseif isRight then
				if centerBoundary > removeBoundary then
					if not beginCheckingCenterIcons or removeBoundary < 0 then
						secondaryCheck()
						return
					end
					nearestCenterIcon:align("Right")
					nearestCenterIcon.hasRelocatedInOverflow = true
					hasShifted = true
				end
			end
			if hasShifted then
				totalChecks += 1
				if totalChecks <= 4 then
					Overflow.updateAvailableIcons("Center")
					checkToShiftCentralIcon()
				end
			end
		end
	end
	checkToShiftCentralIcon()
	
	--[[
	This updates the maximum size of the overflow menus
	The menu determines its bounds from the smallest of either:
	 	1. The closest center-aligned icon (i.e. the boundary)
	 	2. The edge of the opposite overflow menu UNLESS...
	 	3. ... the edge exceeds more than half the screenGui
	--]]
	if overflowIcon then
		local menuBoundary = boundary
		const menu = overflowIcon:getInstance("Menu")
		const holderXEndPos = holderXPos + holderXSize
		local menuWidth = holderXSize
		if menu and oppositeOverflowIcon then
			const oppositeWidget = oppositeOverflowIcon.widget
			const oppositeXPos = oppositeWidget.AbsolutePosition.X
			const oppositeXSize = Overflow.getWidth(oppositeOverflowIcon)
			const oppositeBoundary = (isLeft and oppositeXPos - BOUNDARY_GAP) or oppositeXPos + oppositeXSize + BOUNDARY_GAP
			const oppositeMenu = oppositeOverflowIcon:getInstance("Menu")
			const isDominant = menu.AbsoluteCanvasSize.X >= oppositeMenu.AbsoluteCanvasSize.X
			if not usingNearestCenter then
				const halfwayXPos = holderXPos + holderXSize/2
				const halfwayBoundary = (isLeft and halfwayXPos - BOUNDARY_GAP/2) or halfwayXPos + BOUNDARY_GAP/2
				menuBoundary = halfwayBoundary
				if isDominant then
					menuBoundary = oppositeBoundary
				end
			end
			menuWidth = (isLeft and menuBoundary - holderXPos) or (holderXEndPos - menuBoundary)
		end
		const currentMaxWidth = menu and menu:GetAttribute("MaxWidth")
		menuWidth = Utility.round(menuWidth)
		if menu and currentMaxWidth ~= menuWidth then
			menu:SetAttribute("MaxWidth", menuWidth)
		end
	end

	-- Parent ALL icons of that alignment into the overflow if at least on
	-- sibling exceeds the bounds.
	-- We calculate the the absolute position of icons instead of reading
	-- directly to determine where they would be if not within an overflow
	local joinOverflow = false
	const realXPositions = Overflow.getRealXPositions(alignment, ourOrderedIcons)
	for i = #ourOrderedIcons, 1, -1 do
		const icon = ourOrderedIcons[i]
		const widgetX = Overflow.getWidth(icon)
		const xPos = realXPositions[icon.UID]
		if (isLeft and xPos + widgetX >= boundary) or (isRight and xPos <= boundary) then
			joinOverflow = true
		end
	end
	for i = #ourOrderedIcons, 1, -1 do
		const icon = ourOrderedIcons[i]
		const isOverflow = overflowIconUIDs[icon.UID]
		if not isOverflow then
			if joinOverflow and not icon.parentIconUID then
				icon:joinMenu(overflowIcon)
			elseif not joinOverflow and icon.parentIconUID then
				icon:leave()
			end
		end
	end
	
	-- Hide the overflows when not in use
	if overflowIcon.isEnabled ~= joinOverflow then
		overflowIcon:setEnabled(joinOverflow)
	end
	
	-- Have the menus auto selected
	if overflowIcon.isEnabled and not overflowIcon.overflowAlreadyOpened then
		overflowIcon.overflowAlreadyOpened = true
		overflowIcon:select()
	end

end



return Overflow