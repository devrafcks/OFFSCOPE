# Arquitetura

## 1. Visão geral

```
                 ┌──────────────────────────── universo OFFSCOPE ────────────────────────────┐
                 │                                                                            │
  jogador ──► LOBBY place ──(MemoryStore queue + ReserveServer + TeleportAsync)──► MATCH place │
                 │   range · pads · loja · ranking                     1 mapa · rounds · voto  │
                 │                                                                            │
                 └──────────────── ProfileStore (Offscope_Player_v1) compartilhado ────────────┘
```

O **mesmo código** roda nos dois places. O papel é decidido em runtime (`Config.Places`):

| `game.PlaceId` | Papel | Comportamento |
|---|---|---|
| `== Config.Places.Match` | **match** | lê `TeleportData` do primeiro jogador (modo/mapa), cria **uma** `Match` e devolve todos ao lobby no fim |
| qualquer outro (inclusive Studio, IDs `0`) | **lobby** | constrói o lobby; filas locais (in-place) ou MemoryStore (se `Config.Places.Match ~= 0`) |

**Modo in-place** (padrão enquanto os IDs são `0`): a partida acontece no próprio servidor do lobby, num
"slot" afastado (`Config.Maps.SlotSpacing`). Isso permite testar tudo no Studio com *Start Server + 2 players*
sem publicar nada. A iluminação de cada mapa é aplicada **no cliente** (`EnvironmentController`), por isso
lobby e partida convivem no mesmo servidor com céus diferentes.

## 2. Pastas (Rojo)

```
src/
  shared/   → ReplicatedStorage.Shared
    Config.luau                 ÚNICO lugar de números, strings e IDs
    Types.luau  Remotes.luau
    Util/        Signal, Maid, Spring, Format, Rate
    Combat/      Spread, Damage, Hitbox (ray×OBB), ShotStyle
    Progression/ Elo, Ranks, Levels
    Cosmetics/   Catalog, DailyShop, WrapPainter
    Models/      SniperBuilder, KnifeBuilder, ArmsBuilder, CharmBuilder
    Environment/ LightingPresets
    Audio.luau
  server/   → ServerScriptService.Server
    Main.server.luau            bootstrap (Init → Start de cada serviço)
    Services/                   um módulo por responsabilidade (sem framework)
    Match/                      classe Match + regras de modo
    Maps/                       MapKit + construtores procedurais (Lobby, Cais09, Avenida11, Posto47)
  client/   → StarterPlayerScripts.Client
    Main.client.luau
    Controllers/                Camera, Input, Movement, Weapon, Viewmodel, Effects, Hud, Shop,
                                Killcam, Environment, CharacterPose, Settings
    UI/                         Theme + componentes
ServerPackages/ → ServerScriptService.ServerPackages   (ProfileStore — nunca no cliente)
```

Sem Knit (arquivado), sem roblox-ts. Cada serviço/controller é um módulo com `Init()` (ligações) e
`Start()` (loops). Dependências são `require` diretos — fácil de ler, fácil de testar.

## 3. Fluxo de um tiro

```
CLIENTE (WeaponController)                         SERVIDOR (HitscanService)
──────────────────────────                         ─────────────────────────
1. checa ferrolho/munição local
2. spread = Spread.Compute(estado)                  
3. seed = random int; dir = Spread.Apply(look, spread, seed)
4. raycast local → efeitos imediatos
   (som, muzzle, tracer, impacto, kick)
5. Fire:FireServer(origin, look, seed, spread,  ──► 6. rate limit + ferrolho + munição (servidor)
                   serverTime, adsAlpha)            7. |origin − cabeça rebobinada| ≤ 10 studs
                                                    8. spread ≥ mínimo plausível (velocidade/ar)
                                                    9. dir = Spread.Apply(look, spread, seed)
                                                       (mesma conta do cliente, determinística)
                                                   10. look vs. olhar replicado (cone anti silent-aim → log)
                                                   11. t = clamp(serverTime − ping/2 − interp, now − 0,45, now)
                                                   12. raycast no MUNDO (sem personagens) → distância de LOS
                                                   13. ray × OBBs rebobinadas de cada alvo em t (+padding)
                                                   14. zona → dano (Damage.Compute) → DamageService
◄── HitConfirm (hitmarker, HS, kill) ──────────────15.
◄── ShotFx para os outros clientes (tracer 3ª p.) ─16.
```

Histórico de hitboxes (`LagCompensation`): a 30 Hz, guarda o `CFrame` de cada parte de cada alvo
(jogadores **e** dummies do range) por 1 s. A amostragem interpola entre os dois snapshots vizinhos.

## 4. Dados (ProfileStore)

`Offscope_Player_v1` → chave `Player_<UserId>`:

```lua
{
  Coins, Xp, Level,
  Elo, EloMatches, SeasonId, PeakElo,
  Stats = { Kills, Deaths, Headshots, NoScopes, Wins, Losses, Matches, LongestShot, Knives },
  Inventory = { [itemId] = true },
  Equipped = { Wrap, Charm, Knife, KillEffect, Reticle, Tracer },
  Pass = { Season, Xp, Prime, ClaimedFree = {}, ClaimedPrime = {} },
  Daily = { Day, Progress = {}, Claimed = {} },
  Settings = { Sensitivity, AdsSensitivity, Fov, PerformanceMode },
  PurchaseIdCache = { ... },   -- últimos 100 PurchaseId (idempotência do ProcessReceipt)
  StarterPackOwned,
}
```

- No Studio sem acesso à API, o ProfileStore cai sozinho no **mock** (nada é salvo, tudo funciona).
- `TeleportData` leva só `{ Mode, MapId, Ranked, Teams }`. **Nunca** moedas, inventário ou ELO.

## 5. Teleports e filas

- `MatchmakingService` (lobby): cada modo tem uma `MemoryStoreQueue` (`Offscope_Q_<modo>`).
  Um "matcher" em cada lobby lê `N` entradas com `allOrNothing`, reserva servidor e publica a atribuição
  num `MemoryStoreSortedMap` por `UserId`. Cada lobby observa as atribuições dos **seus** jogadores e
  teleporta com `TeleportServiceWrapper.SafeTeleport` (pcall + retry + `TeleportInitFailed`).
- Sem IDs publicados → filas locais e partida in-place (mesmo código de `Match`).
- Match place: *Access Control* "secure within universe" (só teleport de servidor).

## 6. Performance

- **Um mapa por partida**, construído em `nil` e parentado de uma vez (replicação em lote).
- Peças decorativas: `CastShadow = false`, `CanQuery = false`, `CanTouch = false`.
- Luzes com sombra só nas que importam (`MapKit.Light{ shadows = true }` é explícito).
- Viewmodel, tracers, impactos e sons são locais. Efeitos têm pool e `Debris`.
- `StreamingEnabled` no place; `RequestStreamAroundAsync` antes de mover jogadores para o mapa.
- Modo desempenho (setting) desliga Bloom/SunRays/DoF e as luzes secundárias.
- Hitboxes: snapshots compactos (só partes do corpo, sem acessórios), buffer circular.
