// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IPriceFeed
 * @notice API unificada de lectura de precio validado (Push o Pull ya materializado).
 * @dev Chainlink Push y Pyth Pull se consumen vía remappings de Foundry (ver remappings.txt).
 */
interface IPriceFeed {
    /// @notice Decimales con los que se expresa el precio crudo del feed.
    function decimals() external view returns (uint8);

    /// @notice Precio validado más reciente (staleness, round y bounds aplicados).
    /// @return price Precio en la escala de `decimals()` (típicamente > 0).
    function getValidatedPrice() external view returns (int256 price);
}
