// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {InvalidOracleConfig, ZeroAddress} from "../errors/OracleErrors.sol";
import {OracleValidationLib} from "../libraries/OracleValidationLib.sol";

/**
 * @title ChainlinkPriceFeed
 * @notice Lectura Push segura de un AggregatorV3 (staleness, round completo, bounds).
 */
contract ChainlinkPriceFeed is IPriceFeed {
    /// @notice Aggregator Chainlink subyacente.
    AggregatorV3Interface public immutable aggregator;

    /// @notice Retraso máximo permitido desde `updatedAt` (segundos).
    uint256 public immutable maxDelay;

    /// @notice Cota inferior inclusiva del precio.
    int256 public immutable minAnswer;

    /// @notice Cota superior inclusiva del precio.
    int256 public immutable maxAnswer;

    /**
     * @param aggregator_ Dirección del AggregatorV3.
     * @param maxDelay_ Staleness máxima en segundos.
     * @param minAnswer_ Precio mínimo aceptado (debe ser > 0).
     * @param maxAnswer_ Precio máximo aceptado (>= minAnswer_).
     */
    constructor(address aggregator_, uint256 maxDelay_, int256 minAnswer_, int256 maxAnswer_) {
        if (aggregator_ == address(0)) revert ZeroAddress();
        if (maxDelay_ == 0) revert InvalidOracleConfig();
        if (minAnswer_ <= 0 || minAnswer_ > maxAnswer_) revert InvalidOracleConfig();

        aggregator = AggregatorV3Interface(aggregator_);
        maxDelay = maxDelay_;
        minAnswer = minAnswer_;
        maxAnswer = maxAnswer_;
    }

    /// @inheritdoc IPriceFeed
    function decimals() external view override returns (uint8) {
        return aggregator.decimals();
    }

    /**
     * @notice Alias de `getValidatedPrice`.
     * @return price Precio validado.
     */
    function latestPrice() external view returns (int256 price) {
        return getValidatedPrice();
    }

    /// @inheritdoc IPriceFeed
    function getValidatedPrice() public view override returns (int256 price) {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = aggregator.latestRoundData();
        OracleValidationLib.validateAggregatorRound(
            roundId, answeredInRound, updatedAt, maxDelay, answer, minAnswer, maxAnswer
        );
        return answer;
    }
}
