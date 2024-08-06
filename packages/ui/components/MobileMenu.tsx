"use client";

import { useRef } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import UserAvatar from "./UserAvatar";
import UserInfo from "./UserInfo";
import $ from "jquery";
import { useContentPanel, useOnPathChange } from "~~/hooks/useContentPanel";
import { APP_NAME } from "~~/utils";
import { ROUTES } from "~~/utils/routes";

export default function MobileMenu() {
  const { toggleContentPanel } = useContentPanel();
  const pathname = usePathname();

  const menuRef = useRef<HTMLDivElement>(null);
  const toggleShowMenu = async () => {
    $(menuRef.current!).slideToggle(250, "swing");
  };
  const hideMenu = () => {
    $(menuRef.current!).slideUp(250);
  };

  useOnPathChange(() => {
    hideMenu();
  });

  return (
    <div className="menu-mobile menu-activated-on-click color-scheme-dark">
      <div className="mm-logo-buttons-w">
        <a className="mm-logo" href="/">
          <img src="img/logo.png" />
          <span>{APP_NAME}</span>
        </a>
        <div className="mm-buttons">
          <div onClick={toggleContentPanel} data-testid="sidebar-btn-s" className="content-panel-open">
            <div className="os-icon os-icon-grid-circles"></div>
          </div>
          <div onClick={toggleShowMenu} className="mobile-menu-trigger">
            <div className="os-icon os-icon-hamburger-menu-1"></div>
          </div>
        </div>
      </div>
      <div ref={menuRef} className="menu-and-user">
        <div className="logged-user-w">
          <UserAvatar />
          <UserInfo />
        </div>

        <ul className="main-menu">
          {ROUTES.map((route, index) => (
            <li
              onClick={() => {
                if (pathname.includes(route.path)) {
                  hideMenu();
                }
              }}
              key={`${route.path}+${index}`}
            >
              <Link href={route.path}>
                <div className="icon-w">
                  <div className={`os-icon os-icon-${route.osIcon}`}></div>
                </div>
                <span>{route.name}</span>
              </Link>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
