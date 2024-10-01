// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract CreateSubscription is Script {
    function createSubscribtionUsingConfig() public returns(uint256,address){
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;

        //create subscription...
        (uint256 subId, ) = createSubscription(vrfCoordinator);
        return (subId,vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns(uint256,address){
        console.log("Creating subscribtion on chain Id: ", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscribtion ID is: ", subId);
        console.log("Please update the subscribtion Id in your HelperConfig.s.sol");
        return (subId,vrfCoordinator);
    }
    function run() public {
        createSubscribtionUsingConfig();
    }
}