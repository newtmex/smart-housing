import { useMemo } from "react";
import ClaimStakingRewards from "./ClaimStakingRewards";
import LoadingState from "./LoadingState";
import { useModalToShow } from "./Modals";
import StakingModal from "./StakingModal";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import BigNumber from "bignumber.js";
import { useAccount } from "wagmi";
import { useAccountTokens, useTokenPrices } from "~~/hooks";
import { useSht } from "~~/hooks/coinbase";
import { useHousingStakingToken } from "~~/hooks/smartHousing";
import { prettyFormatAmount } from "~~/utils/prettyFormatAmount";

export default function StakingAndGovernace() {
  const { address } = useAccount();
  const prices = useTokenPrices();
  const { sftBalance } = useHousingStakingToken();
  const sht = useSht();
  const { ownedAssets } = useAccountTokens();

  const stakingBalance = useMemo(() => {
    if (!sht || !prices || !sftBalance) {
      return undefined;
    }

    const balanceValue = sftBalance
      .reduce((stakeTokenValue, { attributes: { projectTokens, shtAmount } }) => {
        const tokensShtValue = BigNumber(prices[sht.symbol].value(shtAmount));
        const tokensValue = projectTokens.reduce((paymentValue, payment) => {
          return paymentValue.plus(prices[payment.token].value(payment.amount));
        }, tokensShtValue);

        return tokensValue.plus(stakeTokenValue);
      }, BigNumber(0))
      .toFixed(0);

    return prettyFormatAmount({
      value: balanceValue,
      decimals: 2,
    });
  }, [sht, prices, sftBalance]);

  const { openModal } = useModalToShow();

  if (!address) {
    return <ConnectButton />;
  }

  if (sftBalance == undefined || stakingBalance == undefined) {
    return <LoadingState text="Loading Staking Details" />;
  }

  return (
    <div className="element-wrapper compact pt-4">
      <h6 className="element-header">Staking</h6>
      <div className="col-12">
        <div className="element-balances justify-content-between mobile-full-width">
          <div className="balance balance-v2" style={{ marginTop: "-35px" }}>
            <div className="balance-title">Your Staking Balance</div>
            <div className="balance-value">
              <span className="d-xxl-none">${stakingBalance}</span>
              <span className="d-none d-xxl-inline-block">${stakingBalance}</span>
            </div>
          </div>
        </div>
        <div className="element-wrapper pb-4 mb-4 border-bottom">
          <div className="element-box-tp row">
            {ownedAssets.length > 1 && (
              <div className="col-sm-5">
                <a
                  className="btn btn-primary"
                  onClick={e => {
                    e.preventDefault();
                    openModal(<StakingModal />);
                  }}
                >
                  <i className="os-icon os-icon-refresh-ccw"></i>
                  <span>Stake Assets</span>
                </a>
              </div>
            )}

            <div className="col-sm-7">
              <ClaimStakingRewards />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
