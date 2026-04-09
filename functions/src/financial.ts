/* eslint-disable indent, require-jsdoc, valid-jsdoc */
import * as admin from "firebase-admin";
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from "crypto";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";

const financialMasterKey = defineSecret("FINANCIAL_MASTER_KEY");
const financeChurchGroupId = "finance";

type FinancialTransactionResponse = {
  id: string;
  title: string;
  description: string;
  category: string;
  paymentMethod: string;
  reference: string;
  recordedBy: string;
  amount: number;
  type: string;
  status: string;
  transactionDateMillis: number;
  createdAtMillis: number | null;
  updatedAtMillis: number | null;
};

export const getFinancialTransactions = onCall(
  {
    region: "us-central1",
    secrets: [financialMasterKey],
  },
  async (request) => {
    const churchId = readUnknownString(request.data?.churchId);
    const email = normalizeEmail(request.auth?.token.email ?? "");
    const uid = readUnknownString(request.auth?.uid);
    ensureAuthenticated(email);
    await ensureFinanceGroupMember(churchId, uid, email);

    const snapshot = await admin.firestore()
      .collection("churches")
      .doc(churchId)
      .collection("financial_transactions")
      .orderBy("updatedAt", "desc")
      .get();

    const transactions = await Promise.all(snapshot.docs.map(async (doc) => {
      return decodeFinancialTransactionDoc(
        doc,
        financialMasterKey.value(),
      );
    }));

    return {transactions};
  },
);

export const upsertFinancialTransaction = onCall(
  {
    region: "us-central1",
    secrets: [financialMasterKey],
  },
  async (request) => {
    const churchId = readUnknownString(request.data?.churchId);
    const transactionId = readUnknownString(request.data?.transactionId);
    const email = normalizeEmail(request.auth?.token.email ?? "");
    const uid = readUnknownString(request.auth?.uid);
    ensureAuthenticated(email);
    await ensureFinanceGroupMember(churchId, uid, email);

    const transaction = normalizeFinancialTransactionInput(
      request.data?.transaction,
    );
    const payload = encryptFinancialPayload(
      transaction,
      financialMasterKey.value(),
    );

    const collection = admin.firestore()
      .collection("churches")
      .doc(churchId)
      .collection("financial_transactions");
    const docRef = transactionId.length > 0 ?
      collection.doc(transactionId) :
      collection.doc();

    const writeData: Record<string, unknown> = {
      payload,
      encryption: "aes-256-gcm",
      schemaVersion: 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      title: admin.firestore.FieldValue.delete(),
      description: admin.firestore.FieldValue.delete(),
      category: admin.firestore.FieldValue.delete(),
      paymentMethod: admin.firestore.FieldValue.delete(),
      reference: admin.firestore.FieldValue.delete(),
      recordedBy: admin.firestore.FieldValue.delete(),
      amount: admin.firestore.FieldValue.delete(),
      type: admin.firestore.FieldValue.delete(),
      status: admin.firestore.FieldValue.delete(),
      transactionDate: admin.firestore.FieldValue.delete(),
    };

    if (transactionId.length === 0) {
      writeData.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }

    await docRef.set(writeData, {merge: true});

    return {id: docRef.id};
  },
);

export const deleteFinancialTransaction = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const churchId = readUnknownString(request.data?.churchId);
    const transactionId = readUnknownString(request.data?.transactionId);
    const email = normalizeEmail(request.auth?.token.email ?? "");
    const uid = readUnknownString(request.auth?.uid);
    ensureAuthenticated(email);
    await ensureFinanceGroupMember(churchId, uid, email);

    if (transactionId.length === 0) {
      throw new HttpsError("invalid-argument", "Missing transaction id.");
    }

    await admin.firestore()
      .collection("churches")
      .doc(churchId)
      .collection("financial_transactions")
      .doc(transactionId)
      .delete();

    return {success: true};
  },
);

function ensureAuthenticated(email: string): void {
  if (email.length === 0) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
}

