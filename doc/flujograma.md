# Flujograma — Ciclo completo Push (Chainlink) y Pull (Pyth)

Flujo extremo a extremo entre actores y contratos (módulo 13, **planificación v1**): lectura Push, actualización Pull, validación y consumo.

## Actores

| Actor | Rol |
|-------|-----|
| Protocolo / Consumer | Solicita un precio seguro (Push o Pull) |
| Keeper / Relayer | En Chainlink mantiene el aggregator; en Pyth aporta `priceUpdateData` |
| Usuario / Tester | En tests: arma mocks o corre fork mainnet |
| AggregatorV3 (Chainlink) | Almacena rounds on-chain (modelo Push) |
| Pyth | Verifica attestations y actualiza precios on-demand (modelo Pull) |
| PriceOracleConsumer | Fachada unificada hacia el protocolo |
| CI / Foundry | Unit, fork, fuzz, gas |

---

## Flujograma principal — Push (Chainlink)

```mermaid
flowchart TD
    Start([Inicio Push]) --> Req[Protocolo llama getPushPrice / getValidatedPrice]
    Req --> Read[ChainlinkPriceFeed lee latestRoundData]
    Read --> Round{¿round completo?}
    Round -->|No| RejR[OracleRoundIncomplete]
    Round -->|Sí| Fresh{¿updatedAt fresco?}
    Fresh -->|No| RejS[StalePriceFeed]
    Fresh -->|Sí| Bound{¿answer válido y en bounds?}
    Bound -->|No| RejI[InvalidOraclePrice]
    Bound -->|Sí| Scale[Opcional: scale a 18 decimals]
    Scale --> Use[Protocolo usa el precio]
    Use --> End([Fin — OK])

    RejR --> EndFail([Fin — rechazo])
    RejS --> EndFail
    RejI --> EndFail
```

---

## Flujograma principal — Pull (Pyth)

```mermaid
flowchart TD
    Start([Inicio Pull]) --> Fetch[Off-chain: obtener priceUpdateData\nHermes / API Pyth]
    Fetch --> Call[Caller: updateAndGetPrice + msg.value]
    Call --> Fee[pyth.getUpdateFee]
    Fee --> Pay{¿msg.value >= fee?}
    Pay -->|No| RejF[InsufficientFee]
    Pay -->|Sí| Upd[updatePriceFeeds value: fee]
    Upd --> Get[getPriceNoOlderThan]
    Get --> Fresh{¿publishTime dentro de maxAge?}
    Fresh -->|No| RejS[StalePriceFeed]
    Fresh -->|Sí| Bound{¿price válido y en bounds?}
    Bound -->|No| RejI[InvalidOraclePrice]
    Bound -->|Sí| Refund[Refund ETH sobrante]
    Refund --> Use[Protocolo usa el precio]
    Use --> End([Fin — OK])

    RejF --> EndFail([Fin — rechazo])
    RejS --> EndFail
    RejI --> EndFail
```

---

## Flujograma — Deploy y wiring

```mermaid
flowchart TD
    A([Deploy]) --> B[Deploy / configurar MockAggregatorV3\no address Chainlink mainnet]
    B --> C[Deploy ChainlinkPriceFeed\nmaxDelay + bounds]
    C --> D[Deploy MockPyth o address Pyth]
    D --> E[Deploy PythPriceFeed\npriceId + maxAge + bounds]
    E --> F[Deploy PriceOracleConsumer\npush + pull]
    F --> G([Listo para lecturas / updates])
```

---

## Flujograma — Ataques / misuse típicos

```mermaid
flowchart TD
    A[Attacker fuerza precio 0 o negativo en mock] --> B{validateAnswer?}
    B -->|Falla| C[InvalidOraclePrice]

    D[Attacker usa updatedAt antiguo] --> E{validateFreshness?}
    E -->|Falla| F[StalePriceFeed]

    G[Attacker llama Pull sin ETH suficiente] --> H{msg.value >= fee?}
    H -->|No| I[InsufficientFee]

    J[Round manipulado answeredInRound bajo] --> K{validateRound?}
    K -->|Falla| L[OracleRoundIncomplete]
```

---

## Secuencia — camino feliz Push

```mermaid
sequenceDiagram
    actor Proto as Protocolo
    participant Cons as PriceOracleConsumer
    participant CL as ChainlinkPriceFeed
    participant Agg as AggregatorV3
    participant Lib as OracleValidationLib

    Proto->>Cons: getPushPrice()
    Cons->>CL: getValidatedPrice()
    CL->>Agg: latestRoundData()
    Agg-->>CL: roundId, answer, updatedAt, answeredInRound
    CL->>Lib: validateRound / Freshness / Bounds
    Lib-->>CL: OK
    CL-->>Cons: answer
    Cons-->>Proto: price (opcionalmente scaled)
```

---

## Secuencia — camino feliz Pull

```mermaid
sequenceDiagram
    actor Relayer as Relayer/Usuario
    participant Cons as PriceOracleConsumer
    participant PF as PythPriceFeed
    participant Pyth as IPyth
    participant Lib as OracleValidationLib

    Relayer->>Cons: getPullPrice(updateData) + value
    Cons->>PF: updateAndGetPrice(updateData)
    PF->>Pyth: getUpdateFee(updateData)
    Pyth-->>PF: fee
    PF->>Pyth: updatePriceFeeds{value: fee}(updateData)
    PF->>Pyth: getPriceNoOlderThan(priceId, maxAge)
    Pyth-->>PF: PythPrice
    PF->>Lib: validateAnswer / Bounds / age
    Lib-->>PF: OK
    PF-->>Cons: price
    Cons-->>Relayer: price + refund si aplica
```

---

## Gobernanza de implementación (autorización)

```mermaid
flowchart LR
    Doc[doc/ plan + diagramas ✅] --> Gate0{¿autorizo Fase 0?}
    Gate0 -->|Sí| F0[Setup Foundry]
    Gate0 -->|No| Wait[Esperar]
    F0 --> Gate1{¿autorizo Fase 1?}
    Gate1 -->|Sí| F1[Libs + interfaces]
    F1 --> Gate2{¿autorizo Fase 2?}
    Gate2 -->|Sí| F2[Mocks]
    F2 --> Gate3{¿autorizo Fase 3?}
    Gate3 -->|Sí| F3[Chainlink Push]
    F3 --> Gate4{¿autorizo Fase 4?}
    Gate4 -->|Sí| F4[Pyth Pull]
    F4 --> Gate5{¿autorizo Fase 5?}
    Gate5 -->|Sí| F5[Consumer + fork + fuzz]
    F5 --> Gate6{¿autorizo Fase 6?}
    Gate6 -->|Sí| F6[Gas + Deploy + SWC]
```

Sin frase de autorización explícita, **no se avanza** a la siguiente fase.
