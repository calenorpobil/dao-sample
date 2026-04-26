// Must match DAOVoting.sol: enum VoteType { FOR, AGAINST, ABSTAIN }
export enum VoteType {
  FOR = 0,
  AGAINST = 1,
  ABSTAIN = 2,
}

export enum ProposalState {
  PENDING = "Pending",
  ACTIVE = "Active",
  DEFEATED = "Defeated",
  SUCCEEDED = "Succeeded",
  QUEUED = "Queued",
  EXPIRED = "Expired",
  EXECUTED = "Executed",
}

export interface Proposal {
  id: number;
  recipient: string;
  amount: string;
  deadline: number;
  forVotes: number;
  againstVotes: number;
  abstainVotes: number;
  executed: boolean;
  executedAt?: number;
}

export interface UserVote {
  proposalId: number;
  voteType: VoteType;
}

export interface MetaTxData {
  from: string;
  to: string;
  value: string;
  gas: number;
  data: string;
  nonce: number;
}

export interface SignedMetaTx extends MetaTxData {
  signature: string;
}

export interface WalletState {
  address: string | null;
  balance: string;
  isConnected: boolean;
  chainId: number | null;
}
