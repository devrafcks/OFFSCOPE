# Prompt para o Claude Code — planejar e depois construir o OFFSCOPE

> Cole este arquivo inteiro no Claude Code (Roblox Studio aberto, place salvo, plugin/MCP **Roblox Studio** conectado e Rojo disponível).  
> **Primeiro** escreva o plano completo (GDD + arquitetura + marcos) em arquivos no repo. **Depois** implemente em fases, começando pela Fase 1, sem esperar um “ok” extra, a menos que um passo exija ação humana (IDs, publish, dinheiro).  
> Quando um passo exigir o Dashboard (passes, dev products, IDs, content ratings, publicar), pare, explique em pt-BR e espere. **Não invente IDs reais.**  
> Responda e comente o código em **pt-BR**. Código, instâncias e arquivos em inglês claro. UI do jogo em **pt-BR**.

Leia a pesquisa `/workspace/sniper-fps/pesquisa.md` e siga as decisões abaixo. Não copie IP de RIVALS, Arsenal, Phantom Forces, Bad Business, Frontlines, Sniper Duels ou Quickshot (mapas, nomes, UI, sons, skins). Use só padrões de loop.

O nome do jogo é **OFFSCOPE**. Tagline: “Uma bala. Sem mira. Só reflexo.”

---

## Skills e ferramentas que você (Claude Code) deve instalar e usar

Instale e confirme o ambiente **antes** de escrever código de jogo. Use só os passos abaixo, tirados das páginas oficiais ou do README conferido em 10–12/11/2026. Se um comando não estiver na fonte, está dito — siga o README, **não invente flag nem ID de Wally**.

### 1) Plugin oficial Roblox Studio para o Claude Code

Fonte: https://github.com/Roblox/roblox-studio-agent-plugin

```text
/plugin
```

Busque **Roblox Studio**, instale. Depois peça: `Get me set up with Roblox Studio.` Se quebrar: `continue Roblox setup`. Verifique com `/mcp` (`plugin:roblox-studio:macos` e `:windows`; só o do seu SO conecta). Confirme: `list my open Roblox Studio windows`.

### 2) MCP nativo do Roblox Studio

Fonte: https://create.roblox.com/docs/studio/mcp

No Studio: **Assistant → … → Manage MCP Servers** (ou Settings → MCP Servers) → **Enable Studio as MCP server** → **Quick connect → Claude Code**. A doc da Roblox **não** publica `claude mcp add` como caminho principal.

Fallback oficial (`.mcp.json` na raiz):

```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"
    }
  }
}
```

Windows: `"command": "cmd.exe", "args": ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]`.

