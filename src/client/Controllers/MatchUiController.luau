--[[
	MatchUiController — tudo que é da partida: placar no topo, cronômetro, banners de round,
	scoreboard (Tab), tela de resultado (moedas, XP, ELO) e a votação de mapa (20 s).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Audio = require(Shared.Audio)
local Format = require(Shared.Util.Format)
local Ranks = require(Shared.Progression.Ranks)
local Theme = require(script.Parent.Parent.UI.Theme)
local ClientState = require(script.Parent.Parent.ClientState)
local InputController = require(script.Parent.InputController)

local MatchUiController = {}

local player = Players.LocalPlayer
local New = Theme.New
local C = Theme.Colors

local gui: ScreenGui
local refs = {} :: { [string]: any }
local lastState = ""
local lastRound = 0
local lastCountdown = -1

local function myTeam(match): string
	for _, row in match.Roster do
		if row.UserId == player.UserId then
			return row.Team
		end
	end
	return "FFA"
end

-- resultados chegam com chave UserId (número ou string, conforme a serialização do remote)
local function myResult(match)
	local results = match and match.Results
	if not results then
		return nil
	end
	return results[player.UserId] or results[tostring(player.UserId)]
end

local function teamColor(team: string?): Color3
	return if team == "A" then C.TeamA elseif team == "B" then C.TeamB else C.Text
end

-- ── construção ─────────────────────────────────────────────────────────────
local function buildTopBar()
	local bar = New("Frame", {
		Name = "ScoreBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(380, 64),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local function side(name: string, anchorX: number, color: Color3)
		local box = Theme.Panel({
			Name = name,
			AnchorPoint = Vector2.new(anchorX, 0),
			Position = UDim2.fromScale(anchorX, 0),
			Size = UDim2.fromOffset(110, 52),
			Parent = bar,
		})
		New("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = color, BorderSizePixel = 0, Parent = box })
		local score = Theme.Label({ Name = "Score", Text = "0", FontFace = Theme.Fonts.Display, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 1, -14), Position = UDim2.fromOffset(0, 4), Parent = box })
		local label = Theme.Label({ Name = "Label", Text = "", FontFace = Theme.Fonts.Title, TextSize = 11, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 14), Parent = box })
		return score, label
	end
	refs.ScoreLeft, refs.LabelLeft = side("Left", 0, C.TeamA)
	refs.ScoreRight, refs.LabelRight = side("Right", 1, C.TeamB)
	local center = Theme.Panel({ Name = "Center", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(140, 52), Parent = bar })
	refs.Timer = Theme.Label({ Text = "0:00", FontFace = Theme.Fonts.Display, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4), Parent = center })
	refs.Sub = Theme.Label({ Text = "", FontFace = Theme.Fonts.Title, TextSize = 11, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 34), Parent = center })
	refs.ScoreBar = bar
end

local function buildBanner()
	local banner = New("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(700, 120),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	refs.BannerTitle = Theme.Label({ Text = "", FontFace = Theme.Fonts.Display, TextSize = 56, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 64), TextStrokeTransparency = 0.7, Parent = banner })
	refs.BannerSub = Theme.Label({ Text = "", FontFace = Theme.Fonts.Title, TextSize = 18, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 24), TextStrokeTransparency = 0.8, Parent = banner })
	refs.BannerScale = New("UIScale", { Parent = banner })
	refs.Banner = banner
end

local function buildScoreboard()
	local board = Theme.Panel({
		Name = "Scoreboard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(620, 420),
		Visible = false,
		Parent = gui,
	})
	refs.BoardTitle = Theme.Label({ Text = "", FontFace = Theme.Fonts.Display, TextSize = 22, Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 28), Parent = board })
	refs.BoardSub = Theme.Label({ Text = "", FontFace = Theme.Fonts.Body, TextSize = 14, TextColor3 = C.TextDim, Position = UDim2.fromOffset(20, 42), Size = UDim2.new(1, -40, 0, 18), Parent = board })
	local header = New("Frame", { Position = UDim2.fromOffset(20, 72), Size = UDim2.new(1, -40, 0, 18), BackgroundTransparency = 1, Parent = board })
	for i, spec in { { "JOGADOR", 0, 0.6 }, { "K", 0.6, 0.13 }, { "D", 0.73, 0.13 }, { "", 0.86, 0.14 } } do
		Theme.Label({ Text = spec[1], FontFace = Theme.Fonts.Title, TextSize = 11, TextColor3 = C.TextDim, Position = UDim2.fromScale(spec[2], 0), Size = UDim2.fromScale(spec[3], 1), TextXAlignment = if i == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center, Parent = header })
	end
	refs.BoardList = New("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 94),
		Size = UDim2.new(1, -40, 1, -110),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = board,
		Theme.List(nil, 4),
	})
	refs.Board = board
