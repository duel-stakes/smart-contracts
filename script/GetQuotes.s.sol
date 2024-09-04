// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Quote} from "../src/CrossChain/Glacis/quote/Quote.sol";

contract GetQuotes is Script {
    // set GMS addresses
    address public l0Address;
    address public axelarAddress;
    address public wormholeAddress;

    Quote.Layer0Args public L0_ZERO_ARGS =
        Quote.Layer0Args({
            dstEid: 0,
            message: "",
            options: "",
            payInLzToken: false
        });

    Quote.AxelarArgs public AXELAR_ZERO_ARGS =
        Quote.AxelarArgs({
            destinationChain: "",
            destinationAddress: "",
            payload: "",
            executionGasLimit: 0,
            params: ""
        });

    Quote.WormholeArgs public WORMHOLE_ZERO_ARGS =
        Quote.WormholeArgs({targetChain: 0, receiverValue: 0, gasLimit: 0});

    function run() public {
        Quote quote = new Quote(l0Address, axelarAddress, wormholeAddress);

        // Layer0
        // quote.quote(Quote.GMPService.LAYER_ZERO,);
    }
}
