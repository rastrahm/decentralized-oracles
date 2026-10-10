# Planning — Module 13: Decentralized Oracles & Pyth/Chainlink Push-Pull

> Versión en español: [planificacion-ES.md](./planificacion-ES.md)

**Status:** Phases **0–6** ✅ completed. Module closed at the v1 planning level.  
**Progression rule:** each phase requires **explicit authorization** from the owner before it starts.

---

## 1. Objective

Build our own resilient price consumer and mock aggregator that support:

- **Push** — Chainlink `AggregatorV3Interface` (price already on-chain; the consumer only reads).
- **Pull** — Pyth `IPyth` / on-demand update with cryptographic verification of the payload and payment of `getUpdateFee()`.
- Strict validation of **staleness**, **incomplete rounds**, and **bounds** (`minAnswer` / `maxAnswer`).
- Stack: **Foundry + Solidity `0.8.24`** (fixed pragma).

---

## 2. Scope

| Included | Excluded (v1) |
|----------|----------------|
| Unified Push/Pull consumer, AggregatorV3 mocks, Chainlink/Pyth wrappers, errors, unit/fork/fuzz tests | Multi-oracle aggregator with complex weighted consensus |
| Staleness + round completeness + min/max bounds | Custom oracles with reporter staking |
| Pyth fee (`getUpdateFee`) + `updatePriceFeeds` before reading | Price frontend / dashboard |
| Mainnet fork tests (real Chainlink feeds) | Specific Layer 2 (L2) networks beyond what is documented in deploy |
| Module custom errors | RedStone / API3 / other vendors (post-v1) |

---

## 3. Stack and technical constraints

### Suite (`evm-smart-contracts-suite`)

- **Exact** Solidity `0.8.24`.
- OpenZeppelin Contracts v5.x available (v1 does not use Ownable; config is **immutable**).
- Foundry: unit + fuzz (`runs >= 1000`) + fork tests + gas reports.
- Custom errors (no `require` with strings).
- Checks-Effects-Interactions (CEI) in Pull paths (fee → update → validate → refund).
- Ethereum Natural Language Specification Format (NatSpec) on every public/external API.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.

### Module 13 (Oracles) — implemented

- Push: `latestRoundData()`; reject if `answeredInRound < roundId`, `updatedAt == 0`/in the future, or stale.
- Bounds: price ≤ 0 or outside `[minAnswer, maxAnswer]` → `InvalidOraclePrice`.
- Pull: `getUpdateFee` → `updatePriceFeeds{value: fee}` → `getPriceUnsafe` + `validatePullPrice`.
- Insufficient fee → `InsufficientFee`; failed refund → `EthTransferFailed`.
- 8 → 18 scaling in `PriceScalerLib` via the consumer (`*Scaled18`).
- Chainlink/Pyth: remappings (`lib/` + `node_modules/`), no local copies of vendor interfaces.

---

## 4. Architecture (final v1)

```
13-decentralized-oracles/
├── README.md
├── doc/
│   ├── README.md
│   ├── planificacion.md
│   ├── diagrama-de-clases.md
│   ├── diagrama-de-flujo.md
│   ├── flujograma.md
│   ├── SWC-AUDIT.md
│   └── GAS.md
├── src/
│   ├── consumer/PriceOracleConsumer.sol
│   ├── feeds/
│   │   ├── ChainlinkPriceFeed.sol
│   │   └── PythPriceFeed.sol
│   ├── mocks/
│   │   ├── MockAggregatorV3.sol
│   │   └── MockPyth.sol
│   ├── libraries/
│   │   ├── OracleValidationLib.sol
│   │   └── PriceScalerLib.sol
│   ├── interfaces/IPriceFeed.sol
│   └── errors/OracleErrors.sol
├── test/
│   ├── helpers/OracleTestBase.sol
│   ├── OracleValidationLib.t.sol
│   ├── PriceScalerLib.t.sol
│   ├── MockAggregatorV3.t.sol
│   ├── MockPyth.t.sol
│   ├── ChainlinkPriceFeed.t.sol
│   ├── PythPriceFeed.t.sol
│   ├── PriceOracleConsumer.t.sol
│   ├── fork/ChainlinkMainnet.fork.t.sol
│   ├── fuzz/Oracle.fuzz.t.sol
│   └── gas/Oracle.gas.t.sol
├── script/Deploy.s.sol
├── foundry.toml
├── remappings.txt
├── package.json                  # @pythnetwork/pyth-sdk-solidity
├── .env.example
└── .gas-snapshot
```

### Contracts and responsibilities

