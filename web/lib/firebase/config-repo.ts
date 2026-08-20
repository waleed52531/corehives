import {
  collection,
  doc,
  onSnapshot,
  query,
  orderBy,
  where,
  addDoc,
  updateDoc,
  serverTimestamp,
  QuerySnapshot,
  DocumentData,
} from "firebase/firestore";
import { db, auth } from "./client";

/** Subscribe to all docs in a config collection, newest-first fallback if no `order` field used. */
export function listenAll<T>(
  collectionName: string,
  cb: (rows: (T & { id: string })[]) => void,
  orderField = "name"
) {
  const q = query(collection(db, collectionName), orderBy(orderField));
  return onSnapshot(q, (snap: QuerySnapshot<DocumentData>) => {
    cb(snap.docs.map((d) => ({ ...(d.data() as T), id: d.id })));
  });
}

/** Subscribe to only active docs — for use by transaction-entry forms (mobile/web). */
export function listenActive<T>(
  collectionName: string,
  cb: (rows: (T & { id: string })[]) => void,
  orderField = "name"
) {
  const q = query(
    collection(db, collectionName),
    where("active", "==", true),
    orderBy(orderField)
  );
  return onSnapshot(q, (snap) => {
    cb(snap.docs.map((d) => ({ ...(d.data() as T), id: d.id })));
  });
}

function requireUid(): string {
  const uid = auth.currentUser?.uid;
  if (!uid) throw new Error("Not signed in.");
  return uid;
}

export async function createConfigDoc(
  collectionName: string,
  data: Record<string, unknown>
) {
  const uid = requireUid();
  return addDoc(collection(db, collectionName), {
    ...data,
    active: data.active ?? true,
    createdAt: serverTimestamp(),
    createdByUserId: uid,
    updatedAt: serverTimestamp(),
    updatedByUserId: uid,
  });
}

export async function updateConfigDoc(
  collectionName: string,
  id: string,
  data: Record<string, unknown>
) {
  const uid = requireUid();
  return updateDoc(doc(db, collectionName, id), {
    ...data,
    updatedAt: serverTimestamp(),
    updatedByUserId: uid,
  });
}

export async function setActive(collectionName: string, id: string, active: boolean) {
  return updateConfigDoc(collectionName, id, { active });
}

/** Case-insensitive trimmed-name duplicate check against an already-loaded list. */
export function isDuplicateName<T extends { id: string; name: string }>(
  rows: T[],
  name: string,
  excludeId?: string
): boolean {
  const normalized = name.trim().toLowerCase();
  return rows.some(
    (r) => r.id !== excludeId && r.name.trim().toLowerCase() === normalized
  );
}
