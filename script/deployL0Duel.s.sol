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

    //Duel Stakes L0 moonbeam trial 0 cancun
    // proxy: 0x44852b34a2111247F2015e2Ab5A80d02A2B17715
    // implementation: 0x09ccC4FF970827802380e9E47A933A9F0A749590
    //Duel Stakes L0 moonbeam trial 1 cancun
    // proxy: 0x55e038ED52627A676a42063e9b2f0b44BDF43F6d
    // implementation: 0x0E34CA4785Dd129d99BE91C80E006C34d4eCADb3
    // implementation 2: 0xd7AbCC4DeaefE4E54B6864c95F281F3c8A37BDC9
    //Duel Stakes L0 moonbeam trial 2 paris
    //proxy: 0xf0db811f8EdfFC9dBe0ef99fBBafAAcf6Df7E3F0
    // implementation: 0x1B51FdD62C4907C0B77f0758b3aC3797A6ACb209
    // implementation 3: 0x2ed6775c41AEf2D6e0dDA16F17518fb69b3792EE
    // implementation 4: 0x0F82C6b7Ef187ec71C79a8F23ec28620912879a7
    // implementation 5: 0xB38f858b36f18eDf788662e7f7F7897B2200059a
    // implementation 6: 0x3DAEA47d6bf278B114b13690101BB5AfcDa1b107
    // implementation 7: 0x618621DD10aFfAAF6C2149e9Fff332C26B335824
    // implementation 8: 0xDAE048765e1D208B7932cd68393cD32D96F7833E

    // SET THESE VALUES
    uint32 public DST_EID = 30110;
    uint128 public LZ_GAS_LIMIT;
    address public DepositModule = 0xe768f5A5F9dDB3cFc6Fdca242C8437d7306a11A8;
    uint256 public chainDepositModule = 42161;

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
        // duelStakesL0 = DuelStakesL0(0x55e038ED52627A676a42063e9b2f0b44BDF43F6d);
        // proxy = new ERC1967Proxy(address(duelStakesL0), init);

        // DuelStakesL0(address(proxy)).changeDuelCreator(owner, true);
        // DuelStakesL0(address(proxy)).changeEId(chainDepositModule, DST_EID);
        DuelStakesL0(0xf0db811f8EdfFC9dBe0ef99fBBafAAcf6Df7E3F0).changeEId(
            chainDepositModule,
            DST_EID
        );
        // DuelStakesL0(address(proxy)).changeOptions(
        //     RELEASE_DUEL_GUARANTEED,
        //     100000,
        //     0
        // );
        DuelStakesL0(0xf0db811f8EdfFC9dBe0ef99fBBafAAcf6Df7E3F0).setPeer(
            DST_EID,
            bytes32(uint256(uint160(DepositModule)))
        );
        // DuelStakesL0(address(proxy)).setPeer(
        //     DST_EID,
        //     bytes32(uint256(uint160(DepositModule)))
        // );

        vm.stopBroadcast();

        console.log("Duel Stakes L0");
        console.log("\tproxy:", address(proxy));
        console.log("\timplementation:", address(duelStakesL0));
    }
}
