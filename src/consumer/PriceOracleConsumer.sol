// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {PythPriceFeed} from "../feeds/PythPriceFeed.sol";
import {EthTransferFailed, InsufficientFee, ZeroAddress} from "../errors/OracleErrors.sol";
import {PriceScalerLib} from "../libraries/PriceScalerLib.sol";

/**
 * @title PriceOracleConsumer
 * @notice Fachada Push/Pull para protocolos: lee Chainlink o actualiza/lee Pyth, con escala a 18 decimals.
 * @dev En Pull se paga el fee exacto al feed y el exceso se refunde al caller (no al consumer).
 */
contract PriceOracleConsumer {
    /// @notice Feed Push (p. ej. `ChainlinkPriceFeed`).
    IPriceFeed public immutable pushFeed;

    /// @notice Feed Pull Pyth.
    PythPriceFeed public immutable pullFeed;

    /**
     * @param pushFeed_ Consumer Push (`IPriceFeed`).
     * @param pullFeed_ Consumer Pull (`PythPriceFeed`).
     */
    constructor(address pushFeed_, address pullFeed_) {
        if (pushFeed_ == address(0) || pullFeed_ == address(0)) revert ZeroAddress();
        pushFeed = IPriceFeed(pushFeed_);
        pullFeed = PythPriceFeed(pullFeed_);
    }

    /**
     * @notice Precio Push validado (escala nativa del feed).
     * @return price Precio Chainlink/mock validado.
     */
    function getPushPrice() external view returns (int256 price) {
        return pushFeed.getValidatedPrice();
    }

    /**
     * @notice Actualiza Pyth y retorna precio Pull validado. Refund del ETH sobrante al caller.
     * @param updateData Payload de actualización Pyth.
     * @return price Precio validado.
     */
    function getPullPrice(bytes[] calldata updateData) external payable returns (int256 price) {
        price = _pull(updateData);
    }

    /**
     * @notice Precio Push escalado a 18 decimales (uint256, > 0).
     * @return price18 Precio en 1e18.
     */
    function getPushPriceScaled18() external view returns (uint256 price18) {
        int256 price = pushFeed.getValidatedPrice();
        return uint256(PriceScalerLib.to18Decimals(price, pushFeed.decimals()));
    }

    /**
     * @notice Actualiza Pyth y retorna precio escalado a 18 decimales.
     * @param updateData Payload Pyth.
     * @return price18 Precio en 1e18.
     */
    function getPullPriceScaled18(bytes[] calldata updateData) external payable returns (uint256 price18) {
        int256 price = _pull(updateData);
        return uint256(PriceScalerLib.to18Decimals(price, pullFeed.decimals()));
    }

    /**
     * @dev Paga fee exacto al `PythPriceFeed` y refunde el exceso al `msg.sender` original.
     */
    function _pull(bytes[] calldata updateData) private returns (int256 price) {
        uint256 fee = pullFeed.getUpdateFee(updateData);
        if (msg.value < fee) revert InsufficientFee();

        price = pullFeed.updateAndGetPrice{value: fee}(updateData);

        uint256 refund = msg.value - fee;
        if (refund > 0) {
            (bool ok,) = msg.sender.call{value: refund}("");
            if (!ok) revert EthTransferFailed();
        }
    }
}
