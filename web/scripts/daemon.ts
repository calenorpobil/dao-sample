import dotenv from "dotenv";
import path from "path";
import fs from "fs";
import { JsonRpcProvider, Wallet, Contract, formatEther } from "ethers";

dotenv.config({ path: path.resolve(process.cwd(), ".env.local") });

const POLL_INTERVAL_MS = Number(process.env.DAEMON_POLL_INTERVAL_MS ?? "15000");

function log(msg: string): void {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}

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
  const reasons: string[] = [];

  if (p.executed) {
    return "already executed";
  }
  if (now <= p.votingDeadline) {
    const remaining = p.votingDeadline - now;
    reasons.push(`voting still active (${remaining}s remaining)`);
  }
  if (p.forVotes <= p.againstVotes) {
    reasons.push(`not approved (FOR=${p.forVotes} AGAINST=${p.againstVotes})`);
  }
  const execAt = p.votingDeadline + p.executionDelay;
  if (now <= execAt) {
    const remaining = execAt - now;
    reasons.push(`execution delay not elapsed (${remaining}s remaining)`);
  }
  if (treasuryBalance < p.amount) {
    reasons.push(
      `insufficient treasury (has ${formatEther(treasuryBalance)} ETH, needs ${formatEther(p.amount)} ETH)`
    );
  }

  return reasons.length === 0 ? "eligible" : reasons.join("; ");
}

async function checkAndExecute(dao: Contract, provider: JsonRpcProvider): Promise<void> {
  const count = Number(await dao.proposalCount());

  if (count === 0) {
    log("No proposals yet.");
    return;
  }

  // Wall-clock time: on anvil (automine) the latest block timestamp only advances
  // when a tx is mined and can lag real time by many seconds.
  // The contract will use the real block.timestamp when the tx is mined.
  const now = BigInt(Math.floor(Date.now() / 1000));
  const daoAddress = await dao.getAddress();
  const treasuryBalance = await provider.getBalance(daoAddress);

  log(`Checking ${count} proposal(s) — now: ${now}, treasury: ${formatEther(treasuryBalance)} ETH`);

  for (let id = 1; id <= count; id++) {
    const p: ProposalData = await dao.getProposal(id);
    const status = diagnose(p, now, treasuryBalance);

    if (status === "eligible") {
      log(`  Proposal #${id}: ELIGIBLE — executing...`);
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const tx = await (dao as any).executeProposal(id, { gasLimit: 500_000 });
      const receipt = await tx.wait();
      log(`  Proposal #${id}: executed. tx=${receipt.hash}`);
    } else if (status !== "already executed") {
      log(`  Proposal #${id}: not ready — ${status}`);
    }
  }
}

async function main(): Promise<void> {
  const rpcUrl = process.env.RPC_URL ?? "http://127.0.0.1:8545";
  const chainId = Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? "31337");
  const relayerKey = process.env.RELAYER_PRIVATE_KEY;
  const daoAddress = process.env.NEXT_PUBLIC_DAO_CONTRACT_ADDRESS;

  if (!relayerKey) {
    console.error("RELAYER_PRIVATE_KEY is not set");
    process.exit(1);
  }
  if (!daoAddress) {
    console.error("NEXT_PUBLIC_DAO_CONTRACT_ADDRESS is not set");
    process.exit(1);
  }

  const abiPath = path.resolve(process.cwd(), "src/lib/DAOVoting.abi.json");
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const DAO_ABI: any[] = JSON.parse(fs.readFileSync(abiPath, "utf-8"));

  const provider = new JsonRpcProvider(rpcUrl, chainId, { staticNetwork: true });
  const relayer = new Wallet(relayerKey, provider);
  const dao = new Contract(daoAddress, DAO_ABI, relayer);

  log(`Relayer : ${relayer.address}`);
  log(`DAO     : ${daoAddress}`);
  log(`RPC     : ${rpcUrl}`);
  log(`Poll    : every ${POLL_INTERVAL_MS / 1000}s`);
  log("Daemon started — watching for executable proposals...\n");

  const run = async (): Promise<void> => {
    try {
      await checkAndExecute(dao, provider);
    } catch (err) {
      log(`Error: ${(err as Error).message ?? String(err)}`);
    }
  };

  await run();
  setInterval(run, POLL_INTERVAL_MS);
}

main();
