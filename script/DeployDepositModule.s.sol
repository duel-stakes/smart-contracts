// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DepositModule} from "../src/CrossChain/LayerZero/DepositModule.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDepositModule is Script {
    HelperConfig public config;
    DepositModule public depositModule;
    ERC1967Proxy public proxy;

    // SET THESE VALUES
    uint32 public DST_EID = 30126;
    uint128 public LZ_GAS_LIMIT;

    address public DuelStakesL0 = 0x55e038ED52627A676a42063e9b2f0b44BDF43F6d;

    //   DepositModule Trial 0 moonbeam
    //     proxy: 0x56BE283089Db404784DB156A49746eB4199A8dc0
    //     implementation: 0xab0A62157ec43B3Cb504490a3Aa05d724840ff48
    // DepositModule Trial 1 polygon
    //     proxy: 0xaBaAbF95182937c379de2Fc5689909e1F4C05BC2
    //     implementation: 0x4FC0ac125c5c4bb45E4a69e2551E5471FB71907d

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
        proxy = new ERC1967Proxy(address(depositModule), init);

        DepositModule(address(proxy)).changeDuelCreator(owner, true);
        DepositModule(address(proxy)).setPeer(
            DST_EID,
            bytes32(uint256(uint160(DuelStakesL0)))
        );

        vm.stopBroadcast();

        console.log("DepositModule");
        console.log("\tproxy:", address(proxy));
        console.log("\timplementation:", address(depositModule));
    }
}
