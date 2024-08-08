"use client";

import BlogSummary from "~~/components/BlogSummary";
import PortfolioBalance from "~~/components/PortfolioBalance";
import PortfolioDistribution from "~~/components/PortfolioDistribution";
import ReferralCard from "~~/components/ReferralCard";
import Referrals from "~~/components/Referrals";
import UserEcosystemTransactions from "~~/components/UserEcosystemTransactions";

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
          <BlogSummary />
        </div>
        <div className="col-sm-4">
          <UserEcosystemTransactions />
        </div>
      </div>
    </>
  );
}
