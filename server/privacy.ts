/** Reject likely payment-card input before it reaches a provider. Never echo it. */
export function assertNoCardData(value: unknown): void {
  const visit = (v: unknown): boolean => {
    if (typeof v === "string") {
      // Normalize common Hindi/Arabic digits as well as ASCII.
      const text = v.replace(/[०-९٠-٩۰-۹]/g, (c) => String(c.charCodeAt(0) -
        (c >= "०" && c <= "९" ? 0x966 : c >= "٠" && c <= "٩" ? 0x660 : 0x6f0)));
      return /(?<!\d)(?:\d[ -]?){13,19}(?!\d)/.test(text);
    }
    if (Array.isArray(v)) return v.some(visit);
    return !!v && typeof v === "object" && Object.values(v).some(visit);
  };
  if (visit(value)) throw new Error("Please remove long card-like numbers. Use a payment preference such as pay on pickup instead.");
}

/** Allowlisted operational metadata only; no brief, phone, transcript, or tokens. */
export function safeCallLogArgs(args: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const key of ["plan_id", "run_id", "region", "language"]) {
    if (typeof args[key] === "string") out[key] = args[key];
  }
  if (Array.isArray(args.to_phones)) out.destinationCount = args.to_phones.length;
  return out;
}
