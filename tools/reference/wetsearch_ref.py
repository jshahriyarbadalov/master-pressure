"""Enumerate distinct wet networks (rotations of wet cells only) for a Level."""
from pressure_ref import *


def wet_networks(lv, limit=200000):
    """Yield masks dicts (wet cells assigned; dry cells given any consistent rotation)."""
    pipes = set(lv.pipes)
    rots = {p: distinct_rots(lv.ch(*p)) for p in pipes}
    sx, sy = lv.src
    out = []

    # constraint: req[p] arms that must exist, forb[p] arms that must not exist
    def ok(p, m, req, forb):
        return (m & req.get(p, 0)) == req.get(p, 0) and (m & forb.get(p, 0)) == 0

    def rec(assigned, queue, req, forb):
        if len(out) >= limit: return
        if not queue:
            # finalize dry cells
            masks = dict(assigned)
            for p in pipes:
                if p in masks: continue
                c = [m for m in rots[p] if ok(p, m, req, forb)]
                if not c: return
                masks[p] = c[0]
            out.append(masks)
            return
        p = queue[0]; rest = queue[1:]
        for m in rots[p]:
            if not ok(p, m, req, forb): continue
            # arms to unassigned pipe neighbours -> branch connect / not
            arms = []
            bad = False
            for d in range(4):
                if not (m >> d & 1): continue
                q = (p[0] + DX[d], p[1] + DY[d])
                if q in pipes and q not in assigned and q != p:
                    if q in rest:
                        # already wet & queued: it must have the arm back (else it'd be a leak but it's wet anyway)
                        arms.append((q, OPP(d), 'either'))
                    else:
                        arms.append((q, OPP(d), 'branch'))
            # also: assigned neighbours pointing to p must be consistent: handled because their decision put req/forb on p
            assigned2 = dict(assigned); assigned2[p] = m
            # for unassigned neighbours NOT pointed to by p: if they're wet later, fine; they must not... no constraint
            # but p not pointing to neighbour q while q (unassigned, later wet) points to p -> q leaks into p: allowed.
            def expand(i, queue2, req2, forb2):
                if i == len(arms):
                    rec(assigned2, queue2, req2, forb2); return
                q, back, kind = arms[i]
                if kind == 'either':
                    expand(i + 1, queue2, req2, forb2); return
                # connect
                r2 = dict(req2); r2[q] = r2.get(q, 0) | (1 << back)
                if any(ok(q, mm, r2, forb2) for mm in rots[q]):
                    expand(i + 1, queue2 + [q] if q not in queue2 else queue2, r2, forb2)
                # leak (q stays dry unless wet via another route; if it becomes wet it must lack the arm)
                f2 = dict(forb2); f2[q] = f2.get(q, 0) | (1 << back)
                if any(ok(q, mm, req2, f2) for mm in rots[q]):
                    expand(i + 1, queue2, req2, f2)
            expand(0, rest, req, forb)

    start_q, req0 = [], {}
    for d in lv.outlets:
        q = (sx + DX[d], sy + DY[d])
        if q in pipes:
            # source outlet into pipe: connect or leak
            pass
    # handle outlet branching
    def start(i, q0, r0, f0):
        if i == len(lv.outlets):
            rec({}, q0, r0, f0); return
        d = lv.outlets[i]; q = (sx + DX[d], sy + DY[d])
        if q in pipes:
            r2 = dict(r0); r2[q] = r2.get(q, 0) | (1 << OPP(d))
            start(i + 1, q0 + [q], r2, f0)
            f2 = dict(f0); f2[q] = f2.get(q, 0) | (1 << OPP(d))
            start(i + 1, q0, r0, f2)
        else:
            start(i + 1, q0, r0, f0)
    start(0, [], {}, {})
    return out


def analyse_fast(lv):
    conn, wins = {}, {}
    for masks in wet_networks(lv):
        r = lv.evaluate(masks)
        if not r['connected']: continue
        key = tuple(sorted((p, masks[p]) for p in r['wet']))
        conn[key] = (masks, r)
    return conn
