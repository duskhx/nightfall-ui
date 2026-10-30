--[[
    NightfallUI v1.0.0
    Librería de interfaz oscura con acento morado para Roblox (ModuleScript).

    Uso:
        local Library = require(path.to.NightfallUI)
        local Window = Library:CreateWindow({ Title = "Mi menú" })
        local Tab = Window:AddTab("Principal", "General")
        local Section = Tab:AddSection("Opciones")
        Section:AddToggle({ Name = "Activar", Flag = "enabled", Callback = print })
        Window:AddSettingsTab()
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Library = {
	Version = "1.0.0",
	Flags = {},
	Options = {},
	ToggleKey = Enum.KeyCode.RightShift,
	Theme = {
		Background = Color3.fromRGB(16, 16, 22),
		Sidebar = Color3.fromRGB(20, 20, 28),
		Element = Color3.fromRGB(28, 28, 38),
		ElementHover = Color3.fromRGB(36, 36, 50),
		Outline = Color3.fromRGB(44, 44, 60),
		Text = Color3.fromRGB(235, 235, 245),
		TextDim = Color3.fromRGB(150, 150, 170),
		Accent = Color3.fromRGB(139, 92, 246),
	},
}

local GUI_NAME = "NightfallUI"
local FONT = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold
local Theme = Library.Theme

local connections = {}
local accentObjects = {}
local currentGui

-- Utilidades ---------------------------------------------------------------

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

local function safeCall(fn, ...)
	if not fn then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[NightfallUI] " .. tostring(err))
	end
end

local function New(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function Frame(props, children)
	props.BorderSizePixel = 0
	return New("Frame", props, children)
end

local function Label(props, children)
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextSize = props.TextSize or 13
	props.TextColor3 = props.TextColor3 or Theme.Text
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return New("TextLabel", props, children)
end

local function Button(props, children)
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	props.Font = props.Font or FONT
	props.TextSize = props.TextSize or 13
	props.TextColor3 = props.TextColor3 or Theme.Text
	return New("TextButton", props, children)
end

local function Corner(radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

local function Stroke(color, thickness)
	return New("UIStroke", {
		Color = color or Theme.Outline,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function Padding(l, t, r, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r or l),
		PaddingBottom = UDim.new(0, b or t),
	})
end

local function List(padding)
	return New("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

local function tween(inst, props, time)
	TweenService:Create(inst, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad), props):Play()
end

local function accent(inst, prop)
	table.insert(accentObjects, { inst, prop })
	inst[prop] = Theme.Accent
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

-- Arrastra sobre `frame` y llama fn(Vector3) con la posición del puntero.
local function dragger(frame, fn)
	local dragging = false
	connect(frame.InputBegan, function(input)
		if isPress(input) then
			dragging = true
			fn(input.Position)
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragging and isMove(input) then
			fn(input.Position)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if isPress(input) then
			dragging = false
		end
	end)
end

-- Opciones y flags ---------------------------------------------------------

local function newOption(opts, type_, value)
	local obj = { Type = type_, Value = value, Changed = {} }
	function obj:OnChanged(fn)
		table.insert(self.Changed, fn)
	end
	if opts.Flag then
		Library.Flags[opts.Flag] = value
		Library.Options[opts.Flag] = obj
	end
	return obj
end

local function fire(obj, opts)
	if opts.Flag then
		Library.Flags[opts.Flag] = obj.Value
	end
	safeCall(opts.Callback, obj.Value)
	for _, fn in ipairs(obj.Changed) do
		safeCall(fn, obj.Value)
	end
end

-- Almacenamiento de configs (reemplazable con Library.Storage = {...}) ------

local memory = {}
Library.Storage = {
	Write = function(name, text)
		memory[name] = text
	end,
	Read = function(name)
		return memory[name]
	end,
	Delete = function(name)
		memory[name] = nil
	end,
	List = function()
		local names = {}
		for name in pairs(memory) do
			if name ~= "__autoload" then
				table.insert(names, name)
			end
		end
		table.sort(names)
		return names
	end,
}

local function encodeOption(opt)
	local v = opt.Value
	if opt.Type == "Colorpicker" then
		return { v.R, v.G, v.B }
	elseif opt.Type == "Keybind" then
		return v and v.Name or ""
	end
	return v
end

local function decodeOption(opt, v)
	if opt.Type == "Colorpicker" and type(v) == "table" then
		return Color3.new(v[1], v[2], v[3])
	elseif opt.Type == "Keybind" then
		return v ~= "" and Enum.KeyCode[v] or nil
	end
	return v
end

function Library:SaveConfig(name)
	if not name or name == "" then
		return false
	end
	local data = {}
	for flag, opt in pairs(Library.Options) do
		if not opt.NoSave then
			data[flag] = encodeOption(opt)
		end
	end
	Library.Storage.Write(name, HttpService:JSONEncode(data))
	return true
end

function Library:LoadConfig(name)
	local text = Library.Storage.Read(name)
	if not text then
		return false
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, text)
	if not ok then
		return false
	end
	for flag, v in pairs(data) do
		local opt = Library.Options[flag]
		if opt and not opt.NoSave then
			opt:SetValue(decodeOption(opt, v))
		end
	end
	return true
end

function Library:DeleteConfig(name)
	Library.Storage.Delete(name)
end

function Library:ListConfigs()
	return Library.Storage.List()
end

function Library:SetAutoload(name)
	Library.Storage.Write("__autoload", name or "")
end

function Library:LoadAutoload()
	local name = Library.Storage.Read("__autoload")
	if name and name ~= "" then
		return Library:LoadConfig(name)
	end
	return false
end

-- Tema ---------------------------------------------------------------------

function Library:SetAccent(color)
	Theme.Accent = color
	for _, entry in ipairs(accentObjects) do
		if entry[1].Parent then
			entry[1][entry[2]] = color
		end
	end
end

function Library:Unload()
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(accentObjects)
	table.clear(Library.Flags)
	table.clear(Library.Options)
	if currentGui then
		currentGui:Destroy()
		currentGui = nil
	end
end

-- Elementos ----------------------------------------------------------------

local Section = {}
Section.__index = Section

local function newElement(section, name, height)
	local frame = Frame({
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		Parent = section.Body,
	})
	table.insert(section.Window.Elements, { Frame = frame, Name = name or "" })
	return frame
end

function Section:AddLabel(text)
	local frame = newElement(self, text, 18)
	local label = Label({ Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = Theme.TextDim, Parent = frame })
	return {
		SetText = function(_, t)
			label.Text = t
		end,
	}
end

function Section:AddSeparator()
	local frame = Frame({ Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Outline, Parent = self.Body })
	return frame
end

function Section:AddButton(opts)
	local frame = newElement(self, opts.Name, 30)
	local btn = Button({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Element,
		Text = opts.Name,
		Parent = frame,
	}, { Corner(), Stroke() })
	connect(btn.MouseEnter, function()
		tween(btn, { BackgroundColor3 = Theme.ElementHover })
	end)
	connect(btn.MouseLeave, function()
		tween(btn, { BackgroundColor3 = Theme.Element })
	end)
	connect(btn.MouseButton1Click, function()
		safeCall(opts.Callback)
	end)
	return btn
end

function Section:AddToggle(opts)
	local frame = newElement(self, opts.Name, 28)
	local obj = newOption(opts, "Toggle", opts.Default == true)

	Label({ Size = UDim2.new(1, -50, 1, 0), Text = opts.Name, Parent = frame })
	local track = Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = Theme.Element,
		Text = "",
		Parent = frame,
	}, { Corner(10), Stroke() })
	local knob = Frame({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Theme.TextDim,
		Parent = track,
	}, { Corner(7) })

	local function render()
		local on = obj.Value
		tween(track, { BackgroundColor3 = on and Theme.Accent or Theme.Element })
		tween(knob, {
			Position = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = on and Color3.new(1, 1, 1) or Theme.TextDim,
		})
	end

	function obj:SetValue(v)
		self.Value = v == true
		render()
		fire(self, opts)
	end

	connect(track.MouseButton1Click, function()
		obj:SetValue(not obj.Value)
	end)
	render()
	if obj.Value then
		fire(obj, opts)
	end
	return obj
end

function Section:AddSlider(opts)
	local min, max = opts.Min or 0, opts.Max or 100
	local step = opts.Step or 1
	local frame = newElement(self, opts.Name, 40)
	local obj = newOption(opts, "Slider", math.clamp(opts.Default or min, min, max))

	Label({ Size = UDim2.new(1, -60, 0, 18), Text = opts.Name, Parent = frame })
	local valueLabel = Label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(60, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.TextDim,
		Parent = frame,
	})
	local bar = Button({
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Theme.Element,
		Text = "",
		Parent = frame,
	}, { Corner(4), Stroke() })
	local fill = Frame({ Size = UDim2.fromScale(0, 1), Parent = bar }, { Corner(4) })
	accent(fill, "BackgroundColor3")

	local function render()
		local alpha = (obj.Value - min) / (max - min)
		fill.Size = UDim2.fromScale(alpha, 1)
		valueLabel.Text = tostring(obj.Value) .. (opts.Suffix or "")
	end

	function obj:SetValue(v)
		v = math.clamp(math.round((v - min) / step) * step + min, min, max)
		v = tonumber(string.format("%.6g", v))
		self.Value = v
		render()
		fire(self, opts)
	end

	dragger(bar, function(pos)
		local alpha = math.clamp((pos.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		obj:SetValue(min + (max - min) * alpha)
	end)
	render()
	return obj
end

function Section:AddTextbox(opts)
	local frame = newElement(self, opts.Name, 50)
	local obj = newOption(opts, "Textbox", opts.Default or "")

	Label({ Size = UDim2.new(1, 0, 0, 18), Text = opts.Name, Parent = frame })
	local box = New("TextBox", {
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.Element,
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 13,
		TextColor3 = Theme.Text,
		PlaceholderText = opts.Placeholder or "",
		PlaceholderColor3 = Theme.TextDim,
		ClearTextOnFocus = false,
		Text = obj.Value,
		Parent = frame,
	}, { Corner(), Stroke(), Padding(8, 0) })

	function obj:SetValue(v)
		self.Value = tostring(v)
		box.Text = self.Value
		fire(self, opts)
	end

	connect(box.FocusLost, function()
		obj:SetValue(box.Text)
	end)
	return obj
end

local function buildDropdown(self, opts, multi)
	local values = opts.Values or {}
	local frame = newElement(self, opts.Name, 50)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Size = UDim2.new(1, 0, 0, 50)

	local obj = newOption(opts, multi and "MultiDropdown" or "Dropdown", multi and {} or opts.Default)
	if multi and type(opts.Default) == "table" then
		obj.Value = table.clone(opts.Default)
	end

	New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	Label({ Size = UDim2.new(1, 0, 0, 18), Text = opts.Name, LayoutOrder = 1, Parent = frame })
	local header = Button({
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.Element,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = frame,
	}, { Corner(), Stroke(), Padding(8, 0) })
	local arrow = Label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		Text = "v",
		TextColor3 = Theme.TextDim,
		Parent = header,
	})
	local listFrame = Frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		LayoutOrder = 3,
		Parent = frame,
	}, { List(3) })

	local buttons = {}

	local function selected(value)
		if multi then
			return table.find(obj.Value, value) ~= nil
		end
		return obj.Value == value
	end

	local function render()
		if multi then
			header.Text = #obj.Value > 0 and table.concat(obj.Value, ", ") or "Ninguno"
		else
			header.Text = tostring(obj.Value or "Ninguno")
		end
		for value, btn in pairs(buttons) do
			btn.TextColor3 = selected(value) and Theme.Accent or Theme.TextDim
		end
	end

	local function rebuild()
		for _, b in pairs(buttons) do
			b:Destroy()
		end
		table.clear(buttons)
		for i, value in ipairs(values) do
			local btn = Button({
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = Theme.Element,
				Text = tostring(value),
				TextColor3 = Theme.TextDim,
				LayoutOrder = i,
				Parent = listFrame,
			}, { Corner(5) })
			buttons[value] = btn
			connect(btn.MouseButton1Click, function()
				if multi then
					local idx = table.find(obj.Value, value)
					local new = table.clone(obj.Value)
					if idx then
						table.remove(new, idx)
					else
						table.insert(new, value)
					end
					obj:SetValue(new)
				else
					obj:SetValue(value)
					listFrame.Visible = false
					arrow.Text = "v"
				end
			end)
		end
		render()
	end

	function obj:SetValue(v)
		self.Value = v
		render()
		fire(self, opts)
	end

	function obj:SetValues(list)
		values = list
		rebuild()
	end

	connect(header.MouseButton1Click, function()
		listFrame.Visible = not listFrame.Visible
		arrow.Text = listFrame.Visible and "^" or "v"
	end)
	rebuild()
	return obj
