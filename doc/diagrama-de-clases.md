# Diagrama de clases — Decentralized Oracles (Push / Pull)

Vista estructural de contratos, interfaces y relaciones (módulo 13, **v1 final**).

## Diagrama (Mermaid)

```mermaid
classDiagram
    direction TB

    class IPriceFeed {
        <<interface>>
        +decimals() uint8
        +getValidatedPrice() int256
    }

    class AggregatorV3Interface {
        <<interface Chainlink remapping>>
        +decimals() uint8
        +description() string
        +version() uint256
        +getRoundData(roundId) ...
        +latestRoundData() ...
    }

    class IPyth {
        <<interface Pyth SDK>>
        +getUpdateFee(updateData) uint256
        +updatePriceFeeds(updateData)
        +getPriceUnsafe(id) Price
        +getPriceNoOlderThan(id, age) Price
    }

    class PythStructs_Price {
        <<struct SDK>>
        +int64 price
        +uint64 conf
        +int32 expo
        +uint publishTime
    }

    class OracleErrors {
        <<errors>>
        +StalePriceFeed()
        +InvalidOraclePrice()
        +OracleRoundIncomplete()
        +InsufficientFee()
        +ZeroAddress()
        +InvalidOracleConfig()
        +EthTransferFailed()
    }

    class OracleValidationLib {
        <<library>>
        +validateRound(roundId, answeredInRound)
        +validateFreshness(updatedAt, maxDelay)
        +validateAnswer(answer)
        +validateBounds(answer, min, max)
        +validateAggregatorRound(...)
        +validatePullPrice(...)
    }

    class PriceScalerLib {
        <<library>>
        +MAX_DECIMALS$
        +scale(price, from, to) int256
        +to18Decimals(price, from) int256
    }

    class MockAggregatorV3 {
        <<contract mock>>
        +setRoundData(...)
        +setLatestAnswer(answer, updatedAt)
        +decimals() uint8
        +latestRoundData() ...
        +getRoundData(roundId) ...
    }

    class MockPyth {
        <<contract mock extends SDK MockPyth>>
        +createUpdateData(...) bytes
        +setPrice(...) payable
        +getUpdateFee(updateData) uint256
        +updatePriceFeeds(updateData) payable
        +getPriceUnsafe(id) Price
        +getPriceNoOlderThan(id, age) Price
    }

    class ChainlinkPriceFeed {
        <<contract Push IPriceFeed>>
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
        <<contract Pull IPriceFeed>>
        +IPyth pyth$
        +bytes32 priceId$
        +uint256 maxAge$
        +int256 minAnswer$
        +int256 maxAnswer$
        +constructor(pyth, priceId, maxAge, min, max, decimals)
        +getUpdateFee(updateData) uint256
        +updateAndGetPrice(updateData) int256 payable
        +getValidatedPrice() int256
        +decimals() uint8
    }

    class PriceOracleConsumer {
        <<contract>>
        +IPriceFeed pushFeed$
        +PythPriceFeed pullFeed$
        +constructor(pushFeed, pullFeed)
        +getPushPrice() int256
        +getPullPrice(updateData) int256 payable
        +getPushPriceScaled18() uint256
        +getPullPriceScaled18(updateData) uint256 payable
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
    PriceOracleConsumer ..> OracleErrors : reverts
    IPyth ..> PythStructs_Price : returns
```

## Relaciones clave

| Relación | Motivo |
|----------|--------|
| `ChainlinkPriceFeed` → `AggregatorV3Interface` | Patrón Push: el feed ya está on-chain |
| `PythPriceFeed` → `IPyth` | Patrón Pull: el caller trae el payload y paga fee |
| Ambos → `OracleValidationLib` | Misma política de staleness / bounds / answer |
| `PriceOracleConsumer` → feeds | Fachada; Push view + Pull payable con fee exacto y refund al caller |
| `MockPyth` hereda SDK | `IPyth` completo; helpers `createUpdateData` / `setPrice` |
| Remappings | Chainlink vía `lib/`; Pyth vía `node_modules/@pythnetwork/...` |

## Decisiones de diseño (v1)

- `IPriceFeed` solo `decimals` + `getValidatedPrice`; `latestPrice()` es alias en `ChainlinkPriceFeed`.
- Bounds, `maxDelay` / `maxAge`, addresses: **immutable** (retune = redeploy).
- Escalado a 18 decimals solo en el consumer (`getPushPriceScaled18` / `getPullPriceScaled18`).
- Consumer paga **fee exacto** a `PythPriceFeed` y refunde el exceso al `msg.sender` original.
