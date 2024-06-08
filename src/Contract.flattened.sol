// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2 ^0.8.20;

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// lib/openzeppelin-contracts/contracts/utils/Pausable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
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
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// src/DuelStakes.sol

///@author Waiandt.eth

contract duelStakes is Ownable,Pausable{

    //----------------------------------------------------------------------------------------------------
    //                                               STORAGE
    //----------------------------------------------------------------------------------------------------
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

    struct betDuel{
        pickOpts releaseReward;
        bool blockedDuel;
        string duelTitle;
        string duelDescription;
        string eventTitle;
        uint256 eventTimestamp;
        uint256 deadlineTimestamp;
        address duelCreator;
        uint256 totalPrizePool;
        uint256 opt1PrizePool;
        uint256 opt2PrizePool;
        uint256 opt3PrizePool;
        uint256 unclaimedPrizePool;
        mapping (address => bool) userClaimed; //math to do is total pooled on (pooledAmount/winner)*totalprizepool = (pooledAmount*totalprizepool/winner)
        mapping (address => deposit) userDeposits;
    }
    struct betDuelInput{
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
    event duelCreated(string _title, uint256 indexed _eventDate, uint256 indexed _openAmount);
    event duelBet(address indexed _user, uint256 indexed _amount, pickOpts indexed _pick, string _title, uint256 _eventDate);
    event betClosed(string _title, uint256 indexed _eventDate, pickOpts indexed _winner);
    event claimedBet(string _title, uint256 indexed _eventDate, address indexed _winner);
    //@note on claimed bet put the amount withdraw as well

    //----------------------------------------------------------------------------------------------------
    //                                               MODIFIERS
    //----------------------------------------------------------------------------------------------------

    modifier onlyCreator(){
        if(!duelCreators[msg.sender])
        revert notAllowedCreator();
        _;
    }
    modifier notBlocked(string calldata _title, uint256 _eventDate){
        if(duels[keccak256(abi.encode(_eventDate,_title))].blockedDuel)
        revert duelIsBlocked();
        _;
    }
    
    //----------------------------------------------------------------------------------------------------
    //                                           CONSTRUCTOR/INITIALIZER
    //----------------------------------------------------------------------------------------------------

    constructor (address __paymentToken,address __treasuryAccount,address __operationManager) Ownable(msg.sender) Pausable(){
        _paymentToken = IERC20(__paymentToken);
        duelCreators[msg.sender] = true;
        _treasuryAccount = __treasuryAccount;
        _operationManager = __operationManager;
    }

    //----------------------------------------------------------------------------------------------------
    //                                           DUELS ADJUSTMENT MANAGER
    //----------------------------------------------------------------------------------------------------

    function changeDuelCreator(address _address, bool _allowed) public onlyOwner {
        duelCreators[_address] = _allowed;
        emit duelCreatorChanged(_address, _allowed);
    }

    function pause()  public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _pause();
    }

    //----------------------------------------------------------------------------------------------------
    //                                           DUELS EMERGENCY PROTOCOL
    //----------------------------------------------------------------------------------------------------

    function emergencyWithdraw(string calldata _title, uint256 _eventDate) public onlyOwner {
       betDuel storage _aux = _checkDuelExistence(_title,_eventDate);

        bool success = _paymentToken.transfer(_treasuryAccount, _aux.unclaimedPrizePool);
        if(!success)
        revert transferDidNotSucceed();

        _aux.releaseReward = pickOpts.none;
        _aux.blockedDuel = true;
        _aux.unclaimedPrizePool = 0;

        emit emergencyBlock(_title,_eventDate);
    }

    //----------------------------------------------------------------------------------------------------
    //                                               DUELS CREATION
    //----------------------------------------------------------------------------------------------------

    function createDuel(betDuelInput calldata _newDuel) public onlyCreator whenNotPaused {
        _checkEmpty(_newDuel.duelTitle);
        _checkEmpty(_newDuel.duelDescription);
        _checkEmpty(_newDuel.eventTitle);
        _checkTimestamp(_newDuel.eventTimestamp);
        _checkTimestamp(_newDuel.deadlineTimestamp);
        _checkCaller(_newDuel.duelCreator);
        require(_newDuel.initialPrizePool >= 100,"Due to underflow you cannot set units less than 100");
        _checkAmount(_newDuel.initialPrizePool);
        _transferAmount(_newDuel.initialPrizePool);

        _populateDuel(_newDuel);
        emit duelCreated(_newDuel.duelTitle, _newDuel.eventTimestamp, _newDuel.initialPrizePool);
    }

    //----------------------------------------------------------------------------------------------------
    //                                             DUELS INCREASE BETS
    //----------------------------------------------------------------------------------------------------

    function betOnDuel(string calldata _title, uint256 _eventDate, pickOpts _option, uint256 _amount) public notBlocked(_title, _eventDate) whenNotPaused{
        betDuel storage _aux = _checkDuelExistence(_title,_eventDate);
        require(block.timestamp <= _aux.deadlineTimestamp, "Bet not possible due to time limit");
        _checkAmount(_amount);
        _transferAmount(_amount);
        _depositPick(_amount,_option,msg.sender,_aux);

        if(_aux.unclaimedPrizePool <= _aux.totalPrizePool && _aux.unclaimedPrizePool != 0){
            bool success = _paymentToken.transfer(_aux.duelCreator, _aux.unclaimedPrizePool);
            if (!success)
            revert transferDidNotSucceed();
            _aux.unclaimedPrizePool = 0;
        }   

        emit duelBet(msg.sender, _amount, _option, _title,_eventDate);

    }

    //----------------------------------------------------------------------------------------------------
    //                                             DUELS CLAIM AMOUNTS
    //----------------------------------------------------------------------------------------------------

    function releaseBet(string calldata _title, uint256 _eventDate, pickOpts _winner) public onlyOwner {
        betDuel storage _aux = _checkDuelExistence(_title,_eventDate);
        require(_aux.eventTimestamp <= block.timestamp,"event did not happen yet");
        if(_aux.totalPrizePool < _aux.unclaimedPrizePool && _aux.totalPrizePool > 0){
            bool success = _paymentToken.transfer(_aux.duelCreator, _aux.totalPrizePool);
            if (!success)
            revert transferDidNotSucceed();
            _aux.totalPrizePool = _aux.unclaimedPrizePool;
        }
        _5percent(_aux);
        _aux.releaseReward = _winner;
        _aux.unclaimedPrizePool = _aux.totalPrizePool;
        emit betClosed(_title, _eventDate, _winner);
    }

    function claimBet(string calldata _title, uint256 _eventDate) notBlocked(_title, _eventDate) public whenNotPaused {
        betDuel storage _aux = _checkDuelExistence(_title,_eventDate);
        require(!_aux.userClaimed[msg.sender],"User already claimed");
        _updateClaim(_aux, msg.sender);

        emit claimedBet(_title, _eventDate, msg.sender);
    }
    //----------------------------------------------------------------------------------------------------
    //                                         MANAGEMENT SETTER FUNCTIONS
    //----------------------------------------------------------------------------------------------------

    function changeTreasury(address _treasury) public onlyOwner{
        _treasuryAccount = _treasury;
    }
    
    function changeOperations(address _operation) public onlyOwner{
        _operationManager = _operation;
    }
    function changePayment(address _payment) public onlyOwner{
        _paymentToken = IERC20(_payment);
    }

    //----------------------------------------------------------------------------------------------------
    //                                             GETTER FUNCTIONS
    //----------------------------------------------------------------------------------------------------
    function getReleaseReward(string memory _title, uint256 _timestamp) public view returns(pickOpts){
        bytes32 _id = keccak256(abi.encode(_timestamp,_title));
        return duels[_id].releaseReward;
    }
    function getBlockedDuel(string memory _title, uint256 _timestamp) public view returns(bool){
        bytes32 _id = keccak256(abi.encode(_timestamp,_title));
        return duels[_id].blockedDuel;
    }
    function getDuelTitleAndDescrition(string memory _title, uint256 _timestamp) public view returns(string memory,string memory,string memory){
        bytes32 _id = keccak256(abi.encode(_timestamp,_title));
        return (duels[_id].duelTitle,duels[_id].duelDescription,duels[_id].eventTitle);
    }
    function getTimestamps(string memory _title, uint256 _timestamp) public view returns(uint256,uint256){
        bytes32 _id = keccak256(abi.encode(_timestamp,_title));
        return (duels[_id].eventTimestamp,duels[_id].deadlineTimestamp);
    }
    function getPrizes(string memory _title, uint256 _timestamp) public view returns(uint256,uint256,uint256,uint256,uint256){
        bytes32 _id = keccak256(abi.encode(_timestamp,_title));
        return (duels[_id].totalPrizePool,duels[_id].opt1PrizePool,duels[_id].opt2PrizePool,duels[_id].opt3PrizePool,duels[_id].unclaimedPrizePool);
    }
    function getCreator(string memory _title, uint256 _timestamp) public view returns(address){
        bytes32 _id = keccak256(abi.encode(_timestamp,_title));
        return (duels[_id].duelCreator);
    }
    function getUserClaimed(string memory _title, uint256 _timestamp,address _user) public view returns(bool){
        bytes32 _id = keccak256(abi.encode(_timestamp,_title));
        return (duels[_id].userClaimed[_user]);
    }
    function getUserDeposits(string memory _title, uint256 _timestamp,address _user) public view returns(uint256,uint256,uint256){
        bytes32 _id = keccak256(abi.encode(_timestamp,_title));
        return (duels[_id].userDeposits[_user]._amountOp1,duels[_id].userDeposits[_user]._amountOp2,duels[_id].userDeposits[_user]._amountOp3);
    }

    //----------------------------------------------------------------------------------------------------
    //                                             INTERNAL AUXILIAR
    //----------------------------------------------------------------------------------------------------

    function _checkEmpty(string memory _str) internal pure {
        if(keccak256(abi.encodePacked(_str)) == keccak256(abi.encodePacked("")))
        revert emptyString();
    }
    function _checkTimestamp(uint256 _timestamp) internal view{
        if(_timestamp < block.timestamp)
        revert eventAlreadyHappened();
    }
    function _checkCaller(address _creator) internal view{
        if(_creator != msg.sender)
        revert callerNotTheCreator();
    }
    function _checkAmount(uint256 _amount) internal view{
        if(_amount == 0)
        revert amountEmpty();

        if(_paymentToken.balanceOf(msg.sender) < _amount)
        revert notEnoughBalance();

        if(_paymentToken.allowance(msg.sender, address(this)) < _amount)
        revert notEnoughAllowance();
    }
    function _checkDuelExistence(string memory _title, uint256 _timestamp) internal view returns(betDuel storage _aux){
        _aux = duels[keccak256(abi.encode(_timestamp,_title))];
        if(keccak256(abi.encodePacked(_aux.duelTitle)) != keccak256(abi.encodePacked(_title)))
        revert duelDoesNotExist();
    }

    function _populateDuel(betDuelInput calldata _newDuel) internal{
        betDuel storage _aux = duels[keccak256(abi.encode(_newDuel.eventTimestamp,_newDuel.duelTitle))];
        _aux.duelTitle = _newDuel.duelTitle;
        _aux.eventTitle = _newDuel.eventTitle;
        _aux.duelDescription = _newDuel.duelDescription;
        _aux.duelCreator = _newDuel.duelCreator;
        _aux.deadlineTimestamp = _newDuel.deadlineTimestamp;
        _aux.eventTimestamp = _newDuel.eventTimestamp;
        _aux.unclaimedPrizePool = _newDuel.initialPrizePool;
    }

    function _transferAmount(uint256 _amount) internal {
        bool success = _paymentToken.transferFrom(msg.sender, address(this), _amount);
        if (!success)
        revert transferDidNotSucceed();
    }
    function _transferUserAmount(uint256 _amount) internal {
        bool success = _paymentToken.transfer(msg.sender, _amount);
        if (!success)
        revert transferDidNotSucceed();
    }

    function _depositPick(uint256 _amount, pickOpts _pick, address sender,betDuel storage _duel) internal{
        if(_pick == pickOpts.opt1){
            _duel.totalPrizePool += _amount;
            _duel.opt1PrizePool += _amount;
            _duel.userDeposits[sender]._amountOp1 += _amount;
        }else if(_pick == pickOpts.opt2){
            _duel.totalPrizePool += _amount;
            _duel.opt2PrizePool += _amount;
            _duel.userDeposits[sender]._amountOp2 += _amount;
        }else if (_pick == pickOpts.opt3){
            _duel.totalPrizePool += _amount;
            _duel.opt3PrizePool += _amount;
            _duel.userDeposits[sender]._amountOp3 += _amount;
        }else if (_pick == pickOpts.none){ //@note THIS OPTIONS DOES NOT INTAKE POINTS
            _duel.totalPrizePool += _amount;
        }else{
            revert pickNotAvailable();
        }
    }

    function _updateClaim(betDuel storage _duel, address _claimer) internal {
        if(_duel.releaseReward == pickOpts.opt1){
            uint256 _payment = (_duel.userDeposits[_claimer]._amountOp1 * _duel.totalPrizePool) / _duel.opt1PrizePool;
            _duel.userClaimed[_claimer] = true;
            _duel.unclaimedPrizePool -= _payment;
            _transferUserAmount(_payment);
        }else if(_duel.releaseReward == pickOpts.opt2){
            uint256 _payment = (_duel.userDeposits[_claimer]._amountOp2 * _duel.totalPrizePool) / _duel.opt2PrizePool;
            _duel.userClaimed[_claimer] = true;
            _duel.unclaimedPrizePool -= _payment;
            _transferUserAmount(_payment);
        }else if (_duel.releaseReward == pickOpts.opt3){
            uint256 _payment = (_duel.userDeposits[_claimer]._amountOp2 * _duel.totalPrizePool) / _duel.opt2PrizePool;
            _duel.userClaimed[_claimer] = true;
            _duel.unclaimedPrizePool -= _payment;
            _transferUserAmount(_payment);            
        }else{
            revert claimNotAvailable();
        }
    }

    function _5percent(betDuel storage _duel) internal{
        uint256 _pay = (_duel.totalPrizePool*300)/10000;
        bool success = _paymentToken.transfer(_treasuryAccount, _pay);
        if (!success)
        revert transferDidNotSucceed();
        _pay = (_duel.totalPrizePool*100)/10000;
        success = _paymentToken.transfer(_operationManager, _pay);
        if (!success)
        revert transferDidNotSucceed();
        _pay = (_duel.totalPrizePool*100)/10000;
        success = _paymentToken.transfer(_duel.duelCreator, _pay);
        if (!success)
        revert transferDidNotSucceed();

        _duel.totalPrizePool -= (_pay*5);
    }
}
