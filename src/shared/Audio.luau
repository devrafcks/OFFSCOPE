--[[
	Audio — toca sons por chave (Config.Audio). Resolve o id em AssetIds (upload próprio)
	ou cai para o fallback local `rbxasset://` que vem com o client do Roblox.
	Nunca usa áudio de terceiros com copyright.
]]

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)
local AssetIds = require(script.Parent.AssetIds)

local Audio = {}

export type PlayOptions = {
	Volume: number?,
	Pitch: number?,
	RollOff: number?,
	Parent: Instance?,
	Position: Vector3?,
	Looped: boolean?,
}

local function resolve(key: string): (string?, number)
	local def = (Config.Audio :: any)[key]
	if not def then
		return nil, 1
	end
	local uploaded = AssetIds.Audio[key]
	if uploaded and uploaded ~= "" then
		return uploaded, 1
	end
	if def.Fallback then
		return def.Fallback, def.FallbackPitch or 1
	end
	return nil, 1
end

function Audio.Has(key: string): boolean
	return (resolve(key)) ~= nil
end

function Audio.Create(key: string, options: PlayOptions?): Sound?
	local id, basePitch = resolve(key)
	if not id then
		return nil
	end
	local opts = options or {}
	local def = (Config.Audio :: any)[key]
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = id
	sound.Volume = (opts.Volume or 1) * (def.Volume or 1)
	sound.PlaybackSpeed = basePitch * (opts.Pitch or 1)
	sound.Looped = opts.Looped == true
	sound.RollOffMaxDistance = opts.RollOff or 400
	sound.RollOffMinDistance = 8
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	return sound
end

-- Som 2D (UI, primeira pessoa).
function Audio.Play2D(key: string, options: PlayOptions?)
	local sound = Audio.Create(key, options)
	if not sound then
		return
	end
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength, 3) + 1)
end

-- Som 3D numa posição do mundo ou preso a uma instância.
function Audio.Play3D(key: string, options: PlayOptions?): Sound?
	local opts = options or {}
	local sound = Audio.Create(key, opts)
	if not sound then
		return nil
	end
	if opts.Parent then
		sound.Parent = opts.Parent
	else
		local holder = Instance.new("Attachment")
		holder.Name = "Sfx"
		holder.WorldPosition = opts.Position or Vector3.zero
		holder.Parent = Workspace.Terrain
		sound.Parent = holder
		Debris:AddItem(holder, 6)
	end
	sound:Play()
	if not sound.Looped then
		Debris:AddItem(sound, 6)
	end
	return sound
end

return Audio
