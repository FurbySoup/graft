def merge_intervals(intervals):
    merged = []
    for start, end in sorted(intervals, key=lambda x: x[0]):
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], end)
        else:
            merged.append((start, end))
    return merged
