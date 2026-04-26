/**
 * Integration tests: GET /api/daemon
 *
 * Verifies the daemon route correctly identifies and executes
 * eligible proposals, using a mocked blockchain layer.
 */

const mockReadFileSync = jest.fn().mockReturnValue("[]");

jest.mock("fs", () => ({
  __esModule: true,
  default: { readFileSync: mockReadFileSync },
  readFileSync: mockReadFileSync,
}));

const mockGetProposal = jest.fn();
const mockProposalCount = jest.fn();
const mockExecuteProposal = jest.fn();
const mockGetBalance = jest.fn();

jest.mock("ethers", () => {
  const actual = jest.requireActual("ethers");
  return {
    ...actual,
    JsonRpcProvider: jest.fn().mockImplementation(() => ({
      getBalance: mockGetBalance,
    })),
    Wallet: jest.fn().mockImplementation(() => ({ address: "0xRelayer" })),
    Contract: jest.fn().mockImplementation(() => ({
      proposalCount: mockProposalCount,
      getProposal: mockGetProposal,
      executeProposal: mockExecuteProposal,
      getAddress: jest.fn().mockResolvedValue("0xDAO"),
    })),
  };
});

function makeRequest(): Request {
  return new Request("http://localhost/api/daemon", { method: "GET" });
}

const NOW_SEC = BigInt(Math.floor(Date.now() / 1000));

// A proposal that passed voting and execution delay
const eligibleProposal = {
  id: BigInt(1),
  recipient: "0xRecipient",
  amount: BigInt(1e17), // 0.1 ETH
  description: "Test",
  votingDeadline: NOW_SEC - BigInt(200),
  executionDelay: BigInt(60),
  forVotes: BigInt(5),
  againstVotes: BigInt(2),
  abstainVotes: BigInt(0),
  executed: false,
};

// A proposal still in voting period
const activeProposal = {
  ...eligibleProposal,
  id: BigInt(2),
  votingDeadline: NOW_SEC + BigInt(3600),
};

describe("GET /api/daemon", () => {
  const OLD_ENV = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...OLD_ENV };
    mockGetProposal.mockReset();
    mockProposalCount.mockReset();
    mockExecuteProposal.mockReset();
    mockGetBalance.mockReset();
    mockReadFileSync.mockReturnValue(JSON.stringify([]));
  });

  afterAll(() => {
    process.env = OLD_ENV;
  });

  it("returns 500 when env vars are missing", async () => {
    delete process.env.RELAYER_PRIVATE_KEY;
    delete process.env.NEXT_PUBLIC_DAO_CONTRACT_ADDRESS;

    const { GET } = await import("@/app/api/daemon/route");
    const res = await GET();

    expect(res.status).toBe(500);
    const json = await res.json();
    expect(json.error).toMatch(/not set/);
  });

  it("returns empty result when there are no proposals", async () => {
    process.env.RELAYER_PRIVATE_KEY = "0xkey";
    process.env.NEXT_PUBLIC_DAO_CONTRACT_ADDRESS = "0xDAO";

    mockProposalCount.mockResolvedValueOnce(BigInt(0));

    const { GET } = await import("@/app/api/daemon/route");
    const res = await GET();

    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json).toEqual({ checked: 0, executed: [], skipped: [] });
  });

  it("executes an eligible proposal and skips an active one", async () => {
    process.env.RELAYER_PRIVATE_KEY = "0xkey";
    process.env.NEXT_PUBLIC_DAO_CONTRACT_ADDRESS = "0xDAO";
    process.env.NEXT_PUBLIC_CHAIN_ID = "31337";

    mockProposalCount.mockResolvedValueOnce(BigInt(2));
    mockGetBalance.mockResolvedValueOnce(BigInt(1e18)); // 1 ETH treasury
    mockGetProposal
      .mockResolvedValueOnce(eligibleProposal)
      .mockResolvedValueOnce(activeProposal);

    const mockWait = jest.fn().mockResolvedValueOnce({ hash: "0xtx" });
    mockExecuteProposal.mockResolvedValueOnce({ wait: mockWait });

    const { GET } = await import("@/app/api/daemon/route");
    const res = await GET();

    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.checked).toBe(2);
    expect(json.executed).toContain(1);
    expect(json.skipped.length).toBe(1);
    expect(json.skipped[0].id).toBe(2);
    expect(mockExecuteProposal).toHaveBeenCalledTimes(1);
  });

  it("skips an already-executed proposal silently", async () => {
    process.env.RELAYER_PRIVATE_KEY = "0xkey";
    process.env.NEXT_PUBLIC_DAO_CONTRACT_ADDRESS = "0xDAO";

    mockProposalCount.mockResolvedValueOnce(BigInt(1));
    mockGetBalance.mockResolvedValueOnce(BigInt(1e18));
    mockGetProposal.mockResolvedValueOnce({ ...eligibleProposal, executed: true });

    const { GET } = await import("@/app/api/daemon/route");
    const res = await GET();

    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.executed).toHaveLength(0);
    expect(json.skipped).toHaveLength(0);
    expect(mockExecuteProposal).not.toHaveBeenCalled();
  });
});
