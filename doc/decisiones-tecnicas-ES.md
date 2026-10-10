# Decisiones técnicas, lógica y gas — Módulo 13
> English version: [decisiones-tecnicas-EN.md](./decisiones-tecnicas-EN.md)

Documento de lectura para entender **por qué** está armado así el proyecto, **qué flujo** sigue un precio hasta el protocolo, y **dónde** aún se puede ahorrar gas (unidad de coste de ejecución en Ethereum).

Complementa: [`GAS-ES.md`](./GAS-ES.md) · [`flujograma-ES.md`](./flujograma-ES.md) · [`SWC-AUDIT-ES.md`](./SWC-AUDIT-ES.md) (auditoría según la *Smart Contract Weakness Classification*, clasificación de debilidades de contratos inteligentes).

---

## 1. Qué problema resuelve

Los protocolos de finanzas descentralizadas (*Decentralized Finance*) no pueden “confiar” a ciegas en un precio ya publicado en la cadena (on-chain):

| Riesgo | Defensa en este módulo |
|--------|------------------------|
| Precio viejo (staleness / caducidad) | `maxDelay` / `maxAge` + error `StalePriceFeed` |
| Ronda incompleta (Chainlink) | `answeredInRound >= roundId` |
| Precio cero / negativo / caída brusca (*flash crash*) | `answer > 0` + `minAnswer` / `maxAnswer` |
| Modelo Pull sin pagar la tarifa / Ether colgado en el contrato | `InsufficientFee` + devolución del exceso |
| Decimales distintos (8 frente a 18) | `PriceScalerLib` solo en el consumidor |

El módulo no es “otro Chainlink”: es una **capa de consumo segura** encima del modelo Push (empujar datos; Chainlink) y Pull (tirar / traer datos bajo demanda; Pyth).

---

## 2. Decisiones técnicas (y por qué)

### 2.1 Dos arquitecturas, una fachada

| Decisión | Alternativa descartada | Motivo |
|----------|------------------------|--------|
| Separar `ChainlinkPriceFeed` y `PythPriceFeed` | Un solo contrato “oráculo genérico” | Push es solo lectura (`view`); Pull es `payable` (acepta Ether) + escritura. Mezclarlos oscurece el patrón Checks-Effects-Interactions (comprobar → efectos → interacciones externas) y el manejo de tarifas. |
| `PriceOracleConsumer` como fachada | Que cada aplicación descentralizada hable directo a los feeds | Interfaz de uso estable (`getPush*` / `getPull*`), escala a 18 decimales, un solo punto de cableado. |
| Ambos feeds implementan `IPriceFeed` | Interfaces distintas sin nada en común | `getValidatedPrice()` + `decimals()` unifican la lectura ya on-chain. Pull añade `updateAndGetPrice`. |

### 2.2 Validación centralizada en biblioteca (*library*)

`OracleValidationLib` concentra:

1. Ronda completa (solo Push)
2. Frescura del dato (`updatedAt` / `publishTime`)
3. Precio estrictamente mayor que cero
4. Límites permitidos `[minAnswer, maxAnswer]`

**Por qué biblioteca y no modificadores en cada feed:** reutilización Push/Pull, el optimizador del compilador puede insertar el código en línea (*inlining*), y se pueden probar las reglas de seguridad sin desplegar los feeds.

### 2.3 Configuración inmutable (sin funciones *setter*)

`aggregator`, `pyth`, `priceId`, retardos máximos, límites de precio y decimales (Pyth) son `immutable` (fijos en el despliegue).

| Ventajas | Contras aceptados |
|----------|-------------------|
| Cero lecturas de almacenamiento (`SLOAD`, *storage load*) de configuración en la ruta crítica | Retocar parámetros = volver a desplegar |
| Sin gobernanza / sin clave de administrador en la versión 1 | No hay “pausar oráculo” on-chain |

Alineado con el alcance del módulo (consumidor + validación, no una organización autónoma descentralizada).

### 2.4 Push frente a Pull: modelo de datos

```text
PUSH — empujar (Chainlink)
  Red fuera de cadena → escribe rondas en AggregatorV3
  Consumidor on-chain → solo LEE latestRoundData + valida
  Coste: ~lectura view + validación (~20 000 gas en la captura de referencia)

PULL — tirar / traer bajo demanda (Pyth)
  Fuera de cadena: obtienes priceUpdateData firmado
  On-chain: PAGAS tarifa → updatePriceFeeds → LEES → validas
  Coste: escritura + verificación criptográfica (~170 000 gas en la captura)
```

**Decisión:** no inventar un “Pull de solo lectura barato”. Sin `updatePriceFeeds`, el estado de Pyth puede estar caduco; el modelo del proveedor exige una actualización fresca cuando importa la frescura.

### 2.5 Tarifa exacta en el consumidor

En `PriceOracleConsumer._pull`:

