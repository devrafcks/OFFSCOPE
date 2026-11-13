local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = {}

Theme.Colors = {
	Ink = Color3.fromRGB(12, 12, 14),
	Panel = Color3.fromRGB(44, 46, 52),
	PanelHi = Color3.fromRGB(68, 71, 79),
	PanelLo = Color3.fromRGB(30, 31, 36),
	Line = Color3.fromRGB(12, 12, 14),
	LineSoft = Color3.fromRGB(86, 90, 99),
	Text = Color3.fromRGB(246, 245, 240),
	TextDim = Color3.fromRGB(178, 180, 187),
	Brand = Color3.fromRGB(255, 184, 48),
	BrandDark = Color3.fromRGB(176, 118, 20),
	Good = Color3.fromRGB(96, 220, 140),
	Bad = Color3.fromRGB(255, 84, 84),
	TeamA = Color3.fromRGB(80, 170, 255),
	TeamB = Color3.fromRGB(255, 96, 86),
	Coin = Color3.fromRGB(255, 206, 84),
}

local function family(name: string, weight: Enum.FontWeight): Font
	return Font.new(`rbxasset://fonts/families/{name}.json`, weight)
end

Theme.Fonts = {
	Display = family("LuckiestGuy", Enum.FontWeight.Regular),
	Title = family("FredokaOne", Enum.FontWeight.Regular),
	Body = family("FredokaOne", Enum.FontWeight.Regular),
	Mono = family("FredokaOne", Enum.FontWeight.Regular),
}

local OUTLINED = { LuckiestGuy = 2.4, FredokaOne = 1.4 }

local function outlineFor(font: Font): number?
	return OUTLINED[(font.Family:match("families/(%w+)%.json") or "")]
end

function Theme.New(className: string, props: { [any]: any }?): any
	local instance = Instance.new(className)
	local parent = nil
	for key, value in (props or {}) :: { [any]: any } do
		if type(key) == "number" then
			value.Parent = instance
		elseif key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Theme.Corner(radius: number?): UICorner
	return Theme.New("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Theme.TextOutline(label: GuiObject, thickness: number?)
	Theme.New("UIStroke", {
		Color = Theme.Colors.Ink,
		Thickness = thickness or 2,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = label,
	})
end

function Theme.Shade(target: GuiObject, color: Color3, lip: number?)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.1)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.38)
	local keypoints
	if lip and lip > 0 then
		local edge = 1 - lip
		keypoints = {
			ColorSequenceKeypoint.new(0, light),
			ColorSequenceKeypoint.new(edge - 0.001, color),
			ColorSequenceKeypoint.new(edge, dark),
			ColorSequenceKeypoint.new(1, dark),
		}
	else
		keypoints = { ColorSequenceKeypoint.new(0, light), ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.12)) }
	end
	target.BackgroundColor3 = Color3.new(1, 1, 1)
	return Theme.New("UIGradient", { Color = ColorSequence.new(keypoints), Rotation = 90, Parent = target })
end

Theme.MinText = 13
Theme.MinButtonText = 14

function Theme.Fit(frame: GuiObject, design: Vector2, margin: number?): UIScale
	local scale = frame:FindFirstChildOfClass("UIScale") or Theme.New("UIScale", { Parent = frame })
	local pad = margin or 24
	local function update()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local fit = math.clamp(math.min((viewport.X - pad) / design.X, (viewport.Y - pad) / design.Y), 0.6, 1)
		frame:SetAttribute("FitScale", fit)
		scale.Scale = fit
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return scale
end

function Theme.FitScale(frame: GuiObject): number
	return (frame:GetAttribute("FitScale") :: number?) or 1
end

