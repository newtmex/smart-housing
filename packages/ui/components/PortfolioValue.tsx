"use client";

import { useCallback, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAccount } from "wagmi";
import { useAccountTokens } from "~~/hooks";
import { useOnPathChange } from "~~/hooks/useContentPanel";
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

  const { address } = useAccount();

  const onUnlockLockedSHT = useCallback(async () => {
    if (!lkSht) {
      return;
    }
  }, [lkSht, address]);

  return (
    <div className={`fancy-selector-w ${opened ? "opened" : ""}`}>
      <div className="fancy-selector-current">
        <div className="fs-img">
          <img alt="" src="img/card4.png" />
        </div>
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
        {lkSht && (
          <div className="fancy-selector-option">
            <div className="fs-img">
              <img alt="" src="img/card2.png" />
            </div>
            <div className="fs-main-info">
              <div className="fs-name">
                <span>{lkSht.name} Portfolio</span>
                <strong>{lkSht.symbol}</strong>
              </div>
              <div className="fs-sub">
                <span>Balance:</span>
                <strong>{prettyFormatAmount({ value: lkSht.balance })}</strong>
              </div>
            </div>
            <button onClick={() => onUnlockLockedSHT()} className="btn btn-primary" style={{ fontSize: "0.75em" }}>
              Unlock
            </button>
          </div>
        )}

        {projectsToken && <>Properties</>}
        {projectsToken?.map((token, index) => {
          return (
            <div key={index} className="fancy-selector-option">
              <div className="fs-img">{/* <img alt='' src='img/card2.png' /> */}</div>
              <div className="fs-main-info">
                <div className="fs-name">
                  <span>{token.projectData.sftDetails.name} Portfolio</span>
                  <strong>{token.projectData.sftDetails.symbol}</strong>
                </div>
                <div className="fs-sub">
                  <span>Units:</span>
                  <strong>
                    {prettyFormatAmount({
                      value: token.balance,
                      decimals: 0,
                    })}
                  </strong>
                </div>
              </div>
            </div>
          );
        })}

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