end

local function buildResults()
	local panel = Theme.Panel({
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 220),
		Size = UDim2.fromOffset(620, 70),
		Visible = false,
		Parent = gui,
	})
	refs.ResultsText = Theme.Label({ Text = "", FontFace = Theme.Fonts.Title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), RichText = true, Parent = panel })
	refs.Results = panel
end

local function buildVote()
	local panel = Theme.Panel({
		Name = "Vote",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(760, 300),
		Visible = false,
		Parent = gui,
	})
	Theme.Label({ Text = "PRÓXIMO MAPA", FontFace = Theme.Fonts.Display, TextSize = 24, Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(400, 30), Parent = panel })
	refs.VoteTimer = Theme.Label({ Text = "", FontFace = Theme.Fonts.Mono, TextSize = 18, TextColor3 = C.Brand, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 22), Size = UDim2.fromOffset(120, 24), Parent = panel })
	refs.VoteRow = New("Frame", {
		Position = UDim2.fromOffset(24, 64),
		Size = UDim2.new(1, -48, 0, 170),
		BackgroundTransparency = 1,
		Parent = panel,
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	local leave = Theme.Button("VOLTAR AO LOBBY", "Ghost", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(200, 36), TextSize = 14, Parent = panel })
	leave.Activated:Connect(function()
		Remotes.Event("Queue"):FireServer("leave")
	end)
	refs.Vote = panel
	refs.VoteCards = {}
end

-- ── render ─────────────────────────────────────────────────────────────────
local MAP_TINTS = {
	Cais09 = { Color3.fromRGB(214, 150, 140), Color3.fromRGB(60, 70, 100) },
	Avenida11 = { Color3.fromRGB(110, 60, 200), Color3.fromRGB(20, 20, 50) },
	Posto47 = { Color3.fromRGB(240, 180, 100), Color3.fromRGB(90, 70, 60) },
	Random = { Color3.fromRGB(90, 90, 96), Color3.fromRGB(30, 30, 34) },
}

local function renderVote(vote)
	refs.Vote.Visible = vote ~= nil
	if not vote then
		return
	end
	for _, card in refs.VoteCards do
		card:Destroy()
	end
	refs.VoteCards = {}
	for index, option in vote.Options do
		local def = Config.Maps.List[option]
		local tint = MAP_TINTS[option] or MAP_TINTS.Random
		local chosen = vote.Mine == option
		local card = New("TextButton", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(220, 170),
			AutoButtonColor = false,
			BackgroundColor3 = tint[2],
			BorderSizePixel = 0,
			Text = "",
			Parent = refs.VoteRow,
			Theme.Corner(10),
			New("UIGradient", { Rotation = 90, Color = ColorSequence.new(tint[1], tint[2]) }),
			New("UIStroke", { Color = if chosen then C.Brand else C.Line, Thickness = if chosen then 3 else 1 }),
		})
		Theme.Label({ Text = if def then string.upper(def.DisplayName) else "ALEATÓRIO", FontFace = Theme.Fonts.Display, TextSize = 24, Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 0, 28), TextStrokeTransparency = 0.6, Parent = card })
		Theme.Label({ Text = if def then def.Subtitle else "Qualquer um dos três", FontFace = Theme.Fonts.Body, TextSize = 13, TextColor3 = Color3.fromRGB(230, 230, 230), Position = UDim2.fromOffset(14, 124), Size = UDim2.new(1, -28, 0, 18), Parent = card })
		local count = vote.Counts and vote.Counts[option] or 0
		Theme.Label({ Text = Format.Plural(count, "voto", "votos"), FontFace = Theme.Fonts.Title, TextSize = 13, TextColor3 = C.Brand, Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(120, 16), Parent = card })
		card.Activated:Connect(function()
			Audio.Play2D("UiClick")
			Remotes.Event("Vote"):FireServer(option)
		end)
		table.insert(refs.VoteCards, card)
	end
