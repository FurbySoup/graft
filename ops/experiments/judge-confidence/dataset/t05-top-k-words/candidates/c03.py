def top_k_words(text, k):
    letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    tally = {}
    buffer = ""
    for ch in text + " ":
        if ch in letters:
            buffer += ch.lower()
        else:
            if buffer:
                tally[buffer] = tally.get(buffer, 0) + 1
            buffer = ""
    chosen = []
    remaining = dict(tally)
    while len(chosen) < k and remaining:
        best = None
        for word, count in remaining.items():
            if best is None:
                best = word
            elif count > remaining[best]:
                best = word
            elif count == remaining[best] and word < best:
                best = word
        chosen.append(best)
        del remaining[best]
    return chosen
