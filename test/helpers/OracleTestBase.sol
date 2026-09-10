// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChainlinkPriceFeed} from "../../src/feeds/ChainlinkPriceFeed.sol";
import {PythPriceFeed} from "../../src/feeds/PythPriceFeed.sol";
import {PriceOracleConsumer} from "../../src/consumer/PriceOracleConsumer.sol";
import {MockAggregatorV3} from "../../src/mocks/MockAggregatorV3.sol";
import {MockPyth} from "../../src/mocks/MockPyth.sol";

/**
 * @title OracleTestBase
 * @notice Helpers compartidos para suites e2e / fuzz del módulo.
 */
abstract contract OracleTestBase is Test {
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

    function _deployStack() internal {
        agg = new MockAggregatorV3(8, "ETH / USD");
        pyth = new MockPyth(MAX_AGE, FEE);
        pushFeed = new ChainlinkPriceFeed(address(agg), MAX_DELAY, MIN_ANSWER, MAX_ANSWER);
        pullFeed = new PythPriceFeed(address(pyth), PRICE_ID, MAX_AGE, MIN_ANSWER, MAX_ANSWER, 8);
        consumer = new PriceOracleConsumer(address(pushFeed), address(pullFeed));
    }

    function _pythUpdate(int64 price, uint64 publishTime) internal view returns (bytes[] memory updateData) {
        updateData = new bytes[](1);
        updateData[0] = pyth.createUpdateData(PRICE_ID, price, 1, -8, publishTime);
    }
}
