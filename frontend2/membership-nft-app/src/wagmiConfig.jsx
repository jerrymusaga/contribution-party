import { http, createConfig } from "wagmi";
import { mainnet, sepolia } from "wagmi/chains";
import { getDefaultWallets } from "@rainbow-me/rainbowkit";

// You can replace this with your desired chains
const chains = [mainnet, sepolia];

const { connectors } = getDefaultWallets({
  appName: "Membership NFT DApp",
  projectId: "12cba34aff6618d10bab72a2aed5cdd1",
  chains,
});

export const config = createConfig({
  chains,
  connectors,
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(import.meta.env.VITE_SEPOLIA_RPC_URL || undefined),
  },
});

export const contractAddress = "0x9175fD8a8a07BA67Fd5191c2B12524ee07188cfA";
