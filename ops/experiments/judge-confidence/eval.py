#!/usr/bin/env python3
"""R-03: compare ways of deriving the tier-2 judge's confidence (raw_conf) that an
artifact is correct. Stdlib only; talks to Ollama on localhost; deterministic
(temperature 0, fixed seed). Labels come from dataset/labels.csv (hidden-test exit
codes), never from a model.

Methods (each yields p_correct in [0, 1]):
  A  grammar, verdict-first  SPEC §3.2 JSON schema, verdict field first; p = prob of the
                             sampled verdict token as Ollama reports it (status quo).
  A2 grammar, verdict-first, renormalised: same call; p = mass on pass-prefix tokens /
                             (pass + fail mass) among top_logprobs at the verdict position.
  D  grammar, notes-first    schema with `notes` before `verdict`; renormalised as A2.
  B  option likelihood       unconstrained; one token, "yes or no"; p = P(yes)/(P(yes)+P(no)).
  C  reason, then score      free analysis first (≤300 tokens), then B's question on top.

Usage: eval.py [--model graft-judge:cpu] [--out results.json]
"""
import argparse, csv, json, math, pathlib, time, urllib.request

HERE = pathlib.Path(__file__).resolve().parent
DATA = HERE / "dataset"
OLLAMA = "http://localhost:11434/api/chat"
OPTS = {"temperature": 0, "seed": 7, "num_ctx": 4096}
TOP = 20

SYSTEM = ("You are a strict code reviewer. You are given a programming task and a "
          "candidate solution. Decide whether the candidate fully and correctly "
          "implements the task, including edge cases. You cannot run the code.")


