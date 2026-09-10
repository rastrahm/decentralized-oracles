// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    InsufficientFee,
    InvalidOraclePrice,
    StalePriceFeed,
    ZeroAddress
} from "../src/errors/OracleErrors.sol";
import {PriceOracleConsumer} from "../src/consumer/PriceOracleConsumer.sol";
import {ChainlinkPriceFeed} from "../src/feeds/ChainlinkPriceFeed.sol";
import {PythPriceFeed} from "../src/feeds/PythPriceFeed.sol";
import {MockAggregatorV3} from "../src/mocks/MockAggregatorV3.sol";
import {MockPyth} from "../src/mocks/MockPyth.sol";

/**
 * @title PriceOracleConsumerTest
 * @notice E2E Push/Pull vía mocks + consumer.
 */
contract PriceOracleConsumerTest is Test {
    uint256 internal constant MAX_DELAY = 1 hours;
    uint256 internal constant MAX_AGE = 60;
    uint256 internal constant FEE = 1 wei;
    int256 internal constant MIN_ANSWER = 1e8;
    int256 internal constant MAX_ANSWER = 1_000_000e8;
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
        vm.deal(address(this), 10 ether);
    }

    function test_constructor_zero_reverts() public {
        vm.expectRevert(ZeroAddress.selector);
        new PriceOracleConsumer(address(0), address(pullFeed));
        vm.expectRevert(ZeroAddress.selector);
        new PriceOracleConsumer(address(pushFeed), address(0));
    }

    function test_e2e_push_ok_and_scaled18() public {
        agg.setRoundData(1, 2000e8, block.timestamp, block.timestamp, 1);
        assertEq(consumer.getPushPrice(), 2000e8);
        assertEq(consumer.getPushPriceScaled18(), 2000e18);
    }

    function test_e2e_push_stale_reverts() public {
        uint256 updatedAt = block.timestamp - MAX_DELAY - 1;
        agg.setRoundData(1, 2000e8, updatedAt, updatedAt, 1);
        vm.expectRevert(StalePriceFeed.selector);
        consumer.getPushPrice();
    }

    function test_e2e_push_zero_reverts() public {
        agg.setRoundData(1, 0, block.timestamp, block.timestamp, 1);
        vm.expectRevert(InvalidOraclePrice.selector);
        consumer.getPushPrice();
    }

    function test_e2e_pull_ok_and_scaled18() public {
        bytes[] memory updateData = _updateData(2500e8, uint64(block.timestamp));
        assertEq(consumer.getPullPrice{value: FEE}(updateData), 2500e8);

        bytes[] memory updateData2 = _updateData(2500e8, uint64(block.timestamp));
        assertEq(consumer.getPullPriceScaled18{value: FEE}(updateData2), 2500e18);
    }

    function test_e2e_pull_refundsExcess() public {
        bytes[] memory updateData = _updateData(2500e8, uint64(block.timestamp));
        uint256 beforeBal = address(this).balance;
        consumer.getPullPrice{value: 1 ether}(updateData);
        assertEq(address(this).balance, beforeBal - FEE);
        assertEq(address(consumer).balance, 0);
        assertEq(address(pyth).balance, FEE);
    }

    function test_e2e_pull_insufficientFee_reverts() public {
        bytes[] memory updateData = _updateData(2500e8, uint64(block.timestamp));
        vm.expectRevert(InsufficientFee.selector);
        consumer.getPullPrice{value: 0}(updateData);
    }

    function test_e2e_pull_stale_reverts() public {
        bytes[] memory updateData = _updateData(2500e8, uint64(block.timestamp - MAX_AGE - 1));
        vm.expectRevert(StalePriceFeed.selector);
        consumer.getPullPrice{value: FEE}(updateData);
    }

    function test_e2e_pull_negative_reverts() public {
        bytes[] memory updateData = _updateData(-1, uint64(block.timestamp));
        vm.expectRevert(InvalidOraclePrice.selector);
        consumer.getPullPrice{value: FEE}(updateData);
    }

    function _updateData(int64 price, uint64 publishTime) internal view returns (bytes[] memory updateData) {
        updateData = new bytes[](1);
        updateData[0] = pyth.createUpdateData(PRICE_ID, price, 1, -8, publishTime);
    }

    receive() external payable {}
}
