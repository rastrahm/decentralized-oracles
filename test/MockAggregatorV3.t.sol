// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockAggregatorV3} from "../src/mocks/MockAggregatorV3.sol";

contract MockAggregatorV3Test is Test {
    MockAggregatorV3 internal agg;

    function setUp() public {
        agg = new MockAggregatorV3(8, "ETH / USD");
    }

    function test_decimals_and_metadata() public view {
        assertEq(agg.decimals(), 8);
        assertEq(agg.description(), "ETH / USD");
        assertEq(agg.version(), 1);
    }

    function test_setRoundData_latestRoundData() public {
        agg.setRoundData(3, 2000e8, 100, 150, 3);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            agg.latestRoundData();
        assertEq(roundId, 3);
        assertEq(answer, 2000e8);
        assertEq(startedAt, 100);
        assertEq(updatedAt, 150);
        assertEq(answeredInRound, 3);
    }

    function test_setRoundData_incompleteRound() public {
        agg.setRoundData(5, 100e8, 1, 2, 4); // answeredInRound < roundId
        (,,,, uint80 answeredInRound) = agg.latestRoundData();
        assertEq(answeredInRound, 4);
        (uint80 roundId,,,,) = agg.latestRoundData();
        assertEq(roundId, 5);
        assertTrue(answeredInRound < roundId);
    }

    function test_getRoundData_readsStored() public {
        agg.setRoundData(7, 123e8, 10, 20, 7);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            agg.getRoundData(7);
        assertEq(roundId, 7);
        assertEq(answer, 123e8);
        assertEq(startedAt, 10);
        assertEq(updatedAt, 20);
        assertEq(answeredInRound, 7);
    }

    function test_getRoundData_missing_reverts() public {
        vm.expectRevert(MockAggregatorV3.RoundNotFound.selector);
        agg.getRoundData(99);
    }

    function test_setLatestAnswer_incrementsRound() public {
        agg.setLatestAnswer(1000e8, 500);
        (uint80 r1, int256 a1,, uint256 u1, uint80 ar1) = agg.latestRoundData();
        assertEq(r1, 1);
        assertEq(a1, 1000e8);
        assertEq(u1, 500);
        assertEq(ar1, 1);

        agg.setLatestAnswer(1100e8, 600);
        (uint80 r2, int256 a2,, uint256 u2, uint80 ar2) = agg.latestRoundData();
        assertEq(r2, 2);
        assertEq(a2, 1100e8);
        assertEq(u2, 600);
        assertEq(ar2, 2);
    }

    function test_setRoundData_zeroUpdatedAt_and_negative() public {
        agg.setRoundData(1, -1, 0, 0, 1);
        (, int256 answer,, uint256 updatedAt,) = agg.latestRoundData();
        assertEq(answer, -1);
        assertEq(updatedAt, 0);
    }

    function testFuzz_setRoundData(uint80 roundId, int256 answer, uint256 updatedAt, uint80 answeredInRound)
        public
    {
        vm.assume(roundId != 0);
        agg.setRoundData(roundId, answer, updatedAt, updatedAt, answeredInRound);
        (uint80 r, int256 a,, uint256 u, uint80 ar) = agg.latestRoundData();
        assertEq(r, roundId);
        assertEq(a, answer);
        assertEq(u, updatedAt);
        assertEq(ar, answeredInRound);
        (uint80 gr, int256 ga,, uint256 gu, uint80 gar) = agg.getRoundData(roundId);
        assertEq(gr, roundId);
        assertEq(ga, answer);
        assertEq(gu, updatedAt);
        assertEq(gar, answeredInRound);
    }
}
