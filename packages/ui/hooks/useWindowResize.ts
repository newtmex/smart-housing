"use client";

import { useCallback, useEffect, useRef } from "react";

export const useWindowWidthChange = (cb: () => void) => {
  const windowWidthRef = useRef(typeof window !== "undefined" ? window.innerWidth : 0);
  const run = useCallback(() => {
    if (typeof window !== "undefined") {
      if (window.innerWidth != windowWidthRef.current) {
        windowWidthRef.current == window.innerWidth;
        cb();
      }
    }
  }, [cb]);

  useEffect(() => {
    if (typeof window !== "undefined") {
      window.addEventListener("resize", run);

      return () => {
        window.removeEventListener("resize", run);
      };
    }
  }, [run]);
};
