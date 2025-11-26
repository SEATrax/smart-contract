# GitHub Copilot Instructions – Solidity Project

## Project Overview
You are assisting on a Solidity smart contract project using Foundry.  
Goal: write secure, gas-efficient contracts with clear business logic and comprehensive test coverage.

## Tech Stack
- Solidity ^0.8.x (latest stable)
- Foundry (`forge`) for build, test, and scripts
- OpenZeppelin for ERC standards, access control, and guards (when appropriate)

## Coding Guidelines
- Use Solidity ^0.8.x with fixed pragma (no floating ranges)
- Prefer composition and small, focused contracts over monolithic designs
- Use `internal`/`private` modifiers to limit visibility
- Use clear, consistent camelCase naming for variables and functions
- Write NatSpec comments on all `public` and `external` functions
- Use `constant`/`immutable` for configuration constants
- Use basis points (1 bp = 0.01%) to handle percentages accurately

## Security Best Practices

### Checks-Effects-Interactions (CEI) Pattern

- Always follow the CEI pattern in functions that modify state and transfer funds:
  1. **Checks:** Validate all conditions using `require` or custom errors upfront.
  2. **Effects:** Update all contract state variables after checks pass.
  3. **Interactions:** Perform external calls or transfers *last* to avoid reentrancy vulnerabilities.

### Contract Structure and Positioning Rules

- **Custom Errors:**  
  - Declare custom errors at the top of the contract, immediately after SPDX license and pragma statements.
  - Name errors clearly reflecting the failure reason.
  
- **Events:**  
  - Declare all events after error declarations.
  - Emit events at the *end* of state-modifying functions after all state changes.

- **Functions Order:**  
  - Start with public and external functions grouped by functionality.
  - Follow with internal and private helper functions.
  - Use modifiers after functions and before internal functions.
  - Organize functions with NatSpec comments describing their purpose and behavior.

### Example Structure
```solidity
// SPDX-License-Identifier: MITpragma solidity ^0.8.20;
error Unauthorized(address caller);
error InsufficientBalance(uint256 requested, uint256 available);
event Deposited(address indexed user, uint256 amount);event Withdrawn(address indexed user, uint256 amount);
contract Example {mapping(address => uint256) private balances;

modifier onlyOwner() {
    if (msg.sender != owner) revert Unauthorized(msg.sender);
    _;
}

function deposit() external payable {
    // Checks
    require(msg.value > 0, "Deposit: amount must be > 0");

    // Effects
    balances[msg.sender] += msg.value;

    // Interactions - none here

    emit Deposited(msg.sender, msg.value);
}

function withdraw(uint256 amount) external {
    // Checks
    uint256 bal = balances[msg.sender];
    if (amount == 0 || amount > bal) revert InsufficientBalance(amount, bal);

    // Effects
    balances[msg.sender] = bal - amount;

    // Interactions
    (bool sent, ) = payable(msg.sender).call{value: amount}("");
    require(sent, "Withdraw: failed to send Ether");

    emit Withdrawn(msg.sender, amount);
}

// Internal helper functions here
```
---
## Testing Guidelines (Foundry)
- One test file per contract (e.g., `ContractName.t.sol`)
- Cover every public/external function for:
  - Successful executions (happy paths)
  - Access control restrictions and failures
  - Edge and boundary cases
  - Expected revert scenarios
- Write integration tests for full flows
- Use Foundry cheatcodes for better test control
- Aim for high coverage and detailed assertions

---

## Project Structure
- `src/` — Solidity contracts  
- `test/` — Foundry test scripts  
- `script/` — Deployment and utility scripts  
- `foundry.toml` — Foundry configuration

Follow these instructions strictly to ensure robust, secure, and maintainable Solidity code.
