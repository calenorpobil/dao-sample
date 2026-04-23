"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  ReactNode,
} from "react";
import type { WalletState } from "./types";
import { BrowserProvider } from "ethers";

const EXPECTED_CHAIN_ID = Number(process.env.NEXT_PUBLIC_CHAIN_ID || "31337");

interface WalletContextValue {
  wallet: WalletState;
  connect: () => Promise<void>;
  disconnect: () => void;
  isLoading: boolean;
  error: string | null;
}

const WalletContext = createContext<WalletContextValue | null>(null);

export function WalletProvider({ children }: { children: ReactNode }) {
  const [wallet, setWallet] = useState<WalletState>({
    address: null,
    balance: "0",
    isConnected: false,
    chainId: null,
  });
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const connect = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      if (!window.ethereum) throw new Error("MetaMask not found");

      const provider = new BrowserProvider(window.ethereum);
      const accounts = await window.ethereum.request({
        method: "eth_requestAccounts",
      });

      if (!accounts || accounts.length === 0) {
        throw new Error("No accounts found");
      }

      const signer = await provider.getSigner();
      const address = await signer.getAddress();
      const balance = await provider.getBalance(address);
      const network = await provider.getNetwork();

      if (Number(network.chainId) !== EXPECTED_CHAIN_ID) {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: `0x${EXPECTED_CHAIN_ID.toString(16)}` }],
        });
        return;
      }

      setWallet({
        address,
        balance: balance.toString(),
        isConnected: true,
        chainId: Number(network.chainId),
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Connection failed");
      setWallet((prev) => ({ ...prev, isConnected: false }));
    } finally {
      setIsLoading(false);
    }
  }, []);

  const disconnect = useCallback(() => {
    setWallet({
      address: null,
      balance: "0",
      isConnected: false,
      chainId: null,
    });
  }, []);

  useEffect(() => {
    const handleAccountsChanged = (accounts: string[]) => {
      if (accounts.length === 0) {
        disconnect();
      } else {
        connect();
      }
    };

    const handleChainChanged = () => {
      window.location.reload();
    };

    if (window.ethereum) {
      window.ethereum.on("accountsChanged", handleAccountsChanged);
      window.ethereum.on("chainChanged", handleChainChanged);

      return () => {
        window.ethereum?.removeListener("accountsChanged", handleAccountsChanged);
        window.ethereum?.removeListener("chainChanged", handleChainChanged);
      };
    }
    return undefined;
  }, [connect, disconnect]);

  return (
    <WalletContext.Provider value={{ wallet, connect, disconnect, isLoading, error }}>
      {children}
    </WalletContext.Provider>
  );
}

export function useWallet() {
  const ctx = useContext(WalletContext);
  if (!ctx) {
    throw new Error("useWallet must be used within a WalletProvider");
  }
  return ctx;
}
