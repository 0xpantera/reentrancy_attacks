# README.txt

## Reentrancy Attacks in Cairo Smart Contracts

This project demonstrates how reentrancy attacks can be exploited in Cairo smart contracts on the Starknet blockchain, and how they can be mitigated using proper security patterns.

### Overview

The repository contains two examples of reentrancy vulnerabilities:

1. **Bank Attack** - A classic reentrancy attack on a bank-like contract where an attacker can withdraw more funds than they deposited.
2. **Marketplace Attack** - A reentrancy attack on an NFT marketplace where an attacker can steal NFTs without paying for them.

### Attack Vector Explanation

#### What is a Reentrancy Attack?

A reentrancy attack occurs when a malicious contract calls back into the vulnerable contract before the first invocation is complete. This can allow the attacker to repeatedly execute code that should only be executed once, often resulting in theft of assets.

#### Bank Attack

In the `eth_bank.cairo` contract, the vulnerability exists in the `withdraw` function:

1. The function checks if the caller has sufficient balance
2. Makes an external call to the caller (to verify receiver)
3. Transfers funds to the receiver
4. Updates the caller's balance state **after** the external call

This violates the Checks-Effects-Interactions (CEI) pattern. The attacker exploits this by creating a malicious contract (`sundance_kid.cairo`) that calls `withdraw` again during the callback, before the balance is updated.

#### Marketplace Attack

In the `marketplace.cairo` contract, the vulnerability exists in the interaction between `buy_nft` and NFT callbacks:

1. When a user buys an NFT, the contract transfers the NFT to the buyer using `safe_transfer_from`
2. This triggers the `on_erc721_received` callback on the recipient
3. The malicious contract (`butch_cassidy.cairo`) uses this callback to perform further operations on the marketplace
4. Before the original `buy_nft` function completes, the attacker can list, delist, and steal NFTs

### Mitigation Strategies

#### Checks-Effects-Interactions (CEI) Pattern

The CEI pattern is a best practice for preventing reentrancy attacks:

1. **Checks**: Verify preconditions (e.g., balance checks)
2. **Effects**: Update state variables (e.g., decrease balances)
3. **Interactions**: Make external calls to other contracts

In both vulnerable contracts, they perform interactions before updating state, allowing reentrancy.

#### How to Fix the Vulnerabilities

1. **Bank Contract**:
   - Move the balance update (`self.balances.write(caller, balance - amount);`) before the external calls
   - Consider using a reentrancy guard

2. **Marketplace Contract**:
   - Implement status flags to track the state of NFTs during transactions
   - Update state before making external calls
   - Consider using a reentrancy guard

#### Using OpenZeppelin ReentrancyGuard

OpenZeppelin provides a ReentrancyGuard component that can be used to prevent reentrancy attacks:

```cairo
use openzeppelin_security::reentrancy_guard::ReentrancyGuardComponent;

component!(path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent);

#[storage]
struct Storage {
    #[substorage(v0)]
    reentrancy_guard: ReentrancyGuardComponent::Storage,
    // other storage...
}

// Inside functions:
self.reentrancy_guard.start();
// function logic...
self.reentrancy_guard.end();
```

### How to Run the Tests

1. Install Scarb and Starknet Foundry
2. Run tests with: `scarb test`

The tests demonstrate successful exploitation of the reentrancy vulnerabilities:
- The bank attack shows how an attacker can drain all funds
- The marketplace attack shows how an attacker can steal all NFTs without paying

### Conclusion

Reentrancy attacks remain a critical vulnerability in smart contracts across all blockchain platforms. By understanding how these attacks work and applying proper security patterns like CEI and reentrancy guards, developers can build more secure smart contracts on Starknet.

Remember: always update state before making external calls, and consider using a reentrancy guard for functions that interact with external contracts.
