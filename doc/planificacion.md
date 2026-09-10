# Planificación — Módulo 13: Decentralized Oracles & Pyth/Chainlink Push-Pull

**Estado:** Documentación inicial creada. Fases **0–6** ⏳ sin autorizar.  
**Regla de avance:** cada fase requiere **autorización explícita** del responsable antes de empezar.

---

## 1. Objetivo

Construir un consumidor de precios resiliente y un mock aggregator propios que soporten:

- **Push** — Chainlink `AggregatorV3Interface` (precio ya on-chain; el consumidor solo lee).
- **Pull** — Pyth `IPyth` / actualización on-demand con verificación criptográfica del payload y pago de `getUpdateFee()`.
- Validación estricta de **staleness**, **rounds incompletos** y **bounds** (`minAnswer` / `maxAnswer`).
- Stack: **Foundry + Solidity `0.8.24`** (pragma fijo).

---

## 2. Alcance

| Incluido | Excluido (v1) |
|----------|----------------|
| Consumer unificado Push/Pull, mocks AggregatorV3, wrappers Chainlink/Pyth, errors, tests unit/fork/fuzz | Aggregator multi-oracle con consenso ponderado complejo |
| Staleness + round completeness + min/max bounds | Oráculos propios con staking de reporters |
| Fee Pyth (`getUpdateFee`) + `updatePriceFeeds` antes de leer | Frontend / dashboard de precios |
| Fork tests mainnet (feeds Chainlink reales) | Redes L2 específicas más allá de lo documentado en deploy |
| Custom errors del módulo | RedStone / API3 / otros vendors (post-v1) |

---

## 3. Stack y restricciones técnicas

### Suite (`evm-smart-contracts-suite`)

- Solidity **exacto** `0.8.24`.
- OpenZeppelin Contracts v5.x donde aporte valor (p. ej. `Ownable2Step` para admin de bounds).
- Foundry: unit + fuzz (`runs >= 1000`) + fork tests + gas reports.
- Custom errors (no `require` con strings).
- CEI / access control en funciones administrativas.
- NatSpec en toda API pública/externa.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.

### Módulo 13 (Oracles)

- Push: `latestRoundData()` / `getRoundData`; rechazar si `answeredInRound < roundId`, `updatedAt == 0`, o `block.timestamp - updatedAt > MAX_DELAY`.
- Bounds: precio fuera de `[minAnswer, maxAnswer]` → `InvalidOraclePrice`.
- Pull: parsear `priceUpdateData`, pagar fee, llamar `updatePriceFeeds{value: fee}`, luego `getPrice` / `getPriceNoOlderThan`.
- Fee insuficiente → `InsufficientFee`.
- Escalado de decimales (8 → 18) en lib dedicada cuando el consumidor lo necesite.

---

## 4. Arquitectura prevista

```
13-decentralized-oracles/
├── README.md
├── doc/
│   ├── README.md
│   ├── planificacion.md
│   ├── diagrama-de-clases.md
│   ├── diagrama-de-flujo.md
│   ├── flujograma.md
│   ├── SWC-AUDIT.md          # Fase 6
│   └── GAS.md                # Fase 6
├── src/
│   ├── consumer/
│   │   └── PriceOracleConsumer.sol
│   ├── feeds/
│   │   ├── ChainlinkPriceFeed.sol
│   │   └── PythPriceFeed.sol
│   ├── mocks/
│   │   ├── MockAggregatorV3.sol
│   │   └── MockPyth.sol
│   ├── libraries/
│   │   ├── OracleValidationLib.sol
│   │   └── PriceScalerLib.sol
│   ├── interfaces/
│   │   ├── IPriceFeed.sol
│   │   ├── AggregatorV3Interface.sol   # o remapping Chainlink
│   │   └── IPyth.sol                   # o remapping Pyth
│   └── errors/OracleErrors.sol
├── test/
│   ├── helpers/OracleTestBase.sol
│   ├── OracleValidationLib.t.sol
│   ├── PriceScalerLib.t.sol
│   ├── MockAggregatorV3.t.sol
│   ├── ChainlinkPriceFeed.t.sol
│   ├── PythPriceFeed.t.sol
│   ├── PriceOracleConsumer.t.sol
│   ├── fork/ChainlinkMainnet.fork.t.sol
│   ├── fuzz/Oracle.fuzz.t.sol
│   └── gas/Oracle.gas.t.sol
├── script/Deploy.s.sol
├── foundry.toml
├── remappings.txt
└── .gas-snapshot
```

### Contratos y responsabilidades

