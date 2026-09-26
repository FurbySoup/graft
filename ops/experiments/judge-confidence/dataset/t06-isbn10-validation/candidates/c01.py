def is_valid_isbn10(s):
    worth = {str(d): d for d in range(10)}
    stripped = [c for c in s if c != "-"]
    if len(stripped) != 10:
        return False
    running = 0
    accumulated = 0
    for index in range(10):
        c = stripped[index]
        if c in worth:
            v = worth[c]
        elif index == 9 and c == "X":
            v = 10
        else:
            return False
        running = running + v
        accumulated = accumulated + running
    return accumulated % 11 == 0
