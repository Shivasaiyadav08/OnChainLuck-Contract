// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import {Script,console2} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {Helperconfig, CodeConstants} from "./Helperconfig.s.sol";
import {AddConsumer, FundSubscription, CreateSubscription} from "./interactions.s.sol";
contract  DeployRaffle is Script , CodeConstants {
    function run() external returns (Raffle, Helperconfig) {
        Helperconfig helperConfig = new Helperconfig();
        Helperconfig.NetworkConfig memory config = helperConfig.getConfig();
        
        AddConsumer addConsumer = new AddConsumer();
        if(config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId,config.vrfCoordinatorV2_5)= createSubscription.createSub(
                config.vrfCoordinatorV2_5,
                config.account
            );
        
           
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSub(
                config.vrfCoordinatorV2_5,
                config.link,
                config.subscriptionId,
                config.account
            );
            helperConfig.setConfig(block.chainid, config);
        }
        console2.log("Chain ID:", block.chainid);
        console2.log("EntranceFee in deployer", config.entranceFee);
        vm.startBroadcast(config.account);
         console2.log("in deploy enterancefee: ",config.entranceFee);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.callbackGasLimit,
            config.gasLane,
            config.subscriptionId,
            config.vrfCoordinatorV2_5
        );
        vm.stopBroadcast();
        addConsumer.addConsumer(
            address(raffle),
            config.vrfCoordinatorV2_5,
            config.subscriptionId,
            config.account
        );
        return (raffle,helperConfig);
    }
}