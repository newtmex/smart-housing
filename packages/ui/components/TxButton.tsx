import React, { useCallback, useState } from "react";
import { useModalToShow } from "./Modals";
import TransactionWaitingIcon, { IconReqState, TxErrorModal } from "./TransactionWaitingIcon";
import { useWriteContract } from "wagmi";
import { useTransactor } from "~~/hooks/scaffold-eth";

const TxButton: React.FC<{
  icon?: React.ReactNode;
  btnName: string;
  onClick: () => ReturnType<ReturnType<typeof useWriteContract>["writeContractAsync"]>;
  onComplete: () => Promise<any>;
  className?: string;
}> = ({ onComplete, icon, btnName, onClick, className }) => {
  const [status, setStatus] = useState<IconReqState>();
  const [err, setErr] = useState<string>();

  const { openModal, closeModal } = useModalToShow();

  const waitTx = useTransactor();

  const handleClick = useCallback(async () => {
    if (err) {
      openModal(
        <TxErrorModal
          msg={err}
          handleSeen={() => {
            setStatus("idle");
            setErr(undefined);
            closeModal();
          }}
        />,
      );
      return;
    }

    setStatus("pending");
    try {
      await waitTx(() => onClick());

      setStatus("idle");
      await onComplete();
    } catch (error: any) {
      setStatus("error");
      setErr(error.toString());
    }
  }, [onClick, err, onComplete]);

  return (
    <button onClick={handleClick} disabled={status == "pending"} className={className}>
      {icon}
      <span>{btnName}</span>
      {status && <TransactionWaitingIcon iconReqState={status} />}
    </button>
  );
};

export default TxButton;
