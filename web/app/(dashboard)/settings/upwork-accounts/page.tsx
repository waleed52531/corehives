import { SimpleConfigManager } from "@/components/settings/simple-config-manager";

export default function UpworkAccountsPage() {
  return (
    <SimpleConfigManager
      collectionName="upwork_accounts"
      title="Upwork Accounts"
      singularLabel="Upwork Account"
      hasNotes
    />
  );
}
