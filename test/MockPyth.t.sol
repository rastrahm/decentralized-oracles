// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {PythErrors} from "@pythnetwork/pyth-sdk-solidity/PythErrors.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {MockPyth} from "../src/mocks/MockPyth.sol";

contract MockPythTest is Test {
    MockPyth internal pyth;
    bytes32 internal constant PRICE_ID = keccak256("ETH/USD");
    uint256 internal constant FEE = 1 wei;
    uint256 internal constant VALID_PERIOD = 60;

    function setUp() public {
        pyth = new MockPyth(VALID_PERIOD, FEE);
        vm.deal(address(this), 10 ether);
    }

    function test_getUpdateFee_scalesWithLength() public view {
        bytes[] memory empty;
        assertEq(pyth.getUpdateFee(empty), 0);

        bytes[] memory one = new bytes[](1);
        one[0] = hex"00";
        assertEq(pyth.getUpdateFee(one), FEE);

        bytes[] memory two = new bytes[](2);
        two[0] = hex"00";
        two[1] = hex"01";
        assertEq(pyth.getUpdateFee(two), 2 * FEE);
    }

    function test_setPrice_then_getPriceUnsafe() public {
        pyth.setPrice{value: FEE}(PRICE_ID, 2000e8, 1, -8, 1_700_000_000);
        PythStructs.Price memory p = pyth.getPriceUnsafe(PRICE_ID);
        assertEq(p.price, 2000e8);
        assertEq(p.conf, 1);
        assertEq(p.expo, -8);
        assertEq(p.publishTime, 1_700_000_000);
    }

    function test_updatePriceFeeds_insufficientFee_reverts() public {
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = pyth.createUpdateData(PRICE_ID, 100e8, 1, -8, 100);
        vm.expectRevert(PythErrors.InsufficientFee.selector);
        pyth.updatePriceFeeds{value: 0}(updateData);
    }

    function test_updatePriceFeeds_ok() public {
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = pyth.createUpdateData(PRICE_ID, 2500e8, 2, -8, 50);
        pyth.updatePriceFeeds{value: FEE}(updateData);
        assertEq(pyth.getPriceUnsafe(PRICE_ID).price, 2500e8);
    }

    function test_getPriceNoOlderThan_ok() public {
        vm.warp(1_000);
        pyth.setPrice{value: FEE}(PRICE_ID, 1800e8, 1, -8, 990);
        PythStructs.Price memory p = pyth.getPriceNoOlderThan(PRICE_ID, 20);
        assertEq(p.price, 1800e8);
    }

    function test_getPriceNoOlderThan_stale_reverts() public {
        vm.warp(1_000);
        pyth.setPrice{value: FEE}(PRICE_ID, 1800e8, 1, -8, 900);
        vm.expectRevert(PythErrors.StalePrice.selector);
        pyth.getPriceNoOlderThan(PRICE_ID, 50);
    }

    function test_getPrice_usesValidTimePeriod() public {
        vm.warp(500);
        pyth.setPrice{value: FEE}(PRICE_ID, 1e8, 1, -8, 450);
        assertEq(pyth.getPrice(PRICE_ID).price, 1e8);

        vm.warp(500 + VALID_PERIOD + 1);
        vm.expectRevert(PythErrors.StalePrice.selector);
        pyth.getPrice(PRICE_ID);
    }

    function test_newerPublishTime_overwrites() public {
        pyth.setPrice{value: FEE}(PRICE_ID, 100e8, 1, -8, 10);
        pyth.setPrice{value: FEE}(PRICE_ID, 200e8, 1, -8, 20);
        assertEq(pyth.getPriceUnsafe(PRICE_ID).price, 200e8);
        assertEq(pyth.getPriceUnsafe(PRICE_ID).publishTime, 20);
    }

    function test_olderPublishTime_ignored() public {
        pyth.setPrice{value: FEE}(PRICE_ID, 200e8, 1, -8, 20);
        pyth.setPrice{value: FEE}(PRICE_ID, 100e8, 1, -8, 10);
        assertEq(pyth.getPriceUnsafe(PRICE_ID).price, 200e8);
    }

    function test_missingFeed_reverts() public {
        vm.expectRevert(PythErrors.PriceFeedNotFound.selector);
        pyth.getPriceUnsafe(keccak256("missing"));
    }

    function testFuzz_setPrice(int64 price, uint64 conf, uint64 publishTime) public {
        vm.assume(publishTime > 0);
        pyth.setPrice{value: FEE}(PRICE_ID, price, conf, -8, publishTime);
        PythStructs.Price memory p = pyth.getPriceUnsafe(PRICE_ID);
        assertEq(p.price, price);
        assertEq(p.conf, conf);
        assertEq(p.publishTime, publishTime);
    }

    receive() external payable {}
}
