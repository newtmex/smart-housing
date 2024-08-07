"use client";

import PortfolioBalance from "~~/components/PortfolioBalance";
import PortfolioDistribution from "~~/components/PortfolioDistribution";
import ReferralCard from "~~/components/ReferralCard";
import Referrals from "~~/components/Referrals";

export default function Dashboard() {
  return (
    <>
      <div className="row">
        <PortfolioBalance />

        <div className="col-sm-2 d-none d-lg-block">
          <PortfolioDistribution />
        </div>

        <div className="col-sm-4 d-none d-lg-block">
          <ReferralCard />
        </div>
      </div>

      <div className="row">
        <div className="col-sm-8">
          <Referrals />
        </div>
      </div>
    </>
  );
}
