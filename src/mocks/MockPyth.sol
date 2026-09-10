// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MockPyth as PythSdkMockPyth} from "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

/**
 * @title MockPyth
 * @notice Wrapper del MockPyth del SDK con helpers para unit tests (fee, update, getPrice).
 * @dev Hereda `IPyth` completo vía AbstractPyth del SDK. `updateData` para `updatePriceFeeds`
 *      es `abi.encode(PriceFeed)` (formato del mock SDK, distinto al wire format de mainnet).
 */
contract MockPyth is PythSdkMockPyth {
    /**
     * @param validTimePeriod Periodo válido usado por `getPrice()` legacy.
     * @param singleUpdateFeeInWei Fee por cada elemento de `updateData`.
     */
    constructor(uint256 validTimePeriod, uint256 singleUpdateFeeInWei)
        PythSdkMockPyth(validTimePeriod, singleUpdateFeeInWei)
    {}

    /**
     * @notice Codifica un `PriceFeed` listo para `updatePriceFeeds` del mock.
     * @param id Price feed id.
     * @param price Precio int64.
     * @param conf Confianza.
     * @param expo Exponente (p. ej. -8).
     * @param publishTime Timestamp de publicación.
     * @return updateData Bytes para un slot de `bytes[]`.
     */
    function createUpdateData(bytes32 id, int64 price, uint64 conf, int32 expo, uint64 publishTime)
        public
        pure
        returns (bytes memory updateData)
    {
        PythStructs.PriceFeed memory feed;
        feed.id = id;
        feed.price = PythStructs.Price({price: price, conf: conf, expo: expo, publishTime: publishTime});
        feed.emaPrice = feed.price;
        return abi.encode(feed);
    }

    /**
     * @notice Empuja un precio pagando el fee requerido (`msg.value`).
     * @param id Price feed id.
     * @param price Precio.
     * @param conf Confianza.
     * @param expo Exponente.
     * @param publishTime Timestamp.
     */
    function setPrice(bytes32 id, int64 price, uint64 conf, int32 expo, uint64 publishTime) external payable {
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = createUpdateData(id, price, conf, expo, publishTime);
        this.updatePriceFeeds{value: msg.value}(updateData);
    }
}
