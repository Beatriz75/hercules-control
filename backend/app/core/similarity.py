"""Find questions similar to a new one, to avoid repeating questions in the bank."""

from difflib import SequenceMatcher
import re
import unicodedata

STOPWORDS = {
    "a", "al", "ante", "con", "cual", "cuales", "cuando", "de", "del", "debe", "el", "en", "es", "esta", "este",
    "la", "las", "le", "lo", "los", "o", "para", "por", "que", "qué", "se", "si", "su", "sus", "un", "una", "y",
    "como", "donde", "haces", "hace", "hay", "mas", "no", "tu", "te",
}


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.lower())
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9ñ ]+", " ", text).strip()


def _tokens(text: str) -> set[str]:
    return {word for word in normalize(text).split() if word not in STOPWORDS and len(word) > 1}


def similarity(a: str, b: str) -> float:
    """0..1 — the higher of word overlap (ignoring order and filler words) and character similarity."""
    na, nb = normalize(a), normalize(b)
    if not na or not nb:
        return 0.0
    ratio = SequenceMatcher(None, na, nb).ratio()
    ta, tb = _tokens(a), _tokens(b)
    jaccard = len(ta & tb) / len(ta | tb) if ta and tb else 0.0
    return max(ratio, jaccard)
