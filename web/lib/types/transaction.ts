export type TxType = "expense" | "cash_in";
export type AttachmentStatus = "none" | "pending" | "uploaded" | "failed";
export type SourceType = "Upwork" | "Front Sale" | "PayPal" | "Direct Client" | "Fiverr" | "Other";

export interface Transaction {
  id: string;
  type: TxType;
  sourceType?: SourceType;
  amountPaisa: number;
  currency: "PKR";

  categoryId?: string;
  categoryName?: string;
  subcategoryId?: string;
  subcategoryName?: string;

  payeeId?: string;
  payeeName?: string;

  projectId?: string;
  projectName?: string;

  employeeId?: string;
  employeeName?: string;

  upworkAccountId?: string;
  upworkAccountName?: string;

  salespersonEmployeeId?: string;
  salespersonName?: string;
  clientName?: string;

  paidByUserId: string;
  paidByUserName: string;
  paymentMethod?: string;

  transactionDateKey: string;
  monthKey: string;

  status: string;
  attachmentUrl?: string | null;
  attachmentStoragePath?: string | null;
  attachmentStatus: AttachmentStatus;

  description?: string;
  notes?: string;

  lateEntry: boolean;
  lateEntryReason?: string;
  originalMonthKey?: string;

  createdByUserId: string;
  createdByName: string;
  createdAt: unknown;
  updatedAt: unknown;
  deletedAt: unknown | null;
  deletedByUserId?: string | null;
}
