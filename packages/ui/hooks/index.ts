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

  const { data, mutate } = useSWR(
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
        nonce: bigint;
      }[] = [];
      for (const token of [
        sht,
        ...lkSht.balances.map(({ amount, nonce }) => ({
          symbol: lkSht.symbol,
          tokenAddress: lkSht.address,
          balance: amount,
          nonce,
          decimals: lkSht.decimals,
        })),
        ...projectsToken.flatMap(
          ({
            balances,
            projectData: {
              sftDetails: { symbol },
              data: { tokenAddress },
            },
          }) =>
            balances.map(({ amount, nonce }) => ({
              symbol,
              tokenAddress,
              balance: amount,
              nonce,
              decimals: 0,
            })),
        ),
      ]) {
        if (!prices || token.balance <= 0) {
          continue;
        }

        const { symbol, tokenAddress, decimals, nonce } =
          "tokenAddress" in token
            ? {
                symbol: token.symbol,
                tokenAddress: token.tokenAddress,
                decimals: token.decimals,
                nonce: token.nonce,
              }
            : { symbol: token.symbol, tokenAddress: token.address, decimals: token.decimals, nonce: 0n };

        assets.push({
          symbol,
          tokenAddress,
          backgroundColor: getColor(tokenAddress, 5),
          qty: token.balance,
          decimals,
          value: prices[symbol].value(token.balance),
          nonce,
        });
      }

      return { sht, lkSht, projectsToken, ownedAssets: assets };
    },
    { keepPreviousData: true },
  );

  const refresh = () => mutate();

  if (!data) {
    return {
      sht: null,
      lkSht: null,
      projectsToken: null,
      ownedAssets: [],
      prices,
      refresh,
    };
  }

  return { ...data, prices, refresh };
};

// TODO get real values
export const useTokenPrices = () => {
  const projects = useProjects();
  const sht = useSht();
  const lkSht = useLkSht();

  return useSWRImmutable(
    sht && lkSht ? { key: "tokenPrices-Dummy", sht, lkSht, projects } : null,
    ({
      lkSht: { symbol: lkShtID, address: lkShtAddress },
      sht: { symbol: shtID, decimals: shtDecimals, address: shtAddress },
      projects,
    }) => {
      const prices: { [key: string]: { value: (amount: bigint) => string; price: number; decimals: number } } = {};
      const shtPrice: (typeof prices)[string] = {
        decimals: shtDecimals,
        price: Math.random() * 10,
        value(amount) {
          return BigNumber(amount.toString())
            .multipliedBy(this.price.toFixed(2))
            .dividedBy(10 ** this.decimals)
            .toFixed(0);
        },
      };

      prices[shtAddress] = prices[shtID] = prices[lkShtID] = prices[lkShtAddress] = shtPrice;

      projects.forEach(
        ({
          projectData: {
            sftDetails: { symbol: tokenId },
            data: { tokenAddress, projectAddress },
          },
        }) => {
          prices[projectAddress] =
            prices[tokenAddress] =
            prices[tokenId] =
              { ...shtPrice, price: Math.random() * 10, decimals: 0 };
        },
      );

      return prices;
    },
  ).data;
};
