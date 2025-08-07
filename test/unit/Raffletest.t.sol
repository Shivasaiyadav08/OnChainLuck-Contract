// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import {Test,console2} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Helperconfig} from "../../script/Helperconfig.s.sol";
import {LinkToken} from "../mocks/LinkToken.sol";
import {CodeConstants} from "../../script/Helperconfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";
contract Raffletest is Test, CodeConstants {
    Raffle public raffle;
    Helperconfig public helperConfig;
   


    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 interval;
    uint256 entranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    LinkToken link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() public {
         DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
         
        vm.deal(PLAYER, STARTING_USER_BALANCE);
       Helperconfig.NetworkConfig memory config = helperConfig.getConfig();
       console2.log("in setup tes :",config.entranceFee);
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        interval = config.interval;
        entranceFee = config.entranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        link=LinkToken(config.link);
        
        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subscriptionId, LINK_BALANCE);
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();
       
    }
    modifier ClosingRaffle(){
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
        vm.warp(block.timestamp + interval+ 1);
        vm.roll(block.number + 1);
        _;
    }
    function testCannotEnterRaffleWithInsufficientFunds() public {
       vm.startPrank(PLAYER);
       vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
       raffle.enterRaffle();
         vm.stopPrank();
    }
    function testenterRaffle() public{
        vm.startPrank(PLAYER);
        console2.log("Player address:", PLAYER);
        console2.log("Raffle address:", address(raffle));
        console2.log("Entrance fee:", entranceFee);
        console2.log("Player balance before:", PLAYER.balance);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
        assertEq(raffle.getPlayer(0), PLAYER);
    }
    function testRaffleStateIsOpenInatitially() public {
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
    }
    function testEmitEventOnEntrance() public{
        vm.startPrank(PLAYER);
        vm.expectEmit(true, false, false, false,address(raffle));
        emit Raffle.RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
    }

    function testDontAllowEntranceWhenCaluclating() public ClosingRaffle{
        vm.startPrank(PLAYER);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECKUPKEEP
    //////////////////////////////////////////////////////////////*/

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

function testCheckUpKeepReturnsFalseIfRaffleIsnotOpen() public ClosingRaffle{
       Raffle.RaffleState raffleState = raffle.getRaffleState();
       raffle.performUpkeep("");
       (bool upkeepNeeded,)=raffle.checkUpkeep("");
         assert(!upkeepNeeded);
       
}
function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    
    function testCheckUpkeepReturnsTrueWhenParametersGood() public ClosingRaffle{

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }
    //////////////////////////////////////////////////////////////
                      //   FULFILLRANDOMWORDS //
    //////////////////////////////////////////////////////////////*/

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public ClosingRaffle {
        // Arrange
        // Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(0, address(raffle));

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(1, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public    ClosingRaffle {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
