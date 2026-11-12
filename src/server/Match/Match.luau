--[[
	Match — uma partida do começo ao voto.

	Fluxo:
	  Warmup → (por round: Freeze → Live → RoundEnd)* → MatchEnd → Vote → fim
	  Modos com respawn pulam os rounds: Freeze → Live (até placar/tempo) → MatchEnd → Vote.

	A mesma classe roda in-place (slot afastado no servidor do lobby) e no match place.
	O estado vai para os clientes via MatchState (snapshot pequeno) — os timers são EndsAt em
	horário de servidor, o cliente faz a contagem sozinho.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)

local Match = {}
Match.__index = Match

export type Params = {
	Mode: Config.ModeDef,
	MapId: string,
	Players: { Player },
	Slot: number,
	OnEnded: (match: any, nextMap: string?, players: { Player }) -> (),
}

type PlayerStats = { Kills: number, Deaths: number, Team: string, Name: string }

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

function Match.new(params: Params)
	local self = setmetatable({}, Match)
	self.Id = HttpService:GenerateGUID(false)
	self.Mode = params.Mode
	self.MapId = params.MapId
	self.Slot = params.Slot
	self.OnEnded = params.OnEnded
	self.Players = table.clone(params.Players) :: { Player }
	self.Roster = table.clone(params.Players) :: { Player } -- quem começou (ELO)
	self.Teams = { A = {}, B = {} } :: { [string]: { Player } }
	self.Stats = {} :: { [Player]: PlayerStats }
	self.Score = { A = 0, B = 0 } :: { [string]: number }
	self.State = "Loading"
	self.Round = 0
	self.EndsAt = 0
	self.Alive = {} :: { [Player]: boolean }
	self.RoundWinner = nil :: string?
	self.Winner = nil :: string?
	self.Results = {} :: { [number]: { [string]: any } }
	self.Votes = {} :: { [Player]: string }
	self.VoteOptions = {} :: { string }
	self.Ended = false
	self.Map = nil :: any
	self._connections = {} :: { RBXScriptConnection | any }
	return self
end

-- ── consultas ───────────────────────────────────────────────────────────────
function Match:GetPlayers(): { Player }
	return table.clone(self.Players)
end

function Match:Has(player: Player): boolean
	return table.find(self.Players, player) ~= nil
end

function Match:TeamOf(player: Player): string
	local stats = self.Stats[player]
	return if stats then stats.Team else "FFA"
end

function Match:AreEnemies(a: Player, b: Player): boolean
	if a == b or not self:Has(a) or not self:Has(b) then
		return false
	end
	if self.Mode.TeamSize == 0 then
		return true
	end
	return self:TeamOf(a) ~= self:TeamOf(b)
end

function Match:RespawnDelay(): number
	return if self.Mode.RoundBased then Config.Match.RoundEndTime else Config.Player.RespawnDelay
end

function Match:IsLive(): boolean
	return self.State == "Live"
end

-- ── rede ────────────────────────────────────────────────────────────────────
function Match:Snapshot()
	local roster = {}
	for player, stats in self.Stats do
		table.insert(roster, {
			UserId = player.UserId,
			Name = stats.Name,
			Team = stats.Team,
			Kills = stats.Kills,
			Deaths = stats.Deaths,
			Alive = self.Alive[player] == true,
		})
	end
	table.sort(roster, function(a, b)
		if a.Kills ~= b.Kills then
			return a.Kills > b.Kills
		end
		return a.Deaths < b.Deaths
	end)
	return {
		Id = self.Id,
		Mode = self.Mode.Id,
		ModeName = self.Mode.DisplayName,
		RoundBased = self.Mode.RoundBased,
		TeamSize = self.Mode.TeamSize,
		Ranked = self.Mode.Ranked,
		MapId = self.MapId,
		MapName = Config.Maps.List[self.MapId].DisplayName,
		MapSubtitle = Config.Maps.List[self.MapId].Subtitle,
		State = self.State,
		Round = self.Round,
		Score = self.Score,
		ScoreToWin = self.Mode.ScoreToWin,
		EndsAt = self.EndsAt,
		Roster = roster,
		RoundWinner = self.RoundWinner,
		Winner = self.Winner,
		Results = self.Results,
	}
end

function Match:Broadcast()
	local snapshot = self:Snapshot()
	local remote = Remotes.Event("MatchState")
	for _, player in self.Players do
		remote:FireClient(player, snapshot)
	end
end

function Match:Notify(text: string, kind: string?)
	for _, player in self.Players do
		Registry.ProgressionService.Toast(player, { Kind = kind or "Info", Text = text })
	end
end

-- ── times e spawns ──────────────────────────────────────────────────────────
function Match:_assignTeams()
	local shuffled = table.clone(self.Players)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	for index, player in shuffled do
		local team = if self.Mode.TeamSize == 0 then "FFA" elseif index % 2 == 1 then "A" else "B"
		if team ~= "FFA" then
			table.insert(self.Teams[team], player)
		end
		self.Stats[player] = { Kills = 0, Deaths = 0, Team = team, Name = player.DisplayName }
		player:SetAttribute("Team", team)
		player:SetAttribute("MatchId", self.Id)
		Registry.CharacterService.SetContext(player, { Kind = "Match", Match = self })
	end
end

function Match:_spawnPoint(player: Player, index: number): CFrame
	local spawns = self.Map.Spawns
	local team = self:TeamOf(player)
	if self.Mode.RoundBased and team ~= "FFA" then
		local list = spawns[team]
		return list[(index - 1) % #list + 1]
	end
	-- respawn: o ponto mais longe dos inimigos vivos
	local list = if team == "FFA" then spawns.FFA else spawns[team]
	if self.Mode.TeamSize > 0 and self.State == "Live" then
		-- em TDM pode nascer em qualquer ponto do lado, o mais seguro
		list = table.clone(spawns[team])
		for _, cf in spawns.FFA do
			table.insert(list, cf)
		end
	end
	local best, bestScore = list[1], -math.huge
	for _, cf in list do
		local nearest = math.huge
		for _, other in self.Players do
			if other ~= player and self:AreEnemies(player, other) and self.Alive[other] then
				local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					nearest = math.min(nearest, (root.Position - cf.Position).Magnitude)
				end
			end
		end
		local score = nearest + math.random() * 8
		if score > bestScore then
			best, bestScore = cf, score
		end
	end
	return best
end

function Match:_spawn(player: Player, index: number, frozen: boolean)
	if not self:Has(player) then
		return
	end
	local cf = self:_spawnPoint(player, index)
	local character = Registry.CharacterService.Spawn(player, cf, {
		Frozen = frozen,
		Protection = if self.Mode.RoundBased then nil else Config.Player.SpawnProtection,
		Regen = not self.Mode.RoundBased,
		Team = self:TeamOf(player),
		Preset = self.Map.Def.Preset,
	})
	if character then
		self.Alive[player] = true
	end
end

function Match:_spawnAll(frozen: boolean)
	local counters = { A = 0, B = 0, FFA = 0 }

	for _, player in self.Players do
		local team = self:TeamOf(player)
		counters[team] += 1
		local index = counters[team]
		task.spawn(function()
			self:_spawn(player, index, frozen)
		end)
	end
	-- espera os personagens (LoadCharacter yielda)
	local deadline = os.clock() + 8
	while os.clock() < deadline do
		local ready = true
		for _, player in self.Players do
			if not self.Alive[player] then
				ready = false
			end
		end
		if ready then
			break
		end
		task.wait(0.1)
	end
end

function Match:_setFrozen(frozen: boolean)
	for _, player in self.Players do
		Registry.CharacterService.SetFrozen(player, frozen)
	end
end

-- ── eventos ─────────────────────────────────────────────────────────────────
function Match:OnKill(info, victimPlayer: Player?)
	local attacker: Player = info.Attacker
	if not victimPlayer or not self:Has(attacker) or not self:Has(victimPlayer) then
		return
	end
	local stats = self.Stats[attacker]
	if stats then
		stats.Kills += 1
	end
	if not self.Mode.RoundBased and self.State == "Live" then
		if self.Mode.TeamSize > 0 then
			local team = self:TeamOf(attacker)
			self.Score[team] = (self.Score[team] or 0) + 1
		end
	end
	self:Broadcast()
end

function Match:OnPlayerDied(player: Player, _character: Model)
	if not self:Has(player) then
		return
	end
	self.Alive[player] = false
	local stats = self.Stats[player]
	if stats then
		stats.Deaths += 1
	end
	self:Broadcast()
	if not self.Mode.RoundBased and (self.State == "Live" or self.State == "Freeze") then
		task.delay(Config.Player.RespawnDelay, function()
			if self.Ended or not self:Has(player) or self.State ~= "Live" then
				return
			end
			self:_spawn(player, 1, false)
			self:Broadcast()
		end)
	end
end

function Match:Vote(player: Player, option: any)
	if self.State ~= "Vote" or not self:Has(player) or type(option) ~= "string" then
		return
	end
	if not table.find(self.VoteOptions, option) then
		return
	end
	self.Votes[player] = option
	self:_broadcastVotes()
end

function Match:RemovePlayer(player: Player)
	local index = table.find(self.Players, player)
	if not index then
		return
	end
	table.remove(self.Players, index)
	for _, list in self.Teams do
		local i = table.find(list, player)
		if i then
			table.remove(list, i)
		end
	end
	self.Alive[player] = nil
	self.Votes[player] = nil
	if player.Parent == Players then
		player:SetAttribute("Team", nil)
		player:SetAttribute("MatchId", nil)
	end
	self:Broadcast()
end

-- ── loop ────────────────────────────────────────────────────────────────────
local function waitUntil(deadline: number, condition: (() -> boolean)?)
	while serverNow() < deadline do
		if condition and condition() then
			return true
		end
		task.wait(0.1)
	end
	return false
end

function Match:_aliveCount(team: string): number
	local count = 0
	for _, player in self.Teams[team] or {} do
		if self.Alive[player] then
			count += 1
		end
	end
	return count
end

function Match:_teamHealth(team: string): number
	local total = 0
	for _, player in self.Teams[team] or {} do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and self.Alive[player] then
			total += humanoid.Health
		end
	end
	return total
end

function Match:_forfeitWinner(): string?
	if self.Mode.TeamSize == 0 then
		return if #self.Players <= 1 then "FFA" else nil
	end
	if #self.Teams.A == 0 and #self.Teams.B > 0 then
		return "B"
	elseif #self.Teams.B == 0 and #self.Teams.A > 0 then
		return "A"
	end
	return nil
end

function Match:_killPlaneLoop()
	task.spawn(function()
		while not self.Ended do
			for _, player in self.Players do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 and root.Position.Y < self.Map.KillY then
					humanoid.Health = 0
				end
			end
			task.wait(0.25)
		end
	end)
end

function Match:_playRounds()
	local mode = self.Mode
	while not self.Ended do
		self.Round += 1
		self.RoundWinner = nil
		self.State = "Freeze"
		self.EndsAt = serverNow() + Config.Match.RoundFreezeTime
		self.Alive = {}
		self:_spawnAll(true)
		self:Broadcast()
		waitUntil(self.EndsAt)
		self:_setFrozen(false)

		self.State = "Live"
		self.EndsAt = serverNow() + mode.TimeLimit
		self:Broadcast()
		waitUntil(self.EndsAt, function()
			return self:_aliveCount("A") == 0 or self:_aliveCount("B") == 0 or self:_forfeitWinner() ~= nil
		end)

		local forfeit = self:_forfeitWinner()
		local winner: string?
		if forfeit then
			winner = forfeit
		elseif self:_aliveCount("A") == 0 and self:_aliveCount("B") > 0 then
			winner = "B"
		elseif self:_aliveCount("B") == 0 and self:_aliveCount("A") > 0 then
			winner = "A"
		else
			-- tempo esgotado: mais vida somada vence; empate não pontua
			local ha, hb = self:_teamHealth("A"), self:_teamHealth("B")
			winner = if ha > hb then "A" elseif hb > ha then "B" else nil
		end
		if winner then
			self.Score[winner] += 1
		end
		self.RoundWinner = winner or "Draw"
		self.State = "RoundEnd"
		self.EndsAt = serverNow() + Config.Match.RoundEndTime
		self:Broadcast()
		waitUntil(self.EndsAt)

		if forfeit then
			self.Score[forfeit] = math.max(self.Score[forfeit], mode.ScoreToWin)
			return
		end
		if self.Score.A >= mode.ScoreToWin or self.Score.B >= mode.ScoreToWin then
			return
		end
	end
end

function Match:_topFfaPlayer(): (Player?, number)
	local best, kills = nil, -1
	for player, stats in self.Stats do
		if self:Has(player) and stats.Kills > kills then
			best, kills = player, stats.Kills
		end
	end
	return best, kills
end

function Match:_playRespawn()
	local mode = self.Mode
	self.State = "Freeze"
	self.EndsAt = serverNow() + Config.Match.RoundFreezeTime
	self:_spawnAll(true)
	self:Broadcast()
	waitUntil(self.EndsAt)
	self:_setFrozen(false)

	self.State = "Live"
	self.Round = 1
	self.EndsAt = serverNow() + mode.TimeLimit
	self:Broadcast()
	waitUntil(self.EndsAt, function()
		if self:_forfeitWinner() ~= nil then
			return true
		end
		if mode.TeamSize > 0 then
			return self.Score.A >= mode.ScoreToWin or self.Score.B >= mode.ScoreToWin
		end
		local _, kills = self:_topFfaPlayer()
		return kills >= mode.ScoreToWin
	end)
end

function Match:_finish()
	local mode = self.Mode
	if mode.TeamSize > 0 then
		self.Winner = if self.Score.A > self.Score.B then "A" elseif self.Score.B > self.Score.A then "B" else "Draw"
	else
		local top = self:_topFfaPlayer()
		self.Winner = if top then tostring(top.UserId) else "Draw"
	end

	local eloDeltas = {}
	if mode.Ranked and mode.TeamSize > 0 then
		local teams = { A = {}, B = {} }
		for _, player in self.Roster do
			local stats = self.Stats[player]
			if stats and player.Parent == Players and teams[stats.Team] then
				table.insert(teams[stats.Team], player)
			end
		end
		local winner = if self.Winner == "Draw" then nil else self.Winner
		eloDeltas = Registry.RankedService.ApplyMatch(teams, winner)
	end

	for _, player in self.Players do
		local stats = self.Stats[player]
		local won = if mode.TeamSize > 0 then stats.Team == self.Winner else tostring(player.UserId) == self.Winner
		local roundsWon = if mode.RoundBased and stats.Team ~= "FFA" then self.Score[stats.Team] or 0 else 0
		local coins, xp = Registry.ProgressionService.MatchResult(player, won, roundsWon)
		local data = Registry.DataService.GetData(player)
		self.Results[player.UserId] = {
			Won = won,
			Coins = coins,
			Xp = xp,
			EloDelta = eloDeltas[player],
			Elo = data and data.Elo,
		}
	end

	self.State = "MatchEnd"
	self.EndsAt = serverNow() + Config.Match.MatchEndTime
	self:_setFrozen(true)
	self:Broadcast()
	waitUntil(self.EndsAt)
end

function Match:_broadcastVotes()
	local counts = {}
	for _, option in self.VoteOptions do
		counts[option] = 0
	end
	for _, option in self.Votes do
		counts[option] = (counts[option] or 0) + 1
	end
	local remote = Remotes.Event("VoteState")
	for _, player in self.Players do
		remote:FireClient(player, {
			Options = self.VoteOptions,
			Counts = counts,
			EndsAt = self.EndsAt,
			Mine = self.Votes[player],
		})
	end
end

function Match:_vote(): string
	local pool = table.clone(Config.Maps.Order)
	for i = #pool, 2, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	self.VoteOptions = {}
	for i = 1, math.min(Config.Match.VoteOptions, #pool) do
		table.insert(self.VoteOptions, pool[i])
	end
	table.insert(self.VoteOptions, "Random")
	self.Votes = {}
	self.State = "Vote"
	self.EndsAt = serverNow() + Config.Match.VoteTime
	self:Broadcast()
	self:_broadcastVotes()
	waitUntil(self.EndsAt, function()
		local voters = 0
		for _ in self.Votes do
			voters += 1
		end
		return voters >= #self.Players and #self.Players > 0
	end)

	local counts = {}
	local best, bestCount = "Random", 0
	for _, option in self.Votes do
		counts[option] = (counts[option] or 0) + 1
		if counts[option] > bestCount then
			best, bestCount = option, counts[option]
		end
	end
	if best == "Random" then
		return Registry.MapService.RandomMap(nil)
	end
	return best
end

function Match:_run()
	self.Map = Registry.MapService.Load(self.MapId, self.Slot)
	self:_assignTeams()
	self:_killPlaneLoop()

	table.insert(self._connections, Registry.DamageService.Killed:Connect(function(info, victimPlayer)
		self:OnKill(info, victimPlayer)
	end))

	self.State = "Warmup"
	self.EndsAt = serverNow() + Config.Match.WarmupTime
	self:Broadcast()
	self:Notify(`{self.Mode.DisplayName} · {self.Map.Def.DisplayName}`, "Match")
	waitUntil(self.EndsAt)

	if self.Mode.RoundBased then
		self:_playRounds()
	else
		self:_playRespawn()
	end

	self:_finish()
	local nextMap = self:_vote()
	self:Destroy()
	self.OnEnded(self, nextMap, self:GetPlayers())
end

function Match:Start()
	task.spawn(function()
		local ok, err = pcall(self._run, self)
		if not ok then
			warn("[Match] erro:", err)
			self:Destroy()
			self.OnEnded(self, nil, self:GetPlayers())
		end
	end)
end

function Match:Destroy()
	if self.Ended then
		return
	end
	self.Ended = true
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for _, player in self.Players do
		if player.Parent == Players then
			player:SetAttribute("Team", nil)
			player:SetAttribute("MatchId", nil)
		end
		-- segura o personagem no lugar enquanto o mapa some (sem queda no vazio)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.Anchored = true
		end
	end
	if self.Map then
		Registry.MapService.Unload(self.Map)
		self.Map = nil
	end
end

return Match