end

function Section:AddDropdown(opts)
	return buildDropdown(self, opts, false)
end

function Section:AddMultiDropdown(opts)
	return buildDropdown(self, opts, true)
end

function Section:AddKeybind(opts)
	local frame = newElement(self, opts.Name, 28)
	local obj = newOption(opts, "Keybind", opts.Default)
	local listening = false

	Label({ Size = UDim2.new(1, -90, 1, 0), Text = opts.Name, Parent = frame })
	local btn = Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(84, 22),
		BackgroundColor3 = Theme.Element,
		TextColor3 = Theme.TextDim,
		Parent = frame,
	}, { Corner(), Stroke() })

	local function render()
		btn.Text = listening and "..." or (obj.Value and obj.Value.Name or "Ninguna")
	end

	function obj:SetValue(v)
		self.Value = v
		listening = false
		render()
		if opts.Flag then
			Library.Flags[opts.Flag] = v
		end
		for _, fn in ipairs(self.Changed) do
			safeCall(fn, v)
		end
	end

	connect(btn.MouseButton1Click, function()
		listening = true
		render()
	end)
	connect(UserInputService.InputBegan, function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if listening then
			obj:SetValue(input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode or nil)
		elseif not processed and obj.Value and input.KeyCode == obj.Value then
			safeCall(opts.Callback, obj.Value)
		end
	end)
	render()
	return obj
