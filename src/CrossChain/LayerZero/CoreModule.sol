// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract CoreModule is Ownable, Pausable {
    //----------------------------------------------------------------------------------------------------
    //                                               STORAGE
    //----------------------------------------------------------------------------------------------------

    mapping(address => bool) public duelCreators;

    //----------------------------------------------------------------------------------------------------
    //                                               ERC20 IDENTIFIER
    //----------------------------------------------------------------------------------------------------

    IERC20 public _paymentToken;
    address public _treasuryAccount;
    address public _operationManager;

    //----------------------------------------------------------------------------------------------------
    //                                                  ROUTER
    //----------------------------------------------------------------------------------------------------

    address routerOperator;

    //----------------------------------------------------------------------------------------------------
    //                                        CROSSCHAIN VARIABLES
    //----------------------------------------------------------------------------------------------------

    bool payInLzToken;

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

    //----------------------------------------------------------------------------------------------------
    //                                        STRUCTS
    //----------------------------------------------------------------------------------------------------

    struct CreateDuelInput {
        string duelTitle;
        string duelDescription;
        string eventTitle;
        uint256 eventTimestamp;
        uint256 deadlineTimestamp;
        address duelCreator;
        uint256 initialPrizePool;
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
    error NotRouterOperator(address sender);

    //----------------------------------------------------------------------------------------------------
    //                                               EVENTS
    //----------------------------------------------------------------------------------------------------
    event duelCreatorChanged(address indexed _address, bool indexed _allowed);

    event claimedBet(
        string _title,
        uint256 indexed _eventDate,
        address indexed _user,
        uint256 indexed _payment,
        pickOpts _winner,
        uint256 _chain
    );

    event changedEId(uint256 indexed _chain, uint32 indexed _eId);
    event feeTaken(
        address indexed _operation,
        uint256 indexed _amount,
        uint256 indexed _chain
    );

    event claimedBet(
        string _title,
        uint256 indexed _eventDate,
        address indexed _user,
        uint256 indexed _amount,
        uint256 _chain
    );

    //----------------------------------------------------------------------------------------------------
    //                                               MODIFIERS
    //----------------------------------------------------------------------------------------------------

    modifier onlyCreator() {
        if (!duelCreators[msg.sender]) revert notAllowedCreator();
        _;
    }

    //----------------------------------------------------------------------------------------------------
    //                                           CONSTRUCTOR
    //----------------------------------------------------------------------------------------------------

    constructor(
        address _owner,
        address __paymentToken,
        address __treasuryAccount,
        address __operationManager
    ) Ownable(_owner) {
        _paymentToken = IERC20(__paymentToken);
        _treasuryAccount = __treasuryAccount;
        _operationManager = __operationManager;
        routerOperator = _owner;
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

    function _transferAmount(uint256 _amount) internal {
        bool success = _paymentToken.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        if (!success) revert transferDidNotSucceed();
    }

    //----------------------------------------------------------------------------------------------------
    //                                               LIQUIDITY ROUTING
    //----------------------------------------------------------------------------------------------------

    function route(
        address target,
        uint256 amount,
        bytes calldata data
    ) external payable returns (bool) {
        if (msg.sender != routerOperator || msg.sender != owner())
            revert NotRouterOperator(msg.sender);

        require(
            _paymentToken.approve(target, amount),
            "Deposit module: approve didn't go through"
        );
        (bool success, ) = payable(target).call{value: msg.value}(data);
        return success;
    }

    //----------------------------------------------------------------------------------------------------
    //                                       LIQUIDITY ROUTING CONFIGS
    //----------------------------------------------------------------------------------------------------

    function changeRouterOperator(address newRouter) external returns (bool) {
        if (msg.sender != routerOperator || msg.sender == owner())
            revert NotRouterOperator(msg.sender);
        routerOperator = newRouter;
        return true;
    }
}
