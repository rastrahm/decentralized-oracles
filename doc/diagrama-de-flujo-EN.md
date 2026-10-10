# Flow diagram — Push / Pull validation and price consumption

> Versión en español: [diagrama-de-flujo-ES.md](./diagrama-de-flujo-ES.md)

Internal decision flows of the oracle system (module 13, **final v1**).

## 1. Push read — `ChainlinkPriceFeed.getValidatedPrice`

```mermaid
flowchart TD
    A[Caller requests Push price] --> B[aggregator.latestRoundData]
    B --> C{updatedAt == 0 or in the future?}
    C -->|Yes| D[Revert StalePriceFeed]
    C -->|No| E{answeredInRound < roundId?}
    E -->|Yes| F[Revert OracleRoundIncomplete]
    E -->|No| G{block.timestamp - updatedAt > maxDelay?}
    G -->|Yes| D
    G -->|No| H{answer <= 0 or outside min/max?}
    H -->|Yes| I[Revert InvalidOraclePrice]
    H -->|No| J[Return answer]
    D --> Z[End]
    F --> Z
    I --> Z
    J --> Z
```

## 2. Pull read — `PythPriceFeed.updateAndGetPrice`

```mermaid
flowchart TD
    A[Caller sends updateData + msg.value] --> B[fee = pyth.getUpdateFee]
    B --> C{msg.value >= fee?}
    C -->|No| D[Revert InsufficientFee]
    C -->|Yes| E[pyth.updatePriceFeeds value: fee]
    E --> F[pyth.getPriceUnsafe priceId]
    F --> G[OracleValidationLib.validatePullPrice]
    G --> H{publishTime fresh / answer OK / bounds?}
    H -->|No| I[StalePriceFeed or InvalidOraclePrice]
    H -->|Yes| J{msg.value > fee?}
    J -->|Yes| K[Refund excess to msg.sender]
    J -->|No| L[No refund]
    K --> M{refund OK?}
    M -->|No| N[Revert EthTransferFailed]
    M -->|Yes| O[Return price]
    L --> O
    D --> Z[End]
    I --> Z
    N --> Z
    O --> Z
```

## 3. Pull consumer — `PriceOracleConsumer.getPullPrice`

```mermaid
flowchart TD
    A[Caller + msg.value + updateData] --> B[fee = pullFeed.getUpdateFee]
    B --> C{msg.value >= fee?}
    C -->|No| D[InsufficientFee]
    C -->|Yes| E[pullFeed.updateAndGetPrice value: fee]
    E --> F[validated price]
    F --> G[Refund msg.value - fee to caller]
    G --> H[Return price]
    D --> Z[End]
    H --> Z
```

> The consumer sends the **exact fee** to the feed (the feed does not refund on that path) and refunds the remainder to the user.

## 4. Shared validation — `OracleValidationLib`

```mermaid
flowchart TD
    A[Raw oracle data] --> B[validateRound]
    B --> C{answeredInRound >= roundId?}
    C -->|No| R1[OracleRoundIncomplete]
    C -->|Yes| D[validateFreshness]
    D --> E{updatedAt != 0, not in the future, age <= maxDelay?}
    E -->|No| R2[StalePriceFeed]
    E -->|Yes| F[validateAnswer + validateBounds]
    F --> G{answer > 0 and within min..max?}
    G -->|No| R3[InvalidOraclePrice]
    G -->|Yes| OK[Validation OK]
```

## 5. Decimal scaling — `PriceScalerLib`

```mermaid
flowchart TD
    A[price + fromDecimals + toDecimals] --> B{from/to > 18?}
    B -->|Yes| C[InvalidOracleConfig]
    B -->|No| D{price <= 0?}
    D -->|Yes| E[InvalidOraclePrice]
    D -->|No| F{from == to?}
    F -->|Yes| G[Return price]
    F -->|No| H{from < to?}
    H -->|Yes| I[Multiply / overflow → InvalidOraclePrice]
    H -->|No| J[Divide by 10^delta]
    I --> K[scaled]
    J --> K
    G --> K
```

## 6. State lifecycle — observed price

```mermaid
stateDiagram-v2
    [*] --> Raw: Oracle responds / payload arrives

    Raw --> RoundCheck: check roundId vs answeredInRound
    RoundCheck --> RejectedRound: OracleRoundIncomplete
    RoundCheck --> FreshnessCheck: round OK

    FreshnessCheck --> RejectedStale: StalePriceFeed
    FreshnessCheck --> BoundsCheck: fresh

    BoundsCheck --> RejectedInvalid: InvalidOraclePrice
    BoundsCheck --> Accepted: usable price

    Accepted --> Scaled: optional scale to 18 decimals
    Scaled --> Consumed: protocol uses the price

    RejectedRound --> [*]
    RejectedStale --> [*]
    RejectedInvalid --> [*]
    Consumed --> [*]
```

## 7. Cross-cutting rule — never trust a raw price

```mermaid
flowchart LR
    X[Any price read] --> Y{Passed ValidationLib?}
    Y -->|Yes| OK[Expose to consumer / protocol]
    Y -->|No| NO[Custom error — no silent fallback]
```

Applies to: Push `latestRoundData`, Pull after `updatePriceFeeds`, and consumer helpers.
