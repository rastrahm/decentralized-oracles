# Flujograma — Ciclo completo Push (Chainlink) y Pull (Pyth)

Flujo extremo a extremo entre actores y contratos (módulo 13, **v1 final**): lectura Push, actualización Pull, validación y consumo.

## Actores

| Actor | Rol |
|-------|-----|
| Protocolo / Consumer | Solicita un precio seguro (Push o Pull) |
| Keeper / Relayer | En Chainlink mantiene el aggregator; en Pyth aporta `priceUpdateData` |
| Usuario / Tester | En tests: arma mocks o corre fork mainnet |
| AggregatorV3 (Chainlink) | Almacena rounds on-chain (modelo Push) |
| Pyth (`IPyth`) | Verifica attestations y actualiza precios on-demand (modelo Pull) |
| `ChainlinkPriceFeed` / `PythPriceFeed` | Wrappers con validación del módulo |
| `PriceOracleConsumer` | Fachada unificada hacia el protocolo |
| CI / Foundry | Unit, fork, fuzz, gas |

---

## Flujograma principal — Push (Chainlink)

```mermaid
flowchart TD
    Start([Inicio Push]) --> Req[Protocolo: getPushPrice / getValidatedPrice]
    Req --> Read[ChainlinkPriceFeed lee latestRoundData]
    Read --> Round{¿round completo?}
    Round -->|No| RejR[OracleRoundIncomplete]
    Round -->|Sí| Fresh{¿updatedAt fresco?}
    Fresh -->|No| RejS[StalePriceFeed]
    Fresh -->|Sí| Bound{¿answer válido y en bounds?}
    Bound -->|No| RejI[InvalidOraclePrice]
    Bound -->|Sí| Scale[Opcional: getPushPriceScaled18]
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
    Start([Inicio Pull]) --> Fetch[Off-chain: obtener priceUpdateData]
    Fetch --> Call[Caller: getPullPrice / updateAndGetPrice + msg.value]
    Call --> Fee[getUpdateFee]
    Fee --> Pay{¿msg.value >= fee?}
    Pay -->|No| RejF[InsufficientFee]
    Pay -->|Sí| Upd[updatePriceFeeds value: fee]
    Upd --> Get[getPriceUnsafe + validatePullPrice]
    Get --> Fresh{¿publishTime / bounds OK?}
    Fresh -->|No| RejS[StalePriceFeed / InvalidOraclePrice]
    Fresh -->|Sí| Refund[Refund exceso al caller]
    Refund --> Use[Protocolo usa el precio]
    Use --> End([Fin — OK])

    RejF --> EndFail([Fin — rechazo])
    RejS --> EndFail
```

---

## Flujograma — Deploy y wiring

```mermaid
flowchart TD
    A([Deploy.s.sol]) --> B{¿CHAINLINK_AGGREGATOR set?}
    B -->|No| C[Deploy MockAggregatorV3 + seed]
    B -->|Sí| D[Usar address env]
    C --> E{¿PYTH set?}
    D --> E
    E -->|No| F[Deploy MockPyth]
    E -->|Sí| G[Usar address env]
    F --> H[Deploy ChainlinkPriceFeed]
    G --> H
    H --> I[Deploy PythPriceFeed]
    I --> J[Deploy PriceOracleConsumer]
    J --> K([Listo — logs de addresses])
```

**Mainnet ref documentada:** ETH/USD Chainlink `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`

---

## Flujograma — Ataques / misuse típicos

```mermaid
flowchart TD
    A[Attacker fuerza precio 0 o negativo] --> B{validateAnswer?}
    B -->|Falla| C[InvalidOraclePrice]

    D[Attacker usa updatedAt antiguo] --> E{validateFreshness?}
    E -->|Falla| F[StalePriceFeed]

    G[Attacker llama Pull sin ETH suficiente] --> H{msg.value >= fee?}
    H -->|No| I[InsufficientFee]

    J[Round answeredInRound bajo] --> K{validateRound?}
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
    CL->>Lib: validateAggregatorRound
    Lib-->>CL: OK
    CL-->>Cons: answer
    Cons-->>Proto: price
```

---

## Secuencia — camino feliz Pull (vía consumer)

```mermaid
sequenceDiagram
    actor Relayer as Relayer/Usuario
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

## Gobernanza de implementación (histórico v1)

```mermaid
flowchart LR
    Doc[doc/ ✅] --> F0[Fase 0 Setup ✅]
    F0 --> F1[Fase 1 Libs ✅]
    F1 --> F2[Fase 2 Mocks ✅]
    F2 --> F3[Fase 3 Push ✅]
    F3 --> F4[Fase 4 Pull ✅]
    F4 --> F5[Fase 5 Consumer/fork/fuzz ✅]
    F5 --> F6[Fase 6 Gas/Deploy/SWC ✅]
    F6 --> Done([Módulo v1 cerrado])
```

Todas las fases **0–6** fueron autorizadas y completadas. Extensiones: ver `planificacion.md` §12.
