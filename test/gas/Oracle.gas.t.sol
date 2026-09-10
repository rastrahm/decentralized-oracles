// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChainlinkPriceFeed} from "../../src/feeds/ChainlinkPriceFeed.sol";
import {PythPriceFeed} from "../../src/feeds/PythPriceFeed.sol";
import {PriceOracleConsumer} from "../../src/consumer/PriceOracleConsumer.sol";
import {MockAggregatorV3} from "../../src/mocks/MockAggregatorV3.sol";
import {MockPyth} from "../../src/mocks/MockPyth.sol";

/**
 * @title OracleGasTest
 * @notice Fase 6: coste Push vs Pull vs lectura cruda (`forge test --gas-report` / snapshot).
 */
contract OracleGasTest is Test {
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
    bytes[] internal updateData;

    function setUp() public {
        agg = new MockAggregatorV3(8, "ETH / USD");
        pyth = new MockPyth(MAX_AGE, FEE);
        pushFeed = new ChainlinkPriceFeed(address(agg), MAX_DELAY, MIN_ANSWER, MAX_ANSWER);
        pullFeed = new PythPriceFeed(address(pyth), PRICE_ID, MAX_AGE, MIN_ANSWER, MAX_ANSWER, 8);
        consumer = new PriceOracleConsumer(address(pushFeed), address(pullFeed));

        vm.warp(1_700_000_000);
        vm.deal(address(this), 10 ether);

        agg.setRoundData(1, 2000e8, block.timestamp, block.timestamp, 1);
        updateData = new bytes[](1);
        updateData[0] = pyth.createUpdateData(PRICE_ID, 2000e8, 1, -8, uint64(block.timestamp));
    }

    /// @notice Baseline: lectura cruda AggregatorV3 sin validación.
    function testGas_rawLatestRoundData() public view {
        agg.latestRoundData();
    }

    /// @notice Push validado vía `ChainlinkPriceFeed`.
    function testGas_push_getValidatedPrice() public view {
        pushFeed.getValidatedPrice();
    }

    /// @notice Push vía consumer.
    function testGas_consumer_getPushPrice() public view {
        consumer.getPushPrice();
    }

    /// @notice Push + escala a 18 decimals.
    function testGas_consumer_getPushPriceScaled18() public view {
        consumer.getPushPriceScaled18();
    }

    /// @notice Pull: update + validate en `PythPriceFeed`.
    function testGas_pull_updateAndGetPrice() public {
        pullFeed.updateAndGetPrice{value: FEE}(updateData);
    }

    /// @notice Pull vía consumer (fee exacto + sin refund path).
    function testGas_consumer_getPullPrice() public {
        // Nuevo publishTime para que el mock acepte overwrite en corridas repetidas.
        bytes[] memory data = new bytes[](1);
        data[0] = pyth.createUpdateData(PRICE_ID, 2000e8, 1, -8, uint64(block.timestamp));
        consumer.getPullPrice{value: FEE}(data);
    }

    receive() external payable {}
}
