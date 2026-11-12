# OFFSCOPE — Game Design Document

> **Uma bala. Sem mira. Só reflexo.**
> FPS online em primeira pessoa para Roblox. Uma sniper, uma faca, três mapas. A fantasia é o **no-scope**.

Versão do documento: 1.0 (12/11/2026). Todos os números citados aqui vivem em
[`src/shared/Config.luau`](../src/shared/Config.luau) — este GDD descreve a **filosofia**; o Config é a fonte da verdade.

---

## 1. Pilares

| Pilar | O que significa na prática |
|---|---|
| **No-scope é o tiro certo** | Hip-fire com cone pequeno parado. O scope é lento, deixa você mais lento e brilha (glint). Ele existe para o ângulo longo do Posto 47, não como muleta. |
| **Cada bala importa** | Bolt-action de ~1 s, headshot mata sempre, corpo precisa de 2. A faca cobre o close. |
| **Partidas curtas** | Duelo de 6 rounds, sem onboarding pesado: entrou, pisou no pad, jogou. |
| **Bonito e leve** | `LightingStyle.Realistic`, Atmosphere, Clouds, PBR por material — e jogável no quality baixo do celular. |
| **Zero pay-to-win** | Robux compra só visual. Nada muda dano, spread, velocidade, munição ou ELO. |

## 2. Loop

```
Lobby (range de treino · pads de fila · loja · ranking)
   └─► fila (pad) ──► partida (servidor reservado ou arena in-place)
                          └─► rounds ──► fim de partida ──► voto de mapa (20 s)
                                                              ├─► próxima partida
                                                              └─► volta ao lobby
```

- **Lobby** é em primeira pessoa e com a arma na mão: dá para treinar no range enquanto espera a fila.
  Cenário: hangar militar a céu aberto na serra — praça com portais de fila, monólito com vitrines
  da arma, heliponto com helicóptero, pátio de contêineres, Arsenal (loja) e quadro de ranking.
- Recompensas (moedas, XP, XP de passe) saem no fim de cada partida e a cada kill estilosa.

## 3. Modos

| Modo | Formato | Vitória | Fila |
|---|---|---|---|
| **Duelo 1v1** | rounds, 1 vida por round | primeiro a **6 rounds** | Casual + **Ranked** (modo rei) |
| **Duplas 2v2** | rounds, 1 vida por round | primeiro a **6 rounds** | Casual + **Ranked** |
| **Equipes 4v4** | TDM com respawn | **40 kills** ou 8 min | Casual |
| **FFA** | 8 jogadores, respawn | **20 kills** ou 8 min | Casual |

- Round de duelo: 75 s. Se acabar o tempo, vence quem tem mais vida somada; empate não pontua.
- Ranked usa **ELO** (K variável por número de partidas), temporada com **soft reset** configurável.
- Faixas: Recruta · Atirador · Veterano · Especialista · Elite · Lenda.

## 4. A arma

### 4.1 Sniper "Vanta-7" (bolt-action, hitscan)

| Parâmetro | Valor inicial | Por quê |
|---|---|---|
| Cadência | 0,95 s entre tiros (ferrolho) | Cada bala importa |
| Pente | 5, reserva infinita | Reload (2,4 s) é o único downtime longo |
| Dano | Cabeça 100 · Peito 75 · Abdômen 65 · Membros 50 | HS sempre mata |
| Queda de dano | 100% até 220 studs, cai até 80% em 450 (cabeça ignora) | Mapas médios |
| Spread parado | 0,25° | Skill shot, nem shotgun nem laser |
| Andando / correndo | ×1,6 / ×3,0 | Premia parar um frame |
| Slide / no ar | ×2,4 / ×7 | Slide-stop é técnica, pulo é aposta |
| ADS | 340 ms + 90 ms de settle, −45% de velocidade, glint visível | Castiga quem campa no scope |
| Quickscope | tiro entre 55% e 100% do ADS: spread interpolado | Extra, não pilar |
| FOV | 95 (hip) / 30 (scope) | Sensação de velocidade |

O tiro é **instantâneo** (hitscan). O tracer é só visual.

### 4.2 Faca

- Sempre disponível (tecla `2`/`Q`, ou ataque rápido `V`).
- **Costas = 100** (1 hit). **Frente = 55** (2 hits). Alcance 6,5 studs, cone de 50°.
- Equipar a faca deixa você **10% mais rápido** — é a ferramenta anti-rush e de clutch.

### 4.3 Movimento

Andar 16 · Correr 23 · Slide (a partir da corrida) 38 → decai em 0,8 s, recarga 1,1 s · Pulo 6,5 studs.

### 4.4 Jogadas estilosas (recompensam moedas e aparecem no kill feed — **nunca dano**)

| Tag | Condição | Moedas |
|---|---|---:|
| `HEADSHOT` | zona cabeça | +15 |
| `NO-SCOPE` | ADS < 15% no disparo | +20 |
| `QUICKSCOPE` | ADS 55–100% em < 0,45 s de scope | +10 |
| `LONGA` | distância ≥ 150 studs | +15 |
| `AÉREO` | atirador no ar | +20 |
| `360` | ≥ 300° de giro na última 1,2 s | +50 |
| `FACADA` / `PELAS COSTAS` | faca / faca nas costas | +20 / +30 |

