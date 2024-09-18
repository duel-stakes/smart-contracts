// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CoreModule, ICommons} from "./CoreModule.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DepositModule is CoreModule {
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

    address public dstModule;
    uint256 public dstChain;
    // bytes options;
    // bytes options2;

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
        bool drawAvailable;
        mapping(address => bool) userClaimed; //math to do is total pooled on (pooledAmount/winner)*totalprizepool = (pooledAmount*totalprizepool/winner)
        mapping(address => deposit) userDeposits;
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
        address _glacisRouter,
        uint256 _quorum,
        address _owner
    ) CoreModule(_glacisRouter, _quorum, _owner) Ownable(_owner) {}

    function initialize(
        address _owner,
        address __paymentToken,
        address __treasuryAccount,
        address __operationManager,
        address __mainAdapter
    ) external reinitializer(uint64(0)) {
        __core_init(
            _owner,
            __paymentToken,
            __treasuryAccount,
            __operationManager,
            __mainAdapter
        );
    }

    //----------------------------------------------------------------------------------------------------
    //                                               MANAGEMENT
    //----------------------------------------------------------------------------------------------------
    function changeModule(address _module) public onlyOwner {
        dstModule = _module;
        GlacisRoute memory allowedRoute = GlacisRoute({
            fromChainId: dstChain,
            fromAddress: bytes32(bytes20(uint160(_module))),
            fromAdapter: address(WILDCARD)
        });
        _addAllowedRoute(allowedRoute);
        emit changedModule(block.chainid, _module);
    }

    function changeChain(uint256 _dstChain) public onlyOwner {
        dstChain = _dstChain;
        GlacisRoute memory allowedRoute = GlacisRoute({
            fromChainId: _dstChain,
            fromAddress: bytes32(bytes20(uint160(dstModule))),
            fromAdapter: address(WILDCARD)
        });
        _addAllowedRoute(allowedRoute);
        emit changedChain(block.chainid, _dstChain);
    }

    function cancelDuel(string calldata _title, uint256 _eventDate) public {
        bytes32 _id = keccak256(abi.encode(_eventDate, _title));
        if (duels[_id].duelCreator == address(0)) revert eventDoesNotExists();

        if ((msg.sender != owner()) && (msg.sender != duels[_id].duelCreator))
            revert notDuelManager(msg.sender);

        _releaseGuarateed(_id, duels[_id].guaranteed);

        duels[_id].releaseReward = pickOpts.none;
        duels[_id].blockedDuel = true;
        duels[_id].multiplier = 1 ether;

        emit cancelledDuel(_title, _eventDate, block.chainid);
    }

    function changeTimestamp(
        string calldata _title,
        uint256 _eventDate,
        uint128 _eventTimestamp
    ) public {
        bytes32 _id = keccak256(abi.encode(_eventDate, _title));
        if (duels[_id].duelCreator == address(0)) revert eventDoesNotExists();

        if ((msg.sender != owner()) && (msg.sender != duels[_id].duelCreator))
            revert notDuelManager(msg.sender);

        duels[_id].eventTimestamp = _eventTimestamp;

        /// @note create a multichain change event timestamp interaction for the data

        emit changedTimestamp(_title, _eventDate, block.chainid, address(this));
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
        } else if (_pick == pickOpts.opt2 && _duel.drawAvailable) {
            _duel.userDeposits[sender]._amountOp2 += _amount;
        } else if (_pick == pickOpts.opt2 && !_duel.drawAvailable) {
            revert DrawNotAvailable();
        } else if (_pick == pickOpts.opt3) {
            _duel.userDeposits[sender]._amountOp3 += _amount;
        } else if (_pick == pickOpts.none) {
            //@note THIS OPTIONS DOES NOT INTAKE POINTS
            _duel.guaranteed += _amount;
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
        _aux.drawAvailable = _newDuel.drawAvailable;
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
        if (_aux.releaseReward == ICommons.pickOpts.opt1) {
            require(
                _aux.userDeposits[msg.sender]._amountOp1 > 0,
                "No bets done on the winner"
            );
            _aux.userClaimed[msg.sender] = true;
            return
                (_aux.userDeposits[msg.sender]._amountOp1 * _aux.multiplier) /
                1 ether;
        } else if (_aux.releaseReward == ICommons.pickOpts.opt2) {
            require(
                _aux.userDeposits[msg.sender]._amountOp2 > 0,
                "No bets done on the winner"
            );
            _aux.userClaimed[msg.sender] = true;
            return
                (_aux.userDeposits[msg.sender]._amountOp2 * _aux.multiplier) /
                1 ether;
        } else if (_aux.releaseReward == ICommons.pickOpts.opt3) {
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
    ) external ownerOrRouterOrController returns (bool) {
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
            ///@follow-up test to remove the block.chainid + 1
            block.chainid,
            msg.sender
        );

        bytes32 _hash = _routeSingle(
            dstChain,
            bytes32(bytes20(uint160(dstModule))),
            _payload,
            mainAdapter,
            address(this),
            msg.value
        );

        emit CrossChainInitiated("betOnDuel", _hash, dstChain);
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
            ///@follow-up test to remove the block.chainid + 1
            block.chainid,
            msg.sender
        );

        bytes32 _hash = _routeSingle(
            dstChain,
            bytes32(bytes20(uint160(dstModule))),
            _payload,
            mainAdapter,
            address(this),
            msg.value
        );

        emit CrossChainInitiated("betOnDuelFull", _hash, dstChain);
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
        if (_newDuel.initialPrizePool != 0) {
            _checkAmount(_newDuel.initialPrizePool);
            _transferAmount(_newDuel.initialPrizePool);
        }
        _populateDuel(_newDuel);

        bytes memory _payload = abi.encode(
            CREATE_DUEL_SELECTOR,
            _newDuel,
            ///@follow-up test to remove the block.chainid + 1
            block.chainid,
            msg.sender
        );

        bytes32 _hash = _routeSingle(
            dstChain,
            bytes32(bytes20(uint160(dstModule))),
            _payload,
            mainAdapter,
            address(this),
            msg.value
        );

        emit CrossChainInitiated("createDuel", _hash, dstChain);
    }

    //----------------------------------------------------------------------------------------------------
    //                                               CROSS-CHAIN MESSAGE
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
        if (funcSelector == RELEASE_DUEL_GUARANTEED) {
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
}
