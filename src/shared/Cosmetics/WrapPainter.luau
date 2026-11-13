local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config)
local AssetIds = require(script.Parent.Parent.AssetIds)

local WrapPainter = {}

local FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Bottom }

local function clearExtras(model: Instance)
	for _, child in model:GetDescendants() do
		if child:GetAttribute("WrapExtra") then
			child:Destroy()
		end
	end
end

local function sampleGradient(colors: { Color3 }, t: number): Color3
	local n = #colors
	if n == 1 then
		return colors[1]
	end
	local scaled = (t % 1) * (n - 1)
	local index = math.floor(scaled)
	local alpha = scaled - index
	return colors[index + 1]:Lerp(colors[math.min(index + 2, n)], alpha)
end

export type Options = {
	Textures: boolean?,
	Animate: boolean?,
}

function WrapPainter.Apply(model: Instance, wrapId: string?, options: Options?): () -> ()
	local opts = options or {}
	local def = Config.Cosmetics[wrapId or ""] or Config.Cosmetics[Config.DefaultEquipped.Wrap]
	local visual = def.Visual
	clearExtras(model)

	local animated: { BasePart } = {}
	local textureKey = visual.Texture and visual.Texture.Key
	local textureId = textureKey and AssetIds.Textures[textureKey]

	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local group = part:GetAttribute("Group")
		local spec = group and visual[group]
		if not spec then
			continue
		end

		part.Color = spec[1]
		local ok, material = pcall(function()
			return (Enum.Material :: any)[spec[2]]
		end)
		part.Material = if ok and material then material else Enum.Material.SmoothPlastic

		if part.Material == Enum.Material.ForceField and visual.Underlay then
			local under = part:Clone()
			under:ClearAllChildren()
			under.Name = part.Name .. "_Under"
			under.Material = Enum.Material.SmoothPlastic
			under.Color = visual.Underlay
			under.Size = part.Size * 0.94
			under.CFrame = part.CFrame
			under:SetAttribute("Group", nil)
			under:SetAttribute("WrapExtra", true)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = under
			weld.Parent = under
			under.Parent = part
			table.insert(animated, part)
		end

		if opts.Textures and textureId and table.find(visual.Texture.Groups, group) then
			for _, face in FACES do
				local texture = Instance.new("Texture")
				texture.Texture = textureId
				texture.Face = face
				texture.StudsPerTileU = visual.Texture.StudsPerTile
				texture.StudsPerTileV = visual.Texture.StudsPerTile
				texture:SetAttribute("WrapExtra", true)
				texture.Parent = part
			end
		end

		if visual.Animated and (group == "Accent" or part.Material == Enum.Material.ForceField) then
			if not table.find(animated, part) then
				table.insert(animated, part)
			end
		end
	end

	if not (opts.Animate and visual.Animated and #animated > 0) then
		return function() end
	end

	local anim = visual.Animated
	local start = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) * anim.Speed
		local color: Color3
		if anim.Kind == "Pulse" then
			local alpha = (math.sin(t * math.pi * 2) + 1) * 0.5
			color = anim.Colors[1]:Lerp(anim.Colors[2], alpha)
		else
			color = sampleGradient(anim.Colors, t)
		end
		for _, part in animated do
			part.Color = color
		end
	end)
	return function()
		connection:Disconnect()
	end
end

function WrapPainter.PaintKnife(model: Instance, knifeId: string?)
	local def = Config.Cosmetics[knifeId or ""] or Config.Cosmetics[Config.DefaultEquipped.Knife]
	local visual = def.Visual
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local group = part:GetAttribute("Group")
		local spec = group and visual[group]
		if spec then
			part.Color = spec[1]
			part.Material = (Enum.Material :: any)[spec[2]] or Enum.Material.Metal
		end
		if group == "Blade" and visual.Glow then
			local light = part:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
			light.Color = spec[1]
			light.Range = 4
			light.Brightness = 1.4
			light.Shadows = false
			light.Parent = part
		end
	end
end

return WrapPainter
