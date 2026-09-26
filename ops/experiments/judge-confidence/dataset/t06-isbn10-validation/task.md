# is_valid_isbn10

Write a function `is_valid_isbn10(s: str) -> bool` that validates an ISBN-10. Remove every hyphen
from `s`; what remains must be exactly 10 characters, the first 9 must be digits `0-9`, and the last
must be a digit or an uppercase `X` (worth 10) — any other character (including spaces or a lowercase
`x`) makes it invalid. With values `d0..d9`, the ISBN is valid iff
`d0*10 + d1*9 + ... + d9*1` is divisible by 11.

Example: `is_valid_isbn10("3-598-21508-8")` returns `True`, and `is_valid_isbn10("3-598-21508-9")` returns `False`.
