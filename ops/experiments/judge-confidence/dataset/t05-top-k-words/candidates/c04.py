import re
from collections import Counter


def top_k_words(text, k):
    counts = Counter(w.lower() for w in re.findall(r"[A-Za-z]+", text))
    ranked = sorted(counts, key=lambda w: (-counts[w], w))
    return ranked[:k]
