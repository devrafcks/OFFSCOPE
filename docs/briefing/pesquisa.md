# Pesquisa: FPS online de sniper no-scope no Roblox

Pesquisa feita em **12 de novembro de 2026**, horário de Brasília (America/Sao_Paulo, UTC-3).  
Objetivo: embasar o jogo **OFFSCOPE** — multiplayer em primeira pessoa, só sniper + faca, fantasia de **no-scope / quickscope** (tiro de quadril, sem mirar no scope), gráficos ultrarrealistas, 3 mapas em rotação.  
Não copiar mapas, nomes, armas, UI, sons ou skins dos jogos citados; use só padrões de loop e monetização.

---

## 1. Nome (opções e escolha)

| Nome | Por quê |
|---|---|
| **OFFSCOPE** (escolhido) | Curto, único o bastante para busca, descreve a fantasia na hora: a mira telescópica está *off*. Tagline: “Uma bala. Sem mira. Só reflexo.” |
| FLICKPOINT | Enfatiza o flick, bom para clipe/highlight. |
| BARESIGHT | “Mira nua”, tom mais sério/realista. |
| NOLOCK | Soa competitivo (sem aim-lock), um pouco genérico. |
| CRACKSHOT | Clima de tiro certeiro; menos óbvio sobre no-scope. |

O prompt e o GDD usam **OFFSCOPE**. Trocar o nome depois é só string no `Config.luau`.

---

## 2. Fontes verificadas

### Jogos de referência (páginas oficiais)

| Jogo | URL |
|---|---|
| RIVALS | https://www.roblox.com/games/87224703310554/RIVALS |
| Arsenal (ROLVe) | https://www.roblox.com/games/286090429/Arsenal |
| Phantom Forces (StyLiS) | https://www.roblox.com/games/292439477/Phantom-Forces |
| Bad Business | https://www.roblox.com/games/3233893879/Bad-Business-FPS |
| FRONTLINES | https://www.roblox.com/games/5938036553/FRONTLINES |
| SNIPER DUELS | https://www.roblox.com/games/109397169461300/SNIPER-DUELS |
| Quickshot | https://www.roblox.com/games/102493848471029/Quickshot |

### Skins / passes (comunitários — conferir no jogo; preços mudam)

| Tema | URL |
|---|---|
| RIVALS skins / loja | https://rivalswiki.com/wiki/skins/ · https://robloxrivals.miraheze.org/wiki/Season_Pass_%26_Prime_Season_Pass |
| RIVALS gamepasses (nov/2026, terceiros) | https://patchday.app/roblox/rivals/game-passes/ |
| Phantom Forces skins / credits | https://roblox-phantom-forces.fandom.com/wiki/Skins · https://roblox-phantom-forces.fandom.com/wiki/Credits |
| Bad Business skins | https://roblox-bad-business.fandom.com/wiki/Skins |
| FRONTLINES passes (wiki set/2026) | https://frontlines.wiki/players/game-passes/ |

### Docs oficiais — armas, templates, net, gráficos, monetização

| Tema | URL |
|---|---|
| Weapons Kit (oficial) | https://create.roblox.com/docs/resources/weapons-kit |
| Sniper Rifle do kit (Creator Store, @IgnisRBX, jul/2026) | https://create.roblox.com/store/asset/83137776064772/Sniper-Rifle |
| Templates (Laser Tag, FPS System, Modern City, Suburban…) | https://create.roblox.com/docs/resources/templates |
| Endorsed packs / templates (DevForum) | https://devforum.roblox.com/t/new-studio-template-endorsed-packs/2333430 |
| Teleport / ReservedServer | https://create.roblox.com/docs/en-us/projects/teleport.md |
| Memory stores / filas (matchmaking) | https://create.roblox.com/docs/cloud-services/memory-stores · https://create.roblox.com/docs/cloud-services/memory-stores/queue |
| Streaming / LOD | https://create.roblox.com/docs/workspace/streaming · https://create.roblox.com/docs/en-us/workspace/streaming/slim.md |
| LightingStyle Realistic | https://create.roblox.com/docs/en-us/environment/lighting.md · https://create.roblox.com/docs/reference/engine/enums/LightingStyle.md |
| Tutorial lighting outdoor | https://create.roblox.com/docs/en-us/tutorials/use-case-tutorials/lighting/enhance-outdoor-environments.md |
| Unified Lighting (substitui Technology=Future como caminho principal) | https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512 |
| Atmosphere | https://create.roblox.com/docs/environment/atmosphere |
| Clouds (filho de Terrain) | https://create.roblox.com/docs/environment/clouds |
| Pós-processamento | https://create.roblox.com/docs/environment/post-processing-effects |
| SurfaceAppearance PBR | https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance.md |
| Terrain / materiais | https://create.roblox.com/docs/parts/terrain · https://create.roblox.com/docs/parts/materials |
| Paid random items | https://create.roblox.com/docs/en-us/production/monetization/paid-random-items.md |
| Developer Products / ProcessReceipt | https://create.roblox.com/docs/production/monetization/developer-products · https://create.roblox.com/docs/reference/engine/classes/MarketplaceService.md |
| Passes | https://create.roblox.com/docs/production/monetization/passes |
| Server Authority (staff; rewind de tiro ainda “implemente você”) | https://devforum.roblox.com/t/server-authority-tech-deep-dive-engineering-insights/4624565 |

