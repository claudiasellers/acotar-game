# Market contract (lane L53, story/market)

How Feyre sells things in the human village, and how other lanes reach it.

## Data

- `data/market/market.tres` (`MarketSet`), built by `tools/market/gen_market.gd` from the
  village scatter (`world/human_realm/village/scatter/goods_*.tres`). Re-run it after the
  village generator moves stalls; `tests/unit/market/test_market.gd` fails if a stall has no trade.
- `MarketStall`: `trade`, `display_name`, `canon`, `sign_path`, `position`, `yaw` (the stall's
  own transform, +Z = front), `buyer` (a `MarketBuyer` or null).
- `MarketBuyer`: `id`, `display_name`, `canon`, `buys` (item ids), `buys_tags` (ingredient
  craft tags), `refuses`, `price_factor`, `greeting` / `thanks` / `nothing` lines.
  Price = `base_price × price_factor`, at least 1 copper. Coin only, no barter (Keeper, ch 3).

| Trade | Stall | Buys | Factor | Canon |
|---|---|---|---|---|
| mercenary | none: the lip of the square's well (CastPresence spot `mercenary_well`) | wolf pelt, doe hide | 1.5 | C (price X) |
| cobbler | the goods_pelts stall = `act1_fur_stall` (Act I's `FurStall`) | hides, hare pelt, sinew | 0.6 | C |
| clothier | square goods_furs stall | hides, hare pelt | 0.6 | C |
| spice | square goods_salt stall (hot food and spice) | game, honey, garlic, juniper, salt | 0.8 | stall C, buying X |
| charms | square goods_iron stall (charms and bits of iron) | herbs and odd finds by tag | 1.0 | stall C, buying X |

Grain, bread, roots, wool, tinker and salt stalls have signs but buy nothing from Feyre.

## Runtime

- `MarketDressing` (added by `act1_game.gd`): trade signs, buyer `MarketStation`s, the
  fingerpost at the cottage fork. No glow, pulse or floating marker (R2).
- `MarketStation` (group `station` + `market_station`): `use()` opens the sell screen.
- `MarketMenu.open_for(tree, buyer, speaker := null) -> MarketMenu`: the sell screen
  (SatchelTheme, L50 crafted look). It pauses the tree while open. `sold(item_id, count, coin)`.
  Every sale goes through `Inventory.sell` → `EventBus.item_sold`, so `PeltSale` raises
  `pelt_sold` whoever buys the pelt.
- `FurStall` (L01): with the wolf pelt, E sells it directly at base price (unchanged, the L08
  chain beat); without it, E opens the cobbler's screen when Feyre carries something he takes.
- `MarketThoughts`: Feyre's walk lines (Keeper, [A]) on the GuideJournal card while she carries
  the pelt; never on top of a DialogueDirector caption.
- `MarketPrompt`: "E  Trade with …" within 2.5 m of a buyer.
