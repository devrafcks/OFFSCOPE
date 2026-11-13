--[[
	RoundService — cria e acompanha as partidas (Match).

	Papel do servidor:
	  • "Lobby": partidas in-place em slots afastados (até Config.Maps.MaxConcurrentInPlace).
	  • "Match": match place publicado; lê TeleportData {Mode, MapId, Expected}, roda UMA partida
	    e devolve todo mundo ao lobby no fim (ou emenda outra partida após o voto).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)
local Match = require(script.Parent.Parent.Match.Match)

local RoundService = {}

local matches: { [string]: any } = {}
local playerMatch: { [Player]: any } = {}

function RoundService.Role(): string
	if Config.Places.Match ~= 0 and game.PlaceId == Config.Places.Match then
		return "Match"
	end
	return "Lobby"
end

local function isMatchPlace(): boolean
	return RoundService.Role() == "Match"
end

function RoundService.GetMatch(player: Player): any?
	return playerMatch[player]
end

function RoundService.CanStart(): boolean
	return Registry.MapService.HasFreeSlot(isMatchPlace())
end

local function returnToLobby(players: { Player })
	if isMatchPlace() then
		Registry.TeleportServiceWrapper.ToLobby(players)
		return
	end
	for _, player in players do
		if player.Parent == Players then
			Remotes.Event("MatchState"):FireClient(player, nil)
			Registry.CharacterService.SetContext(player, { Kind = "Lobby" })
			task.spawn(Registry.LobbyService.SpawnInLobby, player)
		end
	end
end

local function onEnded(match, nextMap: string?, players: { Player })
	matches[match.Id] = nil
	for _, player in players do
		if playerMatch[player] == match then
			playerMatch[player] = nil
		end
	end
	local stillHere = {}
	for _, player in players do
		if player.Parent == Players then
			table.insert(stillHere, player)
		end
	end
	local enough = #stillHere >= math.max(Config.Match.MinPlayersToContinue, if match.Mode.Players > 2 then 2 else match.Mode.Players)
	if Config.Match.ContinueAfterVote and nextMap and enough then
		local started = RoundService.StartMatch(match.Mode.Id, stillHere, nextMap)
		if started then
			return
		end
	end
	returnToLobby(stillHere)
end

function RoundService.StartMatch(modeId: string, players: { Player }, mapId: string?): boolean
	local mode = Config.Modes[modeId]
	if not mode or #players == 0 then
		return false
	end
	local slot = Registry.MapService.AcquireSlot(isMatchPlace())
	if not slot then
		return false
	end
	local match = Match.new({
		Mode = mode,
		MapId = mapId or Registry.MapService.RandomMap(nil),
		Players = players,
		Slot = slot,
		OnEnded = onEnded,
	})
	matches[match.Id] = match
	for _, player in players do
		playerMatch[player] = match
		Registry.MatchmakingService.Leave(player, true)
	end
	match:Start()
	return true
end

-- Jogador pediu para sair da partida (botão "Voltar ao lobby").
-- desconectar no meio de uma ranked = derrota de ELO na hora
-- (o fim da partida só conta quem ainda está no servidor; sem isso, sair do jogo "salvaria" o ELO)
local function penalizeAbandon(match, player: Player)
	if not match.Mode.Ranked or match.State == "MatchEnd" or match.State == "Vote" then
		return
	end
	local team = player:GetAttribute("Team")
	local opponents = {}
	for name, list in match.Teams do
		if name ~= team then
			for _, other in list do
				table.insert(opponents, other)
			end
		end
	end
	Registry.RankedService.ApplyAbandon(player, opponents)
end

function RoundService.Leave(player: Player)
	local match = playerMatch[player]
	if not match then
		return
	end
	playerMatch[player] = nil
	-- quem volta ao lobby continua no Roster da partida: o fim da ranked já conta a derrota
	match:RemovePlayer(player)
	Remotes.Event("MatchState"):FireClient(player, nil)
	returnToLobby({ player })
end

-- Match place: espera os jogadores que vieram juntos e começa.
local function bootMatchPlace()
	local expected: { number } = {}
	local modeId = "Duel"
	local mapId: string? = nil
	local arrived: { Player } = {}
	local started = false

	local function consider(player: Player)
		local joinData = player:GetJoinData()
		local data = joinData and joinData.TeleportData
		if type(data) == "table" then
			if type(data.Mode) == "string" and Config.Modes[data.Mode] then
				modeId = data.Mode
			end
			if type(data.MapId) == "string" and Config.Maps.List[data.MapId] then
				mapId = data.MapId
			end
			if type(data.Expected) == "table" then
				expected = data.Expected
			end
		end
		table.insert(arrived, player)
	end

	Players.PlayerAdded:Connect(function(player)
		if started then
			-- reconexão / atrasado: volta ao lobby
			Registry.TeleportServiceWrapper.ToLobby({ player })
			return
		end
		consider(player)
	end)
	for _, player in Players:GetPlayers() do
		consider(player)
	end

	local deadline = os.clock() + 25
	while os.clock() < deadline do
		if #expected > 0 and #arrived >= #expected then
			break
		end
		task.wait(0.5)
	end
	started = true
	local ready = {}
	for _, player in arrived do
		if player.Parent == Players and Registry.DataService.Wait(player, 10) then
			table.insert(ready, player)
		end
	end
	if #ready == 0 then
		return
	end
	RoundService.StartMatch(modeId, ready, mapId)
end

function RoundService.Init()
	Remotes.Event("Vote").OnServerEvent:Connect(function(player, option)
		local match = playerMatch[player]
		if match then
			match:Vote(player, option)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local match = playerMatch[player]
		playerMatch[player] = nil
		if match then
			penalizeAbandon(match, player)
			match:RemovePlayer(player)
		end
	end)
end

function RoundService.Start()
	if isMatchPlace() then
		bootMatchPlace()
	end
end

return RoundService
