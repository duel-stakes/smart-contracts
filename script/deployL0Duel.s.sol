// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DuelStakesL0} from "../src/CrossChain/LayerZero/DuelStakesL0.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDepositModule is Script {
    HelperConfig public config;
    DuelStakesL0 public duelStakesL0;
    ERC1967Proxy public proxy;

    // SET THESE VALUES
    uint32 public DST_EID;
    uint128 public LZ_GAS_LIMIT;
    address public DepositModule;
    uint256 public chainDepositModule;

    bytes4 public constant RELEASE_DUEL_GUARANTEED = 0x4134a730;

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
        proxy = new ERC1967Proxy(address(duelStakesL0), init);

        DuelStakesL0(address(proxy)).changeDuelCreator(owner, true);
        DuelStakesL0(address(proxy)).changeEId(chainDepositModule, DST_EID);
        DuelStakesL0(address(proxy)).changeOptions(
            RELEASE_DUEL_GUARANTEED,
            100000,
            0
        );
        DuelStakesL0(address(proxy)).setPeer(
            DST_EID,
            bytes32(uint256(uint160(DepositModule)))
        );

        vm.stopBroadcast();

        console.log("Duel Stakes L0");
        console.log("\tproxy:", address(proxy));
        console.log("\timplementation:", address(duelStakesL0));
    }
}
