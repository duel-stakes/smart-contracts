// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.2;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
// import { OApp, Origin, MessagingFee } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

// ///@author Waiandt.eth
// contract senderMessage is OApp,Pausable{

//     //----------------------------------------------------------------------------------------------------
//     //                                               STORAGE
//     //----------------------------------------------------------------------------------------------------

//     mapping (address => bool) public duelCreators;
//     betDuelInput data;
//     address executor;
//     address OAppSender;

//     //----------------------------------------------------------------------------------------------------
//     //                                               ERC20 IDENTIFIER
//     //----------------------------------------------------------------------------------------------------

//     IERC20 _paymentToken;
//     address public _treasuryAccount;
//     address public _operationManager;

//     //----------------------------------------------------------------------------------------------------
//     //                                               STRUCTS
//     //----------------------------------------------------------------------------------------------------

//     struct betDuelInput{
//         string duelTitle;
//         string duelDescription;
//         string eventTitle;
//         uint256 eventTimestamp;
//         uint256 deadlineTimestamp;
//         address duelCreator;
//         uint256 initialPrizePool;
//     }

//     //----------------------------------------------------------------------------------------------------
//     //                                               ERRORS
//     //----------------------------------------------------------------------------------------------------

//     error notAllowedCreator();
//     error nonExistingDuel();
//     error transferDidNotSucceed();
//     error emptyString();
//     error eventAlreadyHappened();
//     error callerNotTheCreator();
//     error amountEmpty();
//     error notEnoughBalance();
//     error notEnoughAllowance();
//     error duelDoesNotExist();
//     error duelIsBlocked();
//     error pickNotAvailable();
//     error claimNotAvailable();

//     //----------------------------------------------------------------------------------------------------
//     //                                               EVENTS
//     //----------------------------------------------------------------------------------------------------

//     event duelCreatorChanged(address indexed _address, bool indexed _allowed);
//     event emergencyBlock(bytes32 indexed _duel);
//     event duelCreated(string indexed _title, uint256 indexed _eventDate, uint256 indexed _openAmount);
//     event claimedBet(string indexed _title, uint256 indexed _eventDate, address indexed _winner);


//     //----------------------------------------------------------------------------------------------------
//     //                                               MODIFIERS
//     //----------------------------------------------------------------------------------------------------

//     modifier onlyCreator(){
//         if(!duelCreators[msg.sender])
//         revert notAllowedCreator();
//         _;
//     }
    
//     //----------------------------------------------------------------------------------------------------
//     //                                           CONSTRUCTOR/INITIALIZER
//     //----------------------------------------------------------------------------------------------------

//     constructor (address __paymentToken,address __treasuryAccount,address __operationManager,address _endpoint) OApp(_endpoint, msg.sender)  Ownable(msg.sender) Pausable(){
//         _paymentToken = IERC20(__paymentToken);
//         duelCreators[msg.sender] = true;
//         _treasuryAccount = __treasuryAccount;
//         _operationManager = __operationManager;
//     }

//     //----------------------------------------------------------------------------------------------------
//     //                                           CROSS CHAIN MESSAGE
//     //----------------------------------------------------------------------------------------------------

//     // Sends a message from the source to destination chain.
//     function send(uint32 _dstEid, bytes memory _payload, bytes calldata _options) public payable {
//         // bytes memory _payload = abi.encode(_message); // Encodes message as bytes.
//         _lzSend(
//             _dstEid, // Destination chain's endpoint ID.
//             _payload, // Encoded message payload being sent.
//             _options, // Message execution options (e.g., gas to use on destination).
//             MessagingFee(msg.value, 0), // Fee struct containing native gas and ZRO token.
//             payable(msg.sender) // The refund address in case the send call reverts.
//         );
//     }