async function ensureFinanceGroupMember(
  churchId: string,
  uid: string,
  email: string,
): Promise<void> {
  if (churchId.length === 0) {
    throw new HttpsError("invalid-argument", "Missing church id.");
  }
  if (uid.length === 0) {
    throw new HttpsError("unauthenticated", "Missing user identity.");
  }

  const userSnapshot = await admin.firestore()
    .collection("churches")
    .doc(churchId)
    .collection("users")
    .doc(uid)
    .get();

  if (!userSnapshot.exists) {
    throw new HttpsError(
      "permission-denied",
      "You must belong to the selected church to access finance data.",
    );
  }

  const churchGroupIds = Array.isArray(userSnapshot.data()?.churchGroupIds) ?
    userSnapshot.data()?.churchGroupIds as unknown[] :
    [];
  const normalizedGroupIds = churchGroupIds
    .map((item) => readUnknownString(item))
    .map((item) => item.toLowerCase())
    .filter(Boolean);

  if (!normalizedGroupIds.includes(financeChurchGroupId)) {
    throw new HttpsError(
      "permission-denied",
      `Only Finance group members can access financial data for ${email}.`,
    );
  }
}

function normalizeFinancialTransactionInput(
  value: unknown,
): Record<string, unknown> {
  const raw = value as Record<string, unknown> | undefined;
  const title = readUnknownString(raw?.title);
  const category = readUnknownString(raw?.category);
  const paymentMethod = readUnknownString(raw?.paymentMethod);
  const type = readUnknownString(raw?.type).toLowerCase();
  const status = readUnknownString(raw?.status).toLowerCase();
  const amount = readUnknownNumber(raw?.amount);
  const transactionDateMillis = readUnknownInteger(raw?.transactionDateMillis);

  if (title.length === 0) {
    throw new HttpsError("invalid-argument", "Transaction title is required.");
  }
  if (category.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Transaction category is required.",
    );
  }
  if (paymentMethod.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Transaction payment method is required.",
    );
  }
  if (!["income", "expense"].includes(type)) {
    throw new HttpsError("invalid-argument", "Transaction type is invalid.");
  }
  if (!["cleared", "pending"].includes(status)) {
    throw new HttpsError("invalid-argument", "Transaction status is invalid.");
  }
  if (amount <= 0) {
    throw new HttpsError("invalid-argument", "Transaction amount is invalid.");
  }
  if (transactionDateMillis <= 0) {
    throw new HttpsError(
      "invalid-argument",
      "Transaction date is required.",
    );
  }

  return {
    title,
    description: readUnknownString(raw?.description),
    category,
    paymentMethod,
    reference: readUnknownString(raw?.reference),
    recordedBy: readUnknownString(raw?.recordedBy),
    amount,
    type,
    status,
    transactionDateMillis,
  };
}

async function decodeFinancialTransactionDoc(
  doc: FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>,
  secret: string,
): Promise<FinancialTransactionResponse> {
  const data = doc.data();
  const createdAt = readUnknownDate(data.createdAt);
  const updatedAt = readUnknownDate(data.updatedAt);
  const payload = data.payload;

  if (isEncryptedPayload(payload)) {
    const decrypted = decryptFinancialPayload(payload, secret);
    return buildFinancialTransactionResponse(
      doc.id,
      decrypted,
      createdAt,
      updatedAt,
    );
  }

  const legacy = normalizeLegacyFinancialPayload(data);
  await migrateLegacyFinancialTransaction(
    doc.ref,
    legacy,
    createdAt,
    updatedAt,
    secret,
  );
  return buildFinancialTransactionResponse(
    doc.id,
    legacy,
    createdAt,
    updatedAt,
  );
}

function buildFinancialTransactionResponse(
  id: string,
  payload: Record<string, unknown>,
  createdAt: Date | null,
  updatedAt: Date | null,
): FinancialTransactionResponse {
  return {
    id,
    title: readUnknownString(payload.title),
    description: readUnknownString(payload.description),
    category: readUnknownString(payload.category),
    paymentMethod: readUnknownString(payload.paymentMethod),
    reference: readUnknownString(payload.reference),
    recordedBy: readUnknownString(payload.recordedBy),
    amount: readUnknownNumber(payload.amount),
    type: readUnknownString(payload.type),
    status: readUnknownString(payload.status),
    transactionDateMillis: readUnknownInteger(payload.transactionDateMillis),
    createdAtMillis: createdAt ? createdAt.getTime() : null,
    updatedAtMillis: updatedAt ? updatedAt.getTime() : null,
  };
}

