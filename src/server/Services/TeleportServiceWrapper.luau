--[[
	TeleportServiceWrapper — SafeTeleport (padrão da doc oficial de teleport).
	pcall + retry com espera + reenvio em TeleportInitFailed. Só o servidor teleporta.
	TeleportData leva apenas { Mode, MapId, Ranked, Teams } — nada de economia.
]]

local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TeleportServiceWrapper = {}

local RETRYABLE = {
	[Enum.TeleportResult.Flooded] = true,
	[Enum.TeleportResult.Failure] = true,
}

function TeleportServiceWrapper.SafeTeleport(placeId: number, players: { Player }, options: TeleportOptions?): boolean
	local attempts = 0
	local success, result
	repeat
		success, result = pcall(function()
			return TeleportService:TeleportAsync(placeId, players, options)
		end)
		attempts += 1
		if not success then
			task.wait(Config.Matchmaking.TeleportRetryDelay)
		end
	until success or attempts >= Config.Matchmaking.TeleportRetries
	if not success then
		warn("[Teleport] falhou:", result)
	end
	return success
end

-- Reserva um servidor do match place. Retorna o access code (ou nil).
function TeleportServiceWrapper.Reserve(placeId: number): string?
	local ok, code = pcall(function()
		local accessCode = TeleportService:ReserveServer(placeId)
		return accessCode
	end)
	if not ok then
		warn("[Teleport] ReserveServer falhou:", code)
		return nil
	end
	return code
end

function TeleportServiceWrapper.ToReserved(placeId: number, players: { Player }, accessCode: string, data: { [string]: any }): boolean
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData(data)
	return TeleportServiceWrapper.SafeTeleport(placeId, players, options)
end

function TeleportServiceWrapper.ToLobby(players: { Player }): boolean
	if Config.Places.Lobby == 0 then
		return false
	end
	return TeleportServiceWrapper.SafeTeleport(Config.Places.Lobby, players)
end

function TeleportServiceWrapper.Init()
	TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId, options)
		if RETRYABLE[result] then
			task.wait(Config.Matchmaking.TeleportRetryDelay)
			TeleportServiceWrapper.SafeTeleport(placeId, { player }, options)
		else
			warn(`[Teleport] {player.Name}: {result.Name} {message}`)
		end
	end)
end

return TeleportServiceWrapper
