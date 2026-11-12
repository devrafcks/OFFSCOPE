# Produtos para criar no Dashboard

> Eu (Claude) **não invento IDs**. Crie cada item abaixo como **Developer Product** no Creator Hub
> (Experiência → Monetização → Developer Products), com o **nome e o preço exatos**, e cole o ID no
> campo `ProductId` do item correspondente em [`src/shared/Config.luau`](../src/shared/Config.luau).
>
> Enquanto um ID for `0`, o botão de Robux **simula a compra no Studio** (`Config.Studio.SimulateRobuxPurchases`)
> e, fora do Studio, mostra "Produto ainda não configurado". Moedas funcionam sempre.

## Pacotes

| Chave no Config | Nome do produto | Preço (R$) |
|---|---|---:|
| `Config.Pass.PrimeProductId` | Passe Prime — Temporada 1 | 199 |
| `Config.StarterPack.ProductId` | Pacote Iniciante | 49 |

> O Prime é um **Developer Product por temporada** (não um Game Pass): ele vale para a temporada
> gravada no perfil e a próxima temporada ganha um produto novo — passe de batalha "zera", passe de jogo não.

## Cosméticos (um produto por item)

| Id | Nome | Categoria | Raridade | Pool | R$ | Moedas |
|---|---|---|---|---|---:|---:|
| `wrap_areia` | Areia | Wrap | Common | catalog | 15 | 500 |
| `wrap_grafite` | Grafite | Wrap | Common | catalog | 15 | 500 |
| `wrap_oliva` | Oliva | Wrap | Common | catalog | 15 | 500 |
| `wrap_artico` | Ártico | Wrap | Common | catalog | 15 | 500 |
| `wrap_floresta` | Floresta | Wrap | Uncommon | catalog | 29 | 1.000 |
| `wrap_urbano` | Urbano | Wrap | Uncommon | catalog | 29 | 1.000 |
| `wrap_deserto` | Deserto Digital | Wrap | Uncommon | daily | 29 | 1.000 |
| `wrap_tundra` | Tundra | Wrap | Uncommon | daily | 29 | 1.000 |
| `wrap_carbono` | Fibra de Carbono | Wrap | Rare | daily | 49 | 1.800 |
| `wrap_hex` | Colmeia | Wrap | Rare | daily | 49 | 1.800 |
| `wrap_marmore` | Mármore Negro | Wrap | Rare | daily | 49 | 1.800 |
| `wrap_pulso` | Pulso | Wrap | Epic | daily | 79 | 3.000 |
| `wrap_magma` | Magma | Wrap | Epic | daily | 79 | 3.000 |
| `wrap_estatica` | Estática | Wrap | Epic | daily | 79 | 3.000 |
| `wrap_aurora` | Aurora Austral | Wrap | Legendary | pass | 149 | 5.000 |
| `charm_dado` | Dado da Sorte | Charm | Common | catalog | 15 | 500 |
| `charm_cartucho` | Cartucho | Charm | Uncommon | pass | 29 | 1.000 |
| `charm_placa` | Placa de Identificação | Charm | Rare | daily | 49 | 1.800 |
| `charm_cubo` | Cubo Neon | Charm | Epic | daily | 79 | 3.000 |
| `knife_carbono` | Carbono | Knife | Uncommon | daily | 29 | 1.000 |
| `knife_tanto` | Tanto Laqueado | Knife | Rare | daily | 49 | 1.800 |
| `knife_neon` | Lâmina de Plasma | Knife | Epic | daily | 79 | 3.000 |
| `fx_faisca` | Faíscas | KillEffect | Rare | daily | 49 | 1.800 |
| `fx_papel` | Confete | KillEffect | Rare | pass | 49 | 1.800 |
| `fx_fumaca` | Cortina de Fumaça | KillEffect | Rare | daily | 49 | 1.800 |
| `fx_glitch` | Glitch | KillEffect | Epic | daily | 79 | 3.000 |
| `finisher_corte` | Corte Lunar | Finisher | Epic | pass | 79 | 3.000 |
| `ret_ciano` | Ponto Ciano | Reticle | Common | catalog | 15 | 500 |
| `ret_magenta` | Ponto Magenta | Reticle | Common | catalog | 15 | 500 |
| `ret_cruz` | Cruz Fina | Reticle | Rare | daily | 49 | 1.800 |
| `tracer_ouro` | Ouro | Tracer | Common | catalog | 15 | 500 |
| `tracer_plasma` | Plasma | Tracer | Rare | daily | 49 | 1.800 |

Pools: `catalog` = sempre à venda · `daily` = só quando aparece na loja do dia · `pass` = recompensa do passe
(as lendárias do passe também podem ser compradas).

## Checklist depois de colar os IDs

1. `Config.Places.Lobby` e `Config.Places.Match` com os PlaceIds publicados.
2. Match place: *Access Control → teleports seguros dentro do universo*.
3. Testar uma compra real de 1 item barato e conferir o `PurchaseIdCache` no perfil (ProfileStore).
4. Content Ratings honestos (violência leve, sem gore).
