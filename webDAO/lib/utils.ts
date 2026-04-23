export function truncateAddress(address: string, length = 6): string {
  if (!address) return "";
  return `${address.slice(0, length)}...${address.slice(-4)}`;
}

export function formatDate(timestamp: number): string {
  const date = new Date(timestamp * 1000);
  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function isValidAddress(address: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(address);
}

export function getVotePercentage(votes: number, total: number): string {
  if (total === 0) return "0%";
  return `${Math.round((votes / total) * 100)}%`;
}
