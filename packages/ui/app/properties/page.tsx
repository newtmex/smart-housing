import Properties from ".";
import { Metadata } from "next";

export const metadata: Metadata = {
  title: "Smart Housing | Properties",
  description: "Prperties for Sale or Rent",
};

export default function PropertiesPage() {
  return <Properties />;
}
