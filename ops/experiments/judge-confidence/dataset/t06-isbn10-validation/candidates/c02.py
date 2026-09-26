def is_valid_isbn10(s):
    digits = s.replace("-", "")
    if len(digits) != 10:
        return False
    if not digits[:9].isdigit():
        return False
    last = digits[9]
    if last in "Xx":
        check = 10
    elif last.isdigit():
        check = int(last)
    else:
        return False
    total = sum(int(d) * (10 - i) for i, d in enumerate(digits[:9])) + check
    return total % 11 == 0
