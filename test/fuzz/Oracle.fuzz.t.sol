// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    InvalidOraclePrice,
    OracleRoundIncomplete,
    StalePriceFeed
} from "../../src/errors/OracleErrors.sol";
import {PriceOracleConsumer} from "../../src/consumer/PriceOracleConsumer.sol";
import {ChainlinkPriceFeed} from "../../src/feeds/ChainlinkPriceFeed.sol";
import {PythPriceFeed} from "../../src/feeds/PythPriceFeed.sol";
import {MockAggregatorV3} from "../../src/mocks/MockAggregatorV3.sol";
import {MockPyth} from "../../src/mocks/MockPyth.sol";
import {PriceScalerLib} from "../../src/libraries/PriceScalerLib.sol";

/**
 * @title OracleFuzzTest
 * @notice Fuzz de answers, delays y escalado 8↔18 sobre consumer + feeds.
 */
contract OracleFuzzTest is Test {
    uint256 internal constant MAX_DELAY = 1 hours;
    uint256 internal constant MAX_AGE = 60;
    uint256 internal constant FEE = 1 wei;
    int256 internal constant MIN_ANSWER = 1e8;
    int256 internal constant MAX_ANSWER = 50_000e8;
    bytes32 internal constant PRICE_ID = keccak256("ETH/USD");

    MockAggregatorV3 internal agg;
    MockPyth internal pyth;
    ChainlinkPriceFeed internal pushFeed;
    PythPriceFeed internal pullFeed;
    PriceOracleConsumer internal consumer;

    function setUp() public {
        agg = new MockAggregatorV3(8, "ETH / USD");
        pyth = new MockPyth(MAX_AGE, FEE);
        pushFeed = new ChainlinkPriceFeed(address(agg), MAX_DELAY, MIN_ANSWER, MAX_ANSWER);
        pullFeed = new PythPriceFeed(address(pyth), PRICE_ID, MAX_AGE, MIN_ANSWER, MAX_ANSWER, 8);
        consumer = new PriceOracleConsumer(address(pushFeed), address(pullFeed));
        vm.warp(1_700_000_000);
        vm.deal(address(this), 100 ether);
    }

    function testFuzz_push_validAnswerAndAge(uint256 age, uint256 answerRaw) public {
        age = bound(age, 0, MAX_DELAY);
        int256 answer = int256(bound(answerRaw, uint256(MIN_ANSWER), uint256(MAX_ANSWER)));
        uint256 updatedAt = block.timestamp - age;
        agg.setRoundData(1, answer, updatedAt, updatedAt, 1);
        assertEq(consumer.getPushPrice(), answer);
        assertEq(consumer.getPushPriceScaled18(), uint256(PriceScalerLib.to18Decimals(answer, 8)));
    }

    function testFuzz_push_stale(uint256 overflow) public {
        overflow = bound(overflow, 1, 30 days);
        uint256 updatedAt = block.timestamp - MAX_DELAY - overflow;
        if (updatedAt == 0) {
            updatedAt = 1;
            vm.warp(updatedAt + MAX_DELAY + overflow);
        }
        agg.setRoundData(1, 2000e8, updatedAt, updatedAt, 1);
        vm.expectRevert(StalePriceFeed.selector);
        consumer.getPushPrice();
    }

    function testFuzz_push_incompleteRound(uint80 roundId, uint80 answeredInRound) public {
        roundId = uint80(bound(roundId, 1, type(uint80).max));
        answeredInRound = uint80(bound(answeredInRound, 0, roundId - 1));
        agg.setRoundData(roundId, 2000e8, block.timestamp, block.timestamp, answeredInRound);
        vm.expectRevert(OracleRoundIncomplete.selector);
        consumer.getPushPrice();
    }

    function testFuzz_push_outOfBoundsOrNonPositive(int256 answer) public {
        vm.assume(answer <= 0 || answer < MIN_ANSWER || answer > MAX_ANSWER);
        agg.setRoundData(1, answer, block.timestamp, block.timestamp, 1);
        vm.expectRevert(InvalidOraclePrice.selector);
        consumer.getPushPrice();
    }

    function testFuzz_pull_validAnswerAndAge(uint256 age, uint256 answerRaw) public {
        age = bound(age, 0, MAX_AGE);
        int256 answer = int256(bound(answerRaw, uint256(MIN_ANSWER), uint256(MAX_ANSWER)));
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = pyth.createUpdateData(PRICE_ID, int64(answer), 1, -8, uint64(block.timestamp - age));
        assertEq(consumer.getPullPrice{value: FEE}(updateData), answer);
    }

    function testFuzz_scale_8_to_18(uint256 answerRaw) public {
        int256 answer = int256(bound(answerRaw, 1, 1e15));
        assertEq(PriceScalerLib.scale(answer, 8, 18), answer * 1e10);
        assertEq(PriceScalerLib.scale(answer * 1e10, 18, 8), answer);
    }

    receive() external payable {}
}
