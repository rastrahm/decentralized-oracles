# Planificación — Módulo 13: Decentralized Oracles & Pyth/Chainlink Push-Pull

**Estado:** Fases **0–6** ✅ completadas. Módulo cerrado a nivel de planificación v1.  
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
- OpenZeppelin Contracts v5.x disponible (v1 no usa Ownable; config **immutable**).
- Foundry: unit + fuzz (`runs >= 1000`) + fork tests + gas reports.
- Custom errors (no `require` con strings).
- CEI en paths Pull (fee → update → validate → refund).
- NatSpec en toda API pública/externa.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.

### Módulo 13 (Oracles) — implementado

- Push: `latestRoundData()`; rechazar si `answeredInRound < roundId`, `updatedAt == 0`/futuro, o stale.
- Bounds: precio ≤ 0 o fuera de `[minAnswer, maxAnswer]` → `InvalidOraclePrice`.
- Pull: `getUpdateFee` → `updatePriceFeeds{value: fee}` → `getPriceUnsafe` + `validatePullPrice`.
- Fee insuficiente → `InsufficientFee`; refund fallido → `EthTransferFailed`.
- Escalado 8 → 18 en `PriceScalerLib` vía consumer (`*Scaled18`).
- Chainlink/Pyth: remappings (`lib/` + `node_modules/`), sin copias locales de interfaces vendor.

---

## 4. Arquitectura (final v1)

```
13-decentralized-oracles/
├── README.md
├── doc/
│   ├── README.md
│   ├── planificacion.md
│   ├── diagrama-de-clases.md
│   ├── diagrama-de-flujo.md
│   ├── flujograma.md
│   ├── SWC-AUDIT.md
│   └── GAS.md
├── src/
│   ├── consumer/PriceOracleConsumer.sol
│   ├── feeds/
│   │   ├── ChainlinkPriceFeed.sol
│   │   └── PythPriceFeed.sol
│   ├── mocks/
│   │   ├── MockAggregatorV3.sol
│   │   └── MockPyth.sol
│   ├── libraries/
│   │   ├── OracleValidationLib.sol
│   │   └── PriceScalerLib.sol
│   ├── interfaces/IPriceFeed.sol
│   └── errors/OracleErrors.sol
├── test/
│   ├── helpers/OracleTestBase.sol
│   ├── OracleValidationLib.t.sol
│   ├── PriceScalerLib.t.sol
│   ├── MockAggregatorV3.t.sol
│   ├── MockPyth.t.sol
│   ├── ChainlinkPriceFeed.t.sol
│   ├── PythPriceFeed.t.sol
│   ├── PriceOracleConsumer.t.sol
│   ├── fork/ChainlinkMainnet.fork.t.sol
│   ├── fuzz/Oracle.fuzz.t.sol
│   └── gas/Oracle.gas.t.sol
├── script/Deploy.s.sol
├── foundry.toml
├── remappings.txt
├── package.json                  # @pythnetwork/pyth-sdk-solidity
├── .env.example
└── .gas-snapshot
```

### Contratos y responsabilidades

| Contrato / artefacto | Responsabilidad |
|----------------------|-----------------|
| `IPriceFeed` | `decimals()` + `getValidatedPrice()` |
| `ChainlinkPriceFeed` | Push AggregatorV3 + validación; alias `latestPrice()` |
| `PythPriceFeed` | Pull: fee → update → validate → refund |
| `PriceOracleConsumer` | Fachada Push/Pull + `*Scaled18`; fee exacto + refund caller |
| `MockAggregatorV3` | Rounds/timestamps/answers controlables |
| `MockPyth` | Wrapper SDK MockPyth + `createUpdateData` / `setPrice` |
| `OracleValidationLib` | Round, freshness, answer, bounds, pipelines Push/Pull |
| `PriceScalerLib` | Escalado 8 ↔ 18 con guarda overflow |
| `OracleErrors` | Custom errors del módulo |

---

## 5. Errores custom (módulo)

```solidity
error StalePriceFeed();
error InvalidOraclePrice();
error OracleRoundIncomplete();
error InsufficientFee();
error ZeroAddress();
error InvalidOracleConfig();
error EthTransferFailed();
```

