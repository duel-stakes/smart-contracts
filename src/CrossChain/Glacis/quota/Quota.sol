// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//----------------------------------------------------------------------------------------------------
//                                        IMPORTS
//----------------------------------------------------------------------------------------------------

import {ILayerZeroEndpointV2, MessagingFee, MessagingParams} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {IAxelarGasService} from "@axelar/interfaces/IAxelarGasService.sol";
import {IWormholeRelayer} from "@wormhole/interfaces/IWormholeRelayer.sol";

//----------------------------------------------------------------------------------------------------
//                                        CONTRACT
//----------------------------------------------------------------------------------------------------

/**
 * @title Quota
 * @author @EWCunha and @G-Deps
 * @notice Retrieves cross chain communication quota from several GMP services.
 * @dev Supports Layer 0, Axelar, and Wormhole.
 */
contract Quota {
    //----------------------------------------------------------------------------------------------------
    //                                        STRUCTS
    //----------------------------------------------------------------------------------------------------

    /**
     * @dev Arguments for Layer 0 quota call
     * @param dstEid: EID of the destination chain;
     * @param peer: peer address of the calling contract;
     * @param message: payload to be sent;
     * @param options: option settings for the cross chain messaging;
     * @param payInLzToken: whether or not to pay in LZ tokens.
     */
    struct Layer0Args {
        uint32 dstEid;
        bytes32 peer;
        bytes message;
        bytes options;
        bool payInLzToken;
    }

    /**
     * @dev Arguments for Axelar quota call
     * @param destinationChain: destination chain;
     * @param destinationAddress: calling address in the destination chain;
     * @param payload: payload to be sent;
     * @param executionGasLimit: gas limit for the cross chain messaging;
     * @param params: additional parameters for the cross chain messaging.
     */
    struct AxelarArgs {
        string destinationChain;
        string destinationAddress;
        bytes payload;
        uint256 executionGasLimit;
        bytes params;
    }

    /**
     * @dev Arguments for Wormhole quota call
     * @param targetChain: target chain ID;
     * @param receiverValue: amount to pay the receiver in the destination chain;
     * @param gasLimit: gas limit for the cross chain messaging.
     */
    struct WormholeArgs {
        uint16 targetChain;
        uint256 receiverValue;
        uint256 gasLimit;
    }

    /// @dev supported GMP services.
    enum GMPService {
        LAYER_ZERO,
        AXELAR,
        WORMHOLE
    }

    //----------------------------------------------------------------------------------------------------
    //                                              VARIABLES
    //----------------------------------------------------------------------------------------------------

    ILayerZeroEndpointV2 internal l0Endpoint;
    IAxelarGasService internal axelarEndpoint;
    IWormholeRelayer internal wormholeEndpoint;

    //----------------------------------------------------------------------------------------------------
    //                                           CONSTRUCTOR
    //----------------------------------------------------------------------------------------------------

    /**
     * @notice constructor logic
     * @param _l0Endpoint: relayer endpoint address for Layer 0
     * @param _axelarEndpoint: relayer endpoint address for Axelar
     * @param _wormholeEndpoint: relayer endpoint address for Wormhole
     */
    constructor(
        address _l0Endpoint,
        address _axelarEndpoint,
        address _wormholeEndpoint
    ) {
        l0Endpoint = ILayerZeroEndpointV2(_l0Endpoint);
        axelarEndpoint = IAxelarGasService(_axelarEndpoint);
        wormholeEndpoint = IWormholeRelayer(_wormholeEndpoint);
    }

    /// -----------------------------------------------------------------------
    /// View external quota functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Retrieves quota for cross chain messaging service.
     * @param router: GMP service specifier;
     * @param layer0Args: input arguments for Layer 0 call;
     * @param axelarArgs: input arguments for Axelar call;
     * @param wormholeArgs: input arguments for Wormhole call;
     * @return value1 first returned value.
     * `nativeFee` for Layer 0; `gasEstimate` for Axelar; `nativePriceQuote` for Wormhole;
     * @return value2 second returned value.
     * `lzTokenFee` for Layer 0; 0 for Axelar (no second value); `targetChainRefundPerGasUnused` for Wormhole;
     */
    function quote(
        GMPService router,
        Layer0Args calldata layer0Args,
        AxelarArgs calldata axelarArgs,
        WormholeArgs calldata wormholeArgs
    ) external view returns (uint256 value1, uint256 value2) {
        if (router == GMPService.LAYER_ZERO) {
            MessagingFee memory fee = l0Endpoint.quote(
                MessagingParams(
                    layer0Args.dstEid,
                    layer0Args.peer,
                    layer0Args.message,
                    layer0Args.options,
                    layer0Args.payInLzToken
                ),
                address(this) // @follow-up address(this) or msg.sender ?
            );

            value1 = fee.nativeFee;
            value2 = fee.lzTokenFee;
        } else if (router == GMPService.AXELAR) {
            value1 = axelarEndpoint.estimateGasFee(
                axelarArgs.destinationChain,
                axelarArgs.destinationAddress,
                axelarArgs.payload,
                axelarArgs.executionGasLimit,
                axelarArgs.params
            );
        } else if (router == GMPService.WORMHOLE) {
            (value1, value2) = wormholeEndpoint.quoteEVMDeliveryPrice(
                wormholeArgs.targetChain,
                wormholeArgs.receiverValue,
                wormholeArgs.gasLimit
            );
        }
    }
}
