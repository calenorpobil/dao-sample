import { BrowserProvider, getAddress } from "ethers";
import type { MetaTxData, SignedMetaTx } from "./types";

const FORWARD_REQUEST_TYPE = [
  { name: "from", type: "address" },
  { name: "to", type: "address" },
  { name: "value", type: "uint256" },
  { name: "gas", type: "uint256" },
  { name: "nonce", type: "uint256" },
  { name: "data", type: "bytes" },
];

export async function signMetaTx(
  metaTx: MetaTxData,
  forwarderAddress: string
): Promise<SignedMetaTx> {
  if (!window.ethereum) throw new Error("MetaMask not found");

  const provider = new BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  const chainId = (await provider.getNetwork()).chainId;

  const domain = {
    name: "MinimalForwarder",
    version: "1",
    chainId: Number(chainId),
    verifyingContract: getAddress(forwarderAddress),
  };

  const types = {
    ForwardRequest: FORWARD_REQUEST_TYPE,
  };

  const message = {
    from: getAddress(metaTx.from),
    to: getAddress(metaTx.to),
    value: metaTx.value,
    gas: metaTx.gas,
    nonce: metaTx.nonce.toString(),
    data: metaTx.data,
  };

  const signature = await signer.signTypedData(domain, types, message);

  return { ...metaTx, signature };
}

export async function relayMetaTx(signedMetaTx: SignedMetaTx) {
  const response = await fetch("/api/relay", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(signedMetaTx),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || "Relay failed");
  }

  return response.json();
}
