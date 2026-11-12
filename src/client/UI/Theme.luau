--[[
	Theme — tokens visuais do OFFSCOPE e um `New` declarativo para montar UI sem boilerplate.

	Direção de arte: tático e limpo. Fundo grafite translúcido, branco quente para texto,
	âmbar como cor de marca (o "flash" do disparo), cores de raridade nos cosméticos.
]]

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Ink = Color3.fromRGB(10, 11, 13),
	Panel = Color3.fromRGB(18, 20, 24),
	PanelHi = Color3.fromRGB(28, 31, 37),
	Line = Color3.fromRGB(58, 62, 70),
	Text = Color3.fromRGB(240, 238, 232),
	TextDim = Color3.fromRGB(160, 162, 168),
	Brand = Color3.fromRGB(255, 184, 48),
	BrandDark = Color3.fromRGB(176, 118, 20),
	Good = Color3.fromRGB(96, 220, 140),
	Bad = Color3.fromRGB(255, 84, 84),
	TeamA = Color3.fromRGB(80, 170, 255),
	TeamB = Color3.fromRGB(255, 96, 86),
	Coin = Color3.fromRGB(255, 206, 84),
}

Theme.Fonts = {
	Display = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
	Title = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
	Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
}

-- New("Frame", { Size = ..., [children] }) — tabelas na parte de array viram filhos.
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
	return Theme.New("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Theme.Stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Theme.New("UIStroke", {
		Color = color or Theme.Colors.Line,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
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
	return Theme.New("TextLabel", defaults)
end

function Theme.Panel(props: { [any]: any }): Frame
	local defaults = {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
	}
	for key, value in props do
		defaults[key] = value
	end
	local frame = Theme.New("Frame", defaults)
	Theme.Corner(10).Parent = frame
	Theme.Stroke(Theme.Colors.Line, 1, 0.4).Parent = frame
	return frame
end

-- Botão com hover/press animados. `style`: "Primary" | "Ghost" | "Danger"
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
	Theme.Corner(8).Parent = button
	if s == "Ghost" then
		Theme.Stroke(Theme.Colors.Line, 1, 0.2).Parent = button
	end
	local scale = Theme.New("UIScale", { Parent = button })
	local base = bg
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.12) }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.96 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	button:SetAttribute("BaseColor", base)
	return button
end

function Theme.SetButtonColor(button: TextButton, color: Color3)
	button.BackgroundColor3 = color
end

function Theme.Tween(instance: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

return Theme
