--[[
	LightingPresets — identidade visual de cada mapa (aplicada no CLIENTE).
	Como Lighting é global, aplicar localmente permite lobby e partidas in-place com céus diferentes.

	Receita "ultrarrealista" (ver pesquisa §6): LightingStyle.Realistic, EnvironmentDiffuse/Specular = 1,
	Ambient com matiz, Atmosphere para profundidade, Clouds (filho de Terrain), pós leve.
	DoF nunca no gameplay — só na killcam.
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LightingPresets = {}

local C = Color3.fromRGB

export type Preset = {
	Lighting: { [string]: any },
	Atmosphere: { [string]: any },
	Clouds: { [string]: any }?,
	ColorCorrection: { [string]: any },
	Bloom: { [string]: any },
	SunRays: { [string]: any }?,
	Sky: { [string]: any },
	Ambience: string?,
	Reverb: Enum.ReverbType?,
}

LightingPresets.List = {
	Lobby = {
		Lighting = {
			ClockTime = 14.2,
			GeographicLatitude = 28,
			Brightness = 2.6,
			Ambient = C(64, 66, 74),
			OutdoorAmbient = C(118, 124, 138),
			ColorShift_Top = C(255, 244, 228),
			ColorShift_Bottom = C(40, 44, 52),
			ExposureCompensation = 0.1,
			ShadowSoftness = 0.25,
		},
		Atmosphere = { Density = 0.28, Offset = 0.12, Color = C(200, 212, 228), Decay = C(120, 136, 160), Glare = 0.2, Haze = 1.2 },
		Clouds = { Cover = 0.55, Density = 0.55, Color = C(250, 250, 255) },
		ColorCorrection = { Brightness = 0.02, Contrast = 0.12, Saturation = 0.05, TintColor = C(255, 252, 246) },
		Bloom = { Intensity = 0.35, Size = 26, Threshold = 1.6 },
		SunRays = { Intensity = 0.05, Spread = 0.7 },
		Sky = { SunAngularSize = 14, MoonAngularSize = 9, StarCount = 600 },
		Reverb = Enum.ReverbType.Hangar,
	},

	-- porto ao amanhecer: névoa úmida, sol rasante e rosado, contraste suave
	Cais09 = {
		Lighting = {
			ClockTime = 6.15,
			GeographicLatitude = 41,
			Brightness = 2.1,
			Ambient = C(70, 76, 92),
			OutdoorAmbient = C(126, 120, 136),
			ColorShift_Top = C(255, 196, 160),
			ColorShift_Bottom = C(60, 70, 96),
			ExposureCompensation = 0.25,
			ShadowSoftness = 0.45,
		},
		Atmosphere = { Density = 0.42, Offset = 0.18, Color = C(214, 196, 196), Decay = C(108, 112, 140), Glare = 1.1, Haze = 2.3 },
		Clouds = { Cover = 0.72, Density = 0.42, Color = C(255, 214, 200) },
		ColorCorrection = { Brightness = 0.0, Contrast = 0.14, Saturation = -0.06, TintColor = C(255, 240, 236) },
		Bloom = { Intensity = 0.45, Size = 30, Threshold = 1.45 },
		SunRays = { Intensity = 0.09, Spread = 0.8 },
		Sky = { SunAngularSize = 18, MoonAngularSize = 8, StarCount = 200 },
		Ambience = "AmbientHarbor",
		Reverb = Enum.ReverbType.Plain,
	},

	-- centro à noite com chuva recente: azul frio, neon, asfalto espelhado
	Avenida11 = {
		Lighting = {
			ClockTime = 0.4,
			GeographicLatitude = 23,
			Brightness = 0.6,
			Ambient = C(38, 42, 62),
			OutdoorAmbient = C(52, 58, 86),
			ColorShift_Top = C(140, 160, 255),
			ColorShift_Bottom = C(30, 30, 50),
			ExposureCompensation = 0.55,
			ShadowSoftness = 0.3,
		},
		Atmosphere = { Density = 0.36, Offset = 0.08, Color = C(70, 76, 110), Decay = C(40, 34, 70), Glare = 0, Haze = 1.6 },
		Clouds = { Cover = 0.85, Density = 0.6, Color = C(70, 74, 100) },
		ColorCorrection = { Brightness = 0.02, Contrast = 0.2, Saturation = 0.1, TintColor = C(232, 236, 255) },
		Bloom = { Intensity = 0.8, Size = 36, Threshold = 1.15 },
		SunRays = nil,
		Sky = { SunAngularSize = 10, MoonAngularSize = 13, StarCount = 900 },
		Ambience = "AmbientCity",
		Reverb = Enum.ReverbType.City,
	},

	-- serra na golden hour: luz dourada lateral, ar limpo e profundo, nuvens visíveis
	Posto47 = {
		Lighting = {
			ClockTime = 17.6,
			GeographicLatitude = 35,
			Brightness = 2.8,
			Ambient = C(84, 74, 66),
			OutdoorAmbient = C(150, 128, 110),
			ColorShift_Top = C(255, 200, 140),
			ColorShift_Bottom = C(80, 70, 70),
			ExposureCompensation = 0.05,
			ShadowSoftness = 0.2,
		},
		Atmosphere = { Density = 0.3, Offset = 0.04, Color = C(232, 200, 168), Decay = C(140, 120, 130), Glare = 1.6, Haze = 1.1 },
		Clouds = { Cover = 0.6, Density = 0.7, Color = C(255, 226, 196) },
		ColorCorrection = { Brightness = 0.01, Contrast = 0.16, Saturation = 0.08, TintColor = C(255, 246, 232) },
		Bloom = { Intensity = 0.4, Size = 28, Threshold = 1.5 },
		SunRays = { Intensity = 0.12, Spread = 0.6 },
		Sky = { SunAngularSize = 20, MoonAngularSize = 9, StarCount = 300 },
		Ambience = "AmbientMountain",
		Reverb = Enum.ReverbType.Mountains,
	},
} :: { [string]: Preset }

local function ensure(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

local function assign(instance: Instance, props: { [string]: any })
	for key, value in props do
		pcall(function()
			(instance :: any)[key] = value
		end)
	end
end

export type ApplyOptions = { Performance: boolean?, Tween: number? }

function LightingPresets.Apply(presetId: string, options: ApplyOptions?)
	local preset = LightingPresets.List[presetId] or LightingPresets.List.Lobby
	local opts = options or {}
	local performance = opts.Performance == true

	-- caminho oficial atual (Unified Lighting); pcall porque a API pode não existir em builds antigos
	pcall(function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Realistic
		;(Lighting :: any).PrioritizeLightingQuality = not performance
	end)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true

	local tweenTime = opts.Tween or 0
	if tweenTime > 0 then
		local tweenable = {}
		for key, value in preset.Lighting do
			if typeof(value) == "number" or typeof(value) == "Color3" then
				tweenable[key] = value
			end
		end
		TweenService:Create(Lighting, TweenInfo.new(tweenTime, Enum.EasingStyle.Sine), tweenable):Play()
	else
		assign(Lighting, preset.Lighting)
	end

	assign(ensure(Lighting, "Atmosphere", "OffscopeAtmosphere"), preset.Atmosphere)
	assign(ensure(Lighting, "Sky", "OffscopeSky"), preset.Sky)
	assign(ensure(Lighting, "ColorCorrectionEffect", "OffscopeGrade"), preset.ColorCorrection)

	local bloom = ensure(Lighting, "BloomEffect", "OffscopeBloom") :: BloomEffect
	assign(bloom, preset.Bloom)
	bloom.Enabled = not performance

	local rays = ensure(Lighting, "SunRaysEffect", "OffscopeRays") :: SunRaysEffect
	if preset.SunRays and not performance then
		assign(rays, preset.SunRays)
		rays.Enabled = true
	else
		rays.Enabled = false
	end

	local terrain = Workspace.Terrain
	if preset.Clouds then
		local clouds = ensure(terrain, "Clouds", "OffscopeClouds") :: Clouds
		assign(clouds, preset.Clouds)
		clouds.Enabled = true
	else
		local clouds = terrain:FindFirstChild("OffscopeClouds")
		if clouds then
			(clouds :: Clouds).Enabled = false
		end
	end

	-- DoF existe mas fica desligado: só a killcam liga
	local dof = ensure(Lighting, "DepthOfFieldEffect", "OffscopeDof") :: DepthOfFieldEffect
	dof.Enabled = false
	dof.FarIntensity = 0.35
	dof.FocusDistance = 30
	dof.InFocusRadius = 40
	dof.NearIntensity = 0.2

	if preset.Reverb then
		pcall(function()
			game:GetService("SoundService").AmbientReverb = preset.Reverb :: Enum.ReverbType
		end)
	end

	return preset
end

return LightingPresets
