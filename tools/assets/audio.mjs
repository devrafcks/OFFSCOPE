// Sintetiza TODOS os sons do jogo (WAV 44,1 kHz mono 16-bit) em assets/audio.
// Nenhum áudio de terceiros: tiro, ferrolho, hitmarkers, ambiente — tudo é matemática.
// Uso: node tools/assets/audio.mjs
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const OUT = join(ROOT, "assets", "audio");
const RATE = 44100;

let seed = 4747;
const rand = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296) * 2 - 1;

function buffer(seconds) {
	return new Float32Array(Math.ceil(seconds * RATE));
}

function writeWav(name, samples) {
	// normaliza com folga e aplica fade-out curtíssimo (sem clique no fim)
	let peak = 0;
	for (const s of samples) peak = Math.max(peak, Math.abs(s));
	const gain = peak > 0 ? 0.89 / peak : 1;
	const fade = Math.min(samples.length, 400);
	const data = Buffer.alloc(samples.length * 2);
	for (let i = 0; i < samples.length; i++) {
		let s = samples[i] * gain;
		if (i > samples.length - fade) s *= (samples.length - i) / fade;
		data.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(s * 32767))), i * 2);
	}
	const header = Buffer.alloc(44);
	header.write("RIFF", 0);
	header.writeUInt32LE(36 + data.length, 4);
	header.write("WAVE", 8);
	header.write("fmt ", 12);
	header.writeUInt32LE(16, 16);
	header.writeUInt16LE(1, 20);
	header.writeUInt16LE(1, 22);
	header.writeUInt32LE(RATE, 24);
	header.writeUInt32LE(RATE * 2, 28);
	header.writeUInt16LE(2, 32);
	header.writeUInt16LE(16, 34);
	header.write("data", 36);
	header.writeUInt32LE(data.length, 40);
	writeFileSync(join(OUT, `${name}.wav`), Buffer.concat([header, data]));
	console.log(`  ✓ ${name}.wav  (${(samples.length / RATE).toFixed(2)} s)`);
}

// ── blocos ──────────────────────────────────────────────────────────────────
const env = (t, attack, decay) => (t < attack ? t / attack : Math.exp(-(t - attack) / decay));

function lowpass(samples, cutoff) {
	const rc = 1 / (2 * Math.PI * cutoff);
	const alpha = 1 / RATE / (rc + 1 / RATE);
	let y = 0;
	for (let i = 0; i < samples.length; i++) {
		y += alpha * (samples[i] - y);
		samples[i] = y;
	}
	return samples;
}

function highpass(samples, cutoff) {
	const rc = 1 / (2 * Math.PI * cutoff);
	const alpha = rc / (rc + 1 / RATE);
	let prevX = 0, prevY = 0;
	for (let i = 0; i < samples.length; i++) {
		const y = alpha * (prevY + samples[i] - prevX);
		prevX = samples[i];
		prevY = y;
		samples[i] = y;
	}
	return samples;
}

// reverb barato: linhas de atraso com feedback
function reverb(samples, mix, size) {
	const out = Float32Array.from(samples);
	const delays = [1557, 1617, 1491, 1422].map((d) => Math.round(d * size));
	for (const d of delays) {
		const line = new Float32Array(samples.length);
		for (let i = d; i < samples.length; i++) line[i] = samples[i - d] * 0.6 + line[i - d] * 0.72;
		for (let i = 0; i < samples.length; i++) out[i] += line[i] * mix / delays.length;
	}
	return out;
}

function add(target, source, offsetSeconds = 0, gain = 1) {
	const offset = Math.round(offsetSeconds * RATE);
	for (let i = 0; i < source.length && i + offset < target.length; i++) target[i + offset] += source[i] * gain;
	return target;
}

function click(seconds, freq, decay, noiseAmount = 0.6) {
	const s = buffer(seconds);
	for (let i = 0; i < s.length; i++) {
		const t = i / RATE;
		s[i] = (Math.sin(2 * Math.PI * freq * t) * (1 - noiseAmount) + rand() * noiseAmount) * Math.exp(-t / decay);
	}
	return s;
}

function tone(seconds, freq, decay, harmonics = [1], attack = 0.004) {
	const s = buffer(seconds);
	for (let i = 0; i < s.length; i++) {
		const t = i / RATE;
		let v = 0;
		harmonics.forEach((h, k) => (v += Math.sin(2 * Math.PI * freq * (k + 1) * t) * h));
		s[i] = v * env(t, attack, decay);
	}
	return s;
}

