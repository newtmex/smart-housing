import { useEffect, useState } from "react";
import { useModalToShow } from "../Modals";
import SlideWrapper from "../SlideWrapper";
import "./array.extensions";
import { ICON_TRANSITION_DELAY } from "./constants";
import styles from "./style.module.scss";

export type IconReqState = "idle" | "error" | "success" | "pending";

const matchStrings = [" reason:", " Error:", "TransactionExecutionError:", "ContractFunctionExecutionError:"];
const processedMatchString = matchStrings.reduce((acc, curr, index) => {
  acc += curr;

  if (index !== matchStrings.length - 1) {
    acc += "|";
  }

  return acc;
}, "");
const errorMsg = (msg: string) => {
  const regEx = new RegExp("(" + processedMatchString + ")(\n)?(.*)", "g");
  const match = msg.match(regEx);

  const error = match?.at(-1)?.replace(processedMatchString, "");

  return error;
};

export function TxErrorModal({ msg, handleSeen }: { msg: string; handleSeen: () => any }) {
  const { closeModal } = useModalToShow();

  const handleClose = () => {
    closeModal();
  };

  return (
    <SlideWrapper
      imageScr="img/portfolio16.jpg"
      title={`Error executing ${msg.match(/function \"\w+\"/)?.at(0) || "action"}`}
      description={
        matchStrings.some(matchSrring => msg.includes(matchSrring)) ? (
          <p className="text-danger d-flex justify-content-center align-items-center">{errorMsg(msg)}</p>
        ) : (
          msg
            .replace(/(\w+:)/g, captured => "<br> " + captured)
            .split("<br> ")
            .map((e, i) => (
              <p key={i} className="text-danger d-flex justify-content-center align-items-center">
                {e}
              </p>
            ))
        )
      }
    >
      <div className="buttons-w">
        <button className="btn btn-info mx-2 " onClick={handleSeen}>
          Seen
        </button>

        <a className="btn btn-link" onClick={handleClose}>
          Close
        </a>
      </div>
    </SlideWrapper>
  );
}

const nextIconState = (currentState: string[]) => {
  const [state, extraClass] = (() => {
    if (currentState.hasRegEx(/-o$/)) {
      return ["start"];
    }
    if (currentState.hasRegEx(/start$/)) {
      return ["half"];
    }
    if (currentState.hasRegEx(/half$/)) {
      return ["end"];
    }
    if (currentState.hasRegEx(/end$/)) {
      return ["end", styles.rotate];
    }
    if (currentState.hasRegEx(/end \w*rotate/)) {
      return ["start"];
    }

    return ["o"];
  })();
  const newState = [`fa-hourglass-${state}`];
  extraClass && newState.push(extraClass);

  return newState;
};

export default function TransactionWaitingIcon({ iconReqState }: { iconReqState: IconReqState }) {
  const [iconState, setIconState] = useState<string[]>([]);

  useEffect(() => {
    let timer: NodeJS.Timeout;

    const stop = () => {
      clearTimeout(timer);
    };

    if (iconReqState == "pending") {
      const run = () => {
        setIconState(nextIconState);
      };

      (iconState.length < 1 || iconState.hasRegEx(/error/)) && run();
      timer = setTimeout(run, ICON_TRANSITION_DELAY);
    } else {
      stop();
    }

    return stop;
  }, [iconState, iconReqState]);

  useEffect(() => {
    if (iconReqState == "error") {
      setIconState(["fa-exclamation-triangle", styles.error]);
    } else if (iconReqState == "idle") {
      setIconState([]);
    }
  }, [iconReqState]);

  return !iconReqState || iconReqState == "idle" ? null : (
    <span
      className={`${iconState.hasRegEx(/error/) ? styles.error : ""}`}
      style={{
        fontSize: "0.6rem",
        marginLeft: "0.7em",
        marginTop: "0.2em",
        display: "inline-block",
      }}
    >
      <i className={`fa ${iconState.join(" ")}`}></i>
    </span>
  );
}