//     /* @dev Quotes the gas needed to pay for the full omnichain transaction.
//      * @return nativeFee Estimated gas fee in native gas.
//      * @return lzTokenFee Estimated gas fee in ZRO token.
//      */
//     function quote(
//         uint32 _dstEid, // Destination chain's endpoint ID.
//         bytes memory _payload, // The message to send.
//         bytes calldata _options, // Message execution options
//         bool _payInLzToken // boolean for which token to return fee in
//     ) public view returns (uint256 nativeFee, uint256 lzTokenFee) {
//         // bytes memory _payload = abi.encode(_message);
//         MessagingFee memory fee = _quote(_dstEid, _payload, _options, _payInLzToken);
//         return (fee.nativeFee, fee.lzTokenFee);
//     }

//     function _lzReceive(
//     Origin calldata _origin, // struct containing info about the message sender
//     bytes32 _guid, // global packet identifier
//     bytes calldata payload, // encoded message payload being received
//     address _executor, // the Executor address.
//     bytes calldata _extraData // arbitrary data appended by the Executor
//     ) internal override {
//         // require(address(uint160(uint256(_origin.sender))) == address(0),"ODuelStakes: Wrong OApp sender");
//         data = abi.decode(payload, (betDuelInput)); // your logic here
//         executor = _executor;
//         OAppSender = address(uint160(uint256(_origin.sender)));
//     }


//     //----------------------------------------------------------------------------------------------------
//     //                                           DUELS ADJUSTMENT MANAGER
//     //----------------------------------------------------------------------------------------------------

//     function changeDuelCreator(address _address, bool _allowed) public onlyOwner {
//         duelCreators[_address] = _allowed;
//         emit duelCreatorChanged(_address, _allowed);
//     }

//     function pause()  public onlyOwner {
//         _pause();
//     }

//     function unpause() public onlyOwner {
//         _pause();
//     }

//     //----------------------------------------------------------------------------------------------------
//     //                                           DUELS EMERGENCY PROTOCOL
//     //----------------------------------------------------------------------------------------------------

//     // function emergencyWithdraw(string calldata _title, uint256 _eventDate) public onlyOwner {
//     // //    betDuel storage _aux = _checkDuelExistence(_title,_eventDate);

//     //     bool success = _paymentToken.transfer(_treasuryAccount, _aux.unclaimedPrizePool);
//     //     if(!success)
//     //     revert transferDidNotSucceed();

//     //     _aux.releaseReward = pickOpts.none;
//     //     _aux.blockedDuel = true;
//     //     _aux.unclaimedPrizePool = 0;

//     //     emit emergencyBlock(keccak256(abi.encode(_eventDate,_title)));
//     // }

//     function getPayload(string memory duelTitle,string memory duelDescription,string memory eventTitle,uint256 eventTimestamp,uint256 deadlineTimestamp,address duelCreator,uint256 initialPrizePool)public returns(bytes memory){
//         betDuelInput memory _aux = betDuelInput({
//          duelTitle: duelTitle,
//          duelDescription: duelDescription,
//          eventTitle: eventTitle,
//          eventTimestamp: eventTimestamp,
//          deadlineTimestamp: deadlineTimestamp,
//          duelCreator: duelCreator,
//          initialPrizePool: initialPrizePool
//         });

//         return abi.encode(_aux);
//     }

//     //----------------------------------------------------------------------------------------------------
//     //                                               DUELS CREATION
//     //----------------------------------------------------------------------------------------------------

//     function createDuel(betDuelInput calldata _newDuel,uint32 _dstEid,bytes calldata _options) public onlyCreator whenNotPaused {
//         _checkEmpty(_newDuel.duelTitle);
//         _checkEmpty(_newDuel.duelDescription);
//         _checkEmpty(_newDuel.eventTitle);
//         _checkTimestamp(_newDuel.eventTimestamp);
//         _checkTimestamp(_newDuel.deadlineTimestamp);
//         _checkCaller(_newDuel.duelCreator);
//         require(_newDuel.initialPrizePool >= 100,"Due to underflow you cannot set units less than 100");
//         _checkAmount(_newDuel.initialPrizePool);
//         _transferAmount(_newDuel.initialPrizePool);
//         bytes memory _payload = abi.encode(_newDuel);
//         send(_dstEid, _payload, _options);
        
