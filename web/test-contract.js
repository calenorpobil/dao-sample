const { JsonRpcProvider, Contract } = require("ethers");
const fs = require("fs");

// Leer .env.local manualmente
const envContent = fs.readFileSync(".env.local", "utf-8");
const env = {};
envContent.split("\n").forEach(line => {
  const [key, value] = line.split("=");
  if (key && value) env[key.trim()] = value.trim();
});

const rpc = env.NEXT_PUBLIC_RPC_URL || "http://127.0.0.1:8545";
const daoAddress = env.NEXT_PUBLIC_DAO_CONTRACT_ADDRESS;
const ABI = JSON.parse(fs.readFileSync("./src/lib/DAOVoting.abi.json", "utf-8")).abi;

console.log("RPC URL:", rpc);
console.log("DAO Address:", daoAddress);
console.log("ABI Functions:", ABI.filter(x => x.name).map(x => x.name).slice(0, 10));

async function test() {
  try {
    const provider = new JsonRpcProvider(rpc);
    const contract = new Contract(daoAddress, ABI, provider);
    
    console.log("\n--- Testing proposalCount ---");
    const count = await contract.proposalCount();
    console.log("✓ proposalCount() =", count.toString());
  } catch (err) {
    console.error("✗ Error calling proposalCount():");
    console.error("  Code:", err.code);
    console.error("  Message:", err.message);
  }
  
  try {
    const provider = new JsonRpcProvider(rpc);
    const bytecode = await provider.getCode(daoAddress);
    console.log("\n--- Contract Status ---");
    console.log("Bytecode at address:", bytecode.length > 2 ? `YES (${bytecode.length} bytes)` : "NO (empty/EOA)");
  } catch (err) {
    console.error("✗ Error getting bytecode:", err.message);
  }
}

test();