### Bibliotecas / netcode (terceiros)

| Lib | URL | Nota |
|---|---|---|
| FastCast API docs | https://github.com/EtiTheSpirit/FastCastAPIDocs | Docs oficiais do autor. O repo antigo do código deu 404 na pesquisa; o asset no Creator Store é https://create.roblox.com/store/asset/4453855787/FastCast-Redux (atualizado em 2021). **Não invente ID de Wally.** Para OFFSCOPE, o modelo certo é **hitscan**, não projétil simulado. |
| RollbackHitbox (open source, DevForum) | https://devforum.roblox.com/t/rollbackhitbox-server-authoritative-lag-compensation-for-roblox-shooters-open-source/4553295 | Padrão: buffer de hitboxes + rewind limitado. |
| Rewind | https://text21.github.io/Rewind/docs | Framework de lag compensation; siga o README se for usar. |
| BitGunPrediction | https://github.com/RiseBit/BitGunPrediction | Predição de projétil + validação no server; siga o README. |
| ByteNet | https://github.com/ffrostfall/ByteNet · docs https://ffrostfall.github.io/ByteNet/ | Networking tipado/buffer. Confirme o identificador no Wally/README (há menção a `ffrostflame/bytenet` no registry — **confira antes de piná-lo**). |
| Promise | https://github.com/evaera/roblox-lua-promise · Wally https://www.wally.run/package/evaera/promise | Útil em teleports e filas. |
| ProfileStore | https://madstudioroblox.github.io/ProfileStore/ · Wally `lm-loleris/profilestore` | Save de inventário/cosméticos. |
| Knit | https://github.com/Sleitnick/Knit (ver ARCHIVAL.md) | **Arquivado, não usar em projeto novo.** |
| Nevermore / Spring | https://github.com/Quenty/NevermoreEngine | Spring útil em viewmodel; não invente ID de Wally — siga o README ou implemente um spring curto no projeto. |
| Rojo / Rokit / Wally | https://create.roblox.com/docs/en-us/projects/external-tools.md · https://rojo.space/docs/v7/ · https://github.com/rojo-rbx/rokit · https://wally.run | Stack padrão. |
| Studio MCP / Open Cloud / plugin | https://create.roblox.com/docs/studio/mcp · https://create.roblox.com/docs/studio/mcp-open-cloud · https://github.com/Roblox/roblox-studio-agent-plugin | |
| Blender MCP (`mcp-for-blender`) | https://github.com/ahujasid/blender-mcp | Assets PBR. |

---

## 3. O que os FPS / snipers da Roblox ensinam (2026)

### RIVALS
Página oficial: duelos **1v1 a 5v5**, **primeiro a 5** vence; pads no lobby para desafiar; keys para armas/skins; contracts; streak e leaderboard; anti-cheat anunciado (ban permanente). Loop curto, zero onboarding pesado, loadout (primária, secundária, melee, utility). Ranked com temporadas e reset. Monetização **pesada em cosmético**: skins, wraps, charms, finishers, cases, Season Pass (faixa grátis + Prime). Relatos de comunidade (conferir no jogo): cases ~**249 R$** (3 por ~724); Daily Shop Common **299** / Rare **449** / Legendary **599**, ou 10 Skin Tickets; Prime Pass citado a **724 R$**. Bundles de armas+cosméticos de 59 a 1.425 R$ (passes, nov/2026, site terceiro). Há caminho grátis lento (tickets no passe, login). **Lição:** partidas curtas, fantasia clara, loja rotativa + passe, mas os preços da Daily Shop são altos — OFFSCOPE deve ser **mais justo** e ter compra direta. Cases = paid random (odds + PolicyService).