function noise(seconds) {
	const s = buffer(seconds);
	for (let i = 0; i < s.length; i++) s[i] = rand();
	return s;
}

// ── sons ────────────────────────────────────────────────────────────────────
function sniperShot(distant) {
	const out = buffer(distant ? 2.4 : 1.8);
	// estalo supersônico (crack)
	const crack = highpass(noise(0.08), distant ? 900 : 1800);
	for (let i = 0; i < crack.length; i++) crack[i] *= Math.exp(-(i / RATE) / 0.012);
	// corpo (boom) com queda de pitch
	const boom = buffer(0.5);
	let phase = 0;
	for (let i = 0; i < boom.length; i++) {
		const t = i / RATE;
		phase += (2 * Math.PI * (110 * Math.exp(-t * 9) + 42)) / RATE;
		boom[i] = (Math.sin(phase) * 0.9 + rand() * 0.35) * env(t, 0.002, 0.11);
	}
	lowpass(boom, distant ? 380 : 900);
	add(out, crack, distant ? 0.0 : 0, distant ? 0.5 : 1.1);
	add(out, boom, distant ? 0.05 : 0.002, 1.0);
	// cauda do ambiente
	const tail = lowpass(noise(distant ? 2 : 1.4), distant ? 600 : 1400);
	for (let i = 0; i < tail.length; i++) tail[i] *= env(i / RATE, 0.01, distant ? 0.55 : 0.35) * 0.25;
	add(out, tail, 0.01);
	return distant ? lowpass(reverb(out, 0.6, 1.6), 2400) : reverb(out, 0.35, 1.1);
}

function bolt() {
	const out = buffer(0.75);
	add(out, highpass(click(0.06, 2400, 0.008, 0.7), 900), 0.0, 0.8); // destrava
	const slide = highpass(noise(0.12), 2500);
	for (let i = 0; i < slide.length; i++) slide[i] *= Math.sin((i / slide.length) * Math.PI) * 0.35;
	add(out, slide, 0.08); // puxa
	add(out, click(0.08, 1300, 0.012, 0.5), 0.22, 1.0); // bate atrás
	add(out, slide, 0.32, 0.8); // empurra
	add(out, click(0.08, 1700, 0.01, 0.5), 0.46, 1.1); // fecha
	add(out, click(0.05, 2900, 0.006, 0.6), 0.58, 0.6); // trava
	return reverb(out, 0.15, 0.4);
}

function reload() {
	const out = buffer(2.3);
	add(out, click(0.08, 900, 0.015, 0.5), 0.25, 0.8); // solta o pente
	const drop = lowpass(noise(0.15), 700);
	for (let i = 0; i < drop.length; i++) drop[i] *= Math.exp(-(i / RATE) / 0.04);
	add(out, drop, 0.55, 0.6);
	add(out, click(0.1, 600, 0.02, 0.4), 1.25, 0.8); // encaixa
	add(out, click(0.06, 2200, 0.008, 0.6), 1.32, 1.0);
	add(out, bolt(), 1.5, 0.8);
	return out;
}

function whoosh(seconds, from, to, gain = 1) {
	const s = noise(seconds);
	// filtro varrido simulado com dois passa-baixas em sequência
	const out = buffer(seconds);
	let y1 = 0, y2 = 0;
	for (let i = 0; i < s.length; i++) {
		const t = i / s.length;
		const cutoff = from + (to - from) * t;
		const alpha = 1 - Math.exp((-2 * Math.PI * cutoff) / RATE);
		y1 += alpha * (s[i] - y1);
		y2 += alpha * (y1 - y2);
		out[i] = (y1 - y2) * Math.sin(t * Math.PI) * gain;
	}
	return out;
}

function chord(seconds, freqs, decay, attack = 0.01) {
	const out = buffer(seconds);
	freqs.forEach((f, i) => add(out, tone(seconds, f, decay, [1, 0.3, 0.12], attack), i * 0.06, 1 / freqs.length));
	return reverb(out, 0.3, 0.8);
}

