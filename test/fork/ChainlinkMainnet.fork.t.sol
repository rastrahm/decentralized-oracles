// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ChainlinkPriceFeed} from "../../src/feeds/ChainlinkPriceFeed.sol";

/**
 * @title ChainlinkMainnetForkTest
 * @notice Lee el feed ETH/USD de Chainlink en mainnet fork si hay `MAINNET_RPC_URL`.
 * @dev Sin RPC la suite se salta (`vm.skip`). Address: `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`.
 */
contract ChainlinkMainnetForkTest is Test {
    /// @dev Chainlink ETH/USD proxy (Ethereum mainnet).
    address internal constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    uint256 internal constant MAX_DELAY = 1 days;
    int256 internal constant MIN_ANSWER = 1e8; // $1
    int256 internal constant MAX_ANSWER = 1_000_000e8; // $1M

    bool internal forked;
    ChainlinkPriceFeed internal feed;

    function setUp() public {
        string memory rpc;
        try vm.envString("MAINNET_RPC_URL") returns (string memory url) {
            rpc = url;
        } catch {
            return;
        }
        if (bytes(rpc).length == 0) {
            return;
        }

        vm.createSelectFork(rpc);
        forked = true;
        feed = new ChainlinkPriceFeed(ETH_USD_FEED, MAX_DELAY, MIN_ANSWER, MAX_ANSWER);
    }

    function _skipIfNoFork() internal {
        if (!forked) {
            vm.skip(true);
        }
    }

    function testFork_ethUsd_decimals() public {
        _skipIfNoFork();
        assertEq(feed.decimals(), 8);
        assertEq(AggregatorV3Interface(ETH_USD_FEED).decimals(), 8);
    }

    function testFork_ethUsd_getValidatedPrice_positive() public {
        _skipIfNoFork();
        int256 price = feed.getValidatedPrice();
        assertGt(price, MIN_ANSWER);
        assertLt(price, MAX_ANSWER);
    }

    function testFork_ethUsd_matchesAggregatorAnswer() public {
        _skipIfNoFork();
        (, int256 answer,,,) = AggregatorV3Interface(ETH_USD_FEED).latestRoundData();
        assertEq(feed.getValidatedPrice(), answer);
    }
}