### Arsenal (ROLVe)
Arcade “gun game”: mate → troca de arma → faca dourada. Partida 5–10 min, hitscan, mobile ok. Monetização **só cosmética** (skins, kill effects, announcers, emotes; faixas comunitárias ~75–400+ R$). Sem Vantagem paga de dano. **Lição:** kill effects e finishers vendem; todos no mesmo footing mecânico.

### Phantom Forces (StyLiS)
FPS tático, loadout profundo, **projétil com drop**, partidas 10–15 min. Credits compráveis aceleram unlock de arma/anexo — tudo também é grindável (pay-for-convenience, não arma exclusiva). Skins por **case + key** (raridades Common 60% → Legendary 1%, pity nas lendas). Key em Robux ~1/10 do preço em credits (ex. starter case 5 R$ / key 10 R$, wiki). **Lição:** se houver progressão, ela não pode vender precisao/dano; cases exigem disclosure de odds.

### Bad Business
Loja **diária** de skins com preços em credits (comuns ~100, camos ~200, splatter ~400; animadas mais caras). Sem precisar abrir caixa. **Lição:** shop rotativo com preço fixo é o modelo mais limpo para começar.

### FRONTLINES
7v7 tático; armas por progressão. Passes citados como cosméticos + **Extra Loadouts ~199 R$** (QoL, não dano). **Lição:** conveniência (slot de loadout, passe XP) pode ser paga; gun power não.

### SNIPER DUELS
O mais próximo da fantasia: **só sniper**, agressivo, **1v1 a 4v4** (às vezes 12v12), **primeiro a 6**; FFA e LTMs; pads no lobby; coins → skins; trade de skins; streak; ban de cheat/farm. Guias: no-scope só é confiável de perto (spread alto); quickscope = mirar, scope, atirar, unscope; pre-aim na altura da cabeça. **Lição:** o loop “pad → duelo curto → skin” funciona; OFFSCOPE diferencia ao **priorizar o no-scope** (não deixar o scope ser o default “certo”).

### Quickshot
Sniper rápido, **trickshots pagam mais cash**, updates frequentes. **Lição:** recompensar jogada estilosas (no-scope, 360, long shot) com XP/coins e badge no kill feed — não com vantagem de dano.

**Por que um no-scope realista pode funcionar:** o nicho de sniper duel já existe, mas o mercado líder (RIVALS/Arsenal) é arcade e cheio de armas. Um jogo com **uma arma**, feel de CoD-trickshot, mapas bonitos e cosméticos polidos é uma proposta clara (“só isso, mas perfeito”).

---

## 4. Fantasia da arma e tuning (no-scope / quickscope)

Definição para OFFSCOPE:

- Tiro principal = **hip-fire** (sem ADS). Crosshair é um ponto/anel pequeno, não uma luneta.
- **ADS/scope é opcional e desvantajoso no ritmo do jogo** (demora para abrir, deixa o jogador mais lento e visível — glint). O “high skill” é o no-scope; o scope existe para ângulo muito longo no mapa 3, não como crutch.
- Quickscope, se implementado: janela curta em que o scope ainda não assentou — precisão no meio termo entre hip-fire e ADS pleno. Não é o pilar.

Sugestão inicial de feel (tudo no `Config.luau`, playtest obrigatório):

| Parâmetro | Ponto de partida | Por quê |
|---|---|---|
| Cadência | Bolt-action ~0,85–1,1 s entre tiros | Cada bala importa; faca cobre o close |
| Dano | Head = 100 (one-tap); peito ~70–80 (2 taps); membros ~50 | Satisfação de HS no-scope |
| Hip-fire (parado) | Cone pequeno (~0,15–0,35°) | Skill shot, não shotgun nem laser |
| Andando / correndo | Cone cresce (~1,2× / 2×) | Premia parar um frame ou slide-stop |
| Slide / pulo | Spread alto no ar; slide no chão um pouco melhor que corrida | Movimento estilo duel |
| Distância | Full damage até ~180–250 studs; depois cai até um floor (nunca 0 no mapa) | Maps médios |
| Recoil da câmera | Kick vertical curto + sway da viewmodel; recovery rápido | Leitura do próximo tiro |
| ADS time | 280–400 ms + settle | Castiga quem “campa de scope” |
| Munição | 5–8 no pente, reserva alta ou infinita no modo duel | Reload é o único downtime longo |
| Faca | Melee 1 hit nas costas / 2 na frente, range curto, 2ª arma sempre disponível | Clutch e anti-rush |
| FOV hip-fire | Alto (ex. 90–100) | Sensação de velocidade |
| Sons | Estalo seco, ferrolho metálico, whiz da bala, hitmarker agudo em HS, “thud” no corpo | Sem trilha com copyright |

