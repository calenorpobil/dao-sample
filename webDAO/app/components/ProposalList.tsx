"use client";

import { useEffect, useState } from "react";
import { getDAOContract, getForwarderContract, getReadProvider } from "@/lib/contracts";
import { ProposalCard } from "./ProposalCard";
import { VoteType, type Proposal } from "@/lib/types";
import { signMetaTx, relayMetaTx } from "@/lib/metaTx";
import { Interface } from "ethers";

interface ProposalListProps {
  userAddress: string | null;
}

export function ProposalList({ userAddress }: ProposalListProps) {
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [userVotes, setUserVotes] = useState<Map<number, VoteType>>(new Map());
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadProposals();
    const interval = setInterval(loadProposals, 5000);
    return () => clearInterval(interval);
  }, [userAddress]);

  const loadProposals = async () => {
    if (!userAddress) {
      setIsLoading(false);
      return;
    }

    try {
      const daoContract = getDAOContract(getReadProvider()) as any;

      const count = await daoContract.proposalCount();
      const loadedProposals: Proposal[] = [];
      const votes = new Map<number, VoteType>();

      for (let i = 1; i <= count; i++) {
        const proposal = await daoContract.getProposal(i);
        const voted = await daoContract.hasVoted(i, userAddress);

        // getProposal returns: [0]id [1]recipient [2]amount [3]votingDeadline
        //   [4]executionDelay [5]executed [6]forVotes [7]againstVotes [8]abstainVotes [9]description
        loadedProposals.push({
          id: i,
          recipient: proposal[1],
          amount: proposal[2].toString(),
          deadline: Number(proposal[3]),
          forVotes: Number(proposal[6]),
          againstVotes: Number(proposal[7]),
          abstainVotes: Number(proposal[8]),
          executed: proposal[5],
        });

        if (voted) {
          const vote = await daoContract.getUserVote(i, userAddress);
          votes.set(i, Number(vote) as VoteType);
        }
      }

      setProposals(loadedProposals);
      setUserVotes(votes);
      setError(null);
    } catch (err) {
      console.error("Failed to load proposals:", err);
      setError(err instanceof Error ? err.message : "Failed to load proposals");
    } finally {
      setIsLoading(false);
    }
  };

  const handleVote = async (proposalId: number, voteType: VoteType) => {
    if (!userAddress) throw new Error("Not connected");

    try {
      const daoAddress = process.env.NEXT_PUBLIC_DAO_CONTRACT_ADDRESS;
      const forwarderAddress = process.env.NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS;

      if (!daoAddress || !forwarderAddress) throw new Error("Contract addresses not configured");

      const forwarderContract = getForwarderContract(getReadProvider());
      const nonce = await forwarderContract.getNonce(userAddress);

      const iface = new Interface([
        "function vote(uint256 proposalId, uint8 voteType)",
      ]);

      const data = iface.encodeFunctionData("vote", [proposalId, voteType]);

      const metaTx = {
        from: userAddress,
        to: daoAddress,
        value: "0",
        gas: 500000,
        data,
        nonce: Number(nonce),
      };

      const signedMetaTx = await signMetaTx(metaTx, forwarderAddress);
      await relayMetaTx(signedMetaTx);

      setUserVotes((prev) => new Map(prev).set(proposalId, voteType));
      await loadProposals();
    } catch (err) {
      throw err instanceof Error ? err : new Error("Vote failed");
    }
  };

  if (!userAddress) {
    return (
      <div className="text-center py-12 text-gray-400">
        Connect your wallet to view proposals
      </div>
    );
  }

  if (isLoading) {
    return <div className="text-center py-12">Loading proposals...</div>;
  }

  if (proposals.length === 0) {
    return (
      <div className="text-center py-12 text-gray-400">
        No proposals yet. Create one to get started!
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {error && <p className="text-red-400 text-sm p-4 bg-red-900 rounded">{error}</p>}
      {proposals.map((proposal) => {
        const now = Math.floor(Date.now() / 1000);
        const isActive = proposal.deadline > now && !proposal.executed;

        return (
          <ProposalCard
            key={proposal.id}
            proposal={proposal}
            userVote={userVotes.get(proposal.id) ?? null}
            isActive={isActive}
            onVote={(voteType) => handleVote(proposal.id, voteType)}
          />
        );
      })}
    </div>
  );
}
