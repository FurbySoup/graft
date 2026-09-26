import copy
import importlib.util
import signal
import sys

FUNC = 'merge_intervals'

CASES = [
    (([],), []),
    (([(5, 5)],), [(5, 5)]),
    (([(1, 3), (2, 6), (8, 10), (10, 12)],), [(1, 6), (8, 12)]),
    (([(8, 10), (1, 3), (2, 6)],), [(1, 6), (8, 10)]),
    (([(1, 10), (2, 3), (4, 5)],), [(1, 10)]),
    (([(1, 2), (3, 4)],), [(1, 2), (3, 4)]),
    (([(1, 4), (4, 4)],), [(1, 4)]),
    (([(-5, -1), (-3, 2)],), [(-5, 2)]),
    (([(1, 2), (2, 3), (3, 4)],), [(1, 4)]),
    (([(6, 7), (1, 2), (4, 5)],), [(1, 2), (4, 5), (6, 7)]),
]


def _timeout(signum, frame):
    raise TimeoutError("call exceeded 5s")


def main():
    if len(sys.argv) != 2:
        print("usage: python3 test_hidden.py <candidate.py>")
        sys.exit(1)
    signal.signal(signal.SIGALRM, _timeout)
    try:
        signal.alarm(5)
        spec = importlib.util.spec_from_file_location("candidate", sys.argv[1])
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        fn = getattr(mod, FUNC)
        signal.alarm(0)
    except BaseException as e:
        signal.alarm(0)
        print("FAIL: import error: %r" % (e,))
        sys.exit(1)
    failures = []
    for args, expected in CASES:
        try:
            signal.alarm(5)
            got = fn(*copy.deepcopy(args))
            signal.alarm(0)
        except BaseException as e:
            signal.alarm(0)
            failures.append("%s%r raised %r" % (FUNC, args, e))
            continue
        got = _normalize(got)
        if got != expected:
            failures.append("%s%r = %r, expected %r" % (FUNC, args, got, expected))
    if failures:
        print("FAIL: %d/%d cases failed" % (len(failures), len(CASES)))
        for f in failures:
            print("  " + f)
        sys.exit(1)
    print("PASS: %d/%d cases" % (len(CASES), len(CASES)))
    sys.exit(0)


def _normalize(value):
    if isinstance(value, list):
        try:
            return [tuple(x) for x in value]
        except TypeError:
            return value
    return value


if __name__ == "__main__":
    main()
