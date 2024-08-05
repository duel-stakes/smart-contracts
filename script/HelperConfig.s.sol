// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

//  ██████╗ ███╗   ███╗███╗   ██╗███████╗███████╗
// ██╔═══██╗████╗ ████║████╗  ██║██╔════╝██╔════╝
// ██║   ██║██╔████╔██║██╔██╗ ██║█████╗  ███████╗
// ██║   ██║██║╚██╔╝██║██║╚██╗██║██╔══╝  ╚════██║
// ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║███████╗███████║
//  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝

/// -----------------------------------------------------------------------
/// Imports
/// -----------------------------------------------------------------------

import {Script} from "forge-std/Script.sol";

/// -----------------------------------------------------------------------
/// Contract (script)
/// -----------------------------------------------------------------------

/**
 * @title Script for configuration settings.
 * @author Eduardo W. da Cunha (@EWCunha).
 * @dev Useful for testing and deployment.
 */
contract HelperConfig is Script {
    /// -----------------------------------------------------------------------
    /// Type declarations
    /// -----------------------------------------------------------------------

    struct NetworkConfig {
        // common initialization parameters
        address owner;
        address paymentToken;
        address treasuryAccount;
        address operationManager;
        bool payInLzToken;
        // common constructor parameters
        address endpoint;
        // deployment parameters
        uint256 key;
        bool isAnvil;
    }

    /// -----------------------------------------------------------------------
    /// State variables
    /// -----------------------------------------------------------------------

    NetworkConfig public activeNetworkConfig;

    uint256 public constant ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // REPLACE THESE VALUES
    address public constant OWNER = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    /// -----------------------------------------------------------------------
    /// Constructor logic
    /// -----------------------------------------------------------------------

    /// @notice Checks chain ID and calls proper function to set configurations.
    constructor() {
        if (
            block.chainid == 1 || // Ethereum - mainnet
            block.chainid == 5 || // Goerli - testnet
            block.chainid == 17_000 || // Holesky - testnet
            block.chainid == 11_155_111 || // Sepolia - testnet
            block.chainid == 137 || // Polygon - mainnet
            block.chainid == 80_002 || // Amoy - testnet
            block.chainid == 1287 || // Moonbase - testnet
            block.chainid == 1284 || // Moonbeam - mainnet
            block.chainid == 59_140 || //linea - testnet
            block.chainid == 88882 || // Chilliz
            block.chainid == 42161 // Arbitrum - mainnet
        ) {
            activeNetworkConfig = getPublicConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    /// -----------------------------------------------------------------------
    /// View public/external functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Sets configurations for public networks.
     * @return {NetworkConfig} object.
     */
    // function getPublicConfig() public view returns (NetworkConfig memory) {
    //     //moonbeam
    //     return
    //         NetworkConfig({
    //             owner: 0xa4563Cc4619191bE18C3A01Cc50D37EB456d102a,
    //             paymentToken: 0xFFFFFFfFea09FB06d082fd1275CD48b191cbCD1d,
    //             treasuryAccount: 0x76Ba2605bD6C5496ff041201880dF1A5dC12F4CC,
    //             operationManager: 0x36657503e2bF76A239669Fbe5ca6FF200C8db376,
    //             payInLzToken: false,
    //             endpoint: 0x1a44076050125825900e736c501f859c50fE728c,
    //             key: vm.envUint("PRIVATE_KEY"),
    //             isAnvil: false
    //         });
    // }

    // function getPublicConfig() public view returns (NetworkConfig memory) {
    //     //arbitrum
    //     return
    //         NetworkConfig({
    //             owner: 0xa4563Cc4619191bE18C3A01Cc50D37EB456d102a,
    //             paymentToken: 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9,
    //             treasuryAccount: 0x36657503e2bF76A239669Fbe5ca6FF200C8db376,
    //             operationManager: 0x36657503e2bF76A239669Fbe5ca6FF200C8db376,
    //             payInLzToken: false,
    //             endpoint: 0x1a44076050125825900e736c501f859c50fE728c,
    //             key: vm.envUint("PRIVATE_KEY"),
    //             isAnvil: false
    //         });
    // }

    function getPublicConfig() public view returns (NetworkConfig memory) {
        //polygon
        return
            NetworkConfig({
                owner: 0xa4563Cc4619191bE18C3A01Cc50D37EB456d102a,
                paymentToken: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F,
                treasuryAccount: 0xa4563Cc4619191bE18C3A01Cc50D37EB456d102a,
                operationManager: 0x36657503e2bF76A239669Fbe5ca6FF200C8db376,
                payInLzToken: false,
                endpoint: 0x1a44076050125825900e736c501f859c50fE728c,
                key: vm.envUint("PRIVATE_KEY"),
                isAnvil: false
            });
    }

    /**
     * @notice Sets configurations for Anvil network.
     * @return {NetworkConfig} object.
     */
    function getAnvilConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                owner: address(0),
                paymentToken: address(0),
                treasuryAccount: address(0),
                operationManager: address(0),
                payInLzToken: false,
                endpoint: address(0),
                key: ANVIL_KEY,
                isAnvil: true
            });
    }
}
