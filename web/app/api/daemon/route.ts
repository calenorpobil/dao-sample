import { NextResponse } from "next/server";
import { JsonRpcProvider, Wallet, Contract } from "ethers";

const RPC_URL = process.env.RPC_URL || "http://127.0.0.1:8545";
const RELAYER_PRIVATE_KEY = process.env.RELAYER_PRIVATE_KEY;
const DAO_ADDRESS = process.env.NEXT_PUBLIC_DAO_CONTRACT_ADDRESS;

const DAO_ABI = [
  "function proposalCount() external view returns (uint256)",
  "function getProposal(uint256 proposalId) external view returns (uint256 id, address recipient, uint256 amount, uint256 votingDeadline, uint256 executionDelay, bool executed, uint256 forVotes, uint256 againstVotes, uint256 abstainVotes, string description)",
  "function executeProposal(uint256 proposalId) external",
  "function canExecute(uint256 proposalId) external view returns (bool)",
];

async function executeEligibleProposals() {
  if (!RELAYER_PRIVATE_KEY || !DAO_ADDRESS) {
    throw new Error("Configuration missing");
  }

  const provider = new JsonRpcProvider(RPC_URL);
  const relayer = new Wallet(RELAYER_PRIVATE_KEY, provider);
  const dao = new Contract(DAO_ADDRESS, DAO_ABI, relayer);

  const count = await dao.proposalCount();
  const now = Math.floor(Date.now() / 1000);
  const executed = [];

  for (let i = 1; i <= count; i++) {
    const proposal = await dao.getProposal(i);
    // [0]id [1]recipient [2]amount [3]votingDeadline [4]executionDelay [5]executed [6]forVotes [7]againstVotes
    const [, , , votingDeadline, executionDelay, executed_, forVotes, againstVotes] = proposal;

    const isEligible =
      !executed_ &&
      BigInt(now) >= BigInt(votingDeadline) &&
      BigInt(now) >= BigInt(executionDelay) &&
      BigInt(forVotes) > BigInt(againstVotes);

    if (isEligible) {
      try {
        const tx = await dao.executeProposal(i, { gasLimit: 500000 });
        await tx.wait();
        executed.push(i);
        console.log(`Executed proposal ${i}`);
      } catch (err) {
        console.error(`Failed to execute proposal ${i}:`, err);
      }
    }
  }

  return executed;
}

export async function POST() {
  try {
    const executed = await executeEligibleProposals();

    return NextResponse.json({
      success: true,
      executed,
      count: executed.length,
    });
  } catch (error) {
    console.error("Daemon error:", error);

    return NextResponse.json(
      {
        message:
          error instanceof Error ? error.message : "Daemon execution failed",
      },
      { status: 500 }
    );
  }
}

export async function GET() {
  return POST();
}
