# Gas optimization — Decentralized Oracles (Push / Pull)
> Versión en español: [GAS-ES.md](./GAS-ES.md)

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract OracleGasTest --gas-report
forge snapshot --match-contract OracleGasTest
```

**Baseline date:** 2026-09-10 (Phase 6)  
**Snapshot:** `.gas-snapshot` (`test/gas/Oracle.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`

---

## Raw read vs Push vs Pull comparison

Measurement = gas of the **Foundry test** (includes validation / update where applicable). Orders of magnitude for comparing paths, not the exact cost of the aggregator SLOAD alone.

| Path | Gas (snapshot) | vs raw |
|------|----------------|--------|
| `testGas_rawLatestRoundData` | **16 173** | baseline |
| `testGas_push_getValidatedPrice` | **19 849** | **+3 676** (~1.23×) |
| `testGas_consumer_getPushPrice` | **22 816** | **+6 643** (~1.41×) |
| `testGas_consumer_getPushPriceScaled18` | **24 756** | **+8 583** (~1.53×) |
| `testGas_pull_updateAndGetPrice` | **169 786** | **+153 613** (~10.5×) |
| `testGas_consumer_getPullPrice` | **166 531** | **+150 358** (~10.3×) |

### Reading

- **Push** adds little over the raw read: round + freshness + bounds in `OracleValidationLib` (view).
- **Pull** dominates the cost: `updatePriceFeeds` (write + fee) + validate. Expected compared to Push.
- The Push consumer adds a cheap external hop; scaled18 adds `PriceScalerLib` arithmetic.

---

## Optimizations already applied in the module

| Technique | Where | Effect |
|---------|-------|--------|
| `aggregator` / `pyth` / bounds / delays **immutable** | Feeds | No config SLOAD in the hot path |
| Validation in a **library** | `OracleValidationLib` | Reuse + inlining with the optimizer |
| Custom errors | `OracleErrors` | Cheaper than `require` strings |
| Consumer pays the **exact fee** to Pull | `PriceOracleConsumer` | Avoids the feed's internal refund (one less call) |
| `calldata` for `updateData` | Pull APIs | Fewer memory copies |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Aggressive inlining |

---

## Accepted tradeoffs

| Decision | Why |
|----------|---------|
| Immutable config (no setters) | Simplicity / no governance in v1; retune = redeploy |
| Staleness with `block.timestamp` | Oracle standard; documented in SWC-116 |
| Pull always writes on-chain | Pyth model; there is no “read-only pull” without a fresh update |
| Scale to 18 only in the consumer | Feeds report the vendor's native decimals |

---

## Deploy

```bash
# Local (mocks + feeds + consumer)
anvil   # another terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast

# Mainnet-style (example): wire the Chainlink aggregator
CHAINLINK_AGGREGATOR=0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419 \
PYTH=<pyth_address> \
PYTH_PRICE_ID=<bytes32> \
forge script script/Deploy.s.sol:Deploy --rpc-url $MAINNET_RPC_URL --broadcast
```

See `script/Deploy.s.sol` for env.

README: [`../README-EN.md`](../README-EN.md) · Docs index: [`README-EN.md`](./README-EN.md)
