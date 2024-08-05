// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DuelStakesL0} from "../src/CrossChain/LayerZero/DuelStakesL0.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeL0Module is Script {
    HelperConfig public config;
    DuelStakesL0 public duelStakesL0;
    address public proxyAddr = 0xf0db811f8EdfFC9dBe0ef99fBBafAAcf6Df7E3F0;

    // SET THESE VALUES
    uint32 public DST_EID;
    uint128 public LZ_GAS_LIMIT;

    function run() public {
        config = new HelperConfig();

        (
            address owner,
            address paymentToken,
            address treasuryAccount,
            address operationManager,
            bool payInLzToken,
            address endpoint,
            uint256 key,

        ) = config.activeNetworkConfig();

        bytes memory init = abi.encodeWithSelector(
            DuelStakesL0.initialize.selector,
            paymentToken,
            treasuryAccount,
            operationManager,
            owner,
            payInLzToken
        );

        vm.startBroadcast(key);

        duelStakesL0 = new DuelStakesL0(endpoint, owner);
        UUPSUpgradeable(payable(proxyAddr)).upgradeToAndCall(
            address(duelStakesL0),
            init
        );

        vm.stopBroadcast();

        console.log("DuelStakesL0 upgraded");
        console.log("\tproxy:", proxyAddr);
        console.log("\timplementation:", address(duelStakesL0));
    }
}