1. `fee = pullFeed.getUpdateFee(updateData)` (tarifa de actualización)
2. Se envía **exactamente** esa tarifa a `updateAndGetPrice`
3. El exceso `msg.value - fee` se devuelve al **llamador** (no queda en el consumidor)

**Por qué:** evita una devolución interna extra en el camino consumidor → feed (menos saltos de llamada). El feed sigue pudiendo devolver Ether si alguien lo llama directo pagando de más.

### 2.6 Escala a 18 decimales solo en el consumidor

Los feeds reportan **decimales nativos** del proveedor (típicamente 8).  
`to18Decimals` vive en `getPushPriceScaled18` / `getPullPriceScaled18`.

**Por qué:** no distorsionar lo que reporta el oráculo; el protocolo elige si necesita unidades `1e18` para la aritmética de finanzas descentralizadas.

### 2.7 Errores personalizados + Solidity 0.8.24

- `StalePriceFeed`, `InvalidOraclePrice`, `OracleRoundIncomplete`, `InsufficientFee`, etc.
- Versión de compilador fija `0.8.24` (suite del curso).
- Foundry: pruebas unitarias + fuzzing (entradas aleatorias) + fork (réplica de red principal) + medición de gas + debilidades documentadas según la clasificación *Smart Contract Weakness Classification*.

### 2.8 Dobles (*mocks*) y dependencias

| Pieza | Rol |
|-------|-----|
| `MockAggregatorV3` | Controlar ronda / respuesta / marca de tiempo en pruebas |
| `MockPyth` | Envoltorio del kit de desarrollo de software de Pyth + ayudas para armar el payload |
| Contratos Chainlink (brownie) + kit de desarrollo Pyth | Interfaces reales, no reinventadas |

---

## 3. Lógica que sigue el sistema

### 3.1 Capas (de fuera hacia dentro)

```text
Protocolo / aplicación descentralizada
    → PriceOracleConsumer          (fachada + escala + tarifa exacta)
        → ChainlinkPriceFeed       (Push — empujar)
            → AggregatorV3         (Chainlink / doble de prueba)
            → OracleValidationLib
        → PythPriceFeed            (Pull — traer bajo demanda)
            → IPyth                (Pyth / doble de prueba)
            → OracleValidationLib
        → PriceScalerLib           (solo funciones *Scaled18*)
```

### 3.2 Flujo Push (lectura)

```text
getPushPrice()
  → pushFeed.getValidatedPrice()
      → aggregator.latestRoundData()
      → validateAggregatorRound(
            ronda completa,
            frescura ≤ maxDelay,
            answer > 0,
            mínimo ≤ answer ≤ máximo
        )
  → return answer   // o *Scaled18 vía PriceScalerLib
```

Si falla cualquier comprobación → la transacción revierte con error personalizado (fallar cerrado: ante duda se rechaza).

### 3.3 Flujo Pull (actualización + lectura)

```text
Fuera de cadena: Hermes / interfaz de consulta → bytes[] updateData

getPullPrice{value: msg.value}(updateData)
  → fee = getUpdateFee(updateData)
  → exigir msg.value >= fee
  → pullFeed.updateAndGetPrice{value: fee}(updateData)
        → pyth.updatePriceFeeds{value: fee}(updateData)
        → getPriceUnsafe(priceId)
        → validatePullPrice(publishTime, maxAge, límites…)
        → (si se pagó de más al feed) devolución al msg.sender del feed
  → devolución (msg.value - fee) al llamador original
  → return price   // o *Scaled18
```

Orden intencional: **tarifa → actualización (interacción externa) → validar → devolver exceso**, según el patrón Checks-Effects-Interactions aplicado al Ether sobrante.

### 3.4 Reglas de validación (núcleo)

| Comprobación | Push | Pull | Error |
|--------------|------|------|-------|
| Ronda completa | `answeredInRound >= roundId` | no aplica | `OracleRoundIncomplete` |
| Marca de tiempo cero / futuro | sí | sí (`publishTime`) | `StalePriceFeed` |
| Edad mayor que el umbral | `maxDelay` | `maxAge` | `StalePriceFeed` |
| `answer <= 0` | sí | sí | `InvalidOraclePrice` |
| Fuera de límites | sí | sí | `InvalidOraclePrice` |

### 3.5 Modelo mental del despliegue

`Deploy.s.sol` cablea:

1. Agregador real **o** `MockAggregatorV3` con precio semilla
2. Pyth real **o** `MockPyth`
3. `ChainlinkPriceFeed` + `PythPriceFeed` (retardos y límites vía variables de entorno)
4. `PriceOracleConsumer(push, pull)`

Sin administrador posterior: la “configuración” es el bytecode más los valores inmutables.

---

## 4. ¿Se puede mejorar el gas de lo que existe?

Sí. Lo ya aplicado y lo opcional (compromisos).

### 4.1 Ya aplicado (línea base)

