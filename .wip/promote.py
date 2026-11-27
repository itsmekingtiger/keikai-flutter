#!/usr/bin/env python3
"""Moves finished work from the working directory into the repository checkout.

  promote.py commit "<subject>" [--body "<body>"] <path>...
      Mirrors each path (file or directory, relative to the roots) from the
      working directory into the checkout and commits exactly those paths.
      A path that no longer exists in the working directory is removed.

  promote.py verify
      flutter analyze + flutter test in the checkout. Exit code 0 when green.

  promote.py push
      verify, then push main. Refuses to push a tree that is not green.

Commits are made per feature unit; a push closes one task.
"""
import os, shutil, subprocess, sys

WORK = '/home/user/keikai'
REPO = '/home/user/keikai-flutter'
TRAILER = ('\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n'
           'Claude-Session: https://claude.ai/code/session_01XRqxUN3g1FvNnHhytHNh2H')
ENV = dict(os.environ, PATH='/opt/sdk/flutter/bin:' + os.environ.get('PATH', ''))
SKIP_DIRS = {'.dart_tool', 'build', 'failures', 'frames', '_review', '.idea'}


def run(cmd, cwd=REPO, check=True, quiet=False):
    r = subprocess.run(cmd, cwd=cwd, env=ENV, text=True, capture_output=True)
    if check and r.returncode != 0:
        sys.stdout.write(r.stdout[-4000:] + r.stderr[-4000:])
        raise SystemExit(f'FAILED: {" ".join(cmd)}')
    return r


def mirror(rel):
    src, dst = os.path.join(WORK, rel), os.path.join(REPO, rel)
    if os.path.isdir(src):
        # Copy the directory, then drop files that are gone from the source.
        for root, dirs, files in os.walk(src):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            out = os.path.join(dst, os.path.relpath(root, src))
            os.makedirs(out, exist_ok=True)
            for f in files:
                shutil.copy2(os.path.join(root, f), os.path.join(out, f))
        for root, dirs, files in os.walk(dst):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for f in files:
                twin = os.path.join(src, os.path.relpath(os.path.join(root, f), dst))
                if not os.path.exists(twin):
                    os.remove(os.path.join(root, f))
    elif os.path.isfile(src):
        os.makedirs(os.path.dirname(dst) or '.', exist_ok=True)
        shutil.copy2(src, dst)
    else:
        if os.path.isdir(dst):
            shutil.rmtree(dst)
        elif os.path.exists(dst):
            os.remove(dst)


def commit(args):
    subject, body, paths = args[0], '', []
    i = 1
    while i < len(args):
        if args[i] == '--body':
            body = args[i + 1]
            i += 2
        else:
            paths.append(args[i])
            i += 1
    if not paths:
        raise SystemExit('no paths')
    for p in paths:
        mirror(p)
    run(['git', 'add', '-A', '--'] + paths)
    if run(['git', 'diff', '--cached', '--quiet'], check=False).returncode == 0:
        print(f'PROMOTE: nothing to commit for "{subject}"')
        return
    msg = subject + (('\n\n' + body) if body else '') + TRAILER
    run(['git', 'commit', '-q', '-m', msg])
    print('PROMOTE: ' + run(['git', 'log', '--oneline', '-1']).stdout.strip())


def verify():
    for d in (REPO, os.path.join(REPO, 'example')):
        if run(['flutter', 'pub', 'get', '--offline'], cwd=d, check=False).returncode != 0:
            run(['flutter', 'pub', 'get'], cwd=d)
    r = run(['flutter', 'analyze'], check=False)
    tail = '\n'.join(r.stdout.strip().splitlines()[-12:])
    print('== analyze\n' + tail)
    if r.returncode != 0:
        return 5
    g = run(['grep', '-rnE', r'package:flutter/(material|cupertino)\.dart', 'lib', 'example/lib', 'test'], check=False)
    if g.stdout.strip():
        print('== forbidden imports\n' + g.stdout)
        return 6
    r = run(['flutter', 'test'], check=False)
    lines = r.stdout.strip().splitlines()
    print('== test\n' + '\n'.join(lines[-1:] if r.returncode == 0 else lines[-25:]))
    return 0 if r.returncode == 0 else 7


