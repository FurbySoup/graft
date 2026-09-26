# rle_encode

Write a function `rle_encode(s: str) -> str` that run-length encodes a string of letters.
Each maximal run of identical consecutive characters is written as the run length (in decimal)
followed by the character; the count is always written, even when it is 1. Matching is
case-sensitive (`"a"` and `"A"` are different characters), and the empty string encodes to `""`.

Example: `rle_encode("aaabccdddd")` returns `"3a1b2c4d"`.
