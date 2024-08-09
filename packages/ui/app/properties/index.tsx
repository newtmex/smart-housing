"use client";

import { useCallback } from "react";
import Link from "next/link";
import BuyPropertyModal from "./BuyPropertyModal";
import useSWR from "swr";
import { useAccount, useWriteContract } from "wagmi";
import { useModalToShow } from "~~/components/Modals";
import { useReferralInfo } from "~~/components/ReferralCard/hooks";
import TxButton from "~~/components/TxButton";
import { useAccountTokens } from "~~/hooks";
import { ProjectsValue, useProjects } from "~~/hooks/housingProject";
import useRawCallsInfo from "~~/hooks/useRawCallsInfo";
import { useSpendERC20 } from "~~/hooks/useSpendERC20";
import { prettyFormatAmount } from "~~/utils/prettyFormatAmount";
import { RoutePath } from "~~/utils/routes";
import { isZeroAddress } from "~~/utils/scaffold-eth/common";

export default function Properties() {
  const properties = useProjects();

  const { sht } = useAccountTokens();

  const { writeContractAsync } = useWriteContract();
  const { projectFunding, housingProjectAbi, client } = useRawCallsInfo();
  const { address } = useAccount();

  const { data: projectsClaimable } = useSWR(
    properties && projectFunding && client && address
      ? { key: "canClaimProject token", projectFunding, client, user: address, properties }
      : null,
    ({ client, projectFunding, user, properties }) =>
      Promise.all(
        properties.map(
          ({
            projectData: {
              data: { id: projectId, isTokensClaimable },
            },
          }) =>
            !isTokensClaimable
              ? Promise.resolve(0n)
              : client.readContract({
                  abi: projectFunding.abi,
                  address: projectFunding.address,
                  functionName: "usersProjectDeposit",
                  args: [projectId, user],
                }),
        ),
      ),
  );

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

      return writeContractAsync({
        abi: housingProjectAbi,
        address: projectAddress,
        functionName: "receiveRent",
        args: [payment],
      });
    },
    [housingProjectAbi, sht],
  );

  const { refIdData, refresh: refreshUserRefInfo } = useReferralInfo();

  const { openModal } = useModalToShow();

  const onClaimProperty = useCallback(
    async ({
      data: { id: projectId, isTokensClaimable },
    }: Pick<ProjectsValue["projectData"], "data" | "fundingToken">) => {
      if (!projectFunding) {
        throw new Error("projectFunding not loaded");
      }
      if (!address || isZeroAddress(address)) {
        throw new Error("address not loaded");
      }

      if (!isTokensClaimable) {
        throw new Error("Property can not be claimed at this time or units have are not available");
      }

      return writeContractAsync({
        abi: projectFunding.abi,
        address: projectFunding.address,
        functionName: "claimProjectTokens",
        args: [projectId],
        account: address,
      });
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
                ({ projectData: { data, sftDetails, fundingToken }, features, rentPrice, unitPrice, image }, index) => {
                  const href = `${RoutePath.Properties}`;
                  const purchased = projectsClaimable?.at(index);
                  const hasClaimable = !!purchased;

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
                                <TxButton
                                  btnName="Rent"
                                  onClick={() => onRentProperty({ data })}
                                  className="btn btn-primary"
                                />
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

                            {data.collectedFunds < data.fundingGoal && (
                              <div className="item-buttons col-4">
                                <button
                                  className="btn btn-warning"
                                  onClick={() =>
                                    openModal(
                                      <BuyPropertyModal
                                        data={data}
                                        fundingToken={fundingToken}
                                        sftDetails={sftDetails}
                                        purchased={purchased}
                                        unitPrice={unitPrice}
                                      />,
                                    )
                                  }
                                >
                                  Buy {hasClaimable && "More"}
                                </button>
                              </div>
                            )}

                            {hasClaimable && data.collectedFunds >= data.fundingGoal && (
                              <div className="item-buttons col-4">
                                <TxButton
                                  btnName="Claim Property Units"
                                  onClick={() => onClaimProperty({ data, fundingToken })}
                                  onComplete={async () => {
                                    await refreshUserRefInfo();
                                  }}
                                  className="btn btn-success"
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
