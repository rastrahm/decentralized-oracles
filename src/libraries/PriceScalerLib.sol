// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {InvalidOracleConfig, InvalidOraclePrice} from "../errors/OracleErrors.sol";

/**
 * @title PriceScalerLib
 * @notice Escalado de precios entre distintas precisiones decimales (p. ej. 8 → 18).
 */
library PriceScalerLib {
    uint8 internal constant MAX_DECIMALS = 18;

    /**
     * @notice Escala `price` de `fromDecimals` a `toDecimals`.
     * @param price Precio de entrada (típicamente > 0 tras validación).
     * @param fromDecimals Decimales de origen.
     * @param toDecimals Decimales de destino.
     * @return scaled Precio en la escala destino.
     */
    function scale(int256 price, uint8 fromDecimals, uint8 toDecimals) internal pure returns (int256 scaled) {
        if (fromDecimals > MAX_DECIMALS || toDecimals > MAX_DECIMALS) revert InvalidOracleConfig();
        if (price <= 0) revert InvalidOraclePrice();
        if (fromDecimals == toDecimals) return price;

        if (fromDecimals < toDecimals) {
            uint8 delta = toDecimals - fromDecimals;
            int256 factor = int256(10 ** uint256(delta));
            if (price > type(int256).max / factor) revert InvalidOraclePrice();
            return price * factor;
        }

        uint8 down = fromDecimals - toDecimals;
        return price / int256(10 ** uint256(down));
    }

    /**
     * @notice Atajo: escala a 18 decimales.
     * @param price Precio de entrada.
     * @param fromDecimals Decimales de origen.
     * @return scaled Precio en 18 decimales.
     */
    function to18Decimals(int256 price, uint8 fromDecimals) internal pure returns (int256 scaled) {
        return scale(price, fromDecimals, 18);
    }
}
