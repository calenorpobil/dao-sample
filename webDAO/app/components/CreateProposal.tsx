"use client";

import { useState } from "react";
import { BrowserProvider, parseEther } from "ethers";
import { getDAOContract } from "@/lib/contracts";

interface CreateProposalProps {
  onSuccess: () => void;
  canCreate: boolean;
}

export function CreateProposal({ onSuccess, canCreate }: CreateProposalProps) {
  const [recipient, setRecipient] = useState("");
  const [amount, setAmount] = useState("");
  const [deadline, setDeadline] = useState("");
  const [description, setDescription] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [txHash, setTxHash] = useState<string | null>(null);

  const handleCreate = async () => {
    if (!recipient || !amount || !deadline || !description) {
      setError("Fill all fields");
      return;
    }

    if (!canCreate) {
      setError("Insufficient balance to create proposal (need 10% of DAO total)");
      return;
    }

    setIsLoading(true);
    setError(null);
    setTxHash(null);

    try {
      if (!window.ethereum) throw new Error("MetaMask not found");

      const provider = new BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const daoContract = getDAOContract(provider).connect(signer) as any;

      // Contract expects voting duration in seconds, not absolute timestamp
      const deadlineTs = Math.floor(new Date(deadline).getTime() / 1000);
      const votingDuration = deadlineTs - Math.floor(Date.now() / 1000);
      if (votingDuration <= 0) {
        setError("Deadline must be in the future");
        setIsLoading(false);
        return;
      }

      const tx = await daoContract.createProposal(
        recipient,
        parseEther(amount),
        votingDuration,
        description
      );

      setTxHash(tx.hash);
      await tx.wait();
      setRecipient("");
      setAmount("");
      setDeadline("");
      setDescription("");
      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Creation failed");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
      <h2 className="text-xl font-bold mb-4">Create Proposal</h2>

      {!canCreate && (
        <p className="text-yellow-400 text-sm mb-4">
          You need at least 10% of DAO balance to create proposals
        </p>
      )}

      <div className="space-y-4">
        <input
          type="text"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Proposal description"
          className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          disabled={isLoading || !canCreate}
        />
        <input
          type="text"
          value={recipient}
          onChange={(e) => setRecipient(e.target.value)}
          placeholder="Recipient address (0x...)"
          className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          disabled={isLoading || !canCreate}
        />

        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="Amount in ETH"
          className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          disabled={isLoading || !canCreate}
        />

        <input
          type="datetime-local"
          value={deadline}
          onChange={(e) => setDeadline(e.target.value)}
          className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          disabled={isLoading || !canCreate}
        />

        <button
          onClick={handleCreate}
          disabled={isLoading || !canCreate}
          className="w-full px-4 py-2 bg-purple-600 hover:bg-purple-700 disabled:bg-purple-400 rounded-lg text-white font-medium"
        >
          {isLoading ? "Creating..." : "Create Proposal"}
        </button>

        {error && <p className="text-red-400 text-sm">{error}</p>}
        {txHash && (
          <p className="text-green-400 text-sm">
            Transaction: {txHash.slice(0, 10)}...
          </p>
        )}
      </div>
    </div>
  );
}