| Técnica | Efecto |
|---------|--------|
| Valores inmutables de configuración | Evita lectura de almacenamiento en cada lectura de precio |
| Biblioteca + `optimizer_runs = 10_000` + `via_ir` (compilación por representación intermedia) | Insertar validación en línea |
| Errores personalizados | Más barato que `require("texto…")` |
| Tarifa exacta desde el consumidor | Menos devoluciones anidadas |
| `calldata` en `updateData` | Menos copias a memoria |

Números aproximados (ver [`GAS-ES.md`](./GAS-ES.md)):

| Camino | Gas |
|--------|-----|
| Lectura cruda `latestRoundData` | ~16 173 |
| Push validado | ~19 849 |
| Consumidor Push / Scaled18 | ~22 816 / ~24 756 |
| Pull actualizar + validar | ~169 786 |
| Consumidor Pull | ~166 531 |

**Conclusión de magnitud:** el sobrecoste Push (~+4 000 gas sobre la lectura cruda) es el precio de la seguridad. El Pull (~10 veces más) lo domina **`updatePriceFeeds` de Pyth**, no tu envoltorio.

### 4.2 Mejoras posibles (no hechas en la versión 1)

Ordenadas de más realistas a más agresivas:

| Mejora | Ahorro esperado | Compromiso |
|--------|-----------------|------------|
| **Guardar en caché `decimals()` del agregador** como inmutable en `ChainlinkPriceFeed` | ~2 000–5 000 gas en el camino `*Scaled18` (evita llamada externa) | Redeploy si el feed cambia decimales (raro) |
| **Fusionar consumidor + feed Push** en un solo contrato | ~2 000–4 000 gas (un salto de llamada menos) | Pierdes modularidad / reutilizar el feed solo |
| **`getPriceNoOlderThan` de Pyth** en vez de `getPriceUnsafe` + validar frescura propia | Posible menos lógica duplicada; gas similar o ligeramente distinto | Te acoplas más a la interfaz de Pyth; los límites de precio siguen siendo tuyos |
| **Omitir devolución cuando `msg.value == fee`** (ya casi gratis: `if (refund > 0)`) | Ya óptimo en el camino feliz con pago exacto | — |
| **Assembly / unchecked** en `PriceScalerLib` | Marginal (cientos de gas) | Legibilidad / riesgo; el desbordamiento ya está acotado por los límites |
| **No escalar on-chain** (el protocolo escala fuera de esa ruta) | Ahorra aritmética Scaled18 | Cada integrador lo reimplementa |
| **Actualización por lote** de varios `priceId` en una transacción | Amortiza la tarifa fija de Pyth | Fuera del alcance de un solo feed en la versión 1 |
| **Leer Pyth sin actualizar** (`getValidatedPrice` solo) | Muy barato frente a actualizar | Solo válido si otra transacción ya actualizó el feed recientemente |

### 4.3 Qué no conviene “optimizar”

- **Quitar límites / control de caducidad** → ahorro pequeño, riesgo grande (debilidades de la clasificación *Smart Contract Weakness Classification* / exploits de precio).
- **Intentar que Pull cueste como Push** → imposible sin dejar de hacer `updatePriceFeeds`.
- **Almacenamiento mutable de configuración “para no redeploy”** → empeora el gas en la ruta crítica y abre superficie de administración.

### 4.4 Heurística práctica

```text
¿Necesitas frescura garantizada en esta transacción?
  SÍ + Chainlink Push reciente → getPushPrice / Scaled18
  SÍ + Pyth → paga la actualización (~170 000 gas) a conciencia
  NO (otro keeper / mantenedor ya actualizó Pyth)
       → getValidatedPrice() en modo view en PythPriceFeed
```

---

## 5. Resumen ejecutivo

1. **Arquitectura:** envoltorios Push/Pull + consumidor + bibliotecas de validación/escala; configuración inmutable; fallar cerrado con errores personalizados.
2. **Lógica:** Push = leer y validar; Pull = tarifa → actualizar → validar → devolver exceso; escala a 18 decimales opcional en la fachada.
3. **Gas:** Push ya cerca del óptimo seguro; Pull lo limita el proveedor. Mejoras realistas para una versión 2: caché de decimales, menos saltos de llamada, o lectura Pull sin actualizar cuando el dato ya está fresco.

---

## 6. Mapa rápido de archivos

| Archivo | Responsabilidad |
|---------|-----------------|
| `src/consumer/PriceOracleConsumer.sol` | Interfaz hacia el protocolo, tarifa exacta, escala a 18 |
| `src/feeds/ChainlinkPriceFeed.sol` | Push + validación |
| `src/feeds/PythPriceFeed.sol` | Pull: actualizar + validar + devolver exceso |
| `src/libraries/OracleValidationLib.sol` | Reglas de seguridad compartidas |
| `src/libraries/PriceScalerLib.sol` | Normalización a 18 decimales |
| `src/interfaces/IPriceFeed.sol` | Contrato común de lectura |
| `src/errors/OracleErrors.sol` | Errores personalizados |
| `test/gas/Oracle.gas.t.sol` | Línea base medible de gas |

Índice de documentación: [`README-ES.md`](./README-ES.md)
