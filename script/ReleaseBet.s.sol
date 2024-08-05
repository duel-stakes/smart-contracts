// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DuelStakesL0, CoreModule, MessagingFee} from "../src/CrossChain/LayerZero/DuelStakesL0.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract ReleseBetL0 is Script {
    HelperConfig public config;
    DuelStakesL0 public duelStakesL0 =
        DuelStakesL0(0xf0db811f8EdfFC9dBe0ef99fBBafAAcf6Df7E3F0);

    IERC20 public payment = IERC20(0xFFFFFFfFea09FB06d082fd1275CD48b191cbCD1d);
    address public owner = 0xa4563Cc4619191bE18C3A01Cc50D37EB456d102a;

    function run() public {
        bytes32 _id = keccak256(abi.encode(1722110303, "Test VS Test"));

        // payment.approve(address(depositModule), 0 ether);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MessagingFee memory fee = duelStakesL0.quoteRelease(_id, 137);
        //@note carefull and take the 5percent along
        duelStakesL0.releaseBet{value: fee.nativeFee}(
            "Test VS Test",
            1722110303,
            CoreModule.pickOpts(uint8(1))
        );

        vm.stopBroadcast();

        // console.log("Duel Stakes L0");
        // console.log("\tproxy:", address(proxy));
        // console.log("\timplementation:", address(duelStakesL0));
    }
}
