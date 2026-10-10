# Technical decisions, logic and gas — Module 13
> Versión en español: [decisiones-tecnicas-ES.md](./decisiones-tecnicas-ES.md)

A reading guide to understand **why** the project is built this way, **what flow** a price follows until it reaches the protocol, and **where** gas (the unit of execution cost on Ethereum) can still be saved.

Complements: [`GAS-EN.md`](./GAS-EN.md) · [`flujograma-EN.md`](./flujograma-EN.md) · [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) (audit based on the *Smart Contract Weakness Classification* (SWC), a classification of smart contract weaknesses).

---

## 1. What problem it solves

Decentralized Finance (DeFi) protocols cannot blindly “trust” a price already published on the chain (on-chain):

| Risk | Defense in this module |
|--------|------------------------|
| Old price (staleness / expiry) | `maxDelay` / `maxAge` + `StalePriceFeed` error |
| Incomplete round (Chainlink) | `answeredInRound >= roundId` |
| Zero / negative price / sudden drop (*flash crash*) | `answer > 0` + `minAnswer` / `maxAnswer` |
| Pull model without paying the fee / Ether stuck in the contract | `InsufficientFee` + refund of the excess |
| Different decimals (8 vs 18) | `PriceScalerLib` only in the consumer |

The module is not “another Chainlink”: it is a **secure consumption layer** on top of the Push model (data is pushed; Chainlink) and the Pull model (data is pulled / fetched on demand; Pyth).

---

## 2. Technical decisions (and why)

### 2.1 Two architectures, one facade

| Decision | Discarded alternative | Reason |
|----------|------------------------|--------|
| Separate `ChainlinkPriceFeed` and `PythPriceFeed` | A single “generic oracle” contract | Push is read-only (`view`); Pull is `payable` (accepts Ether) + writes. Mixing them obscures the Checks-Effects-Interactions (CEI) pattern (check → effects → external interactions) and fee handling. |
| `PriceOracleConsumer` as a facade | Each decentralized application talking directly to the feeds | Stable usage interface (`getPush*` / `getPull*`), scaling to 18 decimals, a single wiring point. |
| Both feeds implement `IPriceFeed` | Different interfaces with nothing in common | `getValidatedPrice()` + `decimals()` unify reading data already on-chain. Pull adds `updateAndGetPrice`. |

### 2.2 Validation centralized in a *library*

`OracleValidationLib` concentrates:

1. Complete round (Push only)
2. Data freshness (`updatedAt` / `publishTime`)
3. Price strictly greater than zero
4. Allowed bounds `[minAnswer, maxAnswer]`

**Why a library and not modifiers in each feed:** Push/Pull reuse, the compiler optimizer can insert the code inline (*inlining*), and the security rules can be tested without deploying the feeds.

### 2.3 Immutable configuration (no *setter* functions)

`aggregator`, `pyth`, `priceId`, maximum delays, price bounds and decimals (Pyth) are `immutable` (fixed at deployment).

| Advantages | Accepted drawbacks |
|----------|-------------------|
| Zero configuration storage reads (`SLOAD`, *storage load*) in the critical path | Tweaking parameters = redeploying |
| No governance / no admin key in version 1 | No on-chain “pause oracle” |

Aligned with the module scope (consumer + validation, not a Decentralized Autonomous Organization).

### 2.4 Push vs Pull: data model

```text
PUSH — data is pushed (Chainlink)
  Off-chain network → writes rounds to AggregatorV3
  On-chain consumer → only READS latestRoundData + validates
  Cost: ~view read + validation (~20 000 gas in the reference snapshot)

PULL — data is pulled / fetched on demand (Pyth)
  Off-chain: you obtain signed priceUpdateData
  On-chain: you PAY the fee → updatePriceFeeds → you READ → you validate
  Cost: write + cryptographic verification (~170 000 gas in the snapshot)
```

**Decision:** do not invent a “cheap read-only Pull”. Without `updatePriceFeeds`, Pyth's state may be stale; the provider's model requires a fresh update when freshness matters.

### 2.5 Exact fee in the consumer

In `PriceOracleConsumer._pull`:

1. `fee = pullFeed.getUpdateFee(updateData)` (update fee)
2. **Exactly** that fee is sent to `updateAndGetPrice`
3. The excess `msg.value - fee` is refunded to the **caller** (it does not stay in the consumer)

