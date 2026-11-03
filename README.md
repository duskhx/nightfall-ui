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

## What's new in 1.1.0

- **Tab indicator and icons:** the selected tab gets an accent bar. `Window:AddTab(name, category, icon)` takes an optional icon: an image id string, or `{ Image = id, Offset = Vector2.new(x, y), Size = Vector2.new(w, h) }` to use one cell of a sprite sheet (one uploaded image for all icons is the cheapest option).
- **Compact sidebar:** when the window is narrower than `CompactWidth` (default 360, set `CompactWidth = 0` to disable) the sidebar becomes an icon rail (first letter of the tab if it has no icon). It switches only when the width crosses the limit.
- **Collapsible sections:** click a section title to fold it. `Tab:AddSection(name, true)` starts folded.
- **Slider:** round handle on the bar and the value in a pill.
- **FPS / ping colors:** green, yellow or red depending on the value.
- **Notifications:** `Library:Notify("text", seconds)` shows a small toast (max 5 at once). Save, load, delete and autoload in the settings tab use it.
- **Accent presets:** quick swatches in the color popup, defined in `Library.Presets`.
- **Fix:** dropdown `SetValues` no longer leaves old button connections in memory.

### Performance

Nothing new runs every frame. The only per-frame code is the existing `Heartbeat` counter, which now also sleeps while the window is compact (the FPS card is hidden then) and updates its text once per second. Hover, tab and toast animations are one-shot tweens, there is no blur, no looping gradient and no `CanvasGroup`. The UI never touches the network, so it cannot change your ping; it only reads `GetNetworkPing()` once per second to show it.

## Window

- **Size:** the window is 220x220 by default and the text keeps its size. Change it with `CreateWindow({ Size = UDim2.fromOffset(500, 360) })`, or drag the corner at the bottom right to resize it (minimum 140x120).
- **Top bar:** accent color picker, minimize and close buttons.
- **Profile card (bottom of the sidebar):** your Roblox avatar, username, FPS and ping.
- **Menu key button (same card):** pick the key that shows or hides the whole interface (default `RightShift`, or set `Library.ToggleKey`).

## Configs

`Library:SaveConfig(name)`, `LoadConfig`, `DeleteConfig`, `ListConfigs`, `SetAutoload`, `LoadAutoload`.

Configs are kept in memory by default. To store them somewhere else (DataStore, files, etc.), replace `Library.Storage` with `{ Write, Read, Delete, List }`.
