// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {InvalidOracleConfig, InvalidOraclePrice, OracleRoundIncomplete, StalePriceFeed} from "../errors/OracleErrors.sol";

/**
 * @title OracleValidationLib
 * @notice Validaciones compartidas para respuestas Push (Chainlink) y Pull (Pyth).
 * @dev Reglas del módulo: round completo, `updatedAt != 0`, no stale, answer > 0 y dentro de bounds.
 */
library OracleValidationLib {
    /**
     * @notice Exige `answeredInRound >= roundId`.
     * @param roundId Identificador del round solicitado / latest.
     * @param answeredInRound Round en el que se respondió.
     */
    function validateRound(uint80 roundId, uint80 answeredInRound) internal pure {
        if (answeredInRound < roundId) revert OracleRoundIncomplete();
    }

    /**
     * @notice Exige `updatedAt != 0`, no futuro y edad ≤ `maxDelay`.
     * @param updatedAt Timestamp de la respuesta del oráculo.
     * @param maxDelay Retraso máximo permitido en segundos.
     */
    function validateFreshness(uint256 updatedAt, uint256 maxDelay) internal view {
        if (updatedAt == 0 || updatedAt > block.timestamp) revert StalePriceFeed();
        if (block.timestamp - updatedAt > maxDelay) revert StalePriceFeed();
    }

    /**
     * @notice Exige precio estrictamente positivo.
     * @param answer Precio crudo del oráculo.
     */
    function validateAnswer(int256 answer) internal pure {
        if (answer <= 0) revert InvalidOraclePrice();
    }

    /**
     * @notice Exige `minAnswer <= answer <= maxAnswer`.
     * @param answer Precio a validar.
     * @param minAnswer Cota inferior inclusiva.
     * @param maxAnswer Cota superior inclusiva.
     */
    function validateBounds(int256 answer, int256 minAnswer, int256 maxAnswer) internal pure {
        if (minAnswer > maxAnswer) revert InvalidOracleConfig();
        if (answer < minAnswer || answer > maxAnswer) revert InvalidOraclePrice();
    }

    /**
     * @notice Pipeline completo de validación Push/estilo AggregatorV3.
     * @param roundId Round id.
     * @param answeredInRound Round respondido.
     * @param updatedAt Timestamp on-chain.
     * @param maxDelay Staleness máxima.
     * @param answer Precio.
     * @param minAnswer Cota inferior.
     * @param maxAnswer Cota superior.
     */
    function validateAggregatorRound(
        uint80 roundId,
        uint80 answeredInRound,
        uint256 updatedAt,
        uint256 maxDelay,
        int256 answer,
        int256 minAnswer,
        int256 maxAnswer
    ) internal view {
        validateRound(roundId, answeredInRound);
        validateFreshness(updatedAt, maxDelay);
        validateAnswer(answer);
        validateBounds(answer, minAnswer, maxAnswer);
    }

    /**
     * @notice Validación post-lectura Pull (edad ya acotada por `getPriceNoOlderThan` o `publishTime`).
     * @param publishTime Timestamp de publicación Pyth.
     * @param maxAge Edad máxima aceptada.
     * @param answer Precio (puede venir de `int64` casteado).
     * @param minAnswer Cota inferior.
     * @param maxAnswer Cota superior.
     */
    function validatePullPrice(
        uint256 publishTime,
        uint256 maxAge,
        int256 answer,
        int256 minAnswer,
        int256 maxAnswer
    ) internal view {
        validateFreshness(publishTime, maxAge);
        validateAnswer(answer);
        validateBounds(answer, minAnswer, maxAnswer);
    }
}
