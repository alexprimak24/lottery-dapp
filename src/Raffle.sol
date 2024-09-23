// Layout of the contract file:
// version
// imports
// errors
// interfaces, libraries, contract
// Inside Contract:
// Type declarations
// State variables
// Events
// Modifiers
// Functions
// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions

// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/* 
* @title A sample Raffle contract
* @author Alex Primak
* @notice This contract is for creating a sample raffle
* @dev It implements chainlink VRFv2 and Chainlink Automation
*/
contract Raffle{
    /* Errors */
    error Raffle__SendMoreToEnterRuffle();

    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    /* Events */
    event RaffleEntered(address indexed player);

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enought Eth sent!");
        // require(msg.value >= i_entranceFee, SendMoreToEnterRuffle());
        if(msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRuffle();
        }
        s_players.push(payable(msg.sender));
        //! Smart contracts can't access logs
        // this is how frontend works: we have an even listener for an event to be emitted 
        // for ex tx went through, frontend received an event and updated the state
        //we use events because
        // 1. Makes migration easier
        // 2. Makes front end "indexing" easier
        emit RaffleEntered(msg.sender);
    }
    
    // 1. Get a random number
    // 2. Use random number to pick a player
    // 3, Be automatically called
    function pickWinnder() external {

    }

    /* Getter Function */ 

    function getEntranceFee() external view returns(uint256) {
        return i_entranceFee;
    }


}