import { useCallback, useMemo } from "react";
import FormErrorMessage from "./FormErrorMessage";
import LoadingState from "./LoadingState";
import { useModalToShow } from "./Modals";
import TxButton from "./TxButton";
import { useFormik } from "formik";
import RcSlider from "rc-slider";
import Select from "react-select";
import { parseUnits } from "viem";
import { useAccount, useWriteContract } from "wagmi";
import { useAccountTokens } from "~~/hooks";
import { useHousingStakingToken } from "~~/hooks/smartHousing";
import useRawCallsInfo from "~~/hooks/useRawCallsInfo";
import { useSpendERC20 } from "~~/hooks/useSpendERC20";
import { RefIdData } from "~~/utils";
import nonceToRandString from "~~/utils/nonceToRandom";
import { prettyFormatAmount } from "~~/utils/prettyFormatAmount";

export default function StakingModal() {
  const { closeModal } = useModalToShow();
  const { address: userAddress } = useAccount();

  const { ownedAssets: ownedAssets_, lkSht, sht, refresh: refreshAccountTokens } = useAccountTokens();
  const { refreshBalance: refreshHST } = useHousingStakingToken();

  const ownedAssets = useMemo(
    () =>
      ownedAssets_
        .filter(token => token.tokenAddress != sht?.address)
        .map(token => {
          return {
            value: {
              nonce: token.nonce,
              amount: token.qty,
              token: token.tokenAddress,
            },
            label: `${token.symbol + "-" + nonceToRandString(token.nonce, token.tokenAddress)} ${prettyFormatAmount({ value: token.qty, decimals: token.decimals })}`,
          };
        }),
    [ownedAssets_, sht],
  );

  const { errors, values, handleChange, setFieldValue, isValid } = useFormik({
    initialValues: {
      shtAmount: 0,
      sfts: undefined as { token: string; amount: bigint; nonce: bigint }[] | undefined,
      epochsLock: 180,
    },
    onSubmit: () => {
      console.log("submit");
    },
  });

  const { smartHousing, lkSHTAbi: ERC1155Abi, client } = useRawCallsInfo();
  const { writeContractAsync } = useWriteContract();

  const { checkApproval } = useSpendERC20();

  const onStake = useCallback(async () => {
    if (!smartHousing || !sht || !ERC1155Abi || !client || !userAddress) {
      throw new Error("smartHousing not loaded");
    }
    if (!isValid || !values.sfts) {
      throw new Error("Invalid input");
    }

    const payments = values.sfts;
    // Set approvals
    for (const sft of payments) {
      const owner = userAddress;
      const spender = smartHousing.address;
      const abi = ERC1155Abi;
      const address = sft.token;

      if (
        await client.readContract({
          abi,
          address,
          functionName: "isApprovedForAll",
          args: [owner, spender],
        })
      ) {
        continue;
      }

      await writeContractAsync({
        abi,
        address,
        functionName: "setApprovalForAll",
        args: [spender, true],
      });
    }

    const epochsLock = parseUnits(values.epochsLock.toString(), 0);

    const referrerId = RefIdData.getReferrerId();

    const shtPayment = values.shtAmount && {
      amount: parseUnits(values.shtAmount.toString(), sht.decimals), // TODO this can caboom if string is returned as scientific notation
      token: sht.address,
      nonce: 0n,
    };

    if (shtPayment) {
      await checkApproval({ payment: shtPayment, spender: smartHousing.address });
      payments.unshift(shtPayment);
    }

    return writeContractAsync({
      abi: smartHousing.abi,
      address: smartHousing.address,
      functionName: "stake",
      args: [payments, epochsLock, referrerId],
    });
  }, [smartHousing, values, isValid, sht, userAddress, client]);

  return (
    <>
      <button className="close" onClick={() => closeModal()} type="button">
        <span className="close-label">Close</span>
        <span className="os-icon os-icon-close"></span>
      </button>
      <div className="onboarding-side-by-side">
        <div className="onboarding-media">
          <img alt="" src="img/bigicon5.png" width="200px" />
        </div>

        {!sht || !lkSht || !ownedAssets ? (
          <LoadingState text="Getting Tokens" />
        ) : (
          <div className="onboarding-content with-gradient">
            <h4 className="onboarding-title">Stake Your Assets</h4>
            <div className="onboarding-text">
              Stake your {sht.symbol} or {lkSht.symbol} with atleast one project asset to earn more rewards and
              participate in platform governance
            </div>
            <form>
              <div className="mb-3 form-group" style={{ width: "100%" }}>
                <label htmlFor="splippage">Number of Epochs to Lock token: {values.epochsLock}</label>
                <RcSlider
                  defaultValue={values.epochsLock}
                  step={25}
                  min={10}
                  max={1000}
                  onChange={value => {
                    setFieldValue("epochsLock", value);
                  }}
                />
              </div>
              <div className="row">
                {sht.balance > 0n && (
                  <div className="col-sm-6">
                    <div className="form-group">
                      <label>{sht.symbol} Amount</label>
                      <input
                        placeholder={`Enter ${sht.symbol} amount`}
                        type="number"
                        className={`form-control ${errors.shtAmount ? "is-invalid" : ""}`}
                        id="shtAmount"
                        name="shtAmount"
                        onChange={handleChange}
                        value={values.shtAmount}
                        step={"any"}
                        min={1}
                      />
                      <FormErrorMessage message={errors.shtAmount} />
                    </div>
                  </div>
                )}

                {ownedAssets.length > 0 && (
                  <div className="col-sm-12">
                    <div className="form-group">
                      <label>{sht.balance > 0 ? "Other a" : "A"}ssets to use</label>
                      <Select
                        id="sfts"
                        name="sfts"
                        onChange={tokens => {
                          const payments = [];

                          for (const { value } of tokens) {
                            if (value.amount > 0) {
                              payments.push(value);
                            }
                          }

                          setFieldValue("sfts", payments);
                        }}
                        styles={{
                          option: styles => {
                            return { ...styles, color: "black" };
                          },
                        }}
                        isMulti={true}
                        options={ownedAssets}
                      />
                    </div>
                  </div>
                )}
              </div>

              <TxButton
                disabled={!isValid || !values.sfts?.length}
                btnName="Stake"
                onClick={() => onStake()}
                onComplete={async () => {
                  await refreshAccountTokens();
                  await refreshHST();

                  closeModal();
                }}
                className="btn btn-primary"
              />
            </form>
          </div>
        )}
      </div>
    </>
  );
}
