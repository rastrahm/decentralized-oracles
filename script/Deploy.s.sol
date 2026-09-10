// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ChainlinkPriceFeed} from "../src/feeds/ChainlinkPriceFeed.sol";
import {PythPriceFeed} from "../src/feeds/PythPriceFeed.sol";
import {PriceOracleConsumer} from "../src/consumer/PriceOracleConsumer.sol";
import {MockAggregatorV3} from "../src/mocks/MockAggregatorV3.sol";
import {MockPyth} from "../src/mocks/MockPyth.sol";

/**
 * @title Deploy
 * @notice Despliega stack local (mocks + feeds + consumer) o cablea addresses mainnet vía env.
 * @dev Ejemplo Anvil:
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 *
 * Env opcionales:
 * - `PRIVATE_KEY` — deployer (default Anvil #0)
 * - `CHAINLINK_AGGREGATOR` — si se setea, no despliega MockAggregatorV3 (p. ej. ETH/USD mainnet)
 * - `PYTH` — si se setea, no despliega MockPyth
 * - `PYTH_PRICE_ID` — price id Pyth (default keccak256("ETH/USD") solo para mocks)
 * - `MAX_DELAY` / `MAX_AGE` — staleness (default 1 hours / 60)
 * - `MIN_ANSWER` / `MAX_ANSWER` — bounds (default 1e8 / 1_000_000e8)
 * - `MOCK_SEED_PRICE` — si hay mock aggregator, seed inicial (default 2000e8)
 */
contract Deploy is Script {
    /// @dev Chainlink ETH/USD proxy (Ethereum mainnet) — referencia documentada.
    address internal constant MAINNET_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);

        uint256 maxDelay = vm.envOr("MAX_DELAY", uint256(1 hours));
        uint256 maxAge = vm.envOr("MAX_AGE", uint256(60));
        int256 minAnswer = int256(vm.envOr("MIN_ANSWER", uint256(1e8)));
        int256 maxAnswer = int256(vm.envOr("MAX_ANSWER", uint256(1_000_000e8)));
        int256 seedPrice = int256(vm.envOr("MOCK_SEED_PRICE", uint256(2000e8)));

        address aggregatorAddr = vm.envOr("CHAINLINK_AGGREGATOR", address(0));
        address pythAddr = vm.envOr("PYTH", address(0));
        bytes32 priceId = vm.envOr("PYTH_PRICE_ID", keccak256("ETH/USD"));

        vm.startBroadcast(pk);

        if (aggregatorAddr == address(0)) {
            MockAggregatorV3 mockAgg = new MockAggregatorV3(8, "ETH / USD");
            mockAgg.setRoundData(1, seedPrice, block.timestamp, block.timestamp, 1);
            aggregatorAddr = address(mockAgg);
        }

        if (pythAddr == address(0)) {
            MockPyth mockPyth = new MockPyth(maxAge, 1 wei);
            pythAddr = address(mockPyth);
        }

        ChainlinkPriceFeed pushFeed = new ChainlinkPriceFeed(aggregatorAddr, maxDelay, minAnswer, maxAnswer);
        PythPriceFeed pullFeed = new PythPriceFeed(pythAddr, priceId, maxAge, minAnswer, maxAnswer, 8);
        PriceOracleConsumer consumer = new PriceOracleConsumer(address(pushFeed), address(pullFeed));

        vm.stopBroadcast();

        console2.log("=== Decentralized Oracles Deploy (Push/Pull) ===");
        console2.log("Deployer", deployer);
        console2.log("Aggregator", aggregatorAddr);
        console2.log("Pyth", pythAddr);
        console2.log("ChainlinkPriceFeed", address(pushFeed));
        console2.log("PythPriceFeed", address(pullFeed));
        console2.log("PriceOracleConsumer", address(consumer));
        console2.log("Mainnet ETH/USD ref", MAINNET_ETH_USD);
        console2.log("maxDelay", maxDelay);
        console2.log("maxAge", maxAge);
    }
}
