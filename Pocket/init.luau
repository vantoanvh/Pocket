--!strict
--!optimize 2
--!native

--[[
	init.luau

	Composes the Pocket state, slot presenters, hotbar, inventory, drag behavior,
	gamepad behavior, avatar lifecycle, input routing, device layout values,
	and public API.
]]

const UserInputService = game:GetService("UserInputService")
const GuiService = game:GetService("GuiService")
const StarterGui = game:GetService("StarterGui")
const VRService = game:GetService("VRService")
const Players = game:GetService("Players")

const Camera = workspace.CurrentCamera :: Camera

const CreateAvatar = require("@self/Avatar")
const CreateGamepad = require("@self/Gamepad")
const CreateDragger = require("@self/Dragger")
const CreateState = require("@self/State")
const CreateInventory = require("@self/Inventory")
const CreateSlot = require("@self/Slot")
const CreateSearch = require("@self/Search")
const CreateSignal = require("@self/Signal")
const CreateInput = require("@self/Input")

const ICON_BUFFER = 5
const ICON_SIZE_DEFAULT = 60
const ICON_SIZE_TEN_FOOT = 100
const TEXT_SIZE_DEFAULT = 14
const TEXT_SIZE_TEN_FOOT = 24

const HOTBAR_SLOTS_FULL = 10
const HOTBAR_SLOTS_MINI = 3
const HOTBAR_SLOTS_WIDTH_CUTOFF = 1024

const INVENTORY_ROWS_FULL = 4
const INVENTORY_ROWS_MINI = 2

const INVENTORY_HEADER_SIZE = 40

const DOUBLE_CLICK_TIME = 0.5
const CLICK_DRAG_THRESHOLD = 5
const MAX_EQUIP_DELTA_TIME = 0.06

type SignalObject<Parameters...> = CreateSignal.Signal<Parameters...>
type SignalConnection<Parameters...> = CreateSignal.Connection<Parameters...>
type Avatar = CreateAvatar.Avatar
type Dragger = CreateDragger.Dragger
type Gamepad = CreateGamepad.Gamepad
type Inventory = CreateInventory.Inventory
type State = CreateState.State
type Search = CreateSearch.Search
type SlotPresenter = CreateSlot.SlotPresenter
type SlotRecord = CreateState.SlotRecord

export type StateChangedSignal = {
	Connect: (StateChangedSignal, (boolean) -> ()) -> SignalConnection<boolean>,
}

export type Pocket = {
	OpenClose: () -> (),
	IsOpen: boolean,
	StateChanged: StateChangedSignal,
}

const isTenFootInterface = GuiService:IsTenFootInterface()
const isPhone = UserInputService.PreferredInput == Enum.PreferredInput.Touch
	and Camera.ViewportSize.X < HOTBAR_SLOTS_WIDTH_CUTOFF
const iconSize = if isTenFootInterface then ICON_SIZE_TEN_FOOT else ICON_SIZE_DEFAULT
const textSize = if isTenFootInterface then TEXT_SIZE_TEN_FOOT else TEXT_SIZE_DEFAULT
const hotbarSlotCount = if isPhone then HOTBAR_SLOTS_MINI else HOTBAR_SLOTS_FULL
const inventoryRowCount = if isPhone then INVENTORY_ROWS_MINI else INVENTORY_ROWS_FULL

const player = Players.LocalPlayer :: Player
const localPlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

const backpackGui = Instance.new("ScreenGui")
backpackGui.Name = "BackpackGui"
backpackGui.ResetOnSpawn = false
backpackGui.Parent = localPlayerGui

const mainFrame = Instance.new("Frame")
mainFrame.Name = "Backpack"
mainFrame.BackgroundTransparency = 1
mainFrame.BorderSizePixel = 0
mainFrame.Size = UDim2.fromScale(1, 1)
mainFrame.Parent = backpackGui

local state: State = CreateState(hotbarSlotCount)

local inventoryOpen = false

const presenters: { SlotPresenter } = {}
const presentersById: { [number]: SlotPresenter } = {}
local lastEquippedPresenter: SlotPresenter? = nil

