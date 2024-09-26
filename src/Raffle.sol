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

import {VRFV2PlusClient} from "chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

import {VRFConsumerBaseV2Plus} from "chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
/* 
* @title A sample Raffle contract
* @author Alex Primak
* @notice This contract is for creating a sample raffle
* @dev It implements chainlink VRFv2 and Chainlink Automation
*/

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRuffle();
    error Raffle__NotEnoughTime();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();

    /* Type Declarations */
    enum RaffleState {
        OPEN, //0
        CALCULATING //1

    }

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscribtionId;
    // @dev The duration of the lottery in seconds
    uint256 private immutable i_interval;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscribtionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        // @dev when we deploy contract we set lastTimeStapt to the latest timestamp for now
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enought Eth sent!");
        // require(msg.value >= i_entranceFee, SendMoreToEnterRuffle());
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRuffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
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
        // check to see if enought time has passsed

        // 1000 - 900 = 100
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert Raffle__NotEnoughTime();
        }
        s_raffleState = RaffleState.CALCULATING;
        // Get our random number from Chainlink
        // 1. Request RNG
        // 2. Get RNF
        //there we create a struct
        //we set it to memory as this data should be removed once we execute the function.
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscribtionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });
        //and then here we are pasting a struct to requestRandomWords
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        //s_player = 10
        //rng = 12
        //12 % 10 = 2 <-
        //in reality random word will be something like 2348937589375256423423 % 10 = 3 <- winner
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /* Getter Function */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
