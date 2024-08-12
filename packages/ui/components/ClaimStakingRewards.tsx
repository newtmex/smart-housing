import { useCallback } from "react";
import TxButton from "./TxButton";
import useSWR from "swr";
import { useAccount, useWriteContract } from "wagmi";
import { useHousingStakingToken } from "~~/hooks/smartHousing";
import useRawCallsInfo from "~~/hooks/useRawCallsInfo";
import { RefIdData } from "~~/utils";
import nonceToRandString from "~~/utils/nonceToRandom";

export default function ClaimStakingRewards() {
  const { client, smartHousing } = useRawCallsInfo();
  const { sftBalance, hstInfo, refreshBalance } = useHousingStakingToken();
  const { address: userAddress } = useAccount();

  const { data: claimableHSTs, mutate: refreshClaimableHSTs } = useSWR(
    hstInfo && userAddress && sftBalance && client && smartHousing
      ? {
          key: "getUserClaimableHSTs",
          hstInfo,
          userAddress,
          client,
          smartHousing,
          sftBalance,
        }
      : null,
    ({ client, smartHousing, userAddress, sftBalance, hstInfo }) =>
      Promise.all(
        sftBalance.map(sft =>
          client
            .readContract({
              abi: smartHousing.abi,
              address: smartHousing.address,
              functionName: "userCanClaim",
              args: [userAddress, sft.nonce],
            })
            .then(canClaim => {
              return {
                collection: hstInfo.symbol + "-" + nonceToRandString(sft.nonce, hstInfo.address),
                canClaim,
                ...sft,
              };
            }),
        ),
      ).then(results => results.filter(token => token.canClaim).sort((a, b) => +(a.nonce - b.nonce).toString())),
    {
      keepPreviousData: true,
    },
  );

  const { writeContractAsync } = useWriteContract();

  const selectedHST = claimableHSTs?.at(0);

  const onClaim = useCallback(async () => {
    if (!smartHousing || !selectedHST) {
      throw new Error("values not set");
    }

    return writeContractAsync({
      abi: smartHousing.abi,
      address: smartHousing.address,
      functionName: "claimRewards",
      args: [selectedHST.nonce, RefIdData.getReferrerId()],
    });
  }, [selectedHST, smartHousing]);

  if (!selectedHST || !smartHousing || !userAddress) {
    return null;
  }

  return (
    <TxButton
      className="btn btn-success"
      btnName={`Claim ${selectedHST.collection} Rewards`}
      onClick={() => onClaim()}
      onComplete={async () => {
        await refreshBalance();
        refreshClaimableHSTs();
      }}
    />
  );
}