| Contract / artifact | Responsibility |
|----------------------|-----------------|
| `IPriceFeed` | `decimals()` + `getValidatedPrice()` |
| `ChainlinkPriceFeed` | Push AggregatorV3 + validation; `latestPrice()` alias |
| `PythPriceFeed` | Pull: fee → update → validate → refund |
| `PriceOracleConsumer` | Push/Pull facade + `*Scaled18`; exact fee + caller refund |
| `MockAggregatorV3` | Controllable rounds/timestamps/answers |
| `MockPyth` | SDK MockPyth wrapper + `createUpdateData` / `setPrice` |
| `OracleValidationLib` | Round, freshness, answer, bounds, Push/Pull pipelines |
| `PriceScalerLib` | 8 ↔ 18 scaling with overflow guard |
| `OracleErrors` | Module custom errors |

---

## 5. Custom errors (module)

```solidity
error StalePriceFeed();
error InvalidOraclePrice();
error OracleRoundIncomplete();
error InsufficientFee();
error ZeroAddress();
error InvalidOracleConfig();
error EthTransferFailed();
```

Required by `.cursorrules`: the first four. The next three were added during implementation (config, zero address, refund).

---

## 6. Phase governance (mandatory authorization)

| Rule | Detail |
|-------|---------|
| **Gate** | No code for a phase is written until you explicitly say: *“I authorize Phase N”* (*“autorizo Fase N”*) (or equivalent). |
| **Delivery** | When closing a phase: acceptance checklist + summary of files touched. |
| **Blocking** | If new scope appears, it is documented and a new authorization is awaited. |
| **Test-Driven Development (TDD)** | Within each contract phase: tests first, then implementation. |

### Phase board

| Phase | Name | Status | Authorization |
|------|--------|--------|--------------|
| 0 | Foundry setup + structure + Chainlink/Pyth deps | ✅ Completed | ✅ Authorized |
| 1 | Interfaces + errors + `OracleValidationLib` + `PriceScalerLib` | ✅ Completed | ✅ Authorized |
| 2 | `MockAggregatorV3` + `MockPyth` | ✅ Completed | ✅ Authorized |
| 3 | `ChainlinkPriceFeed` (Push + validations) | ✅ Completed | ✅ Authorized |
| 4 | `PythPriceFeed` (Pull + fee + update) | ✅ Completed | ✅ Authorized |
| 5 | `PriceOracleConsumer` + e2e / fork / fuzz suite | ✅ Completed | ✅ Authorized |
| 6 | Gas profiling + Deploy + NatSpec / SWC hardening | ✅ Completed | ✅ Authorized |

> **Module v1 closed.** Future extensions: see §12.

---

## 7. Phase details

### Phase 0 — Foundry setup ✅

**Objective:** a compilable repo with tooling and pinned oracle dependencies.

1. Foundry structure compatible with the suite (`forge init` or minimal scaffold).
2. `foundry.toml`: solc `0.8.24`, fuzz runs ≥ 1000, `[rpc_endpoints]` section for fork.
3. Dependencies: `forge-std`, OpenZeppelin v5, Chainlink and/or Pyth interfaces (documented version).
4. Folders `src/{consumer,feeds,mocks,libraries,interfaces,errors}`, `test/{fork,fuzz,gas}`, `script/`, `doc/`.

**Exit criterion:** `forge build` OK; dependency versions written in this section.

**Done (2026-09-10):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer, fuzz `runs = 1000`, `[rpc_endpoints].mainnet = ${MAINNET_RPC_URL}`) + `remappings.txt`.
- Dependencies in `lib/` (gitignored): `forge-std`, OpenZeppelin **v5.2.0**, `chainlink-brownie-contracts` **1.3.0** (`AggregatorV3Interface`).
- Pyth via npm (official): `@pythnetwork/pyth-sdk-solidity` **4.2.0** (`IPyth`, `MockPyth`, etc.) + `package.json` / `package-lock.json`.
- Folders `src/{consumer,feeds,mocks,libraries,interfaces,errors}`, `test/{helpers,fork,fuzz,gas}`, `script/`, `.env.example`.
- Stub `src/Placeholder.sol` + smoke test `test/Placeholder.t.sol` (includes remappings check).
- Stub `script/Deploy.s.sol` (Phase 6).
- `forge build` and `forge test` green (**2 PASS**).
- Note: use `~/.foundry/bin/forge` (the `forge` from nvm/npm is not Foundry).

---

### Phase 1 — Interfaces + validation libs ✅

**Objective:** reusable types and validation rules.

1. `IPriceFeed`, AggregatorV3 and Pyth aliases/interfaces.
2. `OracleErrors.sol` with the module's required errors.
3. `OracleValidationLib`: staleness, `answeredInRound`, `updatedAt == 0`, bounds.
4. `PriceScalerLib`: decimal scaling with tests.
5. Unit tests + fuzzing of delays and prices.

**Exit criterion:** libs green; correct reverts on stale / invalid price / incomplete round.

