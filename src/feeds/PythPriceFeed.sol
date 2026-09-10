// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {
    EthTransferFailed,
    InsufficientFee,
    InvalidOracleConfig,
    ZeroAddress
} from "../errors/OracleErrors.sol";
import {OracleValidationLib} from "../libraries/OracleValidationLib.sol";

/**
 * @title PythPriceFeed
 * @notice Lectura Pull segura: paga fee, actualiza payload y valida precio (edad + bounds).
 */
contract PythPriceFeed is IPriceFeed {
    /// @notice Contrato Pyth on-chain.
    IPyth public immutable pyth;

    /// @notice Identificador del price feed Pyth.
    bytes32 public immutable priceId;

    /// @notice Edad máxima aceptada del `publishTime` (segundos).
    uint256 public immutable maxAge;

    /// @notice Cota inferior inclusiva (escala del precio Pyth crudo).
    int256 public immutable minAnswer;

    /// @notice Cota superior inclusiva.
    int256 public immutable maxAnswer;

    /// @notice Decimales lógicos del precio (p. ej. 8 si `expo == -8`).
    uint8 private immutable _decimals;

    /**
     * @param pyth_ Dirección del contrato IPyth.
     * @param priceId_ Feed id.
     * @param maxAge_ Staleness máxima.
     * @param minAnswer_ Precio mínimo (> 0).
     * @param maxAnswer_ Precio máximo (>= minAnswer_).
     * @param decimals_ Decimales reportados por `decimals()`.
     */
    constructor(
        address pyth_,
        bytes32 priceId_,
        uint256 maxAge_,
        int256 minAnswer_,
        int256 maxAnswer_,
        uint8 decimals_
    ) {
        if (pyth_ == address(0)) revert ZeroAddress();
        if (priceId_ == bytes32(0)) revert InvalidOracleConfig();
        if (maxAge_ == 0) revert InvalidOracleConfig();
        if (minAnswer_ <= 0 || minAnswer_ > maxAnswer_) revert InvalidOracleConfig();
        if (decimals_ > 18) revert InvalidOracleConfig();

        pyth = IPyth(pyth_);
        priceId = priceId_;
        maxAge = maxAge_;
        minAnswer = minAnswer_;
        maxAnswer = maxAnswer_;
        _decimals = decimals_;
    }

    /// @inheritdoc IPriceFeed
    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Fee requerido por Pyth para el payload dado.
     * @param updateData Payload de actualización.
     * @return feeAmount Fee en wei.
     */
    function getUpdateFee(bytes[] calldata updateData) external view returns (uint256 feeAmount) {
        return pyth.getUpdateFee(updateData);
    }

    /**
     * @notice Actualiza el feed on-chain, valida y retorna el precio. Refund del ETH sobrante.
     * @param updateData Payload Pyth (formato del mock o wire format mainnet).
     * @return price Precio validado.
     */
    function updateAndGetPrice(bytes[] calldata updateData) external payable returns (int256 price) {
        uint256 fee = pyth.getUpdateFee(updateData);
        if (msg.value < fee) revert InsufficientFee();

        // Checks → Interactions (update) → validate → refund (CEI sobre el exceso).
        pyth.updatePriceFeeds{value: fee}(updateData);
        price = _readAndValidate();

        uint256 refund = msg.value - fee;
        if (refund > 0) {
            (bool ok,) = msg.sender.call{value: refund}("");
            if (!ok) revert EthTransferFailed();
        }
    }

    /**
     * @notice Lee el precio ya on-chain (sin update) y aplica validaciones del módulo.
     * @return price Precio validado.
     */
    function getValidatedPrice() public view override returns (int256 price) {
        return _readAndValidate();
    }

    /**
     * @dev `getPriceUnsafe` + `OracleValidationLib` (errores custom del módulo, no solo Pyth).
     */
    function _readAndValidate() private view returns (int256 price) {
        PythStructs.Price memory p = pyth.getPriceUnsafe(priceId);
        price = int256(p.price);
        OracleValidationLib.validatePullPrice(p.publishTime, maxAge, price, minAnswer, maxAnswer);
    }
}
