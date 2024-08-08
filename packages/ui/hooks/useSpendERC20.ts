import { useCallback } from "react";
import useRawCallsInfo from "./useRawCallsInfo";
import { erc20Abi } from "viem";
import { useAccount, useWriteContract } from "wagmi";

export const useSpendERC20 = <TokenPayment extends { token: string; amount: bigint }>() => {
  const { address } = useAccount();
  const { client } = useRawCallsInfo();
  const { writeContractAsync } = useWriteContract();

  const checkApproval = useCallback(
    async ({ payment: { amount, token }, spender }: { payment: TokenPayment; spender: string }) => {
      if (!token || !address || !client) {
        throw new Error("Missing necessary data for token approval");
      }

      const spendAllowance = await client.readContract({
        abi: erc20Abi,
        address: token,
        functionName: "allowance",
        args: [address, spender],
      });

      if (spendAllowance < amount) {
        await writeContractAsync({
          abi: erc20Abi,
          address: token,
          functionName: "approve",
          args: [spender, amount],
        });
      }
    },
    [client, address],
  );

  return { checkApproval };
};
