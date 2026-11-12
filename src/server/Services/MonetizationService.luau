--[[
	MonetizationService — Developer Products e o ÚNICO ProcessReceipt do jogo.

	Padrão (doc do ProfileStore "Developer Products" + doc oficial do MarketplaceService):
	  1. jogador ausente / perfil não carregado → NotProcessedYet (o Roblox tenta de novo depois)
	  2. PurchaseId já no cache do perfil → só espera o save
	  3. concede + grava o PurchaseId em Profile.Data
	  4. espera Profile.LastSavedData conter o PurchaseId → PurchaseGranted
	Nunca concede no PromptProductPurchaseFinished.

	IDs = 0 no Config: no Studio a compra é simulada (Config.Studio.SimulateRobuxPurchases),
	fora do Studio o botão avisa que o produto ainda não foi configurado.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.Cosmetics.Catalog)
local Registry = require(script.Parent.Parent.Registry)

local MonetizationService = {}

type Grant = (player: Player, data: any) -> string -- retorna mensagem para o toast

-- ProductId → função de concessão
local function grantFor(productId: number): Grant?
	if productId == 0 then
		return nil
	end
	if productId == Config.Pass.PrimeProductId then
		return function(_, data)
			data.Pass.Prime = true
			return `{Config.Pass.PrimeName} ativado!`
		end
	end
	if productId == Config.StarterPack.ProductId then
		return function(_, data)
			for _, itemId in Config.StarterPack.Items do
				Registry.InventoryService.Grant(data, itemId)
			end
			data.Coins += Config.StarterPack.BonusCoins
			data.StarterPackOwned = true
			return `{Config.StarterPack.Name} recebido!`
		end
	end
	local itemId = Catalog.ItemForProduct(productId)
	if itemId then
		return function(_, data)
			Registry.InventoryService.Grant(data, itemId)
			return `{(Catalog.Get(itemId) :: any).Name} desbloqueado!`
		end
	end
	return nil
end

local function cachePurchase(data, purchaseId: string)
	local cache = data.PurchaseIdCache
	while #cache >= Config.Data.PurchaseIdCacheSize do
		table.remove(cache, 1)
	end
	table.insert(cache, purchaseId)
end

local function waitForSave(profile, purchaseId: string): Enum.ProductPurchaseDecision
	local function saved(): boolean
		local cache = profile.LastSavedData and profile.LastSavedData.PurchaseIdCache
		return cache ~= nil and table.find(cache, purchaseId) ~= nil
	end
	if saved() then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	while profile:IsActive() do
		local before = profile.LastSavedData
		profile:Save()
		if profile.LastSavedData == before then
			profile.OnAfterSave:Wait()
		end
		if saved() then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if profile:IsActive() then
			task.wait(10)
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = Registry.DataService.Wait(player, 20)
	if not profile or not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local grant = grantFor(receipt.ProductId)
	if not grant then
		warn(`[Monetization] ProductId sem função: {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receipt.PurchaseId)
	if not table.find(profile.Data.PurchaseIdCache, purchaseId) then
		local ok, message = pcall(grant, player, profile.Data)
		if not ok then
			warn("[Monetization] falha ao conceder:", message)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		cachePurchase(profile.Data, purchaseId)
		Registry.DataService.MarkDirty(player)
		Registry.ProgressionService.Toast(player, { Kind = "Purchase", Text = message })
	end
	return waitForSave(profile, purchaseId)
end

-- Studio + ID 0: simula o recibo pelo MESMO caminho de concessão (testa o fluxo inteiro).
local function simulate(player: Player, grant: Grant): { Ok: boolean, Message: string? }
	local profile = Registry.DataService.Get(player)
	if not profile then
		return { Ok = false, Message = "Perfil carregando…" }
	end
	local message = grant(player, profile.Data)
	cachePurchase(profile.Data, "studio-" .. HttpService:GenerateGUID(false))
	Registry.DataService.MarkDirty(player)
	return { Ok = true, Message = `[Studio] {message}` }
end

local function prompt(player: Player, productId: number, simulatedGrant: Grant): { Ok: boolean, Message: string? }
	if productId == 0 then
		if RunService:IsStudio() and Config.Studio.SimulateRobuxPurchases then
			return simulate(player, simulatedGrant)
		end
		return { Ok = false, Message = "Produto ainda não configurado." }
	end
	MarketplaceService:PromptProductPurchase(player, productId)
	return { Ok = true, Message = nil }
end

function MonetizationService.PromptItem(player: Player, itemId: string)
	local item = Catalog.Get(itemId)
	local data = Registry.DataService.GetData(player)
	if not item or not data then
		return { Ok = false, Message = "Item inexistente." }
	end
	if Registry.InventoryService.Owns(data, itemId) then
		return { Ok = false, Message = "Você já tem este item." }
	end
	return prompt(player, item.ProductId, function(_, d)
		Registry.InventoryService.Grant(d, itemId)
		return `{item.Name} desbloqueado!`
	end)
end

function MonetizationService.PromptPrime(player: Player)
	local data = Registry.DataService.GetData(player)
	if data and data.Pass.Prime then
		return { Ok = false, Message = "Você já tem o Prime desta temporada." }
	end
	return prompt(player, Config.Pass.PrimeProductId, function(_, d)
		d.Pass.Prime = true
		return `{Config.Pass.PrimeName} ativado!`
	end)
end

function MonetizationService.PromptStarter(player: Player)
	local data = Registry.DataService.GetData(player)
	if data and data.StarterPackOwned then
		return { Ok = false, Message = "Pacote já resgatado." }
	end
	return prompt(player, Config.StarterPack.ProductId, function(_, d)
		for _, itemId in Config.StarterPack.Items do
			Registry.InventoryService.Grant(d, itemId)
		end
		d.StarterPackOwned = true
		return `{Config.StarterPack.Name} recebido!`
	end)
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
