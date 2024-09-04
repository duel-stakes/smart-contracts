// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Quote} from "../src/CrossChain/Glacis/quote/Quote.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

contract QuoteTest is Test {
    using OptionsBuilder for bytes;

    Quote public quote;

    address public l0Endpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    bytes public options =
        OptionsBuilder.newOptions().addExecutorLzReceiveOption(1000000, 0);
    uint32 public dstEid = 40161;
    bool public payInLzToken = false;

    function setUp() public {
        quote = new Quote(l0Endpoint, address(0), address(0));

        quote.setL0Configs(options, dstEid, payInLzToken);
    }

    function setTestQuote() public {
        bytes memory message = abi.encode("hello world");

        (uint256 val1, uint256 val2) = quote.getQuote(
            Quote.GMPService.LAYER_ZERO,
            message
        );

        assertTrue(val1 > 0);
        assertTrue(val2 > 0);
    }
}
