"use client";

import { Modal } from "./modal";

export function ConfirmDialog({
  open,
  title,
  message,
  confirmLabel = "Confirm",
  onConfirm,
  onCancel,
}: {
  open: boolean;
  title: string;
  message: string;
  confirmLabel?: string;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <Modal open={open} title={title} onClose={onCancel}>
      <p className="text-sm text-neutral-600">{message}</p>
      <div className="mt-6 flex justify-end gap-2">
        <button
          onClick={onCancel}
          className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
        >
          Cancel
        </button>
        <button
          onClick={onConfirm}
          className="rounded-md bg-red-600 px-3 py-1.5 text-sm font-medium text-white"
        >
          {confirmLabel}
        </button>
      </div>
    </Modal>
  );
}
