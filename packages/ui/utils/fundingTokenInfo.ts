import { isZeroAddress } from "./scaffold-eth/common";
import { erc20Abi } from "viem";
import { UsePublicClientReturnType } from "wagmi";

export default async function getFundingTokenInfo({
  tokenAddress,
  client,
}: {
  tokenAddress: string;
  client: UsePublicClientReturnType;
}) {
  if (isZeroAddress(tokenAddress)) {
    // TODO set these values from config
    return { name: "BNB Chain Coin", decimals: 18, symbol: "BNB", isNative: true, tokenAddress };
  }

  if (!client) {
    throw new Error("Client not set");
  }

  const [symbol, name, decimals] = await Promise.all([
    client.readContract({
      abi: erc20Abi,
      address: tokenAddress,
      functionName: "symbol",
    }),
    client.readContract({
      abi: erc20Abi,
      address: tokenAddress,
      functionName: "name",
    }),
    client.readContract({
      abi: erc20Abi,
      address: tokenAddress,
      functionName: "decimals",
    }),
  ]);

  return { symbol, name, decimals, isNative: false, tokenAddress };
}