const stateChangedSignal = CreateSignal() :: SignalObject<boolean>
const purse: Pocket = {} :: Pocket
purse.IsOpen = inventoryOpen
purse.StateChanged = stateChangedSignal :: StateChangedSignal

local dragger: Dragger
local gamepad: Gamepad
local search: Search
local avatar: Avatar

const hotbarSlotStride = ICON_BUFFER + iconSize
const hotbarFrameWidth = ICON_BUFFER + (hotbarSlotCount * hotbarSlotStride)
const hotbarFrameHeight = hotbarSlotStride + ICON_BUFFER

const hotbarFrame = Instance.new("Frame")
hotbarFrame.Name = "Hotbar"
hotbarFrame.BackgroundTransparency = 1
hotbarFrame.BorderSizePixel = 0
hotbarFrame.Size = UDim2.fromOffset(hotbarFrameWidth, hotbarFrameHeight)
hotbarFrame.Position = UDim2.new(0.5, -hotbarFrameWidth / 2, 1, -hotbarFrameHeight)
hotbarFrame.Parent = mainFrame

const inventory: Inventory = CreateInventory({
	Parent = mainFrame,
	HotbarFrame = hotbarFrame,
	Presenters = presenters,
	IconSize = iconSize,
	IconBuffer = ICON_BUFFER,
	InventoryHeaderSize = INVENTORY_HEADER_SIZE,
	NumberOfInventoryRows = inventoryRowCount,
	NumberOfHotbarSlots = hotbarSlotCount,
})

const function UpdateHotbarSlots()
	hotbarFrame.Active = not inventoryOpen

	local fullHotbarSlots = 0
	for i = 1, hotbarSlotCount do
		const presenter = presenters[i]
		if presenter and presenter.Slot.Tool then
			fullHotbarSlots += 1
		end
	end

	const visualTotal = if inventoryOpen then hotbarSlotCount else fullHotbarSlots
	const centered = hotbarFrameWidth / 2
	const visualMidpoint = (visualTotal / 2) + 0.5
	local visualIndex = 0

	for i = 1, hotbarSlotCount do
		const presenter = presenters[i]
		if presenter then
			const slotFrame = presenter.View.Frame
			slotFrame.Parent = hotbarFrame
			slotFrame.Name = tostring(presenter.Slot.Index)
			slotFrame.LayoutOrder = presenter.Slot.Index
			const visible = presenter.Slot.Tool ~= nil or inventoryOpen
			slotFrame.Visible = visible
			if visible then
				visualIndex += 1
				const factor = visualIndex - visualMidpoint
				slotFrame.Position = UDim2.fromOffset(
					centered - (iconSize / 2) + (hotbarSlotStride * factor),
					ICON_BUFFER
				)
			end
		end
	end
end

const function ReleasePresenter(presenter: SlotPresenter)
	if lastEquippedPresenter == presenter then
		lastEquippedPresenter = nil
	end
	if GuiService.SelectedObject == presenter.View.Frame then
		GuiService.SelectedObject = nil
	end

	dragger.Unregister(presenter)
	gamepad.ForgetPresenter(presenter)
	presenter.View.Frame:Destroy()
end

const function RefreshAll()
	table.clear(presenters)

	for slotId, presenter in presentersById do
		if not state.HasSlot(slotId) then
			ReleasePresenter(presenter)
			presentersById[slotId] = nil
		end
	end

	local equippedPresenter: SlotPresenter? = nil
	for _, slot in state.Slots do
		local presenter = presentersById[slot.Id]
		if not presenter then
			const view = CreateSlot({
				IconSize = iconSize,
				TextSize = textSize,
				SlotArea = slot.Area,
				SlotIndex = slot.Index,
				HotbarSlotCount = hotbarSlotCount,
			})
			const createdPresenter: SlotPresenter = {
				Slot = slot,
				View = view,
			}
			view.Frame.Activated:Connect(function()
				if createdPresenter.View.Frame == GuiService.SelectedObject then
					gamepad.HandleSlotActivated(createdPresenter)
				end
			end)
			presentersById[slot.Id] = createdPresenter
			dragger.Register(createdPresenter)
			presenter = createdPresenter
		end

		presenter.View.SetTool(slot.Tool)
		const isEquipped = avatar.IsEquipped(slot.Tool)
		presenter.View.SetActiveVisual(slot.Tool ~= nil and inventoryOpen)
		presenter.View.SetHotkeyVisible(
			slot.Area == "Hotbar"
				and UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
				and not VRService.VREnabled
		)
		presenter.View.SetEquipped(isEquipped)
		presenters[slot.Index] = presenter
		if isEquipped then
			equippedPresenter = presenter
		end
	end

	lastEquippedPresenter = equippedPresenter or lastEquippedPresenter
	UpdateHotbarSlots()
	search.UpdateSlots()

	gamepad.RefreshHotbarAction()
