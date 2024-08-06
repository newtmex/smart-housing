"use client";

// @ts-ignore
import blockies from "blockies-identicon";

export default function BlockiesImage({ seed }: { seed: string }) {
  return (
    <img
      alt=""
      src={blockies
        .create({
          seed,
          size: 8,
          scale: 16,
        })
        .toDataURL()}
    />
  );
}
