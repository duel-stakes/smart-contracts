// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

// import {Test, console} from "forge-std/Test.sol";
// import {DepositModule} from "../src/CrossChain/Glacis/DepositModule.sol";
// import {DuelStakesL0} from "../src/CrossChain/Glacis/DuelStakesL0.sol";
// import {CoreModule} from "../src/CrossChain/Glacis/CoreModule.sol";
// import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroV2Mock, GlacisLayerZeroV2Adapter, WormholeRelayerMock, GlacisWormholeAdapter} from "../../lib/v1-core/test/LocalTestSetup.sol";
// import {mockERC20} from "./utils/mockERC20.sol";

// contract CrossChainGlacis__LayerZero is LocalTestSetup {
//     using AddressBytes32 for address;

//     LayerZeroV2Mock internal lzGatewayMock;
//     GlacisLayerZeroV2Adapter internal lzAdapter;
//     GlacisRouter internal glacisRouter;
//     GlacisClientSample internal clientSample;

//     function setUp() public {
//         glacisRouter = deployGlacisRouter();
//         (lzGatewayMock) = deployLayerZeroFixture();
//         lzAdapter = deployLayerZeroAdapters(glacisRouter, lzGatewayMock);
//         (clientSample, ) = deployGlacisClientSample(glacisRouter);
//     }

//     function test__Abstraction_LayerZero(uint256 val) external {
//         clientSample.setRemoteValue__execute{value: 0.1 ether}(
//             block.chainid,
//             address(clientSample).toBytes32(),
//             LAYERZERO_GMP_ID,
//             abi.encode(val)
//         );

//         assertEq(clientSample.value(), val);
//     }

//     function test__RefundAddress_LayerZero() external {
//         address randomRefundAddress = 0xc0ffee254729296a45a3885639AC7E10F9d54979;
//         assertEq(randomRefundAddress.balance, 0);

//         address[] memory gmps = new address[](1);
//         gmps[0] = LAYERZERO_GMP_ID;
//         clientSample.setRemoteValue{value: 1 ether}(
//             block.chainid,
//             address(clientSample).toBytes32(),
//             abi.encode(0),
//             gmps,
//             createFees(1 ether, 1),
//             randomRefundAddress,
//             false,
//             1 ether
//         );

//         assertEq(randomRefundAddress.balance, 1 ether);
//     }

//     receive() external payable {}
// }
