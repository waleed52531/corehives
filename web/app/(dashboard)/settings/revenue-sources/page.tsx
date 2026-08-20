import { SimpleConfigManager } from "@/components/settings/simple-config-manager";

export default function RevenueSourcesPage() {
  return (
    <SimpleConfigManager
      collectionName="revenue_sources"
      title="Cash-In Sources"
      singularLabel="Cash-In Source"
    />
  );
}
