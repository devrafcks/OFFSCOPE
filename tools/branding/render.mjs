// Renderiza a identidade visual do OFFSCOPE (banner, thumbnail, ícone, cartões dos mapas).
// Tudo vetorial em SVG → PNG com resvg. Uso: cd tools/branding && npm install && npm run render
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Resvg } from "@resvg/resvg-js";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const OUT = join(ROOT, "assets", "branding");
mkdirSync(OUT, { recursive: true });

const FONT_DIR = "C:/Windows/Fonts";
const fontFiles = ["bahnschrift.ttf", "ariblk.ttf", "segoeui.ttf", "segoeuib.ttf", "arialbd.ttf"]
	.map((f) => join(FONT_DIR, f))
	.filter(existsSync);

const DISPLAY = "Bahnschrift, 'Arial Black', sans-serif";
const BODY = "'Segoe UI', Arial, sans-serif";
const AMBER = "#FFB830";

// ── peças ───────────────────────────────────────────────────────────────────
let rngState = 47;
const rnd = () => ((rngState = (rngState * 1664525 + 1013904223) >>> 0) / 4294967296);

// Retículo cortado — o "O" do logo: luneta desligada.
function reticleMark(cx, cy, r, stroke = "#FFFFFF", slash = AMBER, weight = 1) {
	const w = r * 0.13 * weight;
	return `
	<g>
		<circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="${stroke}" stroke-width="${w}"/>
		<line x1="${cx - r * 1.35}" y1="${cy}" x2="${cx - r * 0.42}" y2="${cy}" stroke="${stroke}" stroke-width="${w * 0.7}" stroke-linecap="round"/>
		<line x1="${cx + r * 0.42}" y1="${cy}" x2="${cx + r * 1.35}" y2="${cy}" stroke="${stroke}" stroke-width="${w * 0.7}" stroke-linecap="round"/>
		<line x1="${cx}" y1="${cy - r * 1.35}" x2="${cx}" y2="${cy - r * 0.42}" stroke="${stroke}" stroke-width="${w * 0.7}" stroke-linecap="round"/>
		<line x1="${cx}" y1="${cy + r * 0.42}" x2="${cx}" y2="${cy + r * 1.35}" stroke="${stroke}" stroke-width="${w * 0.7}" stroke-linecap="round"/>
		<circle cx="${cx}" cy="${cy}" r="${w * 0.55}" fill="${slash}"/>
		<line x1="${cx - r * 1.05}" y1="${cy + r * 1.05}" x2="${cx + r * 1.05}" y2="${cy - r * 1.05}" stroke="${slash}" stroke-width="${w * 1.1}" stroke-linecap="round"/>
	</g>`;
}

// Silhueta da Vanta-7 (frente para a direita), em unidades de 1000 de comprimento.
function rifle(x, y, scale, fill = "#0B0C0E", accent = AMBER, rotate = 0) {
	return `
	<g transform="translate(${x} ${y}) rotate(${rotate}) scale(${scale})">
		<path fill="${fill}" d="
			M0,40 L60,20 L230,22 L250,10 L330,10 L340,24 L560,24 L560,16 L600,16 L600,24 L940,26 L940,22 L1000,22 L1000,40
			L940,42 L600,44 L560,52 L420,52 L410,58 L380,58 L372,90 L356,128 L322,128 L330,92 L300,58 L250,58
			L210,92 L170,96 L150,64 L70,70 L0,96 Z"/>
		<rect x="300" y="-34" width="250" height="30" rx="14" fill="${fill}"/>
		<rect x="520" y="-44" width="70" height="50" rx="18" fill="${fill}"/>
		<rect x="270" y="-30" width="50" height="22" rx="10" fill="${fill}"/>
		<rect x="380" y="-10" width="18" height="20" fill="${fill}"/>
		<rect x="460" y="-10" width="18" height="20" fill="${fill}"/>
		<rect x="545" y="-38" width="6" height="38" fill="${accent}" opacity="0.9"/>
		<rect x="960" y="20" width="44" height="24" rx="3" fill="${fill}"/>
		<rect x="318" y="58" width="6" height="20" rx="2" fill="${fill}"/>
	</g>`;
}

