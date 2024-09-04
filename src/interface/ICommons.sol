// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

abstract contract ICommons {
    bytes4 public constant BET_ON_DUEL_SELECTOR =
        bytes4(
            keccak256(
                "_betOnDuel(string,uint256,uint8,uint256,uint256,address)"
            )
        );
    bytes4 public constant CREATE_DUEL_SELECTOR =
        bytes4(
            keccak256(
                "_createDuel((string,string,string,uint256,uint256,address,uint256),uint256)"
            )
        );
    bytes4 public constant RELEASE_DUEL_GUARANTEED =
        bytes4(keccak256("_releaseGuarateed(bytes32,uint256)"));

    enum pickOpts {
        none,
        opt1,
        opt2,
        opt3
    }

    //change this to populate betDuel, choose duel based on the duel title and event timestamp of bytes32 key
    struct Bet {
        string _title;
        uint256 _timestamp;
        pickOpts _opt;
        uint256 _amount;
    }

    struct CreateDuelInput {
        string duelTitle;
        string duelDescription;
        string eventTitle;
        uint256 eventTimestamp;
        uint256 deadlineTimestamp;
        address duelCreator;
        uint256 initialPrizePool;
        bool drawAvaliable;
    }
}
