"use client";

import { useWallet } from "@/lib/useWallet";

export function ConnectWallet() {
  const { wallet, connect, disconnect, isLoading, error } = useWallet();

  if (wallet.isConnected) {
    return (
      <div className="flex items-center gap-4">
        <div className="text-sm">
          <p className="text-gray-400">Connected:</p>
          <p className="font-mono text-green-400">
            {wallet.address?.slice(0, 6)}...{wallet.address?.slice(-4)}
          </p>
        </div>
        <button
          onClick={disconnect}
          className="px-4 py-2 bg-red-600 hover:bg-red-700 rounded-lg text-white text-sm"
        >
          Disconnect
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <button
        onClick={connect}
        disabled={isLoading}
        className="px-6 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 rounded-lg text-white font-medium"
      >
        {isLoading ? "Connecting..." : "Connect Wallet"}
      </button>
      {error && <p className="text-red-400 text-sm">{error}</p>}
    </div>
  );
}
