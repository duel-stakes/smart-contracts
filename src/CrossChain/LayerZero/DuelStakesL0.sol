// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {OApp, Origin, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

///@author Waiandt.eth

contract duelStakesL0 is OApp, Pausable {
    //----------------------------------------------------------------------------------------------------
    //                                               STORAGE
    //----------------------------------------------------------------------------------------------------
    //----------------------------------------------------------------------------------------------------
    //                                               DUELS
    //----------------------------------------------------------------------------------------------------

    mapping(bytes32 => betDuel) public duels;
    mapping(address => bool) public duelCreators;

    //----------------------------------------------------------------------------------------------------
    //                                               ERC20 IDENTIFIER
    //----------------------------------------------------------------------------------------------------

    IERC20 public _paymentToken;
    address public _treasuryAccount;
    address public _operationManager;

    //----------------------------------------------------------------------------------------------------
    //                                               STRUCTS
    //----------------------------------------------------------------------------------------------------

    struct betDuel {
        pickOpts releaseReward;
        bool blockedDuel;
        string duelTitle;
        string duelDescription;
        string eventTitle;
        uint256 eventTimestamp;
        uint256 deadlineTimestamp;
        mapping(uint256 chainId => address) duelCreator;
        uint256 totalPrizePool;
        uint256 opt1PrizePool;
        uint256 opt2PrizePool;
        uint256 opt3PrizePool;
        uint256 unclaimedPrizePool;
        mapping(address => bool) userClaimed; //math to do is total pooled on (pooledAmount/winner)*totalprizepool = (pooledAmount*totalprizepool/winner)
        mapping(address => mapping(uint256 chainId => deposit)) userDeposits; //@note changed here
    }
    struct betDuelInput {
        string duelTitle;
        string duelDescription;
        string eventTitle;
        uint256 eventTimestamp;
        uint256 deadlineTimestamp;
        address duelCreator;
        uint256 initialPrizePool;
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

    //----------------------------------------------------------------------------------------------------
    //                                               ERRORS
    //----------------------------------------------------------------------------------------------------

    error notAllowedCreator();
    error nonExistingDuel();
    error transferDidNotSucceed();
    error emptyString();
    error eventAlreadyHappened();
    error callerNotTheCreator();
    error amountEmpty();
    error notEnoughBalance();
    error notEnoughAllowance();
    error duelDoesNotExist();
    error duelIsBlocked();
    error pickNotAvailable();
    error claimNotAvailable();

    //----------------------------------------------------------------------------------------------------
    //                                               EVENTS
    //----------------------------------------------------------------------------------------------------

    event duelCreatorChanged(address indexed _address, bool indexed _allowed);
    event emergencyBlock(string _title, uint256 indexed _eventDate);
    event duelCreated(
        string _title,
        uint256 indexed _eventDate,
        uint256 indexed _openAmount
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
        pickOpts indexed _winner
    );
    event claimedBet(
        string _title,
        uint256 indexed _eventDate,
        address indexed _user,
        uint256 indexed _payment
    );

    //----------------------------------------------------------------------------------------------------
    //                                               MODIFIERS
    //----------------------------------------------------------------------------------------------------

    modifier onlyCreator() {
        if (!duelCreators[msg.sender]) revert notAllowedCreator();
        _;
    }
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
        address _owner
    ) OApp(_endpoint, _owner) Ownable(_owner) Pausable() {
        _paymentToken = IERC20(__paymentToken);
        duelCreators[msg.sender] = true;
        _treasuryAccount = __treasuryAccount;
        _operationManager = __operationManager;
    }

    //----------------------------------------------------------------------------------------------------
    //                                           DUELS ADJUSTMENT MANAGER
    //----------------------------------------------------------------------------------------------------

    function changeDuelCreator(
        address _address,
        bool _allowed
    ) public onlyOwner {
        duelCreators[_address] = _allowed;
        emit duelCreatorChanged(_address, _allowed);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _pause();
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
        betDuelInput calldata _newDuel
    ) public onlyCreator whenNotPaused {
        _checkEmpty(_newDuel.duelTitle);
        _checkEmpty(_newDuel.duelDescription);
        _checkEmpty(_newDuel.eventTitle);
        _checkTimestamp(_newDuel.eventTimestamp);
        _checkTimestamp(_newDuel.deadlineTimestamp);
        _checkCaller(_newDuel.duelCreator);
        require(
            _newDuel.initialPrizePool >= 100,
            "Due to underflow you cannot set units less than 100"
        );
        _checkAmount(_newDuel.initialPrizePool);
        _transferAmount(_newDuel.initialPrizePool);

        _populateDuel(_newDuel);
        emit duelCreated(
            _newDuel.duelTitle,
            _newDuel.eventTimestamp,
            _newDuel.initialPrizePool
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
    ) public notBlocked(_title, _eventDate) whenNotPaused {
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
            _aux.unclaimedPrizePool != 0
        ) {
            bool success = _paymentToken.transfer(
                _aux.duelCreator[block.chainid],
                _aux.unclaimedPrizePool
            );
            if (!success) revert transferDidNotSucceed();
            _aux.unclaimedPrizePool = 0;
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
    ) public onlyOwner {
        betDuel storage _aux = _checkDuelExistence(_title, _eventDate);
        require(
            _aux.eventTimestamp <= block.timestamp,
            "event did not happen yet"
        );
        if (
            _aux.totalPrizePool < _aux.unclaimedPrizePool &&
            _aux.totalPrizePool > 0
        ) {
            bool success = _paymentToken.transfer(
                _aux.duelCreator[block.chainid],
                _aux.totalPrizePool
            );
            if (!success) revert transferDidNotSucceed();
            _aux.totalPrizePool = _aux.unclaimedPrizePool;
        }
        _5percent(_aux);
        _aux.releaseReward = _winner;
        _aux.unclaimedPrizePool = _aux.totalPrizePool;
        emit betClosed(_title, _eventDate, _winner);
    }

    function claimBet(
        string calldata _title,
        uint256 _eventDate
    ) public notBlocked(_title, _eventDate) whenNotPaused {
        betDuel storage _aux = _checkDuelExistence(_title, _eventDate);
        require(!_aux.userClaimed[msg.sender], "User already claimed");
        uint256 _payment = _updateClaim(_aux, msg.sender);

        emit claimedBet(_title, _eventDate, msg.sender, _payment);
    }

    //----------------------------------------------------------------------------------------------------
    //                                         MANAGEMENT SETTER FUNCTIONS
    //----------------------------------------------------------------------------------------------------

    function changeTreasury(address _treasury) public onlyOwner {
        _treasuryAccount = _treasury;
    }

    function changeOperations(address _operation) public onlyOwner {
        _operationManager = _operation;
    }

    function changePayment(address _payment) public onlyOwner {
        _paymentToken = IERC20(_payment);
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

    function _checkEmpty(string memory _str) internal pure {
        if (
            keccak256(abi.encodePacked(_str)) == keccak256(abi.encodePacked(""))
        ) revert emptyString();
    }

    function _checkTimestamp(uint256 _timestamp) internal view {
        if (_timestamp < block.timestamp) revert eventAlreadyHappened();
    }

    function _checkCaller(address _creator) internal view {
        if (_creator != msg.sender) revert callerNotTheCreator();
    }

    function _checkAmount(uint256 _amount) internal view {
        if (_amount == 0) revert amountEmpty();

        if (_paymentToken.balanceOf(msg.sender) < _amount)
            revert notEnoughBalance();

        if (_paymentToken.allowance(msg.sender, address(this)) < _amount)
            revert notEnoughAllowance();
    }

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
        if (_aux.duelCreator[block.chainid] == address(0))
            revert duelDoesNotExist();
    }

    function _populateDuel(betDuelInput calldata _newDuel) internal {
        betDuel storage _aux = duels[
            keccak256(abi.encode(_newDuel.eventTimestamp, _newDuel.duelTitle))
        ];
        _aux.duelTitle = _newDuel.duelTitle;
        _aux.eventTitle = _newDuel.eventTitle;
        _aux.duelDescription = _newDuel.duelDescription;
        _aux.duelCreator[block.chainid] = _newDuel.duelCreator;
        _aux.deadlineTimestamp = _newDuel.deadlineTimestamp;
        _aux.eventTimestamp = _newDuel.eventTimestamp;
        _aux.unclaimedPrizePool = _newDuel.initialPrizePool;
    }

    function _transferAmount(uint256 _amount) internal {
        bool success = _paymentToken.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        if (!success) revert transferDidNotSucceed();
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
        _pay = (_duel.totalPrizePool * 100) / 10000;
        success = _paymentToken.transfer(_operationManager, _pay);
        if (!success) revert transferDidNotSucceed();
        _pay = (_duel.totalPrizePool * 100) / 10000;
        success = _paymentToken.transfer(
            _duel.duelCreator[block.chainid],
            _pay
        );
        if (!success) revert transferDidNotSucceed();

        _duel.totalPrizePool -= (_pay * 5);
    }

    //----------------------------------------------------------------------------------------------------
    //                                             L0 FUNCTIONS
    //----------------------------------------------------------------------------------------------------

    //@note implement a bytes4 to get what function you're interacting with
    //@note Use local storage for bytes4 "_betOnDuel"
    //@note implement create a new duel
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /* _guid */,
        bytes calldata payload,
        address, // Executor address as specified by the OApp.
        bytes calldata // Any extra data or options to trigger on receipt.
    ) internal override {
        // Decode the payload to get the message
        // In this case, type is string, but depends on your encoding!
        if (
            bytes4(payload[:4]) ==
            bytes4(
                keccak256(
                    "_betOnDuel(string,uint256,uint8,uint256,uint256,address)"
                )
            )
        ) {
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
        }
    }

    //@note Implement a _lzSend with "release bet"
    //@note Implement a _lzSend with "repay guaranteed"

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
            _aux.unclaimedPrizePool != 0
        ) {
            bool success = _paymentToken.transfer(
                _aux.duelCreator[_chainId],
                _aux.unclaimedPrizePool
            );
            if (!success) revert transferDidNotSucceed();
            _aux.unclaimedPrizePool = 0;
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
        betDuelInput calldata _newDuel
    ) internal whenNotPaused {
        _checkTimestamp(_newDuel.eventTimestamp);
        _checkTimestamp(_newDuel.deadlineTimestamp);

        _populateDuel(_newDuel);
        emit duelCreated(
            _newDuel.duelTitle,
            _newDuel.eventTimestamp,
            _newDuel.initialPrizePool
        );
    }
}
