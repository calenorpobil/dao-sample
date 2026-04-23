# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DAO voting platform with **gasless meta-transactions** (EIP-2771). Users vote on proposals without paying gas — a relayer subsidizes costs. Built for educational purposes with a Foundry smart contract backend and a Next.js web frontend.

## Repository Structure

```
dao/
├── sc/        # Foundry smart contracts
└── web/       # Next.js 15 frontend
```

## Smart Contract Commands (in `dao/sc/`)

```bash
forge build                                          # Compile contracts
forge test                                           # Run full test suite
forge test -vvv                                      # Verbose test output (show logs and traces)
forge test --match-test <TestFunctionName>           # Run a single test
forge script script/Deploy.s.sol:DeployScript --rpc-url http://127.0.0.1:8545 --broadcast
```

Dependencies live in `lib/` (OpenZeppelin, forge-std) — installed via `forge install`.

## Web Commands (in `dao/web/`)

```bash
npm run dev    # Dev server with Turbopack
npm run build  # Production build
npm run lint   # ESLint
npm start      # Run production build
```

## Local Development Setup

1. Start Anvil: `anvil` (provides a local blockchain on `http://127.0.0.1:8545`)
2. Deploy contracts: `forge script script/Deploy.s.sol:DeployScript --rpc-url http://127.0.0.1:8545 --broadcast`
3. Copy contract addresses into `dao/web/.env.local`
4. Copy ABIs from `dao/sc/out/` into `dao/web/src/lib/`
5. Run web: `npm run dev`

The `deploy-local.sh` script automates steps 2–4.

## Architecture

### EIP-2771 Gasless Flow

1. User signs a vote off-chain (EIP-712 typed data, no gas)
2. Browser posts to `/api/relay` with the signed message
3. Relayer (server) validates nonce and calls `MinimalForwarder.execute()`
4. `MinimalForwarder` appends original user address to calldata
5. `DAOVoting` inherits `ERC2771Context` — recovers the real `_msgSender()` from appended bytes

### Proposal Lifecycle

```
Create → Voting Period → Deadline → Execution Delay (1 day) → Execute
```

- **Create**: Requires caller balance ≥ 10% of total DAO balance
- **Vote**: Requires ≥ 0.1 ETH deposited; votes are gasless via meta-tx
- **Execute**: Triggered by daemon (`/api/daemon`) or manually; requires FOR > AGAINST + delay elapsed

### Key Contracts

| File | Purpose |
|------|---------|
| `src/DAOVoting.sol` | Main DAO: deposits, proposals, voting, execution |
| `src/MinimalForwarder.sol` | EIP-2771 forwarder: nonce tracking, signature recovery, tx forwarding |

### Key Web Files

| File | Purpose |
|------|---------|
| `src/app/api/relay/route.ts` | Server: validates + forwards meta-transactions |
| `src/app/api/daemon/route.ts` | Server: auto-executes eligible proposals |
| `src/lib/metaTx.ts` | Client: builds and signs EIP-712 meta-transaction |
| `src/lib/contracts.ts` | Exports ethers Contract instances + ABIs |

### Environment Variables

`dao/web/.env.local`:
- `NEXT_PUBLIC_DAO_CONTRACT_ADDRESS` — DAO contract (public, browser-visible)
- `NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS` — Forwarder contract (public)
- `RELAYER_PRIVATE_KEY` — Relayer account key (server-side only)
- `RELAYER_ADDRESS` — Relayer address
- `RPC_URL` — RPC endpoint used by the server relayer

`dao/sc/.env` (for deploy scripts):
- `PRIVATE_KEY` — Deployer private key
- `RPC_URL` — RPC endpoint
- `MINIMUM_BALANCE` — Voting eligibility threshold in wei (default 0.1 ETH)

## ABI Sync

After recompiling contracts, copy updated ABIs to the frontend:
```bash
cp dao/sc/out/DAOVoting.sol/DAOVoting.json dao/web/src/lib/DAOVoting.abi.json
cp dao/sc/out/MinimalForwarder.sol/MinimalForwarder.json dao/web/src/lib/MinimalForwarder.abi.json
```

The web app reads ABIs from `src/lib/*.abi.json` — mismatches cause silent failures in ethers.js calls.

## Testing Notes

Foundry tests in `sc/test/DAOVoting.t.sol` use `vm.warp()` to advance block time past voting deadlines and execution delays. Always run `forge test -vvv` when debugging vote or execution failures to see revert reasons.
