"use client";

import { formatEther } from "ethers";
import { VoteType, type Proposal } from "@/lib/types";
import { VoteButtons } from "./VoteButtons";

interface ProposalCardProps {
  proposal: Proposal;
  userVote: VoteType | null;
  isActive: boolean;
  onVote: (voteType: VoteType) => Promise<void>;
}

export function ProposalCard({
  proposal,
  userVote,
  isActive,
  onVote,
}: ProposalCardProps) {
  const totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
  const forPercentage = totalVotes > 0 ? (proposal.forVotes / totalVotes) * 100 : 0;
  const againstPercentage = totalVotes > 0 ? (proposal.againstVotes / totalVotes) * 100 : 0;

  return (
    <div className="bg-gray-800 p-6 rounded-lg border border-gray-700 space-y-4">
      <div className="flex justify-between items-start">
        <div>
          <h3 className="text-lg font-bold">Proposal #{proposal.id}</h3>
          <p className="text-gray-400 text-sm">
            to: <span className="font-mono">{proposal.recipient.slice(0, 10)}...</span>
          </p>
        </div>
        <div className="text-right">
          <p className="text-2xl font-bold text-green-400">
            {formatEther(proposal.amount)} ETH
          </p>
          <p className={`text-sm ${isActive ? "text-yellow-400" : "text-gray-400"}`}>
            {isActive ? "Active" : "Closed"}
          </p>
        </div>
      </div>

      <div className="space-y-2">
        <div className="flex gap-2 text-sm">
          <span className="text-green-400">✓ {proposal.forVotes} FOR</span>
          <span className="text-red-400">✗ {proposal.againstVotes} AGAINST</span>
          <span className="text-gray-400">~ {proposal.abstainVotes} ABSTAIN</span>
        </div>

        <div className="w-full bg-gray-700 h-2 rounded-full overflow-hidden flex">
          {forPercentage > 0 && (
            <div
              style={{ width: `${forPercentage}%` }}
              className="bg-green-500"
            />
          )}
          {againstPercentage > 0 && (
            <div
              style={{ width: `${againstPercentage}%` }}
              className="bg-red-500"
            />
          )}
          {forPercentage + againstPercentage < 100 && (
            <div className="bg-gray-500 flex-1" />
          )}
        </div>
      </div>

      {isActive && (
        <VoteButtons userVote={userVote} onVote={onVote} />
      )}

      {proposal.executed && (
        <p className="text-green-400 text-sm">✓ Executed</p>
      )}
    </div>
  );
}
