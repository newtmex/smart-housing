"use client";

import React from "react";
import { RainbowKitProvider, darkTheme } from "@rainbow-me/rainbowkit";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider } from "wagmi";
import { wagmiConfig } from "~~/services/web3/wagmiConfig";

const queryClient = new QueryClient();

export default function AppProvider({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      <WagmiProvider config={wagmiConfig}>
        <RainbowKitProvider theme={darkTheme()}>{children}</RainbowKitProvider>
      </WagmiProvider>
    </QueryClientProvider>
  );
}
