"use client";

import { useCallback } from "react";
import Link from "next/link";
import { useAccount, useWriteContract } from "wagmi";
import { useReferralInfo } from "~~/components/ReferralCard/hooks";
import TxButton from "~~/components/TxButton";
import { useAccountTokens } from "~~/hooks";
import { ProjectsValue, useProjects } from "~~/hooks/housingProject";
import useRawCallsInfo from "~~/hooks/useRawCallsInfo";
import { useSpendERC20 } from "~~/hooks/useSpendERC20";
import { getItem } from "~~/storage/session";
import { RefIdData } from "~~/utils";
import { prettyFormatAmount } from "~~/utils/prettyFormatAmount";
import { RoutePath } from "~~/utils/routes";
import { isZeroAddress } from "~~/utils/scaffold-eth/common";

export default function Properties() {
  const properties = useProjects();

  const { projectsToken: _projectsToken, sht } = useAccountTokens();

  const projectsToken = _projectsToken?.map(token => token.projectData.sftDetails.symbol);

  const { writeContractAsync } = useWriteContract();
  const { projectFunding, housingProjectAbi } = useRawCallsInfo();
  const { address } = useAccount();

  const { checkApproval } = useSpendERC20();

  const onRentProperty = useCallback(
    async ({ data: { projectAddress } }: Pick<ProjectsValue["projectData"], "data">) => {
      if (!housingProjectAbi) {
        throw new Error("Housing Project ABI not loaded");
      }

      if (!sht || sht.balance < 1_000_000n) {
        throw new Error("Not enough rent payment balance");
      }

      const payment = { amount: sht.balance / 100n, token: sht.address };

      await checkApproval({ payment, spender: projectAddress });

      await writeContractAsync({
        abi: housingProjectAbi,
        address: projectAddress,
        functionName: "receiveRent",
        args: [payment],
      });
    },
    [housingProjectAbi, sht],
  );

  const { refIdData, refresh: refreshUserRefInfo } = useReferralInfo();

  const onBuyPropertyUnits = useCallback(
    async ({
      data: { fundingGoal, id: projectId, isTokensClaimable },
      fundingToken,
    }: Pick<ProjectsValue["projectData"], "data" | "fundingToken">) => {
      if (!projectFunding) {
        throw new Error("projectFunding not loaded");
      }
      if (!address || isZeroAddress(address)) {
        throw new Error("address not loaded");
      }

      if (!isTokensClaimable) {
        const referrerLink = getItem("userRefBy");
        const referrerId = referrerLink ? BigInt(RefIdData.getID(referrerLink)) : 0n;

        const payment = {
          // TODO set user configured amount
          amount: fundingGoal,
          // amount: (fundingGoal * 2n) / 3n,
          token: fundingToken.tokenAddress,
          nonce: 0n,
        };

        if (!fundingToken.isNative) {
          await checkApproval({ payment, spender: projectFunding.address });
        }

        return writeContractAsync({
          abi: projectFunding.abi,
          address: projectFunding.address,
          functionName: "fundProject",
          args: [payment, projectId, referrerId],
          value: fundingToken.isNative ? payment.amount : undefined,
          account: address,
        });
      } else {
        return writeContractAsync({
          abi: projectFunding.abi,
          address: projectFunding.address,
          functionName: "claimProjectTokens",
          args: [projectId],
          account: address,
        });
      }
    },
    [projectFunding, refIdData, address],
  );

  return (
    <div className="all-wrapper rentals">
      <div className="rentals-list-w hide-filters">
        <div className="rentals-list">
          <div className="property-items as-grid">
            {!properties.length ? (
              <div style={{ height: "100%", fontSize: "10rem" }}>No Listed Properties</div>
            ) : (
              properties.map(
                ({ projectData: { data, sftDetails, fundingToken }, features, rentPrice, unitPrice, image }) => {
                  const href = `${RoutePath.Properties}`;

                  return (
                    <div className="property-item" key={`property-${data.projectAddress}`}>
                      <Link className="item-media-w" href={href}>
                        <div className="item-media" style={{ backgroundImage: `url(${image})` }}></div>
                      </Link>
                      <div className="item-info">
                        <div className="item-features">
                          {features.map(feature => (
                            <div key={feature} className="feature">
                              {feature}
                            </div>
                          ))}
                        </div>
                        <h3 className="item-title">
                          <Link href={href}>
                            {sftDetails.name}&nbsp;{sftDetails.symbol}
                          </Link>
                        </h3>

                        <div className="item-price-buttons row">
                          {data.isTokensClaimable && (
                            <div className="col-12 row">
                              <div className="item-price col-8">
                                <strong>${rentPrice}</strong>
                                <span>/per year</span>
                              </div>
                              <div className="item-buttons col-4">
                                <button onClick={() => onRentProperty({ data })} className="btn btn-primary">
                                  Rent
                                </button>
                              </div>
                            </div>
                          )}
                          <div className="col-12 row">
                            {!data.isTokensClaimable && (
                              <div className="item-price col-8">
                                <strong>
                                  <small>{fundingToken.symbol}</small>{" "}
                                  {prettyFormatAmount({
                                    value: unitPrice,
                                    length: 50,
                                    showIsLessThanDecimalsLabel: false,
                                  })}
                                </strong>
                                <span>/per unit</span>
                              </div>
                            )}

                            {!projectsToken?.includes(sftDetails.symbol) && (
                              <div className="item-buttons col-4">
                                <TxButton
                                  btnName={!data.isTokensClaimable ? "Buy" : "Claim Tokens"}
                                  onClick={() => onBuyPropertyUnits({ data, fundingToken })}
                                  onComplete={async () => {
                                    await refreshUserRefInfo();
                                  }}
                                  className={`btn btn-${data.isTokensClaimable ? "success" : "warning"}`}
                                />
                              </div>
                            )}
                          </div>
                        </div>
                      </div>
                    </div>
                  );
                },
              )
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