def push():
    dirty = run(['git', 'status', '--porcelain']).stdout.strip()
    if dirty:
        print('PROMOTE: checkout has uncommitted changes:\n' + dirty[:2000])
        return 3
    code = verify()
    if code != 0:
        print('PROMOTE: not pushing, the tree is not green')
        return code
    for attempt in range(4):
        run(['git', '-c', 'push.negotiate=true', 'push', 'origin', 'main'], check=False)
        head = run(['git', 'rev-parse', 'HEAD']).stdout.strip()
        remote = run(['git', 'rev-parse', 'origin/main'], check=False).stdout.strip()
        if head == remote:
            print('PROMOTE: pushed ' + run(['git', 'log', '--oneline', '-1']).stdout.strip())
            return 0
        import time
        time.sleep(4 * (attempt + 1))
    print('PROMOTE: push failed')
    return 9


# ── one family, one commit per feature ───────────────────────────────────

import re
import textwrap

WIDGET_BASES = ('StatelessWidget', 'StatefulWidget', 'SingleChildRenderObjectWidget',
                'MultiChildRenderObjectWidget', 'LeafRenderObjectWidget', 'ParentDataWidget',
                'InheritedWidget', 'KkFlexible', 'KkFlex')


def _public_names(path):
    """(widget classes, other public classes) declared in a Dart file, in order."""
    src = open(path).read()
    widgets, others = [], []
    for m in re.finditer(r'^(?:abstract |final |sealed |base |interface )*class (\w+)([^{]*)\{', src, re.M):
        name, rest = m.group(1), m.group(2)
        if name.startswith('_') or name.startswith('Render'):
            continue
        (widgets if any(b in rest for b in WIDGET_BASES) else others).append(name)
    return widgets, others


def _doc_of(path, name):
    """First paragraph of the doc comment above `class name`."""
    lines = open(path).read().splitlines()
    for i, line in enumerate(lines):
        if re.match(r'^(?:abstract |final |sealed |base |interface )*class ' + re.escape(name) + r'\b', line):
            doc = []
            j = i - 1
            while j >= 0 and (lines[j].startswith('///') or lines[j].startswith('@')):
                if lines[j].startswith('///'):
                    doc.insert(0, lines[j][3:].strip())
                j -= 1
            para = []
            for d in doc:
                if not d:
                    break
                para.append(d)
            return ' '.join(para)
    return ''


def _join(names):
    if len(names) == 1:
        return names[0]
    if len(names) > 3:
        names = names[:3] + [f'{len(names) - 3} more']
    return ', '.join(names[:-1]) + ' and ' + names[-1]


def _subject_and_body(family, rel):
    path = os.path.join(WORK, rel)
    widgets, others = _public_names(path)
    stem = os.path.basename(rel)[:-5]
    if widgets:
        body = _doc_of(path, widgets[0])
        return 'Add ' + _join(widgets), body
    if others:
        return 'Add ' + _join(others), _doc_of(path, others[0])
    return f'Add the {stem.replace("_", " ")} helpers of the {family} family', ''


def _wrap(text):
    text = re.sub(r'\[([^\]]+)\]', r'\1', text.replace('`', ''))
    return '\n'.join(textwrap.wrap(text, 72))


def family(name, extra_final=()):
    libdir = f'lib/src/{name}'
    testdir = f'test/{name}'
    barrel = f'{name}.dart'
    files = sorted(f for f in os.listdir(os.path.join(WORK, libdir)) if f.endswith('.dart') and f != barrel)
    deps = {}
    for f in files:
        src = open(os.path.join(WORK, libdir, f)).read()
        deps[f] = {m for m in re.findall(r"^import '([a-z_0-9]+\.dart)';", src, re.M) if m in files and m != f}
    order, done = [], set()
    while len(order) < len(files):
        ready = [f for f in files if f not in done and deps[f] <= done]
        if not ready:  # an import cycle: take what is left in name order
            ready = [f for f in files if f not in done]
        for f in ready[:1] if deps[ready[0]] - done else ready:
            order.append(f)
            done.add(f)
    tests = sorted(f for f in os.listdir(os.path.join(WORK, testdir)) if f.endswith('.dart')) if os.path.isdir(os.path.join(WORK, testdir)) else []
    sheet_test = f'{name}_sheet_test.dart'
    paired = set()
    for f in order:
        rel = f'{libdir}/{f}'
        paths = [rel]
        twin = f[:-5] + '_test.dart'
        if twin in tests:
            paths.append(f'{testdir}/{twin}')
            paired.add(twin)
        subject, body = _subject_and_body(name, rel)
        commit([subject, '--body', _wrap(body)] + paths if body else [subject] + paths)
    helpers = [t for t in tests if not t.endswith('_test.dart')]
    loose = [t for t in tests if t.endswith('_test.dart') and t not in paired and t != sheet_test]
    if helpers or loose:
        first = True
        for t in loose:
            paths = [f'{testdir}/{t}'] + ([f'{testdir}/{h}' for h in helpers] if first else [])
            first = False
            commit([f'Test the {name} family: {t[:-10].replace("_", " ")}'] + paths)
        if first and helpers:
            commit([f'Add the test helpers of the {name} family'] + [f'{testdir}/{h}' for h in helpers])
    final = [f'{libdir}/{barrel}', 'lib/keikai.dart', f'example/lib/sheets/{name}_sheet.dart',
             f'{testdir}/{sheet_test}', f'{testdir}/goldens'] + list(extra_final)
    commit([f'Export the {name} family and add its catalogue sheet'] + final)


