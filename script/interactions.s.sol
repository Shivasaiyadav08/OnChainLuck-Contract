//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {Raffle} from "../src/Raffle.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {Script,console2} from "forge-std/Script.sol";
import {Helperconfig,CodeConstants} from "./Helperconfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract CreateSubscription is Script, CodeConstants {
    function run() public returns(uint256,address) {
      return  createSubscriptionUsingConfig();
    }
    function createSubscriptionUsingConfig() public returns (uint256,address) {
        Helperconfig helperConfig = new Helperconfig();
        address vrfCoordinatorV2_5 = helperConfig.getConfigByChainID(block.chainid).vrfCoordinatorV2_5;
        address account = helperConfig.getConfigByChainID(block.chainid).account;
        return createSub(vrfCoordinatorV2_5, account);
    }
    function createSub(address vrfCoordinatorV2_5, address account) public returns (uint256,address) {
        console2.log("Creating subscription on ChainID: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).createSubscription();
        console2.log("Created subscription with ID: ", subId);
        vm.stopBroadcast();
        return (subId,vrfCoordinatorV2_5);
    }
 

}
contract AddConsumer is Script, CodeConstants {
    function run() external {
        address mostRecentRaffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentRaffle);
    }
     function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        Helperconfig helperConfig = new Helperconfig();
        uint256 subId = helperConfig.getConfigByChainID(block.chainid).subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfigByChainID(block.chainid).vrfCoordinatorV2_5;
        address account = helperConfig.getConfigByChainID(block.chainid).account;

        addConsumer(mostRecentlyDeployed, vrfCoordinatorV2_5, subId, account);
    }
    function addConsumer(
        address mostRecentlyDeployed,
        address vrfCoordinatorV2_5,
        uint256 subId,
        address account
    ) public {
        console2.log("Adding consumer to subscription: ", subId);
        console2.log("Using vrfCoordinator: ", vrfCoordinatorV2_5);
        console2.log("On ChainID: ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).addConsumer(subId, mostRecentlyDeployed);
        vm.stopBroadcast();
    }
   
}

contract FundSubscription is Script ,CodeConstants{
    uint256 public constant FUND_AMOUNT = 3 ether;
    function run() external {
        fundSubscriptionUsingConfig();
    }
    function fundSubscriptionUsingConfig() public {
        Helperconfig helperConfig = new Helperconfig();
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinatorV2_5;
        address link = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        
        if (subId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (uint256 updatedSubId, address updatedVRFv2) = createSub.run();
            subId = updatedSubId;
            vrfCoordinatorV2_5 = updatedVRFv2;
            console2.log("New SubId Created! ", subId, "VRF Address: ", vrfCoordinatorV2_5);
        }
        fundSub(vrfCoordinatorV2_5, link, subId, account);
    }
    function fundSub(address vrfCoordinatorV2_5, address link, uint256 subId, address account) public {
         console2.log("Funding subscription: ", subId);
        console2.log("Using vrfCoordinator: ", vrfCoordinatorV2_5);
        console2.log("On ChainID: ", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subId, FUND_AMOUNT * 100);
            vm.stopBroadcast();
        } else {
            console2.log(LinkToken(link).balanceOf(msg.sender));
            console2.log(msg.sender);
            console2.log(LinkToken(link).balanceOf(address(this)));
            console2.log(address(this));
// transferAndCall is a LINK-specific function (from ERC677).
// It transfers LINK to the VRF Coordinator and calls its fallback to credit your subscription.
// The last argument abi.encode(subId) tells the coordinator which subscription ID you want to fund.
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(vrfCoordinatorV2_5, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
    }
}
}