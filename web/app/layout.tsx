import type { Metadata } from "next";
import "./globals.css";
import { WalletProvider } from "@/lib/useWallet";

export const metadata: Metadata = {
  title: "DAO Voting Platform",
  description: "Gasless voting with meta-transactions",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-slate-950 text-slate-50">
        <WalletProvider>
          <header className="border-b border-gray-700 bg-gray-900">
            <div className="max-w-7xl mx-auto px-4 py-4 flex justify-between items-center">
              <h1 className="text-2xl font-bold">DAO Voting</h1>
              <p className="text-gray-400 text-sm">Gasless Voting Platform</p>
            </div>
          </header>

          <main className="max-w-7xl mx-auto px-4 py-8">{children}</main>

          <footer className="border-t border-gray-700 bg-gray-900 mt-12">
            <div className="max-w-7xl mx-auto px-4 py-6 text-center text-gray-400 text-sm">
              Built with Next.js 15 + Foundry + EIP-2771
            </div>
          </footer>
        </WalletProvider>
      </body>
    </html>
  );
}
