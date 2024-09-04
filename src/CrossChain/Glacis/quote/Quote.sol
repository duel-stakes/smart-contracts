// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//----------------------------------------------------------------------------------------------------
//                                        IMPORTS
//----------------------------------------------------------------------------------------------------

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILayerZeroEndpointV2, MessagingFee, MessagingParams} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {IAxelarGasService} from "@axelar/interfaces/IAxelarGasService.sol";
import {IWormholeRelayer} from "@wormhole/interfaces/IWormholeRelayer.sol";
import {ICommons} from "../../../interface/ICommons.sol";

//----------------------------------------------------------------------------------------------------
//                                        CONTRACT
//----------------------------------------------------------------------------------------------------

/**
 * @title Quote
 * @author @EWCunha and @G-Deps
 * @notice Retrieves cross chain communication quota from several GMP services.
 * @dev Supports Layer 0, Axelar, and Wormhole.
 */
contract Quote is ICommons, Ownable {
    //----------------------------------------------------------------------------------------------------
    //                                        STRUCTS
    //----------------------------------------------------------------------------------------------------

    /**
     * @dev Arguments for Layer 0 quota call
     * @param dstEid: EID of the destination chain;
     * @param message: payload to be sent;
     * @param options: option settings for the cross chain messaging;
     * @param payInLzToken: whether or not to pay in LZ tokens.
     */
    struct Layer0Args {
        uint32 dstEid;
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

    Layer0Args internal L0_ZERO_ARGS =
        Layer0Args({dstEid: 0, message: "", options: "", payInLzToken: false});

    AxelarArgs internal AXELAR_ZERO_ARGS =
        AxelarArgs({
            destinationChain: "",
            destinationAddress: "",
            payload: "",
            executionGasLimit: 0,
            params: ""
        });

    WormholeArgs internal WORMHOLE_ZERO_ARGS =
        WormholeArgs({targetChain: 0, receiverValue: 0, gasLimit: 0});

    // Layer0 settings
    bytes internal options;
    uint32 internal dstEid;
    bool internal payInLzToken;

    // Axelar settings
    string internal destinationChain;
    string internal destinationAddress;
    uint256 internal executionGasLimit;
    bytes internal params;

    // Wormhole settings
    uint16 internal targetChain;
    uint256 internal receiverValue;
    uint256 internal gasLimit;

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
    ) Ownable(msg.sender) {
        l0Endpoint = ILayerZeroEndpointV2(_l0Endpoint);
        axelarEndpoint = IAxelarGasService(_axelarEndpoint);
        wormholeEndpoint = IWormholeRelayer(_wormholeEndpoint);
    }

    /// -----------------------------------------------------------------------
    /// State-change external functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Sets Layer0 settings.
     * @param _options: options for sending cross-chain messages.
     * @param _dstEid: EID of the destination chain.
     * @param _payInLzToken: specifies whether to pay in LZ tokens or not.
     */
    function setL0Configs(
        bytes calldata _options,
        uint32 _dstEid,
        bool _payInLzToken
    ) external onlyOwner {
        options = _options;
        dstEid = _dstEid;
        payInLzToken = _payInLzToken;
    }

    /**
     * @notice Sets Axelar settings.
     * @param _destinationChain: destination chain of the cross-chain message.
     * @param _destinationAddress: destination address of the cross-chain message.
     * @param _executionGasLimit: gas limit for the cross-chain message esecution.
     * @param _params: parameters for the cross-chain messaging.
     */
    function setAxelarConfigs(
        string calldata _destinationChain,
        string calldata _destinationAddress,
        uint256 _executionGasLimit,
        bytes calldata _params
    ) external onlyOwner {
        destinationChain = _destinationChain;
        destinationAddress = _destinationAddress;
        executionGasLimit = _executionGasLimit;
        params = _params;
    }

    /**
     * @notice Sets Wormhole settings.
     * @param _targetChain: target chain of the cross-chain message.
     * @param _receiverValue: value to be send with the cross-chain message.
     * @param _gasLimit: gas limit for the cross-chain message esecution.
     */
    function setWormholeConfigs(
        uint16 _targetChain,
        uint256 _receiverValue,
        uint256 _gasLimit
    ) external onlyOwner {
        targetChain = _targetChain;
        receiverValue = _receiverValue;
        gasLimit = _gasLimit;
    }

    /// -----------------------------------------------------------------------
    /// View public/external quota functions
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
        Layer0Args memory layer0Args,
        AxelarArgs memory axelarArgs,
        WormholeArgs memory wormholeArgs
    ) public view returns (uint256 value1, uint256 value2) {
        if (router == GMPService.LAYER_ZERO) {
            MessagingFee memory fee = l0Endpoint.quote(
                MessagingParams({
                    dstEid: layer0Args.dstEid,
                    receiver: bytes32(uint256(uint160(msg.sender))), // @follow-up address(this) or msg.sender ?
                    message: layer0Args.message,
                    options: layer0Args.options,
                    payInLzToken: layer0Args.payInLzToken
                }),
                msg.sender // @follow-up address(this) or msg.sender ?
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

    /**
     * @dev Builds and gets quote.
     * @param router: router choice (Layer0, Axelar, Wormhole).
     * @param payload: payload to be sent in cross-chain messaging.
     * @return value1 - uint256 - first returned value.
     * @return value2 - uint256 - second returned value.
     */
    function getQuote(
        GMPService router,
        bytes memory payload
    ) public view returns (uint256 value1, uint256 value2) {
        Layer0Args memory l0Args;
        AxelarArgs memory axelarArgs;
        WormholeArgs memory wormholeArgs;

        if (router == GMPService.LAYER_ZERO) {
            l0Args = Layer0Args({
                dstEid: dstEid,
                message: payload,
                options: options,
                payInLzToken: payInLzToken
            });
            axelarArgs = AXELAR_ZERO_ARGS;
            wormholeArgs = WORMHOLE_ZERO_ARGS;
        } else if (router == GMPService.AXELAR) {
            l0Args = L0_ZERO_ARGS;
            axelarArgs = AxelarArgs({
                destinationChain: destinationChain,
                destinationAddress: destinationAddress,
                payload: payload,
                executionGasLimit: executionGasLimit,
                params: params
            });
            wormholeArgs = WORMHOLE_ZERO_ARGS;
        } else if (router == GMPService.WORMHOLE) {
            l0Args = L0_ZERO_ARGS;
            axelarArgs = AXELAR_ZERO_ARGS;
            wormholeArgs = WormholeArgs({
                targetChain: targetChain,
                receiverValue: receiverValue,
                gasLimit: gasLimit
            });
        }

        return quote(router, l0Args, axelarArgs, wormholeArgs);
    }

    /**
     * @notice Quotes a bet duel.
     * @param router: router choice (Layer0, Axelar, Wormhole).
     * @param _duel: bet values.
     * @param creator: creator of the bet.
     * @return value1 - uint256 - first returned value.
     * @return value2 - uint256 - second returned value.
     */
    function quoteBet(
        GMPService router,
        Bet memory _duel,
        address creator
    ) external view returns (uint256 value1, uint256 value2) {
        bytes32 _id = keccak256(abi.encode(_duel._timestamp, _duel._title));
        bytes memory _message = abi.encode(
            BET_ON_DUEL_SELECTOR,
            _id,
            _duel._opt,
            _duel._amount,
            block.chainid,
            creator
        );

        return getQuote(router, _message);
    }

    /**
     * @notice Quotes a full bet duel.
     * @param router: router choice (Layer0, Axelar, Wormhole).
     * @param _duel: bet values.
     * @param creator: creator of the bet.
     * @return value1 - uint256 - first returned value.
     * @return value2 - uint256 - second returned value.
     */
    function quoteBetFull(
        GMPService router,
        Bet memory _duel,
        address creator
    ) external view returns (uint256 value1, uint256 value2) {
        bytes32 _id = keccak256(abi.encode(_duel._timestamp, _duel._title));
        bytes memory _message = abi.encode(
            BET_ON_DUEL_SELECTOR,
            _id,
            _duel._opt,
            _duel._amount,
            block.chainid,
            creator
        );
        return getQuote(router, _message);
    }

    /**
     * @notice Quotes new duel creation.
     * @param router: router choice (Layer0, Axelar, Wormhole).
     * @param _duel: create duel input values.
     * @param creator: creator of the bet.
     * @return value1 - uint256 - first returned value.
     * @return value2 - uint256 - second returned value.
     */
    function quoteNewDuel(
        GMPService router,
        CreateDuelInput memory _duel,
        address creator
    ) external view returns (uint256 value1, uint256 value2) {
        // bytes32 _id = keccak256(
        //     abi.encode(_duel.eventTimestamp, _duel.duelTitle)
        // );
        bytes memory _message = abi.encode(
            CREATE_DUEL_SELECTOR,
            _duel,
            block.chainid,
            creator
        );
        return getQuote(router, _message);
    }

    /**
     * @notice Quotes release bet.
     * @param router: router choice (Layer0, Axelar, Wormhole).
     * @param _id: ID of the duel.
     * @param _chain: chainId of the duel.
     * @param _amount: amount of the release.
     * @return value1 - uint256 - first returned value.
     * @return value2 - uint256 - second returned value.
     */
    function quoteRelease(
        GMPService router,
        bytes32 _id,
        uint256 _chain,
        uint256 _amount
    ) external view returns (uint256 value1, uint256 value2) {
        bytes memory _message = abi.encode(
            RELEASE_DUEL_GUARANTEED,
            _id,
            _chain,
            _amount
        );
        return getQuote(router, _message);
    }
}