Fallback opcional da CLI do Claude Code (sintaxe: https://code.claude.com/docs/en/mcp; caminhos: doc da Roblox):

```bash
# macOS
claude mcp add --transport stdio --scope user Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
```

```bash
# Windows
claude mcp add-json --scope user Roblox_Studio "{\"command\":\"cmd.exe\",\"args\":[\"/c\",\"%LOCALAPPDATA%\\\\Roblox\\\\mcp.bat\"]}"
```

Se o escape falhar, use o `.mcp.json`. Confira com `claude mcp list` e `/mcp`.

### 3) Skills oficiais de Open Cloud (não clonar)

Fonte: https://create.roblox.com/docs/studio/mcp-open-cloud

**rbx-open-cloud-usage**, **rbx-permissions**, **rbx-import-asset** já vêm no Studio. Assistant → Settings → Skills. Place **publicado** para permissões. “Money & monetization” só com meu ok. Use `rbx-import-asset` para FBX/GLB (arma, faca, props) de pasta aprovada.

### 4) Rojo, Rokit, Wally, ProfileStore

Fontes: https://create.roblox.com/docs/en-us/projects/external-tools.md · https://rojo.space/docs/v7/ · https://github.com/rojo-rbx/rokit · https://wally.run · https://madstudioroblox.github.io/ProfileStore/

Instale o **Rokit** pelo README (https://github.com/rojo-rbx/rokit) — a Roblox não dá um one-liner único para todos os SOs.

`rokit.toml` (versões da doc; suba se já tiverem sido superadas):

```toml
[tools]
rojo = "rojo-rbx/rojo@7.6.1"
wally = "upliftgames/wally@0.3.2"
lune = "lune-org/lune@0.10.4"
```

Inclua Selene e StyLua se for piná-los (https://github.com/Kampfkarren/selene · https://github.com/JohnnyMorganz/StyLua).

```bash
rokit install
rojo init offscope
cd offscope
rojo build -o offscope.rbxl
rojo plugin install
wally init
# wally.toml, server-side:
# ProfileStore = "lm-loleris/profilestore@1.0.3"
# Promise = "evaera/promise@4.0.0"   -- confirme a versão estável no registry
wally install
rojo serve
```

Mapeie `Packages` no `default.project.json`. **ProfileStore só no server.** Se a versão do registry mudou, use a estável atual e anote no README.

Stack: **Luau + Rojo + Wally + ProfileStore**. Sem roblox-ts. **Sem Knit** (repo arquivado: https://github.com/Sleitnick/Knit/blob/main/ARCHIVAL.md). Services/Controllers simples.

Opcional depois do MVP de remotes: **ByteNet** — https://ffrostfall.github.io/ByteNet/ · https://github.com/ffrostfall/ByteNet — confirme o identificador no Wally/README (não invente; há menção a `ffrostflame/bytenet`).

### 5) Blender MCP (arma, faca, charms, props PBR)

Fonte: https://github.com/ahujasid/blender-mcp — pacote **`mcp-for-blender`**. Blender 3.0+, Python 3.10+, **uv** (instalador oficial, não `pip install uv`).

```bash
# uv: macOS `brew install uv` · Linux:
curl -LsSf https://astral.sh/uv/install.sh | sh
# Windows: winget install --id=astral-sh.uv -e
```

```bash
claude mcp add blender uvx mcp-for-blender
uvx mcp-for-blender install-addon
```

No Blender: Add-ons → **Interface: MCP for Blender** → `N` → Start MCP Server se precisar. Opcional: `curl -LsSf https://www.mcp-for-blender.com/install.sh | sh` (macOS/Linux) ou `irm https://www.mcp-for-blender.com/install.ps1 | iex` (Windows).

---

## 0. O que eu quero

Um **FPS online** na Roblox, **primeira pessoa**, gráficos **ultrarrealistas**, só **uma sniper e uma faca**. A mecânica-core é o tiro **sem mirar no scope** (no-scope / hip-fire / flick), com quickscope no máximo como extra. **3 mapas** realistas em rotação aleatória (e voto no fim da partida). Multiplayer com lobby, matchmaking, modos casuais e ranked (ELO), kill feed, killcam simples. Cosméticos **polidos e a preço justo** (camos/wraps, charms, skins de faca, kill effects, finishers, passe), **sem pay-to-win**. Um único `Config.luau` e `ProcessReceipt` correto.

Use assets **oficiais** como ponto de partida (Weapons Kit / Sniper Rifle, templates Laser Tag, FPS System, Modern City, Suburban, Village — https://create.roblox.com/docs/resources/weapons-kit · https://create.roblox.com/docs/resources/templates · sniper https://create.roblox.com/store/asset/83137776064772/Sniper-Rifle). O kit é 3ª pessoa: aproveite malha, som e attachments; **reimplemente** viewmodel 1ª pessoa + hitscan no servidor. Modelos da comunidade: só mesh, inspeção de scripts (ver armadilhas abaixo).

---

## 1. Entrega 0 — o plano (faça isto primeiro)

Crie no repo (ex. `/workspace/sniper-fps/game/` ou `offscope/`):

- `docs/GDD.md` — design completo em pt-BR (loop, modos, mapas, arma, cosméticos, monetização, anti-cheat em alto nível).
- `docs/arquitetura.md` — places, pastas Rojo, serviços, fluxo de um tiro, dados, teleports.
- `docs/marcos.md` — fases abaixo, com definição de pronto.
- `README.md` — setup Rojo + checklist humano.

O GDD deve incluir os 3 mapas e a tabela de preços deste prompt (pode refinar números no Config, não mude a filosofia).

---

## 2. Decisões de design (obrigatórias no plano e no código)

### Loop
Lobby (range de treino + fila + loja de cosméticos) → match em reserved server → 1 mapa carregado → round(s) → voto de mapa ou random → próxima partida ou volta ao lobby. Partidas **curtas**.

### Modos (Config)
- **Duelo 1v1** — primeiro a 6 (modo rei; é o ranked padrão).
- **Duplas 2v2** — primeiro a 6 (ranked também).
- **Equipes 4v4** — TDM, primeiro a 40 ou tempo (casual).
- **FFA** — 8 jogadores, primeiro a 20 (casual).
- Ranked: só 1v1/2v2, ELO no ProfileStore, temporada com reset configurável.

### Arma — feel (tudo no Config; playteste e ajuste)
- Hitscan, bolt-action, **~0,85–1,1 s** entre tiros.
- Head 100 (one-tap), peito ~70–80, membros ~50.
- Hip-fire é o tiro “certo”: cone pequeno parado (~0,15–0,35°), piora andando/correndo/no ar; slide no chão um pouco melhor que corrida.
- ADS/scope **lento** (280–400 ms + settle), reduz velocidade, pode ter glint — útil só em ângulo longo, não é o default.
- Faca sempre disponível; 1 hit nas costas, 2 na frente; range curto.
- FOV hip-fire alto. Recoil de câmera curto + spring na viewmodel. Tracer visual (o hit é instantâneo).
- Sons originais ou do kit oficial, sem soundtrack com copyright.
- Recompensar no-scope / HS / long shot / trick no kill feed e em coins — nunca em dano.

### Três mapas (realista, assimétricos mas justos, misturam lane longa e beco para faca)

**1. Cais 09** — porto industrial ao **amanhecer**, névoa úmida, concreto molhado (PBR, poças), containers empilhados (corredores médios + faca entre os vãos), armazém fechado, escritório do cais vs. convés de navio como spawns, um guindaste/escada para vertical, uma reta longa no cais. Atmosphere densa, Clouds baixas, ClockTime de aurora, gaivotas/som de água (áudios livres). Mapa “médio”, o mais cinematográfico.

**2. Avenida 11** — **centro urbano à noite**, chuva recente, asfalto reflexivo, neon e postes (PointLights com sombra só nos que importam), estacionamento, hall de prédio, uma ligação de rooftop, boca de metrô para close-quarters, a avenida como lane de no-scope. Usar geometria do template **Modern City** só como base, remontada. Iluminação noturna é a identidade; testar no mobile (menos luzes).

**3. Posto 47** — posto de fronteira / barragem na **serra**, golden hour, terreno realista (pedra, terra, grama seca ou pinheiros), torres de vigia, hangar, estrada de terra (a lane mais longa dos três), bunkers e rochas para mid-range. Clouds visíveis, SunRays leves. O mapa “sniper longo”; o scope opcional aparece aqui, mas um bom no-scope ainda mata no mid.

Rotação: carga de **um** mapa por match (`ServerStorage` → workspace), os outros não instanciam. Fim de partida: voto 20 s (2 opções + aleatório). Sem voto = random.

### Cosméticos e preços (compra direta; sem crate no MVP)

Só visual. Wraps usam UVs da arma (cano, coronha, luneta, pente). Charms no swivel. Kill effect leve para terceiros.

| Item | Raridade | Robux | Coins |
|---|---|---:|---:|
| Camo lisa | Common | 49 | 2.500 |
| Camo militar | Uncommon | 99 | 5.000 |
| Wrap estilizada | Rare | 199 | 10.000 |
| Wrap animada / emissive | Epic | 349 | 18.000 |
| Wrap lendária (temporada) | Legendary | 499 | 25.000 ou passe |
| Charm simples | Common–Rare | 49–149 | 2.500–8.000 |
| Charm raro | Epic | 199 | 12.000 |
| Skin de faca | Uncommon–Epic | 99–299 | 5.000–15.000 |
| Kill effect | Rare–Epic | 149–299 | 8.000–15.000 |
| Finisher melee | Epic | 249–399 | 20.000 ou passe |
| Retículo / tracer | Common–Rare | 49–99 | 3.000 |
| Passe Prime | — | 399–499 | faixa grátis forte |
| Pacote iniciante | — | 99 | 2 camos Uncommon + 1 charm |

Loja rotativa diária + catálogo permanente das camos Common/Uncommon. Passe com recompensas **fixas**. Se um dia houver caixa: odds 100%, `PolicyService.ArePaidRandomItemsRestricted`, alternativa direta — https://create.roblox.com/docs/en-us/production/monetization/paid-random-items.md

### Gráficos
`LightingStyle = Realistic`, EnvironmentDiffuse/Specular = 1, Atmosphere + Clouds (Clouds é filho de Terrain), PBR, StreamingEnabled, LOD/SLIM em props longe, poucas luzes com sombra, Bloom baixo, jogável no quality baixo. Docs na pesquisa.

### Netcode
Cliente prevê o tiro; servidor valida (cooldown, origem, rewind 0,3–0,5 s + buffer, LOS, zona). Nunca confie em “eu acertei”. Ver pesquisa (RollbackHitbox / Rewind como referência; implemente no projeto). Rate limit. Anti-silent-aim grosseiro (direção vs. look vector). Logs estatísticos, sem ban automático no primeiro flick.

Arquitetura de servers: **lobby place + match place**, `TeleportAsync` + ReservedServer + `SafeTeleport` (doc oficial), MemoryStore queue no lobby, TeleportData só com map/mode/party (nada de coins). Access Control do match: secure within universe.

---

## 3. Arquitetura de código

```
src/
  ReplicatedStorage/
    Config.luau          -- ÚNICO lugar de números, strings, IDs (0 até eu colar)
    Remotes.luau
    Types.luau
  ServerScriptService/
    Main.server.luau
    Services/
      DataService.luau          -- ProfileStore
      MonetizationService.luau  -- ProcessReceipt + passes
      MatchmakingService.luau
      TeleportServiceWrapper.luau
      RoundService.luau
      MapService.luau
      HitscanService.luau       -- rewind + validação
      DamageService.luau
      AntiCheatService.luau
      InventoryService.luau
  StarterPlayer/StarterPlayerScripts/Controllers/
      ViewmodelController.luau
      FpsInputController.luau
      HudController.luau
      ShopController.luau
      KillcamController.luau
```

`Config.luau` contém: nome OFFSCOPE, durações, modos, ELO, spread/dano/cooldown, raios, `Maps`, catálogo de cosméticos (preço, raridade, productId = 0), passe, `ProfileStoreName = "Offscope_Player_v1"`.

**ProcessReceipt:** um callback no servidor (ou um `BindReceiptHandler`). Persistir `PurchaseId` no perfil **antes** de `PurchaseGranted`. Não conceder no `PromptProductPurchaseFinished`. Player ausente → `NotProcessedYet`. https://create.roblox.com/docs/reference/engine/classes/MarketplaceService.md · https://create.roblox.com/docs/production/monetization/developer-products

---

## 4. Fases de implementação (depois do plano)

**Fase 1 — Fundações.** Rojo, Config, ProfileStore, lobby simples, range (alvos do template FPS System), viewmodel 1ª pessoa, hitscan local+server em dummy, faca, HUD de munição/spread.

**Fase 2 — Uma partida.** Cais 09 jogável (mesmo que placeholder PBR), 1v1 primeiro a 6 em reserved server (ou in-place se o teleport ainda não estiver publicado — documente). Spawns, respawn, kill feed, fim de round.

**Fase 3 — Netcode sério.** Rewind, LOS, rate limit, confirmação de hit, interpolação visual. Playtest com lag no Studio.

**Fase 4 — 3 mapas + rotação + modos.** Avenida 11 e Posto 47 (blockout fiel ao GDD, lighting de cada um). Vote / random. FFA e 4v4. Fila MemoryStore quando o universo tiver 2 places publicados.

**Fase 5 — Cosméticos e monetização.** Inventário, aplicar wrap/charm/faca/efeito, loja rotativa, ProcessReceipt, passe (faixa grátis no código; Prime com passId = 0 até eu criar). Pacote iniciante.

**Fase 6 — Ranked, killcam, polish.** ELO, leaderboard, killcam 3 s, sons, anti-cheat básico, streaming/LOD, passa no quality baixo.

Definição de pronto da Fase 2 (mínimo publicável de playtest): dois jogadores no 1v1, no-scope mata de forma justa, faca funciona, um mapa gira, ninguém ganha poder com Robux.

---

## 5. Dicas e armadilhas

1. **Não confie no hit do cliente.** É o erro nº 1 dos FPS da Roblox.
2. **Viewmodel ≠ Tool do character.** Tool no corpo clipa e mostra a cabeça.
3. Weapons Kit traz **ShoulderCamera** — não deixe isso ligado no match.
4. Hitscan, não projétil lento. FastCast não é necessário no MVP (docs: https://github.com/EtiTheSpirit/FastCastAPIDocs; asset antigo no Store). Se usar lib de rewind de terceiros, **siga o README**, não invente o require.
5. Spread: playteste. Aleatório demais = raiva; zero em corrida = sem decisão.
6. Se o ADS for melhor e mais rápido que o no-scope, a fantasia morre.
7. Não carregue os 3 mapas juntos. StreamingEnabled no place, um mapa por match.
8. Realistic lighting é pesado: orçamento de luz/sombra, `CastShadow` off em miudeza, Bloom/DoF não são gameplay.
9. Sem crate no MVP. Sem dano pago. Sem anexos que mudem TTK por Robux.
10. `TeleportData` não é cofre. Coins e inventário = ProfileStore. Teleport só no servidor, com retry (`TeleportInitFailed`).
11. Modelos grátis: aviso de scripts → copiar mesh, apagar scripts, caçar `require(123)`, `getfenv`, `loadstring`, Http oculto.
12. Áudio com copyright = strike. Gore realista = moderação. Kill effects estilizados (faísca, papel, fumaça), não sangue pesado.
13. Não invente product/pass IDs. `0` + flag de Studio para conceder cosmético em teste.
14. Knit está morto. Não adicione “só para organizar”.
15. Mobile e controle: botão de tiro/ADS/faca; mira assistida **zero** ou mínima e só em alvo já no retículo (sniper no-scope com aim-assist forte destrói o skill).
16. Content ratings no Hub (violência, fear). Eu preencho.

---

## 6. Checklist do que EU (Rafael) faço à mão

1. Instalar Studio, Claude Code, Rokit/Rojo, Blender; ligar MCP e plugin Rojo.
2. Criar o experience, **publicar** lobby e match place (precisa de PlaceIds reais no Config).
3. Access Control do match: teleports seguros no universo (doc de teleport).
4. Criar dev products / passe / pacote iniciante com os nomes e preços do Config; colar IDs.
5. Content Ratings no Hub, com honestidade.
6. Testar em celular (quality baixo) e PC, com lag do Studio, 1v1 e 4v4.
7. Aprovar áudios e meshes importados; eu faço upload de som/imagem.
8. Publicar ícone, descrição (“OFFSCOPE — uma bala, sem mira”), genre FPS. Você não publica no ar sozinho.

---

## 7. Por onde começar agora

1. Instalar as tools da seção do topo e confirmar `/mcp`.
2. Escrever `docs/GDD.md`, `docs/arquitetura.md`, `docs/marcos.md` e o README (Entrega 0).
3. Sem pausa, iniciar a **Fase 1** no mesmo repo: Rojo + `Config.luau` + viewmodel + hitscan em dummy no range.

Não escreva um monólito. Números só no Config. Quando chegar em produtos pagos, liste nomes/preços e espere os IDs.
