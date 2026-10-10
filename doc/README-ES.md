# Documentación — Módulo 13: Decentralized Oracles (Push / Pull)
> English version: [README-EN.md](./README-EN.md)

Índice de la carpeta `doc/`. **Proyecto completo** (contratos + seguridad + gas).

| Documento | Contenido |
|-----------|-----------|
| [planificacion-ES.md](./planificacion-ES.md) | Objetivo, alcance, arquitectura final, fases 0–6 ✅ |
| [diagrama-de-clases-ES.md](./diagrama-de-clases-ES.md) | UML v1: consumer, feeds, mocks, libs |
| [diagrama-de-flujo-ES.md](./diagrama-de-flujo-ES.md) | Validación Push/Pull, fee, refund, scale |
| [flujograma-ES.md](./flujograma-ES.md) | Ciclo e2e + deploy + secuencias |
| [SWC-AUDIT-ES.md](./SWC-AUDIT-ES.md) | Matriz SWC-100–136 (0 vulnerabilidades) |
| [GAS-ES.md](./GAS-ES.md) | Baseline Push vs Pull + snapshot |
| [decisiones-tecnicas-ES.md](./decisiones-tecnicas-ES.md) | Decisiones de diseño, lógica del flujo, mejoras de gas |

**Estado:** Fases **0–6** ✅ (módulo cerrado v1).

**Contratos:** `PriceOracleConsumer` · `ChainlinkPriceFeed` · `PythPriceFeed` · `OracleValidationLib` · `PriceScalerLib` · mocks  
**Deps:** OZ **v5.2.0** · Chainlink brownie **1.3.0** · Pyth SDK **4.2.0** · Solidity **`0.8.24`**  
**Tests:** `forge test` → **102 PASS** · 3 SKIP (fork sin `MAINNET_RPC_URL`) · e2e / fuzz / gas / fork

README del proyecto: [`../README-ES.md`](../README-ES.md)
