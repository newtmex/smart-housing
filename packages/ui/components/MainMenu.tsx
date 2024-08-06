"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import LoggedUserInfo from "./LoggedUserInfo";
import { APP_NAME } from "~~/utils";
import { ROUTES } from "~~/utils/routes";

export default function MainMenu() {
  const pathname = usePathname();
  return (
    <div className="menu-w menu-position-side menu-side-left menu-layout-mini sub-menu-style-over sub-menu-color-bright menu-activated-on-hover menu-has-selected-link color-scheme-dark color-style-transparent selected-menu-color-bright">
      <div className="logo-w">
        <a className="logo" href="/">
          <div className="logo-element"></div>
          <div className="logo-label">{APP_NAME}</div>
        </a>
      </div>
      <LoggedUserInfo location="main-menu" />

      <ul className="main-menu">
        {ROUTES.map((route, index) => (
          <li
            key={`${route.path}+${index}`}
            className={`${pathname.startsWith(route.path) ? "selected " : ""}has-sub-menu`}
          >
            <Link href={route.path}>
              <div className="icon-w">
                <div className={`os-icon os-icon-${route.osIcon}`}></div>
              </div>
              <span>{route.name}</span>
            </Link>
            <div className="sub-menu-w">
              <div className="sub-menu-header">{route.name}</div>
              <div className="sub-menu-icon">
                <i className={`os-icon os-icon-${route.osIcon}`}></i>
              </div>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
