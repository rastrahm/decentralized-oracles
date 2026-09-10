# Módulo 13 — Decentralized Oracles (Push / Pull)

Consumidor resiliente de precios con **Chainlink Push** (`AggregatorV3Interface`) y **Pyth Pull** (`IPyth`), Foundry y Solidity `0.8.24`.

**Estado:** v1 completo (Fases 0–6) · **Tests:** `forge test` → **102 PASS** / 3 SKIP (fork sin RPC)  
**Auditoría:** [`doc/SWC-AUDIT.md`](./doc/SWC-AUDIT.md) — **0 vulnerabilidades** · Gas: [`doc/GAS.md`](./doc/GAS.md)

---

## Qué incluye

| Componente | Descripción |
|------------|-------------|
| `ChainlinkPriceFeed` | Push: staleness, round completo, bounds; `latestPrice` alias |
| `PythPriceFeed` | Pull: fee → `updatePriceFeeds` → validate → refund |
| `PriceOracleConsumer` | Fachada Push/Pull + `*Scaled18`; fee exacto + refund al caller |
| Libs | `OracleValidationLib`, `PriceScalerLib` |
| Mocks | `MockAggregatorV3`, `MockPyth` (wrapper SDK) |

---

## Requisitos

- [Foundry](https://book.getfoundry.sh/) (`forge`, `cast`)
- Usa el binario real: `export PATH="$HOME/.foundry/bin:$PATH"`  
  (el `forge` de nvm/npm **no** es Foundry)
- Node/npm solo para `@pythnetwork/pyth-sdk-solidity` (ver `package.json`)

---

## Setup

```bash
cd 13-decentralized-oracles
export PATH="$HOME/.foundry/bin:$PATH"

forge install foundry-rs/forge-std --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
forge install smartcontractkit/chainlink-brownie-contracts@1.3.0 --no-git --shallow
npm install

forge build
forge test
```

---

## Comandos útiles

```bash
forge test
forge test --match-contract PriceOracleConsumerTest -vv
forge test --match-contract OracleGasTest --gas-report
forge snapshot --match-contract OracleGasTest

# Fork mainnet (opcional)
MAINNET_RPC_URL=https://... forge test --match-contract ChainlinkMainnetForkTest -vv

# Deploy local
anvil
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

### Variables de entorno (deploy / fork)

| Variable | Default | Uso |
|----------|---------|-----|
| `PRIVATE_KEY` | Anvil #0 | Deployer |
| `MAINNET_RPC_URL` | (vacío → skip fork) | Fork ETH/USD Chainlink |
| `CHAINLINK_AGGREGATOR` | mock | Aggregator real si se setea |
| `PYTH` / `PYTH_PRICE_ID` | mock / `keccak256("ETH/USD")` | Cableado Pull |
| `MAX_DELAY` / `MAX_AGE` | `1 hours` / `60` | Staleness |
| `MIN_ANSWER` / `MAX_ANSWER` | `1e8` / `1e6 * 1e8` | Bounds |
| `MOCK_SEED_PRICE` | `2000e8` | Seed del mock aggregator |

**Feed mainnet documentado:** Chainlink ETH/USD `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`

---

## Gas (baseline snapshot)

| Path | Gas approx. |
|------|-------------|
| Raw `latestRoundData` | ~16 173 |
| Push `getValidatedPrice` | ~19 849 |
| Consumer Push / Scaled18 | ~22 816 / ~24 756 |
| Pull `updateAndGetPrice` | ~169 786 |
| Consumer Pull | ~166 531 |

Detalle: [`doc/GAS.md`](./doc/GAS.md) · regenerar con `forge snapshot --match-contract OracleGasTest`.

---

## Estructura

```text
13-decentralized-oracles/
├── src/
│   ├── consumer/PriceOracleConsumer.sol
│   ├── feeds/{ChainlinkPriceFeed,PythPriceFeed}.sol
│   ├── libraries/{OracleValidationLib,PriceScalerLib}.sol
│   ├── mocks/{MockAggregatorV3,MockPyth}.sol
│   ├── interfaces/IPriceFeed.sol
│   └── errors/OracleErrors.sol
├── test/          # unit, e2e, fork/, fuzz/, gas/, helpers/
├── script/Deploy.s.sol
├── doc/           # plan, diagramas, SWC-AUDIT, GAS
├── foundry.toml
├── remappings.txt
├── package.json
├── .env.example
└── .gas-snapshot
```

---

## Documentación

| Doc | Contenido |
|-----|-----------|
| [`doc/planificacion.md`](./doc/planificacion.md) | Fases TDD + gates (0–6 ✅) |
| [`doc/diagrama-de-clases.md`](./doc/diagrama-de-clases.md) | UML v1 final |
| [`doc/diagrama-de-flujo.md`](./doc/diagrama-de-flujo.md) | Decisiones validación / fee / refund |
| [`doc/flujograma.md`](./doc/flujograma.md) | e2e Push/Pull + deploy |
| [`doc/SWC-AUDIT.md`](./doc/SWC-AUDIT.md) | Matriz SWC-100–136 |
| [`doc/GAS.md`](./doc/GAS.md) | Push vs Pull baseline |
