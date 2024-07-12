// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {OApp, Origin, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

import {coreModule} from "./coreModule.sol";

///@author Waiandt.eth

contract duelStakesL0 is coreModule, OApp {
    using OptionsBuilder for bytes;
    //----------------------------------------------------------------------------------------------------
    //                                               STORAGE
    //----------------------------------------------------------------------------------------------------
    //----------------------------------------------------------------------------------------------------
    //                                               DUELS
    //----------------------------------------------------------------------------------------------------

    mapping(bytes32 => betDuel) public duels;

    //----------------------------------------------------------------------------------------------------
    //                                        CROSSCHAIN VARIABLES
    //----------------------------------------------------------------------------------------------------
    mapping(uint256 chainId => uint32 eId) public eIds;
    mapping(bytes4 selector => bytes option) public options;

    //----------------------------------------------------------------------------------------------------
    //                                               STRUCTS
    //----------------------------------------------------------------------------------------------------

    struct betDuel {
        pickOpts releaseReward;
        bool blockedDuel;
        string duelTitle;
        string duelDescription;
        string eventTitle;
        uint128 eventTimestamp;
        uint128 deadlineTimestamp;
        uint256 chainId;
        mapping(uint256 chainId => address) duelCreator;
        uint256 totalPrizePool;
        uint256 opt1PrizePool;
        uint256 opt2PrizePool;
        uint256 opt3PrizePool;
        uint256 unclaimedPrizePool;
        mapping(address => bool) userClaimed; //math to do is total pooled on (pooledAmount/winner)*totalprizepool = (pooledAmount*totalprizepool/winner)
        mapping(address => mapping(uint256 chainId => deposit)) userDeposits;
    }

    //----------------------------------------------------------------------------------------------------
    //                                               ERRORS
    //----------------------------------------------------------------------------------------------------
    error nonExistingDuel();
    error claimNotAvailable();

    //----------------------------------------------------------------------------------------------------
    //                                               EVENTS
    //----------------------------------------------------------------------------------------------------

    event emergencyBlock(string _title, uint256 indexed _eventDate);
    event duelCreated(
        string _title,
        uint256 indexed _eventDate,
        uint256 indexed _openAmount,
        uint256 indexed _chainId
    );
    event duelBet(
        address indexed _user,
        uint256 indexed _amount,
        pickOpts indexed _pick,
        string _title,
        uint256 _eventDate,
        uint256 _chain
    );
    event betClosed(
        string _title,
        uint256 indexed _eventDate,
        pickOpts indexed _winner,
        uint256 indexed _chain
    );

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
    //                                           CONSTRUCTOR/INITIALIZER
    //----------------------------------------------------------------------------------------------------

    constructor(
        address __paymentToken,
        address __treasuryAccount,
        address __operationManager,
        address _endpoint,
        address _owner,
        bool _payInLzToken
    )
        OApp(_endpoint, _owner)
        coreModule(
            _owner,
            __paymentToken,
            __treasuryAccount,
            __operationManager
        )
    {
        duelCreators[msg.sender] = true;
        payInLzToken = _payInLzToken;
    }

    //----------------------------------------------------------------------------------------------------
    //                                           DUELS EMERGENCY PROTOCOL
    //----------------------------------------------------------------------------------------------------

    function emergencyWithdraw(
        string calldata _title,
        uint256 _eventDate
    ) public onlyOwner {
        betDuel storage _aux = _checkDuelExistence(_title, _eventDate);

        bool success = _paymentToken.transfer(
            _treasuryAccount,
            _aux.unclaimedPrizePool
        );
        if (!success) revert transferDidNotSucceed();

        _aux.releaseReward = pickOpts.none;
        _aux.blockedDuel = true;
        _aux.unclaimedPrizePool = 0;

        emit emergencyBlock(_title, _eventDate);
    }

    //----------------------------------------------------------------------------------------------------
    //                                               DUELS CREATION
    //----------------------------------------------------------------------------------------------------

    function createDuel(
        coreModule.CreateDuelInput calldata _newDuel
    ) public onlyCreator whenNotPaused {
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

        _populateDuel(_newDuel, block.chainid);
        emit duelCreated(
            _newDuel.duelTitle,
            _newDuel.eventTimestamp,
            _newDuel.initialPrizePool,
            block.chainid
        );
    }

    //----------------------------------------------------------------------------------------------------
    //                                             DUELS INCREASE BETS
    //----------------------------------------------------------------------------------------------------

    function betOnDuel(
        string calldata _title,
        uint256 _eventDate,
        pickOpts _option,
        uint256 _amount
    ) public payable notBlocked(_title, _eventDate) whenNotPaused {
        betDuel storage _aux = _checkDuelExistence(_title, _eventDate);
        require(
            block.timestamp <= _aux.deadlineTimestamp,
            "Bet not possible due to time limit"
        );
        _checkAmount(_amount);
        _transferAmount(_amount);
        _depositPick(_amount, _option, msg.sender, _aux, block.chainid);

        if (
            _aux.unclaimedPrizePool <= _aux.totalPrizePool &&
            _aux.unclaimedPrizePool != 0 &&
            _aux.duelCreator[block.chainid] != address(0)
        ) {
            bool success = _paymentToken.transfer(
                _aux.duelCreator[block.chainid],
                _aux.unclaimedPrizePool
            );
            if (!success) revert transferDidNotSucceed();
            _aux.unclaimedPrizePool = 0;
        } else if (
            _aux.unclaimedPrizePool <= _aux.totalPrizePool &&
            _aux.unclaimedPrizePool != 0
        ) {
            _releaseGuaranteed(
                _title,
                _eventDate,
                _aux.unclaimedPrizePool,
                _aux.chainId
            );
        }

        emit duelBet(
            msg.sender,
            _amount,
            _option,
            _title,
            _eventDate,
            block.chainid
        );
    }

    //----------------------------------------------------------------------------------------------------
    //                                             DUELS CLAIM AMOUNTS
    //----------------------------------------------------------------------------------------------------

    function releaseBet(
        string calldata _title,
        uint256 _eventDate,
        pickOpts _winner
    ) public payable onlyOwner {
        betDuel storage _aux = _checkDuelExistence(_title, _eventDate);
        require(
            _aux.eventTimestamp <= block.timestamp,
            "event did not happen yet"
        );
        if (
            _aux.totalPrizePool < _aux.unclaimedPrizePool &&
            _aux.totalPrizePool > 0 &&
            _aux.chainId == block.chainid
        ) {
            bool success = _paymentToken.transfer(
                _aux.duelCreator[block.chainid],
                _aux.totalPrizePool
            );
            if (!success) revert transferDidNotSucceed();
            _aux.totalPrizePool = _aux.unclaimedPrizePool;
            _5percent(_aux);
        } else if (
            _aux.totalPrizePool < _aux.unclaimedPrizePool &&
            _aux.totalPrizePool > 0
        ) {
            _releaseGuaranteed(
                _title,
                _eventDate,
                _aux.unclaimedPrizePool - _aux.totalPrizePool,
                _aux.chainId
            );
            _aux.totalPrizePool = _aux.unclaimedPrizePool;
            //@note implement 5percent somehow
        }
        _aux.releaseReward = _winner;
        _aux.unclaimedPrizePool = _aux.totalPrizePool;
        emit betClosed(_title, _eventDate, _winner, block.chainid);
    }

    function claimBet(
        string calldata _title,
        uint256 _eventDate
    ) public notBlocked(_title, _eventDate) whenNotPaused {
        betDuel storage _aux = _checkDuelExistence(_title, _eventDate);
        require(!_aux.userClaimed[msg.sender], "User already claimed");
        uint256 _payment = _updateClaim(_aux, msg.sender);

        emit claimedBet(
            _title,
            _eventDate,
            msg.sender,
            _payment,
            block.chainid
        );
    }

    //----------------------------------------------------------------------------------------------------
    //                                         MANAGEMENT SETTER FUNCTIONS
    //----------------------------------------------------------------------------------------------------

    function changeEId(uint256 _chain, uint32 _eId) public onlyOwner {
        eIds[_chain] = _eId;
        emit changedEId(_chain, _eId);
    }

    function changeOptions(
        bytes4 _selector,
        uint128 _lzGasLimit,
        uint128 _value
    ) public onlyOwner {
        options[_selector] = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(_lzGasLimit, _value);
    }

    //----------------------------------------------------------------------------------------------------
    //                                             GETTER FUNCTIONS
    //----------------------------------------------------------------------------------------------------
    function getReleaseReward(
        string memory _title,
        uint256 _timestamp
    ) public view returns (pickOpts) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return duels[_id].releaseReward;
    }

    function getBlockedDuel(
        string memory _title,
        uint256 _timestamp
    ) public view returns (bool) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return duels[_id].blockedDuel;
    }

    function getDuelTitleAndDescrition(
        string memory _title,
        uint256 _timestamp
    ) public view returns (string memory, string memory, string memory) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return (
            duels[_id].duelTitle,
            duels[_id].duelDescription,
            duels[_id].eventTitle
        );
    }

    function getTimestamps(
        string memory _title,
        uint256 _timestamp
    ) public view returns (uint256, uint256) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return (duels[_id].eventTimestamp, duels[_id].deadlineTimestamp);
    }

    function getPrizes(
        string memory _title,
        uint256 _timestamp
    ) public view returns (uint256, uint256, uint256, uint256, uint256) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return (
            duels[_id].totalPrizePool,
            duels[_id].opt1PrizePool,
            duels[_id].opt2PrizePool,
            duels[_id].opt3PrizePool,
            duels[_id].unclaimedPrizePool
        );
    }

    function getCreator(
        string memory _title,
        uint256 _timestamp
    ) public view returns (address) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return (duels[_id].duelCreator[block.chainid]);
    }

    function getDuelChainId(
        string memory _title,
        uint256 _timestamp
    ) public view returns (uint256) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return (duels[_id].chainId);
    }

    function getUserClaimed(
        string memory _title,
        uint256 _timestamp,
        address _user
    ) public view returns (bool) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return (duels[_id].userClaimed[_user]);
    }

    function getUserDeposits(
        string memory _title,
        uint256 _timestamp,
        uint256 chainId,
        address _user
    ) public view returns (uint256, uint256, uint256) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return (
            duels[_id].userDeposits[_user][chainId]._amountOp1,
            duels[_id].userDeposits[_user][chainId]._amountOp2,
            duels[_id].userDeposits[_user][chainId]._amountOp3
        );
    }

    //----------------------------------------------------------------------------------------------------
    //                                             INTERNAL AUXILIAR
    //----------------------------------------------------------------------------------------------------

    function _checkDuelExistence(
        string memory _title,
        uint256 _timestamp
    ) internal view returns (betDuel storage _aux) {
        _aux = duels[keccak256(abi.encode(_timestamp, _title))];
        if (
            keccak256(abi.encodePacked(_aux.duelTitle)) !=
            keccak256(abi.encodePacked(_title))
        ) revert duelDoesNotExist();
    }

    function _checkDuelExistence(
        bytes32 _id
    ) internal view returns (betDuel storage _aux) {
        _aux = duels[_id];
        if (
            keccak256(abi.encodePacked(_aux.duelTitle)) ==
            keccak256(abi.encodePacked(""))
        ) revert duelDoesNotExist();
    }

    function _populateDuel(
        coreModule.CreateDuelInput memory _newDuel,
        uint256 _chainId
    ) internal {
        betDuel storage _aux = duels[
            keccak256(abi.encode(_newDuel.eventTimestamp, _newDuel.duelTitle))
        ];
        _aux.duelTitle = _newDuel.duelTitle;
        _aux.eventTitle = _newDuel.eventTitle;
        _aux.duelDescription = _newDuel.duelDescription;
        _aux.duelCreator[_chainId] = _newDuel.duelCreator;
        _aux.deadlineTimestamp = uint128(_newDuel.deadlineTimestamp);
        _aux.eventTimestamp = uint128(_newDuel.eventTimestamp);
        _aux.unclaimedPrizePool = _newDuel.initialPrizePool;
        _aux.chainId = _chainId;
    }

    function _transferUserAmount(uint256 _amount) internal {
        bool success = _paymentToken.transfer(msg.sender, _amount);
        if (!success) revert transferDidNotSucceed();
    }

    function _depositPick(
        uint256 _amount,
        pickOpts _pick,
        address sender,
        betDuel storage _duel,
        uint256 chainId
    ) internal {
        if (_pick == pickOpts.opt1) {
            _duel.totalPrizePool += _amount;
            _duel.opt1PrizePool += _amount;
            _duel.userDeposits[sender][chainId]._amountOp1 += _amount;
        } else if (_pick == pickOpts.opt2) {
            _duel.totalPrizePool += _amount;
            _duel.opt2PrizePool += _amount;
            _duel.userDeposits[sender][chainId]._amountOp2 += _amount;
        } else if (_pick == pickOpts.opt3) {
            _duel.totalPrizePool += _amount;
            _duel.opt3PrizePool += _amount;
            _duel.userDeposits[sender][chainId]._amountOp3 += _amount;
        } else if (_pick == pickOpts.none) {
            //@note THIS OPTIONS DOES NOT INTAKE POINTS
            _duel.totalPrizePool += _amount;
        } else {
            revert pickNotAvailable();
        }
    }

    function _updateClaim(
        betDuel storage _duel,
        address _claimer
    ) internal returns (uint256 _payment) {
        if (_duel.releaseReward == pickOpts.opt1) {
            _payment =
                (_duel.userDeposits[_claimer][block.chainid]._amountOp1 *
                    _duel.totalPrizePool) /
                _duel.opt1PrizePool;
            _duel.userClaimed[_claimer] = true;
            _duel.unclaimedPrizePool -= _payment;
            _transferUserAmount(_payment);
        } else if (_duel.releaseReward == pickOpts.opt2) {
            _payment =
                (_duel.userDeposits[_claimer][block.chainid]._amountOp2 *
                    _duel.totalPrizePool) /
                _duel.opt2PrizePool;
            _duel.userClaimed[_claimer] = true;
            _duel.unclaimedPrizePool -= _payment;
            _transferUserAmount(_payment);
        } else if (_duel.releaseReward == pickOpts.opt3) {
            _payment =
                (_duel.userDeposits[_claimer][block.chainid]._amountOp2 *
                    _duel.totalPrizePool) /
                _duel.opt2PrizePool;
            _duel.userClaimed[_claimer] = true;
            _duel.unclaimedPrizePool -= _payment;
            _transferUserAmount(_payment);
        } else {
            revert claimNotAvailable();
        }
    }

    function _5percent(betDuel storage _duel) internal {
        uint256 _pay = (_duel.totalPrizePool * 300) / 10000;
        bool success = _paymentToken.transfer(_treasuryAccount, _pay);
        if (!success) revert transferDidNotSucceed();
        emit feeTaken(_treasuryAccount, _pay, block.chainid);

        _pay = (_duel.totalPrizePool * 100) / 10000;
        success = _paymentToken.transfer(_operationManager, _pay);
        if (!success) revert transferDidNotSucceed();
        emit feeTaken(_operationManager, _pay, block.chainid);

        _pay = (_duel.totalPrizePool * 100) / 10000;
        success = _paymentToken.transfer(
            _duel.duelCreator[block.chainid],
            _pay
        );
        if (!success) revert transferDidNotSucceed();
        emit feeTaken(_duel.duelCreator[block.chainid], _pay, block.chainid);

        _duel.totalPrizePool -= (_pay * 5);
    }

    //----------------------------------------------------------------------------------------------------
    //                                             L0 FUNCTIONS
    //----------------------------------------------------------------------------------------------------
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /* _guid */,
        bytes calldata payload,
        address, // Executor address as specified by the OApp.
        bytes calldata // Any extra data or options to trigger on receipt.
    ) internal override {
        if (bytes4(payload[:4]) == BET_ON_DUEL_SELECTOR) {
            (
                ,
                bytes32 _id,
                pickOpts _opt,
                uint256 _amount,
                uint256 chainId,
                address _user
            ) = abi.decode(
                    payload,
                    (bytes4, bytes32, pickOpts, uint256, uint256, address)
                );
            _betOnDuel(_id, _opt, _amount, chainId, _user);
        } else if (bytes4(payload[:4]) == CREATE_DUEL_SELECTOR) {
            (
                ,
                coreModule.CreateDuelInput memory _newDuel,
                uint256 chainId,

            ) = abi.decode(
                    payload,
                    (bytes4, coreModule.CreateDuelInput, uint256, address)
                );
            _createDuel(_newDuel, chainId);
        }
    }

    function _betOnDuel(
        bytes32 _id,
        pickOpts _option,
        uint256 _amount,
        uint256 _chainId,
        address _user
    ) internal notBlockedBytes32(_id) whenNotPaused {
        betDuel storage _aux = _checkDuelExistence(_id);
        require(
            block.timestamp <= _aux.deadlineTimestamp,
            "Bet not possible due to time limit"
        );
        _depositPick(_amount, _option, _user, _aux, _chainId);

        if (
            _aux.unclaimedPrizePool <= _aux.totalPrizePool &&
            _aux.unclaimedPrizePool != 0 &&
            _aux.duelCreator[block.chainid] != address(0)
        ) {
            bool success = _paymentToken.transfer(
                _aux.duelCreator[block.chainid],
                _aux.unclaimedPrizePool
            );
            if (!success) revert transferDidNotSucceed();
            _aux.unclaimedPrizePool = 0;
        } else if (
            _aux.unclaimedPrizePool <= _aux.totalPrizePool &&
            _aux.unclaimedPrizePool != 0
        ) {
            _releaseGuaranteed(_id, _aux.unclaimedPrizePool, _aux.chainId);
        }

        emit duelBet(
            _user,
            _amount,
            _option,
            _aux.duelTitle,
            _aux.eventTimestamp,
            _chainId
        );
    }

    // @note check if timestamps in all chains are equeal
    function _createDuel(
        coreModule.CreateDuelInput memory _newDuel,
        uint256 _chainId
    ) internal whenNotPaused {
        _checkTimestamp(_newDuel.eventTimestamp);
        _checkTimestamp(_newDuel.deadlineTimestamp);

        _populateDuel(_newDuel, _chainId);
        emit duelCreated(
            _newDuel.duelTitle,
            _newDuel.eventTimestamp,
            _newDuel.initialPrizePool,
            _chainId
        );
    }

    function _releaseGuaranteed(
        string memory duelTitle,
        uint256 eventTimestamp,
        uint256 _amount,
        uint256 _chain
    ) internal whenNotPaused {
        bytes32 _id = keccak256(abi.encode(eventTimestamp, duelTitle));
        _releaseGuaranteed(_id, _amount, _chain);
    }

    function _releaseGuaranteed(
        bytes32 _id,
        uint256 _amount,
        uint256 _chain
    ) internal whenNotPaused {
        require(eIds[_chain] != 0, "Cannot release: invalid chain id");
        bytes memory _payload = abi.encode(
            RELEASE_DUEL_GUARANTEED,
            _id,
            block.chainid,
            _amount
        );
        _lzSend(
            eIds[_chain],
            _payload,
            options[RELEASE_DUEL_GUARANTEED],
            // Fee in native gas and ZRO token.
            MessagingFee(msg.value, 0),
            // Refund address in case of failed source message.
            payable(address(this))
        );
    }

    function quoteRelease(
        bytes32 _id,
        uint256 _chain
    ) external view returns (MessagingFee memory) {
        require(eIds[_chain] != 0, "Cannot release: invalid chain id");
        uint256 _amount = duels[_id].unclaimedPrizePool;
        bytes memory _message = abi.encode(
            RELEASE_DUEL_GUARANTEED,
            _id,
            block.chainid,
            _amount
        );
        return
            _quote(
                eIds[_chain],
                _message,
                options[RELEASE_DUEL_GUARANTEED],
                payInLzToken
            );
    }
}