# ── snapshots of single fixes, one commit each ───────────────────────────

BANNED = ('finding', 'reviewer', 'claude', 'fable', 'opus', 'sonnet', 'workflow', 'agent')


def _snapshots(group_dir):
    out = []
    for n in sorted(os.listdir(group_dir)):
        d = os.path.join(group_dir, n)
        if not os.path.isdir(d):
            continue
        files = []
        for root, _dirs, fs in os.walk(d):
            for f in fs:
                rel = os.path.relpath(os.path.join(root, f), d)
                if rel != 'message.txt':
                    files.append(rel)
        msg = ''
        mp = os.path.join(d, 'message.txt')
        if os.path.exists(mp):
            msg = open(mp).read().strip()
        out.append((n, d, sorted(files), msg))
    return out


def show(group_dir):
    """Prints every snapshot of a group: message, files, and whether the message is fit to commit."""
    for n, d, files, msg in _snapshots(group_dir):
        first = msg.splitlines()[0] if msg else ''
        flags = []
        if not msg:
            flags.append('NO MESSAGE')
        if len(first) > 72:
            flags.append(f'SUBJECT {len(first)} CHARS')
        low = msg.lower()
        flags += [f'WORD "{w}"' for w in BANNED if w in low]
        print(f'--- {os.path.basename(group_dir)}/{n} {" ".join(flags)}')
        print(msg)
        for f in files:
            print('    ' + f)


def replay(group_dir, start=None):
    """Commits each numbered snapshot folder of a group, in order, from snapshot [start] on."""
    for n, d, files, msg in _snapshots(group_dir):
        if start is not None and n < start:
            continue
        if not files:
            print(f'PROMOTE: {n}: no files, skipped')
            continue
        if not msg:
            raise SystemExit(f'{d}: no message.txt')
        for rel in files:
            dst = os.path.join(REPO, rel)
            os.makedirs(os.path.dirname(dst) or '.', exist_ok=True)
            shutil.copy2(os.path.join(d, rel), dst)
        run(['git', 'add', '-A', '--'] + files)
        if run(['git', 'diff', '--cached', '--quiet'], check=False).returncode == 0:
            print(f'PROMOTE: {n}: nothing new in "{msg.splitlines()[0]}"')
            continue
        run(['git', 'commit', '-q', '-m', msg + TRAILER])
        print('PROMOTE: ' + run(['git', 'log', '--oneline', '-1']).stdout.strip())


def drift(paths):
    """Lists the given paths whose content differs between the working directory and the checkout."""
    bad = []
    for rel in paths:
        a, b = os.path.join(WORK, rel), os.path.join(REPO, rel)
        ea, eb = os.path.exists(a), os.path.exists(b)
        if ea != eb or (ea and open(a, 'rb').read() != open(b, 'rb').read()):
            bad.append(rel)
    print('\n'.join(bad) if bad else 'PROMOTE: no drift')
    return 1 if bad else 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    cmd = sys.argv[1]
    if cmd == 'commit':
        commit(sys.argv[2:])
    elif cmd == 'family':
        family(sys.argv[2], sys.argv[3:])
    elif cmd == 'show':
        show(sys.argv[2])
    elif cmd == 'replay':
        replay(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    elif cmd == 'drift':
        raise SystemExit(drift(sys.argv[2:]))
    elif cmd == 'verify':
        raise SystemExit(verify())
    elif cmd == 'push':
        raise SystemExit(push())
    else:
        raise SystemExit(__doc__)
