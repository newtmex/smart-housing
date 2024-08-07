import useSWR from "swr";
import { useAccount } from "wagmi";
import useRawCallsInfo from "~~/hooks/useRawCallsInfo";
import { RefIdData } from "~~/utils";

export const useReferralInfo = () => {
  const { address } = useAccount();
  const { smartHousing, client } = useRawCallsInfo();

  const { data, mutate } = useSWR(
    address && client && smartHousing ? { key: "refdata-getAffiliateDetails", address, client, smartHousing } : null,
    ({ address, client, smartHousing }) =>
      Promise.all([
        client
          .readContract({
            abi: smartHousing.abi,
            address: smartHousing.address,
            functionName: "getUserId",
            args: [address],
          })
          .then(id => new RefIdData(address, +id.toString())),
      ]),
  );

  return { refIdData: data?.at(0), refresh: () => mutate() };
};
