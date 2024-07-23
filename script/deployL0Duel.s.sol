// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DuelStakesL0} from "../src/CrossChain/LayerZero/DuelStakesL0.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployL0 is Script {
    HelperConfig public config;
    DuelStakesL0 public duelStakesL0;
    ERC1967Proxy public proxy;

    //Duel Stakes L0 moonbeam trial 0
    // proxy: 0x44852b34a2111247F2015e2Ab5A80d02A2B17715
    // implementation: 0x09ccC4FF970827802380e9E47A933A9F0A749590
    //Duel Stakes L0 moonbeam trial 1
    // proxy: 0x55e038ED52627A676a42063e9b2f0b44BDF43F6d
    // implementation: 0x0E34CA4785Dd129d99BE91C80E006C34d4eCADb3

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

        // duelStakesL0 = new DuelStakesL0(endpoint, owner);
        duelStakesL0 = DuelStakesL0(0x55e038ED52627A676a42063e9b2f0b44BDF43F6d);
        // proxy = new ERC1967Proxy(address(duelStakesL0), init);

        // duelStakesL0.changeDuelCreator(owner, true);
        duelStakesL0.changeEId(chainDepositModule, DST_EID);
        // duelStakesL0.changeOptions(RELEASE_DUEL_GUARANTEED, 100000, 0);
        duelStakesL0.setPeer(DST_EID, bytes32(uint256(uint160(DepositModule))));

        vm.stopBroadcast();

        console.log("Duel Stakes L0");
        console.log("\tproxy:", address(proxy));
        console.log("\timplementation:", address(duelStakesL0));
    }
}
