import json, random, sys
from pressure_ref import *
from wetsearch_ref import analyse_fast

def rot_of(ch, m):
    for r in range(4):
        if rot(BASE[ch], r) == m: return r
    raise ValueError

def level_dict(lv, rows, masks, solution=None):
    def rotrows(ms):
        out=[]
        for y,row in enumerate(rows):
            s=''
            for x,ch in enumerate(row):
                s+= str(rot_of(ch, ms[(x,y)])) if ch in BASE else '0'
            out.append(s)
        return out
    d={"version":1,"w":lv.w,"h":lv.h,"rows":rows,"rots":rotrows(masks),
       "outlets":lv.outlets,"taps":[{"x":x,"y":y,"req":lv.req[(x,y)]} for (x,y) in lv.taps],
       "H":lv.H,"L":lv.L,"meta":{}}
    if solution: d["solution"]=rotrows(solution)
    return d

def expect(lv, masks):
    r=lv.evaluate(masks)
    return {"leaks":r['leaks'],"heff":r['Heff'],"wet":len(r['wet']),
            "taps":[r['taps'][t] for t in lv.taps],"connected":r['connected'],"win":r['win']}

EX=[("ex1",["SYIYT","#LIL#"],8,{(4,0):3}, lambda r: r['taps'][(4,0)]==1),
    ("ex2",["IYI.I","SLLYT",".LYYY","IITLI"],13,{(4,1):2,(2,3):2}, lambda r: (r['taps'][(4,1)],r['taps'][(2,3)])==(1,4)),
    ("ex3",["L.IIT","SYYIY","ILLLL","LYLTL"],13,{(4,0):4,(3,3):2}, lambda r: r['leaks']==0 and (r['taps'][(4,0)],r['taps'][(3,3)])==(5,1))]
examples=[]
for name,rows,H,req,trapf in EX:
    lv=Level(rows,H,[1],req,L=2); conn=analyse_fast(lv)
    wins=[(m,r) for m,r in conn.values() if r['win']]
    traps=[(m,r) for m,r in conn.values() if trapf(r)]
    sol=wins[0][0]; trap=traps[0][0]
    zero={p:BASE[lv.ch(*p)] for p in lv.pipes}
    examples.append({"name":name,"level":level_dict(lv,rows,zero,sol),
        "connecting":len(conn),"winning":len(wins),
        "solution_expect":expect(lv,sol),
        "trap":{"rots":level_dict(lv,rows,trap)["rots"],"expect":expect(lv,trap)}})
json.dump(examples, open(sys.argv[1]+"/examples.json","w"), ensure_ascii=False, indent=1)

rng=random.Random(20261125); cases=[]
while len(cases)<300:
    w=rng.randint(2,7); h=rng.randint(2,7)
    if w*h<4: continue
    cells=[[rng.choice("IIILLLLYYX..#") for _ in range(w)] for _ in range(h)]
    pos=[(x,y) for y in range(h) for x in range(w)]; rng.shuffle(pos)
    sx,sy=pos[0]; cells[sy][sx]='S'
    nt=rng.randint(1,min(3,len(pos)-1))
    for (x,y) in pos[1:1+nt]: cells[y][x]='T'
    rows=[''.join(r) for r in cells]
    outs=sorted(rng.sample(range(4), rng.choice([1,1,1,2])))
    taps=[(x,y) for y in range(h) for x in range(w) if rows[y][x]=='T']
    lv=Level(rows,rng.randint(4,20),outs,{t:rng.randint(0,6) for t in taps},L=rng.choice([1,2,3]))
    masks={p:rot(BASE[lv.ch(*p)], rng.randint(0,3)) for p in lv.pipes}
    cases.append({"level":level_dict(lv,rows,masks),"expect":expect(lv,masks)})
json.dump(cases, open(sys.argv[1]+"/eval_golden.json","w"), ensure_ascii=False)
print("examples", [(e["name"],e["connecting"],e["winning"]) for e in examples])
print("cases", len(cases), "wins", sum(c["expect"]["win"] for c in cases), "connected", sum(c["expect"]["connected"] for c in cases))
