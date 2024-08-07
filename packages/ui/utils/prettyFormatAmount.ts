import { formatAmount } from "./sdkDappUtils";
import BigNumber from "bignumber.js";

BigNumber.config({ ROUNDING_MODE: BigNumber.ROUND_FLOOR });

export function prettyFormatAmount({
  value,
  length = 8,
  minLength = 30,
  decimals = 18,
  showIsLessThanDecimalsLabel = true,
}: {
  value: string | bigint;
  length?: number;
  minLength?: number;
  decimals?: number;
  showIsLessThanDecimalsLabel?: boolean;
}) {
  value = value.toString();

  const digits = value.length <= minLength ? length : length - (value.length - minLength);
  return formatAmount({
    input: value,
    digits: digits <= 0 ? 0 : digits,
    showLastNonZeroDecimal: false,
    showIsLessThanDecimalsLabel,
    addCommas: true,
    decimals,
  });
}
