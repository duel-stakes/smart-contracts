// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GlacisClientOwnable} from "@glacis/client/GlacisClientOwnable.sol";
import {UUPSUpgradeable, ERC1967Utils} from "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

abstract contract CoreModule is
    GlacisClientOwnable,
    UUPSUpgradeable,
    Initializable
{
    //----------------------------------------------------------------------------------------------------
    //                                               STORAGE
    //----------------------------------------------------------------------------------------------------

    mapping(address => bool) public duelCreators;
    mapping(address => bool) public allowedControllers;
    bool public paused;

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
    address mainAdapter;

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
        bool drawAvaliable;
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
    error senderNotOwnerNorOperator();
    error DrawNotAvailable();

    //----------------------------------------------------------------------------------------------------
    //                                               EVENTS
    //----------------------------------------------------------------------------------------------------
    event duelCreatorChanged(address indexed _address, bool indexed _allowed);

    event changedModule(uint256 indexed _chain, address indexed _module);
    event changedChain(uint256 indexed _Modulechain, uint256 indexed _dstChain);
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
    event CrossChainInitiated(
        string _function,
        bytes32 indexed _hash,
        uint256 indexed _chain
    );

    //----------------------------------------------------------------------------------------------------
    //                                               MODIFIERS
    //----------------------------------------------------------------------------------------------------

    modifier onlyCreator() {
        if (!duelCreators[msg.sender]) revert notAllowedCreator();
        _;
    }
    modifier ownerOrRouterOrController() {
        if (
            msg.sender != owner() &&
            msg.sender != routerOperator &&
            !allowedControllers[msg.sender]
        ) revert senderNotOwnerNorOperator();
        _;
    }

    //----------------------------------------------------------------------------------------------------
    //                                           CONSTRUCTOR
    //----------------------------------------------------------------------------------------------------

    constructor(
        address _glacisRouter,
        uint256 _quorum,
        address _owner
    ) GlacisClientOwnable(_glacisRouter, _quorum, _owner) {}

    function __core_init(
        address _owner,
        address __paymentToken,
        address __treasuryAccount,
        address __operationManager,
        address __mainAdapter
    ) internal {
        paused = false;
        _paymentToken = IERC20(__paymentToken);
        _treasuryAccount = __treasuryAccount;
        _operationManager = __operationManager;
        routerOperator = _owner;
        duelCreators[msg.sender] = true;
        allowedControllers[msg.sender] = true;
        mainAdapter = __mainAdapter;
    }

    /// -----------------------------------------------------------------------
    /// View external proxy functions
    /// -----------------------------------------------------------------------
    /**
     * @notice Gets the implementation address.
     * @dev Uses OpenZeppelin's {ERC1967Utils} contract.
     * @return - address - address of the implementation contract.
     */
    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /// -----------------------------------------------------------------------
    /// View internal/private proxy functions
    /// -----------------------------------------------------------------------

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only owner can upgrade contract.
     */
    function _authorizeUpgrade(
        address /* newImplementation */
    ) internal view override(UUPSUpgradeable) onlyOwner {}

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
        paused = true;
    }

    function unpause() public onlyOwner {
        paused = false;
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

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(paused == false, "Contract must not be paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused == true, "Contract must be paused");
        _;
    }

    //----------------------------------------------------------------------------------------------------
    //                                               LIQUIDITY ROUTING
    //----------------------------------------------------------------------------------------------------

    function route(
        address target,
        uint256 amount,
        uint256 msgValue,
        bytes calldata data
    ) external payable returns (bool) {
        if (msg.sender != routerOperator && msg.sender != owner())
            revert NotRouterOperator(msg.sender);
        if (_paymentToken.allowance(address(this), target) < amount)
            _paymentToken.approve(target, amount);
        if (msgValue == 0) {
            (bool success, ) = payable(target).call{value: msg.value}(data);
            return success;
        } else {
            (bool success, ) = payable(target).call{value: msgValue}(data);
            return success;
        }
    }

    //----------------------------------------------------------------------------------------------------
    //                                       LIQUIDITY ROUTING CONFIGS
    //----------------------------------------------------------------------------------------------------

    function changeRouterOperator(address newRouter) external returns (bool) {
        if (msg.sender != routerOperator && msg.sender != owner())
            revert NotRouterOperator(msg.sender);
        routerOperator = newRouter;
        return true;
    }
}
