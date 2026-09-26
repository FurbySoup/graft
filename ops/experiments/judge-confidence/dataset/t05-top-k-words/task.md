# top_k_words

Write a function `top_k_words(text: str, k: int) -> list[str]` that returns the `k` most frequent
words in `text`. A word is a maximal run of ASCII letters (`a-z`, `A-Z`); words are compared
case-insensitively and returned in lowercase. Order the result by descending count, breaking ties
alphabetically; if there are fewer than `k` distinct words return them all, and `k == 0` gives `[]`
(`k` is never negative).

Example: `top_k_words("the cat and the hat. The end", 2)` returns `["the", "and"]`.
