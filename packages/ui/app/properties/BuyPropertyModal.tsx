import { useCallback } from "react";
import BigNumber from "bignumber.js";
import { useFormik } from "formik";
import { parseUnits } from "viem";
import { useWriteContract } from "wagmi";
import { number as yupNumber, object as yupObj } from "yup";
import FormErrorMessage from "~~/components/FormErrorMessage";
import { useModalToShow } from "~~/components/Modals";
import { useReferralInfo } from "~~/components/ReferralCard/hooks";
import TxButton from "~~/components/TxButton";
import { ProjectsValue } from "~~/hooks/housingProject";
import useRawCallsInfo from "~~/hooks/useRawCallsInfo";
import { useSpendERC20 } from "~~/hooks/useSpendERC20";
import { getItem } from "~~/storage/session";
import { RefIdData } from "~~/utils";

type Props = ProjectsValue["projectData"] & { purchased?: bigint; unitPrice: bigint };
export default function BuyPropertyModal({ unitPrice, data, fundingToken, sftDetails, purchased }: Props) {
  const unitsLeft = +BigNumber(sftDetails.maxSupply.toString())
    .multipliedBy((data.fundingGoal - data.collectedFunds).toString())
    .dividedBy(data.fundingGoal.toString())
    .decimalPlaces(0, BigNumber.ROUND_CEIL);

  const { closeModal } = useModalToShow();
  const { projectFunding } = useRawCallsInfo();
  const { writeContractAsync } = useWriteContract();

  const { checkApproval } = useSpendERC20();
  const { refIdData, refresh: refreshUserRefInfo } = useReferralInfo();

  const { handleChange, values, errors, isValid } = useFormik({
    initialValues: { units: 0 },
    validationSchema: yupObj().shape({
      units: yupNumber().max(unitsLeft).min(1).required(),
    }),
    onSubmit: () => {
      console.log("Submiting");
    },
  });

  const onBuyPropertyUnits = useCallback(async () => {
    const { id: projectId } = data;
    if (!projectFunding) {
      throw new Error("projectFunding not loaded");
    }
    if (!isValid) {
      throw new Error("Invalid input");
    }

    const referrerLink = getItem("userRefBy");
    const referrerId = referrerLink ? BigInt(RefIdData.getID(referrerLink)) : 0n;

    const payment = {
      amount: parseUnits(values.units.toString(), 0) * unitPrice,
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
    });
  }, [projectFunding, refIdData, data, fundingToken, unitPrice, values, isValid]);

  return (
    <div
      className="onboarding-modal modal fade animated show"
      id="onboardingWideFormModal"
      role="dialog"
      tabIndex={-1}
      style={{ display: "block" }}
      aria-modal="true"
    >
      <div className="modal-dialog modal-lg modal-centered" role="document">
        <div className="modal-content text-center">
          <button className="close" onClick={() => closeModal()} type="button">
            <span className="close-label">Close</span>
            <span className="os-icon os-icon-close"></span>
          </button>
          <div className="onboarding-side-by-side">
            <div className="onboarding-media">
              <img alt="" src="img/bigicon5.png" width="200px" />
            </div>
            <div className="onboarding-content with-gradient">
              <h4 className="onboarding-title">
                Buy {purchased && "more"} Units of Property {sftDetails.name}
              </h4>
              <div className="onboarding-text">
                Set the number of {sftDetails.name} housing units you want and click on the button.
                <b>Units Left: {unitsLeft}</b>
              </div>
              <form>
                <div className="row">
                  <div className="col-sm-6">
                    <div className="form-group">
                      <label>Number of Units</label>
                      <input
                        placeholder="Enter units amount"
                        type="number"
                        className={`form-control ${errors.units ? "is-invalid" : ""}`}
                        id="units"
                        name="units"
                        onChange={handleChange}
                        value={values.units}
                        step={"any"}
                        min={1}
                      />
                      <FormErrorMessage message={errors.units} />
                    </div>
                  </div>
                </div>

                <TxButton
                  disabled={!isValid}
                  btnName="Complete Buy"
                  onClick={() => onBuyPropertyUnits()}
                  onComplete={async () => {
                    refreshUserRefInfo();
                    closeModal();
                  }}
                  className="btn btn-primary"
                />
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}