Erros clássicos: spread aleatório demais (parece injusto); hitscan perfeito em full sprint (não há decisão); scope instantâneo melhor que no-scope (mata a fantasia); projectile lento (sniper “sem mira” precisa ser **hitscan** com tracer visual).

---

## 5. Técnica de FPS (netcode, câmera, anti-cheat, partidas)

### Viewmodel em 1ª pessoa
Não use o Tool visível no character como arma na câmera — clipa a parede e mostra a cabeça. Padrão: **viewmodel local** (braços + arma) parentado à `Camera`, atualizado todo frame com sway/bob/recoil (spring). Character em 1ª: transparência 1 no corpo/cabeça, ou `LocalTransparencyModifier`. `CameraMode = LockFirstPerson` no match; no lobby pode ser 3ª. O Weapons Kit oficial é **over-the-shoulder**: sirva de malha/som/config, **troque a câmera**.

### Hitscan autoritativo + predição + lag compensation
1. Cliente dispara na hora (som, tracer, kick) — predição visual.
2. Cliente manda: timestamp, origem, direção, (opcional) sequence id. **Não manda “eu acertei o Player X na cabeça”.**
3. Servidor: rate-limit (≥ ShotCooldown), origem perto da cabeça/câmera rebobinada (máx. uns 8–12 studs), rewind das hitboxes alvo até `clamp(clientTime, now - MAX_REWIND)` (ex. 0,3–0,5 s + buffer de replicação ~0,1 s, como no RollbackHitbox), ray/OBB no estado rebobinado, **LOS** contra o mundo, zona (cabeça/corpo) calculada no server, dano aplicado, confirmação aos clientes.
4. Staff da Roblox (Server Authority deep dive, 2026): rewind de tiro **ainda não é built-in** — implemente com APIs atuais. Não confie no cliente.

Referências de implementação: RollbackHitbox, Rewind. FastCast é para **projéteis**; só faria sentido se no futuro houver travel time. Não trave o MVP nele.

### Anti-cheat (realista, sem falso positivo em flicks)
- Rate limit de tiro / melee / remote.
- Direção do tiro deve estar dentro de um cone da look vector da câmera (silent aim grosseiro).
- Não atravessar parede (LOS).
- Velocidade / teleport / fly: amostrar HRP, tolerar ping.
- Estatístico (log, não ban na 1ª): snaps 180° perfeitos em sequência, % HS sobre-humana em amostra grande, tiros em inimigos nunca renderizados.
- Ban humano ou após score de confiança; o próprio RIVALS/Sniper Duels anunciam ban rígido — copie a **política**, não o detector mágico.

### Kill feed e killcam
Feed no canto: ícones de HS / no-scope / trick (ex. long shot, melee). Killcam MVP: 3 s na câmera do killer (ou replay do último tiro com o viewmodel dele). Não precisa de demo completa no v1.

### Mapas, rotação, matchmaking
Duas arquiteturas válidas:

**A (recomendada no MVP):** um place de **lobby** + um place de **partida**. A partida carrega **um** mapa de `ServerStorage` (os outros nem instanciam). Teleport com `TeleportService:TeleportAsync` + `TeleportOptions.ReservedServerId` (GUID) + `SetTeleportData` só para dados não sensíveis (modo, mapId, party). Economia fica no ProfileStore, não no TeleportData. Filas no **MemoryStoreService** (queue compartilhada entre servers de lobby). Doc: teleport + memory store queue. Use helper tipo `SafeTeleport` (pcall + retry + `TeleportInitFailed`), como na doc oficial.

**B:** um único place, mapas streaming in-place, sem teleport de match — mais simples de testar, pior isolamento e memory se os 3 mapas ficarem carregados.

Votação: no fim do match, 20 s de voto (2 mapas sorteados + “aleatório”). Próxima reserved server recebe o vencedor. Se ninguém vota, random.

Ranked: fila separada 1v1/2v2, ELO (Elo clássico ou Glicko-2, valores no Config), cotas por faixa, reset por temporada. Casual não gasta ELO.

