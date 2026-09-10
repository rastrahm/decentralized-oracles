// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    InsufficientFee,
    InvalidOracleConfig,
    InvalidOraclePrice,
    StalePriceFeed,
    ZeroAddress
} from "../src/errors/OracleErrors.sol";
import {PythPriceFeed} from "../src/feeds/PythPriceFeed.sol";
import {MockPyth} from "../src/mocks/MockPyth.sol";

contract PythPriceFeedTest is Test {
    uint256 internal constant FEE = 1 wei;
    uint256 internal constant MAX_AGE = 60;
    int256 internal constant MIN_ANSWER = 1e8;
    int256 internal constant MAX_ANSWER = 1_000_000e8;
    bytes32 internal constant PRICE_ID = keccak256("ETH/USD");

    MockPyth internal pyth;
    PythPriceFeed internal feed;

    function setUp() public {
        pyth = new MockPyth(MAX_AGE, FEE);
        feed = new PythPriceFeed(address(pyth), PRICE_ID, MAX_AGE, MIN_ANSWER, MAX_ANSWER, 8);
        vm.warp(1_700_000_000);
        vm.deal(address(this), 10 ether);
    }

    function test_constructor_zeroPyth_reverts() public {
        vm.expectRevert(ZeroAddress.selector);
        new PythPriceFeed(address(0), PRICE_ID, MAX_AGE, MIN_ANSWER, MAX_ANSWER, 8);
    }

    function test_constructor_zeroPriceId_reverts() public {
        vm.expectRevert(InvalidOracleConfig.selector);
        new PythPriceFeed(address(pyth), bytes32(0), MAX_AGE, MIN_ANSWER, MAX_ANSWER, 8);
    }

    function test_constructor_zeroMaxAge_reverts() public {
        vm.expectRevert(InvalidOracleConfig.selector);
        new PythPriceFeed(address(pyth), PRICE_ID, 0, MIN_ANSWER, MAX_ANSWER, 8);
    }

    function test_decimals() public view {
        assertEq(feed.decimals(), 8);
    }

    function test_getUpdateFee_forwards() public view {
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = hex"00";
        assertEq(feed.getUpdateFee(updateData), FEE);
    }

    function test_updateAndGetPrice_ok() public {
        bytes[] memory updateData = _updateData(2000e8, uint64(block.timestamp));
        int256 price = feed.updateAndGetPrice{value: FEE}(updateData);
        assertEq(price, 2000e8);
        assertEq(feed.getValidatedPrice(), 2000e8);
    }

    function test_updateAndGetPrice_refundsExcess() public {
        bytes[] memory updateData = _updateData(2000e8, uint64(block.timestamp));
        uint256 balBefore = address(this).balance;
        feed.updateAndGetPrice{value: 1 ether}(updateData);
        assertEq(address(this).balance, balBefore - FEE);
        assertEq(address(pyth).balance, FEE);
    }

    function test_insufficientFee_reverts() public {
        bytes[] memory updateData = _updateData(2000e8, uint64(block.timestamp));
        vm.expectRevert(InsufficientFee.selector);
        feed.updateAndGetPrice{value: 0}(updateData);
    }

    function test_stale_reverts() public {
        bytes[] memory updateData = _updateData(2000e8, uint64(block.timestamp - MAX_AGE - 1));
        vm.expectRevert(StalePriceFeed.selector);
        feed.updateAndGetPrice{value: FEE}(updateData);
    }

    function test_belowMin_reverts() public {
        bytes[] memory updateData = _updateData(int64(uint64(uint256(MIN_ANSWER) - 1)), uint64(block.timestamp));
        vm.expectRevert(InvalidOraclePrice.selector);
        feed.updateAndGetPrice{value: FEE}(updateData);
    }

    function test_aboveMax_reverts() public {
        int64 high = type(int64).max;
        assertTrue(int256(high) > MAX_ANSWER);
        bytes[] memory updateData = _updateData(high, uint64(block.timestamp));
        vm.expectRevert(InvalidOraclePrice.selector);
        feed.updateAndGetPrice{value: FEE}(updateData);
    }

    function test_zeroPrice_reverts() public {
        bytes[] memory updateData = _updateData(0, uint64(block.timestamp));
        vm.expectRevert(InvalidOraclePrice.selector);
        feed.updateAndGetPrice{value: FEE}(updateData);
    }

    function test_negativePrice_reverts() public {
        bytes[] memory updateData = _updateData(-1, uint64(block.timestamp));
        vm.expectRevert(InvalidOraclePrice.selector);
        feed.updateAndGetPrice{value: FEE}(updateData);
    }

    function test_getValidatedPrice_withoutPriorUpdate_revertsMissing() public {
        // PythErrors.PriceFeedNotFound — no feed yet
        vm.expectRevert();
        feed.getValidatedPrice();
    }

    function test_exactlyMaxAge_ok() public {
        bytes[] memory updateData = _updateData(2000e8, uint64(block.timestamp - MAX_AGE));
        assertEq(feed.updateAndGetPrice{value: FEE}(updateData), 2000e8);
    }

    function testFuzz_updateAndGetPrice(uint256 age, uint256 answerRaw) public {
        age = bound(age, 0, MAX_AGE);
        // MIN_ANSWER..MAX_ANSWER caben en int64 para esta config de test.
        int256 answer = int256(bound(answerRaw, uint256(MIN_ANSWER), uint256(MAX_ANSWER)));

        uint64 publishTime = uint64(block.timestamp - age);
        bytes[] memory updateData = _updateData(int64(answer), publishTime);
        assertEq(feed.updateAndGetPrice{value: FEE}(updateData), answer);
    }

    function _updateData(int64 price, uint64 publishTime) internal view returns (bytes[] memory updateData) {
        updateData = new bytes[](1);
        updateData[0] = pyth.createUpdateData(PRICE_ID, price, 1, -8, publishTime);
    }

    receive() external payable {}
}
