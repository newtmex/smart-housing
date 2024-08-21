import { useCallback } from "react";
import TxButton from "./TxButton";
import useSWR from "swr";
import { useWriteContract } from "wagmi";
import { useAccountTokens } from "~~/hooks";
import useRawCallsInfo from "~~/hooks/useRawCallsInfo";
import nonceToRandString from "~~/utils/nonceToRandom";
import { prettyFormatAmount } from "~~/utils/prettyFormatAmount";

export default function RentDividends() {
  const { projectsToken } = useAccountTokens();
  const { client, housingProjectAbi } = useRawCallsInfo();
  const { writeContractAsync } = useWriteContract();

  const { data: tokenBalances, mutate: refreshClaimableRents } = useSWR(
    housingProjectAbi && client && projectsToken
      ? { key: "projects-rent-rewards", tokens: projectsToken, client, housingProjectAbi }
      : null,
    ({ tokens, client, housingProjectAbi }) =>
      Promise.all(
        tokens.flatMap(
          ({
            balances,
            projectData: {
              data: { projectAddress, tokenAddress },
              sftDetails: { name, symbol },
            },
          }) =>
            balances.map(balance =>
              client
                .readContract({
                  abi: housingProjectAbi,
                  address: projectAddress,
                  functionName: "rentClaimable",
                  args: [balance.attributes],
                })
                .then(claimable => ({
                  claimable,
                  projectAddress,
                  name,
                  collection: symbol + "-" + nonceToRandString(balance.nonce, tokenAddress),
                  ...balance,
                })),
            ),
        ),
      ),
    { refreshInterval: 5_000 },
  );

  const onClaimRentReward = useCallback(
    async ({ nonce, projectAddress }: { nonce: bigint; projectAddress: string }) => {
      if (!housingProjectAbi) {
        throw new Error("Data not laoded");
      }

      return writeContractAsync({
        abi: housingProjectAbi,
        address: projectAddress,
        functionName: "claimRentReward",
        args: [nonce],
      });
    },
    [housingProjectAbi],
  );

  return (
    <div className="row pt-2">
      {tokenBalances?.map(({ claimable, name, collection, ...token }) => {
        if (claimable <= 0) {
          return null;
        }

        return (
          <div key={collection} className="col-6 col-sm-3 col-xxl-2">
            <TxButton
              className="element-box el-tablo centered trend-in-corner smaller"
              onClick={() => onClaimRentReward(token)}
              onComplete={async () => {
                refreshClaimableRents();
              }}
              btnName={
                <>
                  <div className="label">{name} Rent Reward</div>
                  <div className="value">{prettyFormatAmount({ value: claimable, length: 8 })}</div>
                  <div className="trending trending-up">
                    <span>{collection}</span>
                    <i className="os-icon os-icon-arrow-up6"></i>
                  </div>
                </>
              }
            />
          </div>
        );
      })}
    </div>
  );
}
