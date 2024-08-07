import useRawCallsInfo from "./useRawCallsInfo";
import useSWRImmutable from "swr/immutable";

export const useSht = () => {
  const { client, coinbase } = useRawCallsInfo();

  return useSWRImmutable(
    client && coinbase ? { key: "project-funding-LKSHT-id", client, coinbase } : null,
    async ({ client, coinbase: { abi, address } }) => {
      const [symbol, decimals, name] = await Promise.all([
        client.readContract({ abi, address, functionName: "symbol" }),
        client.readContract({ abi, address, functionName: "decimals" }),
        client.readContract({ abi, address, functionName: "name" }),
      ]);

      return { decimals, name, symbol };
    },
  ).data;
};
