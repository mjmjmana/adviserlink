const LANGUAGE_LABELS = {
  en: "English",
  tl: "Filipino/Tagalog",
  mixed: "English + Filipino",
  unknown: "",
};

export function messageLanguageLabel(languageCode) {
  return LANGUAGE_LABELS[languageCode] || "";
}
