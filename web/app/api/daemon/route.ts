import { NextResponse } from "next/server";
import fs from "fs";
import path from "path";
import { JsonRpcProvider, Wallet, Contract, formatEther } from "ethers";

interface ProposalData {
  id: bigint;
  recipient: string;
  amount: bigint;
  description: string;
  votingDeadline: bigint;
  executionDelay: bigint;
  forVotes: bigint;
  againstVotes: bigint;
  abstainVotes: bigint;
  executed: boolean;
}

function diagnose(p: ProposalData, now: bigint, treasuryBalance: bigint): string {
  if (p.executed) return "already executed";

  const reasons: string[] = [];

  if (now <= p.votingDeadline) {
    reasons.push(`voting still active (${p.votingDeadline - now}s remaining)`);
  }
  if (p.forVotes <= p.againstVotes) {
    reasons.push(`not approved (FOR=${p.forVotes} AGAINST=${p.againstVotes})`);
  }
  const execAt = p.votingDeadline + p.executionDelay;
  if (now <= execAt) {
    reasons.push(`execution delay not elapsed (${execAt - now}s remaining)`);
  }
  if (treasuryBalance < p.amount) {
    reasons.push(
      `insufficient treasury (has ${formatEther(treasuryBalance)} ETH, needs ${formatEther(p.amount)} ETH)`
    );
  }

  return reasons.length === 0 ? "eligible" : reasons.join("; ");
}

export async function GET() {
  const rpcUrl = process.env.RPC_URL ?? "http://127.0.0.1:8545";
  const chainId = Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? "31337");
  const relayerKey = process.env.RELAYER_PRIVATE_KEY;
  const daoAddress = process.env.NEXT_PUBLIC_DAO_CONTRACT_ADDRESS;

  if (!relayerKey || !daoAddress) {
    return NextResponse.json(
      { error: "RELAYER_PRIVATE_KEY or NEXT_PUBLIC_DAO_CONTRACT_ADDRESS not set" },
      { status: 500 }
    );
  }

  const abiPath = path.resolve(process.cwd(), "src/lib/DAOVoting.abi.json");
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const DAO_ABI: any[] = JSON.parse(fs.readFileSync(abiPath, "utf-8"));

  const provider = new JsonRpcProvider(rpcUrl, chainId, { staticNetwork: true });
  const relayer = new Wallet(relayerKey, provider);
  const dao = new Contract(daoAddress, DAO_ABI, relayer);

  const count = Number(await dao.proposalCount());

  if (count === 0) {
    return NextResponse.json({ checked: 0, executed: [], skipped: [] });
  }

  const now = BigInt(Math.floor(Date.now() / 1000));
  const treasuryBalance = await provider.getBalance(daoAddress);

  const executed: number[] = [];
  const skipped: { id: number; reason: string }[] = [];

  for (let id = 1; id <= count; id++) {
    const p: ProposalData = await dao.getProposal(id);
    const status = diagnose(p, now, treasuryBalance);

    if (status === "eligible") {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const tx = await (dao as any).executeProposal(id, { gasLimit: 500_000 });
      await tx.wait();
      executed.push(id);
    } else if (status !== "already executed") {
      skipped.push({ id, reason: status });
    }
  }

  return NextResponse.json({ checked: count, executed, skipped });
}
