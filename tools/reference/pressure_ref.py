"""Scratch evaluator for «Давление» rules v0 (not project code).

Grid chars:
  .  empty         #  wall
  S  source (outlets given separately)
  T  tap (requirement given separately)
  I  straight  L corner  Y tee  X cross   (rotatable)
Directions: 0=N 1=E 2=S 3=W.
"""
import heapq, itertools, random

DX = [0, 1, 0, -1]
DY = [-1, 0, 1, 0]
OPP = lambda d: (d + 2) % 4
BASE = {'I': 0b0101, 'L': 0b0011, 'Y': 0b0111, 'X': 0b1111}  # bit d = arm toward d


def rot(mask, r):
    r %= 4
    return ((mask << r) | (mask >> (4 - r))) & 0b1111


def distinct_rots(ch):
    seen, out = set(), []
    for r in range(4):
        m = rot(BASE[ch], r)
        if m not in seen:
            seen.add(m); out.append(m)
    return out


class Level:
    def __init__(self, rows, H, outlets, req, L=2):
        self.rows = rows; self.h = len(rows); self.w = len(rows[0])
        self.H = H; self.L = L
        self.outlets = outlets          # list of dirs from source
        self.req = req                  # {(x,y): required pressure}
        self.src = next((x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == 'S')
        self.pipes = [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c in BASE]
        self.taps = [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == 'T']

    def ch(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.rows[y][x]
        return '#'

    def evaluate(self, masks):
        """masks: {(x,y): armmask}. Returns dict with wet set, leaks, tap pressures, win."""
        def accepts(x, y, d_from):  # does cell (x,y) accept an arm coming from direction d_from (its side)
            c = self.ch(x, y)
            if c in BASE: return bool(masks[(x, y)] >> d_from & 1)
            if c == 'T': return True
            if c == 'S': return d_from in self.outlets
            return False

        def nconn(x, y):
            m = masks[(x, y)]; n = 0
            for d in range(4):
                if m >> d & 1 and accepts(x + DX[d], y + DY[d], OPP(d)): n += 1
            return n

        # wet component (topology only)
        wet, stack, leaks = set(), [], 0
        sx, sy = self.src
        for d in self.outlets:
            nx, ny = sx + DX[d], sy + DY[d]
            if accepts(nx, ny, OPP(d)):
                if self.ch(nx, ny) in BASE and (nx, ny) not in wet:
                    wet.add((nx, ny)); stack.append((nx, ny))
            else:
                leaks += 1
        while stack:
            x, y = stack.pop()
            for d in range(4):
                if masks[(x, y)] >> d & 1:
                    nx, ny = x + DX[d], y + DY[d]
                    if accepts(nx, ny, OPP(d)):
                        if self.ch(nx, ny) in BASE and (nx, ny) not in wet:
                            wet.add((nx, ny)); stack.append((nx, ny))
                    else:
                        leaks += 1
        Heff = self.H - self.L * leaks
        # Dijkstra on max pressure, state = (cell, entry side)
        best = {}
        tapP = {t: None for t in self.taps}
        pq = []
        for d in self.outlets:
            nx, ny = sx + DX[d], sy + DY[d]
            c = self.ch(nx, ny)
            if c == 'T': tapP[(nx, ny)] = max(tapP[(nx, ny)] or -99, Heff)
            elif c in BASE and accepts(nx, ny, OPP(d)):
                heapq.heappush(pq, (-Heff, nx, ny, OPP(d)))
        while pq:
            np_, x, y, ent = heapq.heappop(pq); p = -np_
            if best.get((x, y, ent), -999) >= p: continue
            best[(x, y, ent)] = p
            m = masks[(x, y)]; junc = max(0, nconn(x, y) - 2)
            for e in range(4):
                if e == ent or not (m >> e & 1): continue
                nx, ny = x + DX[e], y + DY[e]
                if not accepts(nx, ny, OPP(e)): continue
                cost = 1 + (0 if e == OPP(ent) else 1) + junc
                q = p - cost
                c = self.ch(nx, ny)
                if c == 'T':
                    if tapP[(nx, ny)] is None or q > tapP[(nx, ny)]: tapP[(nx, ny)] = q
                elif c in BASE:
                    heapq.heappush(pq, (-q, nx, ny, OPP(e)))
        connected = all(v is not None for v in tapP.values())
        win = connected and all(tapP[t] >= self.req[t] for t in self.taps)
        return dict(wet=wet, leaks=leaks, Heff=Heff, taps=tapP, connected=connected, win=win)

    def all_configs(self):
        opts = [distinct_rots(self.ch(*p)) for p in self.pipes]
        for combo in itertools.product(*opts):
            yield dict(zip(self.pipes, combo))

    def analyse(self):
        """Count distinct wet-networks that connect all taps vs. that also meet pressure."""
        conn, wins = {}, {}
        for masks in self.all_configs():
            r = self.evaluate(masks)
            if not r['connected']: continue
            key = tuple(sorted((p, masks[p]) for p in r['wet']))
            conn[key] = r
            if r['win']: wins[key] = (masks, r)
        return conn, wins


ARM = {0b0101: '│', 0b1010: '─', 0b0011: '└', 0b0110: '┌', 0b1100: '┐', 0b1001: '┘',
       0b0111: '├', 0b1110: '┬', 0b1101: '┤', 0b1011: '┴', 0b1111: '┼'}


def draw(lv, masks, wet=None):
    out = []
    for y in range(lv.h):
        s = ''
        for x in range(lv.w):
            c = lv.ch(x, y)
            if c in BASE:
                g = ARM[masks[(x, y)]]
                s += g if (wet is None or (x, y) in wet) else '·'
            else:
                s += {'.': ' ', '#': '█'}.get(c, c)
        out.append(s)
    return '\n'.join(out)
