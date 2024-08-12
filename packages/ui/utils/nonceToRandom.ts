import getColor from "./getColor";
import { numberToHex } from "viem";

export default function nonceToRandString(nonce: bigint | number, address: string) {
  const nonceHex = numberToHex(nonce, { size: 4 });

  return getColor(address + nonceHex, 4).replace("#", "");
}
