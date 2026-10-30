# NightfallUI

Librería de interfaz oscura con acento morado para Roblox, hecha en Lua (`ModuleScript`).

## Uso

```lua
local Library = require(game.ReplicatedStorage.NightfallUI)

local Window = Library:CreateWindow({ Title = "Mi menú" })
local Tab = Window:AddTab("Principal", "General")
local Section = Tab:AddSection("Opciones")

Section:AddToggle({ Name = "Activar", Flag = "enabled", Default = true, Callback = print })
Section:AddSlider({ Name = "Velocidad", Flag = "speed", Min = 0, Max = 100, Default = 16 })
Section:AddDropdown({ Name = "Modo", Flag = "mode", Values = { "A", "B" }, Default = "A" })

Window:AddSettingsTab()
```

## Controles

`AddToggle`, `AddButton`, `AddSlider`, `AddDropdown`, `AddMultiDropdown`, `AddColorpicker`, `AddKeybind`, `AddTextbox`, `AddLabel`, `AddSeparator`.

Los valores con `Flag` quedan en `Library.Flags[flag]`, y el control en `Library.Options[flag]` (`:SetValue()`, `:OnChanged()`).

## Configuraciones

`Library:SaveConfig(name)`, `LoadConfig`, `DeleteConfig`, `ListConfigs`, `SetAutoload`, `LoadAutoload`.

Por defecto se guardan en memoria. Para guardarlas en otro sitio (DataStore, archivos, etc.) reemplaza `Library.Storage` con `{ Write, Read, Delete, List }`.

## Teclas

`RightShift` muestra u oculta el menú (se cambia en la pestaña Ajustes o con `Library.ToggleKey`).
