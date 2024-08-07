/**
 * Computes color for a particular string base on a seed
 *
 * With a bit of nudge from https://codepen.io/TimPietrusky/pen/pxCct
 * we define this function thus
 *
 * @param address The string to get color of
 * @returns CSS color
 */
export default function getColor(address: string, region = 0) {
  let color = 0;
  for (let i = address.length - 1; i >= Math.round(address.length / 2); i--) {
    color += "ywuk0al1bm2cn3do4ep5fq6gr7hs8it9jvxz".indexOf(address[i]);
    color *= i;
  }

  return `#${color.toString(16).substring(region, region + 6)}`;
}