function crane(x, base, height, fill) {
	const w = height * 0.32;
	return `
	<g fill="none" stroke="${fill}" stroke-width="${height * 0.025}">
		<line x1="${x}" y1="${base}" x2="${x}" y2="${base - height}"/>
		<line x1="${x + w}" y1="${base}" x2="${x + w}" y2="${base - height}"/>
		<line x1="${x}" y1="${base - height * 0.45}" x2="${x + w}" y2="${base - height * 0.45}"/>
		<line x1="${x}" y1="${base}" x2="${x + w}" y2="${base - height * 0.45}"/>
		<line x1="${x + w}" y1="${base}" x2="${x}" y2="${base - height * 0.45}"/>
		<line x1="${x - w * 1.6}" y1="${base - height}" x2="${x + w * 2.6}" y2="${base - height}"/>
		<line x1="${x + w * 0.5}" y1="${base - height * 1.25}" x2="${x - w * 1.6}" y2="${base - height}"/>
		<line x1="${x + w * 0.5}" y1="${base - height * 1.25}" x2="${x + w * 2.6}" y2="${base - height}"/>
	</g>
	<rect x="${x - w * 0.2}" y="${base - height * 1.07}" width="${w * 1.4}" height="${height * 0.08}" fill="${fill}"/>`;
}

function containers(x0, x1, base, fill, maxStack = 3) {
	let out = "";
	let x = x0;
	while (x < x1) {
		const width = 70 + rnd() * 40;
		const stack = 1 + Math.floor(rnd() * maxStack);
		for (let s = 0; s < stack; s++) out += `<rect x="${x}" y="${base - (s + 1) * 26}" width="${width}" height="25" fill="${fill}"/>`;
		x += width + 2 + (rnd() < 0.2 ? 30 : 0);
	}
	return out;
}

function skyline(x0, x1, base, fill, windows) {
	let out = "";
	let x = x0;
	while (x < x1) {
		const width = 50 + rnd() * 70;
		const height = 90 + rnd() * 230;
		out += `<rect x="${x}" y="${base - height}" width="${width}" height="${height}" fill="${fill}"/>`;
		for (let wy = base - height + 14; wy < base - 10; wy += 16) {
			for (let wx = x + 8; wx < x + width - 10; wx += 14) {
				if (rnd() < 0.18) out += `<rect x="${wx}" y="${wy}" width="7" height="8" fill="${windows[Math.floor(rnd() * windows.length)]}" opacity="${0.5 + rnd() * 0.5}"/>`;
			}
		}
		x += width + 4;
	}
	return out;
}

function mountains(x0, x1, base, fill, peaks, height) {
	let d = `M${x0},${base}`;
	const step = (x1 - x0) / peaks;
	for (let i = 0; i <= peaks; i++) {
		const px = x0 + i * step;
		d += ` L${px - step * 0.5},${base - height * (0.45 + rnd() * 0.25)} L${px},${base - height * (0.7 + rnd() * 0.3)}`;
	}
	return `<path d="${d} L${x1},${base} Z" fill="${fill}"/>`;
}

function pines(x0, x1, base, fill, count) {
	let out = "";
	for (let i = 0; i < count; i++) {
		const x = x0 + rnd() * (x1 - x0);
		const h = 30 + rnd() * 50;
		out += `<path d="M${x},${base - h} L${x + h * 0.22},${base} L${x - h * 0.22},${base} Z" fill="${fill}"/>`;
	}
	return out;
}

function wordmark(x, y, size, anchor = "start") {
	return `
	<text x="${x}" y="${y}" font-family="${DISPLAY}" font-weight="700" font-size="${size}" letter-spacing="${size * 0.04}"
		fill="#FFFFFF" text-anchor="${anchor}" style="font-stretch: condensed">OFFSCOPE</text>`;
}

