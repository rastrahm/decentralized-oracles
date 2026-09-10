# Auditoría SWC — Decentralized Oracles (Push / Pull)

Verificación del consumidor de precios y wrappers Chainlink/Pyth contra el [SWC Registry](https://swcregistry.io/) (EIP-1470) y principios del monorepo (custom errors, pragma fijo, staleness, bounds, fee Pull).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS), [EEA EthTrust](https://entethalliance.org/specs/ethtrust/) y guías de [Chainlink](https://docs.chain.link/data-feeds/price-feeds) / [Pyth](https://docs.pyth.network/).

**Contratos auditados (prod / core):**  
`src/consumer/PriceOracleConsumer.sol`, `src/feeds/ChainlinkPriceFeed.sol`, `src/feeds/PythPriceFeed.sol`,  
`src/libraries/OracleValidationLib.sol`, `src/libraries/PriceScalerLib.sol`,  
`src/interfaces/IPriceFeed.sol`, `src/errors/OracleErrors.sol`

**Dependencias de confianza (fuera de alcance de bugs propios):**  
Chainlink `AggregatorV3Interface` (brownie-contracts 1.3.0), `@pythnetwork/pyth-sdk-solidity` 4.2.0 (`IPyth` / AbstractPyth)

**Mocks (fuera de prod):** `src/mocks/*`  
**Fecha:** 2026-09-10  
**Referencia tests:** `test/ChainlinkPriceFeed.t.sol`, `test/PythPriceFeed.t.sol`, `test/PriceOracleConsumer.t.sol`,  
`test/OracleValidationLib.t.sol`, `test/PriceScalerLib.t.sol`, `test/fork/`, `test/fuzz/`, `test/gas/`  
**Estilo:** alineado a [`12-account-abstraction/doc/SWC-AUDIT.md`](../../12-account-abstraction/doc/SWC-AUDIT.md)  
**Índice docs:** [`README.md`](./README.md) · README módulo: [`../README.md`](../README.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 31 |
| ⚠️ Informativo (diseño / trust / ops) | 5 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance v1 (Push Chainlink + Pull Pyth + consumer). El módulo **rechaza precios stale, rounds incompletos, `updatedAt == 0`, precios ≤ 0 y fuera de bounds**; en Pull exige fee (`InsufficientFee`) antes de `updatePriceFeeds` y refunde el exceso con `.call`. Riesgos informativos: dependencia de `block.timestamp` para staleness, trust en el aggregator/Pyth desplegado, y bounds/config inmutables post-deploy.

**Principios del suite / módulo 13 verificados:**

| Principio | Estado |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `OracleErrors` |
| Pragma fijo `0.8.24` | ✅ |
| Staleness + `updatedAt == 0` + round incompleto | ✅ `OracleValidationLib` |
| Bounds `minAnswer` / `maxAnswer` + answer > 0 | ✅ |
| Pull: `getUpdateFee` → update → validate → refund | ✅ CEI sobre exceso |
| ETH solo vía `.call{value}` | ✅ |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/` |
| Fork Chainlink mainnet (opcional RPC) | ✅ `test/fork/` |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en Oracles |
|----|--------|--------|--------|----------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en `src/` |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; `PriceScalerLib` guarda overflow al escalar |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`) |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | Refunds checan `ok` → `EthTransferFailed` |
| SWC-105 | Unprotected Ether Withdrawal | Sí | ✅ | Sin withdraw libre; ETH solo fee Pyth + refund al `msg.sender` |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Parcial | ✅ | Pull: update externo luego validate luego refund; consumer paga fee exacto al feed; sin callbacks en mocks de prod path |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | `public` / `private` / `immutable` explícitos |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | Sin `delegatecall` |
| SWC-113 | DoS with Failed Call | Sí | ✅ | Refund fallido → `EthTransferFailed` (no deja ETH atrapado silenciosamente en el path feliz) |
| SWC-114 | Transaction Order Dependence | Sí | ⚠️ | Relayers Pull / keepers Push; ver riesgos |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth por config immutable + validación de datos |
| SWC-116 | Block values as a proxy for time | Sí | ⚠️ | Staleness usa `block.timestamp` vs `updatedAt`/`publishTime` |
| SWC-117 | Signature Malleability | Parcial | ✅ | Firmas Pyth verificadas en contrato Pyth (dep); módulo no parsea firmas propias |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing de estado en core |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG |
| SWC-121 | Missing Protection against Signature Replay | Parcial | ✅ | Replay de payload Pyth: el contrato Pyth ignora `publishTime` no más reciente |
| SWC-122 | Lack of Proper Signature Verification | Parcial | ✅ | Verificación en `IPyth` (trust dep); consumer no acepta precio sin pasar por feed |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + unit/e2e/fuzz/fork |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | Sin assembly de storage |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | `IPriceFeed` en feeds; consumer composición |
| SWC-126 | Insufficient Gas Griefing | Parcial | ⚠️ | Update Pyth con payload grande puede ser costoso (ops) |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Parcial | ⚠️ | Arrays `updateData` muy grandes → OOG (caller) |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge build` / suite PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII en `src/` |
| SWC-131 | Presence of unused variables | Sí | ✅ | Sin dead code material en core |
| SWC-132 | Unexpected Ether balance | Parcial | ✅ | Consumer no retiene fee (paga exacto); exceso se refunde |
| SWC-133 | Hash Collisions (var-length args) | No | N/A | Sin hashing de args variables en core |
| SWC-134 | Message call with hardcoded gas | No | N/A | `.call{value}` sin gas hardcodeado restrictivo |
| SWC-135 | Code With No Effects | No | N/A | Sin no-ops relevantes |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ✅ | Precios / eventos públicos por diseño de oráculos |

---

## Riesgos informativos

### SWC-116 — `block.timestamp` para staleness

Push y Pull comparan `updatedAt` / `publishTime` contra `block.timestamp`. Es el patrón estándar de oráculos on-chain; miners pueden sesgar segundos. Mitigación: `maxDelay`/`maxAge` conservadores y bounds de precio.

### SWC-114 — Orden / relayers

En Pull, quien aporta `updateData` elige el momento del update. Front-running de liquidaciones que dependen del precio es riesgo de dominio DeFi, no un bypass de validación del módulo. Mitigación a nivel protocolo consumidor (fuera de v1).

### SWC-126 / SWC-128 — tamaño de `updateData`

Payloads Pyth grandes aumentan fee y gas. Responsabilidad del caller / relayer.

### Centralización / trust post-deploy

| Tema | Riesgo | Tratamiento v1 |
|------|--------|----------------|
| `aggregator` / `pyth` immutable | Address incorrecta = feed inutilizable o malicioso | Deploy script + verificación (mainnet ETH/USD documentado) |
| Bounds / `maxDelay` immutable | No se puede retunar on-chain | Redeploy; documentar márgenes |
| Precio Pyth ya on-chain stale | `getValidatedPrice` view revierte | Forzar `updateAndGetPrice` en hot paths |
| MockPyth en tests | No es el wire format mainnet | Fork/unit separados; mocks solo test |

---

## Checklist principios monorepo (+ módulo 13)

| Principio | ¿Cumple? | Notas |
|-----------|----------|--------|
| Custom errors | ✅ | `StalePriceFeed`, `InvalidOraclePrice`, `OracleRoundIncomplete`, `InsufficientFee`, … |
| Staleness / round / bounds | ✅ | `OracleValidationLib` |
| Pull fee antes de leer | ✅ | `PythPriceFeed` + consumer |
| NatSpec públicas/externas | ✅ | Core + libs |
| Fuzz ≥ 1000 runs | ✅ | `test/fuzz/Oracle.fuzz.t.sol` |
| Fork mainnet opcional | ✅ | `test/fork/ChainlinkMainnet.fork.t.sol` |
| Sin floating pragma | ✅ | `0.8.24` |
| Sin ETH `transfer`/`send` | ✅ | Solo `.call{value}` |
| Gas profiling Push vs Pull | ✅ | `doc/GAS.md` |

---

## Hallazgos de verificación (código)

### Mitigaciones confirmadas

1. **ChainlinkPriceFeed:** immutables; `validateAggregatorRound` (round, freshness, answer > 0, bounds).
2. **PythPriceFeed:** fee check → `updatePriceFeeds` → validate → refund; `EthTransferFailed` si refund falla.
3. **PriceOracleConsumer:** fee exacto al pull feed; exceso refund al caller original (no se queda ETH en el consumer).
4. **OracleValidationLib / PriceScalerLib:** reglas compartidas + overflow guard en scale-up.
5. **E2E / fuzz / fork:** caminos stale, zero/neg, fee, scale 8↔18; ETH/USD mainnet si hay RPC.

### Hardening Fase 6

| # | Cambio | Motivo |
|---|--------|--------|
| 1 | `script/Deploy.s.sol` | Deploy reproducible local / cableado env mainnet |
| 2 | `test/gas/Oracle.gas.t.sol` + `.gas-snapshot` | Push vs Pull vs raw |
| 3 | `doc/SWC-AUDIT.md` / `doc/GAS.md` | Matriz SWC-100–136 + benchmarks |
| 4 | README módulo | Operación / env / estructura |

### Observaciones no bloqueantes (v2)

| # | Observación | Severidad | Acción sugerida |
|---|-------------|-----------|-----------------|
| 1 | Bounds / delay no upgradeables | Info | Ownable2Step + setters o proxy |
| 2 | Sin heartbeat explícito de Chainlink (solo `updatedAt`) | Info | Combinar con `heartbeat` del feed docs |
| 3 | Pull mainnet e2e con Hermes payload real | Mejora | Test de integración off-chain |
| 4 | Invariantes Foundry formales | Mejora | Handler sobre mocks |

---

## Mapeo SWC → tests

| SWC | Test(s) |
|-----|---------|
| SWC-101 | `PriceScalerLib` overflow + fuzz scale |
| SWC-103 | `forge build` pragma fijo |
| SWC-104 / 105 | refund paths `PythPriceFeed` / `PriceOracleConsumer` |
| SWC-107 | e2e pull fee exacto + refund caller |
| SWC-116 | stale unit + fuzz delays |
| SWC-123 | unit + e2e + fuzz + fork |
| Stale / round / bounds | `ChainlinkPriceFeed.t.sol`, `OracleValidationLib.t.sol` |
| Fee Pull | `PythPriceFeed.t.sol`, `PriceOracleConsumer.t.sol` |
| Fork | `test/fork/ChainlinkMainnet.fork.t.sol` |

---

## Resultado de ejecución

```text
forge test --summary
# 2026-09-10 Fase 6
OracleValidationLibTest       21 PASS (+ fuzz 1000)
PriceScalerLibTest             9 PASS (+ fuzz 1000)
MockAggregatorV3Test           8 PASS (+ fuzz 1000)
MockPythTest                  11 PASS (+ fuzz 1000)
ChainlinkPriceFeedTest        16 PASS (+ fuzz 1000)
PythPriceFeedTest             16 PASS (+ fuzz 1000)
PriceOracleConsumerTest        9 PASS
OracleFuzzTest                 6 PASS (1000 runs c/u)
OracleGasTest                  6 PASS
ChainlinkMainnetForkTest       3 SKIP (sin MAINNET_RPC_URL) / PASS con RPC
Total: 102 PASS / 0 FAIL / 3 SKIP
```

---

## Referencias

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
- [Pyth EVM Pull](https://docs.pyth.network/price-feeds/core/use-real-time-data/pull-integration/evm)
- Módulo 12: [`12-account-abstraction/doc/SWC-AUDIT.md`](../../12-account-abstraction/doc/SWC-AUDIT.md)
- Gas: [`GAS.md`](./GAS.md)
- Plan: [`planificacion.md`](./planificacion.md)
