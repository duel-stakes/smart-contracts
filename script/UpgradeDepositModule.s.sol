// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DepositModule} from "../src/CrossChain/LayerZero/DepositModule.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeDepositModule is Script {
    HelperConfig public config;
    DepositModule public depositModule;
    address public proxyAddr = 0xaBaAbF95182937c379de2Fc5689909e1F4C05BC2;

    // SET THESE VALUES
    uint32 public DST_EID = 30126;
    uint128 public LZ_GAS_LIMIT = 500000;

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
            DepositModule.initialize.selector,
            owner,
            paymentToken,
            treasuryAccount,
            operationManager,
            DST_EID,
            LZ_GAS_LIMIT,
            payInLzToken
        );

        vm.startBroadcast(key);

        depositModule = new DepositModule(endpoint, owner);
        UUPSUpgradeable(payable(proxyAddr)).upgradeToAndCall(
            address(depositModule),
            init
        );

        vm.stopBroadcast();

        console.log("DepositModule upgraded");
        console.log("\tproxy:", proxyAddr);
        console.log("\timplementation:", address(depositModule));
    }
}
