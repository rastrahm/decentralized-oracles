# Documentation — Module 13: Decentralized Oracles (Push / Pull)
> Versión en español: [README-ES.md](./README-ES.md)

Index of the `doc/` folder. **Project complete** (contracts + security + gas).

| Document | Content |
|-----------|-----------|
| [planificacion-EN.md](./planificacion-EN.md) | Goal, scope, final architecture, phases 0–6 ✅ |
| [diagrama-de-clases-EN.md](./diagrama-de-clases-EN.md) | v1 UML: consumer, feeds, mocks, libs |
| [diagrama-de-flujo-EN.md](./diagrama-de-flujo-EN.md) | Push/Pull validation, fee, refund, scale |
| [flujograma-EN.md](./flujograma-EN.md) | e2e cycle + deploy + sequences |
| [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) | SWC-100–136 matrix (0 vulnerabilities) |
| [GAS-EN.md](./GAS-EN.md) | Push vs Pull baseline + snapshot |
| [decisiones-tecnicas-EN.md](./decisiones-tecnicas-EN.md) | Design decisions, flow logic, gas improvements |

**Status:** Phases **0–6** ✅ (module closed, v1).

**Contracts:** `PriceOracleConsumer` · `ChainlinkPriceFeed` · `PythPriceFeed` · `OracleValidationLib` · `PriceScalerLib` · mocks  
**Deps:** OZ **v5.2.0** · Chainlink brownie **1.3.0** · Pyth SDK **4.2.0** · Solidity **`0.8.24`**  
**Tests:** `forge test` → **102 PASS** · 3 SKIP (fork without `MAINNET_RPC_URL`) · e2e / fuzz / gas / fork

Project README: [`../README-EN.md`](../README-EN.md)
