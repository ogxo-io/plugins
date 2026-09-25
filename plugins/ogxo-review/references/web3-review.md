# Web3 / Smart Contract Review Guidance

Extended Solidity and DeFi review guidance for the code-review-agent. The inline Web3 checklist covers the actionable per-PR items; read this when reviewing smart contracts or DeFi protocols and you need the deeper vulnerability catalog.

## Solidity Best Practices

- Use the latest stable compiler version; enable the optimizer with appropriate runs
- Follow the Checks-Effects-Interactions pattern (state changes before external calls)
- Emit events for all state changes
- Prefer audited OpenZeppelin contracts over hand-rolled equivalents
- Use `view`/`pure` correctly to signal (and enforce) no state mutation

## Common Vulnerabilities

- **Reentrancy**: external call before state update — apply Checks-Effects-Interactions and/or `ReentrancyGuard`
- **Access control**: verify `onlyOwner` / role-based modifiers on privileged functions
- **Integer overflow/underflow**: confirm Solidity 0.8+ checked arithmetic or SafeMath
- **Unbounded loops**: gas-limit DoS when iterating attacker-influenced arrays
- **Timestamp dependence**: avoid `block.timestamp` for critical logic (miner-influenceable)
- **tx.origin auth**: never authenticate with `tx.origin` (phishing via intermediary contract)

## DeFi-Specific Risks

- **Price oracle manipulation**: single-source or spot-price oracles manipulable via flash loans — prefer TWAP / multi-source
- **Flash loan attack vectors**: atomic borrow → manipulate → profit within one transaction
- **Liquidity pool exploitation**: imbalanced pools, first-depositor share inflation
- **Slippage and sandwich attacks**: enforce slippage bounds and deadlines on swaps

## Upgradeability

- Review proxy patterns (transparent, UUPS) for storage-layout collisions and uninitialized-implementation risks
- Confirm initializer functions cannot be called twice and are protected against front-running
