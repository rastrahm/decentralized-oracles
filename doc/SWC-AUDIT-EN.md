# SWC Audit — Decentralized Oracles (Push / Pull)

> Versión en español: [SWC-AUDIT-ES.md](./SWC-AUDIT-ES.md)

Verification of the price consumer and the Chainlink/Pyth wrappers against the [Smart Contract Weakness Classification (SWC) Registry](https://swcregistry.io/) (EIP-1470) and the monorepo principles (custom errors, fixed pragma, staleness, bounds, Pull fee).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement it with the [Smart Contract Security Verification Standard (SCSVS)](https://github.com/ComposableSecurity/SCSVS), [EEA EthTrust](https://entethalliance.org/specs/ethtrust/) and the [Chainlink](https://docs.chain.link/data-feeds/price-feeds) / [Pyth](https://docs.pyth.network/) guides.

**Audited contracts (prod / core):**  
`src/consumer/PriceOracleConsumer.sol`, `src/feeds/ChainlinkPriceFeed.sol`, `src/feeds/PythPriceFeed.sol`,  
`src/libraries/OracleValidationLib.sol`, `src/libraries/PriceScalerLib.sol`,  
`src/interfaces/IPriceFeed.sol`, `src/errors/OracleErrors.sol`

**Trusted dependencies (out of scope for in-house bugs):**  
Chainlink `AggregatorV3Interface` (brownie-contracts 1.3.0), `@pythnetwork/pyth-sdk-solidity` 4.2.0 (`IPyth` / AbstractPyth)

**Mocks (not production):** `src/mocks/*`  
**Date:** 2026-09-10  
**Test reference:** `test/ChainlinkPriceFeed.t.sol`, `test/PythPriceFeed.t.sol`, `test/PriceOracleConsumer.t.sol`,  
`test/OracleValidationLib.t.sol`, `test/PriceScalerLib.t.sol`, `test/fork/`, `test/fuzz/`, `test/gas/`  
**Style:** aligned with [`12-account-abstraction/doc/SWC-AUDIT.md`](../../12-account-abstraction/doc/SWC-AUDIT.md)  
**Docs index:** [`README-EN.md`](./README-EN.md) · Module README: [`../README-EN.md`](../README-EN.md)

---

## Executive summary

| Status | Count |
|--------|----------|
| ✅ Mitigated / Not applicable | 31 |
| ⚠️ Informational (design / trust / ops) | 5 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities within the v1 scope (Chainlink Push + Pyth Pull + consumer). The module **rejects stale prices, incomplete rounds, `updatedAt == 0`, prices ≤ 0 and out-of-bounds prices**; in Pull it requires the fee (`InsufficientFee`) before `updatePriceFeeds` and refunds the excess with `.call`. Informational risks: reliance on `block.timestamp` for staleness, trust in the deployed aggregator/Pyth contract, and bounds/config that are immutable after deployment.

**Suite / module 13 principles verified:**

| Principle | Status |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `OracleErrors` |
| Fixed pragma `0.8.24` | ✅ |
| Staleness + `updatedAt == 0` + incomplete round | ✅ `OracleValidationLib` |
| Bounds `minAnswer` / `maxAnswer` + answer > 0 | ✅ |
| Pull: `getUpdateFee` → update → validate → refund | ✅ Checks-Effects-Interactions (CEI) on the excess |
| ETH only via `.call{value}` | ✅ |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/` |
| Chainlink mainnet fork (optional RPC) | ✅ `test/fork/` |

---

## Full SWC-100 — SWC-136 matrix

| ID | Title | Applies | Status | Evidence in Oracles |
|----|--------|--------|--------|----------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility in `src/` |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; `PriceScalerLib` guards against overflow when scaling |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`) |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | Refunds check `ok` → `EthTransferFailed` |
| SWC-105 | Unprotected Ether Withdrawal | Yes | ✅ | No open withdraw; ETH only for the Pyth fee + refund to `msg.sender` |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Partial | ✅ | Pull: external update, then validate, then refund; consumer pays the exact fee to the feed; no callbacks in mocks on the prod path |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | Explicit `public` / `private` / `immutable` |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | No `delegatecall` |
| SWC-113 | DoS with Failed Call | Yes | ✅ | Failed refund → `EthTransferFailed` (does not silently leave ETH stuck on the happy path) |
| SWC-114 | Transaction Order Dependence | Yes | ⚠️ | Pull relayers / Push keepers; see risks |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth via immutable config + data validation |
| SWC-116 | Block values as a proxy for time | Yes | ⚠️ | Staleness uses `block.timestamp` vs `updatedAt`/`publishTime` |
| SWC-117 | Signature Malleability | Partial | ✅ | Pyth signatures verified in the Pyth contract (dependency); the module does not parse its own signatures |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No state shadowing in core |
| SWC-120 | Weak Sources of Randomness | No | N/A | No RNG |
| SWC-121 | Missing Protection against Signature Replay | Partial | ✅ | Pyth payload replay: the Pyth contract ignores a `publishTime` that is not newer |
| SWC-122 | Lack of Proper Signature Verification | Partial | ✅ | Verification in `IPyth` (trusted dependency); the consumer does not accept a price without going through the feed |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + unit/e2e/fuzz/fork |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | No storage assembly |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | `IPriceFeed` in feeds; consumer uses composition |
| SWC-126 | Insufficient Gas Griefing | Partial | ⚠️ | A Pyth update with a large payload can be expensive (ops) |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Partial | ⚠️ | Very large `updateData` arrays → out of gas (OOG) (caller) |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge build` / suite PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII in `src/` |
| SWC-131 | Presence of unused variables | Yes | ✅ | No material dead code in core |
| SWC-132 | Unexpected Ether balance | Partial | ✅ | Consumer does not retain the fee (pays exact amount); excess is refunded |
| SWC-133 | Hash Collisions (var-length args) | No | N/A | No hashing of variable-length args in core |
| SWC-134 | Message call with hardcoded gas | No | N/A | `.call{value}` without a restrictive hardcoded gas amount |
| SWC-135 | Code With No Effects | No | N/A | No relevant no-ops |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ✅ | Prices / events are public by oracle design |

---

## Informational risks

### SWC-116 — `block.timestamp` for staleness

Push and Pull compare `updatedAt` / `publishTime` against `block.timestamp`. This is the standard pattern for on-chain oracles; miners can skew it by a few seconds. Mitigation: conservative `maxDelay`/`maxAge` and price bounds.

### SWC-114 — Ordering / relayers

In Pull, whoever supplies `updateData` chooses when the update happens. Front-running of liquidations that depend on the price is a DeFi domain risk, not a bypass of the module's validation. Mitigation at the consuming protocol level (out of v1 scope).

### SWC-126 / SWC-128 — `updateData` size

Large Pyth payloads increase fee and gas. Responsibility of the caller / relayer.

### Centralization / post-deploy trust

| Topic | Risk | v1 handling |
|------|--------|----------------|
| `aggregator` / `pyth` immutable | Wrong address = unusable or malicious feed | Deploy script + verification (mainnet ETH/USD documented) |
| Bounds / `maxDelay` immutable | Cannot be retuned on-chain | Redeploy; document margins |
| Pyth price already on-chain but stale | `getValidatedPrice` view reverts | Force `updateAndGetPrice` on hot paths |
| MockPyth in tests | Not the mainnet wire format | Separate fork/unit tests; mocks for tests only |

---

## Monorepo principles checklist (+ module 13)

| Principle | Compliant? | Notes |
|-----------|----------|--------|
| Custom errors | ✅ | `StalePriceFeed`, `InvalidOraclePrice`, `OracleRoundIncomplete`, `InsufficientFee`, … |
| Staleness / round / bounds | ✅ | `OracleValidationLib` |
| Pull fee before reading | ✅ | `PythPriceFeed` + consumer |
| NatSpec on public/external | ✅ | Core + libs |
| Fuzz ≥ 1000 runs | ✅ | `test/fuzz/Oracle.fuzz.t.sol` |
| Optional mainnet fork | ✅ | `test/fork/ChainlinkMainnet.fork.t.sol` |
| No floating pragma | ✅ | `0.8.24` |
| No ETH `transfer`/`send` | ✅ | Only `.call{value}` |
| Push vs Pull gas profiling | ✅ | `doc/GAS-EN.md` |

---

## Verification findings (code)

### Confirmed mitigations

1. **ChainlinkPriceFeed:** immutables; `validateAggregatorRound` (round, freshness, answer > 0, bounds).
2. **PythPriceFeed:** fee check → `updatePriceFeeds` → validate → refund; `EthTransferFailed` if the refund fails.
3. **PriceOracleConsumer:** exact fee to the pull feed; excess refunded to the original caller (no ETH remains in the consumer).
4. **OracleValidationLib / PriceScalerLib:** shared rules + overflow guard on scale-up.
5. **E2E / fuzz / fork:** stale, zero/negative, fee and 8↔18 scaling paths; mainnet ETH/USD when an RPC is available.

### Phase 6 hardening

| # | Change | Reason |
|---|--------|--------|
| 1 | `script/Deploy.s.sol` | Reproducible local deploy / mainnet env wiring |
| 2 | `test/gas/Oracle.gas.t.sol` + `.gas-snapshot` | Push vs Pull vs raw |
| 3 | `doc/SWC-AUDIT-EN.md` / `doc/GAS-EN.md` | SWC-100–136 matrix + benchmarks |
| 4 | Module README | Operation / env / structure |

### Non-blocking observations (v2)

| # | Observation | Severity | Suggested action |
|---|-------------|-----------|-----------------|
| 1 | Bounds / delay not upgradeable | Info | Ownable2Step + setters or proxy |
| 2 | No explicit Chainlink heartbeat (only `updatedAt`) | Info | Combine with the feed's documented `heartbeat` |
| 3 | Mainnet Pull e2e with a real Hermes payload | Improvement | Off-chain integration test |
| 4 | Formal Foundry invariants | Improvement | Handler over mocks |

---

## SWC → tests mapping

| SWC | Test(s) |
|-----|---------|
| SWC-101 | `PriceScalerLib` overflow + scale fuzz |
| SWC-103 | `forge build` fixed pragma |
| SWC-104 / 105 | refund paths `PythPriceFeed` / `PriceOracleConsumer` |
| SWC-107 | e2e pull exact fee + caller refund |
| SWC-116 | stale unit + delay fuzz |
| SWC-123 | unit + e2e + fuzz + fork |
| Stale / round / bounds | `ChainlinkPriceFeed.t.sol`, `OracleValidationLib.t.sol` |
| Pull fee | `PythPriceFeed.t.sol`, `PriceOracleConsumer.t.sol` |
| Fork | `test/fork/ChainlinkMainnet.fork.t.sol` |

---

## Execution result

```text
forge test --summary
# 2026-09-10 Phase 6
OracleValidationLibTest       21 PASS (+ fuzz 1000)
PriceScalerLibTest             9 PASS (+ fuzz 1000)
MockAggregatorV3Test           8 PASS (+ fuzz 1000)
MockPythTest                  11 PASS (+ fuzz 1000)
ChainlinkPriceFeedTest        16 PASS (+ fuzz 1000)
PythPriceFeedTest             16 PASS (+ fuzz 1000)
PriceOracleConsumerTest        9 PASS
OracleFuzzTest                 6 PASS (1000 runs each)
OracleGasTest                  6 PASS
ChainlinkMainnetForkTest       3 SKIP (no MAINNET_RPC_URL) / PASS with RPC
Total: 102 PASS / 0 FAIL / 3 SKIP
```

---

## References

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
- [Pyth EVM Pull](https://docs.pyth.network/price-feeds/core/use-real-time-data/pull-integration/evm)
- Module 12: [`12-account-abstraction/doc/SWC-AUDIT.md`](../../12-account-abstraction/doc/SWC-AUDIT.md)
- Gas: [`GAS-EN.md`](./GAS-EN.md)
- Plan: [`planificacion-EN.md`](./planificacion-EN.md)