| Contrato / artefacto | Responsabilidad |
|----------------------|-----------------|
| `IPriceFeed` | API unificada `getPrice()` / `latestPrice()` normalizada |
| `ChainlinkPriceFeed` | Lee AggregatorV3; aplica staleness, round y bounds |
| `PythPriceFeed` | Actualiza con payload + fee; lee precio; valida edad |
| `PriceOracleConsumer` | Orquesta Push/Pull; expone precio seguro a protocolos |
| `MockAggregatorV3` | Simula rounds, timestamps y answers para unit tests |
| `MockPyth` | Simula fee, update y precios firmados simplificados |
| `OracleValidationLib` | Staleness, round completeness, bounds |
| `PriceScalerLib` | Escalado entre decimales (8 ↔ 18) |
| `OracleErrors` | Custom errors del módulo |

---

## 5. Errores custom (obligatorios del módulo)

```solidity
error StalePriceFeed();
error InvalidOraclePrice();
error OracleRoundIncomplete();
error InsufficientFee();
```

Ampliar solo si hace falta (p. ej. `ZeroAddress()`, `InvalidFeed()`, `PriceUpdateFailed()`), siempre como custom errors.

---

## 6. Gobernanza de fases (autorización obligatoria)

| Regla | Detalle |
|-------|---------|
| **Gate** | No se escribe código de una fase hasta que digas explícitamente: *“autorizo Fase N”* (o equivalente). |
| **Entrega** | Al cerrar una fase: checklist de aceptación + resumen de archivos tocados. |
| **Bloqueo** | Si aparece alcance nuevo, se documenta y se espera nueva autorización. |
| **TDD** | Dentro de cada fase de contratos: tests primero, luego implementación. |

### Tablero de fases

| Fase | Nombre | Estado | Autorización |
|------|--------|--------|--------------|
| 0 | Setup Foundry + estructura + deps Chainlink/Pyth | ⏳ Pendiente | ❌ Sin autorizar |
| 1 | Interfaces + errors + `OracleValidationLib` + `PriceScalerLib` | ⏳ Pendiente | ❌ Sin autorizar |
| 2 | `MockAggregatorV3` + `MockPyth` | ⏳ Pendiente | ❌ Sin autorizar |
| 3 | `ChainlinkPriceFeed` (Push + validaciones) | ⏳ Pendiente | ❌ Sin autorizar |
| 4 | `PythPriceFeed` (Pull + fee + update) | ⏳ Pendiente | ❌ Sin autorizar |
| 5 | `PriceOracleConsumer` + suite e2e / fork / fuzz | ⏳ Pendiente | ❌ Sin autorizar |
| 6 | Gas profiling + Deploy + NatSpec / SWC hardening | ⏳ Pendiente | ❌ Sin autorizar |

> **Doc gate (esta entrega):** la carpeta `doc/` con plan + diagramas ya está creada.  
> **Próxima autorización solicitada:** *Fase 0* (setup Foundry).

---

## 7. Detalle por fase

### Fase 0 — Setup Foundry ⏳

**Objetivo:** repo compilable con tooling y dependencias de oráculos fijadas.

1. Estructura Foundry compatible con la suite (`forge init` o scaffold mínimo).
2. `foundry.toml`: solc `0.8.24`, fuzz runs ≥ 1000, sección `[rpc_endpoints]` para fork.
3. Dependencias: `forge-std`, OpenZeppelin v5, interfaces Chainlink y/o Pyth (versión documentada).
4. Carpetas `src/{consumer,feeds,mocks,libraries,interfaces,errors}`, `test/{fork,fuzz,gas}`, `script/`, `doc/`.

**Criterio de salida:** `forge build` OK; versiones de deps escritas en esta sección.

**Autorización:** esperar *“autorizo Fase 0”*.

---

### Fase 1 — Interfaces + libs de validación ⏳

**Objetivo:** tipos y reglas de validación reutilizables.

1. `IPriceFeed`, aliases/interfaces AggregatorV3 y Pyth.
2. `OracleErrors.sol` con errores obligatorios del módulo.
3. `OracleValidationLib`: staleness, `answeredInRound`, `updatedAt == 0`, bounds.
4. `PriceScalerLib`: escalado de decimales con tests.
5. Tests unitarios + fuzz de delays y precios.

**Criterio de salida:** libs en verde; reverts correctos ante precio stale / inválido / round incompleto.

**Autorización:** esperar *“autorizo Fase 1”*.

---

### Fase 2 — Mocks ⏳

**Objetivo:** oráculos controlables para unit tests sin mainnet.

1. Tests primero: set answer, set timestamp, set round incompleto.
2. `MockAggregatorV3` compatible con `latestRoundData` / `getRoundData` / `decimals`.
3. `MockPyth`: fee fijo, `updatePriceFeeds`, `getPrice` / `getPriceNoOlderThan`.

**Criterio de salida:** mocks permiten forzar todos los caminos de error del módulo.

**Autorización:** esperar *“autorizo Fase 2”*.

---

### Fase 3 — ChainlinkPriceFeed (Push) ⏳

**Objetivo:** lectura segura de AggregatorV3.

