// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    InvalidOracleConfig,
    InvalidOraclePrice,
    OracleRoundIncomplete,
    StalePriceFeed,
    ZeroAddress
} from "../src/errors/OracleErrors.sol";
import {ChainlinkPriceFeed} from "../src/feeds/ChainlinkPriceFeed.sol";
import {MockAggregatorV3} from "../src/mocks/MockAggregatorV3.sol";

contract ChainlinkPriceFeedTest is Test {
    uint256 internal constant MAX_DELAY = 1 hours;
    int256 internal constant MIN_ANSWER = 1e8;
    int256 internal constant MAX_ANSWER = 1_000_000e8;

    MockAggregatorV3 internal agg;
    ChainlinkPriceFeed internal feed;

    function setUp() public {
        agg = new MockAggregatorV3(8, "ETH / USD");
        feed = new ChainlinkPriceFeed(address(agg), MAX_DELAY, MIN_ANSWER, MAX_ANSWER);
        vm.warp(1_700_000_000);
    }

    function test_constructor_zeroAggregator_reverts() public {
        vm.expectRevert(ZeroAddress.selector);
        new ChainlinkPriceFeed(address(0), MAX_DELAY, MIN_ANSWER, MAX_ANSWER);
    }

    function test_constructor_zeroMaxDelay_reverts() public {
        vm.expectRevert(InvalidOracleConfig.selector);
        new ChainlinkPriceFeed(address(agg), 0, MIN_ANSWER, MAX_ANSWER);
    }

    function test_constructor_badBounds_reverts() public {
        vm.expectRevert(InvalidOracleConfig.selector);
        new ChainlinkPriceFeed(address(agg), MAX_DELAY, 0, MAX_ANSWER);

        vm.expectRevert(InvalidOracleConfig.selector);
        new ChainlinkPriceFeed(address(agg), MAX_DELAY, MAX_ANSWER, MIN_ANSWER);
    }

    function test_decimals_delegatesToAggregator() public view {
        assertEq(feed.decimals(), 8);
    }

    function test_getValidatedPrice_ok() public {
        agg.setRoundData(1, 2000e8, block.timestamp, block.timestamp, 1);
        assertEq(feed.getValidatedPrice(), 2000e8);
        assertEq(feed.latestPrice(), 2000e8);
    }

    function test_stale_reverts() public {
        uint256 updatedAt = block.timestamp - MAX_DELAY - 1;
        agg.setRoundData(1, 2000e8, updatedAt, updatedAt, 1);
        vm.expectRevert(StalePriceFeed.selector);
        feed.getValidatedPrice();
    }

    function test_updatedAtZero_reverts() public {
        agg.setRoundData(1, 2000e8, 0, 0, 1);
        vm.expectRevert(StalePriceFeed.selector);
        feed.getValidatedPrice();
    }

    function test_incompleteRound_reverts() public {
        agg.setRoundData(5, 2000e8, block.timestamp, block.timestamp, 4);
        vm.expectRevert(OracleRoundIncomplete.selector);
        feed.getValidatedPrice();
    }

    function test_zeroAnswer_reverts() public {
        // minAnswer is 1e8; also answer <= 0 fails validateAnswer first if we set 0
        // Use answer below min but > 0 to hit bounds, and 0 for answer check
        agg.setRoundData(1, 0, block.timestamp, block.timestamp, 1);
        vm.expectRevert(InvalidOraclePrice.selector);
        feed.getValidatedPrice();
    }

    function test_negativeAnswer_reverts() public {
        agg.setRoundData(1, -1, block.timestamp, block.timestamp, 1);
        vm.expectRevert(InvalidOraclePrice.selector);
        feed.getValidatedPrice();
    }

    function test_belowMinAnswer_reverts() public {
        agg.setRoundData(1, MIN_ANSWER - 1, block.timestamp, block.timestamp, 1);
        vm.expectRevert(InvalidOraclePrice.selector);
        feed.getValidatedPrice();
    }

    function test_aboveMaxAnswer_reverts() public {
        agg.setRoundData(1, MAX_ANSWER + 1, block.timestamp, block.timestamp, 1);
        vm.expectRevert(InvalidOraclePrice.selector);
        feed.getValidatedPrice();
    }

    function test_atBounds_ok() public {
        agg.setRoundData(1, MIN_ANSWER, block.timestamp, block.timestamp, 1);
        assertEq(feed.getValidatedPrice(), MIN_ANSWER);

        agg.setRoundData(2, MAX_ANSWER, block.timestamp, block.timestamp, 2);
        assertEq(feed.getValidatedPrice(), MAX_ANSWER);
    }

    function test_exactlyMaxDelay_ok() public {
        uint256 updatedAt = block.timestamp - MAX_DELAY;
        agg.setRoundData(1, 2000e8, updatedAt, updatedAt, 1);
        assertEq(feed.getValidatedPrice(), 2000e8);
    }

    function testFuzz_validPrice(uint256 age, uint256 answerRaw) public {
        age = bound(age, 0, MAX_DELAY);
        int256 answer = int256(bound(answerRaw, uint256(MIN_ANSWER), uint256(MAX_ANSWER)));
        uint256 updatedAt = block.timestamp - age;
        agg.setRoundData(1, answer, updatedAt, updatedAt, 1);
        assertEq(feed.getValidatedPrice(), answer);
    }

    function testFuzz_staleReverts(uint256 overflow) public {
        overflow = bound(overflow, 1, 30 days);
        uint256 updatedAt = block.timestamp - MAX_DELAY - overflow;
        // Keep updatedAt > 0
        if (updatedAt == 0) updatedAt = 1;
        vm.warp(updatedAt + MAX_DELAY + overflow);
        agg.setRoundData(1, 2000e8, updatedAt, updatedAt, 1);
        vm.expectRevert(StalePriceFeed.selector);
        feed.getValidatedPrice();
    }
}