end

local function renderBoard(match)
	for _, child in refs.BoardList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	refs.BoardTitle.Text = string.upper(`{match.ModeName} · {match.MapName}`)
	refs.BoardSub.Text = if match.TeamSize > 0 then `Placar {match.Score.A} × {match.Score.B} · primeiro a {match.ScoreToWin}` else `Primeiro a {match.ScoreToWin} kills`
	for index, row in match.Roster do
		local line = New("Frame", {
			LayoutOrder = (if row.Team == "B" then 100 else 0) + index,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = if row.UserId == player.UserId then Color3.fromRGB(56, 44, 16) else C.PanelHi,
			BackgroundTransparency = 0.2,
			Parent = refs.BoardList,
			Theme.Corner(6),
		})
		New("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = teamColor(row.Team), BorderSizePixel = 0, Parent = line })
		Theme.Label({ Text = row.Name .. (if row.Alive then "" else "  ×"), FontFace = Theme.Fonts.Title, TextSize = 15, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromScale(0.58, 1), Parent = line })
		Theme.Label({ Text = tostring(row.Kills), FontFace = Theme.Fonts.Mono, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0.6, 0), Size = UDim2.fromScale(0.13, 1), Parent = line })
		Theme.Label({ Text = tostring(row.Deaths), FontFace = Theme.Fonts.Mono, TextSize = 15, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0.73, 0), Size = UDim2.fromScale(0.13, 1), Parent = line })
	end
end

