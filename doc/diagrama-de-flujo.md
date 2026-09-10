# Diagrama de flujo — Validación Push / Pull y consumo de precio

Flujos de decisión internos del sistema de oráculos (módulo 13, **v1 final**).

## 1. Lectura Push — `ChainlinkPriceFeed.getValidatedPrice`

```mermaid
flowchart TD
    A[Caller pide precio Push] --> B[aggregator.latestRoundData]
    B --> C{¿updatedAt == 0 o futuro?}
    C -->|Sí| D[Revert StalePriceFeed]
    C -->|No| E{¿answeredInRound < roundId?}
    E -->|Sí| F[Revert OracleRoundIncomplete]
    E -->|No| G{¿block.timestamp - updatedAt > maxDelay?}
    G -->|Sí| D
    G -->|No| H{¿answer <= 0 o fuera de min/max?}
    H -->|Sí| I[Revert InvalidOraclePrice]
    H -->|No| J[Retornar answer]
    D --> Z[Fin]
    F --> Z
    I --> Z
    J --> Z
```

## 2. Lectura Pull — `PythPriceFeed.updateAndGetPrice`

```mermaid
flowchart TD
    A[Caller envía updateData + msg.value] --> B[fee = pyth.getUpdateFee]
    B --> C{¿msg.value >= fee?}
    C -->|No| D[Revert InsufficientFee]
    C -->|Sí| E[pyth.updatePriceFeeds value: fee]
    E --> F[pyth.getPriceUnsafe priceId]
    F --> G[OracleValidationLib.validatePullPrice]
    G --> H{¿publishTime fresco / answer OK / bounds?}
    H -->|No| I[StalePriceFeed o InvalidOraclePrice]
    H -->|Sí| J{¿msg.value > fee?}
    J -->|Sí| K[Refund exceso a msg.sender]
    J -->|No| L[Sin refund]
    K --> M{¿refund OK?}
    M -->|No| N[Revert EthTransferFailed]
    M -->|Sí| O[Retornar price]
    L --> O
    D --> Z[Fin]
    I --> Z
    N --> Z
    O --> Z
```

## 3. Consumer Pull — `PriceOracleConsumer.getPullPrice`

```mermaid
flowchart TD
    A[Caller + msg.value + updateData] --> B[fee = pullFeed.getUpdateFee]
    B --> C{¿msg.value >= fee?}
    C -->|No| D[InsufficientFee]
    C -->|Sí| E[pullFeed.updateAndGetPrice value: fee]
    E --> F[price validado]
    F --> G[Refund msg.value - fee al caller]
    G --> H[Retornar price]
    D --> Z[Fin]
    H --> Z
```

> El consumer envía **fee exacto** al feed (el feed no hace refund en ese path) y refunde el sobrante al usuario.

## 4. Validación compartida — `OracleValidationLib`

```mermaid
flowchart TD
    A[Datos crudos del oracle] --> B[validateRound]
    B --> C{answeredInRound >= roundId?}
    C -->|No| R1[OracleRoundIncomplete]
    C -->|Sí| D[validateFreshness]
    D --> E{updatedAt != 0, no futuro, age <= maxDelay?}
    E -->|No| R2[StalePriceFeed]
    E -->|Sí| F[validateAnswer + validateBounds]
    F --> G{answer > 0 y en min..max?}
    G -->|No| R3[InvalidOraclePrice]
    G -->|Sí| OK[Validación OK]
```

## 5. Escalado de decimales — `PriceScalerLib`

```mermaid
flowchart TD
    A[price + fromDecimals + toDecimals] --> B{¿from/to > 18?}
    B -->|Sí| C[InvalidOracleConfig]
    B -->|No| D{¿price <= 0?}
    D -->|Sí| E[InvalidOraclePrice]
    D -->|No| F{¿from == to?}
    F -->|Sí| G[Retornar price]
    F -->|No| H{¿from < to?}
    H -->|Sí| I[Multiplicar / overflow → InvalidOraclePrice]
    H -->|No| J[Dividir por 10^delta]
    I --> K[scaled]
    J --> K
    G --> K
```

## 6. Ciclo de estados — precio observado

```mermaid
stateDiagram-v2
    [*] --> Raw: Oracle responde / payload llega

    Raw --> RoundCheck: comprobar roundId vs answeredInRound
    RoundCheck --> RejectedRound: OracleRoundIncomplete
    RoundCheck --> FreshnessCheck: round OK

    FreshnessCheck --> RejectedStale: StalePriceFeed
    FreshnessCheck --> BoundsCheck: fresco

    BoundsCheck --> RejectedInvalid: InvalidOraclePrice
    BoundsCheck --> Accepted: precio usable

    Accepted --> Scaled: opcional scale a 18 decimals
    Scaled --> Consumed: protocolo usa el precio

    RejectedRound --> [*]
    RejectedStale --> [*]
    RejectedInvalid --> [*]
    Consumed --> [*]
```

## 7. Regla transversal — nunca confiar en precio crudo

```mermaid
flowchart LR
    X[Cualquier lectura de precio] --> Y{¿Pasó ValidationLib?}
    Y -->|Sí| OK[Exponer a consumer / protocolo]
    Y -->|No| NO[Custom error — no fallback silencioso]
```

Aplica a: Push `latestRoundData`, Pull post-`updatePriceFeeds`, y helpers del consumer.
