import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { http } from "viem";
import { sepolia } from "wagmi/chains";

export const config = getDefaultConfig({
  appName: process.env.NEXT_PUBLIC_SITE_NAME!,
  projectId: process.env.NEXT_PUBLIC_REOWN_PROJECT_ID!,
  chains: [
    sepolia,
    // ...(process.env.DEV_ENV === "true" ? [sepolia] : []),
  ],
//   transports: {
//     [sepolia.id]: http(process.env.NEXT_PUBLIC_ALCHEMY_HTTP!),
//   },
  ssr: true,
});
