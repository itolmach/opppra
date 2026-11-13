#!/usr/bin/env python3
"""Splits a .sql file into statements, respecting Postgres quoting.

Needed because the migrations have to be applied over HTTPS (this sandbox
allows no outbound 5432), one statement at a time, and a naive split on ';'
cuts straight through the function bodies in 0001 and the DO block in 0005 --
both of which are dollar-quoted and full of semicolons.
"""
import io, json, re, sys

def split(sql):
    out, buf, i, n = [], [], 0, len(sql)
    tag = None          # open dollar-quote tag, e.g. '$$' or '$fn$'
    quote = None        # open ' or "
    while i < n:
        ch = sql[i]
        if tag:
            if sql.startswith(tag, i):
                buf.append(tag); i += len(tag); tag = None; continue
        elif quote:
            if ch == quote:
                # '' and "" are escaped quotes, not a close.
                if i + 1 < n and sql[i + 1] == quote:
                    buf.append(ch * 2); i += 2; continue
                quote = None
        elif ch in "'\"":
            quote = ch
        elif ch == '-' and sql.startswith('--', i):
            j = sql.find('\n', i)
            j = n if j < 0 else j
            buf.append(sql[i:j]); i = j; continue
        elif ch == '/' and sql.startswith('/*', i):
            j = sql.find('*/', i)
            j = n if j < 0 else j + 2
            buf.append(sql[i:j]); i = j; continue
        elif ch == '$':
            m = re.match(r'\$[A-Za-z_]\w*\$|\$\$', sql[i:])
            if m:
                tag = m.group(0)
                buf.append(tag); i += len(tag); continue
        elif ch == ';':
            stmt = ''.join(buf).strip()
            if stmt:
                out.append(stmt)
            buf = []; i += 1; continue
        buf.append(ch); i += 1
    tail = ''.join(buf).strip()
    if tail:
        out.append(tail)
    # A statement that is only comments does nothing and confuses error
    # reporting, so drop those.
    return [s for s in out if re.sub(r'--[^\n]*|/\*.*?\*/', '', s, flags=re.S).strip()]

if __name__ == '__main__':
    stmts = split(io.open(sys.argv[1], encoding='utf-8').read())
    if len(sys.argv) > 2 and sys.argv[2] == '--json':
        print(json.dumps(stmts))
    else:
        print(f'{sys.argv[1]}: {len(stmts)} statements')
        for s in stmts:
            first = next((l for l in s.splitlines() if l.strip() and not l.strip().startswith('--')), '')
            print(f'  {first.strip()[:78]}')
