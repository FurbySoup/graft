def is_valid_isbn10(s):
    chars = s.replace("-", "")
    if len(chars) != 10:
        return False
    total = 0
    for i, ch in enumerate(chars):
        if ch in "0123456789":
            value = int(ch)
        elif ch == "X" and i == 9:
            value = 10
        else:
            return False
        total += value * (10 - i)
    return total % 11 == 0
