def int_to_roman(n):
    symbols = [("I", "V", "X"), ("X", "L", "C"), ("C", "D", "M"), ("M", "", "")]
    out = ""
    place = 0
    while n > 0:
        d = n % 10
        one, five, ten = symbols[place]
        if d == 9:
            part = one + ten
        elif d >= 5:
            part = five + one * (d - 5)
        elif d == 4:
            part = one + five
        else:
            part = one * d
        out = part + out
        n //= 10
        place += 1
    return out
