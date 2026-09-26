def int_to_roman(n):
    values = [1000, 900, 500, 100, 90, 50, 40, 10, 9, 5, 4, 1]
    numerals = ["M", "CM", "D", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
    result = ""
    i = 0
    while n > 0:
        while n >= values[i]:
            result += numerals[i]
            n -= values[i]
        i += 1
    return result
