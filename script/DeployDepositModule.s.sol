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
    uint128 public LZ_GAS_LIMIT = 500000;

    address public DuelStakesL0 = 0xf0db811f8EdfFC9dBe0ef99fBBafAAcf6Df7E3F0;

    //   DepositModule Trial 0 moonbeam
    //     proxy: 0x56BE283089Db404784DB156A49746eB4199A8dc0
    //     implementation: 0xab0A62157ec43B3Cb504490a3Aa05d724840ff48
    // DepositModule Trial 1 polygon
    //     proxy: 0xaBaAbF95182937c379de2Fc5689909e1F4C05BC2
    //     implementation: 0x4FC0ac125c5c4bb45E4a69e2551E5471FB71907d
    //     implementation 2: 0xC52BF625BBC06A7A1e1612Ec0782c87B9506161A
    //     implementation 3: 0xBd7A5b95720333948377BB1F624EcBEA50a7E79a
    //     implementation 4: 0x09ccC4FF970827802380e9E47A933A9F0A749590
    //     implementation 5: 0x72Aa3Bcf0F299df90834851d4b9CC6e609c926F3
    //     implementation 6: 0xB33B3676d75eFc8bfB6fAE43789AD720c41B55ad
    //     implementation 7: 0xEE94DF2c83192D5928F24a00E0787B8fdfC42604
    // DepositModule Trial 0 arbitrum
    //     proxy: 0xe768f5A5F9dDB3cFc6Fdca242C8437d7306a11A8
    //     implementation: 0xD9E5011E6533e4d711557b97a44D6a7a6Ba126d5
    // DepositModule Trial 2 polygon
    //     proxy: 0xb89E0186aE46b433b3BB08A570dC437A277453E7
    //     implementation: 0xD9E5011E6533e4d711557b97a44D6a7a6Ba126d5

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

        depositModule = new DepositModule{salt: bytes32("depositModule")}(
            endpoint,
            owner
        );
        proxy = new ERC1967Proxy{salt: bytes32("depositModule")}(
            address(depositModule),
            init
        );

        DepositModule(address(proxy)).changeDuelCreator(owner, true);
        DepositModule(address(proxy)).setPeer(
            DST_EID,
            bytes32(uint256(uint160(DuelStakesL0)))
        );
        // DepositModule(0xaBaAbF95182937c379de2Fc5689909e1F4C05BC2).setPeer(
        //     DST_EID,
        //     bytes32(uint256(uint160(DuelStakesL0)))
        // );

        vm.stopBroadcast();

        console.log("DepositModule");
        console.log("\tproxy:", address(proxy));
        console.log("\timplementation:", address(depositModule));
    }
}