//         emit duelCreated(_newDuel.duelTitle, _newDuel.eventTimestamp, _newDuel.initialPrizePool);
//     }

//     //----------------------------------------------------------------------------------------------------
//     //                                             DUELS INCREASE BETS
//     //----------------------------------------------------------------------------------------------------

//     // function betOnDuel(string calldata _title, uint256 _eventDate, pickOpts _option, uint256 _amount) public notBlocked(_title, _eventDate) whenNotPaused{
//         // betDuel storage _aux = _checkDuelExistence(_title,_eventDate);
//         // require(block.timestamp <= _aux.deadlineTimestamp, "Bet not possible due to time limit");
//         // _checkAmount(_amount);
//         // _transferAmount(_amount);
//         // _depositPick(_amount,_option,msg.sender,_aux);

//         // if(_aux.unclaimedPrizePool <= _aux.totalPrizePool && _aux.unclaimedPrizePool != 0){
//         //     bool success = _paymentToken.transfer(_aux.duelCreator, _aux.unclaimedPrizePool);
//         //     if (!success)
//         //     revert transferDidNotSucceed();
//         //     _aux.unclaimedPrizePool = 0;
//         // }

//         // emit duelBet(msg.sender, _amount, _option, keccak256(abi.encode(_eventDate,_title)));

//     // }

//     //----------------------------------------------------------------------------------------------------
//     //                                             DUELS CLAIM AMOUNTS
//     //----------------------------------------------------------------------------------------------------

//     // function releaseBet(string calldata _title, uint256 _eventDate, pickOpts _winner) public onlyOwner {
//         // betDuel storage _aux = _checkDuelExistence(_title,_eventDate);
//         // require(_aux.eventTimestamp <= block.timestamp,"event did not happen yet");
//         // if(_aux.totalPrizePool < _aux.unclaimedPrizePool && _aux.totalPrizePool > 0){
//         //     bool success = _paymentToken.transfer(_aux.duelCreator, _aux.totalPrizePool);
//         //     if (!success)
//         //     revert transferDidNotSucceed();
//         //     _aux.totalPrizePool = _aux.unclaimedPrizePool;
//         // }
//         // _5percent(_aux);
//         // _aux.releaseReward = _winner;
//         // _aux.unclaimedPrizePool = _aux.totalPrizePool;
//     //     emit betClosed(_title, _eventDate, _winner);
//     // }

//     // function claimBet(string calldata _title, uint256 _eventDate) notBlocked(_title, _eventDate) public whenNotPaused {
//         // betDuel storage _aux = _checkDuelExistence(_title,_eventDate);
//         // require(!_aux.userClaimed[msg.sender],"User already claimed");
//         // _updateClaim(_aux, msg.sender);

//     //     emit claimedBet(_title, _eventDate, msg.sender);
//     // }
//     //----------------------------------------------------------------------------------------------------
//     //                                         MANAGEMENT SETTER FUNCTIONS
//     //----------------------------------------------------------------------------------------------------

//     function changeTreasury(address _treasury) public onlyOwner{
//         _treasuryAccount = _treasury;
//     }
    
//     function changeOperations(address _operation) public onlyOwner{
//         _operationManager = _operation;
//     }
//     function changePayment(address _payment) public onlyOwner{
//         _paymentToken = IERC20(_payment);
//     }


//     //----------------------------------------------------------------------------------------------------
//     //                                             INTERNAL AUXILIAR
//     //----------------------------------------------------------------------------------------------------

//     function _checkEmpty(string memory _str) internal pure {
//         if(keccak256(abi.encodePacked(_str)) == keccak256(abi.encodePacked("")))
//         revert emptyString();
//     }
//     function _checkTimestamp(uint256 _timestamp) internal view{
//         if(_timestamp < block.timestamp)
//         revert eventAlreadyHappened();
//     }
//     function _checkCaller(address _creator) internal view{
//         if(_creator != msg.sender)
//         revert callerNotTheCreator();
//     }
//     function _checkAmount(uint256 _amount) internal view{
//         if(_amount == 0)
//         revert amountEmpty();

