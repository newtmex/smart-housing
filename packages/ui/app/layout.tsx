"use client";

import { useCallback } from "react";
import "../styles/global.scss";
import AppProvider from "./provider";
import "@rainbow-me/rainbowkit/styles.css";
import MainMenu from "~~/components/MainMenu";
import MobileMenu from "~~/components/MobileMenu";
import TopBar from "~~/components/TopBar";
import { useContentPanel } from "~~/hooks/useContentPanel";
import { useWindowWidthChange } from "~~/hooks/useWindowResize";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const { contentPanelActive, showContentPanel, hideContentPanel, toggleContentPanel } = useContentPanel();

  useWindowWidthChange(
    useCallback(() => {
      !contentPanelActive && window.innerWidth >= 1150 && showContentPanel();
      contentPanelActive && window.innerWidth < 1150 && hideContentPanel();
    }, [contentPanelActive]),
  );

  return (
    <html lang="en">
      <body className="menu-position-side menu-side-left full-screen color-scheme-dark with-content-panel">
        <AppProvider>
          <div
            className={`all-wrapper with-side-panel solid-bg-all${contentPanelActive ? " content-panel-active" : ""}`}
          >
            <div className="layout-w">
              <MobileMenu />
              <MainMenu />

              <div className="content-w">
                <TopBar />
                <div onClick={toggleContentPanel} className="content-panel-toggler">
                  <i className="os-icon os-icon-grid-squares-22"></i>
                  <span>Sidebar</span>
                </div>
                <div className="content-i">
                  <div className="content-box" style={{ minHeight: "95vh" }}>
                    {children}
                  </div>

                  {/*TODO <Sidebar /> */}
                </div>
              </div>
            </div>
            <div className="display-type"></div>
          </div>
        </AppProvider>
      </body>
    </html>
  );
}
