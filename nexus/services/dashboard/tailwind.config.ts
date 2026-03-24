import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        nexus: {
          bg: "#0a0e1a",
          card: "#111827",
          border: "#1f2937",
          accent: "#3b82f6",
          buy: "#10b981",
          sell: "#ef4444",
          neutral: "#6b7280",
        },
      },
    },
  },
  plugins: [],
};

export default config;
