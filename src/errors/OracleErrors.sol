// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title OracleErrors
 * @notice Custom errors del módulo 13 (oráculos Push/Pull).
 */

/// @notice Precio ausente, `updatedAt == 0`, o más antiguo que el umbral de staleness.
error StalePriceFeed();

/// @notice Precio ≤ 0 o fuera de `[minAnswer, maxAnswer]`.
error InvalidOraclePrice();

/// @notice Round incompleto: `answeredInRound < roundId`.
error OracleRoundIncomplete();

/// @notice `msg.value` insuficiente para `pyth.getUpdateFee()`.
error InsufficientFee();

/// @notice Dirección cero donde no está permitida.
error ZeroAddress();

/// @notice Parámetro de configuración inválido (p. ej. `minAnswer > maxAnswer`, decimals extremos).
error InvalidOracleConfig();

/// @notice Falló el refund de ETH sobrante tras pagar el fee de Pyth.
error EthTransferFailed();
