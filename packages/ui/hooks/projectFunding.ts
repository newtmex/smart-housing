import useRawCallsInfo from "./useRawCallsInfo";
import useSWRImmutable from "swr/immutable";

export const useLkSht = () => {
  const { client, projectFunding, lkSHTAbi } = useRawCallsInfo();

  return useSWRImmutable(
    client && projectFunding && lkSHTAbi ? { key: "project-funding-LKSHT-id", client, projectFunding, lkSHTAbi } : null,
    async ({ client, projectFunding, lkSHTAbi }) => {
      const lkSHTAddr = await client.readContract({
        abi: projectFunding.abi,
        address: projectFunding.address,
        functionName: "lkSht",
      });

      const [name, symbol] = await client.readContract({
        abi: lkSHTAbi,
        address: lkSHTAddr,
        functionName: "tokenInfo",
      });

      return { name, symbol, address: lkSHTAddr, abi: lkSHTAbi };
    },
  ).data;
};
