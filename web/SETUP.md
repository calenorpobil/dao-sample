# Setup Guide - DAO Frontend with Smart Contracts

Complete setup instructions for integrating webDAO with the smart contracts from `sc/`.

## 1. Prerequisites

- Smart contracts compiled and deployed
- Anvil running locally or network accessible
- Environment variables configured

## 2. Contract Integration

### Step 1: Copy ABIs

After compiling contracts in `sc/`, copy the ABIs to the frontend:

```bash
# From the root directory
cp sc/out/DAOVoting.sol/DAOVoting.json webDAO/lib/DAOVoting.abi.json
cp sc/out/MinimalForwarder.sol/MinimalForwarder.json webDAO/lib/MinimalForwarder.abi.json
```

### Step 2: Update ABI Imports

If ABIs have changed, update `lib/contracts.ts` with the actual ABI content:

```typescript
import DAOVotingABI from "./DAOVoting.abi.json";
import MinimalForwarderABI from "./MinimalForwarder.abi.json";

export const DAO_ABI = DAOVotingABI;
export const FORWARDER_ABI = MinimalForwarderABI;
```

## 3. Environment Setup

### Create `.env.local`

```bash
# Smart Contract Addresses (from deployment)
NEXT_PUBLIC_DAO_CONTRACT_ADDRESS=0x1234567890123456789012345678901234567890
NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS=0x0987654321098765432109876543210987654321

# Network Configuration
NEXT_PUBLIC_CHAIN_ID=31337
RPC_URL=http://127.0.0.1:8545

# Relayer Account (from deployment private key)
RELAYER_PRIVATE_KEY=0x1234567890abcdef...
RELAYER_ADDRESS=0x1234567890123456789012345678901234567890
```

### Get Contract Addresses

After deployment with `forge script`:

```bash
cd sc
forge script script/Deploy.s.sol:DeployScript --rpc-url http://127.0.0.1:8545 --broadcast
```

The output will show:
- `DAOVoting` contract address
- `MinimalForwarder` contract address

## 4. Installation & Build

```bash
cd webDAO

# Install dependencies
npm install

# Build for production
npm run build

# Run locally
npm run dev
```

## 5. Deployment Variables

The contracts expect these environment variables during deployment:

```bash
# In sc/.env
PRIVATE_KEY=0x1234567890abcdef...
RPC_URL=http://127.0.0.1:8545
MINIMUM_BALANCE=100000000000000000  # 0.1 ETH in wei
```

## 6. Testing the Integration

### Local Testing

1. **Start Anvil**

```bash
anvil
```

2. **Deploy Smart Contracts**

```bash
cd sc
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

3. **Update `.env.local`** with contract addresses

4. **Start Frontend**

```bash
cd webDAO
npm run dev
```

5. **Test Workflow**

- Open http://localhost:3000
- Connect MetaMask to localhost:8545
- Import test account from Anvil into MetaMask
- Deposit ETH to DAO
- Create a proposal
- Vote gaslessly
- Trigger daemon to execute

### Verify Meta-Transaction Flow

Check logs in `/api/relay`:

```bash
# Terminal 1: Start dev server
npm run dev

# Terminal 2: Monitor logs
tail -f .next/logs
```

## 7. Configuration Reference

### Contract Methods Used

#### DAOVoting

```solidity
function fundDAO() external payable
function createProposal(address recipient, uint256 amount, uint256 deadline) external
function vote(uint256 proposalId, uint8 voteType) external
function executeProposal(uint256 proposalId) external
function getProposal(uint256 proposalId) external view returns (Proposal)
function getUserBalance(address user) external view returns (uint256)
function getTotalBalance() external view returns (uint256)
```

#### MinimalForwarder

```solidity
function getNonce(address from) external view returns (uint256)
function verify(ForwardRequest calldata req, bytes calldata signature) external view returns (bool)
function execute(ForwardRequest calldata req, bytes calldata signature) external payable returns (bytes32)
```

### Environment Variables by Component

| Variable | Used By | Purpose |
|----------|---------|---------|
| `NEXT_PUBLIC_DAO_CONTRACT_ADDRESS` | Frontend | Contract calls |
| `NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS` | Frontend | Meta-tx relay |
| `NEXT_PUBLIC_CHAIN_ID` | Frontend | Network validation |
| `RPC_URL` | Relayer API | Transaction execution |
| `RELAYER_PRIVATE_KEY` | Relayer API | Sign relay transactions |
| `RELAYER_ADDRESS` | Tests | Fund relayer account |

## 8. Troubleshooting

### "Contract addresses not configured"

Check that `NEXT_PUBLIC_*` environment variables are set in `.env.local`.

### "Invalid signature" from relay

1. Verify `RELAYER_PRIVATE_KEY` matches relayer account in smart contracts
2. Check nonce is correct (use `getNonce()`)
3. Ensure forwarder address matches deployment

### MetaMask rejects transaction

1. Check chain ID (should be 31337 for Anvil)
2. Ensure account has ETH for gas
3. Verify RPC URL is accessible

### Proposals not showing

1. Check contract address is correct
2. Run `getProposalCount()` to verify proposals exist
3. Check browser console for errors

### Auto-execution daemon not working

1. Test manually: `curl http://localhost:3000/api/daemon`
2. Check `RELAYER_PRIVATE_KEY` is set
3. Verify relayer account has ETH for gas

## 9. Next Steps

- Implement proposal metadata (title, description, discussion URL)
- Add time-lock mechanism for security
- Implement delegation voting
- Add voting power display
- Create proposal templates

## 10. Resources

- [EIP-2771 Standard](https://eips.ethereum.org/EIPS/eip-2771)
- [ethers.js Documentation](https://docs.ethers.org/)
- [Next.js 15 Docs](https://nextjs.org/docs)
- [Foundry Documentation](https://book.getfoundry.sh/)
