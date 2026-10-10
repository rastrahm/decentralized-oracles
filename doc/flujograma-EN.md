# Flowchart — Full Push (Chainlink) and Pull (Pyth) lifecycle

> Versión en español: [flujograma-ES.md](./flujograma-ES.md)

End-to-end flow between actors and contracts (module 13, **final v1**): Push read, Pull update, validation and consumption.

## Actors

| Actor | Role |
|-------|-----|
| Protocol / Consumer | Requests a safe price (Push or Pull) |
| Keeper / Relayer | In Chainlink, maintains the aggregator; in Pyth, supplies `priceUpdateData` |
| User / Tester | In tests: sets up mocks or runs a mainnet fork |
| AggregatorV3 (Chainlink) | Stores rounds on-chain (Push model) |
| Pyth (`IPyth`) | Verifies attestations and updates prices on demand (Pull model) |
| `ChainlinkPriceFeed` / `PythPriceFeed` | Wrappers with the module's validation |
| `PriceOracleConsumer` | Unified facade toward the protocol |
| CI / Foundry | Unit, fork, fuzz, gas |

---

## Main flowchart — Push (Chainlink)

```mermaid
flowchart TD
    Start([Push start]) --> Req[Protocol: getPushPrice / getValidatedPrice]
    Req --> Read[ChainlinkPriceFeed reads latestRoundData]
    Read --> Round{Round complete?}
    Round -->|No| RejR[OracleRoundIncomplete]
    Round -->|Yes| Fresh{updatedAt fresh?}
    Fresh -->|No| RejS[StalePriceFeed]
    Fresh -->|Yes| Bound{Answer valid and within bounds?}
    Bound -->|No| RejI[InvalidOraclePrice]
    Bound -->|Yes| Scale[Optional: getPushPriceScaled18]
    Scale --> Use[Protocol uses the price]
    Use --> End([End — OK])

    RejR --> EndFail([End — rejected])
    RejS --> EndFail
    RejI --> EndFail
```

---

## Main flowchart — Pull (Pyth)

```mermaid
flowchart TD
    Start([Pull start]) --> Fetch[Off-chain: fetch priceUpdateData]
    Fetch --> Call[Caller: getPullPrice / updateAndGetPrice + msg.value]
    Call --> Fee[getUpdateFee]
    Fee --> Pay{msg.value >= fee?}
    Pay -->|No| RejF[InsufficientFee]
    Pay -->|Yes| Upd[updatePriceFeeds value: fee]
    Upd --> Get[getPriceUnsafe + validatePullPrice]
    Get --> Fresh{publishTime / bounds OK?}
    Fresh -->|No| RejS[StalePriceFeed / InvalidOraclePrice]
    Fresh -->|Yes| Refund[Refund excess to caller]
    Refund --> Use[Protocol uses the price]
    Use --> End([End — OK])

    RejF --> EndFail([End — rejected])
    RejS --> EndFail
```

---

## Flowchart — Deploy and wiring

```mermaid
flowchart TD
    A([Deploy.s.sol]) --> B{CHAINLINK_AGGREGATOR set?}
    B -->|No| C[Deploy MockAggregatorV3 + seed]
    B -->|Yes| D[Use env address]
    C --> E{PYTH set?}
    D --> E
    E -->|No| F[Deploy MockPyth]
    E -->|Yes| G[Use env address]
    F --> H[Deploy ChainlinkPriceFeed]
    G --> H
    H --> I[Deploy PythPriceFeed]
    I --> J[Deploy PriceOracleConsumer]
    J --> K([Ready — address logs])
```

**Documented mainnet reference:** ETH/USD Chainlink `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`

---

## Flowchart — Typical attacks / misuse

```mermaid
flowchart TD
    A[Attacker forces a zero or negative price] --> B{validateAnswer?}
    B -->|Fails| C[InvalidOraclePrice]

    D[Attacker uses an old updatedAt] --> E{validateFreshness?}
    E -->|Fails| F[StalePriceFeed]

    G[Attacker calls Pull without enough ETH] --> H{msg.value >= fee?}
    H -->|No| I[InsufficientFee]

    J[Round with low answeredInRound] --> K{validateRound?}
    K -->|Fails| L[OracleRoundIncomplete]
```

---

## Sequence — Push happy path

```mermaid
sequenceDiagram
    actor Proto as Protocol
    participant Cons as PriceOracleConsumer
    participant CL as ChainlinkPriceFeed
    participant Agg as AggregatorV3
    participant Lib as OracleValidationLib

    Proto->>Cons: getPushPrice()
    Cons->>CL: getValidatedPrice()
    CL->>Agg: latestRoundData()
    Agg-->>CL: roundId, answer, updatedAt, answeredInRound
    CL->>Lib: validateAggregatorRound
    Lib-->>CL: OK
    CL-->>Cons: answer
    Cons-->>Proto: price
```

---

## Sequence — Pull happy path (via consumer)

```mermaid
sequenceDiagram
    actor Relayer as Relayer/User
    participant Cons as PriceOracleConsumer
    participant PF as PythPriceFeed
    participant Pyth as IPyth
    participant Lib as OracleValidationLib

    Relayer->>Cons: getPullPrice(updateData) + value
    Cons->>PF: getUpdateFee(updateData)
    PF-->>Cons: fee
    Cons->>PF: updateAndGetPrice{value: fee}(updateData)
    PF->>Pyth: updatePriceFeeds{value: fee}
    PF->>Pyth: getPriceUnsafe(priceId)
    Pyth-->>PF: Price
    PF->>Lib: validatePullPrice
    Lib-->>PF: OK
    PF-->>Cons: price
    Cons-->>Relayer: refund (msg.value - fee) + price
```

---

## Implementation governance (v1 history)

```mermaid
flowchart LR
    Doc[doc/ ✅] --> F0[Phase 0 Setup ✅]
    F0 --> F1[Phase 1 Libs ✅]
    F1 --> F2[Phase 2 Mocks ✅]
    F2 --> F3[Phase 3 Push ✅]
    F3 --> F4[Phase 4 Pull ✅]
    F4 --> F5[Phase 5 Consumer/fork/fuzz ✅]
    F5 --> F6[Phase 6 Gas/Deploy/SWC ✅]
    F6 --> Done([Module v1 closed])
```

All phases **0–6** were authorized and completed. Extensions: see `planificacion-EN.md` §12.
