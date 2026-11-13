# Lançamento — passo a passo

> **Status (13/11/2026):** publicado e público em
> [roblox.com/games/133650768159073](https://www.roblox.com/games/133650768159073) — universe `10776286889`.
> Feito: place publicada (modo servidor único), 34 produtos, sons e texturas, ícone, thumbnails,
> gênero e questionário (Leve · 16+). Pendente: teste ao vivo com 2 contas (passo 5) e liberar menores de 16.

Tudo que depende da **sua conta** no Roblox, na ordem. Cada passo diz o que fazer e como conferir.
O código não publica nada sozinho.

## 1. Publicar as duas places (≈10 min)

O OFFSCOPE usa **uma experiência com duas places**: o lobby (place inicial) e a place de partida.

1. Gere o arquivo: `rojo build default.project.json -o OFFSCOPE.rbxl` e abra no Studio.
2. **File → Publish to Roblox As…** → *Create new experience* → nome **OFFSCOPE**. Essa é a place inicial (lobby).
3. No Creator Hub da experiência: **Places → Add Place** → crie a place **Partida** e publique o mesmo `.rbxl` nela
   (o código decide sozinho se é lobby ou partida pelo `Config.Places`).
4. Cole os dois PlaceIds em `src/shared/Config.luau`:
   ```lua
   Config.Places = {
   	Lobby = 1234567890,
   	Match = 1234567891,
   }
   ```
5. Republique **as duas** places com esse Config.
6. Game Settings → **Security**: ligue *Enable Studio Access to API Services* (DataStore e MemoryStore).
7. Game Settings → **Places** → place Partida: *Max Players* = 8. Lobby: 30 é um bom começo.

**Conferir:** entre no lobby publicado, pise no pad de Duelo com um amigo — os dois devem ser teleportados
para a place Partida e voltar ao lobby no fim.

## 2. Criar os Developer Products (≈2 min)

Siga **[docs/produtos.md](produtos.md)** → seção *Criar todos de uma vez*:

```bash
node tools/products/create.mjs --dry-run
node tools/products/create.mjs
```

O script grava os 34 IDs no `Config.luau`. Republique as duas places.
Se a API (beta) recusar, a mesma página tem a tabela para criar à mão.

**Conferir:** compre o item mais barato (R$ 15) na loja publicada. Ele aparece no inventário e continua lá
depois de sair e entrar de novo (prova que o `ProcessReceipt` gravou no ProfileStore).

## 3. Subir sons e texturas (≈3 min)

```bash
node tools/assets/upload.mjs --dry-run
node tools/assets/upload.mjs
```

Gera `src/shared/AssetIds.luau`. Sem isso o jogo usa sons genéricos do Roblox e camos em cor sólida.
Republique.

## 4. Página da experiência (≈15 min)

- **Questionário de maturidade** (Creator Hub → experiência → *Maturity & Compliance*). Violência leve,
  sem sangue, sem conteúdo gerado por usuário além do chat.
- Ícone: `assets/branding/icon.png` · Thumbnails: `assets/branding/thumbnail.png` e os cards dos mapas.
- Descrição curta: *"Sniper no-scope competitivo. Uma bala, sem mira, só reflexo. Duelos 1v1, duplas, 4v4,
  todos contra todos e ranked com ELO. Cosméticos só visuais — nada de pay-to-win."*
- Gênero: Shooter · Dispositivos: PC, celular, tablet, console.
- Deixe **privada** até o teste do passo 5 passar; depois mude para pública.

## 5. Teste final com o jogo publicado (≈15 min, 2 contas)

- [ ] Fila Duelo → teleporte para a Partida → 6 rounds → votação → volta ao lobby
- [ ] Ranked 1v1: o ELO muda nos dois (e continua igual depois de sair e voltar)
- [ ] Loja: compra com moedas e com Robux; item continua no inventário depois de reentrar
- [ ] Celular: menus cabem na tela e os botões de toque (ATIRAR, SCOPE, FACA, SLIDE) funcionam
- [ ] Sair no meio de uma partida pelo menu **M → SAIR DA PARTIDA**

## O que já foi testado no Studio (sem publicar)

| Área | Como | Resultado |
|---|---|---|
| Combate | 102 testes de unidade + tiros reais com 2 clientes | headshot, peito e faca pelas costas corretos |
| Duelo 1v1 | partida inteira até 6 com 2 clientes | rounds, empate sem ponto, fim, recompensa, votação |
| Ranked 1v1 | partida até 6 | ELO +20 / −20; sair no meio conta derrota |
| Todos contra Todos e 2v2 | 2 clientes | kill conta, respawn longe, placar por time |
| Loja | remote real da loja | moedas, Robux simulado, pacote, passe, recusas |
| Desempenho | Studio, lobby e partida | 60 fps estáveis no cliente e no servidor |

**Não dá para testar sem publicar:** compra real com Robux, save no DataStore, teleporte entre places,
fila entre servidores e controles de celular/console em aparelho real.
