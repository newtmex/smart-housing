import { ArcElement, Chart, DoughnutController, Point, Tooltip } from "chart.js";

Chart.register(Tooltip, DoughnutController, ArcElement);

const defaultFont = Chart.defaults.font;
defaultFont.family =
  '"Proxima Nova W01", -apple-system, system-ui, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif'; // set defaults;

Chart.defaults.font = defaultFont;
Chart.defaults.plugins.tooltip.titleFont = { ...defaultFont, size: 14 };
Chart.defaults.plugins.tooltip.titleMarginBottom = 4;
Chart.defaults.plugins.tooltip.displayColors = false;
Chart.defaults.plugins.tooltip.bodyFont = { ...defaultFont, size: 12 };
(Chart.defaults.plugins.tooltip.padding as unknown as Point) = { x: 10, y: 8 };

export default Chart;
