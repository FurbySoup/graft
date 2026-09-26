def is_balanced(s):
    kept = "".join(ch for ch in s if ch in "()[]{}")
    previous = None
    while previous != kept:
        previous = kept
        for pair in ("()", "[]", "{}"):
            kept = kept.replace(pair, "")
    return len(kept) == 0
