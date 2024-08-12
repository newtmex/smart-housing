import React, { useCallback, useState } from "react";
import { useModalToShow } from "./Modals";
import TransactionWaitingIcon, { IconReqState, TxErrorModal } from "./TransactionWaitingIcon";
import { useWriteContract } from "wagmi";
import { useTransactor } from "~~/hooks/scaffold-eth";

export default function TxButton({
  onComplete,
  icon,
  btnName,
  onClick,
  className,
  disabled,
  ...props
}: {
  icon?: React.ReactNode;
  btnName: React.ReactNode;
  onClick: () => ReturnType<ReturnType<typeof useWriteContract>["writeContractAsync"]>;
  onComplete?: () => Promise<any>;
  className?: string;
  disabled?: boolean;
}) {
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
      onComplete && (await onComplete());
    } catch (error: any) {
      setStatus("error");
      setErr(error.toString());
    }
  }, [onClick, err, onComplete, waitTx]);

  return (
    <button onClick={handleClick} disabled={disabled || status == "pending"} className={className} {...props}>
      {icon}
      {typeof btnName == "string" ? <span>{btnName}</span> : btnName}
      {status && <TransactionWaitingIcon iconReqState={status} />}
    </button>
  );
}
