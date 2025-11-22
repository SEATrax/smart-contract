# Export-Import Funding Smart Contract Project Instructions for GitHub Copilot

## Project Overview
You are assisting in building Solidity smart contracts for an export-import funding platform using Foundry as the development and testing framework.

The platform allows:
- Importers to create purchase contracts (requests) off-chain.
- Exporters to submit offers for contracts.
- Importers to approve offers, triggering NFT minting representing approved contracts.
- Admins to bundle approved contracts into pools.
- Investors to invest in pools; investments are proportionally split across contracts within each pool.
- Escrowed payment handling with automatic release to exporters upon contract fulfillment.
- Refund mechanisms for canceled or unfulfilled contracts.
- Role-based access control with the roles: Admin, Importer, Exporter, Investor.

## Coding Guidelines
- Use Solidity stable versions (e.g., ^0.8.20).
- Follow Solidity best practices for security (reentrancy guards, input validation, checks-effects-interactions).
- Use modular contract architecture: separate concerns for NFTs, Pools, Investments, Escrow, AccessControl, and Oracle functionality.
- Implement ERC-721 for contract NFTs.
- Track investments meticulously using nested mappings to record investor contributions per contract in pools.
- Use event emissions for important state changes.
- Apply role-based access control modifiers on sensitive functions.

## Testing Requirements
- Use Foundry/forge for writing unit tests.
- Provide full coverage tests for every public/external function.
- Cover:
  - Successful execution scenarios ("happy paths").
  - Edge cases and boundary conditions.
  - Correct enforcement of access controls.
  - Expected reverts and failure cases.
  - Correct event emissions.
- Utilize Foundry cheatcodes for mocking, state manipulation, and reverts.
- Write integration tests simulating full contract lifecycle: contract creation, pool formation, investment, fulfillment, payout, and refunds.

## Best Practices
- Prioritize security and maintainability.
- Optimize gas consumption where possible.
- Keep functions small and focused.
- Document functions and complex logic with NatSpec comments.
- Use explicit visibility (public, external, internal, private).
- Do not expose sensitive data.
- Use descriptive variable and function names.
- Structure code and tests clearly by feature.

## Project Layout
/src
	•	ContractNFT.sol
	•	PoolManager.sol
	•	InvestmentPool.sol
	•	EscrowPayment.sol
	•	AccessControl.sol
	•	FulfillmentOracle.sol
/test
	•	ContractNFT.t.sol
	•	PoolManager.t.sol
	•	InvestmentPool.t.sol
	•	EscrowPayment.t.sol
	•	AccessControl.t.sol
	•	FulfillmentOracle.t.sol
/scripts
	•	Deploy.s.sol
    •   foundry.toml

---

Follow these instructions closely when generating Solidity code or test scripts.

# Solidity API Style and Error Handling Conventions

## API Style Guidelines

- Use clear, descriptive function names reflecting their intent.
- Group related functions meaningfully.
- Use `external` visibility for functions called by users or other contracts.
- Use `public` for internal calls exposed externally.
- Use modifiers for access control (e.g., `onlyAdmin`, `onlyInvestor`).
- Emit events on every important state change.
- Document functions with NatSpec comments.
- Return values explicitly when appropriate.
- Use require/assert checks with clear revert messages on all input validations.

### Example
```solidity
event Invested(address indexed investor, uint256 indexed poolId, uint256 amount);
function invest(uint256 poolId, uint256 amount) external onlyInvestor {require(amount > 0, “Invest: amount must be > 0”);// Investment logic …emit Invested(msg.sender, poolId, amount);}
```

---

## Error Handling Conventions

- Use custom errors (`error Unauthorized(address caller);`) for gas-efficient and clear reverts.
- Use `require` for simple conditions with readable revert messages.
- Use `revert` for complex revert scenarios with custom errors.
- Always check input parameters thoroughly.
- Protect external calls with reentrancy guards.
- Gracefully handle failed external calls.
- Use modifier functions to enforce preconditions.
- Provide internal helper functions for repeated checks.

### Example
```solidity
error Unauthorized(address caller);
error InvalidAmount(uint256 amount);

modifier onlyAdmin() {
    if (msg.sender != admin) revert Unauthorized(msg.sender);_;}
function depositPayment(uint256 contractId) external payable {if (msg.value == 0) revert InvalidAmount(0);// …}
```

---

These conventions promote readable, maintainable, and secure smart contract code consistent with Ethereum best practices.