local function showBanner(title: string, subtitle: string, color: Color3?)
	refs.BannerTitle.Text = title
	refs.BannerTitle.TextColor3 = color or C.Text
	refs.BannerSub.Text = subtitle
	refs.Banner.Visible = true
	refs.BannerScale.Scale = 1.25
	Theme.Tween(refs.BannerScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function render(match)
	refs.ScoreBar.Visible = match ~= nil
	if not match then
		refs.Banner.Visible = false
		refs.Board.Visible = false
		refs.Results.Visible = false
		lastState = ""
		return
	end
	local team = myTeam(match)
	if match.TeamSize > 0 then
		local mine = if team == "B" then "B" else "A"
		local other = if mine == "A" then "B" else "A"
		refs.ScoreLeft.Text = tostring(match.Score[mine])
		refs.ScoreRight.Text = tostring(match.Score[other])
		refs.LabelLeft.Text = "VOCÊ" .. (if match.TeamSize > 1 then "S" else "")
		refs.LabelRight.Text = "RIVAL"
	else
		local myKills, best = 0, 0
		for _, row in match.Roster do
			if row.UserId == player.UserId then
				myKills = row.Kills
			elseif row.Kills > best then
				best = row.Kills
			end
		end
		refs.ScoreLeft.Text = tostring(myKills)
		refs.ScoreRight.Text = tostring(best)
		refs.LabelLeft.Text = "VOCÊ"
		refs.LabelRight.Text = "LÍDER"
	end
	refs.Sub.Text = if match.RoundBased then `ROUND {math.max(match.Round, 1)} · ATÉ {match.ScoreToWin}` else `ATÉ {match.ScoreToWin}`

	local stateChanged = match.State ~= lastState or match.Round ~= lastRound
	lastState = match.State
	lastRound = match.Round
	if stateChanged then
		if match.State == "Warmup" then
			showBanner(string.upper(match.MapName), `{match.ModeName} · {match.MapSubtitle}`)
		elseif match.State == "Freeze" then
			showBanner(if match.RoundBased then `ROUND {match.Round}` else "PREPARE-SE", if match.Ranked then "RANKED" else "")
			Audio.Play2D("RoundStart")
		elseif match.State == "Live" then
			task.delay(0.6, function()
				if lastState == "Live" then
					refs.Banner.Visible = false
				end
			end)
			showBanner("VALENDO", "")
		elseif match.State == "RoundEnd" then
			local winner = match.RoundWinner
			if winner == "Draw" then
				showBanner("EMPATE", "Ninguém pontua")
			elseif winner == team then
				showBanner("ROUND SEU", `{match.Score.A} × {match.Score.B}`, C.Good)
				Audio.Play2D("RoundWin")
			else
				showBanner("ROUND PERDIDO", `{match.Score.A} × {match.Score.B}`, C.Bad)
			end
		elseif match.State == "MatchEnd" then
			local mine = myResult(match)
			local won = mine ~= nil and mine.Won == true
			showBanner(if won then "VITÓRIA" else "DERROTA", match.ModeName, if won then C.Brand else C.Bad)
			if won then
				Audio.Play2D("RoundWin", { Pitch = 0.9 })
			end
		elseif match.State == "Vote" then
			refs.Banner.Visible = false
		end
	end

	-- resultado pessoal
	local result = myResult(match)
	refs.Results.Visible = (match.State == "MatchEnd" or match.State == "Vote") and result ~= nil
	if result then
		local parts = { `<font color="#FFCE54">+{result.Coins} moedas</font>`, `+{result.Xp} XP` }
		if result.EloDelta then
			local sign = if result.EloDelta >= 0 then "+" else ""
			local tier = Ranks.For(result.Elo or Config.Ranked.StartElo)
			table.insert(parts, `ELO {sign}{result.EloDelta} → {result.Elo} ({tier.Name})`)
		end
		refs.ResultsText.Text = table.concat(parts, "   ·   ")
	end
	refs.Board.Visible = InputController.IsHeld("Scoreboard") or match.State == "MatchEnd"
	if refs.Board.Visible then
		renderBoard(match)
	end
end

local function tick()
	local match = ClientState.Match
	if not match then
		return
	end
	local remaining = math.max(0, match.EndsAt - Workspace:GetServerTimeNow())
	refs.Timer.Text = Format.Time(remaining)
	refs.Timer.TextColor3 = if match.State == "Live" and remaining <= 10 then C.Bad else C.Text
	if match.State == "Freeze" or match.State == "Warmup" then
		local seconds = math.ceil(remaining)
		if seconds ~= lastCountdown and seconds <= 3 and seconds > 0 then
			lastCountdown = seconds
			Audio.Play2D("Countdown", { Pitch = 1 + (3 - seconds) * 0.1 })
			if match.State == "Freeze" then
				refs.BannerSub.Text = `começa em {seconds}`
			end
		end
	else
		lastCountdown = -1
	end
	local vote = ClientState.Vote
	if vote and refs.Vote.Visible then
		refs.VoteTimer.Text = Format.Time(math.max(0, vote.EndsAt - Workspace:GetServerTimeNow()))
	end
end

function MatchUiController.Init()
	gui = New("ScreenGui", {
		Name = "OffscopeMatch",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildTopBar()
	buildBanner()
	buildScoreboard()
	buildResults()
	buildVote()

	ClientState.MatchChanged:Connect(function(match)
		render(match)
		if not match or match.State ~= "Vote" then
			renderVote(nil)
			-- partida emendada após o voto: devolve o mouse para a mira
			if match and ClientState.UiOpen then
				ClientState.SetUiOpen(false)
			end
		end
	end)
	ClientState.VoteChanged:Connect(function(vote)
		local match = ClientState.Match
		renderVote(if match and match.State == "Vote" then vote else nil)
		ClientState.SetUiOpen(vote ~= nil and match ~= nil and match.State == "Vote")
	end)
	InputController.Pressed:Connect(function(action)
		if action == "Scoreboard" and ClientState.Match then
			render(ClientState.Match)
		end
	end)
	InputController.Released:Connect(function(action)
		if action == "Scoreboard" and ClientState.Match then
			render(ClientState.Match)
		end
	end)
end

function MatchUiController.Start()
	RunService.Heartbeat:Connect(tick)
end

return MatchUiController
