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
  const lkSHTdata = useLkSht();
  const shtData = useSht();

  const { data } = useSWR(
    prices && shtData && lkSHTdata && userAddress && client && coinbase && housingSFTAbi
      ? { client, userAddress, lkSHTdata, coinbase, housingSFTAbi, shtData, prices }
      : null,
    async ({ userAddress, client, coinbase, lkSHTdata, housingSFTAbi, shtData, prices }) => {
      const [sht, lkSht, ..._projectsToken] = await Promise.all([
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
            abi: lkSHTdata.abi,
            address: lkSHTdata.address,
            functionName: "sftBalance",
            args: [userAddress],
          })
          .then(balances => {
            const { abi, ...params } = lkSHTdata;
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
      const projectsToken = _projectsToken.filter(({ balances }) => balances.length > 0);

      // Compute ownedAssets
      const assets: {
        symbol: string;
        tokenAddress: string;
        backgroundColor: string;
        value: string;
        qty: bigint;
        decimals: number;
      }[] = [];
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

      return { sht, lkSht, projectsToken, ownedAssets: assets };
    },
    { keepPreviousData: true },
  );

  if (!data) {
    return {
      sht: null,
      lkSht: null,
      projectsToken: null,
      ownedAssets: [],
      prices,
    };
  }

  return { ...data, prices };
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

      const shtPrice = Math.random() * 10;

      if (shtID) {
        prices[shtID] = shtPrice;
      }
      if (lkShtID) {
        prices[lkShtID] = shtPrice;
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