Obligatorios del `.cursorrules`: los cuatro primeros. Los tres siguientes se añadieron en implementación (config, zero address, refund).

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
| 0 | Setup Foundry + estructura + deps Chainlink/Pyth | ✅ Completada | ✅ Autorizada |
| 1 | Interfaces + errors + `OracleValidationLib` + `PriceScalerLib` | ✅ Completada | ✅ Autorizada |
| 2 | `MockAggregatorV3` + `MockPyth` | ✅ Completada | ✅ Autorizada |
| 3 | `ChainlinkPriceFeed` (Push + validaciones) | ✅ Completada | ✅ Autorizada |
| 4 | `PythPriceFeed` (Pull + fee + update) | ✅ Completada | ✅ Autorizada |
| 5 | `PriceOracleConsumer` + suite e2e / fork / fuzz | ✅ Completada | ✅ Autorizada |
| 6 | Gas profiling + Deploy + NatSpec / SWC hardening | ✅ Completada | ✅ Autorizada |

> **Módulo v1 cerrado.** Extensiones futuras: ver §12.

---

## 7. Detalle por fase

### Fase 0 — Setup Foundry ✅

**Objetivo:** repo compilable con tooling y dependencias de oráculos fijadas.

1. Estructura Foundry compatible con la suite (`forge init` o scaffold mínimo).
2. `foundry.toml`: solc `0.8.24`, fuzz runs ≥ 1000, sección `[rpc_endpoints]` para fork.
3. Dependencias: `forge-std`, OpenZeppelin v5, interfaces Chainlink y/o Pyth (versión documentada).
4. Carpetas `src/{consumer,feeds,mocks,libraries,interfaces,errors}`, `test/{fork,fuzz,gas}`, `script/`, `doc/`.

**Criterio de salida:** `forge build` OK; versiones de deps escritas en esta sección.

**Hecho (2026-09-10):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer, fuzz `runs = 1000`, `[rpc_endpoints].mainnet = ${MAINNET_RPC_URL}`) + `remappings.txt`.
- Dependencias en `lib/` (gitignored): `forge-std`, OpenZeppelin **v5.2.0**, `chainlink-brownie-contracts` **1.3.0** (`AggregatorV3Interface`).
- Pyth vía npm (oficial): `@pythnetwork/pyth-sdk-solidity` **4.2.0** (`IPyth`, `MockPyth`, etc.) + `package.json` / `package-lock.json`.
- Carpetas `src/{consumer,feeds,mocks,libraries,interfaces,errors}`, `test/{helpers,fork,fuzz,gas}`, `script/`, `.env.example`.
- Stub `src/Placeholder.sol` + smoke `test/Placeholder.t.sol` (incluye check de remappings).
- Stub `script/Deploy.s.sol` (Fase 6).
- `forge build` y `forge test` en verde (**2 PASS**).
- Nota: usar `~/.foundry/bin/forge` (el `forge` de nvm/npm no es Foundry).

---

### Fase 1 — Interfaces + libs de validación ✅

**Objetivo:** tipos y reglas de validación reutilizables.

1. `IPriceFeed`, aliases/interfaces AggregatorV3 y Pyth.
2. `OracleErrors.sol` con errores obligatorios del módulo.
3. `OracleValidationLib`: staleness, `answeredInRound`, `updatedAt == 0`, bounds.
4. `PriceScalerLib`: escalado de decimales con tests.
5. Tests unitarios + fuzz de delays y precios.

**Criterio de salida:** libs en verde; reverts correctos ante precio stale / inválido / round incompleto.

**Hecho (2026-09-10):**
- `src/errors/OracleErrors.sol`: `StalePriceFeed`, `InvalidOraclePrice`, `OracleRoundIncomplete`, `InsufficientFee`, `ZeroAddress`, `InvalidOracleConfig`.
- `src/interfaces/IPriceFeed.sol` (API unificada); Chainlink/Pyth vía remappings de Fase 0.
- `OracleValidationLib`: round, freshness (incl. `updatedAt == 0` / futuro), answer > 0, bounds, pipelines Push/Pull.
- `PriceScalerLib`: `scale` / `to18Decimals` con guarda de overflow y max 18 decimals.
- Tests: `OracleValidationLib.t.sol` + `PriceScalerLib.t.sol` (unit + fuzz 1000).
- Stub `Placeholder` eliminado.
- **`forge test` → 30 PASS**.

---

### Fase 2 — Mocks ✅

**Objetivo:** oráculos controlables para unit tests sin mainnet.

