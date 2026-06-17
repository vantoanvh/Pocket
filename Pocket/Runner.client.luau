--!strict
--!optimize 2
--!native

--[[
	Runner.client.luau

	Creates the TopbarPlus backpack icon and keeps its selection state synced with
	the Pocket inventory state.
]]

const Pocket = require("./")

const BUILDER_ICONS_FONT = "rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json"

type TopbarIcon = {
	modifyTheme: (TopbarIcon, { string | number }) -> (),
	setLabel: (TopbarIcon, string) -> (),
	setOrder: (TopbarIcon, number) -> (),
	setTextSize: (TopbarIcon, number) -> (),
	setTextFont: (TopbarIcon, string, Enum.FontWeight, Enum.FontStyle, string) -> (),
	bindToggleKey: (TopbarIcon, Enum.KeyCode) -> (),
	autoDeselect: (TopbarIcon, boolean) -> (),
	setCaption: (TopbarIcon, string) -> (),
	select: (TopbarIcon) -> (),
	deselect: (TopbarIcon) -> (),
	toggled: RBXScriptSignal,
}

type TopbarIconModule = {
	new: () -> TopbarIcon,
}

const Icon = require("./TopbarPlus") :: TopbarIconModule

const icon = Icon.new()
icon:modifyTheme({ "IconLabelContainer", "TargetWidth", 0 })
icon:setLabel("backpack")
icon:setOrder(-1)
icon:setTextSize(24)

icon:setTextFont(
	BUILDER_ICONS_FONT,
	Enum.FontWeight.Bold,
	Enum.FontStyle.Normal,
	"Selected"
)

icon:setTextFont(
	BUILDER_ICONS_FONT,
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal,
	"Deselected"
)

icon:bindToggleKey(Enum.KeyCode.Backquote)
icon:autoDeselect(false)
icon:setCaption("Inventory")

Pocket.StateChanged:Connect(function(isNowOpen: boolean)
	if isNowOpen then
		icon:select()
	else
		icon:deselect()
	end
end)

icon.toggled:Connect(function(isSelected: boolean, fromSource: string)
	if fromSource == "User" then
		Pocket.OpenClose()
	end
end)
