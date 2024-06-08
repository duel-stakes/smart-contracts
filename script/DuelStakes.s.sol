// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/DuelStakes.sol";
import "../utils/mockERC20.sol";

contract DeployScript is Script {

    duelStakes public _duelStakes;
    mockERC20 public _mockERC20;

    function setUp() public {}

    function run() public {

        // DEPLOYED SEPOLIA V1
        // Mock Payment token sepolia :  0xC738EFf4f092e6D34FbFa8D6BAe129F9806387C6 (usa esse como token de pagamento)
        // Duel Stakes sepolia :  0x5d042F06531c3BcDB81002A992905e99166Cf471 (esse de duel stakes)
        //MULTISIG : sep:0x4BDf96C56d85041377ddb0037c42b11F9fF9076a
        //OPERATUION MANAGER : 0x58e5e912De806ECe8b8e051ce8b9362b5AD4B4C3
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        //DEPLOYED SEPOLIA V2
        // Duel Stakes sepolia :  0xE51cec34751b4BDC136F6280Bb513120594B2547 (esse de duel stakes) SEM INDEXED ON EVENT

        //DEPOLYED SEPOLIA V3
        // Duel Stakes sepolia :  0x8DEd422a09008ca39297fc1E495677916eBAcC91 (esse de duel stakes) /event emergencyBlock(string _title, uint256 indexed _eventDate)/    event duelBet(address indexed _user, uint256 indexed _amount, pickOpts indexed _pick, string _title, uint256 _eventDate);

        //OPTIMISM: 
        //MULTISIG: 0x9E13eAccDb1d7D3d002cED2a7150f5dc64B7C91E
        //OPERATION MANAGER: 0x36657503e2bF76A239669Fbe5ca6FF200C8db376
        // USDT: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58 6 decimals
        //DUELSTAKES: 0x57E4056C9aDc66ecFe1E843fD50811D0da25D8B9

        //MOONBEAM
        //MULTISIG : mbeam:0x76Ba2605bD6C5496ff041201880dF1A5dC12F4CC
        //OPERATION MANAGER : 0x36657503e2bF76A239669Fbe5ca6FF200C8db376
        //USDT: 0xeFAeeE334F0Fd1712f9a8cc375f427D9Cdd40d73
        //DUELSTAKES: 0xaBaAbF95182937c379de2Fc5689909e1F4C05BC2
        
        //MOONBASE
        //MULTISIG : 0xa4563Cc4619191bE18C3A01Cc50D37EB456d102a
        //OPERATION MANAGER : 0xa4563Cc4619191bE18C3A01Cc50D37EB456d102a
        //MOCK PAYMENT: 0x4FC0ac125c5c4bb45E4a69e2551E5471FB71907d
        //DUELSTAKES: 0xaBaAbF95182937c379de2Fc5689909e1F4C05BC2

        // address _paymentSepolia = 0xC738EFf4f092e6D34FbFa8D6BAe129F9806387C6;
        // address _tresurySepolia = 0x4BDf96C56d85041377ddb0037c42b11F9fF9076a;
        // address _operationSepolia = 0x58e5e912De806ECe8b8e051ce8b9362b5AD4B4C3;
        // _mockERC20 = mockERC20(_paymentSepolia);
        
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // _mockERC20 = new mockERC20();
        // _duelStakes = new duelStakes(_paymentSepolia,_tresurySepolia,_operationSepolia);
        // _duelStakes = new duelStakes(address(_mockERC20),0xa4563Cc4619191bE18C3A01Cc50D37EB456d102a,0xa4563Cc4619191bE18C3A01Cc50D37EB456d102a);
        _duelStakes = new duelStakes(0xeFAeeE334F0Fd1712f9a8cc375f427D9Cdd40d73,0x76Ba2605bD6C5496ff041201880dF1A5dC12F4CC,0x36657503e2bF76A239669Fbe5ca6FF200C8db376);

        // console.log("Mock Payment token moonbase : ", address(_mockERC20));
        console.log("Duel Stakes moonbase : ", address(_duelStakes));

        // duelStakes.betDuelInput memory _aux = duelStakes.betDuelInput({
        //     duelTitle : "Test VS Test",
        //     duelDescription : "This is a description of test vs test",
        //     eventTitle : "Test function fighting test function",
        //     eventTimestamp : block.timestamp + 120 days,
        //     deadlineTimestamp : block.timestamp + 119 days,
        //     duelCreator : 0xa4563Cc4619191bE18C3A01Cc50D37EB456d102a,
        //     initialPrizePool : 1 ether
        // });

        // _mockERC20.mint(2 ether);
        // _mockERC20.approve(address(_duelStakes), 1 ether);
        // _duelStakes.createDuel(_aux);

        vm.stopBroadcast();
    }
}
