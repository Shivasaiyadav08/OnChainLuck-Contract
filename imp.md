# Automation 
  Automation in Chainlink lets your smart contract run functions automatically without you manually calling them.
  The two key functions are:
  ## checkUpkeep
 1. Purpose: To see if some condition is true for performing a task.
 2. It doesn’t actually change the blockchain — just checks if an update is needed.
 3. Returns a boolean (upkeepNeeded) and any data (performData) that may be needed for the next step.
   ## performUpkeep
 1. Purpose: Actually performs the task if checkUpkeep says it’s needed.
 2. Costs gas because it changes the blockchain.

# VRFV2PlusClient
  VRFV2PlusClient is a smart contract that asks Chainlink VRF v2.5 for random numbers
## Chainlink VRF ensures the random numbers are:
1. Unbiased → No one can influence the outcome.
2. Verifiable → Proof is published on-chain.
3. Secure → Attackers can’t predict or manipulate the randomness.
## Working
 1. Create a VRF Subscription
   You (the contract owner) go to Chainlink VRF and create a subscription.
   You fund it with LINK tokens (or sometimes native ETH/MATIC depending on the chain).
   This subscription pays for your randomness requests.
2. Add Your Contract as a Consumer
  The VRF subscription has a list of approved consumer contracts.
  Only those contracts can request randomness using that subscription.
  This prevents strangers from draining your LINK.
  Your VRFV2PlusClient must be added there.
3. Your Contract Requests Randomness

 ```
requestId = COORDINATOR.requestRandomWords(
    keyHash,            // VRF key (defines gas price & speed)
    subscriptionId,     // your funded subscription ID
    requestConfirmations, // how many block confirmations before returning result
    callbackGasLimit,   // gas provided for the callback function
    numWords            // how many random numbers you want
);
1. keyHash: i_gasLane
A unique ID for the VRF key pair used to generate randomness.

Different keyHashes correspond to different gas lanes (which affect speed & cost).

2. subId: i_subscriptionId
Your VRF subscription ID.

The one you created and funded with LINK or ETH.

Ensures the request uses your balance.

3. requestConfirmations: REQUEST_CONFIRMATIONS
How many block confirmations VRF waits before fulfilling the request.

More confirmations = more secure (less chance of manipulation), but slower.

4. callbackGasLimit: i_callbackGasLimit
The maximum gas that VRF will supply when calling your fulfillRandomWords() function.

Must be high enough to cover whatever logic you put inside.

5. numWords: NUM_WORDS
The number of random numbers you want in one request.

Example: 1 for a dice roll, 3 for a random card draw, etc.

6. extraArgs
Additional settings for how you want to pay.


extraArgs: VRFV2PlusClient._argsToBytes(
    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
)

Converts the settings into bytes (because VRF requires it).

nativePayment: false → you’re paying in LINK.

If true → you’d pay in the blockchain’s native token (e.g., Sepolia ETH).


```


   ```
   You → create & fund subscription
   You → add your contract as a consumer
   Your contract → calls requestRandomWords()
   VRF Coordinator → verifies request & sends randomness back
   Your contract → gets result in fulfillRandomWords()
   ```
 # VRFConsumerBaseV2Plus
   It’s a base contract provided by Chainlink that your contract inherits from when you want to use VRF v2.5 random numbers.
   VRFConsumerBaseV2Plus is a special helper contract from Chainlink that you attach to your own contract so it can safely get random numbers.
   ## 📌 Why It’s Important
   
   1. Security

     If you just made a normal function like this:
    ```
    function getRandom(uint256[] memory randomWords) public {
       // do something
    }
   ```
   anyone could call it and pass in fake numbers.
   VRFConsumerBaseV2Plus makes sure only the official Chainlink VRF Coordinator can call your fulfillRandomWords.

2. Connection to VRF Coordinator

   The base contract wires your consumer contract to the correct VRF Coordinator address on your blockchain.
   Without it, your contract wouldn’t know who to trust for randomness.

3. Callback Setup

   The base contract defines the fulfillRandomWords function you must override.
   That’s the “mailbox” where Chainlink delivers your random numbers.



# VvrfCoordinatorV2_5
Address of the Chainlink VRF Coordinator contract on localenvironment
This is the contract that receives randomness requests from your contract and returns verifiable random numbers.


