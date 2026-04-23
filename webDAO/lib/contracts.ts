import { BrowserProvider, JsonRpcProvider, Contract } from "ethers";

// ABI para DAOVoting - debe copiarse desde sc/out/DAOVoting.sol/DAOVoting.json
export const DAO_ABI = [
  "function deposit() external payable",
  "function createProposal(address recipient, uint256 amount, uint256 votingDuration, string description) external returns (uint256)",
  "function vote(uint256 proposalId, uint8 voteType) external",
  "function executeProposal(uint256 proposalId) external",
  "function getProposal(uint256 proposalId) external view returns (uint256 id, address recipient, uint256 amount, uint256 votingDeadline, uint256 executionDelay, bool executed, uint256 forVotes, uint256 againstVotes, uint256 abstainVotes, string description)",
  "function getUserBalance(address user) external view returns (uint256)",
  "function getTotalDeposited() external view returns (uint256)",
  "function getUserVote(uint256 proposalId, address user) external view returns (uint8)",
  "function hasVoted(uint256 proposalId, address user) external view returns (bool)",
  "function proposalCount() external view returns (uint256)",
  "function canExecute(uint256 proposalId) external view returns (bool)",
];

// ABI para MinimalForwarder - debe copiarse desde sc/out/MinimalForwarder.sol/MinimalForwarder.json
export const FORWARDER_ABI = [
  "function getNonce(address from) external view returns (uint256)",
  "function getTypedDataHash(tuple(address from, address to, uint256 value, uint256 gas, uint256 nonce, bytes data) req) external view returns (bytes32)",
  "function execute(tuple(address from, address to, uint256 value, uint256 gas, uint256 nonce, bytes data) req, bytes signature) external payable",
];

// Para lecturas de chain — usa JsonRpcProvider directo, sin pasar por MetaMask
export function getReadProvider(): JsonRpcProvider {
  const rpc = process.env.NEXT_PUBLIC_RPC_URL || "http://127.0.0.1:8545";
  return new JsonRpcProvider(rpc);
}

export function getDAOContract(provider: BrowserProvider | JsonRpcProvider) {
  const address = process.env.NEXT_PUBLIC_DAO_CONTRACT_ADDRESS;
  if (!address) throw new Error("DAO_CONTRACT_ADDRESS not set");
  return new Contract(address, DAO_ABI, provider);
}

export function getForwarderContract(provider: BrowserProvider | JsonRpcProvider) {
  const address = process.env.NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS;
  if (!address) throw new Error("FORWARDER_CONTRACT_ADDRESS not set");
  return new Contract(address, FORWARDER_ABI, provider);
}
