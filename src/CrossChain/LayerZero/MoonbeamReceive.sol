// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OApp, Origin, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Receiver is OApp {
    event Received(bytes32 indexed duel, address indexed user, uint256 amount);

    struct Duel {
        bytes32 duel;
        address user;
        uint256 amount;
    }

    constructor(
        address _endpoint,
        address _owner
    ) OApp(_endpoint, _owner) Ownable(_owner) {}

    function _lzReceive(
        Origin calldata /* _origin*/,
        bytes32 /* _guid */,
        bytes calldata payload,
        address, // Executor address as specified by the OApp.
        bytes calldata // Any extra data or options to trigger on receipt.
    ) internal override {
        // Decode the payload to get the message
        // In this case, type is string, but depends on your encoding!
        Duel memory duel = abi.decode(payload, (Duel));
        emit Received(duel.duel, duel.user, duel.amount);
    }
}