end

function Section:AddColorpicker(opts)
	local frame = newElement(self, opts.Name, 28)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Size = UDim2.new(1, 0, 0, 28)
	local obj = newOption(opts, "Colorpicker", opts.Default or Color3.new(1, 1, 1))
	local h, s, v = obj.Value:ToHSV()

	New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	local header = Frame({ Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 1, Parent = frame })
	Label({ Size = UDim2.new(1, -50, 1, 0), Text = opts.Name, Parent = header })
	local swatch = Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = obj.Value,
		Text = "",
		Parent = header,
	}, { Corner(5), Stroke() })

	local panel = Frame({
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		Visible = false,
		LayoutOrder = 2,
		Parent = frame,
	})
	local sv = Frame({
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundColor3 = Color3.fromHSV(h, 1, 1),
		Parent = panel,
	}, { Corner(5) })
	local white = Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv }, {
		Corner(5),
		New("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
	})
	Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = white }, {
		Corner(5),
		New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }),
	})
	local svCursor = Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = sv,
	}, { Corner(4), Stroke(Color3.new(0, 0, 0)) })

	local hue = Frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 20, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = panel,
	}, {
		Corner(5),
		New("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
				ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
				ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
				ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
				ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
				ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
			}),
		}),
	})
	local hueCursor = Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 4, 0, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = hue,
	}, { Corner(2), Stroke(Color3.new(0, 0, 0)) })

	local function render()
		obj.Value = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = obj.Value
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(0.5, h)
	end

	function obj:SetValue(color)
		h, s, v = color:ToHSV()
		render()
		fire(self, opts)
	end

	dragger(sv, function(pos)
		s = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
		v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		render()
		fire(obj, opts)
	end)
	dragger(hue, function(pos)
		h = math.clamp((pos.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 1)
		render()
		fire(obj, opts)
	end)
	connect(swatch.MouseButton1Click, function()
		panel.Visible = not panel.Visible
	end)
	render()
	return obj
end

-- Pestañas y ventana -------------------------------------------------------

local Tab = {}
Tab.__index = Tab

function Tab:AddSection(name)
	local holder = Frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Sidebar,
		Parent = self.Page,
	}, { Corner(8), Stroke(), Padding(12, 10), List(8) })

	Label({
		Size = UDim2.new(1, 0, 0, 18),
		Text = string.upper(name),
		Font = FONT_BOLD,
		TextSize = 12,
		LayoutOrder = -1,
		Parent = holder,
	})
	local body = Frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = holder,
	}, { List(8) })

	return setmetatable({ Body = body, Window = self.Window }, Section)
