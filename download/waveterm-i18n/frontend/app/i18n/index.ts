// WaveTerm i18n Configuration
// Provides internationalization support with automatic language detection,
// persistent language preference, and runtime language switching.

import i18n from "i18next";
import { initReactI18next } from "react-i18next";

import en from "./locales/en.json";
import zhCN from "./locales/zh-CN.json";

// Supported languages with display names
export const supportedLanguages = [
  { code: "en", name: "English", nativeName: "English" },
  { code: "zh-CN", name: "Chinese (Simplified)", nativeName: "简体中文" },
] as const;

export type LanguageCode = (typeof supportedLanguages)[number]["code"];

const STORAGE_KEY = "waveterm-language";

/**
 * Detect the user's preferred language from:
 * 1. Saved preference in localStorage
 * 2. Browser language (navigator.language)
 * 3. Fallback to "en"
 */
function detectLanguage(): string {
  // 1. Check localStorage for saved preference
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved && supportedLanguages.some((l) => l.code === saved)) {
      return saved;
    }
  } catch {
    // localStorage may not be available (SSR, privacy mode, etc.)
  }

  // 2. Check browser language
  try {
    const browserLang = navigator.language; // e.g., "zh-CN", "en-US", "ja"
    if (browserLang) {
      // Try exact match first
      if (supportedLanguages.some((l) => l.code === browserLang)) {
        return browserLang;
      }
      // Try base language match (e.g., "zh" -> "zh-CN")
      const baseLang = browserLang.split("-")[0];
      if (baseLang === "zh") {
        return "zh-CN";
      }
    }
  } catch {
    // navigator may not be available
  }

  // 3. Fallback
  return "en";
}

// Save language preference
export function saveLanguage(lang: string): void {
  try {
    localStorage.setItem(STORAGE_KEY, lang);
  } catch {
    // Ignore
  }
}

// Change language at runtime
export async function changeLanguage(lang: string): Promise<void> {
  if (supportedLanguages.some((l) => l.code === lang)) {
    await i18n.changeLanguage(lang);
    saveLanguage(lang);
    document.documentElement.setAttribute("lang", lang);
  }
}

// Initialize i18next
i18n.use(initReactI18next).init({
  resources: {
    en: { translation: en },
    "zh-CN": { translation: zhCN },
  },
  lng: detectLanguage(),
  fallbackLng: "en",
  interpolation: {
    // React already handles XSS escaping
    escapeValue: false,
  },
});

// Set initial document lang attribute
try {
  document.documentElement.setAttribute("lang", i18n.language);
} catch {
  // Ignore in non-browser environments
}

export default i18n;
