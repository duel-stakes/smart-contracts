// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/DuelStakes.sol";
import "../utils/MockERC20.sol";

contract DeployScript is Script {

    duelStakes public _duelStakes;
    mockERC20 public _mockERC20;

    function setUp() public {}

    function run() public {

        // DEPLOYED
        // Mock Payment token sepolia :  0xC738EFf4f092e6D34FbFa8D6BAe129F9806387C6 (usa esse como token de pagamento)
        // Duel Stakes sepolia :  0x5d042F06531c3BcDB81002A992905e99166Cf471 (esse de duel stakes)
        //sep:0x4BDf96C56d85041377ddb0037c42b11F9fF9076a
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        _mockERC20 = new mockERC20();
        _duelStakes = new duelStakes(address(_mockERC20),0x4BDf96C56d85041377ddb0037c42b11F9fF9076a,0xED2d3c8B942c0f0A8b5bA8cC64289322CDa0739B);

        console.log("Mock Payment token sepolia : ", address(_mockERC20));
        console.log("Duel Stakes sepolia : ", address(_duelStakes));

        duelStakes.betDuelInput memory _aux = duelStakes.betDuelInput({
            duelTitle : "Test VS Test",
            duelDescription : "This is a description of test vs test",
            eventTitle : "Test function fighting test function",
            eventTimestamp : block.timestamp + 120 days,
            deadlineTimestamp : block.timestamp + 119 days,
            duelCreator : 0xED2d3c8B942c0f0A8b5bA8cC64289322CDa0739B,
            initialPrizePool : 1 ether
        });

        _mockERC20.approve(address(_duelStakes), 1 ether);
        _duelStakes.createDuel(_aux);

        vm.stopBroadcast();
    }
}
