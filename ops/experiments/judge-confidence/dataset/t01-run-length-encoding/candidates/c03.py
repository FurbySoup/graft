def rle_encode(s):
    out = []
    count = 1
    for i in range(1, len(s)):
        if s[i] == s[i - 1]:
            count += 1
        else:
            out.append(f"{count}{s[i - 1]}")
            count = 1
    return "".join(out)
