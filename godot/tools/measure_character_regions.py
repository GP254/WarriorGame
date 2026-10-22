"""Measure alpha gutters and foot-aligned atlas regions. Does not edit source images."""
from pathlib import Path
from PIL import Image
import numpy as np
import json
root=Path(__file__).resolve().parents[1]
result={}
def cuts(projection,count):
    length=len(projection)
    positions=[0]
    for index in range(1,count):
        expected=length*index/count
        lo=max(positions[-1]+1,round(expected-length/count*.23))
        hi=min(length,round(expected+length/count*.23))
        values=projection[lo:hi]
        # Minimise foreground at seam, break ties in favour of nominal grid.
        best=min(range(lo,hi),key=lambda x:(int(projection[x]),abs(x-expected)))
        positions.append(best)
    return positions+[length]
for p in sorted((root/'assets/art').glob('*walk8.png')):
    mask=np.asarray(Image.open(p).getchannel('A'))>80
    ys=cuts(mask.sum(axis=1),8)
    boxes=[]
    for row in range(8):
        band=mask[ys[row]:ys[row+1]]
        xs=cuts(band.sum(axis=0),4)
        row_boxes=[]
        for col in range(4):
            y,x=np.nonzero(band[:,xs[col]:xs[col+1]])
            assert len(x)>100,p
            box=[int(x.min()+xs[col]),int(y.min()+ys[row]),int(x.max()-x.min()+1),int(y.max()-y.min()+1)]
            row_boxes.append(box)
        boxes.append(row_boxes)
    canvas=max(max(b[2],b[3]) for row in boxes for b in row)+4
    result[p.stem]={'canvas':canvas,'rows':boxes}
# Work atlas has large outer gutters; use occupied bounds before finding column seams.
p=root/'assets/art/villager-work.png'
mask=np.asarray(Image.open(p).getchannel('A'))>80
ys=cuts(mask.sum(axis=1),8)
boxes=[]
for row in range(8):
    band=mask[ys[row]:ys[row+1]]
    y,x=np.nonzero(band)
    left,right=int(x.min()),int(x.max()+1)
    xs=[v+left for v in cuts(band[:,left:right].sum(axis=0),4)]
    row_boxes=[]
    for col in range(4):
        y,x=np.nonzero(band[:,xs[col]:xs[col+1]])
        row_boxes.append([int(x.min()+xs[col]),int(y.min()+ys[row]),int(x.max()-x.min()+1),int(y.max()-y.min()+1)])
    boxes.append(row_boxes)
result['villager-work']={'canvas':max(max(b[2],b[3]) for row in boxes for b in row)+4,'rows':boxes}
(root/'data/character-regions.json').write_text(json.dumps(result,indent=2)+'\n')
for name,item in result.items(): print(name,item['canvas'],len(item['rows'])*4)