def chat(model, messages, fmt=None, num_predict=None, logprobs=True):
    body = {"model": model, "messages": messages, "stream": False,
            "options": dict(OPTS, **({"num_predict": num_predict} if num_predict else {}))}
    if logprobs:
        body.update(logprobs=True, top_logprobs=TOP)
    if fmt is not None:
        body["format"] = fmt
    req = urllib.request.Request(OLLAMA, json.dumps(body).encode(),
                                 {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=900) as r:
        return json.load(r)


def user_prompt(task, code):
    return f"## Task\n{task.strip()}\n\n## Candidate solution\n```python\n{code.rstrip()}\n```\n"


def schema(order):
    props = {"verdict": {"type": "string", "enum": ["pass", "fail", "unclear"]},
             "notes": {"type": "string"}}
    return {"type": "object", "properties": {k: props[k] for k in order},
            "required": list(order)}


def verdict_position(resp):
    """Index into resp['logprobs'] of the first token of the verdict value."""
    lps = resp.get("logprobs") or []
    text, starts = "", []
    for t in lps:
        starts.append(len(text)); text += t["token"]
    key = text.find('"verdict"')
    if key < 0:
        return None
    colon = text.find(":", key)
    quote = text.find('"', colon + 1)
    target = quote + 1
    for i, s in enumerate(starts):
        if s <= target < s + len(lps[i]["token"]) or s >= target:
            # token may begin with the quote itself ('"pass'); step past pure-quote tokens
            if lps[i]["token"].strip().strip('"') == "":
                continue
            return i
    return None


def renorm(tops, yes_words, no_words):
    y = n = 0.0
    for t in tops:
        w = t["token"].strip().strip('"').lower()
        if not w:
            continue
        p = math.exp(t["logprob"])
        if any(yw.startswith(w) for yw in yes_words):
            y += p
        elif any(nw.startswith(w) for nw in no_words):
            n += p
    return (y / (y + n)) if (y + n) > 0 else None


def grammar_method(model, task, code, order):
    r = chat(model, [{"role": "system", "content": SYSTEM},
                     {"role": "user", "content": user_prompt(task, code) +
                      "\nAnswer in JSON: verdict is pass, fail or unclear; notes is a short justification."}],
             fmt=schema(order), num_predict=400)
    try:
        verdict = json.loads(r["message"]["content"]).get("verdict")
    except json.JSONDecodeError:
        verdict = None
    i = verdict_position(r)
    sampled = renormed = None
    if i is not None:
        tok = r["logprobs"][i]
        ps = math.exp(tok["logprob"])
        sampled = ps if verdict == "pass" else (1 - ps) if verdict == "fail" else 0.5
        renormed = renorm(tok.get("top_logprobs", []), ["pass"], ["fail"])
    return verdict, sampled, renormed


YESNO = "\nIs the candidate solution fully correct? Reply with exactly one word: yes or no."


def yes_no(r):
    lp = (r.get("logprobs") or [{}])[0]
    return renorm(lp.get("top_logprobs", []), ["yes"], ["no"])


def method_b(model, task, code):
    r = chat(model, [{"role": "system", "content": SYSTEM},
                     {"role": "user", "content": user_prompt(task, code) + YESNO}], num_predict=1)
    return yes_no(r)


def method_c(model, task, code):
    msgs = [{"role": "system", "content": SYSTEM},
            {"role": "user", "content": user_prompt(task, code) +
             "\nAnalyse the candidate briefly: trace it on the task's example and on edge cases, and list any bug you find."}]
    a = chat(model, msgs, num_predict=300, logprobs=False)
    msgs += [{"role": "assistant", "content": a["message"]["content"]},
             {"role": "user", "content": YESNO.strip()}]
    return yes_no(chat(model, msgs, num_predict=1))


def metrics(ps, ys):
    """ps: p_correct or None (method produced no usable signal); ys: 1 correct / 0 incorrect."""
    missing = sum(p is None for p in ps)
    ps = [0.5 if p is None else p for p in ps]
    n = len(ps)
    acc = sum((p > 0.5) == bool(y) for p, y in zip(ps, ys)) / n
    brier = sum((p - y) ** 2 for p, y in zip(ps, ys)) / n
    pos = [p for p, y in zip(ps, ys) if y]; neg = [p for p, y in zip(ps, ys) if not y]
    auroc = sum((a > b) + 0.5 * (a == b) for a in pos for b in neg) / (len(pos) * len(neg))
    ece, bins = 0.0, 5
    for b in range(bins):
        lo, hi = b / bins, (b + 1) / bins
        idx = [i for i, p in enumerate(ps) if lo <= p < hi or (b == bins - 1 and p == 1.0)]
        if idx:
            ece += len(idx) / n * abs(sum(ps[i] for i in idx) / len(idx) - sum(ys[i] for i in idx) / len(idx))
    return {"n": n, "missing": missing, "accuracy": round(acc, 3), "auroc": round(auroc, 3),
            "brier": round(brier, 3), "ece5": round(ece, 3)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="graft-judge:cpu")
    ap.add_argument("--out", default=str(HERE / "results.json"))
    a = ap.parse_args()
    rows = list(csv.DictReader(open(DATA / "labels.csv")))
    per_item, secs = [], {m: 0.0 for m in ("A", "D", "B", "C")}
    for row in rows:
        tdir = DATA / row["task"]
        task = (tdir / "task.md").read_text()
        code = (tdir / "candidates" / f"{row['candidate']}.py").read_text()
        rec = {"item": row["item_id"], "label": row["label"]}
        t = time.time(); rec["A_verdict"], rec["A"], rec["A2"] = grammar_method(a.model, task, code, ("verdict", "notes")); secs["A"] += time.time() - t
        t = time.time(); rec["D_verdict"], _, rec["D"] = grammar_method(a.model, task, code, ("notes", "verdict")); secs["D"] += time.time() - t
        t = time.time(); rec["B"] = method_b(a.model, task, code); secs["B"] += time.time() - t
        t = time.time(); rec["C"] = method_c(a.model, task, code); secs["C"] += time.time() - t
        per_item.append(rec)
        print(json.dumps(rec), flush=True)
    ys = [1 if r["label"] == "correct" else 0 for r in per_item]
    summary = {m: metrics([r[m] for r in per_item], ys) for m in ("A", "A2", "D", "B", "C")}
    for m in summary:
        summary[m]["mean_seconds"] = round(secs[m[0]] / len(per_item), 1)
    out = {"model": a.model, "options": OPTS, "top_logprobs": TOP, "summary": summary, "items": per_item}
    pathlib.Path(a.out).write_text(json.dumps(out, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
