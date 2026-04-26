/**
 * Integration tests: frontend relay client (lib/metaTx.ts)
 *
 * Tests the fetch calls made by relayMetaTx to the backend /api/relay endpoint.
 * This is the frontend side of the frontend-backend boundary.
 */

import { relayMetaTx } from "@/lib/metaTx";
import type { SignedMetaTx } from "@/lib/types";

const SIGNED_TX: SignedMetaTx = {
  from: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  to: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
  value: "0",
  gas: 500000,
  nonce: 0,
  data: "0xdeadbeef",
  signature: "0xsig",
};

describe("relayMetaTx (frontend → /api/relay)", () => {
  beforeEach(() => {
    global.fetch = jest.fn();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("POSTs the signed tx to /api/relay with JSON content-type", async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => ({ success: true, hash: "0xtx", blockNumber: 1 }),
    });

    await relayMetaTx(SIGNED_TX);

    expect(global.fetch).toHaveBeenCalledWith(
      "/api/relay",
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({ "Content-Type": "application/json" }),
        body: JSON.stringify(SIGNED_TX),
      })
    );
  });

  it("returns the response JSON on success", async () => {
    const payload = { success: true, hash: "0xtx", blockNumber: 5 };
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => payload,
    });

    const result = await relayMetaTx(SIGNED_TX);

    expect(result).toEqual(payload);
  });

  it("throws an Error with the server message on non-ok response", async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      json: async () => ({ message: "nonce too low" }),
    });

    await expect(relayMetaTx(SIGNED_TX)).rejects.toThrow("nonce too low");
  });

  it("throws a generic error when the server returns no message", async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      json: async () => ({}),
    });

    await expect(relayMetaTx(SIGNED_TX)).rejects.toThrow("Relay failed");
  });
});
