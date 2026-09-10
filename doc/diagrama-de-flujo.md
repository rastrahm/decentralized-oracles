# Diagrama de flujo — Validación Push / Pull y consumo de precio

Flujos de decisión internos del sistema de oráculos (módulo 13, **planificación v1**).

## 1. Lectura Push — `ChainlinkPriceFeed.getValidatedPrice`

```mermaid
flowchart TD
    A[Caller pide precio Push] --> B[aggregator.latestRoundData]
    B --> C{¿updatedAt == 0?}
    C -->|Sí| D[Revert StalePriceFeed]
    C -->|No| E{¿answeredInRound < roundId?}
    E -->|Sí| F[Revert OracleRoundIncomplete]
    E -->|No| G{¿block.timestamp - updatedAt > MAX_DELAY?}
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
    A[Caller envía priceUpdateData + msg.value] --> B[fee = pyth.getUpdateFee]
    B --> C{¿msg.value >= fee?}
    C -->|No| D[Revert InsufficientFee]
    C -->|Sí| E[pyth.updatePriceFeeds value: fee]
    E --> F[pyth.getPriceNoOlderThan priceId, maxAge]
    F --> G{¿publishTime fresco / sin stale?}
    G -->|No| H[Revert StalePriceFeed]
    G -->|Sí| I{¿price <= 0 o fuera de bounds?}
    I -->|Sí| J[Revert InvalidOraclePrice]
    I -->|No| K[Refund ETH sobrante si aplica]
    K --> L[Retornar price escalado/normalizado]
    D --> Z[Fin]
    H --> Z
    J --> Z
    L --> Z
```

## 3. Validación compartida — `OracleValidationLib`

```mermaid
flowchart TD
    A[Datos crudos del oracle] --> B[validateRound]
    B --> C{answeredInRound >= roundId?}
    C -->|No| R1[OracleRoundIncomplete]
    C -->|Sí| D[validateFreshness]
    D --> E{updatedAt != 0 y age <= maxDelay?}
    E -->|No| R2[StalePriceFeed]
    E -->|Sí| F[validateAnswer + validateBounds]
    F --> G{answer > 0 y en min..max?}
    G -->|No| R3[InvalidOraclePrice]
    G -->|Sí| OK[Validación OK]
```

## 4. Escalado de decimales — `PriceScalerLib`

```mermaid
flowchart TD
    A[price + fromDecimals + toDecimals] --> B{¿from == to?}
    B -->|Sí| C[Retornar price sin cambio]
    B -->|No| D{¿from < to?}
    D -->|Sí| E[Multiplicar por 10^delta]
    D -->|No| F[Dividir por 10^delta]
    E --> G[Retornar price escalado]
    F --> G
```

## 5. Ciclo de estados — precio observado

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

## 6. Regla transversal — nunca confiar en precio crudo

```mermaid
flowchart LR
    X[Cualquier lectura de precio] --> Y{¿Pasó ValidationLib?}
    Y -->|Sí| OK[Exponer a consumer / protocolo]
    Y -->|No| NO[Custom error — no fallback silencioso]
```

Aplica a: Push `latestRoundData`, Pull post-`updatePriceFeeds`, y cualquier helper del consumer.
