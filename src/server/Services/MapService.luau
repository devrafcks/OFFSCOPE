--[[
	MapService — carrega UM mapa por partida num "slot" e descarrega no fim.
	Slot 0 = origem (lobby, ou a partida no match place). Slots 1..N = arenas in-place afastadas.
	Os outros mapas nunca são instanciados.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)

local MapService = {}

local Maps = ServerScriptService.Server.Maps
local builders = {
	Cais09 = require(Maps.Cais09),
	Avenida11 = require(Maps.Avenida11),
	Posto47 = require(Maps.Posto47),
}

export type LoadedMap = {
	MapId: string,
	Def: Config.MapDef,
	Slot: number,
	Origin: CFrame,
	Model: Model,
	Spawns: { A: { CFrame }, B: { CFrame }, FFA: { CFrame } },
	KillY: number,
	Cleanup: () -> (),
}

local slotsInUse: { [number]: boolean } = {}

function MapService.SlotOrigin(slot: number): CFrame
	return CFrame.new(slot * Config.Maps.SlotSpacing, 0, 0)
end

-- `allowZero` = match place (não há lobby na origem).
function MapService.AcquireSlot(allowZero: boolean?): number?
	local first = if allowZero then 0 else 1
	for slot = first, Config.Maps.MaxConcurrentInPlace do
		if not slotsInUse[slot] then
			slotsInUse[slot] = true
			return slot
		end
	end
	return nil
end

function MapService.ReleaseSlot(slot: number)
	slotsInUse[slot] = nil
end

function MapService.HasFreeSlot(allowZero: boolean?): boolean
	local first = if allowZero then 0 else 1
	for slot = first, Config.Maps.MaxConcurrentInPlace do
		if not slotsInUse[slot] then
			return true
		end
	end
	return false
end

function MapService.RandomMap(exclude: string?): string
	local options = {}
	for _, id in Config.Maps.Order do
		if id ~= exclude then
			table.insert(options, id)
		end
	end
	if #options == 0 then
		return Config.Maps.Order[1]
	end
	return options[math.random(1, #options)]
end

function MapService.Load(mapId: string, slot: number): LoadedMap
	local def = Config.Maps.List[mapId] or Config.Maps.List[Config.Maps.Order[1]]
	local builder = builders[def.Builder]
	local origin = MapService.SlotOrigin(slot)
	local started = os.clock()
	local built = builder.Build(origin)
	built.Model:SetAttribute("MapId", def.Id)
	built.Model:SetAttribute("Slot", slot)
	print(string.format("[MapService] %s carregado no slot %d em %.0f ms", def.Id, slot, (os.clock() - started) * 1000))
	return {
		MapId = def.Id,
		Def = def,
		Slot = slot,
		Origin = origin,
		Model = built.Model,
		Spawns = built.Spawns,
		KillY = built.KillY,
		Cleanup = built.Cleanup,
	}
end

function MapService.Unload(map: LoadedMap)
	map.Cleanup()
	MapService.ReleaseSlot(map.Slot)
end

return MapService
