import re
from collections import Counter


def top_k_words(text, k):
    words = re.findall(r"[a-z]+", text.lower())
    return [word for word, _ in Counter(words).most_common(k)]
