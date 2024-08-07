import React, { useEffect, useRef } from "react";
import BigNumber from "bignumber.js";
import { ChartData } from "chart.js";
import { useAccountTokens } from "~~/hooks";
import Chart from "~~/utils/chart";
import { prettyFormatAmount } from "~~/utils/prettyFormatAmount";

interface IPortfolioHighlight {
  backgroundColor: string;
  data: string;
  title: string;
}
const PortfolioHighlight: React.FC<IPortfolioHighlight> = ({ backgroundColor, data, title, ...props }) => (
  <div {...props} className="legend-value-w">
    <div
      className="legend-pin legend-pin-squared"
      style={{
        backgroundColor,
      }}
    ></div>
    <div className="legend-value">
      <span>{data}</span>
      <div className="legend-sub-value">{title}</div>
    </div>
  </div>
);

let chart: Chart | undefined;

export default function PortfolioDistribution() {
  const { ownedAssets } = useAccountTokens();

  const doughnutChartRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const values: any[] = [];
    const backgroundColor: string[] = [];
    const labels: string[] = [];

    for (const { symbol, value, backgroundColor: color } of ownedAssets) {
      values.push(value);
      backgroundColor.push(color);
      labels.push(symbol);
    }

    const data: ChartData<"doughnut"> = {
      labels,
      datasets: [
        {
          data: values,
          backgroundColor,
          hoverBackgroundColor: backgroundColor,
          borderColor: "transparent",
          hoverBorderColor: "transparent",
        },
      ],
    };

    if (!chart || !chart.canvas) {
      chart = new Chart(doughnutChartRef.current!, {
        type: "doughnut",
        data,
        options: {
          // @ts-ignore
          cutout: "80%",
          plugins: {
            tooltip: {
              callbacks: {
                beforeBody(tooltipItems) {
                  const value = (tooltipItems[0].raw as string).toString();
                  tooltipItems[0].formattedValue = prettyFormatAmount({ value: value.replace(".", ""), decimals: 2 });
                },
              },
            },
          },
        },
      });
    } else {
      chart.data = data;
      chart.update();
    }
  }, [ownedAssets]);

  useEffect(
    () => () => {
      chart?.destroy();
    },
    [],
  );

  return (
    <div className="element-box less-padding">
      <h6 className="element-box-header text-center">Portfolio Distribution</h6>
      <div
        className="el-chart-w"
        style={{
          position: "relative",
          display: "flex",
          justifyContent: "center",
        }}
      >
        <canvas ref={doughnutChartRef}></canvas>
        <div className="inside-donut-chart-label">
          <strong>{ownedAssets.length}</strong>
          <span>Assets</span>
        </div>
      </div>

      <div className="el-legend condensed">
        <div className="row">
          {ownedAssets
            ?.sort((a, b) => +BigNumber(b.value).minus(a.value))
            .reduce<(typeof ownedAssets)[]>((acc, curr, index) => {
              const row = acc[index] || [];
              if (row.length < 2) {
                acc[index] = [...row, curr];
              } else {
                acc[index + 1] = [curr];
              }
              return acc;
            }, [])
            .map((row, rowIndex) => (
              <div
                key={"portfolio-highlight-row" + rowIndex}
                className={
                  rowIndex > 0 ? "col-sm-6 d-none d-xxxxl-block" : "col-auto col-xxxxl-6 ml-sm-auto mr-sm-auto"
                }
              >
                {row.map(({ backgroundColor, qty, decimals, symbol }) => (
                  <PortfolioHighlight
                    key={symbol}
                    backgroundColor={backgroundColor}
                    data={symbol}
                    title={prettyFormatAmount({ value: qty, length: 10, minLength: 16, decimals })}
                  />
                ))}{" "}
              </div>
            ))}
        </div>
      </div>
    </div>
  );
}
