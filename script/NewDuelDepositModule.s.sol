// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DepositModule, CoreModule, MessagingFee} from "../src/CrossChain/LayerZero/DepositModule.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract NewDuelDM is Script {
    HelperConfig public config;
    DepositModule public depositModule =
        // DepositModule(0xb89E0186aE46b433b3BB08A570dC437A277453E7);
        DepositModule(0xe768f5A5F9dDB3cFc6Fdca242C8437d7306a11A8);

    // IERC20 public payment = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IERC20 public payment = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    address public owner = 0xa4563Cc4619191bE18C3A01Cc50D37EB456d102a;

    function run() public {
        CoreModule.CreateDuelInput memory params = CoreModule.CreateDuelInput({
            duelTitle: "Test VS Test",
            duelDescription: "This is a description of test vs test",
            eventTitle: "Test function fighting test function",
            eventTimestamp: block.timestamp + 1 hours,
            deadlineTimestamp: block.timestamp + 45 minutes,
            duelCreator: owner,
            initialPrizePool: 0 ether
        });

        // payment.approve(address(depositModule), 0 ether);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MessagingFee memory fee = depositModule.quoteNewDuel(params);
        depositModule.createDuel{value: fee.nativeFee}(params);

        vm.stopBroadcast();

        // console.log("Duel Stakes L0");
        // console.log("\tproxy:", address(proxy));
        // console.log("\timplementation:", address(duelStakesL0));
    }
}
