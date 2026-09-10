# Documentación — Módulo 13: Decentralized Oracles (Push / Pull)

Índice de la carpeta `doc/`. **Planificación v1** (pre-implementación).

| Documento | Contenido |
|-----------|-----------|
| [planificacion.md](./planificacion.md) | Objetivo, alcance, fases TDD, gates de autorización, criterios |
| [diagrama-de-clases.md](./diagrama-de-clases.md) | UML: consumidores, mocks, Chainlink, Pyth |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Flujos de decisión (staleness, bounds, fees, rounds) |
| [flujograma.md](./flujograma.md) | Ciclo e2e Push (Chainlink) y Pull (Pyth) |

**Estado:** Solo documentación creada. Fases **0–6** ⏳ pendientes de autorización.

**Regla:** no se escribe código de una fase hasta que digas explícitamente *“autorizo Fase N”*.

**Contratos previstos:** `PriceOracleConsumer` · `MockAggregatorV3` · `ChainlinkPriceFeed` · `PythPriceFeed` · libs de validación  
**Estándar:** Chainlink `AggregatorV3Interface` + Pyth `IPyth` · Solidity **`0.8.24`** · Foundry