function normalizeLegacyFinancialPayload(
  data: Record<string, unknown>,
): Record<string, unknown> {
  const transactionDate = readUnknownDate(data.transactionDate);
  return {
    title: readUnknownString(data.title),
    description: readUnknownString(data.description),
    category: readUnknownString(data.category),
    paymentMethod: readUnknownString(data.paymentMethod),
    reference: readUnknownString(data.reference),
    recordedBy: readUnknownString(data.recordedBy),
    amount: readUnknownNumber(data.amount),
    type: readUnknownString(data.type),
    status: readUnknownString(data.status),
    transactionDateMillis: transactionDate ? transactionDate.getTime() : 0,
  };
}

async function migrateLegacyFinancialTransaction(
  reference:
    FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>,
  payload: Record<string, unknown>,
  createdAt: Date | null,
  updatedAt: Date | null,
  secret: string,
): Promise<void> {
  const encrypted = encryptFinancialPayload(payload, secret);
  await reference.set({
    payload: encrypted,
    encryption: "aes-256-gcm",
    schemaVersion: 1,
    createdAt: createdAt ?
      admin.firestore.Timestamp.fromDate(createdAt) :
      admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: updatedAt ?
      admin.firestore.Timestamp.fromDate(updatedAt) :
      admin.firestore.FieldValue.serverTimestamp(),
    title: admin.firestore.FieldValue.delete(),
    description: admin.firestore.FieldValue.delete(),
    category: admin.firestore.FieldValue.delete(),
    paymentMethod: admin.firestore.FieldValue.delete(),
    reference: admin.firestore.FieldValue.delete(),
    recordedBy: admin.firestore.FieldValue.delete(),
    amount: admin.firestore.FieldValue.delete(),
    type: admin.firestore.FieldValue.delete(),
    status: admin.firestore.FieldValue.delete(),
    transactionDate: admin.firestore.FieldValue.delete(),
  }, {merge: true});
}

function isEncryptedPayload(value: unknown): value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const payload = value as Record<string, unknown>;
  return typeof payload.nonce === "string" &&
    typeof payload.cipherText === "string" &&
    typeof payload.tag === "string";
}

function encryptFinancialPayload(
  payload: Record<string, unknown>,
  secret: string,
): Record<string, unknown> {
  const key = deriveFinancialKey(secret);
  const nonce = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, nonce);
  cipher.setAAD(Buffer.from("church_financial_transaction_v1"));
  const cipherText = Buffer.concat([
    cipher.update(JSON.stringify(payload), "utf8"),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();

  return {
    nonce: nonce.toString("base64"),
    cipherText: cipherText.toString("base64"),
    tag: tag.toString("base64"),
    version: 1,
  };
}

function decryptFinancialPayload(
  payload: Record<string, unknown>,
  secret: string,
): Record<string, unknown> {
  const key = deriveFinancialKey(secret);
  const decipher = createDecipheriv(
    "aes-256-gcm",
    key,
    Buffer.from(readUnknownString(payload.nonce), "base64"),
  );
  decipher.setAAD(Buffer.from("church_financial_transaction_v1"));
  decipher.setAuthTag(Buffer.from(readUnknownString(payload.tag), "base64"));

  const clearText = Buffer.concat([
    decipher.update(
      Buffer.from(readUnknownString(payload.cipherText), "base64"),
    ),
    decipher.final(),
  ]).toString("utf8");

  const decoded = JSON.parse(clearText);
  if (!decoded || typeof decoded !== "object" || Array.isArray(decoded)) {
    throw new HttpsError("internal", "Encrypted financial payload is invalid.");
  }

  return decoded as Record<string, unknown>;
}

function deriveFinancialKey(secret: string): Buffer {
  return createHash("sha256").update(secret, "utf8").digest();
}

function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

function readUnknownString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function readUnknownDate(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function readUnknownInteger(value: unknown): number {
  if (typeof value === "number") return Math.round(value);
  if (typeof value === "string") {
    return Number.parseInt(value.trim() || "0", 10) || 0;
  }
  return 0;
}

function readUnknownNumber(value: unknown): number {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    return Number.parseFloat(value.trim() || "0") || 0;
  }
  return 0;
}
