"use client";

import { useEffect, useState } from "react";
import { formatEther } from "ethers";
import { useWallet } from "@/lib/useWallet";
import { getDAOContract, getReadProvider } from "@/lib/contracts";
import { ConnectWallet } from "./components/ConnectWallet";
import { FundingPanel } from "./components/FundingPanel";
import { CreateProposal } from "./components/CreateProposal";
import { ProposalList } from "./components/ProposalList";

export default function Home() {
  const { wallet } = useWallet();
  const [userBalance, setUserBalance] = useState("0");
  const [totalBalance, setTotalBalance] = useState("0");
  const [canCreate, setCanCreate] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    if (wallet.isConnected && wallet.address) {
      loadBalances();
      const interval = setInterval(loadBalances, 5000);
      return () => clearInterval(interval);
    }
    return undefined;
  }, [wallet.isConnected, wallet.address]);

  const loadBalances = async () => {
    if (!wallet.address) return;

    try {
      const daoContract = getDAOContract(getReadProvider()) as any;

      const user = await daoContract.getUserBalance(wallet.address);
      const total = await daoContract.getTotalDeposited();

      setUserBalance(user.toString());
      setTotalBalance(total.toString());

      const requiredBalance = BigInt(total) / BigInt(10);
      setCanCreate(BigInt(user) >= requiredBalance);
    } catch (err) {
      console.error("Failed to load balances:", err);
    }
  };

  return (
    <div className="space-y-8">
      {/* Header */}
      <section className="bg-gray-900 p-8 rounded-lg border border-gray-700">
        <div className="flex justify-between items-center">
          <div>
            <h1 className="text-3xl font-bold mb-2">DAO Voting Platform</h1>
            <p className="text-gray-400">
              Vote on proposals without paying gas — meta-transactions powered by EIP-2771
            </p>
          </div>
          <ConnectWallet />
        </div>
      </section>

      {wallet.isConnected && wallet.address && (
        <>
          {/* DAO Stats Section */}
          <section className="bg-gradient-to-r from-blue-900 to-blue-800 p-8 rounded-lg border border-blue-700">
            <h2 className="text-2xl font-bold mb-6">DAO Stats</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="bg-gray-800 p-6 rounded-lg">
                <p className="text-gray-400 text-sm mb-2">Your Balance</p>
                <p className="text-3xl font-bold text-green-400">
                  {formatEther(userBalance)} ETH
                </p>
                <p className="text-xs text-gray-500 mt-2">DAO balance you control</p>
              </div>
              <div className="bg-gray-800 p-6 rounded-lg">
                <p className="text-gray-400 text-sm mb-2">Total DAO Balance</p>
                <p className="text-3xl font-bold text-blue-400">
                  {formatEther(totalBalance)} ETH
                </p>
                <p className="text-xs text-gray-500 mt-2">All user deposits combined</p>
              </div>
              <div className="bg-gray-800 p-6 rounded-lg">
                <p className="text-gray-400 text-sm mb-2">Proposal Creation</p>
                <p className={`text-3xl font-bold ${canCreate ? "text-green-400" : "text-red-400"}`}>
                  {canCreate ? "✓ Enabled" : "✗ Locked"}
                </p>
                <p className="text-xs text-gray-500 mt-2">
                  {canCreate ? "You can create" : "Need 10% of DAO balance"}
                </p>
              </div>
            </div>
          </section>

          {/* Fund DAO Section */}
          <section>
            <FundingPanel
userBalance={userBalance}
              totalBalance={totalBalance}
              onSuccess={() => {
                setRefreshKey((k) => k + 1);
                loadBalances();
              }}
            />
          </section>

          {/* Create Proposal Section */}
          <section>
            <CreateProposal
              canCreate={canCreate}
              onSuccess={() => setRefreshKey((k) => k + 1)}
            />
          </section>
        </>
      )}

      {/* Proposals Section */}
      <section>
        <h2 className="text-2xl font-bold mb-6">Proposals</h2>
        <ProposalList key={refreshKey} userAddress={wallet.address} />
      </section>
    </div>
  );
}
