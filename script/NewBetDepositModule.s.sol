// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DepositModule, CoreModule, MessagingFee} from "../src/CrossChain/LayerZero/DepositModule.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract NewBetDM is Script {
    HelperConfig public config;
    DepositModule public depositModule =
        DepositModule(0xaBaAbF95182937c379de2Fc5689909e1F4C05BC2);

    IERC20 public payment = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    address public owner = 0xa4563Cc4619191bE18C3A01Cc50D37EB456d102a;

    function run() public {
        DepositModule.Bet memory newBet = DepositModule.Bet({
            _title: "Test VS Test",
            _timestamp: 1722110303,
            _opt: CoreModule.pickOpts(1),
            _amount: 5000000
        });

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MessagingFee memory fee = depositModule.quoteBet(newBet);
        payment.approve(address(depositModule), newBet._amount);
        depositModule.betOnDuel{value: fee.nativeFee}(newBet);

        vm.stopBroadcast();

        // console.log("Duel Stakes L0");
        // console.log("\tproxy:", address(proxy));
        // console.log("\timplementation:", address(duelStakesL0));
    }
}
