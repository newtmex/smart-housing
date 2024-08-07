import { useProjects } from "./housingProject";
import { useLkSht } from "./projectFunding";
import useRawCallsInfo from "./useRawCallsInfo";
import useSWR from "swr";
import { useAccount } from "wagmi";

export const useAccountTokens = () => {
  const projects = useProjects();
  const { address: userAddress } = useAccount();
  const { client, coinbase, housingSFTAbi } = useRawCallsInfo();
  const lkSHT = useLkSht();

  const { data } = useSWR(
    lkSHT && userAddress && client && coinbase && housingSFTAbi
      ? { client, userAddress, lkSHT, coinbase, housingSFTAbi }
      : null,
    async ({ userAddress, client, coinbase, lkSHT, housingSFTAbi }) => {
      const [userSht, userLkSht, ...projectsToken] = await Promise.all([
        client.readContract({
          abi: coinbase.abi,
          address: coinbase.address,
          functionName: "balanceOf",
          args: [userAddress],
        }),
        client
          .readContract({
            abi: lkSHT.abi,
            address: lkSHT.address,
            functionName: "balanceOf",
            args: [userAddress, 1n],
          })
          .then(balance => {
            const { abi, ...params } = lkSHT;
            abi;

            return {
              ...params,
              balance,
            };
          }),
        ...projects.map(project =>
          client
            .readContract({
              abi: housingSFTAbi,
              address: project.projectData.data.tokenAddress,
              functionName: "balanceOf",
              args: [userAddress, 1n],
            })
            .then(balance => ({ ...project, balance })),
        ),
      ]);
      return [userSht, userLkSht, projectsToken.filter(({ balance }) => balance > 0n)] as [
        typeof userSht,
        typeof userLkSht,
        typeof projectsToken,
      ];
    },
  );

  if (!data) {
    return {
      sht: null,
      lkSht: null,
      projectsToken: null,
    };
  }

  const [sht, lkSht, projectsToken] = data;

  return { sht, lkSht, projectsToken };
};
