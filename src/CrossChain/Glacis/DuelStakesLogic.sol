// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import {CoreModule, ICommons} from "./CoreModule.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

///@author Waiandt.eth

contract DuelStakesL0 is CoreModule {
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
    mapping(uint256 chainId => address module) public modules;
    mapping(bytes4 selector => bytes option) public options;

    //----------------------------------------------------------------------------------------------------
    //                                               STRUCTS
    //----------------------------------------------------------------------------------------------------

    struct betDuel {
        pickOpts releaseReward;
        duelInfo info;
        prizes prizepool;
        mapping(address => bool) userClaimed; //math to do is total pooled on (pooledAmount/winner)*totalprizepool = (pooledAmount*totalprizepool/winner)
        mapping(address => mapping(uint256 chainId => deposit)) userDeposits;
    }

    struct duelInfo {
        bool blockedDuel;
        string duelTitle;
        string duelDescription;
        string eventTitle;
        uint128 eventTimestamp;
        uint128 deadlineTimestamp;
        uint256 chainId;
        address duelCreator;
    }
    struct prizes {
        uint256 totalPrizePool; //opt 0 -> totalPrizePool - opt1 - opt2 - opt3 + unclaimedPrizePool == garantido
        uint256 opt1PrizePool;
        uint256 opt2PrizePool;
        uint256 opt3PrizePool;
        uint256 unclaimedPrizePool; //garantido quando bet em andamento && nao claimed quando bet fechada
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
        uint256 indexed _chain,
        uint256 totalPrizePool
    );

    //----------------------------------------------------------------------------------------------------
    //                                               MODIFIERS
    //----------------------------------------------------------------------------------------------------

    modifier notBlocked(string calldata _title, uint256 _eventDate) {
        if (duels[keccak256(abi.encode(_eventDate, _title))].info.blockedDuel)
            revert duelIsBlocked();
        _;
    }
    modifier notBlockedMemory(string memory _title, uint256 _eventDate) {
        if (duels[keccak256(abi.encode(_eventDate, _title))].info.blockedDuel)
            revert duelIsBlocked();
        _;
    }
    modifier notBlockedBytes32(bytes32 _id) {
        if (duels[_id].info.blockedDuel) revert duelIsBlocked();
        _;
    }

    //----------------------------------------------------------------------------------------------------
    //                                           CONSTRUCTOR/INITIALIZER
    //----------------------------------------------------------------------------------------------------

    constructor(
        address _glacisRouter,
        uint256 _quorum,
        address _owner
    ) CoreModule(_glacisRouter, _quorum, _owner) Ownable(_owner) {}

    function initialize(
        address __paymentToken,
        address __treasuryAccount,
        address __operationManager,
        address _owner,
        address __mainAdapter
    ) external reinitializer(uint64(8)) {
        __core_init(
            _owner,
            __paymentToken,
            __treasuryAccount,
            __operationManager,
            __mainAdapter
        );
    }

    //----------------------------------------------------------------------------------------------------
    //                                           DUELS EMERGENCY PROTOCOL
    //----------------------------------------------------------------------------------------------------
    //@note CREATE A CANCEL BET // DO THE CROSSCHAIN UNLOCK FUNDS (backend system)
    function emergencyWithdraw(
        string calldata _title,
        uint256 _eventDate
    ) public onlyOwner {
        betDuel storage _aux = _checkDuelExistence(_title, _eventDate);

        bool success = _paymentToken.transfer(
            _treasuryAccount,
            _aux.prizepool.unclaimedPrizePool
        );
        if (!success) revert transferDidNotSucceed();

        _aux.releaseReward = pickOpts.none;
        _aux.info.blockedDuel = true;
        _aux.prizepool.unclaimedPrizePool = 0;

        emit emergencyBlock(_title, _eventDate);
    }

    function cancelDuel(string calldata _title, uint256 _eventDate) public {
        betDuel storage _aux = _checkDuelExistence(_title, _eventDate);

        if ((msg.sender != owner()) && (msg.sender != _aux.info.duelCreator))
            revert notDuelManager(msg.sender);

        _releaseGuaranteed(
            _title,
            _eventDate,
            _aux.prizepool.unclaimedPrizePool,
            _aux.info.chainId
        );

        _aux.releaseReward = pickOpts.none;
        _aux.info.blockedDuel = true;
        _aux.prizepool.unclaimedPrizePool = _aux.prizepool.totalPrizePool;

        emit cancelledDuel(_title, _eventDate, _aux.info.chainId);
    }

    function changeTimestamp(
        string calldata _title,
        uint256 _eventDate,
        uint128 _deadline,
        uint128 _eventTimestamp
    ) public {
        betDuel storage _aux = _checkDuelExistence(_title, _eventDate);

        if ((msg.sender != owner()) && (msg.sender != _aux.info.duelCreator))
            revert notDuelManager(msg.sender);

        _aux.info.deadlineTimestamp = _deadline;
        _aux.info.eventTimestamp = _eventTimestamp;

        emit changedTimestamp(_title, _eventDate, block.chainid, address(this));
    }

    //----------------------------------------------------------------------------------------------------
    //                                               DUELS CREATION
    //----------------------------------------------------------------------------------------------------

    function createDuel(
        CoreModule.CreateDuelInput calldata _newDuel
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
        if (_newDuel.initialPrizePool != 0) {
            _checkAmount(_newDuel.initialPrizePool);
            _transferAmount(_newDuel.initialPrizePool);
        }

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
            block.timestamp <= _aux.info.deadlineTimestamp,
            "Bet not possible due to time limit"
        );
        _checkAmount(_amount);
        _transferAmount(_amount);
        _depositPick(_amount, _option, msg.sender, _aux, block.chainid);

        if (
            _aux.prizepool.unclaimedPrizePool <=
            _aux.prizepool.totalPrizePool &&
            _aux.prizepool.unclaimedPrizePool != 0 &&
            _aux.info.duelCreator != address(0)
        ) {
            bool success = _paymentToken.transfer(
                _aux.info.duelCreator,
                _aux.prizepool.unclaimedPrizePool
            );
            if (!success) revert transferDidNotSucceed();
            _aux.prizepool.unclaimedPrizePool = 0;
        } else if (
            _aux.prizepool.unclaimedPrizePool <=
            _aux.prizepool.totalPrizePool &&
            _aux.prizepool.unclaimedPrizePool != 0
        ) {
            _releaseGuaranteed(
                _title,
                _eventDate,
                _aux.prizepool.unclaimedPrizePool,
                _aux.info.chainId
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
    ) public payable ownerOrRouterOrController {
        betDuel storage _aux = _checkDuelExistence(_title, _eventDate);
        require(
            _aux.info.eventTimestamp <= block.timestamp,
            "event did not happen yet"
        );
        if (
            _aux.prizepool.totalPrizePool < _aux.prizepool.unclaimedPrizePool &&
            _aux.prizepool.totalPrizePool > 0 &&
            _aux.info.chainId == block.chainid
        ) {
            bool success = _paymentToken.transfer(
                _aux.info.duelCreator,
                _aux.prizepool.totalPrizePool
            );
            if (!success) revert transferDidNotSucceed();
            _aux.prizepool.totalPrizePool = _aux.prizepool.unclaimedPrizePool;
            _5percent(_aux);
        } else if (
            _aux.prizepool.totalPrizePool < _aux.prizepool.unclaimedPrizePool &&
            _aux.prizepool.totalPrizePool > 0
        ) {
            _releaseGuaranteed(
                _title,
                _eventDate,
                _aux.prizepool.unclaimedPrizePool -
                    _aux.prizepool.totalPrizePool,
                _aux.info.chainId
            );
            _aux.prizepool.totalPrizePool = _aux.prizepool.unclaimedPrizePool;
        }
        _aux.releaseReward = _winner;
        _aux.prizepool.unclaimedPrizePool = _aux.prizepool.totalPrizePool;
        emit betClosed(
            _title,
            _eventDate,
            _winner,
            _aux.info.chainId,
            _aux.prizepool.totalPrizePool
        );
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

    function changeModule(uint256 _chain, address _module) public onlyOwner {
        modules[_chain] = _module;
        GlacisRoute memory allowedRoute = GlacisRoute({
            fromChainId: _chain,
            fromAddress: bytes32(bytes20(uint160(_module))),
            fromAdapter: address(WILDCARD)
        });
        _addAllowedRoute(allowedRoute);
        emit changedModule(_chain, _module);
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
        return duels[_id].info.blockedDuel;
    }

    function getDuelTitleAndDescrition(
        string memory _title,
        uint256 _timestamp
    ) public view returns (string memory, string memory, string memory) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return (
            duels[_id].info.duelTitle,
            duels[_id].info.duelDescription,
            duels[_id].info.eventTitle
        );
    }

    function getTimestamps(
        string memory _title,
        uint256 _timestamp
    ) public view returns (uint256, uint256) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return (
            duels[_id].info.eventTimestamp,
            duels[_id].info.deadlineTimestamp
        );
    }

    function getPrizes(
        string memory _title,
        uint256 _timestamp
    ) public view returns (uint256, uint256, uint256, uint256, uint256) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return (
            duels[_id].prizepool.totalPrizePool,
            duels[_id].prizepool.opt1PrizePool,
            duels[_id].prizepool.opt2PrizePool,
            duels[_id].prizepool.opt3PrizePool,
            duels[_id].prizepool.unclaimedPrizePool
        );
    }

    function getCreator(
        string memory _title,
        uint256 _timestamp
    ) public view returns (address) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return (duels[_id].info.duelCreator);
    }

    function getDuelChainId(
        string memory _title,
        uint256 _timestamp
    ) public view returns (uint256) {
        bytes32 _id = keccak256(abi.encode(_timestamp, _title));
        return (duels[_id].info.chainId);
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
            keccak256(abi.encodePacked(_aux.info.duelTitle)) !=
            keccak256(abi.encodePacked(_title))
        ) revert duelDoesNotExist();
    }

    function _checkDuelExistence(
        bytes32 _id
    ) internal view returns (betDuel storage _aux) {
        _aux = duels[_id];
        if (
            keccak256(abi.encodePacked(_aux.info.duelTitle)) ==
            keccak256(abi.encodePacked(""))
        ) revert duelDoesNotExist();
    }

    function _populateDuel(
        CoreModule.CreateDuelInput memory _newDuel,
        uint256 _chainId
    ) internal {
        betDuel storage _aux = duels[
            keccak256(abi.encode(_newDuel.eventTimestamp, _newDuel.duelTitle))
        ];
        _aux.info.duelTitle = _newDuel.duelTitle;
        _aux.info.eventTitle = _newDuel.eventTitle;
        _aux.info.duelDescription = _newDuel.duelDescription;
        _aux.info.duelCreator = _newDuel.duelCreator;
        _aux.info.deadlineTimestamp = uint128(_newDuel.deadlineTimestamp);
        _aux.info.eventTimestamp = uint128(_newDuel.eventTimestamp);
        _aux.prizepool.unclaimedPrizePool = _newDuel.initialPrizePool;
        _aux.info.chainId = _chainId;
        if (!_newDuel.drawAvailable) {
            _aux.prizepool.opt2PrizePool = type(uint256).max;
        }
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
            _duel.prizepool.totalPrizePool += _amount;
            _duel.prizepool.opt1PrizePool += _amount;
            _duel.userDeposits[sender][chainId]._amountOp1 += _amount;
        } else if (_pick == pickOpts.opt2) {
            if (_duel.prizepool.opt2PrizePool == type(uint256).max)
                revert DrawNotAvailable();
            _duel.prizepool.totalPrizePool += _amount;
            _duel.prizepool.opt2PrizePool += _amount;
            _duel.userDeposits[sender][chainId]._amountOp2 += _amount;
        } else if (_pick == pickOpts.opt3) {
            _duel.prizepool.totalPrizePool += _amount;
            _duel.prizepool.opt3PrizePool += _amount;
            _duel.userDeposits[sender][chainId]._amountOp3 += _amount;
        } else if (_pick == pickOpts.none) {
            //@note THIS OPTIONS DOES NOT INTAKE POINTS
            _duel.prizepool.totalPrizePool += _amount;
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
                    _duel.prizepool.totalPrizePool) /
                _duel.prizepool.opt1PrizePool;
            _duel.userClaimed[_claimer] = true;
            _duel.prizepool.unclaimedPrizePool -= _payment;
            _transferUserAmount(_payment);
        } else if (_duel.releaseReward == pickOpts.opt2) {
            _payment =
                (_duel.userDeposits[_claimer][block.chainid]._amountOp2 *
                    _duel.prizepool.totalPrizePool) /
                _duel.prizepool.opt2PrizePool;
            _duel.userClaimed[_claimer] = true;
            _duel.prizepool.unclaimedPrizePool -= _payment;
            _transferUserAmount(_payment);
        } else if (_duel.releaseReward == pickOpts.opt3) {
            _payment =
                (_duel.userDeposits[_claimer][block.chainid]._amountOp2 *
                    _duel.prizepool.totalPrizePool) /
                _duel.prizepool.opt2PrizePool;
            _duel.userClaimed[_claimer] = true;
            _duel.prizepool.unclaimedPrizePool -= _payment;
            _transferUserAmount(_payment);
        } else if (
            _duel.releaseReward == pickOpts.none && _duel.info.blockedDuel
        ) {
            _payment = (_duel.userDeposits[_claimer][block.chainid]._amountOp1 +
                _duel.userDeposits[_claimer][block.chainid]._amountOp2 +
                _duel.userDeposits[_claimer][block.chainid]._amountOp3);
            _duel.userClaimed[_claimer] = true;
            _duel.prizepool.unclaimedPrizePool -= _payment;
            _transferUserAmount(_payment);
        } else {
            revert claimNotAvailable();
        }
    }

    function _5percent(betDuel storage _duel) internal {
        uint256 _pay = (_duel.prizepool.totalPrizePool * 300) / 10000;
        bool success = _paymentToken.transfer(_treasuryAccount, _pay);
        if (!success) revert transferDidNotSucceed();
        emit feeTaken(_treasuryAccount, _pay, block.chainid);

        _pay = (_duel.prizepool.totalPrizePool * 100) / 10000;
        success = _paymentToken.transfer(_operationManager, _pay);
        if (!success) revert transferDidNotSucceed();
        emit feeTaken(_operationManager, _pay, block.chainid);

        _pay = (_duel.prizepool.totalPrizePool * 100) / 10000;
        success = _paymentToken.transfer(_duel.info.duelCreator, _pay);
        if (!success) revert transferDidNotSucceed();
        emit feeTaken(_duel.info.duelCreator, _pay, block.chainid);

        _duel.prizepool.totalPrizePool -= (_pay * 5);
    }

    //----------------------------------------------------------------------------------------------------
    //                                         CROSSCHAIN FUNCTIONS
    //----------------------------------------------------------------------------------------------------
    function _receiveMessage(
        address[] memory /*fromAdapters*/,
        uint256 /*fromChainId*/,
        bytes32 /*fromAddress*/,
        bytes memory payload
    ) internal override {
        bytes4 funcSelector;
        assembly {
            funcSelector := mload(add(payload, 32))
        }
        if (funcSelector == BET_ON_DUEL_SELECTOR) {
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
        } else if (funcSelector == CREATE_DUEL_SELECTOR) {
            (
                ,
                CoreModule.CreateDuelInput memory _newDuel,
                uint256 chainId,

            ) = abi.decode(
                    payload,
                    (bytes4, ICommons.CreateDuelInput, uint256, address)
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
            block.timestamp <= _aux.info.deadlineTimestamp,
            "Bet not possible due to time limit"
        );
        _depositPick(_amount, _option, _user, _aux, _chainId);

        if (
            _aux.prizepool.unclaimedPrizePool <=
            _aux.prizepool.totalPrizePool &&
            _aux.prizepool.unclaimedPrizePool != 0 &&
            _aux.info.duelCreator != address(0)
        ) {
            bool success = _paymentToken.transfer(
                _aux.info.duelCreator,
                _aux.prizepool.unclaimedPrizePool
            );
            if (!success) revert transferDidNotSucceed();
            _aux.prizepool.unclaimedPrizePool = 0;
        } else if (
            _aux.prizepool.unclaimedPrizePool <=
            _aux.prizepool.totalPrizePool &&
            _aux.prizepool.unclaimedPrizePool != 0
        ) {
            _releaseGuaranteed(
                _id,
                _aux.prizepool.unclaimedPrizePool,
                _aux.info.chainId
            );
        }

        emit duelBet(
            _user,
            _amount,
            _option,
            _aux.info.duelTitle,
            _aux.info.eventTimestamp,
            _chainId
        );
    }

    function _createDuel(
        CoreModule.CreateDuelInput memory _newDuel,
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
        require(
            modules[_chain] != address(0),
            "Cannot release: invalid chain id"
        );
        bytes memory _payload = abi.encode(
            RELEASE_DUEL_GUARANTEED,
            _id,
            block.chainid,
            _amount
        );
        bytes32 _hash = _routeSingle(
            _chain,
            bytes32(bytes20(uint160(modules[_chain]))),
            _payload,
            mainAdapter,
            address(this),
            msg.value
        );

        emit CrossChainInitiated("releaseGuaranteed", _hash, _chain);
    }
}
