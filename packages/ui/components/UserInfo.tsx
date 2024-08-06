"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";

export default function UserInfo() {
  return (
    <div className="logged-user-info-w">
      <ConnectButton showBalance={false} />
    </div>
  );
}
