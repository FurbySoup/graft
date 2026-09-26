def rle_encode(s):
    pieces = []
    position = 0
    total = len(s)
    while position < total:
        current = s[position]
        run_end = position
        while run_end < total and s[run_end] == current:
            run_end = run_end + 1
        run_length = run_end - position
        pieces.append(str(run_length))
        pieces.append(current)
        position = run_end
    encoded = ""
    for piece in pieces:
        encoded = encoded + piece
    return encoded
