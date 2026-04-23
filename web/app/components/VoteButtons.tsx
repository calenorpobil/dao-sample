"use client";

import { useState } from "react";
import { VoteType } from "@/lib/types";

interface VoteButtonsProps {
  userVote: VoteType | null;
  onVote: (voteType: VoteType) => Promise<void>;
}

export function VoteButtons({ userVote, onVote }: VoteButtonsProps) {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleVote = async (voteType: VoteType) => {
    setIsLoading(true);
    setError(null);

    try {
      await onVote(voteType);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Vote failed");
    } finally {
      setIsLoading(false);
    }
  };

  const buttons = [
    { type: VoteType.FOR, label: "Vote For", color: "bg-green-600 hover:bg-green-700" },
    { type: VoteType.AGAINST, label: "Vote Against", color: "bg-red-600 hover:bg-red-700" },
    { type: VoteType.ABSTAIN, label: "Abstain", color: "bg-gray-600 hover:bg-gray-700" },
  ];

  return (
    <div className="space-y-2">
      <div className="flex gap-2">
        {buttons.map(({ type, label, color }) => (
          <button
            key={type}
            onClick={() => handleVote(type)}
            disabled={isLoading}
            className={`flex-1 px-3 py-2 rounded-lg text-white text-sm font-medium transition ${color} disabled:opacity-50 ${
              userVote === type ? "ring-2 ring-white" : ""
            }`}
          >
            {label}
            {userVote === type && " ✓"}
          </button>
        ))}
      </div>
      {error && <p className="text-red-400 text-xs">{error}</p>}
    </div>
  );
}
