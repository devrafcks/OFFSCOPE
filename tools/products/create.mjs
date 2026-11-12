// Cria os Developer Products do OFFSCOPE pela Open Cloud e grava os IDs no Config.luau.
// Roda do SEU computador, com a SUA chave — nada é criado sem você rodar este script.
//
// Pré-requisitos:
//   1. Experiência publicada (você precisa do Universe ID: Creator Hub → experiência → ⋯ → Copy Universe ID)
//   2. Chave Open Cloud com o escopo "developer-product:write" para essa experiência
//
// Configuração (.env na raiz ou variáveis de ambiente):
//   ROBLOX_API_KEY=...
//   ROBLOX_UNIVERSE_ID=1234567890
//
// Uso:
//   node tools/products/create.mjs --dry-run   # só lista o que seria criado
//   node tools/products/create.mjs             # cria o que falta e escreve os IDs no Config
//
// Idempotente: o que já tem ID (no Config ou em tools/products/created.json) é pulado.
// API (beta): POST https://apis.roblox.com/developer-products/v2/universes/{universeId}/developer-products
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const CONFIG = join(ROOT, "src", "shared", "Config.luau");
const CACHE = join(ROOT, "tools", "products", "created.json");
const dryRun = process.argv.includes("--dry-run");

function loadEnv() {
	const file = join(ROOT, ".env");
	if (!existsSync(file)) return;
	for (const line of readFileSync(file, "utf8").split(/\r?\n/)) {
		const match = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/);
		if (match && !process.env[match[1]]) process.env[match[1]] = match[2].replace(/^["']|["']$/g, "");
	}
}
loadEnv();

const apiKey = process.env.ROBLOX_API_KEY;
const universeId = process.env.ROBLOX_UNIVERSE_ID;
if (!dryRun && (!apiKey || !universeId)) {
	console.error("Defina ROBLOX_API_KEY e ROBLOX_UNIVERSE_ID (veja o cabeçalho deste arquivo).");
	process.exit(1);
}

const CATEGORY_LABEL = {
	Wrap: "Wrap",
	Charm: "Charm",
	Knife: "Faca",
	KillEffect: "Efeito de kill",
	Finisher: "Finalizador",
	Reticle: "Retículo",
	Tracer: "Traçante",
};

let config = readFileSync(CONFIG, "utf8");

// ── o que precisa virar produto ─────────────────────────────────────────────
function collect() {
	const products = [];
	// cosméticos: bloco com Name, Category, Rarity, PriceRobux, PriceCoins, ProductId
	const itemPattern =
		/\n\t(\w+) = \{\n\t\tName = "([^"]+)",\n\t\tCategory = "(\w+)",\n\t\tRarity = "(\w+)",\n\t\tPriceRobux = (\d+),\n\t\tPriceCoins = \d+,\n\t\tProductId = (\d+),/g;
	for (const m of config.matchAll(itemPattern)) {
		const [, id, name, category, rarity, price, productId] = m;
		products.push({
			key: id,
			name: `${CATEGORY_LABEL[category] ?? category}: ${name}`,
			description: `Cosmético ${rarity} do OFFSCOPE. Só visual — não muda dano, mira nem velocidade.`,
			price: Number(price),
			productId: Number(productId),
			// troca exata no Config: o "ProductId = 0," logo depois deste bloco
			anchor: m[0],
		});
	}
	const prime = config.match(/\tPrimeName = "([^"]+)",\n\tPrimePriceRobux = (\d+),\n\tPrimeProductId = (\d+),/);
	if (prime) {
		products.push({
			key: "PassPrime",
			name: prime[1],
			description: "Libera a faixa Prime do passe desta temporada. Só cosméticos.",
			price: Number(prime[2]),
			productId: Number(prime[3]),
			anchor: prime[0],
		});
	}
	const starter = config.match(/Config\.StarterPack = \{\n\tName = "([^"]+)",\n\tPriceRobux = (\d+),\n\tProductId = (\d+),/);
	if (starter) {
		products.push({
			key: "StarterPack",
			name: starter[1],
			description: "Duas camuflagens e um charm para começar. Só cosméticos, compra única.",
			price: Number(starter[2]),
			productId: Number(starter[3]),
			anchor: starter[0],
		});
	}
	return products;
}

function writeId(product, id) {
	const updated = product.anchor.replace(/(ProductId = )\d+,$/, `$1${id},`);
	if (updated === product.anchor || !config.includes(product.anchor)) {
		throw new Error(`não achei onde gravar o ID de ${product.key}`);
	}
	config = config.replace(product.anchor, updated);
	product.anchor = updated;
	writeFileSync(CONFIG, config);
}

async function create(product) {
	const form = new FormData();
	form.append("name", product.name);
	form.append("description", product.description);
	form.append("price", String(product.price));
	form.append("isForSale", "true");
	const url = `https://apis.roblox.com/developer-products/v2/universes/${universeId}/developer-products`;
	for (let attempt = 1; attempt <= 4; attempt++) {
		const response = await fetch(url, { method: "POST", headers: { "x-api-key": apiKey }, body: form });
		if (response.status === 429) {
			await new Promise((r) => setTimeout(r, 2000 * attempt));
			continue;
		}
		const text = await response.text();
		if (!response.ok) throw new Error(`${response.status} ${text}`);
		const body = JSON.parse(text);
		const id = body.productId ?? body.id;
		if (!id) throw new Error(`resposta sem productId: ${text}`);
		return Number(id);
	}
	throw new Error("rate limit persistente (429)");
}

const cache = existsSync(CACHE) ? JSON.parse(readFileSync(CACHE, "utf8")) : {};
const products = collect();
console.log(`${products.length} produtos no Config.`);
let created = 0;
let failed = 0;
for (const product of products) {
	const known = product.productId || cache[product.key];
	if (known) {
		if (!product.productId) writeId(product, known);
		console.log(`  = ${product.key} (${known})`);
		continue;
	}
	if (dryRun) {
		console.log(`  · ${product.key} → "${product.name}" R$ ${product.price}`);
		continue;
	}
	try {
		const id = await create(product);
		cache[product.key] = id;
		writeFileSync(CACHE, JSON.stringify(cache, null, 2));
		writeId(product, id);
		created++;
		console.log(`  ✓ ${product.key} → ${id}`);
	} catch (error) {
		failed++;
		console.warn(`  ✗ ${product.key}: ${error.message}`);
	}
}
console.log(dryRun ? "dry-run: nada foi criado." : `criados: ${created} · falhas: ${failed} · IDs gravados em src/shared/Config.luau`);
if (failed) process.exit(1);
