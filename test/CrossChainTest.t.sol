// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {Test, console} from "forge-std/Test.sol";
import {DepositModule, MessagingFee} from "../src/CrossChain/LayerZero/DepositModule.sol";
import {duelStakesL0} from "../src/CrossChain/LayerZero/DuelStakesL0.sol";
import {EndpointV2Mock} from "@layerzerolabs/devtools/packages/test-devtools-evm-hardhat/contracts/mocks/EndpointV2Mock.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {mockERC20} from "./utils/mockERC20.sol";

contract CrossChainTest is Test {
    using OptionsBuilder for bytes;

    DepositModule public deposit;
    duelStakesL0 public receiver;

    mockERC20 public dummyToken;

    EndpointV2Mock public endpointA;
    EndpointV2Mock public endpointB;

    address public _paymentToken = makeAddr("paymentToken");
    address public _treasuryAccount = makeAddr("treasuryAccount");
    address public _operationManager = makeAddr("operationManager");
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    uint32 public eIdA = 1;
    uint32 public eIdB = 2;
    uint256 public constant INITIAL_FUNDS = 100 ether;

    function setUp() public {
        vm.startPrank(owner);
        dummyToken = new mockERC20();

        endpointA = new EndpointV2Mock(eIdA);
        endpointB = new EndpointV2Mock(eIdB);

        deposit = new DepositModule(address(endpointA), owner,address(dummyToken),_treasuryAccount,_operationManager,eIdB,257000,false);
        receiver = new duelStakesL0(address(dummyToken),_treasuryAccount,_operationManager,address(endpointB), owner,eIdA,100000,false);
        receiver.changeDuelCreator(owner,true);

        endpointA.setDestLzEndpoint(address(receiver), address(endpointB));
        endpointB.setDestLzEndpoint(address(deposit), address(endpointA));

        deposit.setPeer(eIdB, bytes32(uint256(uint160(address(receiver)))));
        receiver.setPeer(eIdA, bytes32(uint256(uint160(address(deposit)))));
        vm.stopPrank();

        deal(user, INITIAL_FUNDS);
        deal(owner, INITIAL_FUNDS);
        vm.prank(user);
        dummyToken.mint(INITIAL_FUNDS);
        vm.prank(owner);
        dummyToken.mint(INITIAL_FUNDS);
    }

    function test_duelOnDuelStakesL0() public {
        vm.startPrank(owner,owner);
        duelStakesL0.betDuelInput memory params = duelStakesL0.betDuelInput({
            duelTitle : "Test VS Test",
            duelDescription : "This is a description of test vs test",
            eventTitle : "Test function fighting test function",
            eventTimestamp : block.timestamp + 120 days,
            deadlineTimestamp : block.timestamp + 119 days,
            duelCreator : owner,
            initialPrizePool : 1 ether
        });
        dummyToken.approve(address(receiver),2 ether);
        receiver.createDuel(params);
        vm.stopPrank();

        vm.startPrank(user);
        uint256 amount = 100;
        //@note Check if the duel does not exists if the initial transaction fails before execution
        DepositModule.Bet memory newBet = DepositModule.Bet({
            _title : "Test VS Test",
            _timestamp : block.timestamp + 120 days,
            _opt : DepositModule.pickOpts(1),
            _amount : amount
        });

        MessagingFee memory fee = deposit.quoteBet(
            newBet
        );

        dummyToken.approve(address(deposit),amount);

        vm.expectEmit(true, true, false, true, address(receiver));
        emit duelStakesL0.duelBet(user, newBet._amount, duelStakesL0.pickOpts(uint8(newBet._opt)),newBet._title, newBet._timestamp,block.chainid);

        deposit.betOnDuel{value: fee.nativeFee}(newBet);
        (uint256 amount1,uint256 amount2,uint256 amount3) = receiver.getUserDeposits(newBet._title, newBet._timestamp, block.chainid, user);
        console.log("Amount 1", amount1);
        console.log("Amount 2", amount2);
        console.log("Amount 3", amount3);
        vm.stopPrank();
    }
    function test_duelOnDepositModule() public {
        vm.startPrank(owner,owner);
        DepositModule.betDuelInput memory params = DepositModule.betDuelInput({
            duelTitle : "Test VS Test",
            duelDescription : "This is a description of test vs test",
            eventTitle : "Test function fighting test function",
            eventTimestamp : block.timestamp + 120 days,
            deadlineTimestamp : block.timestamp + 119 days,
            duelCreator : owner,
            initialPrizePool : 1 ether
        });
        dummyToken.approve(address(deposit),2 ether);
        MessagingFee memory fee = deposit.quoteNewDuel(
            params
        );
        deposit.createDuel{value: fee.nativeFee}(params);
        vm.stopPrank();

        vm.startPrank(user);
        uint256 amount = 100;
        //@note Check if the duel does not exists if the initial transaction fails before execution
        DepositModule.Bet memory newBet = DepositModule.Bet({
            _title : "Test VS Test",
            _timestamp : block.timestamp + 120 days,
            _opt : DepositModule.pickOpts(1),
            _amount : amount
        });

        fee = deposit.quoteBet(
            newBet
        );

        dummyToken.approve(address(deposit),amount);

        vm.expectEmit(true, true, false, true, address(receiver));
        emit duelStakesL0.duelBet(user, newBet._amount, duelStakesL0.pickOpts(uint8(newBet._opt)),newBet._title, newBet._timestamp,block.chainid);

        deposit.betOnDuel{value: fee.nativeFee}(newBet);
        (uint256 amount1,uint256 amount2,uint256 amount3) = receiver.getUserDeposits(newBet._title, newBet._timestamp, block.chainid, user);
        console.log("Amount 1", amount1);
        console.log("Amount 2", amount2);
        console.log("Amount 3", amount3);
        (uint256 total,uint256 amount1_,uint256 amount2_,uint256 amount3_, uint256 unclaimed) = receiver.getPrizes(newBet._title,newBet._timestamp);
        console.log("Total Prizes:", total);
        console.log("Total op1:", amount1_);
        console.log("Total op2:", amount2_);
        console.log("Total op3:", amount3_);
        console.log("Total unclaimed:", unclaimed);
        vm.stopPrank();
    }
}