end

const function UnequipAllTools()
	avatar.UnequipTools()
	RefreshAll()
end

const function SelectSlot(presenter: SlotPresenter)
	const tool = presenter.Slot.Tool
	if not tool then
		return
	end

	if avatar.IsEquipped(tool) then
		UnequipAllTools()
	elseif avatar.IsBackpackTool(tool) then
		avatar.UnequipTools()
		if avatar.EquipTool(tool) then
			lastEquippedPresenter = presenter
			RefreshAll()
		end
	end
end

const function MoveHotbarToInventory(presenter: SlotPresenter)
	const tool = presenter.Slot.Tool
	if state.MoveHotbarToInventory(presenter.Slot.Id) then
		if tool and avatar.IsEquipped(tool) then
			avatar.UnequipTools()
		end
		RefreshAll()
	end
end

const function DeleteEmptyInventorySlot(presenter: SlotPresenter): boolean
	if state.DeleteEmptyInventorySlot(presenter.Slot.Id) then
		RefreshAll()
		return true
	end
	return false
end

const function SwapSlots(leftPresenter: SlotPresenter, rightPresenter: SlotPresenter)
	if state.SwapSlots(leftPresenter.Slot.Id, rightPresenter.Slot.Id) then
		RefreshAll()
	end
end

const function MoveInventoryToHotbar(presenter: SlotPresenter, hotbarIndex: number)
	const targetPresenter = presenters[hotbarIndex]
	const displacedEquippedTool = targetPresenter ~= nil and avatar.IsEquipped(targetPresenter.Slot.Tool)

	if not state.MoveInventoryToHotbar(presenter.Slot.Id, hotbarIndex) then
		return
	end

	if displacedEquippedTool then
		avatar.UnequipTools()
	end
	RefreshAll()
end

const function CanDrag(presenter: SlotPresenter): boolean
	return presenter.Slot.Tool ~= nil and (presenter.Slot.Area == "Inventory" or inventoryOpen)
end

const function ShouldShowPressed(presenter: SlotPresenter): boolean
	return inventoryOpen and presenter.Slot.Tool ~= nil
end

const function DropOnHotbar(presenter: SlotPresenter, targetPresenter: SlotPresenter?)
	if not targetPresenter or targetPresenter.Slot.Id == presenter.Slot.Id then
		return
	end

	if presenter.Slot.Area == "Inventory" then
		MoveInventoryToHotbar(presenter, targetPresenter.Slot.Index)
	else
		SwapSlots(presenter, targetPresenter)
	end
end

const function MoveInventoryToLowestHotbar(presenter: SlotPresenter): boolean
	const targetSlot = state.MoveInventoryToLowestHotbar(presenter.Slot.Id)
	if not targetSlot then
		return false
	end

	RefreshAll()
	const targetPresenter = presentersById[targetSlot.Id]
	if targetPresenter then
		SelectSlot(targetPresenter)
	end
	return true
end

const function ResetState()
	for _, presenter in presentersById do
		ReleasePresenter(presenter)
	end

	table.clear(presentersById)
	table.clear(presenters)
	state = CreateState(hotbarSlotCount)
	lastEquippedPresenter = nil
end

const function AddTool(tool: Tool): (SlotRecord, boolean)
	return state.AddTool(tool)
