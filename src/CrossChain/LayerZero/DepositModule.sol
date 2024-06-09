// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MessagingFee, OAppSender, OAppCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DepositModule is OAppSender {
    struct Duel {
        bytes32 duel;
        address user;
        uint256 amount;
    }

    constructor(
        address _endpoint,
        address _owner
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {}

    function betOnDuel(
        uint32 _dstEid,
        Duel memory _duel,
        bytes calldata _options
    ) external payable {
        // Encodes the message before invoking _lzSend.
        // Replace with whatever data you want to send!
        bytes memory _payload = abi.encode(_duel);
        _lzSend(
            _dstEid,
            _payload,
            _options,
            // Fee in native gas and ZRO token.
            MessagingFee(msg.value, 0),
            // Refund address in case of failed source message.
            payable(msg.sender)
        );
    }

    function quote(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        bool _payInLzToken
    ) external view returns (MessagingFee memory) {
        return _quote(_dstEid, _message, _options, _payInLzToken);
    }
}
