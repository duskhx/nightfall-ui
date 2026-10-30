# NightfallUI

Dark UI library with a purple accent for Roblox, written in Lua (`ModuleScript`).

## Usage

```lua
local Library = require(game.ReplicatedStorage.NightfallUI)

local Window = Library:CreateWindow({ Title = "My menu" })
local Tab = Window:AddTab("Main", "General")
local Section = Tab:AddSection("Options")

Section:AddToggle({ Name = "Enable", Flag = "enabled", Default = true, Callback = print })
Section:AddSlider({ Name = "Speed", Flag = "speed", Min = 0, Max = 100, Default = 16 })
Section:AddDropdown({ Name = "Mode", Flag = "mode", Values = { "A", "B" }, Default = "A" })

Window:AddSettingsTab()
```

## Controls

`AddToggle`, `AddButton`, `AddSlider`, `AddDropdown`, `AddMultiDropdown`, `AddColorpicker`, `AddKeybind`, `AddTextbox`, `AddLabel`, `AddSeparator`.

Values with a `Flag` are stored in `Library.Flags[flag]`, and the control itself in `Library.Options[flag]` (`:SetValue()`, `:OnChanged()`).

## Window

- **Top bar:** accent color picker, minimize and close buttons.
- **Profile card (bottom of the sidebar):** your Roblox avatar, username, FPS and ping.
- **Menu key button (same card):** pick the key that shows or hides the whole interface (default `RightShift`, or set `Library.ToggleKey`).

## Configs

`Library:SaveConfig(name)`, `LoadConfig`, `DeleteConfig`, `ListConfigs`, `SetAutoload`, `LoadAutoload`.

Configs are kept in memory by default. To store them somewhere else (DataStore, files, etc.), replace `Library.Storage` with `{ Write, Read, Delete, List }`.
