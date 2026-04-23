# Architecture - DAO Voting Frontend

Complete architecture documentation for the Next.js 15 DAO voting platform.

## Project Structure

```
webDAO/
├── app/
│   ├── api/
│   │   ├── relay/route.ts          # Meta-transaction relay service
│   │   └── daemon/route.ts         # Auto-execution daemon
│   ├── components/
│   │   ├── ConnectWallet.tsx       # MetaMask connection
│   │   ├── FundingPanel.tsx        # Deposit ETH to DAO
│   │   ├── CreateProposal.tsx      # Create new proposals
│   │   ├── ProposalList.tsx        # Display all proposals
│   │   ├── ProposalCard.tsx        # Individual proposal card
│   │   └── VoteButtons.tsx         # Gasless voting buttons
│   ├── global.d.ts                 # TypeScript globals (window.ethereum)
│   ├── globals.css                 # Tailwind & base styles
│   ├── layout.tsx                  # Root layout
│   └── page.tsx                    # Main dashboard
├── lib/
│   ├── contracts.ts                # Contract ABIs & instances
│   ├── metaTx.ts                   # EIP-712 signing & relay
│   ├── types.ts                    # TypeScript interfaces
│   ├── useWallet.ts                # MetaMask hook
│   └── utils.ts                    # Utility functions
├── styles/                         # Additional stylesheets (if needed)
├── .env.local.example              # Environment template
├── .eslintrc.json                  # ESLint config
├── .gitignore                      # Git ignore rules
├── next.config.ts                  # Next.js configuration
├── package.json                    # Dependencies
├── postcss.config.js               # PostCSS with Tailwind
├── tailwind.config.ts              # Tailwind CSS config
├── tsconfig.json                   # TypeScript config
├── README.md                       # User guide
├── SETUP.md                        # Integration guide
└── ARCHITECTURE.md                 # This file
```

## Component Hierarchy

```
Root (layout.tsx)
├── Header
└── Main Content (page.tsx)
    ├── ConnectWallet
    ├── [Connected User View]
    │   ├── FundingPanel
    │   ├── CreateProposal
    │   └── DAO Stats
    └── ProposalList
        ├── ProposalCard
        │   └── VoteButtons
        ├── ProposalCard
        │   └── VoteButtons
        └── ...
```

## Data Flow

### 1. Wallet Connection

```
User clicks "Connect Wallet"
    ↓
useWallet hook
    ↓
window.ethereum.request('eth_requestAccounts')
    ↓
MetaMask prompts user
    ↓
Provider gets account & balance
    ↓
UI updates with connected state
```

### 2. Funding (Regular Transaction)

```
User inputs amount & clicks "Deposit ETH"
    ↓
CreateProposal component
    ↓
Gets signer from BrowserProvider
    ↓
Calls: dao.fundDAO({ value: parseEther(amount) })
    ↓
MetaMask prompts for confirmation
    ↓
User signs & pays gas
    ↓
Transaction mined
    ↓
Balance updates
```

### 3. Gasless Voting (Meta-Transaction)

```
User clicks "Vote For/Against/Abstain"
    ↓
ProposalList.handleVote()
    ↓
Build EIP-712 typed data
    ├─ domain: chain, forwarder, version
    └─ message: from, to, data, nonce, value
    ↓
signer.signTypedData()
    ↓
MetaMask prompts (no gas cost!)
    ↓
User signs with private key
    ↓
POST /api/relay {signed transaction}
    ↓
Relayer validates signature
    ↓
Relayer calls MinimalForwarder.execute()
    ↓
MinimalForwarder appends msg.sender (user) to calldata
    ↓
MinimalForwarder calls DAO.vote(proposalId, voteType)
    ↓
DAO validates & records vote
    ↓
Success response returned
    ↓
UI updates with new vote
```

### 4. Auto-Execution (Daemon)

```
Proposal deadline passes
    ↓
Daemon polls /api/daemon (periodic)
    ↓
daemon/route.ts:
    ├─ Gets proposal count
    ├─ Checks each proposal for:
    │  ├─ deadline <= now
    │  ├─ forVotes > againstVotes
    │  └─ not executed
    ├─ Calls dao.executeProposal(id)
    └─ Returns executed proposal IDs
    ↓
Relayer pays gas for execution
    ↓
Funds transferred to recipient
    ↓
Proposal marked executed
```

## Key Technologies

### Frontend

- **React 19** - Components & hooks
- **Next.js 15** - Full-stack framework
  - App Router for file-based routing
  - API Routes for backend
  - Server/Client component boundaries
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling

### Web3

- **ethers.js v6** - Blockchain interaction
  - BrowserProvider for wallet connection
  - Contract abstraction
  - EIP-712 signing
- **MetaMask** - Wallet provider
- **EIP-2771** - Meta-transaction standard

### State Management

- React hooks only (no Redux/Zustand)
- useWallet for wallet state
- Component-level state
- Real-time polling (5s interval)

## File Conventions

### Components (`/app/components/`)

- Client components with `"use client"` directive
- Props interface defined above component
- Event handlers as functions
- Styling via Tailwind classes

**Example:**

```typescript
"use client";

interface ComponentProps {
  data: string;
  onAction: () => void;
}

export function Component({ data, onAction }: ComponentProps) {
  return <button onClick={onAction}>{data}</button>;
}
```

### Hooks (`/lib/`)

