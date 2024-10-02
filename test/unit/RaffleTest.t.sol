// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract Raffletest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    ///@dev create player to interact with contract
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
    }

    function testRaffleInitializedInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function testRaffleRevertsWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(PLAYER);
        //Act / Asset
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRuffle.selector);
        raffle.enterRaffle();
        //Asset
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        //Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        //Act / Asset
        raffle.enterRaffle{value: entranceFee}();
        //Asset
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        //Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        //Act
        //true only for the first, as we have only 1 indexed element in our emit
        //4th true is for data
        //we are saying that we are expecting to emit an event
        vm.expectEmit(true,false,false,false, address(raffle));
        //this is an event that we are going to emit
        emit RaffleEntered(PLAYER);
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        //Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        //we imitated that needed time passed
        vm.warp(block.timestamp + interval + 1);
        //this will emulate that new block also been changed
        vm.roll(block.number + 1);
        //so for 2 commands above - we emulated that the time has passed so it is better to
        //also emulate that new block also been added after that time

        //inside performUpkeep we set that we are going to set the ruffle status calculating
        raffle.performUpkeep("");

        //Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECKUPKEEP
    //////////////////////////////////////////////////////////////*/

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        //we imitated that needed time passed
        vm.warp(block.timestamp + interval + 1);
        //this will emulate that new block also been changed
        vm.roll(block.number + 1);

        // Act
        //in Raffle.sol: upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        //Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        //we enter the raffle
        raffle.enterRaffle{value: entranceFee}();
        //we change block time
        vm.warp(block.timestamp + interval + 1);
        //we add a new block
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // Act
        //in Raffle.sol: upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        //this should revert because of isOpen
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(!upkeepNeeded);
    }

    // Challenge - add more test
    // testCheckUpkeepReturnsFalseIfEnoughTimeHasPassed
    // testCheckUpkeepReturnsTrueWhenParametersAreGood
    // etc....

    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        //Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        //we enter the raffle
        raffle.enterRaffle{value: entranceFee}();
        //we change block time
        vm.warp(block.timestamp + interval + 1);
        //we add a new block
        vm.roll(block.number + 1);

        //Act / Assert
        //it actually tests, if this function reverts -> test will fail
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        //Arrage 
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        //Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers,rState)
        );
        raffle.performUpkeep("");
    }
    
}
