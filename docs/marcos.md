# Marcos

Legenda: ✅ feito no código · 🧪 precisa de playtest humano · 🔑 precisa de ação no Dashboard

| Fase | Entrega | Definição de pronto | Estado |
|---|---|---|---|
| **0 — Plano** | GDD, arquitetura, marcos, README | Docs no repo e revisados | ✅ |
| **1 — Fundações** | Rojo + Rokit + Wally, `Config`, ProfileStore, lobby, range com dummies, viewmodel 1ª pessoa, hitscan cliente+servidor, faca, HUD de munição/spread | Atirar num dummy no range e ver o dano confirmado pelo servidor | ✅ 🧪 |
| **2 — Uma partida** | Cais 09, Duelo 1v1 primeiro a 6, spawns, respawn, kill feed, fim de round | 2 jogadores no Studio (*Start Server*) jogam um duelo inteiro | ✅ 🧪 |
| **3 — Netcode sério** | Rewind 30 Hz, LOS, rate limit, confirmação de hit, glint replicado | Playtest com *Incoming Replication Lag* 0,2 s no Studio e acerto justo | ✅ 🧪 |
| **4 — 3 mapas + modos** | Avenida 11, Posto 47, voto/aleatório, 2v2, 4v4, FFA, fila MemoryStore | Ciclo partida → voto → partida nos 3 mapas | ✅ 🧪 🔑 (fila cross-server exige 2 places publicados) |
| **5 — Cosméticos** | Inventário, wraps, charms, facas, kill effects, retículos, tracers, loja diária, passe, ProcessReceipt, pacote iniciante | Comprar com moedas, equipar e ver na arma; compra Robux simulada no Studio | ✅ 🧪 🔑 (IDs dos produtos) |
| **6 — Ranked e polish** | ELO + faixas + temporada, leaderboard, killcam 3 s, anti-cheat básico, modo desempenho, mobile | Partida ranked atualiza ELO; killcam toca; quality baixo jogável | ✅ 🧪 |

## Próximos passos (pós-MVP)

- Meshes-herói no Blender (arma, braços, containers) com `SurfaceAppearance` + `rbx-import-asset`.
- Animações gravadas (KeyframeSequence) para o corpo em 3ª pessoa.
- Parties (entrar na fila 2v2 com amigo).
- ByteNet para serializar tiros quando o volume crescer.
- SLIM/LOD dos props quando o place estiver publicado.