end

local Window = {}
Window.__index = Window

function Window:AddTab(name, category)
	if category and category ~= self.LastCategory then
		self.LastCategory = category
		Label({
			Size = UDim2.new(1, 0, 0, 22),
			Text = string.upper(category),
			TextColor3 = Theme.TextDim,
			TextSize = 11,
			Font = FONT_BOLD,
			LayoutOrder = #self.Tabs * 2,
			Parent = self.TabList,
		})
	end

	local page = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Outline,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self.Content,
	}, { List(10), Padding(2, 2, 6, 2) })

	local btn = Button({
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Theme.Element,
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = #self.Tabs * 2 + 1,
		Parent = self.TabList,
	}, { Corner(), Padding(10, 0) })

	local tab = setmetatable({ Page = page, Button = btn, Window = self }, Tab)
	table.insert(self.Tabs, tab)

	connect(btn.MouseButton1Click, function()
		self:SelectTab(tab)
	end)
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tab)
	for _, t in ipairs(self.Tabs) do
		local active = t == tab
		t.Page.Visible = active
		tween(t.Button, {
			BackgroundTransparency = active and 0 or 1,
			TextColor3 = active and Theme.Accent or Theme.TextDim,
		})
	end
end

function Window:Toggle(state)
	if state == nil then
		state = not self.Main.Visible
	end
	self.Main.Visible = state
