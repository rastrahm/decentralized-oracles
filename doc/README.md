# Documentación — Módulo 13: Decentralized Oracles (Push / Pull)

Índice de la carpeta `doc/`. **Planificación v1** (pre-implementación).

| Documento | Contenido |
|-----------|-----------|
| [planificacion.md](./planificacion.md) | Objetivo, alcance, fases TDD, gates de autorización, criterios |
| [diagrama-de-clases.md](./diagrama-de-clases.md) | UML: consumidores, mocks, Chainlink, Pyth |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Flujos de decisión (staleness, bounds, fees, rounds) |
| [flujograma.md](./flujograma.md) | Ciclo e2e Push (Chainlink) y Pull (Pyth) |

**Estado:** Fases **0–2** ✅. Fases **3–6** ⏳ pendientes de autorización.

**Regla:** no se escribe código de una fase hasta que digas explícitamente *“autorizo Fase N”*.

**Artefactos:** `IPriceFeed` · `OracleErrors` · libs · `MockAggregatorV3` · `MockPyth`  
**Deps:** OZ **v5.2.0** · Chainlink brownie **1.3.0** · Pyth SDK **4.2.0** · Solidity **`0.8.24`** · Foundry  
**Tests:** `forge test` → **49 PASS**
