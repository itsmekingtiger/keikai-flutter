import sys, subprocess, os
from PIL import Image, ImageChops
import numpy as np
repo='/home/user/keikai-flutter'; before=sys.argv[1]
files=subprocess.run(['git','-C',repo,'status','--short'],capture_output=True,text=True).stdout.split('\n')
files=[l[3:] for l in files if l.strip().endswith('.png')]
only=sys.argv[2:] 
for f in files:
    if only and not any(o in f for o in only): continue
    a=Image.open(os.path.join(before,f)).convert('RGB'); b=Image.open(os.path.join(repo,f)).convert('RGB')
    if a.size!=b.size:
        print(f,'SIZE',a.size,'->',b.size); continue
    d=np.asarray(ImageChops.difference(a,b)).sum(axis=2)>0
    rows=d.sum(axis=1); total=int(d.sum())
    bands=[]; start=None; last=None
    for y,c in enumerate(rows):
        if c>0:
            if start is None: start=y
            elif y-last>60:
                bands.append((start,last)); start=y
            last=y
    if start is not None: bands.append((start,last))
    info=[]
    for (y0,y1) in bands:
        sub=d[y0:y1+1]; cols=np.where(sub.any(axis=0))[0]
        info.append((int(sub.sum()),y0,y1,int(cols.min()),int(cols.max())))
    info.sort(reverse=True)
    print(f, a.size, 'px',total,'bands',len(bands),'top:',' '.join(f'[{n}px y{y0}-{y1} x{x0}-{x1}]' for n,y0,y1,x0,x1 in info[:5]))
