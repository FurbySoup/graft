def is_balanced(s):
    counts = {"(": 0, "[": 0, "{": 0}
    closers = {")": "(", "]": "[", "}": "{"}
    for ch in s:
        if ch in counts:
            counts[ch] += 1
        elif ch in closers:
            counts[closers[ch]] -= 1
            if counts[closers[ch]] < 0:
                return False
    return all(v == 0 for v in counts.values())