1. Tests primero: set answer, set timestamp, set round incompleto.
2. `MockAggregatorV3` compatible con `latestRoundData` / `getRoundData` / `decimals`.
3. `MockPyth`: fee fijo, `updatePriceFeeds`, `getPrice` / `getPriceNoOlderThan`.

**Criterio de salida:** mocks permiten forzar todos los caminos de error del módulo.

**Hecho (2026-09-10):**
- `MockAggregatorV3`: `setRoundData`, `setLatestAnswer`, round incompleto, `updatedAt == 0`, answers negativos; error `RoundNotFound`.
- `MockPyth`: hereda SDK MockPyth (`IPyth` completo); helpers `createUpdateData` / `setPrice`; fee vía `getUpdateFee`; stale con `getPriceNoOlderThan`.
- Tests: `MockAggregatorV3.t.sol` + `MockPyth.t.sol` (unit + fuzz).
- **`forge test` → 49 PASS**.

---

### Fase 3 — ChainlinkPriceFeed (Push) ✅

**Objetivo:** lectura segura de AggregatorV3.

1. Tests: stale → `StalePriceFeed`; round incompleto → `OracleRoundIncomplete`; fuera de bounds / ≤0 → `InvalidOraclePrice`.
2. Implementar wrapper Push con `MAX_DELAY`, `minAnswer`, `maxAnswer`.
3. NatSpec + immutables donde aplique.

**Criterio de salida:** camino feliz + todos los reverts de validación Push en verde.

**Hecho (2026-09-10):**
- `ChainlinkPriceFeed`: immutables `aggregator`, `maxDelay`, `minAnswer`, `maxAnswer`; implementa `IPriceFeed`.
- Constructor: `ZeroAddress` / `InvalidOracleConfig` (maxDelay 0, bounds inválidos).
- `getValidatedPrice` / `latestPrice` vía `OracleValidationLib.validateAggregatorRound`.
- Tests: feliz, stale, `updatedAt == 0`, round incompleto, zero/negativo/bounds, fuzz.
- **`forge test` → 65 PASS**.

---

### Fase 4 — PythPriceFeed (Pull) ✅

**Objetivo:** actualización on-demand con fee y verificación vía mock/contrato Pyth.

1. Tests: fee insuficiente → `InsufficientFee`; precio viejo → `StalePriceFeed`; update + read OK.
2. Flujo: `getUpdateFee` → `updatePriceFeeds{value: fee}` → leer precio → validar edad/bounds.
3. Refund de ETH sobrante si aplica (CEI).

**Criterio de salida:** Pull e2e con mock; rechazos de fee/staleness/bounds cubiertos.

**Hecho (2026-09-10):**
- `PythPriceFeed`: immutables `pyth`, `priceId`, `maxAge`, bounds, `decimals`; implementa `IPriceFeed`.
- `updateAndGetPrice`: check fee → `updatePriceFeeds` → `_readAndValidate` → refund exceso (`EthTransferFailed` si falla).
- `getValidatedPrice`: lectura view post-update con `OracleValidationLib.validatePullPrice`.
- Error nuevo: `EthTransferFailed` en `OracleErrors`.
- Tests: fee, refund, stale, bounds, zero/negativo, fuzz.
- **`forge test` → 81 PASS**.

---

### Fase 5 — Consumer + fork + fuzz ✅

**Objetivo:** requisitos de testing del `.cursorrules` del módulo.

| Tipo | Qué valida |
|------|------------|
| Unit e2e | Consumer Push/Pull vía mocks |
| Fork | Lectura de feed Chainlink mainnet (ETH/USD u otro documentado) |
| Stale / zero / negative | Reverts explícitos |
| Fuzz | answers, decimals 8↔18, delays |

**Criterio de salida:** `forge test` verde; fork documentado (RPC); fuzz ≥ 1000 runs.

**Hecho (2026-09-10):**
- `PriceOracleConsumer`: `getPushPrice`, `getPullPrice`, scaled18; fee exacto al Pull + refund al caller.
- E2E: `PriceOracleConsumer.t.sol` (push/pull, stale, zero/neg, fee, refund).
- Fork: `test/fork/ChainlinkMainnet.fork.t.sol` — ETH/USD `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`; skip sin `MAINNET_RPC_URL`.
- Fuzz: `test/fuzz/Oracle.fuzz.t.sol` (answers, delays, rounds, scale 8↔18).
- Helper: `test/helpers/OracleTestBase.sol`.
- **`forge test` → 96 PASS**, 3 SKIP (fork sin RPC).

---

