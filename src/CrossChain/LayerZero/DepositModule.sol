// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MessagingFee, Origin, OApp, OAppCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

import {CoreModule} from "./CoreModule.sol";

contract DepositModule is CoreModule, OApp {
    using OptionsBuilder for bytes;

    //----------------------------------------------------------------------------------------------------
    //                                               EVENTS
    //----------------------------------------------------------------------------------------------------

    event Released(
        bytes32 indexed duel,
        uint8 indexed opt,
        uint256 indexed multiplier,
        uint256 chain
    );
    event GuaranteedTaken(
        bytes32 indexed duel,
        uint256 indexed amount,
        address indexed creator,
        uint256 chain
    );

    //----------------------------------------------------------------------------------------------------
    //                                               DUELS
    //----------------------------------------------------------------------------------------------------

    mapping(bytes32 => betDuel) public duels;

    //----------------------------------------------------------------------------------------------------
    //                                        CROSSCHAIN VARIABLES
    //----------------------------------------------------------------------------------------------------

    uint32 dstEid;
    bytes options;
    bytes options2;

    //----------------------------------------------------------------------------------------------------
    //                                               STRUCTS
    //----------------------------------------------------------------------------------------------------
    struct betDuel {
        pickOpts releaseReward;
        bool blockedDuel;
        string duelTitle;
        string duelDescription;
        uint256 eventTimestamp;
        address duelCreator;
        uint256 guaranteed;
        uint256 multiplier;
        mapping(address => bool) userClaimed; //math to do is total pooled on (pooledAmount/winner)*totalprizepool = (pooledAmount*totalprizepool/winner)
        mapping(address => deposit) userDeposits;
    }

    //change this to populate betDuel, choose duel based on the duel title and event timestamp of bytes32 key
    struct Bet {
        string _title;
        uint256 _timestamp;
        pickOpts _opt;
        uint256 _amount;
    }

    //----------------------------------------------------------------------------------------------------
    //                                               ERRORS
    //----------------------------------------------------------------------------------------------------

    error wrongAmountOrAlreadyTaken();
    error eventDoesNotExists();
    error duelAlreadyReleased();
    error duelNotReleased();

    //----------------------------------------------------------------------------------------------------
    //                                               MODIFIERS
    //----------------------------------------------------------------------------------------------------

    modifier notBlocked(string calldata _title, uint256 _eventDate) {
        if (duels[keccak256(abi.encode(_eventDate, _title))].blockedDuel)
            revert duelIsBlocked();
        _;
    }
    modifier notBlockedMemory(string memory _title, uint256 _eventDate) {
        if (duels[keccak256(abi.encode(_eventDate, _title))].blockedDuel)
            revert duelIsBlocked();
        _;
    }
    modifier notBlockedBytes32(bytes32 _id) {
        if (duels[_id].blockedDuel) revert duelIsBlocked();
        _;
    }

    //----------------------------------------------------------------------------------------------------
    //                                               CONSTRUCTOR
    //----------------------------------------------------------------------------------------------------

    constructor(
        address _endpoint,
        address _owner,
        address __paymentToken,
        address __treasuryAccount,
        address __operationManager,
        uint32 _dstEid,
        uint128 _lzGasLimit,
        bool _payInLzToken
    )
        OApp(_endpoint, _owner)
        CoreModule(
            _owner,
            __paymentToken,
            __treasuryAccount,
            __operationManager
        )
    {
        options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(
            _lzGasLimit,
            0
        );
        options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(
            _lzGasLimit,
            2103608000000000
        );
        dstEid = _dstEid;
        payInLzToken = _payInLzToken;
    }

    //----------------------------------------------------------------------------------------------------
    //                                               MANAGEMENT
    //----------------------------------------------------------------------------------------------------
    //@note create withdrawLiquidity for the liquidityRouter
    function changeEId(uint32 _eId) public onlyOwner {
        dstEid = _eId;
        emit changedEId(block.chainid, _eId);
    }

    //----------------------------------------------------------------------------------------------------
    //                                               INTERNAL
    //----------------------------------------------------------------------------------------------------

    function _depositPick(
        uint256 _amount,
        pickOpts _pick,
        address sender,
        betDuel storage _duel
    ) internal {
        if (_pick == pickOpts.opt1) {
            _duel.userDeposits[sender]._amountOp1 += _amount;
        } else if (_pick == pickOpts.opt2) {
            _duel.userDeposits[sender]._amountOp2 += _amount;
        } else if (_pick == pickOpts.opt3) {
            _duel.userDeposits[sender]._amountOp3 += _amount;
        } else {
            revert pickNotAvailable();
        }
    }

    function _populateDuel(
        CoreModule.CreateDuelInput memory _newDuel
    ) internal {
        betDuel storage _aux = duels[
            keccak256(abi.encode(_newDuel.eventTimestamp, _newDuel.duelTitle))
        ];
        _aux.duelTitle = _newDuel.duelTitle;
        _aux.duelDescription = _newDuel.duelDescription;
        _aux.eventTimestamp = _newDuel.eventTimestamp;
        _aux.guaranteed = _newDuel.initialPrizePool;
        _aux.duelCreator = msg.sender;
    }

    function _releaseGuarateed(bytes32 _id, uint256 _amount) internal {
        if (duels[_id].duelCreator == address(0)) revert eventDoesNotExists();
        bool success = _paymentToken.transfer(duels[_id].duelCreator, _amount);
        if (!success) revert transferDidNotSucceed();
        emit feeTaken(duels[_id].duelCreator, _amount, block.chainid);
    }

    function _checkClaim(
        string calldata _title,
        uint256 _eventDate
    ) internal returns (uint256) {
        betDuel storage _aux = duels[keccak256(abi.encode(_eventDate, _title))];
        require(!_aux.userClaimed[msg.sender], "User already claimed");
        if (_aux.releaseReward == CoreModule.pickOpts.opt1) {
            require(
                _aux.userDeposits[msg.sender]._amountOp1 > 0,
                "No bets done on the winner"
            );
            _aux.userClaimed[msg.sender] = true;
            return
                (_aux.userDeposits[msg.sender]._amountOp1 * _aux.multiplier) /
                1 ether;
        } else if (_aux.releaseReward == CoreModule.pickOpts.opt2) {
            require(
                _aux.userDeposits[msg.sender]._amountOp2 > 0,
                "No bets done on the winner"
            );
            _aux.userClaimed[msg.sender] = true;
            return
                (_aux.userDeposits[msg.sender]._amountOp2 * _aux.multiplier) /
                1 ether;
        } else if (_aux.releaseReward == CoreModule.pickOpts.opt3) {
            require(
                _aux.userDeposits[msg.sender]._amountOp3 > 0,
                "No bets done on the winner"
            );
            _aux.userClaimed[msg.sender] = true;
            return
                (_aux.userDeposits[msg.sender]._amountOp3 * _aux.multiplier) /
                1 ether;
        }
        revert duelNotReleased();
    }

    function _5percent(bytes32 id, uint256 totalPrizePool) internal {
        uint256 _pay = (totalPrizePool * 0.03 ether) / 1 ether;
        bool success = _paymentToken.transfer(_treasuryAccount, _pay);
        if (!success) revert transferDidNotSucceed();
        emit feeTaken(_treasuryAccount, _pay, block.chainid);

        _pay = (totalPrizePool * 0.01 ether) / 1 ether;
        success = _paymentToken.transfer(_operationManager, _pay);
        if (!success) revert transferDidNotSucceed();
        emit feeTaken(_operationManager, _pay, block.chainid);

        _pay = (totalPrizePool * 0.01 ether) / 1 ether;
        success = _paymentToken.transfer(duels[id].duelCreator, _pay);
        if (!success) revert transferDidNotSucceed();
        emit feeTaken(duels[id].duelCreator, _pay, block.chainid);
    }

    //----------------------------------------------------------------------------------------------------
    //                                               EXTERNAL
    //----------------------------------------------------------------------------------------------------

    function releaseClaim(
        bytes32 id,
        uint8 opt,
        uint256 multiplier,
        uint256 totalPrizePool
    ) external onlyOwner returns (bool) {
        if (duels[id].releaseReward != pickOpts(0))
            revert duelAlreadyReleased();
        if (duels[id].multiplier != 0) revert duelAlreadyReleased();

        if (totalPrizePool > 0 && duels[id].duelCreator != address(0)) {
            _5percent(id, totalPrizePool);
        }

        duels[id].releaseReward = pickOpts(opt);
        duels[id].multiplier = multiplier;
        emit Released(id, opt, multiplier, block.chainid);
        return true;
    }

    function claimBet(
        string calldata _title,
        uint256 _eventDate
    ) public notBlocked(_title, _eventDate) whenNotPaused returns (bool) {
        uint256 _amount = _checkClaim(_title, _eventDate);

        bool success = _paymentToken.transfer(msg.sender, _amount);
        if (!success) revert transferDidNotSucceed();

        emit claimedBet(_title, _eventDate, msg.sender, _amount, block.chainid);

        return success;
    }

    //----------------------------------------------------------------------------------------------------
    //                                               EXTERNAL PAYABLE
    //----------------------------------------------------------------------------------------------------

    function betOnDuel(Bet memory _duel) external payable {
        _checkAmount(_duel._amount);
        _transferAmount(_duel._amount);

        bytes32 _id = keccak256(abi.encode(_duel._timestamp, _duel._title));
        _depositPick(_duel._amount, _duel._opt, msg.sender, duels[_id]);

        bytes memory _payload = abi.encode(
            BET_ON_DUEL_SELECTOR,
            _id,
            _duel._opt,
            _duel._amount,
            block.chainid + 1,
            msg.sender
        );

        _lzSend(
            dstEid,
            _payload,
            options,
            // Fee in native gas and ZRO token.
            MessagingFee(msg.value, 0),
            // Refund address in case of failed source message.
            payable(msg.sender)
        );
    }

    function betOnDuelFull(Bet memory _duel) external payable {
        _checkAmount(_duel._amount);
        _transferAmount(_duel._amount);

        bytes32 _id = keccak256(abi.encode(_duel._timestamp, _duel._title));
        _depositPick(_duel._amount, _duel._opt, msg.sender, duels[_id]);

        bytes memory _payload = abi.encode(
            BET_ON_DUEL_SELECTOR,
            _id,
            _duel._opt,
            _duel._amount,
            block.chainid + 1,
            msg.sender
        );

        _lzSend(
            dstEid,
            _payload,
            options2,
            // Fee in native gas and ZRO token.
            MessagingFee(msg.value, 0),
            // Refund address in case of failed source message.
            payable(msg.sender)
        );
    }

    function createDuel(
        CoreModule.CreateDuelInput memory _newDuel
    ) public payable onlyCreator {
        _checkEmpty(_newDuel.duelTitle);
        _checkEmpty(_newDuel.duelDescription);
        _checkEmpty(_newDuel.eventTitle);
        _checkTimestamp(_newDuel.eventTimestamp);
        _checkTimestamp(_newDuel.deadlineTimestamp);
        _checkCaller(_newDuel.duelCreator);
        require(
            _newDuel.initialPrizePool >= 100 || _newDuel.initialPrizePool == 0,
            "Due to underflow you cannot set units less than 100"
        );
        _checkAmount(_newDuel.initialPrizePool);
        _transferAmount(_newDuel.initialPrizePool);
        _populateDuel(_newDuel);

        bytes memory _payload = abi.encode(
            CREATE_DUEL_SELECTOR,
            _newDuel,
            block.chainid + 1,
            msg.sender
        );

        _lzSend(
            dstEid,
            _payload,
            options,
            // Fee in native gas and ZRO token.
            MessagingFee(msg.value, 0),
            // Refund address in case of failed source message.
            payable(msg.sender)
        );
    }

    //----------------------------------------------------------------------------------------------------
    //                                               CROSS-CHAIN MESSAGE
    //----------------------------------------------------------------------------------------------------

    function _lzReceive(
        Origin calldata /* _origin*/,
        bytes32 /* _guid */,
        bytes calldata payload,
        address, // Executor address as specified by the OApp.
        bytes calldata // Any extra data or options to trigger on receipt.
    ) internal override {
        if (bytes4(payload[:4]) == RELEASE_DUEL_GUARANTEED) {
            (, bytes32 duel /*uint256 chainId*/, , uint256 amount) = abi.decode(
                payload,
                (bytes4, bytes32, uint256, uint256)
            );
            _releaseGuarateed(duel, amount);
            emit GuaranteedTaken(
                duel,
                amount,
                duels[duel].duelCreator,
                block.chainid
            );
        }
    }

    function quoteBet(
        Bet memory _duel
    ) external view returns (MessagingFee memory) {
        bytes32 _id = keccak256(abi.encode(_duel._timestamp, _duel._title));
        bytes memory _message = abi.encode(
            BET_ON_DUEL_SELECTOR,
            _id,
            _duel._opt,
            _duel._amount,
            block.chainid,
            msg.sender
        );
        return _quote(dstEid, _message, options, payInLzToken);
    }

    function quoteBetFull(
        Bet memory _duel
    ) external view returns (MessagingFee memory) {
        bytes32 _id = keccak256(abi.encode(_duel._timestamp, _duel._title));
        bytes memory _message = abi.encode(
            BET_ON_DUEL_SELECTOR,
            _id,
            _duel._opt,
            _duel._amount,
            block.chainid,
            msg.sender
        );
        return _quote(dstEid, _message, options2, payInLzToken);
    }

    function quoteNewDuel(
        CoreModule.CreateDuelInput memory _duel
    ) external view returns (MessagingFee memory) {
        // bytes32 _id = keccak256(
        //     abi.encode(_duel.eventTimestamp, _duel.duelTitle)
        // );
        bytes memory _message = abi.encode(
            CREATE_DUEL_SELECTOR,
            _duel,
            block.chainid + 1,
            msg.sender
        );
        return _quote(dstEid, _message, options, payInLzToken);
    }
}
