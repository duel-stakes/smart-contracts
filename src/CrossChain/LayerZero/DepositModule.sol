// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MessagingFee,Origin, OApp, OAppCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DepositModule is OApp {

    //----------------------------------------------------------------------------------------------------
    //                                               EVENTS
    //----------------------------------------------------------------------------------------------------

    event Released(bytes32 indexed duel, uint8 indexed opt, uint256 indexed multiplier);

    //----------------------------------------------------------------------------------------------------
    //                                               DUELS
    //----------------------------------------------------------------------------------------------------
    
    mapping (bytes32 => betDuel) public duels;
    mapping (address => bool) public duelCreators;

    //----------------------------------------------------------------------------------------------------
    //                                               ERC20 IDENTIFIER
    //----------------------------------------------------------------------------------------------------

    IERC20 public _paymentToken;
    address public _treasuryAccount;
    address public _operationManager;

    //----------------------------------------------------------------------------------------------------
    //                                               STRUCTS
    //----------------------------------------------------------------------------------------------------

     struct CreateDuelInput{
        string duelTitle;
        string duelDescription;
        string eventTitle;
        uint256 eventTimestamp;
        uint256 deadlineTimestamp;
        address duelCreator;
        uint256 initialPrizePool;
    }

    struct betDuel{
        pickOpts releaseReward;
        bool blockedDuel;
        string duelTitle;
        string duelDescription;
        uint256 eventTimestamp;
        address duelCreator;
        uint256 multiplier;
        mapping (address => bool) userClaimed; //math to do is total pooled on (pooledAmount/winner)*totalprizepool = (pooledAmount*totalprizepool/winner)
        mapping (address => deposit) userDeposits;
    }

    struct deposit {
        uint256 _amountOp1;
        uint256 _amountOp2;
        uint256 _amountOp3;
    }

    enum pickOpts {
        none,
        opt1,
        opt2,
        opt3
    }

    //change this to populate betDuel, choose duel based on the duel title and event timestamp of bytes32 key
    struct Duel {
        bytes32 duel;
        address user;
        uint256 amount;
    }

    constructor(
        address _endpoint,
        address _owner,
        address __paymentToken,
        address __treasuryAccount,
        address __operationManager
    ) OApp(_endpoint, _owner) Ownable(_owner) {
        _paymentToken = IERC20(__paymentToken);
        _treasuryAccount = __treasuryAccount;
        _operationManager = __operationManager;
    }

    function betOnDuel(
        uint32 _dstEid,
        Duel memory _duel,
        bytes calldata _options
    ) external payable {
        // Encodes the message before invoking _lzSend.
        // Replace with whatever data you want to send!
        bytes memory _payload = abi.encode(bytes4(""),_duel);
        _lzSend(
            _dstEid,
            _payload,
            _options,
            // Fee in native gas and ZRO token.
            MessagingFee(msg.value, 0),
            // Refund address in case of failed source message.
            payable(msg.sender)
        );
    }

    //@note implement a bytes4 to get what function you're interacting with
    function _lzReceive(
        Origin calldata /* _origin*/,
        bytes32 /* _guid */,
        bytes calldata payload,
        address, // Executor address as specified by the OApp.
        bytes calldata // Any extra data or options to trigger on receipt.
    ) internal override {
        // Decode the payload to get the message
        // In this case, type is string, but depends on your encoding!
        (bytes32 duel, uint8 opt, uint256 multiplier) = abi.decode(payload, (bytes32,uint8,uint256));
        duels[duel].releaseReward = pickOpts(opt);
        duels[duel].multiplier = multiplier;
        emit Released(duel,opt,multiplier);
    }

    function quote(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        bool _payInLzToken
    ) external view returns (MessagingFee memory) {
        return _quote(_dstEid, _message, _options, _payInLzToken);
    }
}
