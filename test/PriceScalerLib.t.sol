// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {InvalidOracleConfig, InvalidOraclePrice} from "../src/errors/OracleErrors.sol";
import {PriceScalerLib} from "../src/libraries/PriceScalerLib.sol";

contract PriceScalerLibTest is Test {
    function test_scale_sameDecimals() public pure {
        assertEq(PriceScalerLib.scale(123e8, 8, 8), 123e8);
    }

    function test_scale_8_to_18() public pure {
        assertEq(PriceScalerLib.scale(2000e8, 8, 18), 2000e18);
        assertEq(PriceScalerLib.to18Decimals(2000e8, 8), 2000e18);
    }

    function test_scale_18_to_8() public pure {
        assertEq(PriceScalerLib.scale(2000e18, 18, 8), 2000e8);
    }

    function test_scale_zeroPrice_reverts() public {
        vm.expectRevert(InvalidOraclePrice.selector);
        this.wrapScale(0, 8, 18);
    }

    function test_scale_negative_reverts() public {
        vm.expectRevert(InvalidOraclePrice.selector);
        this.wrapScale(-1, 8, 18);
    }

    function test_scale_tooManyDecimals_reverts() public {
        vm.expectRevert(InvalidOracleConfig.selector);
        this.wrapScale(1e8, 19, 18);
    }

    function test_scale_overflow_reverts() public {
        vm.expectRevert(InvalidOraclePrice.selector);
        this.wrapScale(type(int256).max, 0, 18);
    }

    function testFuzz_scale_roundTrip_downThenUp(uint256 raw, uint8 fromDec) public pure {
        fromDec = uint8(bound(fromDec, 0, 18));
        uint256 factor = 10 ** uint256(18 - fromDec);
        uint256 maxPrice = uint256(type(int256).max) / factor;
        int256 price = int256(bound(raw, 1, maxPrice));

        int256 to18 = PriceScalerLib.to18Decimals(price, fromDec);
        if (fromDec < 18) {
            assertEq(to18, price * int256(factor));
        } else {
            assertEq(to18, price);
        }

        int256 back = PriceScalerLib.scale(to18, 18, fromDec);
        assertEq(back, price);
    }

    function testFuzz_scale_8_vs_18(uint256 raw) public pure {
        int256 price8 = int256(bound(raw, 1, 1e15)); // headroom * 1e10
        int256 price18 = PriceScalerLib.scale(price8, 8, 18);
        assertEq(price18, price8 * 1e10);
        assertEq(PriceScalerLib.scale(price18, 18, 8), price8);
    }

    function wrapScale(int256 price, uint8 fromDecimals, uint8 toDecimals) external pure returns (int256) {
        return PriceScalerLib.scale(price, fromDecimals, toDecimals);
    }
}
