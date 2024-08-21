import Link from "next/link";
import { RoutePath } from "~~/utils/routes";

export default function BuyPropertyLink() {
  return (
    <Link className="btn btn-primary" href={RoutePath.Properties}>
      <i className="os-icon os-icon-plus-circle"></i>
      <span>Buy Property</span>
    </Link>
  );
}
