def merge_intervals(intervals):
    ordered = sorted(intervals, key=lambda p: (p[0], p[1]))
    result = []
    i = 0
    while i < len(ordered):
        lo, hi = ordered[i]
        j = i + 1
        while j < len(ordered) and ordered[j][0] <= hi:
            if ordered[j][1] > hi:
                hi = ordered[j][1]
            j += 1
        result.append((lo, hi))
        i = j
    return result
