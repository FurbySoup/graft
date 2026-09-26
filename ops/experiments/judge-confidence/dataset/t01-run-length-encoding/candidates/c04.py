from itertools import groupby


def rle_encode(s):
    result = ""
    for ch, grp in groupby(s.lower()):
        result += str(len(list(grp))) + ch
    return result
