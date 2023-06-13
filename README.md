# Level Brigde tokens based on layerzero stack

 ### Install & Run tests
```shell
forge build
forge test
```

## C2LevelToken.sol
- This is Level Token Contract on Arbitrum
- Only Bridge Controller allowed to mint

## BridgeController.sol
- This contract is Bridge Controller on BNB Chain
- Saved LVL tokens sent from BNB
- Transfer LVL tokens to user if bridge request validated

## C2BridgeController.sol
- This contract is Bridge Controller on Arbitrum
- Burn LVL tokens sent from Arbitrum
- Mint LVL tokens to user if bridge request validated

## BridgeProxy.sol
This contract communicate with layerzero protocol (send/receive message)
