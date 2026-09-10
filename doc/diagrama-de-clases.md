# Diagrama de clases — Decentralized Oracles (Push / Pull)

Vista estructural de contratos, interfaces y relaciones (módulo 13, **planificación v1**).

## Diagrama (Mermaid)

```mermaid
classDiagram
    direction TB

    class IPriceFeed {
        <<interface>>
        +decimals() uint8
        +latestPrice() int256
        +getValidatedPrice() int256
    }

    class AggregatorV3Interface {
        <<interface Chainlink>>
        +decimals() uint8
        +description() string
        +version() uint256
        +getRoundData(roundId) roundId_answer_startedAt_updatedAt_answeredInRound
        +latestRoundData() roundId_answer_startedAt_updatedAt_answeredInRound
    }

    class IPyth {
        <<interface Pyth>>
        +getUpdateFee(updateData) uint256
        +updatePriceFeeds(updateData)
        +getPrice(priceId) PythPrice
        +getPriceNoOlderThan(priceId, age) PythPrice
    }

    class PythPrice {
        <<struct>>
        +int64 price
        +uint64 conf
        +int32 expo
        +uint256 publishTime
    }

    class OracleErrors {
        <<errors>>
        +StalePriceFeed()
        +InvalidOraclePrice()
        +OracleRoundIncomplete()
        +InsufficientFee()
    }

    class OracleValidationLib {
        <<library>>
        +validateRound(roundId, answeredInRound)
        +validateFreshness(updatedAt, maxDelay)
        +validateBounds(answer, minAnswer, maxAnswer)
        +validateAnswer(answer)
    }

    class PriceScalerLib {
        <<library>>
        +scale(price, fromDecimals, toDecimals) int256
        +to18Decimals(price, fromDecimals) int256
    }

    class MockAggregatorV3 {
        <<contract mock>>
        +uint8 decimals_
        +int256 answer
        +uint256 updatedAt
        +uint80 roundId
        +uint80 answeredInRound
        +setRoundData(...)
        +latestRoundData() ...
        +getRoundData(roundId) ...
    }

    class MockPyth {
        <<contract mock>>
        +uint256 fee
        +mapping prices
        +setPrice(priceId, price, publishTime)
        +getUpdateFee(updateData) uint256
        +updatePriceFeeds(updateData)
        +getPrice(priceId) PythPrice
        +getPriceNoOlderThan(priceId, age) PythPrice
    }

    class ChainlinkPriceFeed {
        <<contract Push>>
        +AggregatorV3Interface aggregator$
        +uint256 maxDelay$
        +int256 minAnswer$
        +int256 maxAnswer$
        +constructor(aggregator, maxDelay, min, max)
        +decimals() uint8
        +latestPrice() int256
        +getValidatedPrice() int256
    }

    class PythPriceFeed {
        <<contract Pull>>
        +IPyth pyth$
        +bytes32 priceId$
        +uint256 maxAge$
        +int256 minAnswer$
        +int256 maxAnswer$
        +constructor(pyth, priceId, maxAge, min, max)
        +updateAndGetPrice(updateData) int256
        +getValidatedPrice() int256
        +getUpdateFee(updateData) uint256
    }

    class PriceOracleConsumer {
        <<contract>>
        +IPriceFeed pushFeed
        +PythPriceFeed pullFeed
        +constructor(pushFeed, pullFeed)
        +getPushPrice() int256
        +getPullPrice(updateData) int256
        +getPriceScaled18(source) uint256
    }

    IPriceFeed <|.. ChainlinkPriceFeed : implements
    IPriceFeed <|.. PythPriceFeed : implements
    AggregatorV3Interface <|.. MockAggregatorV3 : implements
    IPyth <|.. MockPyth : implements

    ChainlinkPriceFeed --> AggregatorV3Interface : reads
    ChainlinkPriceFeed ..> OracleValidationLib : uses
    PythPriceFeed --> IPyth : updates_reads
    PythPriceFeed ..> OracleValidationLib : uses
    PriceOracleConsumer --> IPriceFeed : push
    PriceOracleConsumer --> PythPriceFeed : pull
    PriceOracleConsumer ..> PriceScalerLib : uses
    OracleValidationLib ..> OracleErrors : reverts
    ChainlinkPriceFeed ..> OracleErrors : reverts
    PythPriceFeed ..> OracleErrors : reverts
    IPyth ..> PythPrice : returns
```

## Relaciones clave

| Relación | Motivo |
|----------|--------|
| `ChainlinkPriceFeed` → `AggregatorV3Interface` | Patrón Push: el feed ya está on-chain |
| `PythPriceFeed` → `IPyth` | Patrón Pull: el caller trae el payload y paga fee |
| Ambos → `OracleValidationLib` | Misma política de staleness / bounds / answer |
| `PriceOracleConsumer` → feeds | Fachada para protocolos que no quieren acoplarse al vendor |
| Mocks implementan interfaces reales | Unit tests sin RPC; fork tests usan contratos mainnet |

## Notas de diseño

- `IPriceFeed` unifica lectura; en Pull, la actualización puede ir en `updateAndGetPrice(bytes[])` (payable).
- Bounds y `maxDelay`/`maxAge` como `immutable` o configurables con `Ownable2Step` (decidir en Fase 3–4).
- Escalado a 18 decimales ocurre en el consumer o vía `PriceScalerLib`, no dentro del mock.
