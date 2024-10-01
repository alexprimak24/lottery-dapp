// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

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

contract FundSubscribtion is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; //3 LINK

    function fundSubscribtionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        fundSubscribtion(vrfCoordinator,subscriptionId,linkToken);
    }

    function fundSubscribtion(address vrfCoordinator,uint256 subscriptionId,address linkToken)  public {
        console.log("Funding subscribtion: ", subscriptionId);
        console.log("UsingVRFCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);

        if(block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId,FUND_AMOUNT);
            vm.stopBroadcast();
        }
        else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }
    function run() public {
        fundSubscribtionUsingConfig();
    }
}