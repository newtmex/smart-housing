import { ReactNode, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import BigNumber from "bignumber.js";
import { useAccountTokens, useTokenPrices } from "~~/hooks";
import { useProjects } from "~~/hooks/housingProject";
import { useWindowWidthChange } from "~~/hooks/useWindowResize";
import { prettyFormatAmount } from "~~/utils/prettyFormatAmount";
import { RoutePath } from "~~/utils/routes";

interface TableProps<TableData> {
  data: TableData[];
  renderTableData: (data: TableData, index: number) => ReactNode;
}

function TabTable<T = any>({ data, renderTableData }: TableProps<T>) {
  const [rows, setRows] = useState<(typeof data)[]>([]);
  const [windowWidth, setWindowWidth] = useState(0);

  useWindowWidthChange(() => {
    setWindowWidth(window.innerWidth);
  });

  // Do data grouping
  useEffect(() => {
    const rowsCount = data.length > 3 ? (windowWidth <= 768 || data.length >= 7 ? Math.ceil(data.length / 2) : 2) : 1;

    const rows: (typeof data)[] = [];
    let rowDataCount = Math.floor(data.length / rowsCount);
    rowDataCount <= 0 && (rowDataCount = 1);

    let remainder = data.length < rowsCount ? 0 : data.length % rowsCount;
    let sliceLimit = remainder > 0 ? rowDataCount + 1 : rowDataCount;
    for (let i = 0; i < data.length; i += sliceLimit) {
      remainder > 0 ? (remainder -= 1) : (sliceLimit = rowDataCount);

      rows.push(data.slice(i, i + sliceLimit));
    }

    setRows(rows);
  }, [data, windowWidth]);

  if (rows.length <= 0) {
    return null;
  }

  return (
    <table style={{ width: 0 }} className="table table-lightborder table-bordered table-v-compact mb-0">
      <tbody>
        {rows.map((row, index) => (
          <tr key={"tr" + index}>{row.map((data, index) => renderTableData(data, index))}</tr>
        ))}
      </tbody>
    </table>
  );
}

export default function PortfolioBalance() {
  const prices = useTokenPrices();
  const { sht, lkSht, projectsToken } = useAccountTokens();
  const projectsTokenDetail = useProjects().map(v => ({
    symbol: v.projectData.sftDetails.symbol,
    name: v.projectData.sftDetails.name,
  }));

  const portfolioValue = useMemo(() => {
    let value = new BigNumber(0);

    for (const token of [sht, lkSht, ...(projectsToken || [])]) {
      if (token) {
        const price = prices["projectData" in token ? token.projectData.sftDetails.symbol : token.symbol];

        value = value
          .plus(new BigNumber(token.balance.toString()).multipliedBy(price.toFixed(2)))
          .dividedBy(10 ** ("projectData" in token ? 0 : token.decimals));
      }
    }

    return prettyFormatAmount({ value: value.toFixed(0), decimals: 2 });
  }, [sht, lkSht, projectsToken, prices]);

  return (
    <div className="col-sm-12 col-lg-8 col-xxl-6">
      <div className="element-balances justify-content-between mobile-full-width">
        <div className="balance balance-v2">
          <div className="balance-title">Your Portfolio Balance</div>
          <div className="balance-value">
            <span className="d-xxl-none">${portfolioValue}</span>
            <span className="d-none d-xxl-inline-block">${portfolioValue}</span>
          </div>
        </div>
        <div className="balance-table pl-sm-2">
          <TabTable
            data={projectsTokenDetail}
            renderTableData={token => (
              <td key={token.symbol}>
                <strong>${prices[token.symbol].toFixed(2)}</strong>
                <div className="balance-label smaller lighter text-nowrap">
                  {token.name} {token.symbol}
                </div>
              </td>
            )}
          />
        </div>
      </div>
      <div className="element-wrapper pb-4 mb-4 border-bottom">
        <div className="element-box-tp">
          <Link className="btn btn-primary" href={RoutePath.Properties}>
            <i className="os-icon os-icon-plus-circle"></i>
            <span>Buy Property</span>
          </Link>
        </div>
      </div>
    </div>
  );
}
