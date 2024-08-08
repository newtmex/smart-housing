import { useMemo } from "react";
import { useSht } from "./coinbase";
import { useProjects } from "./housingProject";
import { useLkSht } from "./projectFunding";
import useRawCallsInfo from "./useRawCallsInfo";
import BigNumber from "bignumber.js";
import useSWR from "swr";
import useSWRImmutable from "swr/immutable";
import { useAccount } from "wagmi";
import getColor from "~~/utils/getColor";

export const useAccountTokens = () => {
  const prices = useTokenPrices();

  const projects = useProjects();
  const { address: userAddress } = useAccount();
  const { client, coinbase, housingSFTAbi } = useRawCallsInfo();
  const lkSHT = useLkSht();
  const shtData = useSht();

  const { data } = useSWR(
    shtData && lkSHT && userAddress && client && coinbase && housingSFTAbi
      ? { client, userAddress, lkSHT, coinbase, housingSFTAbi, shtData }
      : null,
    async ({ userAddress, client, coinbase, lkSHT, housingSFTAbi, shtData }) => {
      const [userSht, userLkSht, ...projectsToken] = await Promise.all([
        client
          .readContract({
            abi: coinbase.abi,
            address: coinbase.address,
            functionName: "balanceOf",
            args: [userAddress],
          })
          .then(balance => ({ balance, ...shtData, address: coinbase.address })),
        client
          .readContract({
            abi: lkSHT.abi,
            address: lkSHT.address,
            functionName: "sftBalance",
            args: [userAddress],
          })
          .then(balances => {
            const { abi, ...params } = lkSHT;
            abi;

            return {
              ...params,
              balances,
              decimals: shtData.decimals,
            };
          }),
        ...projects.map(project =>
          client
            .readContract({
              abi: housingSFTAbi,
              address: project.projectData.data.tokenAddress,
              functionName: "sftBalance",
              args: [userAddress],
            })
            .then(balances => ({ ...project, balances })),
        ),
      ]);
      return [userSht, userLkSht, projectsToken.filter(({ balances }) => balances.length > 0)] as [
        typeof userSht,
        typeof userLkSht,
        typeof projectsToken,
      ];
    },
    { keepPreviousData: true },
  );

  const ownedAssets = useMemo(() => {
    const assets: {
      symbol: string;
      tokenAddress: string;
      backgroundColor: string;
      value: string;
      qty: bigint;
      decimals: number;
    }[] = [];

    if (!data) {
      return assets;
    }

    const [sht, lkSht, projectsToken] = data;

    for (const token of [sht, lkSht, ...projectsToken]) {
      if (!prices || ("balance" in token ? token.balance <= 0 : token.balances.length <= 0)) {
        continue;
      }

      const { symbol, tokenAddress, decimals } =
        "projectData" in token
          ? {
              symbol: token.projectData.sftDetails.symbol,
              tokenAddress: token.projectData.data.tokenAddress,
              decimals: 0,
            }
          : { symbol: token.symbol, tokenAddress: token.address, decimals: token.decimals };

      const tokenBalance =
        "balance" in token ? token.balance : token.balances.reduce((acc, cur) => acc + cur.amount, 0n);

      assets.push({
        symbol,
        tokenAddress,
        backgroundColor: getColor(tokenAddress, 5),
        qty: tokenBalance,
        decimals,
        value: BigNumber(tokenBalance.toString())
          .multipliedBy(prices[symbol].toFixed(2))
          .dividedBy(10 ** decimals)
          .toFixed(0),
      });
    }

    return assets;
  }, [data, prices]);

  if (!data) {
    return {
      sht: null,
      lkSht: null,
      projectsToken: null,
      ownedAssets,
      prices,
    };
  }

  const [sht, lkSht, projectsToken] = data;

  return { sht, lkSht, projectsToken, ownedAssets, prices };
};

// TODO get real values
export const useTokenPrices = () => {
  const projects = useProjects();
  const sht = useSht();
  const lkSht = useLkSht();

  return useSWRImmutable(
    sht && lkSht ? { key: "tokenPrices-Dummy", sht, lkSht, projects } : null,
    ({ lkSht: { symbol: lkShtID }, sht: { symbol: shtID }, projects }) => {
      const prices: { [key: string]: number } = {};

      if (shtID) {
        prices[shtID] = Math.random() * 10;
      }
      if (lkShtID) {
        prices[lkShtID] = Math.random() * 10;
      }

      projects.forEach(
        ({
          projectData: {
            sftDetails: { symbol: tokenId },
          },
        }) => {
          prices[tokenId] = Math.random() * 10;
        },
      );

      return prices;
    },
  ).data;
};