end

function Window:AddSettingsTab()
	local tab = self:AddTab("Ajustes", "Sistema")

	local menu = tab:AddSection("Menú")
	menu:AddButton({
		Name = "Descargar interfaz",
		Callback = function()
			Library:Unload()
		end,
	})

	local configs = tab:AddSection("Configuraciones")
	local nameBox = configs:AddTextbox({ Name = "Nombre", Placeholder = "mi-config" })
	nameBox.NoSave = true
	local list = configs:AddDropdown({ Name = "Guardadas", Values = Library:ListConfigs() })
	list.NoSave = true

	local function refresh()
		list:SetValues(Library:ListConfigs())
	end
	configs:AddButton({
		Name = "Guardar",
		Callback = function()
			if Library:SaveConfig(nameBox.Value) then
				refresh()
			end
		end,
	})
	configs:AddButton({
		Name = "Cargar",
		Callback = function()
			if list.Value then
				Library:LoadConfig(list.Value)
			end
		end,
	})
	configs:AddButton({
		Name = "Eliminar",
		Callback = function()
			if list.Value then
				Library:DeleteConfig(list.Value)
				refresh()
			end
		end,
	})
	configs:AddButton({
		Name = "Usar como autocarga",
		Callback = function()
			if list.Value then
				Library:SetAutoload(list.Value)
			end
		end,
	})
	return tab
end

