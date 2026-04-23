# DAO Voting Platform - Frontend

Next.js 15 web application for gasless DAO voting using EIP-2771 meta-transactions.

## Features

- **Gasless Voting**: Vote on proposals without paying gas
- **MetaMask Integration**: Connect wallet and manage balances
- **Proposal Management**: Create, view, and vote on proposals
- **Real-time Updates**: Live proposal status and vote counts
- **Relay Service**: Server-side meta-transaction relay
- **Auto-Execution**: Daemon for automatic proposal execution

## Setup

### Prerequisites

- Node.js 18+
- MetaMask browser extension
- Smart contracts deployed and addresses configured

### Installation

```bash
cd webDAO
npm install
```

### Environment Configuration

Copy `.env.local.example` to `.env.local` and fill in:

```bash
cp .env.local.example .env.local
```

**Required variables:**

- `NEXT_PUBLIC_DAO_CONTRACT_ADDRESS` - DAO voting contract address
- `NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS` - EIP-2771 forwarder address
- `NEXT_PUBLIC_CHAIN_ID` - Network chain ID (31337 for local Anvil)
- `RPC_URL` - RPC endpoint (used by relayer)
- `RELAYER_PRIVATE_KEY` - Private key for relayer account
- `RELAYER_ADDRESS` - Relayer account address

### Development

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Architecture

### Components

#### Page Components

- **page.tsx** - Main dashboard with wallet connection, balance display, and proposal list

#### Features

- **ConnectWallet** - MetaMask connection button and account display
- **FundingPanel** - Deposit ETH into DAO
- **CreateProposal** - Create new proposals (requires 10% of DAO balance)
- **ProposalList** - Display all proposals with real-time updates
- **ProposalCard** - Individual proposal with vote counts and state
- **VoteButtons** - Gasless voting interface

### Libraries

#### Web3

- **ethers.js** - Ethereum provider and contract interaction
- **EIP-712** - Typed data signing for meta-transactions
- **MetaMask** - Wallet connection and transaction signing

#### UI

- **React 19** - Component framework
- **Tailwind CSS** - Styling
- **TypeScript** - Type safety

## Workflow

### 1. Connect Wallet

User clicks "Connect Wallet" to link MetaMask account.

### 2. Fund DAO

User deposits ETH to gain voting rights and proposal creation ability.

```
User Balance → fundDAO() → DAO Contract → Updated Balance
```

### 3. Create Proposal

User creates proposal with:
- Recipient address
- ETH amount to transfer
- Voting deadline

Requires balance ≥ 10% of total DAO balance.

### 4. Vote (Gasless)

User votes without paying gas:

```
User Signs (EIP-712) → API /relay → Relayer → MinimalForwarder → DAO
```

### 5. Execute Proposal

Daemon automatically executes approved proposals:

```
API /daemon → Checks Deadline & Votes → Executes Eligible Proposals
```

## API Routes

### POST `/api/relay`

Executes signed meta-transactions.

**Request:**

```json
{
  "from": "0xUserAddress",
  "to": "0xDAOAddress",
  "value": "0",
  "data": "0x...",
  "nonce": 0,
  "signature": "0x..."
}
```

**Response:**

```json
{
  "success": true,
  "hash": "0xTransactionHash",
  "blockNumber": 12345
}
```

### GET/POST `/api/daemon`

Executes eligible proposals.

**Response:**

```json
{
  "success": true,
  "executed": [1, 3, 5],
  "count": 3
}
```

## Development Notes

### Adding Contract ABIs

After recompiling contracts, copy updated ABIs:

```bash
cp ../sc/out/DAOVoting.sol/DAOVoting.json lib/
cp ../sc/out/MinimalForwarder.sol/MinimalForwarder.json lib/
```

Update `contracts.ts` with any ABI changes.

### Testing Locally

1. Start Anvil: `anvil`
2. Deploy contracts: `cd ../sc && forge script ...`
3. Update `.env.local` with contract addresses
4. Run dev server: `npm run dev`

### Debugging Meta-Transactions

Enable logging in `/api/relay` route to trace signature validation and execution.

## Performance

- **Proposal Loading**: 5-second polling interval
- **Auto-Refresh**: Real-time balance and vote updates
- **Gasless Voting**: <2 second relay confirmation

## Security

- **Signature Verification**: EIP-2771 forwarder validates all signatures
- **Nonce Tracking**: Prevents replay attacks
- **Relayer Authentication**: Private key-based server signing
- **Input Validation**: Type checking for all contract calls

## Building for Production

```bash
npm run build
npm start
```

Use `output: 'standalone'` in `next.config.ts` for Docker deployment.

## Troubleshooting

### "Contract addresses not configured"

Ensure `.env.local` has `NEXT_PUBLIC_*` variables set.

### MetaMask connection fails

Check that MetaMask is on the correct network (Anvil: localhost:8545).

### Relay fails with "invalid signature"

Verify `RELAYER_PRIVATE_KEY` matches the relayer account used in contracts.

### Proposals not executing

Run daemon manually: `curl http://localhost:3000/api/daemon`

## License

Educational project for DAO voting demo.
