"use client";

import PortfolioBalance from "~~/components/PortfolioBalance";
import PortfolioDistribution from "~~/components/PortfolioDistribution";

export default function Dashboard() {
  return (
    <>
      <div className="row">
        <PortfolioBalance />

        <div className="col-sm-2 d-none d-lg-block">
          <PortfolioDistribution />
        </div>
      </div>
    </>
  );
}
