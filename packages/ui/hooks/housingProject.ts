import useRawCallsInfo from "./useRawCallsInfo";
import useSwr from "swr";
import getFundingTokenInfo from "~~/utils/fundingTokenInfo";

const features = [
  ["solar panels", "garage", "smart home system"],
  ["garden", "patio", "fenced yard"],
  ["fireplace", "walk-in closet", "jacuzzi"],
  ["rooftop terrace", "elevator", "wine cellar"],
  ["double glazing", "underfloor heating", "alarm system"],
  ["study room", "laundry room", "home office"],
  ["playground", "basketball court", "tennis court"],
  ["sauna", "spa", "steam room"],
  ["outdoor kitchen", "fire pit", "grill area"],
  ["library", "game room", "bar"],
  ["private cinema", "soundproof rooms", "music studio"],
  ["energy-efficient appliances", "rainwater harvesting", "greenhouse"],
  ["home automation", "voice control", "wireless charging stations"],
  ["indoor pool", "home gym", "yoga room"],
  ["guest suite", "separate entrance", "private balcony"],
  ["panoramic windows", "skylights", "vaulted ceilings"],
  ["backup generator", "water purifier", "air filtration system"],
  ["outdoor shower", "cabana", "sun deck"],
  ["kitchen", "en-suite", "cctv"],
  ["security", "balcony"],
  ["dog house", "guest house", "maid house"],
  ["swimming pool", "gym", "home theater"],
  ["walk-in pantry", "island kitchen", "breakfast nook"],
  ["pet-friendly", "dog run", "catio"],
  ["sound system", "media room", "gaming setup"],
  ["wine fridge", "butler's pantry", "second kitchen"],
  ["attic", "basement", "storage room"],
  ["outdoor lighting", "driveway", "carport"],
  ["hardwood floors", "custom cabinetry", "granite countertops"],
  ["floor-to-ceiling windows", "open-concept living", "chef's kitchen"],
];

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
      features: features[index % 3],
      image: `img/property${((index + 2) % 3) + 1}.jpg`,
      rentPrice: 23.45,
      projectData,
      unitPrice: projectData.data.fundingGoal / projectData.sftDetails.maxSupply,
    })) || []
  );
};
