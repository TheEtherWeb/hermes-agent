import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        cream: "#fbf6ee",
        ink: "#1c1917",
        ember: "#c2410c",
        sage: "#5b7a4a",
      },
      fontFamily: {
        display: ["ui-serif", "Georgia", "Cambria", "serif"],
      },
    },
  },
  plugins: [],
};

export default config;