### Fase 6 — Gas + Deploy + hardening ✅

1. `script/Deploy.s.sol` (feeds + consumer; addresses de mainnet en comments/env).
2. `test/gas/Oracle.gas.t.sol` + `.gas-snapshot`.
3. NatSpec completo; `doc/SWC-AUDIT.md` y `doc/GAS.md` al estilo de módulos previos.

**Criterio de salida:** deploy local reproducible + docs de seguridad + gas documentado.

**Hecho (2026-09-10):**
- `script/Deploy.s.sol` — mocks locales o `CHAINLINK_AGGREGATOR` / `PYTH` / `PYTH_PRICE_ID` vía env; ref mainnet ETH/USD.
- `test/gas/Oracle.gas.t.sol` + `.gas-snapshot` — raw ~16k, Push ~20–25k, Pull ~167–170k.
- `doc/SWC-AUDIT.md` (matriz SWC-100–136, estilo módulo 12): **0 vulnerabilidades**; 5 informativos.
- `doc/GAS.md` + `README.md` raíz del módulo.
- **`forge test` → 102 PASS**, 3 SKIP (fork sin RPC).

---

## 8. Matriz de pruebas (v1 — cubierta)

| Caso | Qué valida | Suite |
|------|------------|-------|
| Push feliz | `latestRoundData` válido → precio OK | `ChainlinkPriceFeed` / consumer |
| Stale | `updatedAt` viejo → `StalePriceFeed` | unit + fuzz |
| Round incompleto | `answeredInRound < roundId` → `OracleRoundIncomplete` | unit + fuzz |
| Bounds / zero / negative | → `InvalidOraclePrice` | unit + fuzz |
| Pull + fee | update + read; fee baja → `InsufficientFee` | `PythPriceFeed` / consumer |
| Pull refund | exceso ETH vuelve al caller | consumer e2e |
| Scale 8↔18 | `PriceScalerLib` / `*Scaled18` | unit + fuzz |
| Fork Chainlink | ETH/USD mainnet | `ChainlinkMainnet.fork.t.sol` |
| Gas profiling | Push vs Pull documentado | `Oracle.gas.t.sol` + `GAS.md` |

---

## 9. Seguridad (checklist vivo)

- [x] Staleness: `block.timestamp - updatedAt > MAX_DELAY` → revert.
- [x] `updatedAt == 0` → revert.
- [x] `answeredInRound < roundId` → revert.
- [x] Bounds `minAnswer` / `maxAnswer` y rechazo de precio ≤ 0.
- [x] Pull: fee pagado antes de leer estado post-update.
- [x] Custom errors del módulo.
- [x] Sin floating pragma; NatSpec en APIs públicas.
- [x] Suite fork + fuzz.
- [x] (Fase 6) SWC-AUDIT + gas.

---

## 10. Entregables de documentación (`doc/`)

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| `README.md` | Índice de esta carpeta | ✅ |
| `planificacion.md` | Este documento (fases + gates) | ✅ |
| `diagrama-de-clases.md` | Estructura y relaciones | ✅ |
| `diagrama-de-flujo.md` | Flujos de decisión | ✅ |
| `flujograma.md` | Flujos actor–sistema e2e | ✅ |
| `SWC-AUDIT.md` | Matriz SWC-100–136 | ✅ |
| `GAS.md` | Optimizaciones y benchmarks | ✅ |

---

## 11. Criterios de aceptación del módulo

1. [x] Compila con `pragma solidity 0.8.24`.
2. [x] Push (Chainlink) y Pull (Pyth) operativos con tests.
3. [x] Precios stale / round incompleto / inválidos revierten con custom errors.
4. [x] Fee Pyth insuficiente → `InsufficientFee`.
5. [x] Fork test de feed mainnet en verde (con RPC).
6. [x] Fuzz de answers / delays / decimals en verde.
7. [x] NatSpec + custom errors en APIs públicas.
8. [x] `doc/SWC-AUDIT.md` sin vulnerabilidades en alcance v1.

---

## 12. Próximo paso

**Módulo v1 completo (Fases 0–6).** Posibles extensiones: bounds upgradeables, heartbeat Chainlink explícito, e2e Pull mainnet con payload Hermes, invariantes Foundry, multisig/timelock en config.

**Nota:** usa `~/.foundry/bin/forge` (o antepón `$HOME/.foundry/bin` al `PATH`); el `forge` de nvm/npm no es Foundry.
