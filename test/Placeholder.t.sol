// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {Placeholder} from "../src/Placeholder.sol";

/// @notice Smoke test de Fase 0: compilación, forge-std y remappings Chainlink/Pyth.
contract PlaceholderTest is Test {
    function test_ok() public {
        Placeholder p = new Placeholder();
        assertTrue(p.ok());
    }

    /// @dev Solo tipado: confirma que AggregatorV3Interface e IPyth resuelven vía remappings.
    function test_remappings_resolve() public pure {
        AggregatorV3Interface agg;
        IPyth pyth;
        agg;
        pyth;
    }
}
