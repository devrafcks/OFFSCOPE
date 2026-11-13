local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(Shared.Util.RateLimiter)
local Registry = require(script.Parent.Parent.Registry)

local MatchmakingService = {}

local queues: { [string]: { Player } } = {}
local playerMode: { [Player]: string } = {}
local limiter = RateLimiter.new(6, 2)

for _, modeId in Config.ModeOrder do
	queues[modeId] = {}
end

local function crossServer(): boolean
	return Config.Places.Match ~= 0 and not RunService:IsStudio() and Registry.RoundService.Role() == "Lobby"
end

local function needed(modeId: string): number
	local mode = Config.Modes[modeId]
	if RunService:IsStudio() and Config.Studio.MinPlayersOverride then
		return math.min(mode.Players, Config.Studio.MinPlayersOverride)
	end
	return mode.Players
end

local function sendState(modeId: string)
	local queue = queues[modeId]
	local remote = Remotes.Event("QueueState")
	for _, player in queue do
		remote:FireClient(player, {
			Mode = modeId,
			Count = #queue,
			Needed = needed(modeId),
			CrossServer = crossServer(),
		})
	end
end

function MatchmakingService.QueueCount(modeId: string): number
	return #(queues[modeId] or {})
end

function MatchmakingService.ModeOf(player: Player): string?
	return playerMode[player]
end

local function memoryQueue(modeId: string): MemoryStoreQueue
	return MemoryStoreService:GetQueue(Config.Matchmaking.QueuePrefix .. modeId, 30)
end

local function assignments(): MemoryStoreSortedMap
	return MemoryStoreService:GetSortedMap(Config.Matchmaking.AssignmentMap)
end

local function cancellations(): MemoryStoreSortedMap
	return MemoryStoreService:GetSortedMap(Config.Matchmaking.AssignmentMap .. "_Cancel")
end

local function enqueueRemote(player: Player, modeId: string)
	pcall(function()
		cancellations():RemoveAsync(tostring(player.UserId))
		local data = Registry.DataService.GetData(player)
		memoryQueue(modeId):AddAsync({ UserId = player.UserId, Elo = data and data.Elo or 1000, At = os.time() }, Config.Matchmaking.QueueEntryTtl, 0)
	end)
end

local function cancelRemote(player: Player)
	pcall(function()
		cancellations():SetAsync(tostring(player.UserId), true, Config.Matchmaking.QueueEntryTtl)
	end)
end

local function matchRemote(modeId: string)
	local mode = Config.Modes[modeId]
	local queue = memoryQueue(modeId)
	local ok, items, readId = pcall(function()
		return queue:ReadAsync(mode.Players, true, 0)
	end)
	if not ok or not items or #items < mode.Players then
		return
	end
	local valid = {}
	local seen = {}
	for _, entry in items do
		local userId = type(entry) == "table" and entry.UserId
		local canceled = false
		pcall(function()
			canceled = cancellations():GetAsync(tostring(userId)) == true
		end)
		if userId and not seen[userId] and not canceled then
			seen[userId] = true
			table.insert(valid, entry)
		end
	end
	pcall(function()
		queue:RemoveAsync(readId)
	end)
	if #valid < mode.Players then

		for _, entry in valid do
			pcall(function()
				queue:AddAsync(entry, Config.Matchmaking.QueueEntryTtl, 1)
			end)
		end
		return
	end
	local accessCode = Registry.TeleportServiceWrapper.Reserve(Config.Places.Match)
	if not accessCode then
		return
	end
	local expected = {}
	for _, entry in valid do
		table.insert(expected, entry.UserId)
	end
	local payload = {
		AccessCode = accessCode,
		Mode = modeId,
		MapId = Registry.MapService.RandomMap(nil),
		Expected = expected,
	}
	for _, entry in valid do
		pcall(function()
			assignments():SetAsync(tostring(entry.UserId), payload, 90)
		end)
	end
end

local function collectAssignments()
	for player, modeId in playerMode do
		local ok, payload = pcall(function()
			return assignments():GetAsync(tostring(player.UserId))
		end)
		if ok and type(payload) == "table" and payload.AccessCode then
			pcall(function()
				assignments():RemoveAsync(tostring(player.UserId))
			end)
			MatchmakingService.Leave(player, true)
			Registry.ProgressionService.Toast(player, { Kind = "Match", Text = "Partida encontrada! Teleportando…" })
			task.spawn(Registry.TeleportServiceWrapper.ToReserved, Config.Places.Match, { player }, payload.AccessCode, {
				Mode = payload.Mode or modeId,
				MapId = payload.MapId,
				Expected = payload.Expected,
			})
		end
	end
end

function MatchmakingService.Join(player: Player, modeId: string)
	if not Config.Modes[modeId] or Registry.RoundService.GetMatch(player) then
		return
	end
	if playerMode[player] == modeId then
		return
	end
	MatchmakingService.Leave(player, true)
	playerMode[player] = modeId
	table.insert(queues[modeId], player)
	if crossServer() then
		task.spawn(enqueueRemote, player, modeId)
	end
	sendState(modeId)
end

function MatchmakingService.Leave(player: Player, silent: boolean?)
	local modeId = playerMode[player]
	if not modeId then
		return
	end
	playerMode[player] = nil
	local queue = queues[modeId]
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
	end
	if crossServer() then
		task.spawn(cancelRemote, player)
	end
	if not silent then
		Remotes.Event("QueueState"):FireClient(player, nil)
	end
	sendState(modeId)
end

local function localLoop()
	while true do
		task.wait(0.5)
		if crossServer() then
			continue
		end
		for _, modeId in Config.ModeOrder do
			local queue = queues[modeId]
			local need = needed(modeId)
			if #queue >= need and Registry.RoundService.CanStart() then
				local group = {}
				for i = 1, need do
					table.insert(group, queue[i])
				end
				for _, player in group do
					Registry.ProgressionService.Toast(player, { Kind = "Match", Text = "Partida encontrada!" })
					Remotes.Event("QueueState"):FireClient(player, nil)
				end
				task.wait(Config.Matchmaking.LocalStartDelay)

				local stillQueued = {}
				for _, player in group do
					if player.Parent == Players and playerMode[player] == modeId then
						table.insert(stillQueued, player)
					end
				end
				if #stillQueued >= need then
					Registry.RoundService.StartMatch(modeId, stillQueued, nil)
				else
					sendState(modeId)
				end
			end
		end
	end
end

local function remoteLoop()
	while true do
		task.wait(Config.Matchmaking.PollInterval)
		if not crossServer() then
			continue
		end
		for _, modeId in Config.ModeOrder do
			if #queues[modeId] > 0 then
				pcall(matchRemote, modeId)
			end
		end
		collectAssignments()
	end
end

function MatchmakingService.Init()
	Remotes.Event("Queue").OnServerEvent:Connect(function(player, modeId)
		if not limiter:Allow(player) then
			return
		end
		if modeId == "leave" then
			Registry.RoundService.Leave(player)
		elseif type(modeId) == "string" then
			MatchmakingService.Join(player, modeId)
		else
			MatchmakingService.Leave(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.Leave(player, true)
		limiter:Forget(player)
	end)
end

function MatchmakingService.Start()
	task.spawn(remoteLoop)
	localLoop()
end

return MatchmakingService