//         if(_paymentToken.balanceOf(msg.sender) < _amount)
//         revert notEnoughBalance();

//         if(_paymentToken.allowance(msg.sender, address(this)) < _amount)
//         revert notEnoughAllowance();
//     }

//     function _transferAmount(uint256 _amount) internal {
//         bool success = _paymentToken.transferFrom(msg.sender, address(this), _amount);
//         if (!success)
//         revert transferDidNotSucceed();
//     }
//     function _transferUserAmount(uint256 _amount) internal {
//         bool success = _paymentToken.transfer(msg.sender, _amount);
//         if (!success)
//         revert transferDidNotSucceed();
//     }

//     // function _depositPick(uint256 _amount, pickOpts _pick, address sender,betDuel storage _duel) internal{
//         // if(_pick == pickOpts.opt1){
//         //     _duel.totalPrizePool += _amount;
//         //     _duel.opt1PrizePool += _amount;
//         //     _duel.userDeposits[sender]._amountOp1 += _amount;
//         // }else if(_pick == pickOpts.opt2){
//         //     _duel.totalPrizePool += _amount;
//         //     _duel.opt2PrizePool += _amount;
//         //     _duel.userDeposits[sender]._amountOp2 += _amount;
//         // }else if (_pick == pickOpts.opt3){
//         //     _duel.totalPrizePool += _amount;
//         //     _duel.opt3PrizePool += _amount;
//         //     _duel.userDeposits[sender]._amountOp3 += _amount;
//         // }else if (_pick == pickOpts.none){ //@note THIS OPTIONS DOES NOT INTAKE POINTS
//         //     _duel.totalPrizePool += _amount;
//         // }else{
//         //     revert pickNotAvailable();
//         // }
//     // }

//     // function _updateClaim(betDuel storage _duel, address _claimer) internal {
//         // if(_duel.releaseReward == pickOpts.opt1){
//         //     uint256 _payment = (_duel.userDeposits[_claimer]._amountOp1 * _duel.totalPrizePool) / _duel.opt1PrizePool;
//         //     _duel.userClaimed[_claimer] = true;
//         //     _duel.unclaimedPrizePool -= _payment;
//         //     _transferUserAmount(_payment);
//         // }else if(_duel.releaseReward == pickOpts.opt2){
//         //     uint256 _payment = (_duel.userDeposits[_claimer]._amountOp2 * _duel.totalPrizePool) / _duel.opt2PrizePool;
//         //     _duel.userClaimed[_claimer] = true;
//         //     _duel.unclaimedPrizePool -= _payment;
//         //     _transferUserAmount(_payment);
//         // }else if (_duel.releaseReward == pickOpts.opt3){
//         //     uint256 _payment = (_duel.userDeposits[_claimer]._amountOp2 * _duel.totalPrizePool) / _duel.opt2PrizePool;
//         //     _duel.userClaimed[_claimer] = true;
//         //     _duel.unclaimedPrizePool -= _payment;
//         //     _transferUserAmount(_payment);            
//         // }else{
//         //     revert claimNotAvailable();
//         // }
//     // }

//     // function _5percent(betDuel storage _duel) internal{
//         // uint256 _pay = (_duel.totalPrizePool*300)/10000;
//         // bool success = _paymentToken.transfer(_treasuryAccount, _pay);
//         // if (!success)
//         // revert transferDidNotSucceed();
//         // _pay = (_duel.totalPrizePool*100)/10000;
//         // success = _paymentToken.transfer(_operationManager, _pay);
//         // if (!success)
//         // revert transferDidNotSucceed();
//         // _pay = (_duel.totalPrizePool*100)/10000;
//         // success = _paymentToken.transfer(_duel.duelCreator, _pay);
//         // if (!success)
//         // revert transferDidNotSucceed();

//         // _duel.totalPrizePool -= (_pay*5);
//     // }
// }
