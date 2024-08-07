import BlockiesImage from "./BlockiesImage";
import useSWR from "swr";
import { useAccount } from "wagmi";
import useRawCallsInfo from "~~/hooks/useRawCallsInfo";
import { truncateFromInside } from "~~/utils";

export default function Referrals() {
  const { address } = useAccount();
  const { client, smartHousing } = useRawCallsInfo();
  const { data: referrals } = useSWR(
    client && smartHousing && address ? { key: "Referrals-getUserReferrals", address, client, smartHousing } : null,
    ({ address, client, smartHousing }) =>
      client.readContract({
        abi: smartHousing.abi,
        address: smartHousing.address,
        functionName: "getReferrals",
        args: [address],
      }),
  );

  if (!referrals?.length) {
    return null;
  }

  return (
    <div className="element-wrapper compact pt-4">
      <h6 className="element-header">Your Referrals</h6>
      <div className="element-box-tp">
        <div className="inline-profile-tiles">
          <div className="row">
            <div className="col-4 col-sm-3 col-xxl-2">
              {referrals.map(({ id, referralAddress }) => (
                <div key={id + referralAddress} className="profile-tile profile-tile-inlined">
                  <a className="profile-tile-box" href="">
                    <div className="pt-avatar-w">
                      <BlockiesImage seed={referralAddress} />
                    </div>
                    <div className="pt-user-name">{truncateFromInside(referralAddress, 15)}</div>
                  </a>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
