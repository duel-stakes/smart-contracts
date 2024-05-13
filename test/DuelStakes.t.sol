// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {mockERC20} from "./utils/mockERC20.sol";
import {duelStakes} from "../src/DuelStakes.sol";

contract DuelStakesTest is Test {
    uint256 mainnetFork;
    uint256 arbitrumFork;
    string MAINNET_RPC_URL = vm.envString("ALCHEMY_MAINNET_URL");
    string ARBITRUM_RPC_URL = vm.envString("ALCHEMY_ARBITRUM_URL");

    mockERC20 public _dummyToken;
    duelStakes public _duelStakes;

    address public owner = makeAddr("owner");
    address public treasury = makeAddr("treasury");
    address public operation = makeAddr("operation");
    address public creator = makeAddr("creator");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);

        vm.startPrank(owner,owner);
        _dummyToken = new mockERC20();
        _duelStakes = new duelStakes(address(_dummyToken),treasury,operation);
        
        vm.stopPrank();
    }

    function test_ChangeDuelCreator() public {
       assertEq(_duelStakes.duelCreators(owner),true);
       assertEq(_duelStakes.duelCreators(creator),false);

       vm.expectRevert();
       vm.prank(user,user);
       _duelStakes.changeDuelCreator(creator, true);

       vm.prank(owner,owner);
       _duelStakes.changeDuelCreator(creator, true);
       assertEq(_duelStakes.duelCreators(creator),true);
    }

    function test_PauseAndUnpause() public {
       assertEq(_duelStakes.paused(),false);

       vm.expectRevert();
       vm.prank(user,user);
       _duelStakes.pause();

       vm.prank(owner,owner);
       _duelStakes.pause();
       assertEq(_duelStakes.paused(),true);
    }

    function test_CreateDuel() public returns(string memory,uint256){
         duelStakes.betDuelInput memory _aux = duelStakes.betDuelInput({
            duelTitle : "Test VS Test",
            duelDescription : "This is a description of test vs test",
            eventTitle : "Test function fighting test function",
            eventTimestamp : block.timestamp + 2 days,
            deadlineTimestamp : block.timestamp + 1 days,
            duelCreator : owner,
            initialPrizePool : 1 ether
        });
        vm.prank(owner,owner);
        _dummyToken.approve(address(_duelStakes), 1 ether);
        
        vm.prank(owner,owner);
        _duelStakes.createDuel(_aux);

        (string memory _duelTitle,string memory _duelDescription,string memory _eventTitle) = _duelStakes.getDuelTitleAndDescrition(_aux.duelTitle, _aux.eventTimestamp);
        assertEq(_eventTitle, _aux.eventTitle);
        assertEq(_duelTitle, _aux.duelTitle);
        assertEq(_duelDescription, _aux.duelDescription);

        return(_aux.duelTitle, _aux.eventTimestamp);
    }

    function test_userFlowBiggerThanInitial() public {
        (string memory _title, uint256 _timestamp) = test_CreateDuel();

        (,,,,uint256 unclaimed) = _duelStakes.getPrizes(_title, _timestamp);
        assertGt(unclaimed,0);
        
        vm.startPrank(user,user);
        _dummyToken.mint(1 ether);
        _dummyToken.approve(address(_duelStakes), 1 ether);
        _duelStakes.betOnDuel(_title, _timestamp, duelStakes.pickOpts.opt1, 1 ether);
        vm.stopPrank();
        vm.startPrank(user2,user2);
        _dummyToken.mint(2 ether);
        _dummyToken.approve(address(_duelStakes), 2 ether);
        _duelStakes.betOnDuel(_title, _timestamp, duelStakes.pickOpts.opt2, 2 ether);
        vm.stopPrank();

        (,,,,unclaimed) = _duelStakes.getPrizes(_title, _timestamp);
        assertEq(unclaimed,0);


        (uint256 _amount,,) = _duelStakes.getUserDeposits(_title, _timestamp, user);
        (,uint256 _amount2,) = _duelStakes.getUserDeposits(_title, _timestamp, user2);

        assertEq(_amount, 1 ether);
        assertEq(_amount2, 2 ether);

        vm.warp(block.timestamp + 3 days);
        vm.prank(owner,owner);
        _duelStakes.releaseBet(_title, _timestamp, duelStakes.pickOpts.opt1);

        assertEq(_dummyToken.balanceOf(_duelStakes._operationManager())*3,_dummyToken.balanceOf(_duelStakes._treasuryAccount()));


        (uint256 total,,,,) = _duelStakes.getPrizes(_title, _timestamp);

        vm.prank(user,user);
        _duelStakes.claimBet(_title, _timestamp);

        assertEq(_dummyToken.balanceOf(user),total);
    }

    function test_userFlowSmallerThanInitial() public {
        (string memory _title, uint256 _timestamp) = test_CreateDuel();

        (,,,,uint256 unclaimed) = _duelStakes.getPrizes(_title, _timestamp);
        assertGt(unclaimed,0);
        
        vm.startPrank(user,user);
        _dummyToken.mint(1000000000);
        _dummyToken.approve(address(_duelStakes), 1000000000);
        _duelStakes.betOnDuel(_title, _timestamp, duelStakes.pickOpts.opt1, 1000000000);
        vm.stopPrank();
        vm.startPrank(user2,user2);
        _dummyToken.mint(2000000000);
        _dummyToken.approve(address(_duelStakes), 2000000000);
        _duelStakes.betOnDuel(_title, _timestamp, duelStakes.pickOpts.opt2, 2000000000);
        vm.stopPrank();

        (,,,,unclaimed) = _duelStakes.getPrizes(_title, _timestamp);
        assertGt(unclaimed,0);


        (uint256 _amount,,) = _duelStakes.getUserDeposits(_title, _timestamp, user);
        (,uint256 _amount2,) = _duelStakes.getUserDeposits(_title, _timestamp, user2);

        assertEq(_amount, 1000000000);
        assertEq(_amount2, 2000000000);

        vm.warp(block.timestamp + 3 days);
        vm.prank(owner,owner);
        _duelStakes.releaseBet(_title, _timestamp, duelStakes.pickOpts.opt1);

        assertEq(_dummyToken.balanceOf(_duelStakes._operationManager())*3,_dummyToken.balanceOf(_duelStakes._treasuryAccount()));


        (uint256 total,,,,) = _duelStakes.getPrizes(_title, _timestamp);

        vm.prank(user,user);
        _duelStakes.claimBet(_title, _timestamp);

        console.logBytes32(keccak256(abi.encode(_timestamp,_title)));

        assertEq(_dummyToken.balanceOf(user),total);
    }

    //@note Missing fuzzing tests

}