function ambience(seconds, kind) {
	const out = buffer(seconds);
	if (kind === "harbor") {
		// ondas: ruído lento modulado + bater na estaca
		const waves = lowpass(noise(seconds), 420);
		for (let i = 0; i < waves.length; i++) {
			const t = i / RATE;
			waves[i] *= 0.6 + 0.4 * Math.sin(2 * Math.PI * t / 4.2) * Math.sin(2 * Math.PI * t / 7.1);
		}
		add(out, waves, 0, 1);
		for (const at of [1.3, 5.8, 9.2]) {
			const gull = buffer(0.5);
			for (let i = 0; i < gull.length; i++) {
				const t = i / RATE;
				const f = 1500 + 500 * Math.sin(t * 22) - t * 900;
				gull[i] = Math.sin(2 * Math.PI * f * t) * env(t, 0.03, 0.12) * 0.12;
			}
			add(out, gull, at);
		}
	} else if (kind === "city") {
		const hum = lowpass(noise(seconds), 160);
		add(out, hum, 0, 1);
		add(out, tone(seconds, 60, 1e9, [0.05, 0.03]), 0, 1);
		for (const at of [2.5, 8]) add(out, whoosh(3, 200, 900, 0.5), at); // carro passando
	} else {
		const wind = buffer(seconds);
		let y = 0;
		for (let i = 0; i < wind.length; i++) {
			const t = i / RATE;
			const cutoff = 300 + 250 * Math.sin(2 * Math.PI * t / 5.3);
			y += (1 - Math.exp((-2 * Math.PI * cutoff) / RATE)) * (rand() - y);
			wind[i] = y * (0.6 + 0.4 * Math.sin(2 * Math.PI * t / 3.7));
		}
		add(out, wind, 0, 1);
	}
	// crossfade início/fim para loop limpo
	const xf = RATE * 0.5;
	for (let i = 0; i < xf; i++) {
		const a = i / xf;
		out[i] = out[i] * a + out[out.length - xf + i] * (1 - a);
	}
	return out.subarray(0, out.length - xf);
}

mkdirSync(OUT, { recursive: true });
console.log("Áudio →", OUT);

writeWav("SniperShot", sniperShot(false));
writeWav("SniperShotDistant", sniperShot(true));
writeWav("BoltCycle", bolt());
writeWav("Reload", reload());
writeWav("DryFire", click(0.12, 1800, 0.01, 0.5));
writeWav("ScopeIn", add(whoosh(0.3, 400, 2400, 0.6), click(0.06, 2600, 0.006), 0.22, 0.5));
writeWav("KnifeSwing", whoosh(0.32, 600, 5200, 1));
writeWav("KnifeHit", add(lowpass(click(0.25, 140, 0.05, 0.6), 1200), highpass(click(0.06, 3000, 0.01, 0.8), 1500), 0, 0.4));
writeWav("HitBody", add(tone(0.12, 1250, 0.03, [1, 0.2]), click(0.03, 4000, 0.004), 0, 0.3));
writeWav("HitHead", add(tone(0.5, 1980, 0.12, [1, 0.5, 0.25]), tone(0.5, 2970, 0.08, [0.4]), 0.0, 0.6));
writeWav("KillConfirm", add(tone(0.4, 880, 0.08, [1, 0.3]), tone(0.5, 1318, 0.12, [1, 0.3]), 0.07, 1));
writeWav("BulletWhiz", whoosh(0.35, 3000, 600, 1));
writeWav("ImpactConcrete", add(lowpass(click(0.3, 180, 0.04, 0.8), 2200), highpass(noise(0.05), 3000), 0, 0.3));
writeWav("ImpactMetal", add(tone(0.8, 1720, 0.18, [1, 0.6, 0.4, 0.2]), click(0.05, 3500, 0.006), 0, 0.5));
writeWav("UiClick", click(0.06, 2100, 0.006, 0.3));
writeWav("UiBuy", chord(0.9, [784, 988, 1175, 1568], 0.25));
writeWav("RoundStart", add(tone(0.6, 440, 0.2, [1, 0.4]), tone(0.6, 660, 0.25, [1, 0.4]), 0.12, 1));
writeWav("RoundWin", chord(1.6, [523, 659, 784, 1046], 0.5));
writeWav("Countdown", tone(0.25, 1046, 0.06, [1, 0.3, 0.1]));
writeWav("AmbientHarbor", ambience(12, "harbor"));
writeWav("AmbientCity", ambience(12, "city"));
writeWav("AmbientMountain", ambience(12, "mountain"));
