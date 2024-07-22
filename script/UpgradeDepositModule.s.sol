// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DepositModule} from "../src/CrossChain/LayerZero/DepositModule.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeDepositModule is Script {
    HelperConfig public config;
    DepositModule public depositModule;
    address public proxyAddr;

    // SET THESE VALUES
    uint32 public DST_EID;
    uint128 public LZ_GAS_LIMIT;

    function run() public {
        config = new HelperConfig();

        (address owner, , , , , address endpoint, uint256 key, ) = config
            .activeNetworkConfig();

        vm.startBroadcast(key);

        depositModule = new DepositModule(endpoint, owner);
        UUPSUpgradeable(payable(proxyAddr)).upgradeToAndCall(
            address(depositModule),
            ""
        );

        vm.stopBroadcast();

        console.log("DepositModule upgraded");
        console.log("\tproxy:", proxyAddr);
        console.log("\timplementation:", address(depositModule));
    }
}