**Done (2026-09-10):**
- `src/errors/OracleErrors.sol`: `StalePriceFeed`, `InvalidOraclePrice`, `OracleRoundIncomplete`, `InsufficientFee`, `ZeroAddress`, `InvalidOracleConfig`.
- `src/interfaces/IPriceFeed.sol` (unified API); Chainlink/Pyth via Phase 0 remappings.
- `OracleValidationLib`: round, freshness (incl. `updatedAt == 0` / future), answer > 0, bounds, Push/Pull pipelines.
- `PriceScalerLib`: `scale` / `to18Decimals` with overflow guard and max 18 decimals.
- Tests: `OracleValidationLib.t.sol` + `PriceScalerLib.t.sol` (unit + fuzz 1000).
- `Placeholder` stub removed.
- **`forge test` → 30 PASS**.

---

### Phase 2 — Mocks ✅

**Objective:** controllable oracles for unit tests without mainnet.

1. Tests first: set answer, set timestamp, set incomplete round.
2. `MockAggregatorV3` compatible with `latestRoundData` / `getRoundData` / `decimals`.
3. `MockPyth`: fixed fee, `updatePriceFeeds`, `getPrice` / `getPriceNoOlderThan`.

**Exit criterion:** mocks allow forcing every error path of the module.

**Done (2026-09-10):**
- `MockAggregatorV3`: `setRoundData`, `setLatestAnswer`, incomplete round, `updatedAt == 0`, negative answers; `RoundNotFound` error.
- `MockPyth`: inherits SDK MockPyth (full `IPyth`); helpers `createUpdateData` / `setPrice`; fee via `getUpdateFee`; stale with `getPriceNoOlderThan`.
- Tests: `MockAggregatorV3.t.sol` + `MockPyth.t.sol` (unit + fuzz).
- **`forge test` → 49 PASS**.

---

### Phase 3 — ChainlinkPriceFeed (Push) ✅

**Objective:** safe reading of AggregatorV3.

1. Tests: stale → `StalePriceFeed`; incomplete round → `OracleRoundIncomplete`; out of bounds / ≤0 → `InvalidOraclePrice`.
2. Implement Push wrapper with `MAX_DELAY`, `minAnswer`, `maxAnswer`.
3. NatSpec + immutables where applicable.

**Exit criterion:** happy path + all Push validation reverts green.

**Done (2026-09-10):**
- `ChainlinkPriceFeed`: immutables `aggregator`, `maxDelay`, `minAnswer`, `maxAnswer`; implements `IPriceFeed`.
- Constructor: `ZeroAddress` / `InvalidOracleConfig` (maxDelay 0, invalid bounds).
- `getValidatedPrice` / `latestPrice` via `OracleValidationLib.validateAggregatorRound`.
- Tests: happy path, stale, `updatedAt == 0`, incomplete round, zero/negative/bounds, fuzz.
- **`forge test` → 65 PASS**.

---

### Phase 4 — PythPriceFeed (Pull) ✅

**Objective:** on-demand update with fee and verification via the Pyth mock/contract.

1. Tests: insufficient fee → `InsufficientFee`; old price → `StalePriceFeed`; update + read OK.
2. Flow: `getUpdateFee` → `updatePriceFeeds{value: fee}` → read price → validate age/bounds.
3. Refund of leftover ETH if applicable (CEI).

**Exit criterion:** Pull e2e with mock; fee/staleness/bounds rejections covered.

**Done (2026-09-10):**
- `PythPriceFeed`: immutables `pyth`, `priceId`, `maxAge`, bounds, `decimals`; implements `IPriceFeed`.
- `updateAndGetPrice`: fee check → `updatePriceFeeds` → `_readAndValidate` → refund excess (`EthTransferFailed` if it fails).
- `getValidatedPrice`: view read after update with `OracleValidationLib.validatePullPrice`.
- New error: `EthTransferFailed` in `OracleErrors`.
- Tests: fee, refund, stale, bounds, zero/negative, fuzz.
- **`forge test` → 81 PASS**.

---

### Phase 5 — Consumer + fork + fuzz ✅

**Objective:** testing requirements from the module's `.cursorrules`.

| Type | What it validates |
|------|------------|
| Unit end-to-end (e2e) | Push/Pull consumer via mocks |
| Fork | Reading a mainnet Chainlink feed (ETH/USD or another documented one) |
| Stale / zero / negative | Explicit reverts |
| Fuzz | answers, decimals 8↔18, delays |

**Exit criterion:** `forge test` green; fork documented (RPC); fuzz ≥ 1000 runs.