Access Control do universo: “Secure within universe only” para o place de partida (só server teleport). Doc de teleport.

---

## 6. Gráficos ultrarrealistas (2026) e performance

Caminho oficial atual: **`Lighting.LightingStyle = Realistic`**, não `Technology = Future` como API principal (Unified Lighting). `PrioritizeLightingQuality = true` se sombra perto for a identidade; teste também `false` em mapas abertos.

Receita:

- `EnvironmentDiffuseScale = 1`, `EnvironmentSpecularScale = 1` (senão metalness some).
- `ClockTime` por mapa (amanhecer no cais, noite na avenida, golden hour no posto).
- Ambient/OutdoorAmbient com matiz, não cinza.
- Skybox com hemisfério inferior mais escuro, cor do chão.
- **Atmosphere:** Density / Offset / Haze / Color — a névoa do porto e a profundidade da serra saem daqui.
- **Clouds** (filho de **Terrain**): Cover, Density, Color + vento. https://create.roblox.com/docs/environment/clouds
- PointLights seletivos (poste, interior, muzzle flash curto). Shadows só nas luzes que importam.
- Pós: ColorCorrection (contraste 0,1–0,2), Bloom baixo, SunRays de dia, ColorGrading. DoF só em cutscene/killcam — no gameplay atrapalha sniper.
- **PBR:** `SurfaceAppearance` nos meshes-herói (arma, braços, containers, asfalto molhado): Color, Normal OpenGL, Roughness, Metalness. Tileáveis: `MaterialVariant` no MaterialService, inclusive terrain 2022.
- Água / poça: reflexo e roughness baixo.

Mobile / mid:

- `Workspace.StreamingEnabled = true` (só no Studio; não liga por script). Mapas grandes **exigem** isso. https://create.roblox.com/docs/workspace/streaming
- `Model.LevelOfDetail` / SLIM para props estáticos longe (place precisa estar publicado para gerar assets). https://create.roblox.com/docs/en-us/workspace/streaming/slim.md
- `CastShadow = false` em folha, cabo, pedra pequena.
- Evitar overdraw de transparência (grade, folhagem empilhada, vidro em série).
- Poucas luzes locais com sombra; quality automático já derruba Bloom/DoF — a jogabilidade (spread, HUD, hit) não pode depender deles.
- Não instanciar os 3 mapas ao mesmo tempo.
- Viewmodel e efeitos de tiro são locais: barato comparado a 16 characters com PBR + lights.

“Ultrarrealista” no Roblox = **materiais + lighting + silhueta dos mapas + som**, não 4k em tudo. Texture streaming aguenta mapas grandes em device capaz; no baixo, mips menores.

---

## 7. Assets prontos (oficiais) e modelos da comunidade

**Use primeiro o que a Roblox endossa:**

- **Weapons Kit** — https://create.roblox.com/docs/resources/weapons-kit — pistola, shotgun, rifles, **Sniper Rifle**, etc. Licença Limited Use (ler a doc). O kit é 3ª pessoa / projétil; `BulletSpeed` muito alto simula raycast. **Pegue malha, attachments (Tip, Handle), sons, casing, muzzle, config de recoil/spread** e reimplemente 1ª pessoa + hitscan server-side. Sniper oficial: https://create.roblox.com/store/asset/83137776064772/Sniper-Rifle (contém scripts — inspecionar e, no fluxo OFFSCOPE, não usar o `WeaponsSystem` de câmera como autoridade de hit).
- **Templates oficiais** — https://create.roblox.com/docs/resources/templates  
  - **Laser Tag**: blaster 1ª pessoa (dano, munição, recoil, spread) + arena PBR + round system.  
  - **FPS System**: o mesmo sistema + alvos de treino (ótimo para o range do lobby).  
  - **Modern City / Suburban / Village / Pirate Island / Castle**: geometria e materiais para *base* dos 3 mapas (remontar, não publicar o template cru).
- Endorsed packs: https://devforum.roblox.com/t/new-studio-template-endorsed-packs/2333430
- Creator Store: filtre por **Official** / criadores conhecidos; packs de cidade realista da comunidade (ex. listagens “Big City”, “City Realistic Graphics”) **não são oficiais** — só malha, nunca scripts.

**Como não levar backdoor:**