1. Tests: stale → `StalePriceFeed`; round incompleto → `OracleRoundIncomplete`; fuera de bounds / ≤0 → `InvalidOraclePrice`.
2. Implementar wrapper Push con `MAX_DELAY`, `minAnswer`, `maxAnswer`.
3. NatSpec + immutables donde aplique.

**Criterio de salida:** camino feliz + todos los reverts de validación Push en verde.

**Autorización:** esperar *“autorizo Fase 3”*.

---

### Fase 4 — PythPriceFeed (Pull) ⏳

**Objetivo:** actualización on-demand con fee y verificación vía mock/contrato Pyth.

1. Tests: fee insuficiente → `InsufficientFee`; precio viejo → `StalePriceFeed`; update + read OK.
2. Flujo: `getUpdateFee` → `updatePriceFeeds{value: fee}` → leer precio → validar edad/bounds.
3. Refund de ETH sobrante si aplica (CEI).

**Criterio de salida:** Pull e2e con mock; rechazos de fee/staleness/bounds cubiertos.

**Autorización:** esperar *“autorizo Fase 4”*.

---

### Fase 5 — Consumer + fork + fuzz ⏳

**Objetivo:** requisitos de testing del `.cursorrules` del módulo.

| Tipo | Qué valida |
|------|------------|
| Unit e2e | Consumer Push/Pull vía mocks |
| Fork | Lectura de feed Chainlink mainnet (ETH/USD u otro documentado) |
| Stale / zero / negative | Reverts explícitos |
| Fuzz | answers, decimals 8↔18, delays |

**Criterio de salida:** `forge test` verde; fork documentado (RPC); fuzz ≥ 1000 runs.

**Autorización:** esperar *“autorizo Fase 5”*.

---

### Fase 6 — Gas + Deploy + hardening ⏳

1. `script/Deploy.s.sol` (feeds + consumer; addresses de mainnet en comments/env).
2. `test/gas/Oracle.gas.t.sol` + `.gas-snapshot`.
3. NatSpec completo; `doc/SWC-AUDIT.md` y `doc/GAS.md` al estilo de módulos previos.

**Criterio de salida:** deploy local reproducible + docs de seguridad + gas documentado.

**Autorización:** esperar *“autorizo Fase 6”*.

---

## 8. Matriz de pruebas (objetivo global)

| Caso | Qué valida |
|------|------------|
| Push feliz | `latestRoundData` válido → precio OK |
| Stale | `updatedAt` viejo → `StalePriceFeed` |
| Round incompleto | `answeredInRound < roundId` → `OracleRoundIncomplete` |
| Bounds / zero / negative | → `InvalidOraclePrice` |
| Pull + fee | update + read; fee baja → `InsufficientFee` |
| Fork Chainlink | Precio live en mainnet fork |
| Fuzz answer / delay / decimals | Sin panics; reverts esperados |
| Gas profiling | Coste Push vs Pull documentado |

---

## 9. Seguridad (checklist vivo)

- [ ] Staleness: `block.timestamp - updatedAt > MAX_DELAY` → revert.
- [ ] `updatedAt == 0` → revert.
- [ ] `answeredInRound < roundId` → revert.
- [ ] Bounds `minAnswer` / `maxAnswer` y rechazo de precio ≤ 0.
- [ ] Pull: fee pagado antes de leer estado post-update.
- [ ] Custom errors del módulo.
- [ ] Sin floating pragma; NatSpec en APIs públicas.
- [ ] Suite fork + fuzz.
- [ ] (Fase 6) SWC-AUDIT + gas.

---

## 10. Entregables de documentación (`doc/`)

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| `README.md` | Índice de esta carpeta | ✅ |
| `planificacion.md` | Este documento (fases + gates) | ✅ |
| `diagrama-de-clases.md` | Estructura y relaciones | ✅ |
| `diagrama-de-flujo.md` | Flujos de decisión | ✅ |
| `flujograma.md` | Flujos actor–sistema e2e | ✅ |
| `SWC-AUDIT.md` | Matriz SWC-100–136 | ⏳ Fase 6 |
| `GAS.md` | Optimizaciones y benchmarks | ⏳ Fase 6 |

---

## 11. Criterios de aceptación del módulo

1. [ ] Compila con `pragma solidity 0.8.24`.
2. [ ] Push (Chainlink) y Pull (Pyth) operativos con tests.
3. [ ] Precios stale / round incompleto / inválidos revierten con custom errors.
4. [ ] Fee Pyth insuficiente → `InsufficientFee`.
5. [ ] Fork test de feed mainnet en verde (con RPC).
6. [ ] Fuzz de answers / delays / decimals en verde.
7. [ ] NatSpec + custom errors en APIs públicas.
8. [ ] `doc/SWC-AUDIT.md` sin vulnerabilidades en alcance v1.

---

## 12. Próximo paso

**Esperando autorización de Fase 0** (setup Foundry + estructura + deps).

Responde con: **`autorizo Fase 0`** para iniciar el scaffold. No se implementará código de fases posteriores sin un gate explícito nuevo.
