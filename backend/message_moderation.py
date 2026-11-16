import re
import unicodedata


ENGLISH_MARKERS = frozenset({
    "a", "an", "and", "are", "before", "can", "for", "from", "hello", "how",
    "i", "is", "it", "please", "send", "thank", "that", "the", "this", "to",
    "was", "we", "were", "what", "will", "with", "you", "your",
})
FILIPINO_MARKERS = frozenset({
    "ako", "ang", "at", "ay", "ba", "bago", "hindi", "ito", "kami", "ka",
    "kay", "ko", "kumusta", "mga", "mo", "na", "ng", "oo", "pa", "po",
    "pwede", "salamat", "sa", "si", "sila", "tayo", "wala", "yung",
})

PROFANITY_TERMS = frozenset({
    "asshole", "bastard", "bitch", "damn", "fuck", "fucking", "leche",
    "motherfucker", "pakyu", "puta", "putangina", "putang ina", "shit",
    "tangina",
})
PERSONAL_ATTACK_TERMS = frozenset({
    "bobo", "gaga", "gago", "idiot", "kupal", "moron", "stupid", "tanga",
    "tarantado", "ulol",
})


def detect_message_language(message: str) -> str:
    tokens = re.findall(r"[a-zñ]+", unicodedata.normalize("NFKC", message).casefold())
    english_hits = sum(token in ENGLISH_MARKERS for token in tokens)
    filipino_hits = sum(token in FILIPINO_MARKERS for token in tokens)

    if english_hits and filipino_hits:
        return "mixed"
    if filipino_hits:
        return "tl"
    if english_hits:
        return "en"
    return "unknown"


def _contains_term(message: str, term: str) -> bool:
    normalized = unicodedata.normalize("NFKC", message).casefold()
    phrase_pattern = re.escape(term).replace(r"\ ", r"[\W_]+")
    return re.search(r"(?<!\w)" + phrase_pattern + r"(?!\w)", normalized) is not None


def analyze_message(message: str) -> tuple[str, list[str]]:
    language = detect_message_language(message)
    categories = []

    if any(_contains_term(message, term) for term in PROFANITY_TERMS):
        categories.append("profanity")
    if any(_contains_term(message, term) for term in PERSONAL_ATTACK_TERMS):
        categories.append("personal_attack")

    return language, categories