end

const function AddStarterTool(tool: Tool): (SlotRecord, boolean)
	return state.AddStarterTool(tool)
end

const function RemoveTool(tool: Tool)
	state.RemoveTool(tool)
end

dragger = CreateDragger({
	InventoryFrame = inventory.Frame,
	HotbarFrame = hotbarFrame,
	InventoryGridFrame = inventory.GridFrame,
	InventoryScrollingFrame = inventory.ScrollingFrame,
	HotbarPresenters = presenters,
	HotbarSlotCount = hotbarSlotCount,
	ClickDragThreshold = CLICK_DRAG_THRESHOLD,
	DoubleClickTime = DOUBLE_CLICK_TIME,
	CanDrag = CanDrag,
	ShouldShowPressed = ShouldShowPressed,
	OnClick = SelectSlot,
	OnDoubleClickInventory = MoveInventoryToLowestHotbar,
	OnDropOutsideHotbar = MoveHotbarToInventory,
	OnDropHotbar = DropOnHotbar,
})

const function OpenClose()
	if dragger.IsDragging() then
		return
	end

	inventoryOpen = not inventoryOpen
	purse.IsOpen = inventoryOpen
	inventory.SetOpen(inventoryOpen)
	RefreshAll()

	search.SetOpen(inventoryOpen)
	gamepad.SetInventoryOpen(inventoryOpen)

	stateChangedSignal:Fire(inventoryOpen)
end
purse.OpenClose = OpenClose

const function CloseInventory()
	if inventoryOpen then
		OpenClose()
	end
end

const function GetLastEquippedPresenter(): SlotPresenter?
	return lastEquippedPresenter
end

const function IsOpen(): boolean
	return inventoryOpen
end

search = CreateSearch({
	Parent = inventory.Frame,
	Presenters = presenters,
	NumberOfHotbarSlots = hotbarSlotCount,
	InventoryHeaderSize = INVENTORY_HEADER_SIZE,
	UpdateInventorySlots = inventory.UpdateSlots,
	UpdateSearchResults = inventory.UpdateSearchResults,
	ResetInventoryScroll = inventory.ResetScroll,
	ScrollInventoryToBottom = inventory.ScrollToBottom,
})

avatar = CreateAvatar({
	Player = player,
	AddTool = AddTool,
	AddStarterTool = AddStarterTool,
	RemoveTool = RemoveTool,
	ResetState = ResetState,
	Refresh = RefreshAll,
	ScrollToNewInventorySlot = search.ScrollToNewInventorySlot,
})

gamepad = CreateGamepad({
	SelectionRoot = mainFrame,
	HotbarFrame = hotbarFrame,
	InventoryFrame = inventory.Frame,
	HotbarPresenters = presenters,
	HotbarSlotCount = hotbarSlotCount,
	IsTenFootInterface = isTenFootInterface,
	MaxEquipDeltaTime = MAX_EQUIP_DELTA_TIME,
	SelectSlot = SelectSlot,
	SwapSlots = SwapSlots,
	MoveHotbarToInventory = MoveHotbarToInventory,
	DeleteEmptyInventorySlot = DeleteEmptyInventorySlot,
	IsEquipped = avatar.IsEquipped,
	UnequipAllTools = UnequipAllTools,
	GetLastEquippedPresenter = GetLastEquippedPresenter,
	CloseInventory = CloseInventory,
	SetInventorySelectorVisible = inventory.SetSelectorVisible,
})

CreateInput({
	Presenters = presenters,
	HotbarSlotCount = hotbarSlotCount,
	InventoryFrame = inventory.Frame,
	HotbarFrame = hotbarFrame,
	IsOpen = IsOpen,
	OpenClose = OpenClose,
	SelectSlot = SelectSlot,
	ResetSearch = search.Reset,
})

UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(RefreshAll)
VRService:GetPropertyChangedSignal("VREnabled"):Connect(RefreshAll)

GuiService.MenuOpened:Connect(function()
	if inventoryOpen then
		OpenClose()
	end
end)

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

avatar.Start()

return purse
