import { useEffect, useState } from "react";

export type LoadingStateType = null | string;

const LoadingState = ({ text }: { text: string }) => {
  const [dots, setDots] = useState("");

  useEffect(() => {
    const timer = setInterval(() => {
      setDots(state => (state.length >= 3 ? "" : `${state}.`));
    }, 700);

    // Clean up
    return () => {
      clearInterval(timer);
    };
  }, []);

  return <div>{`${text}${dots}`}</div>;
};

export default LoadingState;