1. Prefira Official / templates / pack que você mesmo modelou no Blender.
2. Ao inserir: leia o aviso **“This model contains scripts”**. Se só quer o mesh, copie as MeshParts para um modelo seu e **apague todos** os Script/LocalScript/ModuleScript.
3. Busque no Explorer: `require` numérico (`require(1234)`), `getfenv`, `loadstring`, `HttpService` para URL estranha, scripts com nome invisível ou em pastas profundas (`Lighting`, `Terrain`, `Camera`).
4. Não execute o place com o modelo cru em produção.
5. Scanners da comunidade (DevForum) existem, mas **não são oficiais** e não pegam tudo. Revisão manual é obrigatória.
6. Áudio: só biblioteca Roblox ou upload próprio; sem faixa comercial.

Blender MCP: modelar/refinar sniper, faca, charms e kits de mapa com PBR e export FBX/GLB + `rbx-import-asset`.

---

## 8. Cosméticos e preços justos

**Só visual.** Nada de dano, spread, velocidade, munição ou ELO por Robux. “Upgrade” = visual (ferrolho dourado, rastro, cor do retículo, charm).

Caminhos de obtenção:

1. **Loja rotativa diária** (compra direta em Robux **ou** coins ganhos jogando) — modelo principal, estilo Bad Business / daily shop do RIVALS, porém mais barato.
2. **Battle pass** com faixa **grátis** + faixa Prime (recompensas fixas, sem caixa no meio).
3. **Desafios / ranked** (camo de 100 no-scope HS, wrap de rank).
4. **Caixas** só se forem no futuro e **100% compliant** (odds numéricas somando 100% antes da compra, `ArePaidRandomItemsRestricted`, alternativa de compra direta para inelegíveis). No MVP: **sem crates**.

Tabela sugerida (justos frente ao mercado 2026; RIVALS cobra 299–599 numa daily skin — OFFSCOPE fica abaixo):

| Categoria | Raridade | Robux | Coins (earn) | Notas |
|---|---|---:|---:|---|
| Camo lisa (cor sólida / 2-tone) | Common | **49** | 2.500 | Sempre na loja base também |
| Camo militar / padrão | Uncommon | **99** | 5.000 | Woodland, urban, desert, arctic |
| Wrap estilizada (hex, carbon, mármore) | Rare | **199** | 10.000 | Loja rotativa |
| Wrap animada / emissive leve | Epic | **349** | 18.000 | Sem flash que dê vantagem |
| Wrap lendária (tema de temporada) | Legendary | **499** | 25.000 ou só passe/evento | 1–2 por temporada |
| Charm simples | Common–Rare | **49–149** | 2.500–8.000 | Pendurado no swing swivel |
| Charm animado / raro | Epic | **199** | 12.000 | |
| Skin de faca | Uncommon–Epic | **99–299** | 5.000–15.000 | Mesma faca mecânica |
| Kill effect (impacto) | Rare–Epic | **149–299** | 8.000–15.000 | Só o *killer* vê o efeito completo em 1ª; os outros veem versão leve |
| Finisher (execução melee) | Epic | **249–399** | passe ou 20.000 | Curto, sem gore realista |
| Cor do retículo / tracer | Common–Rare | **49–99** | 3.000 | Puro visual |
| Passe de temporada (Prime) | — | **399–499** | — | Faixa grátis robusta (camos + coins + 1 charm) |
| Pacote iniciante | — | **99** | — | 2 camos Uncommon + 1 charm, compra direta |

Coins: vitória, kill, bônus de no-scope/HS/trickshot, desafio diário. Sem compra de coins que desbloqueie poder. Se vender coins, o pacote só compra **cosméticos já listados a preço fixo** (ainda assim evite no MVP para não parecer pay-for-collection agressivo).

Inventário no ProfileStore; aplica wrap como `SurfaceAppearance`/textura por material da arma (mesh com ilhas UV de cano, coronha, luneta, carregador — planeje UV desde o Blender).

---

## 9. Stack técnico recomendado

- Luau + **Rojo + Rokit + Wally + ProfileStore**. Sem roblox-ts. **Sem Knit** (arquivado).
- Networking: RemoteEvents bem tipados no MVP; **ByteNet** (ou equivalente) quando o volume de tiros crescer — confirme o pacote no README/Wally.
- Promise para teleport/fila.
- Spring próprio ou Nevermore (README) para viewmodel.
- Lag compensation: implementar no projeto (padrão RollbackHitbox) ou adotar Rewind seguindo o README.
- Hitscan próprio; FastCast só como referência histórica / se um dia houver projétil.

Comandos de instalação verificados vão no prompt.
