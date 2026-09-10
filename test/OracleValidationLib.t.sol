// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    InvalidOracleConfig,
    InvalidOraclePrice,
    OracleRoundIncomplete,
    StalePriceFeed
} from "../src/errors/OracleErrors.sol";
import {OracleValidationLib} from "../src/libraries/OracleValidationLib.sol";

contract OracleValidationLibTest is Test {
    uint256 internal constant MAX_DELAY = 1 hours;

    function test_validateRound_ok() public pure {
        OracleValidationLib.validateRound(10, 10);
        OracleValidationLib.validateRound(10, 11);
    }

    function test_validateRound_incomplete_reverts() public {
        vm.expectRevert(OracleRoundIncomplete.selector);
        this.wrapValidateRound(10, 9);
    }

    function test_validateFreshness_ok() public {
        vm.warp(1_700_000_000);
        OracleValidationLib.validateFreshness(block.timestamp, MAX_DELAY);
        OracleValidationLib.validateFreshness(block.timestamp - MAX_DELAY, MAX_DELAY);
    }

    function test_validateFreshness_zero_reverts() public {
        vm.warp(1000);
        vm.expectRevert(StalePriceFeed.selector);
        this.wrapValidateFreshness(0, MAX_DELAY);
    }

    function test_validateFreshness_stale_reverts() public {
        vm.warp(1_700_000_000);
        uint256 updatedAt = block.timestamp - MAX_DELAY - 1;
        vm.expectRevert(StalePriceFeed.selector);
        this.wrapValidateFreshness(updatedAt, MAX_DELAY);
    }

    function test_validateFreshness_future_reverts() public {
        vm.warp(1_000);
        vm.expectRevert(StalePriceFeed.selector);
        this.wrapValidateFreshness(block.timestamp + 1, MAX_DELAY);
    }

    function test_validateAnswer_ok() public pure {
        OracleValidationLib.validateAnswer(1);
        OracleValidationLib.validateAnswer(type(int256).max);
    }

    function test_validateAnswer_zero_reverts() public {
        vm.expectRevert(InvalidOraclePrice.selector);
        this.wrapValidateAnswer(0);
    }

    function test_validateAnswer_negative_reverts() public {
        vm.expectRevert(InvalidOraclePrice.selector);
        this.wrapValidateAnswer(-1);
    }

    function test_validateBounds_ok() public pure {
        OracleValidationLib.validateBounds(100, 1, 200);
        OracleValidationLib.validateBounds(1, 1, 1);
    }

    function test_validateBounds_below_reverts() public {
        vm.expectRevert(InvalidOraclePrice.selector);
        this.wrapValidateBounds(0, 1, 100);
    }

    function test_validateBounds_above_reverts() public {
        vm.expectRevert(InvalidOraclePrice.selector);
        this.wrapValidateBounds(101, 1, 100);
    }

    function test_validateBounds_badConfig_reverts() public {
        vm.expectRevert(InvalidOracleConfig.selector);
        this.wrapValidateBounds(50, 100, 1);
    }

    function test_validateAggregatorRound_ok() public {
        vm.warp(1_700_000_000);
        OracleValidationLib.validateAggregatorRound(
            5, 5, block.timestamp - 10, MAX_DELAY, 2000e8, 1, type(int256).max / 2
        );
    }

    function test_validateAggregatorRound_incomplete_reverts() public {
        vm.warp(1_700_000_000);
        vm.expectRevert(OracleRoundIncomplete.selector);
        this.wrapValidateAggregatorRound(5, 4, block.timestamp, MAX_DELAY, 100, 1, 1000);
    }

    function test_validatePullPrice_ok() public {
        vm.warp(1_700_000_000);
        OracleValidationLib.validatePullPrice(block.timestamp - 5, 60, 3500e8, 1, type(int256).max / 2);
    }

    function test_validatePullPrice_stale_reverts() public {
        vm.warp(1_700_000_000);
        vm.expectRevert(StalePriceFeed.selector);
        this.wrapValidatePullPrice(block.timestamp - 61, 60, 100, 1, 1000);
    }

    function testFuzz_validateFreshness_withinDelay(uint256 nowTs, uint256 age, uint256 maxDelay) public {
        nowTs = bound(nowTs, 1, type(uint64).max);
        maxDelay = bound(maxDelay, 0, type(uint64).max);
        // updatedAt must be > 0 (module rule).
        uint256 maxAge = maxDelay < nowTs ? maxDelay : nowTs - 1;
        age = bound(age, 0, maxAge);
        vm.warp(nowTs);
        OracleValidationLib.validateFreshness(nowTs - age, maxDelay);
    }

    function testFuzz_validateFreshness_stale(uint256 nowTs, uint256 maxDelay, uint256 overflow) public {
        nowTs = bound(nowTs, 2, type(uint64).max);
        maxDelay = bound(maxDelay, 0, nowTs - 1);
        overflow = bound(overflow, 1, nowTs - maxDelay);
        uint256 updatedAt = nowTs - maxDelay - overflow;
        vm.warp(nowTs);
        vm.expectRevert(StalePriceFeed.selector);
        this.wrapValidateFreshness(updatedAt, maxDelay);
    }

    function testFuzz_validateAnswer_positive(uint256 raw) public pure {
        int256 answer = int256(bound(raw, 1, uint256(type(int256).max)));
        OracleValidationLib.validateAnswer(answer);
    }

    function testFuzz_validateBounds_inside(uint256 answerRaw, uint256 minRaw, uint256 maxRaw) public pure {
        int256 minAnswer = int256(bound(minRaw, 1, uint256(uint128(type(int128).max))));
        int256 maxAnswer = int256(bound(maxRaw, uint256(minAnswer), uint256(uint128(type(int128).max))));
        int256 answer = int256(bound(answerRaw, uint256(minAnswer), uint256(maxAnswer)));
        OracleValidationLib.validateBounds(answer, minAnswer, maxAnswer);
    }

    // --- wrappers (vm.expectRevert necesita llamada externa) ---

    function wrapValidateRound(uint80 roundId, uint80 answeredInRound) external pure {
        OracleValidationLib.validateRound(roundId, answeredInRound);
    }

    function wrapValidateFreshness(uint256 updatedAt, uint256 maxDelay) external view {
        OracleValidationLib.validateFreshness(updatedAt, maxDelay);
    }

    function wrapValidateAnswer(int256 answer) external pure {
        OracleValidationLib.validateAnswer(answer);
    }

    function wrapValidateBounds(int256 answer, int256 minAnswer, int256 maxAnswer) external pure {
        OracleValidationLib.validateBounds(answer, minAnswer, maxAnswer);
    }

    function wrapValidateAggregatorRound(
        uint80 roundId,
        uint80 answeredInRound,
        uint256 updatedAt,
        uint256 maxDelay,
        int256 answer,
        int256 minAnswer,
        int256 maxAnswer
    ) external view {
        OracleValidationLib.validateAggregatorRound(
            roundId, answeredInRound, updatedAt, maxDelay, answer, minAnswer, maxAnswer
        );
    }

    function wrapValidatePullPrice(
        uint256 publishTime,
        uint256 maxAge,
        int256 answer,
        int256 minAnswer,
        int256 maxAnswer
    ) external view {
        OracleValidationLib.validatePullPrice(publishTime, maxAge, answer, minAnswer, maxAnswer);
    }
}
