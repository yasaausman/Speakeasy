/** Supported user-side languages. The phone call itself is always English;
 *  these are the languages the USER speaks/reads and hears narrated back. */
export type LangCode = "en" | "es" | "hi" | "ar";

export interface LanguageInfo {
  code: LangCode;
  name: string; // English name
  endonym: string; // name in its own script
  ttsLocale: string; // iOS AVSpeechSynthesizer voice (Phase B2)
  sttLocale: string; // iOS SFSpeechRecognizer locale (Phase B1)
  rtl: boolean;
}

export const LANGUAGES: Record<LangCode, LanguageInfo> = {
  en: { code: "en", name: "English", endonym: "English", ttsLocale: "en-US", sttLocale: "en-US", rtl: false },
  es: { code: "es", name: "Spanish", endonym: "Español", ttsLocale: "es-ES", sttLocale: "es-ES", rtl: false },
  hi: { code: "hi", name: "Hindi", endonym: "हिन्दी", ttsLocale: "hi-IN", sttLocale: "hi-IN", rtl: false },
  ar: { code: "ar", name: "Arabic", endonym: "العربية", ttsLocale: "ar-SA", sttLocale: "ar-SA", rtl: true },
};

export function isLangCode(x: unknown): x is LangCode {
  return typeof x === "string" && x in LANGUAGES;
}

export function coerceLang(x: unknown, fallback: LangCode = "en"): LangCode {
  return isLangCode(x) ? x : fallback;
}
