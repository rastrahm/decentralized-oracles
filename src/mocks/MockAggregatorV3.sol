// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title MockAggregatorV3
 * @notice Aggregator Chainlink controlable para unit tests (rounds, timestamps, answers).
 */
contract MockAggregatorV3 is AggregatorV3Interface {
    /// @notice Round inexistente en `getRoundData`.
    error RoundNotFound();

    uint8 private immutable _decimals;
    string private _description;
    uint256 private constant _VERSION = 1;

    uint80 private _roundId;
    int256 private _answer;
    uint256 private _startedAt;
    uint256 private _updatedAt;
    uint80 private _answeredInRound;

    mapping(uint80 => Round) private _rounds;

    struct Round {
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
        bool exists;
    }

    /**
     * @param decimals_ Decimales del feed (p. ej. 8).
     * @param description_ Descripción legible.
     */
    constructor(uint8 decimals_, string memory description_) {
        _decimals = decimals_;
        _description = description_;
    }

    /// @inheritdoc AggregatorV3Interface
    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc AggregatorV3Interface
    function description() external view override returns (string memory) {
        return _description;
    }

    /// @inheritdoc AggregatorV3Interface
    function version() external pure override returns (uint256) {
        return _VERSION;
    }

    /**
     * @notice Configura el latest round (y el mapping de ese `roundId`).
     * @param roundId Identificador del round.
     * @param answer Precio.
     * @param startedAt Inicio del round.
     * @param updatedAt Timestamp de respuesta.
     * @param answeredInRound Round en el que se respondió (`< roundId` = incompleto).
     */
    function setRoundData(
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) external {
        _roundId = roundId;
        _answer = answer;
        _startedAt = startedAt;
        _updatedAt = updatedAt;
        _answeredInRound = answeredInRound;
        _rounds[roundId] =
            Round({answer: answer, startedAt: startedAt, updatedAt: updatedAt, answeredInRound: answeredInRound, exists: true});
    }

    /**
     * @notice Atajo: latest round completo con `answeredInRound == roundId`.
     * @param answer Precio.
     * @param updatedAt Timestamp.
     */
    function setLatestAnswer(int256 answer, uint256 updatedAt) external {
        uint80 nextId = _roundId + 1;
        if (nextId == 0) nextId = 1;
        _roundId = nextId;
        _answer = answer;
        _startedAt = updatedAt;
        _updatedAt = updatedAt;
        _answeredInRound = nextId;
        _rounds[nextId] =
            Round({answer: answer, startedAt: updatedAt, updatedAt: updatedAt, answeredInRound: nextId, exists: true});
    }

    /// @inheritdoc AggregatorV3Interface
    function getRoundData(uint80 roundId_)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        Round memory r = _rounds[roundId_];
        if (!r.exists) revert RoundNotFound();
        return (roundId_, r.answer, r.startedAt, r.updatedAt, r.answeredInRound);
    }

    /// @inheritdoc AggregatorV3Interface
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, _startedAt, _updatedAt, _answeredInRound);
    }
}
