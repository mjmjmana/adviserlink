"""
Smart adviser matching: extracts key words from student's search and scores each adviser
based on how well their specializations (tags), name, and certifications match.

  - exact word in tags       = 3 points
  - partial match in tags    = 2 points (e.g., "web" in "website")
  - match in name/certs      = 1 point
The `percent` is the score relative to the maximum possible (0-100).
"""
import re

STOP = {
    "a", "an", "and", "the", "of", "for", "to", "in", "on", "with", "my", "our", "is", "are", "be", "i", "we",
    "want", "need", "about", "using", "use", "based", "system", "app", "application", "project", "thesis",
    "capstone", "study", "ang", "ng", "sa", "at", "na", "mga", "ko", "namin", "gusto", "para",
}


def _stem(word: str) -> str:
    if len(word) > 4 and word.endswith("ies"):
        return word[:-3] + "y"
    if len(word) > 3 and word.endswith("s") and not word.endswith(("ss", "us", "is")):
        return word[:-1]
    return word


def tokenize(text: str) -> list:
    """Splits into words, removes stopwords, and stems (simple stemming). No duplicates."""
    out = []
    for w in re.findall(r"[a-z0-9\+#\.]+", (text or "").lower()):
        w = w.strip(".")
        if len(w) < 2 or w in STOP:
            continue
        w = _stem(w)
        if w not in out:
            out.append(w)
    return out


def match_score(query_tokens, name: str, tags, certs: str):
    """Returns (score, percent, matched_words)."""
    tag_words = set()
    for t in tags:
        tag_words.update(tokenize(t))
    other = set(tokenize(name)) | set(tokenize(certs))
    score, matched = 0, []
    for q in query_tokens:
        if q in tag_words:
            score += 3
            matched.append(q)
        elif len(q) >= 3 and any(q in w or w in q for w in tag_words if len(w) >= 3):
            score += 2
            matched.append(q)
        elif q in other:
            score += 1
            matched.append(q)
    percent = round(100 * score / (3 * len(query_tokens))) if query_tokens else 0
    return score, min(percent, 100), matched