**Why:** it avoids an extra internal refund on the consumer → feed path (fewer call hops). The feed can still refund Ether if someone calls it directly and overpays.

### 2.6 Scaling to 18 decimals only in the consumer

Feeds report the provider's **native decimals** (typically 8).  
`to18Decimals` lives in `getPushPriceScaled18` / `getPullPriceScaled18`.

**Why:** not to distort what the oracle reports; the protocol chooses whether it needs `1e18` units for decentralized finance arithmetic.

### 2.7 Custom errors + Solidity 0.8.24

- `StalePriceFeed`, `InvalidOraclePrice`, `OracleRoundIncomplete`, `InsufficientFee`, etc.
- Pinned compiler version `0.8.24` (course suite).
- Foundry: unit tests + fuzzing (random inputs) + fork (mainnet replica) + gas measurement + weaknesses documented according to the *Smart Contract Weakness Classification*.

### 2.8 Test doubles (*mocks*) and dependencies

| Piece | Role |
|-------|-----|
| `MockAggregatorV3` | Control round / answer / timestamp in tests |
| `MockPyth` | Wrapper around the Pyth software development kit + helpers to build the payload |
| Chainlink contracts (brownie) + Pyth development kit | Real interfaces, not reinvented |

---

## 3. Logic the system follows

### 3.1 Layers (from outside in)

```text
Protocol / decentralized application
    → PriceOracleConsumer          (facade + scaling + exact fee)
        → ChainlinkPriceFeed       (Push — data is pushed)
            → AggregatorV3         (Chainlink / test double)
            → OracleValidationLib
        → PythPriceFeed            (Pull — fetched on demand)
            → IPyth                (Pyth / test double)
            → OracleValidationLib
        → PriceScalerLib           (*Scaled18* functions only)
```

### 3.2 Push flow (read)

```text
getPushPrice()
  → pushFeed.getValidatedPrice()
      → aggregator.latestRoundData()
      → validateAggregatorRound(
            complete round,
            freshness ≤ maxDelay,
            answer > 0,
            minimum ≤ answer ≤ maximum
        )
  → return answer   // or *Scaled18 via PriceScalerLib
```

If any check fails → the transaction reverts with a custom error (fail closed: when in doubt, reject).

### 3.3 Pull flow (update + read)

```text
Off-chain: Hermes / query interface → bytes[] updateData

getPullPrice{value: msg.value}(updateData)
  → fee = getUpdateFee(updateData)
  → require msg.value >= fee
  → pullFeed.updateAndGetPrice{value: fee}(updateData)
        → pyth.updatePriceFeeds{value: fee}(updateData)
        → getPriceUnsafe(priceId)
        → validatePullPrice(publishTime, maxAge, bounds…)
        → (if the feed was overpaid) refund to the feed's msg.sender
  → refund (msg.value - fee) to the original caller
  → return price   // or *Scaled18
```

Intentional order: **fee → update (external interaction) → validate → refund excess**, following the Checks-Effects-Interactions pattern applied to the leftover Ether.

### 3.4 Validation rules (core)

| Check | Push | Pull | Error |
|--------------|------|------|-------|
| Complete round | `answeredInRound >= roundId` | not applicable | `OracleRoundIncomplete` |
| Zero / future timestamp | yes | yes (`publishTime`) | `StalePriceFeed` |
| Age greater than the threshold | `maxDelay` | `maxAge` | `StalePriceFeed` |
| `answer <= 0` | yes | yes | `InvalidOraclePrice` |
| Out of bounds | yes | yes | `InvalidOraclePrice` |

### 3.5 Deployment mental model

`Deploy.s.sol` wires:

1. Real aggregator **or** `MockAggregatorV3` with a seed price
2. Real Pyth **or** `MockPyth`
3. `ChainlinkPriceFeed` + `PythPriceFeed` (delays and bounds via environment variables)
4. `PriceOracleConsumer(push, pull)`

No admin afterwards: the “configuration” is the bytecode plus the immutable values.

---

## 4. Can the existing gas usage be improved?

Yes. What is already applied and what is optional (tradeoffs).

### 4.1 Already applied (baseline)

