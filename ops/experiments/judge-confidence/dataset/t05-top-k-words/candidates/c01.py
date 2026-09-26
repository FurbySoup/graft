import re
from collections import Counter


def top_k_words(text, k):
    counts = Counter(re.findall(r"[A-Za-z]+", text))
    ordered = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    return [word.lower() for word, _ in ordered[:k]]
