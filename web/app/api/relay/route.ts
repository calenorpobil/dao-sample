import { NextResponse } from "next/server";
import { JsonRpcProvider, Wallet, Contract } from "ethers";
import type { SignedMetaTx } from "@/lib/types";

const RPC_URL = process.env.RPC_URL || "http://127.0.0.1:8545";
const RELAYER_PRIVATE_KEY = process.env.RELAYER_PRIVATE_KEY;
const FORWARDER_ADDRESS = process.env.NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS;

const FORWARDER_ABI = [
  "function execute(tuple(address from, address to, uint256 value, uint256 gas, uint256 nonce, bytes data) req, bytes signature) external payable",
];

export async function POST(request: Request) {
  try {
    if (!RELAYER_PRIVATE_KEY || !FORWARDER_ADDRESS) {
      return NextResponse.json(
        { message: "Relayer not configured" },
        { status: 500 }
      );
    }

    const body: SignedMetaTx = await request.json();

    const { from, to, value, data, nonce, signature } = body;

    if (!from || !to || !data || signature === undefined) {
      return NextResponse.json(
        { message: "Invalid request body" },
        { status: 400 }
      );
    }

    const provider = new JsonRpcProvider(RPC_URL);
    const relayer = new Wallet(RELAYER_PRIVATE_KEY, provider);
    const forwarder = new Contract(FORWARDER_ADDRESS, FORWARDER_ABI, relayer);

    const forwardRequest = {
      from,
      to,
      value: value || "0",
      gas: 500000,
      nonce: BigInt(nonce),
      data,
    };

    const tx = await forwarder.execute(forwardRequest, signature, {
      gasLimit: 500000,
    });

    const receipt = await tx.wait();

    return NextResponse.json({
      success: true,
      hash: tx.hash,
      blockNumber: receipt?.blockNumber,
    });
  } catch (error) {
    console.error("Relay error:", error);

    return NextResponse.json(
      {
        message:
          error instanceof Error ? error.message : "Relay failed",
      },
      { status: 500 }
    );
  }
}
