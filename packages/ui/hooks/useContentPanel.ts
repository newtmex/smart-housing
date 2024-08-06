import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import useSWR from "swr";

export const useContentPanel = () => {
  const { data, mutate } = useSWR("ui-contentent-panel", {
    fallbackData: false,
  });

  return {
    contentPanelActive: data,
    toggleContentPanel() {
      mutate(!data);
    },
    hideContentPanel() {
      mutate(false);
    },
    showContentPanel() {
      mutate(true);
    },
  };
};

export const useOnPathChange = (cb: () => void) => {
  const pathname = usePathname();
  const pathnameRef = useRef(pathname);
  useEffect(() => {
    if (pathname !== pathnameRef.current) {
      cb();
      pathnameRef.current = pathname;
    }
  }, [pathname, cb]);
};
