def is_valid_isbn10(s):
    chars = s.replace("-", "")
    if len(chars) != 10:
        return False
    total = 0
    for i, ch in enumerate(chars):
        if ch == "X":
            value = 10
        elif ch.isdigit():
            value = int(ch)
        else:
            return False
        total += value * (10 - i)
    return total % 11 == 0
