--[[
	InventoryService — comprar com moedas, equipar, resgatar passe.
	Tudo é só visual. Itens à venda por moedas: catálogo permanente + loja diária de hoje.
	Compras em Robux passam pelo MonetizationService (ProcessReceipt).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(Shared.Util.RateLimiter)
local Catalog = require(Shared.Cosmetics.Catalog)
local DailyShop = require(Shared.Cosmetics.DailyShop)
local Levels = require(Shared.Progression.Levels)
local Registry = require(script.Parent.Parent.Registry)

local InventoryService = {}

local limiter = RateLimiter.new(table.unpack(Config.Netcode.RemoteBudgets.Shop))

export type Result = { Ok: boolean, Message: string? }

local function fail(message: string): Result
	return { Ok = false, Message = message }
end

function InventoryService.Owns(data, itemId: string): boolean
	return Catalog.IsDefault(itemId) or data.Inventory[itemId] == true
end

-- Concede (idempotente). Retorna true se era novo.
function InventoryService.Grant(data, itemId: string): boolean
	if not Catalog.Get(itemId) or data.Inventory[itemId] then
		return false
	end
	data.Inventory[itemId] = true
	return true
end

function InventoryService.IsForSaleCoins(itemId: string): boolean
	local item = Catalog.Get(itemId)
	if not item or not item.PriceCoins then
		return false
	end
	if item.Pool == "catalog" then
		return true
	end
	if item.Pool == "daily" then
		return DailyShop.Contains(itemId)
	end
	-- itens de passe também podem ser comprados por moedas quando têm preço (ex.: lendária 25.000)
	return item.Pool == "pass" and item.Rarity == "Legendary"
end

function InventoryService.IsForSaleRobux(itemId: string): boolean
	local item = Catalog.Get(itemId)
	if not item or not item.PriceRobux then
		return false
	end
	return item.Pool == "catalog" or item.Pool == "daily" and DailyShop.Contains(itemId) or item.Pool == "pass"
end

local function buyWithCoins(player: Player, itemId: string): Result
	local item = Catalog.Get(itemId)
	if not item then
		return fail("Item inexistente.")
	end
	if not InventoryService.IsForSaleCoins(itemId) then
		return fail("Este item não está à venda hoje.")
	end
	local data = Registry.DataService.GetData(player)
	if not data then
		return fail("Perfil carregando…")
	end
	if InventoryService.Owns(data, itemId) then
		return fail("Você já tem este item.")
	end
	local price = item.PriceCoins :: number
	if data.Coins < price then
		return fail("Moedas insuficientes.")
	end
	Registry.DataService.Update(player, function(d)
		d.Coins -= price
		InventoryService.Grant(d, itemId)
	end)
	return { Ok = true, Message = `{item.Name} desbloqueado!` }
end

local function equip(player: Player, itemId: string): Result
	local item = Catalog.Get(itemId)
	local data = Registry.DataService.GetData(player)
	if not item or not data then
		return fail("Item inexistente.")
	end
	if not InventoryService.Owns(data, itemId) then
		return fail("Você ainda não tem este item.")
	end
	Registry.DataService.Update(player, function(d)
		d.Equipped[item.Category] = itemId
	end)
	Registry.CharacterService.RefreshCosmetics(player)
	return { Ok = true }
end

local function claimPass(player: Player, tier: any, track: any): Result
	if type(tier) ~= "number" or (track ~= "Free" and track ~= "Prime") then
		return fail("Pedido inválido.")
	end
	tier = math.floor(tier)
	local data = Registry.DataService.GetData(player)
	if not data then
		return fail("Perfil carregando…")
	end
	if tier < 1 or tier > Config.Pass.Tiers or tier > Levels.PassTier(data.Pass.Xp) then
		return fail("Tier ainda bloqueado.")
	end
	if track == "Prime" and not data.Pass.Prime then
		return fail("Requer o Passe Prime.")
	end
	local claimed = if track == "Free" then data.Pass.ClaimedFree else data.Pass.ClaimedPrime
	local key = tostring(tier)
	if claimed[key] then
		return fail("Já resgatado.")
	end
	local rewards = if track == "Free" then Config.Pass.Free else Config.Pass.Prime
	local itemId = rewards[tier]
	local message
	Registry.DataService.Update(player, function(d)
		local c = if track == "Free" then d.Pass.ClaimedFree else d.Pass.ClaimedPrime
		c[key] = true
		if itemId then
			if not InventoryService.Grant(d, itemId) then
				-- já tinha o item: converte em moedas
				local coins = (Catalog.Get(itemId) :: any).PriceCoins or 1000
				d.Coins += math.floor(coins / 2)
			end
			message = `{(Catalog.Get(itemId) :: any).Name} resgatado!`
		else
			local coins = if track == "Free" then Config.Pass.FreeCoinsPerTier else Config.Pass.PrimeCoinsPerTier
			d.Coins += coins
			message = `+{coins} moedas`
		end
	end)
	return { Ok = true, Message = message }
end

local function handle(player: Player, action: any, payload: any): Result
	if not limiter:Allow(player) then
		return fail("Calma! Muitas ações seguidas.")
	end
	if type(action) ~= "string" then
		return fail("Pedido inválido.")
	end
	payload = if type(payload) == "table" then payload else {}
	if action == "BuyCoins" and type(payload.ItemId) == "string" then
		return buyWithCoins(player, payload.ItemId)
	elseif action == "Equip" and type(payload.ItemId) == "string" then
		return equip(player, payload.ItemId)
	elseif action == "ClaimPass" then
		return claimPass(player, payload.Tier, payload.Track)
	elseif action == "BuyRobux" and type(payload.ItemId) == "string" then
		if not InventoryService.IsForSaleRobux(payload.ItemId) then
			return fail("Este item não está à venda por Robux agora.")
		end
		return Registry.MonetizationService.PromptItem(player, payload.ItemId)
	elseif action == "BuyPrime" then
		return Registry.MonetizationService.PromptPrime(player)
	elseif action == "BuyStarter" then
		return Registry.MonetizationService.PromptStarter(player)
	end
	return fail("Ação desconhecida.")
end

function InventoryService.Init()
	Remotes.Function("Shop").OnServerInvoke = function(player, action, payload)
		local ok, result = pcall(handle, player, action, payload)
		if not ok then
			warn("[Shop]", result)
			return fail("Erro na loja. Tente de novo.")
		end
		return result
	end
	Remotes.Function("GetShop").OnServerInvoke = function()
		return {
			Day = DailyShop.Day(),
			Daily = DailyShop.Items(),
			ResetIn = DailyShop.SecondsUntilReset(),
		}
	end
	Players.PlayerRemoving:Connect(function(player)
		limiter:Forget(player)
	end)
end

return InventoryService
