"use client";

import { useState } from "react";
import { BrowserProvider, parseEther, formatEther } from "ethers";
import { getDAOContract } from "@/lib/contracts";

interface FundingPanelProps {
  userBalance: string;
  totalBalance: string;
  onSuccess: () => void;
}

export function FundingPanel({
  userBalance,
  totalBalance,
  onSuccess,
}: FundingPanelProps) {
  const [amount, setAmount] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [txHash, setTxHash] = useState<string | null>(null);

  const handleFund = async () => {
    if (!amount || parseFloat(amount) <= 0) {
      setError("Enter a valid amount");
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

      const tx = await daoContract.deposit({
        value: parseEther(amount),
      });

      setTxHash(tx.hash);
      await tx.wait();
      setAmount("");
      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Transaction failed");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
      <h2 className="text-xl font-bold mb-4">Fund DAO</h2>

      <div className="space-y-4">
        <div>
          <label className="block text-sm text-gray-400 mb-2">
            Your Balance: {formatEther(userBalance)} ETH
          </label>
          <label className="block text-sm text-gray-400 mb-2">
            Total DAO Balance: {formatEther(totalBalance)} ETH
          </label>
        </div>

        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="Amount in ETH"
          className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          disabled={isLoading}
        />

        <button
          onClick={handleFund}
          disabled={isLoading}
          className="w-full px-4 py-2 bg-green-600 hover:bg-green-700 disabled:bg-green-400 rounded-lg text-white font-medium"
        >
          {isLoading ? "Processing..." : "Deposit ETH"}
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
