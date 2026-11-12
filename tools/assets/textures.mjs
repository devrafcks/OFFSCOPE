// Gera as texturas tileáveis dos wraps (camos, carbono, colmeia) em assets/textures.
// Uso: node tools/assets/textures.mjs
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { encodePng } from "./png.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const OUT = join(ROOT, "assets", "textures");
const SIZE = 512;

// ── ruído de valor tileável ─────────────────────────────────────────────────
function makeNoise(seed) {
	const perm = new Uint16Array(512);
	let s = seed >>> 0;
	const rand = () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
	const base = [...Array(256).keys()].sort(() => rand() - 0.5);
	for (let i = 0; i < 512; i++) perm[i] = base[i & 255];
	const values = Float32Array.from({ length: 256 }, rand);
	const lattice = (x, y, period) => values[perm[(perm[((x % period) + period) % period] + (((y % period) + period) % period)) & 511]];
	const smooth = (t) => t * t * (3 - 2 * t);
	return (x, y, period) => {
		const x0 = Math.floor(x), y0 = Math.floor(y);
		const tx = smooth(x - x0), ty = smooth(y - y0);
		const a = lattice(x0, y0, period), b = lattice(x0 + 1, y0, period);
		const c = lattice(x0, y0 + 1, period), d = lattice(x0 + 1, y0 + 1, period);
		return a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty;
	};
}

function fbm(noise, u, v, basePeriod, octaves) {
	let sum = 0, amp = 0.5, norm = 0, period = basePeriod;
	for (let o = 0; o < octaves; o++) {
		sum += noise(u * period, v * period, period) * amp;
		norm += amp;
		amp *= 0.5;
		period *= 2;
	}
	return sum / norm;
}

const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];

function render(name, shader) {
	const data = new Uint8Array(SIZE * SIZE * 4);
	for (let y = 0; y < SIZE; y++) {
		for (let x = 0; x < SIZE; x++) {
			const [r, g, b] = shader(x / SIZE, y / SIZE, x, y);
			const i = (y * SIZE + x) * 4;
			data[i] = r;
			data[i + 1] = g;
			data[i + 2] = b;
			data[i + 3] = 255;
		}
	}
	writeFileSync(join(OUT, `${name}.png`), encodePng(SIZE, SIZE, data));
	console.log(`  ✓ ${name}.png`);
}

// camo de manchas: 4 camadas de ruído com limiares diferentes
function blotchCamo(name, seed, palette, period, pixel = 1) {
	const layers = palette.slice(1).map((_, i) => makeNoise(seed + i * 101));
	const colors = palette.map(hex);
	render(name, (u, v) => {
		const qu = pixel > 1 ? Math.floor(u * SIZE / pixel) * pixel / SIZE : u;
		const qv = pixel > 1 ? Math.floor(v * SIZE / pixel) * pixel / SIZE : v;
		let color = colors[0];
		layers.forEach((noise, i) => {
			if (fbm(noise, qu, qv, period, 4) > 0.53 + i * 0.015) color = colors[i + 1];
		});
		// grão de tecido
		const grain = ((Math.sin(u * SIZE * 2.1) + Math.sin(v * SIZE * 1.7)) * 2) | 0;
		return color.map((c) => Math.max(0, Math.min(255, c + grain)));
	});
}

mkdirSync(OUT, { recursive: true });
console.log("Texturas →", OUT);

blotchCamo("camo_floresta", 11, ["#55603b", "#3c4a2c", "#6e5a3a", "#1f241a"], 4);
blotchCamo("camo_urbano", 23, ["#8c9096", "#5f6369", "#b8bcc0", "#2c2e32"], 5);
blotchCamo("camo_deserto", 37, ["#c6a878", "#a88660", "#dcc49a", "#7c6446"], 6, 16);
blotchCamo("camo_tundra", 41, ["#d8dde1", "#aeb6bd", "#f4f6f7", "#7d868e"], 4);

// fibra de carbono: trama sarja 2×2 com brilho anisotrópico
render("wrap_carbono", (u, v, x, y) => {
	const cell = 16;
	const cx = Math.floor(x / cell), cy = Math.floor(y / cell);
	const warp = (cx + cy) % 4 < 2;
	const local = warp ? (x % cell) / cell : (y % cell) / cell;
	const sheen = Math.pow(Math.sin(local * Math.PI), 2);
	const base = warp ? 26 : 38;
	const value = base + sheen * 34;
	return [value, value, value + 4];
});

// colmeia: grade hexagonal com bordas brilhantes
render("wrap_hex", (u, v) => {
	const scale = 8; // 8 hexágonos por tile (tileável)
	const px = u * scale, py = v * scale * (2 / Math.sqrt(3));
	const row = Math.floor(py);
	const offset = row % 2 ? 0.5 : 0;
	const fx = px + offset - Math.floor(px + offset) - 0.5;
	const fy = py - row - 0.5;
	const edge = Math.max(Math.abs(fx) * 1.0, Math.abs(fy) * 0.86 + Math.abs(fx) * 0.5);
	const line = edge > 0.475 ? 1 : 0;
	const inner = 1 - edge;
	return line ? [255, 196, 40] : [Math.round(30 + inner * 14), Math.round(44 + inner * 18), Math.round(54 + inner * 22)];
});
