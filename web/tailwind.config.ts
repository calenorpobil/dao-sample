import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: "#1F2937",
        secondary: "#6366F1",
        accent: "#06B6D4",
      },
    },
  },
  plugins: [],
};

export default config;