function grain(width, height, opacity = 0.06) {
	return `
	<filter id="grain"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 ${opacity} 0"/></filter>
	<rect width="${width}" height="${height}" filter="url(#grain)"/>`;
}

function render(name, svg, width) {
	const resvg = new Resvg(svg, {
		fitTo: { mode: "width", value: width },
		font: { fontFiles, loadSystemFonts: true, defaultFontFamily: "Segoe UI" },
	});
	const png = resvg.render().asPng();
	writeFileSync(join(OUT, `${name}.png`), png);
	writeFileSync(join(OUT, `${name}.svg`), svg);
	console.log(`  ✓ ${name}.png (${(png.length / 1024).toFixed(0)} KB)`);
}

// ── banner do README (1280×640, também serve de social preview do GitHub) ─────
function banner() {
	rngState = 9;
	const W = 1280, H = 640;
	return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
	<defs>
		<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
			<stop offset="0" stop-color="#0E1220"/>
			<stop offset="0.55" stop-color="#3B2A3A"/>
			<stop offset="0.78" stop-color="#C9785A"/>
			<stop offset="0.9" stop-color="#F2B572"/>
		</linearGradient>
		<radialGradient id="sun" cx="0.72" cy="0.78" r="0.35">
			<stop offset="0" stop-color="#FFE3B0" stop-opacity="0.95"/>
			<stop offset="0.12" stop-color="#FFC27A" stop-opacity="0.6"/>
			<stop offset="1" stop-color="#FF9A50" stop-opacity="0"/>
		</radialGradient>
		<linearGradient id="fog" x1="0" y1="0" x2="0" y2="1">
			<stop offset="0" stop-color="#E8B39A" stop-opacity="0"/>
			<stop offset="1" stop-color="#E8B39A" stop-opacity="0.55"/>
		</linearGradient>
		<linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">
			<stop offset="0" stop-color="#16171C"/>
			<stop offset="1" stop-color="#07080A"/>
		</linearGradient>
		<linearGradient id="shade" x1="0" y1="0" x2="1" y2="0">
			<stop offset="0" stop-color="#07080B" stop-opacity="0.92"/>
			<stop offset="0.55" stop-color="#07080B" stop-opacity="0.35"/>
			<stop offset="1" stop-color="#07080B" stop-opacity="0"/>
		</linearGradient>
	</defs>
	<rect width="${W}" height="${H}" fill="url(#sky)"/>
	<rect width="${W}" height="${H}" fill="url(#sun)"/>
	<circle cx="${W * 0.72}" cy="${H * 0.78}" r="46" fill="#FFE6BC"/>
	${crane(820, 520, 230, "#2A1E26")}
	${crane(1040, 520, 190, "#2A1E26")}
	${containers(560, 1280, 520, "#2C2028", 3)}
	<rect y="440" width="${W}" height="120" fill="url(#fog)"/>
	${containers(700, 1280, 560, "#1B151B", 2)}
	<rect y="520" width="${W}" height="${H - 520}" fill="url(#ground)"/>
	<rect y="520" width="${W}" height="2" fill="#F2B572" opacity="0.35"/>
	<rect width="${W}" height="${H}" fill="url(#shade)"/>
	${rifle(600, 540, 0.66, "#060708", AMBER, -3)}
	${reticleMark(118, 210, 46, "#FFFFFF", AMBER, 1.1)}
	${wordmark(186, 248, 118)}
	<text x="92" y="318" font-family="${BODY}" font-size="30" fill="${AMBER}" font-weight="600">Uma bala. Sem mira. Só reflexo.</text>
	<text x="92" y="372" font-family="${BODY}" font-size="19" fill="#C9C6BE">FPS de sniper no-scope para Roblox · 3 mapas · ranked · zero pay-to-win</text>
	<g font-family="${BODY}" font-size="14" font-weight="700" fill="#0A0B0D">
		<rect x="92" y="402" width="92" height="28" rx="6" fill="${AMBER}"/><text x="138" y="421" text-anchor="middle">LUAU</text>
		<rect x="194" y="402" width="92" height="28" rx="6" fill="#FFFFFF"/><text x="240" y="421" text-anchor="middle">ROJO</text>
		<rect x="296" y="402" width="138" height="28" rx="6" fill="#FFFFFF"/><text x="365" y="421" text-anchor="middle">PROFILESTORE</text>
		<rect x="444" y="402" width="138" height="28" rx="6" fill="#FFFFFF"/><text x="513" y="421" text-anchor="middle">FEITO C/ CLAUDE</text>
	</g>
	${grain(W, H, 0.05)}
	</svg>`;
}

// ── thumbnail do Roblox (1920×1080): os 3 mapas em painéis diagonais ─────────
function thumbnail() {
	rngState = 21;
	const W = 1920, H = 1080;
	const panel = (id, x0, palette, scene) => `
		<clipPath id="clip${id}"><polygon points="${x0},0 ${x0 + 900},0 ${x0 + 660},${H} ${x0 - 240},${H}"/></clipPath>
		<g clip-path="url(#clip${id})">
			<rect x="${x0 - 260}" width="1200" height="${H}" fill="url(#${palette})"/>
			${scene}
		</g>`;
	const cais = `${crane(260, 820, 300, "#2C1F29")}${containers(-240, 700, 820, "#2D2129", 3)}<rect x="-240" y="820" width="960" height="260" fill="#12121A"/>`;
	const avenida = `${skyline(560, 1340, 860, "#0F0D1E", ["#FFB86B", "#8FB6FF", "#FF5FC8", "#5CFFC2"])}<rect x="560" y="860" width="800" height="220" fill="#09080F"/>
		<rect x="900" y="560" width="180" height="40" rx="6" fill="#FF3FB0" opacity="0.85"/><rect x="1120" y="640" width="120" height="30" rx="6" fill="#3FE0FF" opacity="0.8"/>`;
	const posto = `${mountains(1250, 2300, 860, "#6E4C3E", 4, 330)}${mountains(1250, 2300, 900, "#3D2C27", 6, 200)}${pines(1300, 2200, 900, "#1F1A16", 26)}<rect x="1250" y="900" width="1100" height="180" fill="#1A1412"/>`;
	return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
	<defs>
		<linearGradient id="dawn" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#151827"/><stop offset="0.6" stop-color="#6B4252"/><stop offset="0.85" stop-color="#F0A77A"/></linearGradient>
		<linearGradient id="night" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#06060F"/><stop offset="0.7" stop-color="#271A4D"/><stop offset="1" stop-color="#4B2A70"/></linearGradient>
		<linearGradient id="golden" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3A3550"/><stop offset="0.55" stop-color="#D98B55"/><stop offset="0.8" stop-color="#FFD08A"/></linearGradient>
		<radialGradient id="vig" cx="0.5" cy="0.5" r="0.75"><stop offset="0.5" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.75"/></radialGradient>
		<linearGradient id="bottom" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.85"/></linearGradient>
	</defs>
	<rect width="${W}" height="${H}" fill="#08090B"/>
	${panel("a", 0, "dawn", cais)}
	${panel("b", 640, "night", avenida)}
	${panel("c", 1280, "golden", posto)}
	<g stroke="#08090B" stroke-width="14"><line x1="640" y1="0" x2="400" y2="${H}"/><line x1="1280" y1="0" x2="1040" y2="${H}"/></g>
	<rect width="${W}" height="${H}" fill="url(#vig)"/>
	<rect y="560" width="${W}" height="520" fill="url(#bottom)"/>
	${rifle(380, 820, 1.15, "#050506", AMBER, -5)}
	${reticleMark(560, 300, 74, "#FFFFFF", AMBER, 1.1)}
	${wordmark(670, 362, 190)}
	<text x="${W / 2}" y="470" text-anchor="middle" font-family="${BODY}" font-size="46" font-weight="700" fill="${AMBER}">UMA BALA. SEM MIRA. SÓ REFLEXO.</text>
	<g font-family="${DISPLAY}" font-size="40" font-weight="700" fill="#FFFFFF" opacity="0.92">
		<text x="300" y="1030" text-anchor="middle">CAIS 09</text>
		<text x="960" y="1030" text-anchor="middle">AVENIDA 11</text>
		<text x="1620" y="1030" text-anchor="middle">POSTO 47</text>
	</g>
	${grain(W, H, 0.05)}
	</svg>`;
}