## 5. Mapas

Um mapa por partida, construído sob demanda pelo `MapService` (os outros não existem na memória).
Cada mapa mistura **uma lane longa de no-scope** com **becos de faca**. Spawns espelhados em justiça, não em geometria.

### 5.1 Cais 09 — porto industrial ao amanhecer
- `ClockTime 6.15`, névoa úmida densa (Atmosphere), nuvens baixas, concreto molhado com poças.
- Pilhas de containers (corredores médios, vãos de faca), armazém fechado, escritório do cais (spawn A) vs. convés do navio (spawn B), guindaste com escada (vertical), **a reta do cais** (lane longa).
- Ambiente: água batendo, gaivotas (slots de áudio).
- Identidade: o mais cinematográfico.

### 5.2 Avenida 11 — centro urbano à noite
- `ClockTime 0.4`, chuva recente: asfalto reflexivo, neon, postes (sombras só nos que importam).
- Estacionamento, hall de prédio, ponte de rooftop, **boca de metrô** (close quarters), **a avenida** como lane de no-scope.
- Identidade: iluminação noturna. No celular, menos luzes (o `EnvironmentController` desliga as secundárias).

### 5.3 Posto 47 — posto de fronteira na serra, golden hour
- `ClockTime 17.6`, Terrain realista (rocha, terra, grama seca), pinheiros, SunRays leves, nuvens visíveis.
- Torres de vigia, hangar, bunkers, rochas de meia distância e **a estrada de terra** (a lane mais longa do jogo).
- Identidade: o mapa "sniper longo" — o scope aparece aqui, mas um bom no-scope ainda mata no mid.

### 5.4 Rotação
Fim de partida → voto de 20 s com **2 mapas sorteados + "Aleatório"**. Sem voto = aleatório.

## 6. Cosméticos (só visual)

Aplicados por grupos de peça da arma procedural (`Barrel`, `Body`, `Stock`, `Scope`, `Mag`, `Accent`).
Texturas de camo geradas no repositório (`assets/textures`) — sobem como Image com o script de upload.

| Item | Raridade | Robux | Moedas |
|---|---|---:|---:|
| Comum (camo lisa, retículo, tracer, charm simples) | Common | 15 | 500 |
| Incomum (camo militar, faca, charm) | Uncommon | 29 | 1.000 |
| Raro (wrap estilizada, kill effect) | Rare | 49 | 1.800 |
| Épico (wrap animada, faca neon, finisher) | Epic | 79 | 3.000 |
| Lendário (wrap da temporada) | Legendary | 149 | 5.000 ou passe |
| Passe Prime | — | 199 | faixa grátis forte |
| Pacote iniciante | — | 49 | 2 camos Uncommon + 1 charm |

Uma partida rende ~400–600 moedas: um item comum sai em uma partida, um épico em ~6.

- **Loja diária**: 6 itens sorteados de forma determinística pela data (todos os servidores veem a mesma loja).
- **Catálogo permanente**: camos Common e Uncommon.
- **Passe de temporada**: 30 tiers fixos, faixa grátis (moedas, camos, charm) + faixa Prime. Sem caixa.
- **Sem crates no MVP.** Se um dia houver: odds 100% visíveis, `PolicyService.ArePaidRandomItemsRestricted`, alternativa direta.
- Kill effects são estilizados (faísca, papel, fumaça, glitch) — nada de gore.

## 7. Monetização

- Robux só via **Developer Products** (cosméticos, Prime da temporada, pacote iniciante).
- `ProcessReceipt` único no servidor: grava o `PurchaseId` no perfil e **espera o save confirmar** antes de `PurchaseGranted`.
- Moedas são ganhas jogando; não vendemos moedas no MVP.
- IDs ficam `0` no Config até o dono criar os produtos. No Studio, compras com ID 0 são simuladas para teste.

## 8. Anti-cheat (alto nível)

- Servidor autoritativo para hit: o cliente manda **origem, direção, semente de spread e horário**, nunca "acertei".
- Rewind das hitboxes (até 0,45 s), checagem de linha de visão, origem perto da cabeça rebobinada.
- Rate limit em todo remote. Cadência do ferrolho validada no servidor. Munição contada no servidor.
- Cone de silent-aim (direção do tiro vs. olhar replicado). Velocidade amostrada com tolerância de ping.
- Estatística (HS% em amostra grande, snaps perfeitos repetidos) → **log e score**, sem ban automático.

## 9. UI e acessibilidade

- UI em pt-BR, com tipografia GothamSSm / Montserrat, cores por raridade e contraste alto.
- HUD mínimo: ponto + anel de spread dinâmico, munição com pips, vida, placar, kill feed.
- Sensibilidade, sensibilidade no scope, FOV e modo desempenho nas configurações (salvas no perfil).
- Mobile: botões de atirar, scope, faca, recarregar, slide e correr. **Zero aim-assist**.