- Named `use*` for React hooks
- Exported as named exports
- Client-side only (use "use client" if needed)

### Types (`/lib/types.ts`)

- Enums for contracts (VoteType, ProposalState)
- Interfaces for data structures
- Types for Web3 interactions

### Utilities (`/lib/utils.ts`)

- Pure functions
- No side effects
- Formatting, validation, helpers

## API Routes

### `/api/relay` - POST

**Purpose:** Execute signed meta-transactions

**Flow:**

1. Receive signed meta-transaction from frontend
2. Validate request structure
3. Get relayer signer with private key
4. Call MinimalForwarder.execute()
5. Return transaction hash and block number

**Security:**

- Validates all required fields
- Relayer pays gas
- MinimalForwarder validates signature
- Nonce prevents replay attacks

### `/api/daemon` - GET/POST

**Purpose:** Auto-execute approved proposals

**Flow:**

1. Get all proposals
2. Check each for execution eligibility
   - Deadline passed
   - FOR votes > AGAINST votes
   - Not yet executed
3. Call executeProposal() for each eligible
4. Return list of executed proposal IDs

**Security:**

- Anyone can call (public)
- Smart contract validates execution conditions
- Relayer pays gas for all executions

## Best Practices Applied

### Next.js 15 Best Practices

✅ File conventions (app/ directory structure)
✅ TypeScript for type safety
✅ Server/Client component boundaries
✅ Route handlers instead of separate API files
✅ CSS modules with Tailwind
✅ Environment variables with NEXT_PUBLIC_ prefix

### React Best Practices

✅ Functional components only
✅ Custom hooks for logic reuse
✅ Props interface definitions
✅ Event handler naming (handleX)
✅ Controlled components
✅ Error boundary patterns

### Web3 Best Practices

✅ ethers.js v6 for provider/signer
✅ Contract validation before calls
✅ Error handling for network issues
✅ Gas limit specification
✅ Transaction status polling
✅ Secure key management (server-side only)

### Code Organization

✅ Single responsibility principle
✅ Clear file structure
✅ Type definitions in one place
✅ Utility functions extracted
✅ Constants in one location
✅ No hardcoded values

## Environment Variables

| Variable | Used By | Required |
|----------|---------|----------|
| NEXT_PUBLIC_DAO_CONTRACT_ADDRESS | Frontend | Yes |
| NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS | Frontend | Yes |
| NEXT_PUBLIC_CHAIN_ID | Frontend | Yes |
| RPC_URL | API Routes | Yes |
| RELAYER_PRIVATE_KEY | API Routes | Yes |
| RELAYER_ADDRESS | Tests | No |

## Performance Optimizations

- **Component memoization** for stable props
- **Polling interval** (5s) instead of WebSocket
- **Contract caching** to reduce RPC calls
- **Error boundaries** for fault tolerance
- **Suspense boundaries** for async components (future)
- **Code splitting** via dynamic imports (future)

## Error Handling

### Frontend

- Try/catch in event handlers
- User-facing error messages
- Graceful fallbacks
- Network error detection

### API Routes

- Request validation
- Contract call error catching
- Transaction revert messages
- 500/400 status codes

### User Experience

- Loading states
- Disabled buttons during requests
- Error messages displayed
- Transaction hash links

## Testing Considerations

- Unit tests for utilities
- Component tests for UI
- Integration tests for Web3 flows
- E2E tests for complete scenarios

Example test locations:

```
__tests__/
├── lib/
│   ├── utils.test.ts
│   └── metaTx.test.ts
├── components/
│   ├── ConnectWallet.test.tsx
│   └── FundingPanel.test.tsx
└── api/
    ├── relay.test.ts
    └── daemon.test.ts
```

## Deployment

### Production Build

```bash
npm run build
npm start
```

### Docker

Use `output: 'standalone'` in next.config.ts for container deployments.

### Environment Setup

- Copy `.env.local` with production addresses
- Set secure relayer key via secrets manager
- Configure RPC endpoint
- Update contract addresses from production deployment

## Future Enhancements

1. **Proposal Metadata**
   - Title, description, discussion URL
   - Store in IPFS or database

2. **Voting Delegation**
   - Delegate voting power to other addresses
   - Track delegated votes

3. **Proposal Templates**
   - Pre-defined proposal types
   - Validation schemas

4. **Time-locks**
   - Governance security
   - Delay execution by configurable period

5. **Voting Escrow**
   - Vote power based on lock duration
   - Anti-whale mechanism

6. **Treasury Management**
   - Multi-sig for spending control
   - Proposal for fund allocation

7. **Analytics Dashboard**
   - Voting participation rate
   - Proposal execution history
   - Voter demographics

## Security Audit Checklist

- [ ] Contract addresses validated
- [ ] Signature verification on relayer
- [ ] Nonce tracking prevents replays
- [ ] Private key never in browser
- [ ] Environment variables secured
- [ ] Input validation on all calls
- [ ] Error messages don't leak info
- [ ] Rate limiting on relay endpoint
- [ ] CSRF protection for API routes
- [ ] Trusted RPC endpoint only

## Resources

- [Next.js 15 Documentation](https://nextjs.org/docs)
- [ethers.js Documentation](https://docs.ethers.org/)
- [EIP-2771 Standard](https://eips.ethereum.org/EIPS/eip-2771)
- [React Documentation](https://react.dev)
- [Tailwind CSS](https://tailwindcss.com)
