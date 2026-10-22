"""Measure generated atlas sprite bounds without changing any source image pixels.
Requires Pillow and NumPy. Writes runtime AtlasTexture region metadata only.
"""
from pathlib import Path
from PIL import Image, ImageFilter
import numpy as np
import json
root = Path(__file__).resolve().parents[1]
regions = {}
for family in ['swords','axes','spears','bows']:
    pixels = np.array(Image.open(root/'assets/art'/f'{family}.png').convert('RGB'))
    mask = (np.max(pixels, axis=2)>55).astype('uint8')*255
    mask = np.array(Image.fromarray(mask).filter(ImageFilter.MaxFilter(5)))>0
    height,width=mask.shape
    boxes=[]
    for y,x in zip(*np.nonzero(mask)):
        if not mask[y,x]:continue
        todo=[(x,y)];mask[y,x]=False
        left=right=x;top=bottom=y;count=0
        while todo:
            a,b=todo.pop();count+=1
            left=min(left,a);right=max(right,a);top=min(top,b);bottom=max(bottom,b)
            for c,d in ((a+1,b),(a-1,b),(a,b+1),(a,b-1)):
                if 0<=c<width and 0<=d<height and mask[d,c]:
                    mask[d,c]=False;todo.append((c,d))
        if count>150:boxes.append([int(left),int(top),int(right+1),int(bottom+1),count])
    print(family,len(boxes),flush=True)
    columns = 12 if family == "bows" else 10
    if len(boxes)!=columns*5:
        print('Requires visual review:',boxes,flush=True)
        continue
    boxes.sort(key=lambda b:(b[1]+b[3])/2)
    ordered=[]
    for row in range(5):ordered.extend(sorted(boxes[row*columns:(row+1)*columns],key=lambda b:b[0])[:10])
    regions[family]=[[max(0,b[0]-2),max(0,b[1]-2),min(width,b[2]+2)-max(0,b[0]-2),min(height,b[3]+2)-max(0,b[1]-2)] for b in ordered]
(root/'data/weapon-regions.json').write_text(json.dumps(regions,indent=2)+'\n')
