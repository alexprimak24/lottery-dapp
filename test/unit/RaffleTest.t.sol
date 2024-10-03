// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";

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

    modifier raffleEntered() {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        //we enter the raffle
        raffle.enterRaffle{value: entranceFee}();
        //we change block time
        vm.warp(block.timestamp + interval + 1);
        //we add a new block
        vm.roll(block.number + 1);
        _;
    }

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
        vm.expectEmit(true, false, false, false, address(raffle));
        //this is an event that we are going to emit
        emit RaffleEntered(PLAYER);
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        //I LEAVE IT AS IT IS AS THERE I EXPLAINED THE STEPS BUT IN FUTURE USE MODIFIER
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

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public raffleEntered {
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
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEntered {
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
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }

    //What if we need to get data from emitted events in our tests?
    function testPerfromUpkeepUpdatesRaffleStateAndEmitsRequestedId() public raffleEntered {
        // Act
        //this line will record of all the logs that performUpkeep emits
        vm.recordLogs();
        raffle.performUpkeep("");
        //this line will take all the recorded logs and stick it to entries array
        Vm.Log[] memory entries = vm.getRecordedLogs();
        //topics[0] - usually reserved for something else
        //entries[0] - is emit from VRF, but we need emit from our contract
        //so we recorded it
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        //so we make sure that our requestId is not zero
        assert(uint256(requestId) > 0);
        //and me make sure raffle state is CALCULATING as while calling perfromUpkeep
        //we set that status
        assert(uint256(raffleState) == 1);
    }

    /*//////////////////////////////////////////////////////////////
                           FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/
    //this is called fuzz test, we set that as a parameter of our fulfillRandomWords
    //we are going to paste value from function input, and once we wrote forge test
    //it runned and tried to break our test (by default 256 times).
    /**  @notice in foundry.toml you may manually write how much times your test would run
     *  [fuzz]
     *  runs = 1000 
    */
    function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered {
        // Arrange / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillrandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered {
        //raffleEntered - with that we already have a player
        
        // Arrange
        uint256 additionalEntrants = 3; // 4 overall with raffleEntered
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i)); //this is like some cheaty way to convert any number to an address
            //this does vm.prank and vm.deal - so it emulates and funds a new wallet
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;
        
        // Act
        vm.recordLogs();
        //this is going to kick off chainlinkVRF
        raffle.performUpkeep("");
        //this line will take all the recorded logs and stick it to entries array
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        //simulating getting random number back
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        vm.warp(block.timestamp + interval + 1);
        //this will emulate that new block also been changed
        vm.roll(block.number + 1);

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize); 
        assert(endingTimeStamp > startingTimeStamp);
    }
}
