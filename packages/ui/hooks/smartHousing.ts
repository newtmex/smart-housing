import useRawCallsInfo from "./useRawCallsInfo";
import useSWR from "swr";
import useSWRImmutable from "swr/immutable";
import { useAccount } from "wagmi";

export const useHousingStakingToken = () => {
  const { client, smartHousing, housingStakingSFTAbi } = useRawCallsInfo();
  const { address: userAddress } = useAccount();
  const { data: hstAddress } = useSWRImmutable(
    client && smartHousing ? { key: "smartHousing-HST-addrs", client, smartHousing } : null,
    async ({ client, smartHousing: { abi, address } }) => client.readContract({ abi, address, functionName: "hst" }),
  );

  const { data: nameNSymbol } = useSWRImmutable(
    client && smartHousing && hstAddress && housingStakingSFTAbi
      ? { key: "smartHousing-HST-dets", client, address: hstAddress, abi: housingStakingSFTAbi }
      : null,
    async ({ client, abi, address }) => {
      const [symbol, name] = await Promise.all([
        client.readContract({ abi, address, functionName: "symbol" }),
        client.readContract({ abi, address, functionName: "name" }),
      ]);

      return { name, symbol, address };
    },
  );

  const { data: sftBalance, mutate: refreshBalance } = useSWR(
    userAddress && client && smartHousing && hstAddress && housingStakingSFTAbi
      ? { key: "smartHousing-HST-balances", client, address: hstAddress, userAddress, abi: housingStakingSFTAbi }
      : null,
    async ({ userAddress, client, abi, address }) =>
      client.readContract({ abi, address, functionName: "sftBalance", args: [userAddress] }),
    {
      keepPreviousData: true,
    },
  );

  return { name: nameNSymbol?.name, symbol: nameNSymbol?.symbol, hstInfo: nameNSymbol, sftBalance, refreshBalance };
};