function Library:CreateWindow(opts)
	opts = opts or {}
	Library:Unload()

	local parent = opts.Parent or Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = New("ScreenGui", {
		Name = GUI_NAME,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
	currentGui = gui

	local main = Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = opts.Size or UDim2.fromOffset(580, 420),
		BackgroundColor3 = Theme.Background,
		Parent = gui,
	}, { Corner(10), Stroke() })

	local top = Frame({ Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = main })
	local title = Label({
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -110, 1, 0),
		Text = opts.Title or "NightfallUI",
		Font = FONT_BOLD,
		TextSize = 14,
		Parent = top,
	})
	accent(title, "TextColor3")
	Frame({ Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Outline, Parent = top })

	-- Arrastrar ventana
	local dragStart, startPos
	connect(top.InputBegan, function(input)
		if isPress(input) then
			dragStart, startPos = input.Position, main.Position
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragStart and isMove(input) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if isPress(input) then
			dragStart = nil
		end
	end)

	local sidebar = Frame({
		Position = UDim2.fromOffset(8, 44),
		Size = UDim2.new(0, 150, 1, -80),
		BackgroundColor3 = Theme.Sidebar,
		Parent = main,
	}, { Corner(8), Stroke() })

	local search = New("TextBox", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 26),
		BackgroundColor3 = Theme.Element,
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 12,
		TextColor3 = Theme.Text,
		PlaceholderText = "Buscar...",
		PlaceholderColor3 = Theme.TextDim,
		ClearTextOnFocus = false,
		Text = "",
		Parent = sidebar,
	}, { Corner(), Padding(8, 0) })

	local tabList = New("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 42),
		Size = UDim2.new(1, -16, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	}, { List(3) })

	local content = Frame({
		Position = UDim2.fromOffset(166, 44),
		Size = UDim2.new(1, -174, 1, -80),
		BackgroundTransparency = 1,
		Parent = main,
	})

	local window = setmetatable({
		Gui = gui,
		Main = main,
		Content = content,
		TabList = tabList,
		Tabs = {},
		Elements = {},
		LastCategory = nil,
	}, Window)

	-- Barra inferior: elegir la tecla que muestra u oculta toda la interfaz
	local footer = Frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.new(1, -16, 0, 28),
		BackgroundColor3 = Theme.Sidebar,
		Parent = main,
	}, { Corner(8), Stroke() })
	Label({
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -150, 1, 0),
		Text = "Tecla para mostrar / ocultar la interfaz",
		TextColor3 = Theme.TextDim,
		TextSize = 12,
		Parent = footer,
	})
	local keyBtn = Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(110, 20),
		BackgroundColor3 = Theme.Element,
		TextColor3 = Theme.Accent,
		Font = FONT_BOLD,
		TextSize = 12,
		Parent = footer,
	}, { Corner(5), Stroke() })
	accent(keyBtn, "TextColor3")

	local function renderKey()
		keyBtn.Text = window.Listening and "Presiona una tecla..." or ("Tecla: " .. Library.ToggleKey.Name)
	end
	renderKey()
	connect(keyBtn.MouseButton1Click, function()
		window.Listening = true
		renderKey()
	end)
	connect(UserInputService.InputBegan, function(input)
		if window.Listening and input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode ~= Enum.KeyCode.Escape then
				Library.ToggleKey = input.KeyCode
			end
			task.defer(function()
				window.Listening = nil
				renderKey()
			end)
		end
	end)

	-- Botones de la barra superior: color, minimizar y cerrar
	local fullSize = main.Size
	local function topButton(text, offset)
		return Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Theme.Element,
			Text = text,
			TextColor3 = Theme.TextDim,
			Font = FONT_BOLD,
			Parent = top,
		}, { Corner(6) })
	end
	local closeBtn = topButton("X", -8)
	local minBtn = topButton("-", -38)
	local colorBtn = topButton("", -68)
	local colorDot = Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		Parent = colorBtn,
	}, { Corner(6) })
	accent(colorDot, "BackgroundColor3")

	local popup = Frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 40),
		Size = UDim2.fromOffset(210, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Element,
		Visible = false,
		Parent = main,
	}, { Corner(8), Stroke(), Padding(10, 6), List(4) })
	local popupSection = setmetatable({ Body = popup, Window = window }, Section)
	local accentPicker = popupSection:AddColorpicker({ Name = "Color de acento", Flag = "__accent", Default = Theme.Accent })
	accentPicker.NoSave = true
	accentPicker:OnChanged(function(c)
		Library:SetAccent(c)
	end)
	table.remove(window.Elements) -- el buscador no debe ocultar este selector

	for _, b in ipairs({ closeBtn, minBtn, colorBtn }) do
		connect(b.MouseEnter, function()
			tween(b, { BackgroundColor3 = Theme.ElementHover })
		end)
		connect(b.MouseLeave, function()
			tween(b, { BackgroundColor3 = Theme.Element })
		end)
	end
	connect(colorBtn.MouseButton1Click, function()
		popup.Visible = not popup.Visible
	end)
	connect(minBtn.MouseButton1Click, function()
		window.Minimized = not window.Minimized
		popup.Visible = false
		sidebar.Visible = not window.Minimized
		content.Visible = not window.Minimized
		footer.Visible = not window.Minimized
		main.Size = window.Minimized and UDim2.new(fullSize.X.Scale, fullSize.X.Offset, 0, 36) or fullSize
	end)
	connect(closeBtn.MouseButton1Click, function()
		Library:Unload()
	end)

	connect(search:GetPropertyChangedSignal("Text"), function()
		local q = string.lower(search.Text)
		for _, el in ipairs(window.Elements) do
			el.Frame.Visible = q == "" or string.find(string.lower(el.Name), q, 1, true) ~= nil
		end
	end)

	connect(UserInputService.InputBegan, function(input, processed)
		if not processed and not window.Listening and input.KeyCode == Library.ToggleKey then
			window:Toggle()
		end
	end)

	return window
end

return Library
