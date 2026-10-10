# Module 13 — Decentralized Oracles (Push / Pull)
> Versión en español: [README-ES.md](./README-ES.md)

Resilient price consumer with **Chainlink Push** (`AggregatorV3Interface`) and **Pyth Pull** (`IPyth`), Foundry and Solidity `0.8.24`.

**Status:** v1 complete (Phases 0–6) · **Tests:** `forge test` → **102 PASS** / 3 SKIP (fork without RPC)  
**Audit:** [`doc/SWC-AUDIT-EN.md`](./doc/SWC-AUDIT-EN.md) — **0 vulnerabilities** · Gas: [`doc/GAS-EN.md`](./doc/GAS-EN.md)

---

## What's included

| Component | Description |
|------------|-------------|
| `ChainlinkPriceFeed` | Push: staleness, complete round, bounds; `latestPrice` alias |
| `PythPriceFeed` | Pull: fee → `updatePriceFeeds` → validate → refund |
| `PriceOracleConsumer` | Push/Pull facade + `*Scaled18`; exact fee + refund to the caller |
| Libs | `OracleValidationLib`, `PriceScalerLib` |
| Mocks | `MockAggregatorV3`, `MockPyth` (SDK wrapper) |

---

## Requirements

- [Foundry](https://book.getfoundry.sh/) (`forge`, `cast`)
- Use the real binary: `export PATH="$HOME/.foundry/bin:$PATH"`  
  (the nvm/npm `forge` is **not** Foundry)
- Node/npm only for `@pythnetwork/pyth-sdk-solidity` (see `package.json`)

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

## Useful commands

```bash
forge test
forge test --match-contract PriceOracleConsumerTest -vv
forge test --match-contract OracleGasTest --gas-report
forge snapshot --match-contract OracleGasTest

# Mainnet fork (optional)
MAINNET_RPC_URL=https://... forge test --match-contract ChainlinkMainnetForkTest -vv

# Local deploy
anvil
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

### Environment variables (deploy / fork)

| Variable | Default | Usage |
|----------|---------|-----|
| `PRIVATE_KEY` | Anvil #0 | Deployer |
| `MAINNET_RPC_URL` | (empty → skip fork) | Chainlink ETH/USD fork |
| `CHAINLINK_AGGREGATOR` | mock | Real aggregator if set |
| `PYTH` / `PYTH_PRICE_ID` | mock / `keccak256("ETH/USD")` | Pull wiring |
| `MAX_DELAY` / `MAX_AGE` | `1 hours` / `60` | Staleness |
| `MIN_ANSWER` / `MAX_ANSWER` | `1e8` / `1e6 * 1e8` | Bounds |
| `MOCK_SEED_PRICE` | `2000e8` | Mock aggregator seed |

**Documented mainnet feed:** Chainlink ETH/USD `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`

---

## Gas (baseline snapshot)

| Path | Approx. gas |
|------|-------------|
| Raw `latestRoundData` | ~16 173 |
| Push `getValidatedPrice` | ~19 849 |
| Consumer Push / Scaled18 | ~22 816 / ~24 756 |
| Pull `updateAndGetPrice` | ~169 786 |
| Consumer Pull | ~166 531 |

Details: [`doc/GAS-EN.md`](./doc/GAS-EN.md) · regenerate with `forge snapshot --match-contract OracleGasTest`.

---

## Structure

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
├── doc/           # plan, diagrams, SWC-AUDIT, GAS
├── foundry.toml
├── remappings.txt
├── package.json
├── .env.example
└── .gas-snapshot
```

---

## Documentation

| Doc | Content |
|-----|-----------|
| [`doc/planificacion-EN.md`](./doc/planificacion-EN.md) | TDD phases + gates (0–6 ✅) |
| [`doc/diagrama-de-clases-EN.md`](./doc/diagrama-de-clases-EN.md) | Final v1 UML |
| [`doc/diagrama-de-flujo-EN.md`](./doc/diagrama-de-flujo-EN.md) | Validation / fee / refund decisions |
| [`doc/flujograma-EN.md`](./doc/flujograma-EN.md) | Push/Pull e2e + deploy |
| [`doc/SWC-AUDIT-EN.md`](./doc/SWC-AUDIT-EN.md) | SWC-100–136 matrix |
| [`doc/GAS-EN.md`](./doc/GAS-EN.md) | Push vs Pull baseline |
