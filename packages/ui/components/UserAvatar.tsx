"use client";

import dynamic from "next/dynamic";
import { useAccount } from "wagmi";

const BlockiesImage = dynamic(() => import("./BlockiesImage"), {
  ssr: false,
});

export default function UserAvatar() {
  const { address } = useAccount();

  return (
    <div className="avatar-w">
      <BlockiesImage seed={address || "----"} />
    </div>
  );
}