// ── ícone (512×512) ──────────────────────────────────────────────────────────
function icon() {
	const S = 512;
	return `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">
	<defs>
		<radialGradient id="bg" cx="0.5" cy="0.42" r="0.7"><stop offset="0" stop-color="#2A2F3A"/><stop offset="1" stop-color="#0A0B0E"/></radialGradient>
		<linearGradient id="glow" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#FF8A1F"/><stop offset="1" stop-color="#FFD15C"/></linearGradient>
	</defs>
	<rect width="${S}" height="${S}" fill="url(#bg)"/>
	<circle cx="256" cy="230" r="150" fill="none" stroke="#FFFFFF" stroke-opacity="0.06" stroke-width="40"/>
	${reticleMark(256, 230, 120, "#FFFFFF", "url(#glow)", 1.25)}
	<text x="256" y="462" text-anchor="middle" font-family="${DISPLAY}" font-weight="700" font-size="62" letter-spacing="3" fill="#FFFFFF">OFFSCOPE</text>
	</svg>`;
}

// ── cartões dos mapas (README) ───────────────────────────────────────────────
function mapCard(title, subtitle, palette, scene) {
	const W = 640, H = 360;
	return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
	<defs>
		${palette}
		<linearGradient id="fade" x1="0" y1="0" x2="0" y2="1"><stop offset="0.45" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.85"/></linearGradient>
	</defs>
	<rect width="${W}" height="${H}" fill="url(#p)"/>
	${scene}
	<rect width="${W}" height="${H}" fill="url(#fade)"/>
	<text x="28" y="300" font-family="${DISPLAY}" font-weight="700" font-size="46" fill="#FFFFFF">${title}</text>
	<text x="30" y="334" font-family="${BODY}" font-size="19" fill="${AMBER}">${subtitle}</text>
	</svg>`;
}

console.log("Branding →", OUT);
render("banner", banner(), 1280);
render("thumbnail", thumbnail(), 1920);
render("icon", icon(), 512);
rngState = 3;
render("map-cais09", mapCard("CAIS 09", "Porto industrial · amanhecer",
	`<linearGradient id="p" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#151827"/><stop offset="0.6" stop-color="#6B4252"/><stop offset="0.9" stop-color="#F0A77A"/></linearGradient>`,
	`${crane(380, 270, 170, "#2C1F29")}${containers(0, 640, 270, "#2D2129", 3)}<rect y="270" width="640" height="90" fill="#12121A"/>`), 640);
render("map-avenida11", mapCard("AVENIDA 11", "Centro urbano · noite de chuva",
	`<linearGradient id="p" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#06060F"/><stop offset="0.7" stop-color="#271A4D"/><stop offset="1" stop-color="#4B2A70"/></linearGradient>`,
	`${skyline(0, 640, 290, "#0F0D1E", ["#FFB86B", "#8FB6FF", "#FF5FC8", "#5CFFC2"])}<rect y="290" width="640" height="70" fill="#09080F"/>`), 640);
render("map-posto47", mapCard("POSTO 47", "Fronteira na serra · golden hour",
	`<linearGradient id="p" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3A3550"/><stop offset="0.55" stop-color="#D98B55"/><stop offset="0.85" stop-color="#FFD08A"/></linearGradient>`,
	`${mountains(-40, 700, 280, "#6E4C3E", 3, 180)}${mountains(-40, 700, 300, "#3D2C27", 5, 110)}${pines(0, 640, 300, "#1F1A16", 22)}<rect y="300" width="640" height="60" fill="#1A1412"/>`), 640);