function Theme.Stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Theme.New("UIStroke", {
		Color = color or Theme.Colors.Line,
		Thickness = math.max(thickness or 1, 2.5),
		Transparency = (transparency or 0) * 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.Padding(all: number, horizontal: number?): UIPadding
	local h = horizontal or all
	return Theme.New("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, h),
		PaddingRight = UDim.new(0, h),
	})
end

function Theme.List(direction: Enum.FillDirection?, padding: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return Theme.New("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function Theme.Label(props: { [any]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		defaults[key] = value
	end
	local label = Theme.New("TextLabel", defaults)
	if not label.TextScaled then
		label.TextSize = math.max(label.TextSize, Theme.MinText)
	end

	local c = label.TextColor3
	local luminance = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	local outline = outlineFor(label.FontFace)
	if outline and luminance > 0.35 and props.Outline ~= false then
		Theme.TextOutline(label, outline)
	end
	return label
end

function Theme.Panel(props: { [any]: any }): Frame
	local defaults = {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
	}
	for key, value in props do
		defaults[key] = value
	end
	local frame = Theme.New("Frame", defaults)
	Theme.Corner(16).Parent = frame
	Theme.Stroke(Theme.Colors.Ink, 3, 0).Parent = frame
	Theme.Shade(frame, defaults.BackgroundColor3)
	return frame
end

function Theme.Button(text: string, style: string?, props: { [any]: any }?): TextButton
	local s = style or "Primary"
	local bg = if s == "Primary" then Theme.Colors.Brand elseif s == "Danger" then Theme.Colors.Bad else Theme.Colors.PanelHi
	local fg = if s == "Primary" then Theme.Colors.Ink else Theme.Colors.Text
	local defaults = {
		Text = text,
		AutoButtonColor = false,
		BackgroundColor3 = bg,
		BorderSizePixel = 0,
		FontFace = Theme.Fonts.Title,
		TextColor3 = fg,
		TextSize = 16,
		Size = UDim2.fromOffset(160, 40),
	}
	for key, value in (props or {}) :: { [any]: any } do
		defaults[key] = value
	end
	local button = Theme.New("TextButton", defaults)
	button.TextSize = math.max(button.TextSize, Theme.MinButtonText)
	Theme.Corner(12).Parent = button
	Theme.Stroke(Theme.Colors.Ink, 3, 0).Parent = button

	button.TextTransparency = 1
	local face = Theme.New("TextLabel", {
		Name = "Face",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 1, -4),
		Position = UDim2.fromOffset(4, 0),
		ZIndex = button.ZIndex + 1,
		Parent = button,
	})
	local outline: UIStroke? = nil
	local function sync()
		face.Text = button.Text
		face.TextColor3 = button.TextColor3
		face.TextSize = button.TextSize
		face.FontFace = button.FontFace
		face.TextScaled = button.TextScaled
		face.TextWrapped = button.TextWrapped
		face.RichText = button.RichText
		face.TextXAlignment = button.TextXAlignment
		local c = button.TextColor3
		local wantsOutline = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B > 0.35
		if wantsOutline and not outline then
			outline = Theme.New("UIStroke", { Color = Theme.Colors.Ink, Thickness = 1.6, LineJoinMode = Enum.LineJoinMode.Round, Parent = face })
		elseif not wantsOutline and outline then
			(outline :: UIStroke):Destroy()
			outline = nil
		end
	end
	sync()
	for _, property in { "Text", "TextColor3", "TextSize", "FontFace", "TextScaled", "TextWrapped", "RichText", "TextXAlignment" } do
		button:GetPropertyChangedSignal(property):Connect(sync)
	end
	local gradient = Theme.Shade(button, bg, 0.16)
	local scale = Theme.New("UIScale", { Parent = button })
	local hovered = false
	local function paint(color: Color3)
		gradient:Destroy()
		gradient = Theme.Shade(button, color, 0.16)
	end
	button.MouseEnter:Connect(function()
		hovered = true
		paint(((button:GetAttribute("BaseColor") :: Color3?) or bg):Lerp(Color3.new(1, 1, 1), 0.14))
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		paint((button:GetAttribute("BaseColor") :: Color3?) or bg)
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Scale = if hovered then 1.04 else 1 }):Play()
	end)
	button:SetAttribute("BaseColor", bg)
	button:GetAttributeChangedSignal("BaseColor"):Connect(function()
		paint((button:GetAttribute("BaseColor") :: Color3?) or bg)
	end)
	return button
end

function Theme.SetButtonColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
end

function Theme.Tween(instance: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

return Theme
