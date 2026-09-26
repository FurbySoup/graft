def is_balanced(s):
    closers = {")": "(", "]": "[", "}": "{"}
    stack = []
    for ch in s:
        if ch in "([{":
            stack.append(ch)
        elif ch in closers:
            if not stack or stack[-1] != closers[ch]:
                return False
            stack.pop()
    return not stack