| Technique | Effect |
|---------|--------|
| Immutable configuration values | Avoids a storage read on every price read |
| Library + `optimizer_runs = 10_000` + `via_ir` (compilation through the intermediate representation) | Inline validation |
| Custom errors | Cheaper than `require("text…")` |
| Exact fee from the consumer | Fewer nested refunds |
| `calldata` for `updateData` | Fewer copies to memory |

Approximate numbers (see [`GAS-EN.md`](./GAS-EN.md)):

| Path | Gas |
|--------|-----|
| Raw `latestRoundData` read | ~16 173 |
| Validated Push | ~19 849 |
| Consumer Push / Scaled18 | ~22 816 / ~24 756 |
| Pull update + validate | ~169 786 |
| Consumer Pull | ~166 531 |

**Magnitude conclusion:** the Push overhead (~+4 000 gas over the raw read) is the price of security. The Pull cost (~10 times more) is dominated by **Pyth's `updatePriceFeeds`**, not by your wrapper.

### 4.2 Possible improvements (not done in version 1)

Ordered from most realistic to most aggressive:

| Improvement | Expected savings | Tradeoff |
|--------|-----------------|------------|
| **Cache the aggregator's `decimals()`** as an immutable in `ChainlinkPriceFeed` | ~2 000–5 000 gas on the `*Scaled18` path (avoids an external call) | Redeploy if the feed changes decimals (rare) |
| **Merge consumer + Push feed** into a single contract | ~2 000–4 000 gas (one less call hop) | You lose modularity / reusing the feed on its own |
| **Pyth's `getPriceNoOlderThan`** instead of `getPriceUnsafe` + your own freshness validation | Possibly less duplicated logic; similar or slightly different gas | Tighter coupling to Pyth's interface; price bounds remain yours |
| **Skip the refund when `msg.value == fee`** (already almost free: `if (refund > 0)`) | Already optimal on the happy path with exact payment | — |
| **Assembly / unchecked** in `PriceScalerLib` | Marginal (hundreds of gas) | Readability / risk; overflow is already bounded by the limits |
| **Do not scale on-chain** (the protocol scales outside that path) | Saves the Scaled18 arithmetic | Every integrator reimplements it |
| **Batch update** of several `priceId`s in one transaction | Amortizes Pyth's fixed fee | Outside the scope of a single feed in version 1 |
| **Read Pyth without updating** (`getValidatedPrice` only) | Very cheap compared to updating | Only valid if another transaction recently updated the feed |

### 4.3 What is not worth “optimizing”

- **Removing bounds / staleness checks** → small savings, big risk (weaknesses from the *Smart Contract Weakness Classification* / price exploits).
- **Trying to make Pull cost as much as Push** → impossible without dropping `updatePriceFeeds`.
- **Mutable configuration storage “to avoid redeploying”** → worsens gas on the critical path and opens an admin attack surface.

### 4.4 Practical heuristic

```text
Do you need guaranteed freshness in this transaction?
  YES + recent Chainlink Push → getPushPrice / Scaled18
  YES + Pyth → pay for the update (~170 000 gas) knowingly
  NO (another keeper / maintainer already updated Pyth)
       → getValidatedPrice() in view mode on PythPriceFeed
```

---

## 5. Executive summary

1. **Architecture:** Push/Pull wrappers + consumer + validation/scaling libraries; immutable configuration; fail closed with custom errors.
2. **Logic:** Push = read and validate; Pull = fee → update → validate → refund excess; optional scaling to 18 decimals in the facade.
3. **Gas:** Push is already close to the safe optimum; Pull is bounded by the provider. Realistic improvements for a version 2: decimals caching, fewer call hops, or a Pull read without updating when the data is already fresh.

---

## 6. Quick file map

| File | Responsibility |
|---------|-----------------|
| `src/consumer/PriceOracleConsumer.sol` | Interface toward the protocol, exact fee, scaling to 18 |
| `src/feeds/ChainlinkPriceFeed.sol` | Push + validation |
| `src/feeds/PythPriceFeed.sol` | Pull: update + validate + refund excess |
| `src/libraries/OracleValidationLib.sol` | Shared security rules |
| `src/libraries/PriceScalerLib.sol` | Normalization to 18 decimals |
| `src/interfaces/IPriceFeed.sol` | Common read contract |
| `src/errors/OracleErrors.sol` | Custom errors |
| `test/gas/Oracle.gas.t.sol` | Measurable gas baseline |

Documentation index: [`README-EN.md`](./README-EN.md)
