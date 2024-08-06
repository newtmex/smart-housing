"use client";

import { useCallback, useEffect, useRef } from "react";

export const useWindowWidthChange = (cb: () => void) => {
  const windowWidthRef = useRef(window.innerWidth);
  const run = useCallback(() => {
    if (window.innerWidth != windowWidthRef.current) {
      windowWidthRef.current == window.innerWidth;
      cb();
    }
  }, [cb]);

  useEffect(() => {
    window.addEventListener("resize", run);

    return () => {
      window.removeEventListener("resize", run);
    };
  }, [run]);
};
