import { BrowserProvider, JsonRpcProvider, Contract } from "ethers";
import DAO_ABI_JSON from "../src/lib/DAOVoting.abi.json";
import FORWARDER_ABI_JSON from "../src/lib/MinimalForwarder.abi.json";

// ABI generado por Foundry — fuente de verdad
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const DAO_ABI: any[] = DAO_ABI_JSON;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const FORWARDER_ABI: any[] = FORWARDER_ABI_JSON;

// Para lecturas de chain — usa JsonRpcProvider directo, sin pasar por MetaMask
export function getReadProvider(): JsonRpcProvider {
  const rpc = process.env.NEXT_PUBLIC_RPC_URL || "http://127.0.0.1:8545";
  const chainId = Number(process.env.NEXT_PUBLIC_CHAIN_ID || "31337");
  return new JsonRpcProvider(rpc, chainId, { staticNetwork: true });
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
