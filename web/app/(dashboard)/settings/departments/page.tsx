import { SimpleConfigManager } from "@/components/settings/simple-config-manager";

export default function DepartmentsPage() {
  return (
    <SimpleConfigManager
      collectionName="departments"
      title="Departments"
      singularLabel="Department"
    />
  );
}
