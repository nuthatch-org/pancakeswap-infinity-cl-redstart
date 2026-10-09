# pancakeswap-infinity-cl-redstart

A [Redstart](https://github.com/nuthatch-org/redstart) port of the **PancakeSwap
Infinity CL** subgraph, written because the deployed original has been dark since
2026-08-02 and the reason it went dark is a single character.

Redstart unifies `schema.graphql`, `subgraph.yaml` and the AssemblyScript
mappings into one typed source, and transpiles back out to all three. The
canonical `graph build` compiles the output unmodified, so this is an ordinary
subgraph that happens to have been written in a language where the bug below
does not compile.

---

## The bug this port exists to make impossible

The published subgraph is `8jFYxwKP8tNGSDisucpHRK1ojUchZd7ELd8zh2ugHGDN`,
deployment `QmVjXU7yQNyyLphPGqoz8iBzqu5YXphooFJn15JqZ6ZMFz`, source at
[NgoKimPhu/infinity-cl-subgraph](https://github.com/NgoKimPhu/infinity-cl-subgraph).
Since 2026-08-02 every entity query through the gateway has returned:

```
bad indexers: {0xf92f430d…: BadResponse(no attestation: indexing_error)}
```

The cause is one deterministic `nonFatalError` at BSC block **113,581,822**:

```
Mapping aborted at src/mappings/swap.ts:39: unexpected null  (handler: handleSwap)
```

Line 39 is:

```ts
const pool = Pool.load(poolId)!
```

A `Swap` arrived for a pool with no `Pool` entity. The non-null assertion aborted
the handler. graph-node recorded the error and carried on indexing to chain head,
so the deployment reports `synced: true` and is completely current, but
`health: unhealthy` makes every response unattestable and the gateway will not
serve it. The data is there and unreachable. Because the fault is deterministic,
more indexers and more signal cannot help; only a publisher republish under the
same subgraph ID fixes it.

Two details make this worse than bad luck. First, the same file guards the very
next two loads correctly, ten lines below the fault:

```ts
const token0 = Token.load(pool.token0)
const token1 = Token.load(pool.token1)

if (token0 && token1) {
```

Second, the sibling handler in the same repository already does it right.
`src/mappings/modifyLiquidity.ts:31-42`:

```ts
const pool = Pool.load(poolId)
const poolManager = PoolManager.load(poolManagerAddress)

if (pool === null) {
  log.debug('handleModifyLiquidityHelper: pool not found {}', [poolId])
  return
}
```

The author knew. The language simply did not require them to be consistent about
it, and `graph build` was perfectly happy either way.

### What Redstart does about it

There is no `null` in Redstart and no `!` operator to write. `load` returns
`Option<T>` and the checker rejects a dereference that has not been matched, so
the line above is not a bug you avoid, it is a program that does not compile.
The equivalent in `src/pool_manager.red`:

```redstart
match Pool.load(poolId) {
  None => {
    log.debug("handleSwap: pool not found {}", [poolId])
    return
  }
  Some(pool) => {
    // …
  }
}
```

The same applies to contract calls, which return `Result<T, _>` and must be
matched, so the reverted-call abort is unrepresentable too. `src/tokens.red` is
where that shows.

---

## What it indexes

**Chain:** `bsc`. Two static contracts, no factory, no templates. Infinity is a
singleton architecture, so there are no per-pool contracts to discover.

| source | address | start block | events |
|---|---|---|---|
| `PoolManager` | `0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b` | 47,214,308 | `Initialize`, `ModifyLiquidity`, `Swap` |
| `PositionManager` | `0x55f4c8abA71A1e923edC303eb4fEfF14608cC226` | 47,215,015 | `Subscription`, `Unsubscription`, `Transfer` |

**17 entities**, unchanged from the original `schema.graphql`: `PoolManager`,
`Bundle`, `Token`, `Pool`, `Tick`, `Transaction`, `Swap`, `ModifyLiquidity`,
`UniswapDayData`, `PoolDayData`, `PoolHourData`, `TokenDayData`, `TokenHourData`,
`Position`, `Subscribe`, `Unsubscribe`, `Transfer`.

The full derived surface is ported, not just the raw events: USD pricing through
the whitelist-pool graph, tracked versus untracked volume, TVL, tick entities with
their `liquidityGross`/`liquidityNet` bookkeeping, the Uniswap v3 SDK liquidity
maths (`TickMath`, `SqrtPriceMath`, `FullMath`), and the day and hour OHLC
rollups.

---

## Layout

```
src/
  main.red             mods, ABIs, the two source blocks
  schema.red           17 entity declarations         (schema.graphql)
  config.red           the BSC chain config           (utils/chains.ts, BSC branch)
  math.red             constants and numeric helpers  (utils/index.ts, constants.ts, id.ts, tick.ts)
  tokens.red           ERC-20 metadata by contract call (utils/token.ts)
  pricing.red          the USD pricing graph          (utils/pricing.ts)
  intervals.red        day and hour rollups           (utils/intervalUpdates.ts)
  liquidity_math.red   Uniswap v3 SDK maths           (utils/liquidityMath/*.ts)
  pool_manager.red     Initialize, ModifyLiquidity, Swap
  position_manager.red Subscription, Unsubscription, Transfer
  tests.red            20 native tests
```

**1,706 lines of Redstart plus 161 lines of tests**, against the original's 2,097
lines of AssemblyScript, 496-line `schema.graphql`, 67-line `subgraph.yaml` and
1,870 lines of Matchstick tests. It emits a 276-line `schema.graphql`, a 100-line
`subgraph.yaml` and a 1,286-line `mappings.ts`, which `graph build` compiles to an
87,726-byte WASM module.

---

## Running it

```sh
redstart check     # parse and type-check the .red sources
redstart test      # 20 native tests, no WASM, no Docker, no Matchstick
redstart build     # emit schema.graphql + subgraph.yaml + mappings.ts into build/
redstart verify    # …and prove the output compiles: graph codegen + graph build
redstart fmt       # canonical formatting
```

`build/` is generated output. It is gitignored, it is not the source, and the next
build overwrites it.

**Deploying:**

```sh
redstart deploy <subgraph-name> --dry-run    # build + codegen + graph build, then stop
redstart deploy <subgraph-name>              # …and graph deploy
```

Deploying needs a Subgraph Studio deploy key; nothing in this repository carries
one. To republish under the existing subgraph ID, that has to come from the
publisher (`0x29ff…100662`). Deploying under a new ID works for anyone, and a
graft can carry the existing history across.

---

## Grafting

The manifest declares a graft onto the deployment this port replaces:

```
features:
  - grafting
graft:
  base: QmVjXU7yQNyyLphPGqoz8iBzqu5YXphooFJn15JqZ6ZMFz
  block: 113581821
```

113,581,821 is the block before the original's first deterministic abort. Grafting
there inherits roughly 66 million blocks of already-indexed history and leaves
about 4.6 million to catch up, instead of indexing BSC from 47,214,308.

**This cannot be deployed to Subgraph Studio.** Grafting copies the base's entity
store, so the node performing it must already hold that deployment, and Studio's
graph-node holds only what is deployed to Studio. Attempting it fails at
validation:

```
subgraph validation error: [the graft base is invalid:
  deployment not found: QmVjXU7yQNyyLphPGqoz8iBzqu5YXphooFJn15JqZ6ZMFz]
```

### If you hold the base

Only a node already indexing `QmVjXU7yQNyyLphPGqoz8iBzqu5YXphooFJn15JqZ6ZMFz` can
graft onto it — in practice, an indexer that was serving the original. If that is
you, this is the whole recipe:

```sh
git clone https://github.com/nuthatch-org/pancakeswap-infinity-cl-redstart
cd pancakeswap-infinity-cl-redstart
redstart verify                       # proves it compiles, no deploy
redstart deploy <name> --node http://<your-graph-node>:8020/
```

It inherits history to 113,581,821 and catches up ~4.6M blocks instead of ~71M.
Nothing else needs changing; the `graft` block is already in `src/main.red`.

### If you do not

Delete the `graft` block from `src/main.red` and index from scratch. That is what
the published deployment does — about three days on BSC from block 47,214,308,
measured at ~267 blocks/sec.

**Published:** subgraph `FBw4VNzH2FR3Q7xTfSW1XiCfpDCXXffPNQ1xa9hJSGxo`,
deployment `QmbG7eTZXvaDNraEL1GTJXDsiGCC7czW4vSGgsv4vSRut3`. That build has no
graft; it is this repository with the `graft` block removed.

### Schema compatibility

Grafting requires the schema to be compatible with the base, which drove two
decisions in `src/schema.red`:

- **Ids are `Id<ID>`**, rendering `id: ID!`. `Id<String>` renders `String!`, which
  graph-node accepts on its own but which no conventional subgraph declares, so
  it would fail the compatibility check.
- **Five entities are declared `mutable`.** `Swap`, `ModifyLiquidity`,
  `Subscribe`, `Unsubscribe` and `Transfer` are append-only, so Redstart's
  optimiser would infer `@entity(immutable: true)` for them. That changes
  graph-node's storage layout, and the base declares all five
  `@entity(immutable: false)`.

Diffing the emitted `schema.graphql` against the base leaves **five** differences,
all of them element nullability on `@derivedFrom` fields on `Transaction`
(`[Swap]!` in the base, `[Swap!]!` here). Redstart has no syntax for a nullable
list element, and whether graph-node's graft check cares is not something that
can be established locally: only graph-node validates graft compatibility, at
deploy time, against a node holding the base. Treat the graft as untested.

## Tests

`redstart test` runs natively against a mock store. The suite is 20 tests, and the
first two are the point of the whole exercise:

```
✓ REGRESSION: a swap on a pool that was never initialised does not abort
✓ REGRESSION: modify liquidity on a pool that was never initialised does not abort
```

Both fire the exact shape that killed the deployment - an event carrying pool id
`0x8e1c2870ae3c352d2a80be33c7c408d993f7d07e6d63d2983e3270b35a3dbc78`, the pool
Ellipfra identified as having been initialised before it was created on-chain.
Neither is a vacuous "it didn't throw" test: both assert with `assertMissing` that
the handler wrote **nothing**, so a handler that half-built a `Swap` or a `Tick`
before failing would still red. `assertMissing` was itself mutation-checked
against an entity that does exist, to confirm it can fail.

The rest cover the position lifecycle, id derivation from transaction hash and log
index, and the numeric helpers: `safeDiv` on a zero denominator, `hexToBigInt`
with and without the `0x` prefix, `fastExponentiation` across zero/one/even/odd/
negative powers, `getSqrtRatioAtTick` returning exactly Q96 at tick zero and being
monotonic across it, `mulDivRoundingUp` rounding only on a remainder, and the
`getAmount0`/`getAmount1` range boundaries.

---

## Deliberate divergences from the original

Each of these is a decision, not an accident, and each is commented at the site.

- **BSC only.** The original's `utils/chains.ts` is a 586-line `if`/`else` over
  every supported network. A Redstart manifest carries one network per `source`
  block, so the branch collapses into `config.red`. Porting to another network
  means changing those values, not adding a branch.
- **`getSqrtRatioAtTick` does not throw.** The original raises `new Error('TICK')`
  on an out-of-range tick. Throwing *is* a deterministic mapping abort, which is
  the disease this port exists to treat. The PoolManager enforces the range
  on-chain so the branch is unreachable; it clamps and logs a warning instead.
- **Interval helpers take the entity, not its id.** The original's
  `updatePoolDayData` and friends open with `Pool.load(poolId)!` and
  `PoolManager.load(poolManagerAddress)!` - re-loading, by id, entities the caller
  already holds. Passing the entity removes three more non-null assertions
  outright rather than converting them.
- **Two named price helpers instead of a positional pair.**
  `sqrtPriceX96ToTokenPrices` returns a two-element `BigDecimal[]` that callers
  index by position. Redstart writes arrays as literals, and
  `token0PriceFrom`/`token1PriceFrom` are clearer anyway. Same arithmetic, same
  order of operations.
- **Bit tests are arithmetic.** `absTick & 0x1` becomes `bitSet(absTick, 1)`,
  which is `(v / bit) % 2 == 1` - exact for a non-negative `Int`.
- **`tokenOverrides` and `poolsToSkip` are omitted.** BSC's config declares both
  empty, so the code paths that consumed them never fire on this network.
- **`fetchTokenDecimals` returns `Option<BigInt>`.** The original returns
  `BigInt | null` and its caller chooses to bail. Here the bail is compulsory.
- **Five entities became immutable.** Redstart's optimising compiler infers
  `@entity(immutable: true)` for `Swap`, `ModifyLiquidity`, `Subscribe`,
  `Unsubscribe` and `Transfer` - all append-only in every handler - and sets
  `indexerHints: prune: auto`. The original declares all seventeen mutable. This
  changes storage, not the queryable API.

### Accepted warnings

`redstart check` reports three `W040`s: entity ids that stringify an address or a
hash via `.toHexString()` where `Id<Bytes>` would index about 28% faster and use
about 48% less disk. They are accepted deliberately. Changing an id changes entity
identity, and these ids are queried by existing consumers. `redstart explain W040`
sets out the trade.

### Not claimed

Nothing here reads a transaction receipt, because Redstart does not expose one and
the original does not need one. `Transaction.gasUsed` is zero, exactly as in the
original, and for the same reason - it lives on the receipt.

---

## Compiler bugs this port found

Porting a real subgraph rather than an example turned up six defects in Redstart
itself, all now fixed with regression tests upstream. Three were codegen bugs of
precisely the class the porting guide asks to be reported - `redstart check`
passed, and only `graph build` rejected the output:

1. **`Some(x)` was emitted as a function call.** An `Option<T>` lowers to graph-ts's
   `T | null`, so `Some` is the identity, but it fell through to the generic call
   path and produced a reference to an undefined `Some`.
2. **Matching an `Option` emitted a loose `!= null`.** graph-ts gives `BigInt`,
   `BigDecimal`, `Bytes` and `Address` an `@operator('!=')`, so comparing one to
   `null` sends the AssemblyScript compiler into `compileBinaryOverload`, where it
   fails an internal assertion and crashes the entire build with no line number.
   Strict `!==` skips overload resolution and is the right test for a nullable
   reference anyway.
3. **`Entity.create(…)` only lowered in `let` position.** As a bare statement or in
   a `return`, it emitted `Entity.create(id, /* record */)` - a static graph-ts has
   no such thing as, with the record literal replaced by a comment. Fixing it
   needed a guard, because `<Template>.create(addr)` is a data-source spawn and in
   statement position the two shapes are textually identical.

The other three were gaps in the native test runner, which meant code that
`verify` compiles could not be tested at all: no `log` namespace, a mock
transaction carrying only `hash` (the porting guide documents `.from`, `.to`,
`.value` and `.gasPrice`), and no `BigInt`/`BigDecimal` static constructors, no
`pow`/`mod`/shifts/comparisons, no `BigDecimal` arithmetic and no string methods.
A subgraph doing real arithmetic was untestable. `assertMissing` was added at the
same time, because "this handler bails cleanly" needs an assertion or it is not a
test.

Also worth knowing, and not yet fixed: **`redstart check` does not catch a call to
an undefined function.** A project calling six helpers that do not exist reports
`no errors`. `check` proves parse and types; `verify` is the gate.

---

## Licence

**GPL-3.0**, and not by choice.

This is a line-by-line translation of
[NgoKimPhu/infinity-cl-subgraph](https://github.com/NgoKimPhu/infinity-cl-subgraph),
which is a fork of [Uniswap/v4-subgraph](https://github.com/Uniswap/v4-subgraph).
Both are **GPL-3.0**. Translating a work into another language produces a
derivative work, and the entity schema, the algorithms, the control flow and much
of the commentary here are deliberately faithful to the original, so this
repository inherits GPL-3.0 and carries it forward.

Redstart itself is MIT and is unaffected: a compiler does not take the licence of
what it compiles. The constraint applies to this port only.
