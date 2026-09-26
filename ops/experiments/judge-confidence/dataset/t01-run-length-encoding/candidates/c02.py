from itertools import groupby


def rle_encode(s):
    return "".join(f"{len(list(group))}{char}" for char, group in groupby(s))
