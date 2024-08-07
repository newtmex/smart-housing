import { useDeployedContractInfo, useTargetNetwork } from "./scaffold-eth";
import { usePublicClient } from "wagmi";

export default function useRawCallsInfo() {
  const { targetNetwork } = useTargetNetwork();

  const { data: coinbase } = useDeployedContractInfo("Coinbase");
  const { data: projectFunding } = useDeployedContractInfo("ProjectFunding");
  const { data: smartHousing } = useDeployedContractInfo("SmartHousing");
  const { data: housingProject } = useDeployedContractInfo("HousingProject");
  const { data: housingSFT } = useDeployedContractInfo("HousingSFT");
  const { data: lkSHT } = useDeployedContractInfo("LkSHT");
  const client = usePublicClient({ chainId: targetNetwork.id });

  return {
    client,
    smartHousing,
    projectFunding,
    coinbase,
    housingProjectAbi: housingProject?.abi,
    housingSFTAbi: housingSFT?.abi,
    lkSHTAbi: lkSHT?.abi,
  };
}
