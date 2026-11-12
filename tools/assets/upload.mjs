// Sobe os sons (assets/audio/*.wav) e texturas (assets/textures/*.png) pelo Open Cloud
// e gera src/shared/AssetIds.luau. Roda do SEU computador, com a SUA chave — nada é publicado sozinho.
//
// Configuração (.env na raiz ou variáveis de ambiente):
//   ROBLOX_API_KEY=...            chave do Creator Hub com permissão "assets: write"
//   ROBLOX_CREATOR_ID=123456      seu userId (ou groupId)
//   ROBLOX_CREATOR_TYPE=user      user | group
//
// Uso: node tools/assets/upload.mjs [--only=audio|textures] [--dry-run]
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, extname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const OUTPUT = join(ROOT, "src", "shared", "AssetIds.luau");
const CACHE = join(ROOT, "assets", "uploaded.json");
const API = "https://apis.roblox.com/assets/v1";

const args = new Set(process.argv.slice(2));
const only = [...args].find((a) => a.startsWith("--only="))?.split("=")[1];
const dryRun = args.has("--dry-run");

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
const creatorId = process.env.ROBLOX_CREATOR_ID;
const creatorType = (process.env.ROBLOX_CREATOR_TYPE || "user").toLowerCase();

if (!dryRun && (!apiKey || !creatorId)) {
	console.error("Defina ROBLOX_API_KEY e ROBLOX_CREATOR_ID (veja o cabeçalho deste arquivo).");
	process.exit(1);
}

const cache = existsSync(CACHE) ? JSON.parse(readFileSync(CACHE, "utf8")) : { Audio: {}, Textures: {} };
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function upload(file, assetType, contentType) {
	const name = basename(file, extname(file));
	const request = {
		assetType,
		displayName: `OFFSCOPE ${name}`,
		description: "Asset original do OFFSCOPE (gerado proceduralmente).",
		creationContext: { creator: creatorType === "group" ? { groupId: String(creatorId) } : { userId: String(creatorId) } },
	};
	const form = new FormData();
	form.append("request", JSON.stringify(request));
	form.append("fileContent", new Blob([readFileSync(file)], { type: contentType }), basename(file));
	const response = await fetch(`${API}/assets`, { method: "POST", headers: { "x-api-key": apiKey }, body: form });
	if (!response.ok) throw new Error(`${response.status} ${await response.text()}`);
	let operation = await response.json();
	const operationId = operation.path?.split("/").pop() ?? operation.operationId;
	for (let attempt = 0; attempt < 30 && !operation.done; attempt++) {
		await sleep(1500);
		const poll = await fetch(`${API}/operations/${operationId}`, { headers: { "x-api-key": apiKey } });
		operation = await poll.json();
	}
	const assetId = operation.response?.assetId;
	if (!assetId) throw new Error(`operação sem assetId: ${JSON.stringify(operation)}`);
	return `rbxassetid://${assetId}`;
}

async function batch(kind, folder, extension, assetTypes, contentType) {
	const dir = join(ROOT, "assets", folder);
	const files = readdirSync(dir).filter((f) => f.endsWith(extension));
	for (const fileName of files) {
		const key = basename(fileName, extension);
		if (cache[kind][key]) {
			console.log(`  = ${key} (já enviado: ${cache[kind][key]})`);
			continue;
		}
		if (dryRun) {
			console.log(`  · ${key} (dry-run)`);
			continue;
		}
		let lastError;
		for (const type of assetTypes) {
			try {
				cache[kind][key] = await upload(join(dir, fileName), type, contentType);
				console.log(`  ✓ ${key} → ${cache[kind][key]} (${type})`);
				lastError = undefined;
				break;
			} catch (error) {
				lastError = error;
			}
		}
		if (lastError) console.warn(`  ✗ ${key}: ${lastError.message}`);
		writeFileSync(CACHE, JSON.stringify(cache, null, 2));
	}
}

function writeLuau() {
	const entries = (table) =>
		Object.entries(table)
			.sort(([a], [b]) => a.localeCompare(b))
			.map(([k, v]) => `\t\t${k} = "${v}",`)
			.join("\n");
	writeFileSync(
		OUTPUT,
		`--[[
	GERADO por \`node tools/assets/upload.mjs\` — não edite à mão.
	Enquanto vazio, o jogo usa os fallbacks de Config.Audio e cores sólidas nos wraps.
]]

return {
	Audio = {
${entries(cache.Audio)}
	} :: { [string]: string },
	Textures = {
${entries(cache.Textures)}
	} :: { [string]: string },
}
`,
	);
	console.log(`AssetIds → ${OUTPUT}`);
}

if (!only || only === "audio") {
	console.log("Áudio:");
	await batch("Audio", "audio", ".wav", ["Audio"], "audio/wav");
}
if (!only || only === "textures") {
	console.log("Texturas:");
	// "Image" devolve o id de imagem que o Texture usa; "Decal" fica de reserva.
	await batch("Textures", "textures", ".png", ["Image", "Decal"], "image/png");
}
writeLuau();