**Done (2026-09-10):**
- `PriceOracleConsumer`: `getPushPrice`, `getPullPrice`, scaled18; exact fee on Pull + refund to the caller.
- E2E: `PriceOracleConsumer.t.sol` (push/pull, stale, zero/neg, fee, refund).
- Fork: `test/fork/ChainlinkMainnet.fork.t.sol` — ETH/USD `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`; skipped without `MAINNET_RPC_URL`.
- Fuzz: `test/fuzz/Oracle.fuzz.t.sol` (answers, delays, rounds, scale 8↔18).
- Helper: `test/helpers/OracleTestBase.sol`.
- **`forge test` → 96 PASS**, 3 SKIP (fork without RPC).

---

### Phase 6 — Gas + Deploy + hardening ✅

1. `script/Deploy.s.sol` (feeds + consumer; mainnet addresses in comments/env).
2. `test/gas/Oracle.gas.t.sol` + `.gas-snapshot`.
3. Full NatSpec; `doc/SWC-AUDIT-EN.md` and `doc/GAS-EN.md` in the style of previous modules.

**Exit criterion:** reproducible local deploy + security docs + documented gas.

**Done (2026-09-10):**
- `script/Deploy.s.sol` — local mocks or `CHAINLINK_AGGREGATOR` / `PYTH` / `PYTH_PRICE_ID` via env; mainnet ETH/USD reference.
- `test/gas/Oracle.gas.t.sol` + `.gas-snapshot` — raw ~16k, Push ~20–25k, Pull ~167–170k.
- `doc/SWC-AUDIT-EN.md` (Smart Contract Weakness Classification (SWC) matrix SWC-100–136, module 12 style): **0 vulnerabilities**; 5 informational.
- `doc/GAS-EN.md` + module root `README-EN.md`.
- **`forge test` → 102 PASS**, 3 SKIP (fork without RPC).

---

## 8. Test matrix (v1 — covered)

| Case | What it validates | Suite |
|------|------------|-------|
| Push happy path | Valid `latestRoundData` → price OK | `ChainlinkPriceFeed` / consumer |
| Stale | Old `updatedAt` → `StalePriceFeed` | unit + fuzz |
| Incomplete round | `answeredInRound < roundId` → `OracleRoundIncomplete` | unit + fuzz |
| Bounds / zero / negative | → `InvalidOraclePrice` | unit + fuzz |
| Pull + fee | update + read; low fee → `InsufficientFee` | `PythPriceFeed` / consumer |
| Pull refund | excess ETH returns to the caller | consumer e2e |
| Scale 8↔18 | `PriceScalerLib` / `*Scaled18` | unit + fuzz |
| Chainlink fork | mainnet ETH/USD | `ChainlinkMainnet.fork.t.sol` |
| Gas profiling | Push vs Pull documented | `Oracle.gas.t.sol` + `GAS-EN.md` |

---

## 9. Security (living checklist)

- [x] Staleness: `block.timestamp - updatedAt > MAX_DELAY` → revert.
- [x] `updatedAt == 0` → revert.
- [x] `answeredInRound < roundId` → revert.
- [x] `minAnswer` / `maxAnswer` bounds and rejection of price ≤ 0.
- [x] Pull: fee paid before reading post-update state.
- [x] Module custom errors.
- [x] No floating pragma; NatSpec on public APIs.
- [x] Fork + fuzz suite.
- [x] (Phase 6) SWC-AUDIT + gas.

---

## 10. Documentation deliverables (`doc/`)

| File | Content | Status |
|---------|-----------|--------|
| `README-EN.md` | Index of this folder | ✅ |
| `planificacion-EN.md` | This document (phases + gates) | ✅ |
| `diagrama-de-clases-EN.md` | Structure and relationships | ✅ |
| `diagrama-de-flujo-EN.md` | Decision flows | ✅ |
| `flujograma-EN.md` | End-to-end actor–system flows | ✅ |
| `SWC-AUDIT-EN.md` | SWC-100–136 matrix | ✅ |
| `GAS-EN.md` | Optimizations and benchmarks | ✅ |

---

## 11. Module acceptance criteria

1. [x] Compiles with `pragma solidity 0.8.24`.
2. [x] Push (Chainlink) and Pull (Pyth) operational with tests.
3. [x] Stale / incomplete-round / invalid prices revert with custom errors.
4. [x] Insufficient Pyth fee → `InsufficientFee`.
5. [x] Mainnet feed fork test green (with RPC).
6. [x] Fuzzing of answers / delays / decimals green.
7. [x] NatSpec + custom errors on public APIs.
8. [x] `doc/SWC-AUDIT-EN.md` with no vulnerabilities within v1 scope.

---

## 12. Next step

**Module v1 complete (Phases 0–6).** Possible extensions: upgradeable bounds, explicit Chainlink heartbeat, Pull mainnet e2e with a Hermes payload, Foundry invariants, multisig/timelock on config.

**Note:** use `~/.foundry/bin/forge` (or prepend `$HOME/.foundry/bin` to `PATH`); the `forge` from nvm/npm is not Foundry.
