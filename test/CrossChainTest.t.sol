// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {Test, console} from "forge-std/Test.sol";
import {DepositModule, MessagingFee} from "../src/CrossChain/LayerZero/DepositModule.sol";
import {Receiver} from "../src/CrossChain/LayerZero/MoonbeamReceive.sol";
import {EndpointV2Mock} from "@layerzerolabs/devtools/packages/test-devtools-evm-hardhat/contracts/mocks/EndpointV2Mock.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

contract CrossChainTest is Test {
    using OptionsBuilder for bytes;

    DepositModule public deposit;
    Receiver public receiver;

    EndpointV2Mock public endpointA;
    EndpointV2Mock public endpointB;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    uint32 public eIdA = 1;
    uint32 public eIdB = 2;
    uint256 public constant INITIAL_FUNDS = 100 ether;

    function setUp() public {
        endpointA = new EndpointV2Mock(eIdA);
        endpointB = new EndpointV2Mock(eIdB);

        deposit = new DepositModule(address(endpointA), owner);
        receiver = new Receiver(address(endpointB), owner);

        endpointA.setDestLzEndpoint(address(receiver), address(endpointB));
        endpointB.setDestLzEndpoint(address(deposit), address(endpointA));

        vm.startPrank(owner);
        deposit.setPeer(eIdB, bytes32(uint256(uint160(address(receiver)))));
        receiver.setPeer(eIdA, bytes32(uint256(uint160(address(deposit)))));
        vm.stopPrank();

        deal(user, INITIAL_FUNDS);
    }

    function testSend() public {
        bytes32 duel = keccak256("duesl");
        uint256 amount = 100;
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(50000, 0);

        DepositModule.Duel memory newDuel = DepositModule.Duel({
            duel: duel,
            user: user,
            amount: amount
        });

        MessagingFee memory fee = deposit.quote(
            eIdB,
            abi.encode(newDuel),
            options,
            false
        );

        vm.prank(user);
        vm.expectEmit(true, true, false, true, address(receiver));
        emit Receiver.Received(duel, user, amount);
        deposit.betOnDuel{value: fee.nativeFee}(eIdB, newDuel, options);
    }
}
