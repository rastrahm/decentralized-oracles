# Optimización de gas — Decentralized Oracles (Push / Pull)

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract OracleGasTest --gas-report
forge snapshot --match-contract OracleGasTest
```

**Fecha baseline:** 2026-09-10 (Fase 6)  
**Snapshot:** `.gas-snapshot` (`test/gas/Oracle.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`

---

## Comparativa lectura cruda vs Push vs Pull

Medición = gas del **test Foundry** (incluye validación / update donde aplica). Órdenes de magnitud para comparar paths, no coste exacto de solo el SLOAD del aggregator.

| Path | Gas (snapshot) | vs raw |
|------|----------------|--------|
| `testGas_rawLatestRoundData` | **16 173** | baseline |
| `testGas_push_getValidatedPrice` | **19 849** | **+3 676** (~1.23×) |
| `testGas_consumer_getPushPrice` | **22 816** | **+6 643** (~1.41×) |
| `testGas_consumer_getPushPriceScaled18` | **24 756** | **+8 583** (~1.53×) |
| `testGas_pull_updateAndGetPrice` | **169 786** | **+153 613** (~10.5×) |
| `testGas_consumer_getPullPrice` | **166 531** | **+150 358** (~10.3×) |

### Lectura

- **Push** añade poco sobre la lectura cruda: round + freshness + bounds en `OracleValidationLib` (view).
- **Pull** domina el coste: `updatePriceFeeds` (escritura + fee) + validate. Esperado frente a Push.
- El consumer Push añade un hop externo barato; scaled18 añade aritmética de `PriceScalerLib`.

---

## Optimizaciones ya aplicadas en el módulo

| Técnica | Dónde | Efecto |
|---------|-------|--------|
| `aggregator` / `pyth` / bounds / delays **immutable** | Feeds | Sin SLOAD de config en hot path |
| Validación en **library** | `OracleValidationLib` | Reuso + inlining con optimizer |
| Custom errors | `OracleErrors` | Más barato que `require` strings |
| Consumer paga **fee exacto** al Pull | `PriceOracleConsumer` | Evita refund interno del feed (menos call) |
| `calldata` en `updateData` | Pull APIs | Menos copias memory |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Inlining agresivo |

---

## Tradeoffs aceptados

| Decisión | Por qué |
|----------|---------|
| Config immutable (sin setters) | Simplicidad / no governance en v1; retune = redeploy |
| Staleness con `block.timestamp` | Estándar oráculos; documentado en SWC-116 |
| Pull siempre escribe on-chain | Modelo Pyth; no hay “read-only pull” sin update fresco |
| Escala a 18 solo en consumer | Feeds reportan decimals nativos del vendor |

---

## Deploy

```bash
# Local (mocks + feeds + consumer)
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast

# Mainnet-style (ejemplo): cablear aggregator Chainlink
CHAINLINK_AGGREGATOR=0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419 \
PYTH=<pyth_address> \
PYTH_PRICE_ID=<bytes32> \
forge script script/Deploy.s.sol:Deploy --rpc-url $MAINNET_RPC_URL --broadcast
```

Ver `script/Deploy.s.sol` para env.

README: [`../README.md`](../README.md) · Índice docs: [`README.md`](./README.md)
