import ReferralCard from "./ReferralCard";

export default function BlogSummary() {
  return (
    <div className="row">
      <div className="col-12 col-xxl-8">
        <div className="element-wrapper compact pt-4">
          <h6 className="element-header">Real Estate News</h6>
          <div className="element-box-tp">
            <div className="post-box">
              <div className="post-media"></div>
              <div className="post-content">
                <h6 className="post-title">Is RWA the Future of Blockchain Financing?</h6>
                <div className="post-text">
                  Curiously, view both tone emerged. There should which yards two and concepts amidst liabilities
                  sitting of and, parents it wait
                </div>
                <div className="post-foot">
                  <div className="post-tags">
                    <div className="badge badge-primary">opBNB</div>
                    <div className="badge badge-primary">Crypto</div>
                  </div>
                  <a className="post-link" href="#">
                    <span>Read Full Story</span>
                    <i className="os-icon os-icon-arrow-right7"></i>
                  </a>
                </div>
              </div>
            </div>
            <div className="post-box">
              <div className="post-media"></div>
              <div className="post-content">
                <h6 className="post-title">All you need to know about investing in RWA</h6>
                <div className="post-text">
                  Curiously, view both tone emerged. There should which yards two and concepts amidst liabilities
                  sitting of and, parents it wait
                </div>
                <div className="post-foot">
                  <div className="post-tags">
                    <div className="badge badge-primary">housing</div>
                    <div className="badge badge-primary">RWA</div>
                  </div>
                  <a className="post-link" href="#">
                    <span>Read Full Story</span>
                    <i className="os-icon os-icon-arrow-right7"></i>
                  </a>
                </div>
              </div>
            </div>
            <a className="centered-load-more-link" href="#">
              <span>Read Our Blog</span>
            </a>
          </div>
        </div>
      </div>
      <div className="col-12 d-sm-none d-xxl-block col-xxl-4">
        <ReferralCard />
      </div>
    </div>
  );
}
