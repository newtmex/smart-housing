"use client";

import { useCallback, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useWriteContract } from "wagmi";
import { useAccountTokens } from "~~/hooks";
import { useOnPathChange } from "~~/hooks/useContentPanel";
import useRawCallsInfo from "~~/hooks/useRawCallsInfo";
import nonceToRandString from "~~/utils/nonceToRandom";
import { prettyFormatAmount } from "~~/utils/prettyFormatAmount";
import { RoutePath } from "~~/utils/routes";

const usePortfolioViewToggler = () => {
  const [opened, setOpened] = useState(false);

  useOnPathChange(() => setOpened(false));

  return {
    opened,
    viewToggler: () => {
      // Toggle opened state
      setOpened(!opened);
    },
  };
};

export default function PortfolioValue() {
  const { opened, viewToggler } = usePortfolioViewToggler();
  const { sht, lkSht, projectsToken } = useAccountTokens();
  const pathname = usePathname();

  const { writeContractAsync } = useWriteContract();
  const { projectFunding } = useRawCallsInfo();

  const onUnlockLockedSHT = useCallback(
    async ({ tokenNonce }: { tokenNonce: bigint }) => {
      try {
        if (!projectFunding) {
          throw new Error("ProjectFunding info not loaded");
        }

        await writeContractAsync({
          abi: projectFunding.abi,
          address: projectFunding.address,
          functionName: "unlockSHT",
          args: [tokenNonce],
        });
      } catch (error) {
        console.log({ error });
      }
    },
    [projectFunding],
  );

  return (
    <div className={`fancy-selector-w ${opened ? "opened" : ""}`}>
      <div className="fancy-selector-current">
        <div className="fs-main-info">
          <div className="fs-name">
            <span>Housing Portfolio</span>
            <strong>SHT</strong>
          </div>
          <div className="fs-sub">
            <span>Balance:</span>
            <strong>{prettyFormatAmount({ value: sht?.balance || "0" })}</strong>
          </div>
        </div>
        <div onClick={viewToggler} className="fs-selector-trigger">
          <i className="os-icon os-icon-arrow-down4"></i>
        </div>
      </div>
      <div className="fancy-selector-options">
        {lkSht &&
          lkSht.balances.map(({ nonce, amount }) => {
            const collection = lkSht.symbol + "-" + nonceToRandString(nonce, lkSht.address);

            return (
              <div key={collection} className="fancy-selector-option">
                <div className="fs-main-info">
                  <div className="fs-name">
                    <span>{lkSht.symbol} Portfolio</span>
                    <strong>{collection}</strong>
                  </div>
                  <div className="fs-sub">
                    <span>Balance:</span>
                    <strong>{prettyFormatAmount({ value: amount })}</strong>
                  </div>
                </div>
                <button
                  onClick={() => onUnlockLockedSHT({ tokenNonce: nonce })}
                  className="btn btn-primary"
                  style={{ fontSize: "0.75em" }}
                >
                  Unlock
                </button>
              </div>
            );
          })}

        {!!projectsToken?.length && <>Properties</>}
        {projectsToken?.map((token, index) =>
          token.balances.map(({ nonce, amount }) => {
            return (
              <div key={index} className="fancy-selector-option">
                <div className="fs-main-info">
                  <div className="fs-name">
                    <span>{token.projectData.sftDetails.name} Portfolio</span>
                    <strong>
                      {token.projectData.sftDetails.symbol +
                        "-" +
                        nonceToRandString(nonce, token.projectData.data.tokenAddress)}
                    </strong>
                  </div>
                  <div className="fs-sub">
                    <span>Units:</span>
                    <strong>
                      {prettyFormatAmount({
                        value: amount,
                        decimals: 0,
                      })}
                    </strong>
                  </div>
                </div>
              </div>
            );
          }),
        )}

        {!pathname.includes(RoutePath.Properties) && (
          <div className="fancy-selector-actions text-right">
            <Link className="btn btn-primary" href={RoutePath.Properties}>
              <i className="os-icon os-icon-ui-22"></i>
              <span>Add Property</span>
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}
