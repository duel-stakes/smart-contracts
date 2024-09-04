// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DepositModule} from "../DepositModule.sol";
import {Quote} from "./Quote.sol";

contract DepositModuleExample is DepositModule, Quote {
    // set up theses variables:
    bytes options;
    uint32 dstEid;
    bool payInLzToken;

    string destinationChain;
    string destinationAddress;
    uint256 executionGasLimit;
    bytes params;

    uint16 targetChain;
    uint256 receiverValue;
    uint256 gasLimit;

    constructor(
        address _glacisRouter,
        uint256 _quorum,
        address _owner
    ) DepositModule(_glacisRouter, _quorum, _owner) {}

    function quoteBet(
        GMPService router,
        Bet memory _duel
    ) external view returns (uint256 value1, uint256 value2) {
        bytes32 _id = keccak256(abi.encode(_duel._timestamp, _duel._title));
        bytes memory _message = abi.encode(
            BET_ON_DUEL_SELECTOR,
            _id,
            _duel._opt,
            _duel._amount,
            block.chainid,
            msg.sender
        );

        return _getQuote(router, _message);
    }

    function quoteBetFull(
        GMPService router,
        Bet memory _duel
    ) external view returns (MessagingFee memory) {
        bytes32 _id = keccak256(abi.encode(_duel._timestamp, _duel._title));
        bytes memory _message = abi.encode(
            BET_ON_DUEL_SELECTOR,
            _id,
            _duel._opt,
            _duel._amount,
            block.chainid,
            msg.sender
        );
        return _getQuote(router, _message);
    }

    function quoteNewDuel(
        GMPService router,
        CoreModule.CreateDuelInput memory _duel
    ) external view returns (MessagingFee memory) {
        // bytes32 _id = keccak256(
        //     abi.encode(_duel.eventTimestamp, _duel.duelTitle)
        // );
        bytes memory _message = abi.encode(
            CREATE_DUEL_SELECTOR,
            _duel,
            block.chainid + 1,
            msg.sender
        );
        return _getQuote(router, _message);
    }

    function _getQuote(
        GMPService router,
        bytes memory payload
    ) internal pure returns (uint256 value1, uint256 value2) {
        Layer0Args memory l0Args;
        AxelarArgs memory axelarArgs;
        WormholeArgs memory wormholeArgs;

        if (router == GMPService.LAYER_ZERO) {
            l0Args = Layer0Args({
                dstEid: dstEid,
                message: _message,
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
                payload: _message,
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
}
