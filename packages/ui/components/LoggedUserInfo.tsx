"use client";

import UserAvatar from "./UserAvatar";
import UserInfo from "./UserInfo";

export default function LoggedUserInfo({ location }: { location: "main-menu" | "topbar" }) {
  return (
    <div className={location == "main-menu" ? "logged-user-w avatar-inline" : "logged-user-w"}>
      <div className="logged-user-i">
        <UserAvatar />

        <div className="logged-user-menu color-style-bright">
          <div className="logged-user-avatar-info">
            <UserInfo />
          </div>
          <div className="bg-icon">
            <i className="os-icon os-icon-wallet-loaded"></i>
          </div>
        </div>
      </div>
    </div>
  );
}
