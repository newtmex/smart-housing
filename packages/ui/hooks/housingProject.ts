import useRawCallsInfo from "./useRawCallsInfo";
import useSwr from "swr";
import getFundingTokenInfo from "~~/utils/fundingTokenInfo";

export const useProjectsInfo = () => {
  const { client, projectFunding, housingSFTAbi } = useRawCallsInfo();
  return useSwr(
    client && projectFunding && housingSFTAbi ? { key: "useProjects-data" } : null,
    () =>
      client!
        .readContract({ abi: projectFunding!.abi, address: projectFunding!.address, functionName: "allProjects" })
        .then(projectsData =>
          // Merge with maxSupply
          Promise.all(
            projectsData.map(async data => {
              const [[name, symbol, maxSupply], fundingToken] = await Promise.all([
                client!.readContract({
                  abi: housingSFTAbi!,
                  address: data.tokenAddress,
                  functionName: "tokenDetails",
                }),
                getFundingTokenInfo({ tokenAddress: data.fundingToken, client }),
              ]);
              return {
                data: {
                  ...data,
                  get isTokensClaimable(): boolean {
                    return data.collectedFunds >= data.fundingGoal;
                  },
                },
                sftDetails: {
                  maxSupply,
                  name,
                  symbol,
                },
                fundingToken,
              };
            }),
          ),
        ),
    {
      keepPreviousData: true,
      revalidateIfStale: false,
    },
  );
};

export type ProjectsValue = ReturnType<typeof useProjects>[number];

export const useProjects = () => {
  const { data } = useProjectsInfo();

  return (
    data?.map((projectData, index) => ({
      description: "",
      features: [
        ["kitchen", "en-suite", "cctv"],
        ["security", "balcony"],
        ["dog house", "guest house", "maid house"],
      ][index % 3],
      image: `img/property${((index + 2) % 3) + 1}.jpg`,
      rentPrice: 23.45,
      projectData,
      unitPrice: projectData.data.fundingGoal / projectData.sftDetails.maxSupply,
    })) || []
  );
};
