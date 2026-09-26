# is_balanced

Write a function `is_balanced(s: str) -> bool` that reports whether the brackets in `s` are
balanced. The bracket pairs are `()`, `[]` and `{}`; every other character is ignored. The string
is balanced when every opening bracket is closed by the matching bracket type, in the correct
nesting order, and no closing bracket appears without a matching opener; a string with no
brackets (including `""`) is balanced.

Example: `is_balanced("a(b[c]d)e")` returns `True`, and `is_balanced("([)]")` returns `False`.
