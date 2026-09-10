# Documentación — Módulo 13: Decentralized Oracles (Push / Pull)

Índice de la carpeta `doc/`. **Proyecto completo** (contratos + seguridad + gas).

| Documento | Contenido |
|-----------|-----------|
| [planificacion.md](./planificacion.md) | Objetivo, alcance, arquitectura final, fases 0–6 ✅ |
| [diagrama-de-clases.md](./diagrama-de-clases.md) | UML v1: consumer, feeds, mocks, libs |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Validación Push/Pull, fee, refund, scale |
| [flujograma.md](./flujograma.md) | Ciclo e2e + deploy + secuencias |
| [SWC-AUDIT.md](./SWC-AUDIT.md) | Matriz SWC-100–136 (0 vulnerabilidades) |
| [GAS.md](./GAS.md) | Baseline Push vs Pull + snapshot |

**Estado:** Fases **0–6** ✅ (módulo cerrado v1).

**Contratos:** `PriceOracleConsumer` · `ChainlinkPriceFeed` · `PythPriceFeed` · `OracleValidationLib` · `PriceScalerLib` · mocks  
**Deps:** OZ **v5.2.0** · Chainlink brownie **1.3.0** · Pyth SDK **4.2.0** · Solidity **`0.8.24`**  
**Tests:** `forge test` → **102 PASS** · 3 SKIP (fork sin `MAINNET_RPC_URL`) · e2e / fuzz / gas / fork

README del proyecto: [`../README.md`](../README.md)
