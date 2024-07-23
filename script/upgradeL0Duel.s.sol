// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DuelStakesL0} from "../src/CrossChain/LayerZero/DuelStakesL0.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeDepositModule is Script {
    HelperConfig public config;
    DuelStakesL0 public duelStakesL0;
    address public proxyAddr;

    // SET THESE VALUES
    uint32 public DST_EID;
    uint128 public LZ_GAS_LIMIT;

    function run() public {
        config = new HelperConfig();

        (address owner, , , , , address endpoint, uint256 key, ) = config
            .activeNetworkConfig();

        vm.startBroadcast(key);

        duelStakesL0 = new DuelStakesL0(endpoint, owner);
        UUPSUpgradeable(payable(proxyAddr)).upgradeToAndCall(
            address(duelStakesL0),
            ""
        );

        vm.stopBroadcast();

        console.log("DuelStakesL0 upgraded");
        console.log("\tproxy:", proxyAddr);
        console.log("\timplementation:", address(duelStakesL0));
    }
}
