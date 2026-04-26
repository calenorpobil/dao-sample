/**
 * Integration tests: POST /api/relay
 *
 * Tests the boundary between the frontend relay client (metaTx.ts)
 * and the backend relay route handler. The blockchain layer is mocked
 * so no node is required.
 */

const mockExecute = jest.fn();
const mockWait = jest.fn();

jest.mock("ethers", () => {
  const actual = jest.requireActual("ethers");
  return {
    ...actual,
    JsonRpcProvider: jest.fn().mockImplementation(() => ({})),
    Wallet: jest.fn().mockImplementation(() => ({ address: "0xRelayer" })),
    Contract: jest.fn().mockImplementation(() => ({
      execute: mockExecute,
    })),
  };
});

// Helper: build a minimal NextRequest-compatible Request
function makeRequest(body: unknown, method = "POST"): Request {
  return new Request("http://localhost/api/relay", {
    method,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

const VALID_BODY = {
  from: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  to: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
  value: "0",
  gas: 500000,
  nonce: 0,
  data: "0xdeadbeef",
  signature: "0xsig",
};

describe("POST /api/relay", () => {
  const OLD_ENV = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...OLD_ENV };
    mockExecute.mockReset();
    mockWait.mockReset();
  });

  afterAll(() => {
    process.env = OLD_ENV;
  });

  it("returns 500 when relayer is not configured", async () => {
    delete process.env.RELAYER_PRIVATE_KEY;
    delete process.env.NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS;

    const { POST } = await import("@/app/api/relay/route");
    const res = await POST(makeRequest(VALID_BODY));

    expect(res.status).toBe(500);
    const json = await res.json();
    expect(json.message).toBe("Relayer not configured");
  });

  it("returns 400 when required fields are missing", async () => {
    process.env.RELAYER_PRIVATE_KEY = "0xdeadbeef";
    process.env.NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS = "0xForwarder";

    const { POST } = await import("@/app/api/relay/route");
    const res = await POST(makeRequest({ from: "0xabc" })); // missing to, data, signature

    expect(res.status).toBe(400);
    const json = await res.json();
    expect(json.message).toBe("Invalid request body");
  });

  it("returns 200 with tx hash on successful relay", async () => {
    process.env.RELAYER_PRIVATE_KEY = "0xdeadbeef";
    process.env.NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS = "0xForwarder";
    process.env.NEXT_PUBLIC_CHAIN_ID = "31337";

    mockWait.mockResolvedValueOnce({ blockNumber: 1 });
    mockExecute.mockResolvedValueOnce({ hash: "0xtxhash", wait: mockWait });

    // Re-import so Contract mock picks up the execute mock
    const { POST } = await import("@/app/api/relay/route");
    const res = await POST(makeRequest(VALID_BODY));

    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.success).toBe(true);
    expect(json.hash).toBe("0xtxhash");
    expect(json.blockNumber).toBe(1);
  });

  it("returns 500 when the blockchain call throws", async () => {
    process.env.RELAYER_PRIVATE_KEY = "0xdeadbeef";
    process.env.NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS = "0xForwarder";

    mockExecute.mockRejectedValueOnce(new Error("nonce too low"));

    const { POST } = await import("@/app/api/relay/route");
    const res = await POST(makeRequest(VALID_BODY));

    expect(res.status).toBe(500);
    const json = await res.json();
    expect(json.message).toBe("nonce too low");
  });
});
