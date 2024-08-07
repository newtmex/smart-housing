"use client";

import { useCallback } from "react";
import Link from "next/link";
import { erc20Abi } from "viem";
import { useWriteContract } from "wagmi";
import { useReferralInfo } from "~~/components/ReferralCard/hooks";
import { useAccountTokens } from "~~/hooks";
import { ProjectsValue, useProjects } from "~~/hooks/housingProject";
import useRawCallsInfo from "~~/hooks/useRawCallsInfo";
import { getItem } from "~~/storage/session";
import { RefIdData } from "~~/utils";
import { prettyFormatAmount } from "~~/utils/prettyFormatAmount";
import { RoutePath } from "~~/utils/routes";

export default function Properties() {
  const properties = useProjects();

  const { projectsToken: _projectsToken } = useAccountTokens();

  const projectsToken = _projectsToken?.map(token => token.projectData.sftDetails.symbol);

  const { writeContractAsync } = useWriteContract();
  const { projectFunding } = useRawCallsInfo();

  const onRentProperty = useCallback(async () => {
    console.log("rent");
  }, []);

  const { refIdData, refresh: refreshUserRefInfo } = useReferralInfo();

  const onBuyPropertyUnits = useCallback(
    async ({ data }: Pick<ProjectsValue["projectData"], "data">) => {
      if (!projectFunding) {
        throw new Error("projectFunding not loaded");
      }
      if (!data.isTokensClaimable) {
        const referrerLink = getItem("userRefBy");
        const referrerId = referrerLink ? BigInt(RefIdData.getID(referrerLink)) : 0n;

        // TODO set user configured values
        const payment = { amount: (data.fundingGoal * 2n) / 3n, token: data.fundingToken };
        await writeContractAsync({
          abi: erc20Abi,
          address: data.fundingToken,
          functionName: "approve",
          args: [projectFunding.address, payment.amount],
        });

        await writeContractAsync({
          abi: projectFunding.abi,
          address: projectFunding.address,
          functionName: "fundProject",
          // TODO set user configured values
          args: [payment, data.id, referrerId],
        });

        await refreshUserRefInfo();
      }
      if (data.isTokensClaimable) {
        await writeContractAsync({
          abi: projectFunding.abi,
          address: projectFunding.address,
          functionName: "claimProjectTokens",
          // TODO set user configured values
          args: [data.id],
        });
      }
    },
    [projectFunding, refIdData],
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
                                <button onClick={() => onRentProperty()} className="btn btn-primary">
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
                                <button
                                  className={`btn btn-${data.isTokensClaimable ? "success" : "warning"}`}
                                  onClick={() => onBuyPropertyUnits({ data })}
                                >
                                  {!data.isTokensClaimable ? "Buy" : "Claim Tokens"}
                                </button>
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
