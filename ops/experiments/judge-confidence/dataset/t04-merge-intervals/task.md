# merge_intervals

Write a function `merge_intervals(intervals: list[tuple[int, int]]) -> list[tuple[int, int]]`
that merges closed integer intervals `(start, end)` with `start <= end`, given in any order.
Intervals that overlap or merely touch (share an endpoint, e.g. `(1, 2)` and `(2, 3)`) are merged
into one; the result is a list of tuples sorted by start, and an empty input gives `[]`.

Example: `merge_intervals([(8, 10), (1, 3), (2, 6), (10, 12)])` returns `[(1, 6), (8, 12)]`.
