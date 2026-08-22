"""Mutation testing for Dart — this project's only such tool.

## Why it exists

Open item 129 says nothing detects a test that passes while asserting
nothing. The backend answers that with Stryker; **no mature mutation tool
exists for Dart**, recorded at Mission 7.10 and still true. The alternative
was hand-mutating 207 tests, which is neither reproducible nor reviewable —
and Mission 7.10 already found that a carelessly chosen mutation proves
nothing, so the choice of mutation has to be inspectable after the fact.

## What it does

Mutates ONE source line at a time, runs only the test file that covers it,
records a survivor when the suite still passes, and restores the file. Every
rule in RULES is a behaviour change, never a no-op.

## How it was invoked for the Mission 8.1 sweep

    # track (b) — full domain census, every domain source with a test
    python tool/dartmutate.py trackb lib/features/*/domain/**.dart
    #   73 mutants, 68 killed, 5 survived (4 of them equivalent mutants)

    # track (a) — stratified sample, seed 20260822, n=12 per stratum,
    # equal allocation, random-within-stratum, drawn BEFORE any mutation
    python tool/dartmutate.py tracka-core        <9 sources>
    python tool/dartmutate.py tracka-app         <5 sources>
    python tool/dartmutate.py tracka-application <9 sources>
    python tool/dartmutate.py tracka-data        <10 sources>
    python tool/dartmutate.py tracka-presentation <8 sources>
    #   273 mutants, 204 killed, 69 survived

## The caveat that governs its numbers

**It runs only the co-located test file**, so a survivor means "not caught by
the test next to it" — not "not caught by the suite". Calibrated at Mission
8.1: mutating `auth_guard.dart`'s role comparison survives
`auth_guard_test.dart` and fails the full suite with four failures. Every
kill rate it reports is therefore a FLOOR.

## Two things it cannot do

It does not detect equivalent mutants — four of track (b)'s five survivors
were mathematically unkillable and had to be reasoned about by hand. And it
has no incremental mode, so a full sweep re-runs everything.
"""

import io, os, re, subprocess, sys, json, time

# Run from the `mobile/` package root.
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# (pattern, replacement, label) — each is a behaviour change, never a no-op.
RULES = [
    (r'(?<![=!<>])==(?!=)', '!=', 'equality flip'),
    (r'!=', '==', 'inequality flip'),
    (r'(?<![<>=!])>=', '>', 'boundary >= to >'),
    (r'(?<![<>=!])<=', '<', 'boundary <= to <'),
    (r'&&', '||', 'and to or'),
    (r'\|\|', '&&', 'or to and'),
    (r'\btrue\b', 'false', 'true to false'),
    (r'\bfalse\b', 'true', 'false to true'),
]

SKIP_LINE = re.compile(r'^\s*(//|///|\*|/\*)')


def test_for(src):
    """lib/a/b/c.dart -> test/a/b/c_test.dart, if it exists."""
    cand = src.replace('lib/', 'test/', 1).replace('.dart', '_test.dart')
    if os.path.exists(cand):
        return cand
    # Some tests sit a directory above their source (camera_specification is
    # under domain/entities/ and its test under domain/). Fall back to a
    # basename search rather than silently dropping the file.
    import glob as _g
    want = os.path.basename(src).replace('.dart', '_test.dart')
    hits = [h.replace(os.sep, '/') for h in _g.glob('test/**/' + want, recursive=True)]
    return hits[0] if hits else None


def run(test_path, timeout=180):
    r = subprocess.run(['flutter', 'test', test_path, '--no-pub'],
                       capture_output=True, text=True, encoding='utf-8',
                       errors='replace', shell=True, timeout=timeout)
    return 'All tests passed!' in (r.stdout or '')


def mutants_for(src):
    lines = io.open(src, encoding='utf-8').read().split('\n')
    out = []
    for i, line in enumerate(lines):
        if SKIP_LINE.match(line) or not line.strip():
            continue
        for pat, rep, label in RULES:
            for m in re.finditer(pat, line):
                out.append((i, m.start(), m.end(), rep, label, line))
    return lines, out


def sweep(sources, tag, budget_seconds=1500):
    started = time.time()
    results = {'tag': tag, 'killed': 0, 'survived': [], 'no_test': [],
               'skipped_over_budget': 0, 'total_run': 0}
    for src in sources:
        tp = test_for(src)
        if tp is None:
            results['no_test'].append(src)
            continue
        original = io.open(src, encoding='utf-8').read()
        lines, muts = mutants_for(src)
        # Baseline must be green or the file's results mean nothing.
        if not run(tp):
            results['no_test'].append(src + '  (BASELINE RED)')
            continue
        for (i, a, b, rep, label, line) in muts:
            if time.time() - started > budget_seconds:
                results['skipped_over_budget'] += 1
                continue
            mutated = list(lines)
            mutated[i] = line[:a] + rep + line[b:]
            io.open(src, 'w', encoding='utf-8', newline='\n').write('\n'.join(mutated))
            try:
                passed = run(tp)
            except subprocess.TimeoutExpired:
                passed = False
            finally:
                io.open(src, 'w', encoding='utf-8', newline='\n').write(original)
            results['total_run'] += 1
            if passed:
                results['survived'].append({
                    'source': src, 'test': tp, 'line': i + 1,
                    'mutation': label, 'was': line.strip()[:110],
                    'became': (line[:a] + rep + line[b:]).strip()[:110],
                })
            else:
                results['killed'] += 1
    return results


if __name__ == '__main__':
    tag = sys.argv[1]
    sources = sys.argv[2:]
    res = sweep(sources, tag)
    dest = 'dartmut-%s.json' % tag
    io.open(dest, 'w', encoding='utf-8').write(json.dumps(res, indent=2))
    print('%s: ran %d, killed %d, survived %d, no-test %d, over-budget %d'
          % (tag, res['total_run'], res['killed'], len(res['survived']),
             len(res['no_test']), res['skipped_over_budget']))
    print('written:', dest)
