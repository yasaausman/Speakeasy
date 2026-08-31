/** Supported user-side languages. The phone call itself is always English;
 *  these are the languages the USER speaks/reads and hears narrated back. */
export type LangCode =
  | "en" | "es" | "hi" | "ar"
  | "zh" | "vi" | "fr" | "pt" | "ko" | "tl" | "ru" | "ht";

export interface LanguageInfo {
  code: LangCode;
  name: string; // English name
  endonym: string; // name in its own script
  ttsLocale: string; // iOS AVSpeechSynthesizer voice
  sttLocale: string; // iOS SFSpeechRecognizer locale
  rtl: boolean;
}

export const LANGUAGES: Record<LangCode, LanguageInfo> = {
  en: { code: "en", name: "English", endonym: "English", ttsLocale: "en-US", sttLocale: "en-US", rtl: false },
  es: { code: "es", name: "Spanish", endonym: "Español", ttsLocale: "es-ES", sttLocale: "es-ES", rtl: false },
  hi: { code: "hi", name: "Hindi", endonym: "हिन्दी", ttsLocale: "hi-IN", sttLocale: "hi-IN", rtl: false },
  ar: { code: "ar", name: "Arabic", endonym: "العربية", ttsLocale: "ar-SA", sttLocale: "ar-SA", rtl: true },
  zh: { code: "zh", name: "Chinese", endonym: "中文", ttsLocale: "zh-CN", sttLocale: "zh-CN", rtl: false },
  vi: { code: "vi", name: "Vietnamese", endonym: "Tiếng Việt", ttsLocale: "vi-VN", sttLocale: "vi-VN", rtl: false },
  fr: { code: "fr", name: "French", endonym: "Français", ttsLocale: "fr-FR", sttLocale: "fr-FR", rtl: false },
  pt: { code: "pt", name: "Portuguese", endonym: "Português", ttsLocale: "pt-BR", sttLocale: "pt-BR", rtl: false },
  ko: { code: "ko", name: "Korean", endonym: "한국어", ttsLocale: "ko-KR", sttLocale: "ko-KR", rtl: false },
  tl: { code: "tl", name: "Tagalog", endonym: "Tagalog", ttsLocale: "fil-PH", sttLocale: "fil-PH", rtl: false },
  ru: { code: "ru", name: "Russian", endonym: "Русский", ttsLocale: "ru-RU", sttLocale: "ru-RU", rtl: false },
  ht: { code: "ht", name: "Haitian Creole", endonym: "Kreyòl", ttsLocale: "fr-FR", sttLocale: "fr-FR", rtl: false },
};

export function isLangCode(x: unknown): x is LangCode {
  return typeof x === "string" && x in LANGUAGES;
}

export function coerceLang(x: unknown, fallback: LangCode = "en"): LangCode {
  return isLangCode(x) ? x : fallback;
}
