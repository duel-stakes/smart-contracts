// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

///@author Waiandt.eth

interface IDuelStakes{

    ///@dev This is the struct that stores all bets
    ///@param releaseReward The reward to be released, opt1/2/3
    ///@param blockedDuel If something happens and the duel has to be blocked in an emergency
    ///@param duelTitle The title of the duel
    ///@param duelDescription The description of the duel
    ///@param eventTitle The title of the event
    ///@param eventTimestamp The date of the event
    ///@param deadlineTimestamp The deadline to bet on the duel
    ///@param duelCreator The duel creator to receive the 1%
    ///@param totalPrizePool Total prize pool of the duel
    ///@param opt1PrizePool Total prize pool of the opt 1
    ///@param opt2PrizePool Total prize pool of the opt 2
    ///@param opt3PrizePool Total prize pool of the opt 3
    ///@param unclaimedPrizePool Used as "Guaranteed prize" when the bet is not finished and as Unclaimed funds when duel is over
    ///@param userClaimed Map to show if the user has taken the reward
    ///@param userDeposits Map to see how much and in which option the user bet on
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

    ///@dev This is the struct that is used to CREATE bets
    ///@param duelTitle The title of the duel
    ///@param duelDescription The description of the duel
    ///@param eventTitle The title of the event
    ///@param eventTimestamp The date of the event
    ///@param deadlineTimestamp The deadline to bet on the duel
    ///@param duelCreator The duel creator to receive the 1%
    ///@param initialPrizePool Guaranteed prize pool
    struct betDuelInput{
        string duelTitle;
        string duelDescription;
        string eventTitle;
        uint256 eventTimestamp;
        uint256 deadlineTimestamp;
        address duelCreator;
        uint256 initialPrizePool;
    }

    ///@dev This is the struct that is used to store amounts the players bet
    ///@param _amountOp1 The amount of option 1
    ///@param _amountOp2 The amount of option 2
    ///@param _amountOp3 The amount of option 3
    struct deposit {
        uint256 _amountOp1;
        uint256 _amountOp2;
        uint256 _amountOp3;
    }

    ///@dev This is the struct that is used to store the winner of the duel
    ///@param none When no one can claim
    ///@param opt1 Option 1 won and can claim
    ///@param opt2 Option 2 won and can claim
    ///@param opt3 Option 3 won and can claim
    enum pickOpts {
        none,
        opt1,
        opt2,
        opt3
    }

    ///@dev This is the function that changes the permission of an address
    ///@notice Only the owner of the contract can interact
    ///@param _address this is the address that the permission will change
    ///@param _allowed This is the new status
    function changeDuelCreator(address _address, bool _allowed) external;

    ///@dev Function used to pause the contract interactions
    ///@notice Only the owner of the contract can interact
    function pause()  external;
    
    ///@dev Function used to unpause the contract interactions
    ///@notice Only the owner of the contract can interact
    function unpause()  external;
    
    ///@dev This is the function that blocks a duel in an emergency case
    ///@notice Only the owner of the contract can interact
    ///@param _title The title of the duel
    ///@param _eventDate The date in unix timestamp of the duel
    function emergencyWithdraw(string calldata _title, uint256 _eventDate) external;
    
    ///@dev This is the function that creates a duel
    ///@notice Only permissioned duel creators can interact
    ///@param _newDuel The betDuelInput struct to populate a new duel
    function createDuel(betDuelInput calldata _newDuel) external;

    ///@dev This is the function that allows users to bet on duels
    ///@notice The user has to `approve` the duelStakes contract to move the `amount` they're betting
    ///@param _title The title of the duel
    ///@param _eventDate The date in unix timestamp of the duel
    ///@param _option The option 1/2/3 the user wants to bet
    ///@param _amount The amount the user wants to bet
    function betOnDuel(string calldata _title, uint256 _eventDate, pickOpts _option, uint256 _amount) external;

    ///@dev This is the function that releases the bet
    ///@notice Only the owner of the contract can interact
    ///@param _title The title of the duel
    ///@param _eventDate The date in unix timestamp of the duel
    ///@param _winner The option 1/2/3 that won
    function releaseBet(string calldata _title, uint256 _eventDate, pickOpts _winner) external;

    ///@dev This is the function to claim the bet once the duel is over
    ///@param _title The title of the duel
    ///@param _eventDate The date in unix timestamp of the duel
    function claimBet(string calldata _title, uint256 _eventDate) external;

    ///@dev This is the function that changes the Treasury account of the project to receive funds
    ///@notice Only the owner of the contract can interact
    ///@param _treasury The new address of the treasury
    function changeTreasury(address _treasury) external;

    ///@dev This is the function that changes the operation account of the project to receive funds
    ///@notice Only the owner of the contract can interact
    ///@param _operation The new address of the operation manager
    function changeOperations(address _operation) external;

    ///@dev This is the function that changes the payment token of the duelStakes
    ///@notice Only the owner of the contract can interact
    ///@param _payment The new address of the payment token
    function changePayment(address _payment) external;

    ///@dev This is the function that returns the reward of a duel
    ///@param _title The title of the duel
    ///@param _timestamp The date in unix timestamp of the duel
    ///@return pickOpts The option returned
    function getReleaseReward(string memory _title, uint256 _timestamp) external returns(pickOpts);

    ///@dev This is the function that returns if a duel is blocked
    ///@param _title The title of the duel
    ///@param _timestamp The date in unix timestamp of the duel
    ///@return bool Blocked status
    function getBlockedDuel(string memory _title, uint256 _timestamp) external returns(bool);

    ///@dev This is the function that returns the titles and description of the duel
    ///@param _title The title of the duel
    ///@param _timestamp The date in unix timestamp of the duel
    ///@return string,string,string -> duelTitle,duelDescription,eventTitle
    function getDuelTitleAndDescrition(string memory _title, uint256 _timestamp) external returns(string memory,string memory,string memory);
    
    ///@dev This is the function that returns the timestamps of the duel
    ///@param _title The title of the duel
    ///@param _timestamp The date in unix timestamp of the duel
    ///@return uint256,uint256 -> when the duel is happening, deadline to bet on duel
    function getTimestamps(string memory _title, uint256 _timestamp) external returns(uint256,uint256);

    ///@dev This is the function that returns the prizes of the duel
    ///@param _title The title of the duel
    ///@param _timestamp The date in unix timestamp of the duel
    ///@return uint256,uint256,uint256,uint256,uint256 -> total prize pool, option 1 total, option 2 total, option 3 total, unclaimed pool
    function getPrizes(string memory _title, uint256 _timestamp) external returns(uint256,uint256,uint256,uint256,uint256); 

    ///@dev This is the function that returns the creator of the duel
    ///@param _title The title of the duel
    ///@param _timestamp The date in unix timestamp of the duel
    ///@return address -> address of the creator
    function getCreator(string memory _title, uint256 _timestamp) external returns(address);

    ///@dev This is the function that returns if the user has already claimed
    ///@param _title The title of the duel
    ///@param _timestamp The date in unix timestamp of the duel
    ///@return bool -> status of the claim (true = claimed / false = unclaimed)
    function getUserClaimed(string memory _title, uint256 _timestamp,address _user) external returns(bool);

    ///@dev This is the function that returns the amounts deposited by a used on a specific bet
    ///@param _title The title of the duel
    ///@param _timestamp The date in unix timestamp of the duel
    ///@return uint256,uint256,uint256 -> amount on option 1, amount on option 2, amount on option 3
    function getUserDeposits(string memory _title, uint256 _timestamp,address _user) external returns(uint256,uint256,uint256);



}