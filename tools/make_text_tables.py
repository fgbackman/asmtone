# Generates src/text_tables.inc: a static canonical Huffman code for English text
# (letters, space and punctuation short; any other byte, UTF-8 included, still codable),
# plus an end-of-text symbol. Used by src/text.s to shrink messages before they are played.
import heapq, itertools
f={}
low={' ':180,'e':95,'t':70,'a':63,'o':60,'i':57,'n':55,'s':51,'h':48,'r':46,'d':33,'l':31,'c':22,'u':22,'m':19,'w':18,'f':17,'g':16,'y':15,'p':14,'b':12,'v':8,'k':6,'j':1.2,'x':1.2,'q':0.8,'z':0.6}
for b in range(258): f[b]=0.02
for c,v in low.items(): f[ord(c)]=v
for c in 'abcdefghijklmnopqrstuvwxyz': f[ord(c.upper())]=max(0.3,low[c]/14)
for c,v in {'I':4,'T':2.5,'A':2,'S':1.6,'W':1.4,'H':1.4,'M':1.2,'C':1.2,'O':1}.items(): f[ord(c)]=v
for c,v in {'.':8,',':8,"'":3,'?':2,'!':2,'"':1,'-':1.5,':':0.6,';':0.3,'(':0.2,')':0.2,'\n':3,'/':0.3,'@':0.2,'&':0.2,'#':0.1,'*':0.1}.items(): f[ord(c)]=v
for d in '0123456789': f[ord(d)]=1.0
for b in range(128,256): f[b]=0.1
del f[257]; f[256]=10   # end of text
# huffman lengths
cnt=itertools.count()
h=[(w,next(cnt),[s]) for s,w in f.items()]
heapq.heapify(h); L={s:0 for s in f}
while len(h)>1:
    a=heapq.heappop(h); b=heapq.heappop(h)
    for s in a[2]+b[2]: L[s]+=1
    heapq.heappush(h,(a[0]+b[0],next(cnt),a[2]+b[2]))
mx=max(L.values()); print("max len",mx, "avg bits/char english ≈", sum(f[s]*L[s] for s in low and [ord(c) for c in low])/sum(low.values()))
# canonical codes
syms=sorted(f, key=lambda s:(L[s],s))
code=0; prev=0; codes={}
first=[0]*(mx+2); count=[0]*(mx+2); offs=[0]*(mx+2)
for i,s in enumerate(syms):
    l=L[s]
    if l!=prev:
        code<<= (l-prev); prev=l
        first[l]=code; offs[l]=i
    codes[s]=code; count[l]+=1; code+=1
import sys
import os; o=open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"..","src","text_tables.inc"),"w")
o.write("// text_tables.inc — the static Huffman code for English text (made by a script; do not edit)\n")
o.write(".set HUF_MAX, %d\n.set HUF_EOT, 256\n.p2align 2\n"%mx)
o.write("Lhuf_code:   // code for each byte 0-255 and end-of-text 256 (u32)\n")
for i in range(0,257,8): o.write("    .word "+", ".join(str(codes[s]) for s in range(i,min(257,i+8)))+"\n")
o.write("Lhuf_len:\n")
for i in range(0,257,16): o.write("    .byte "+", ".join(str(L[s]) for s in range(i,min(257,i+16)))+"\n")
o.write(".p2align 2\nLhuf_first:  // first code of each length (u32), 0..HUF_MAX\n    .word "+", ".join(str(first[l]) for l in range(mx+1))+"\n")
o.write("Lhuf_count:\n    .word "+", ".join(str(count[l]) for l in range(mx+1))+"\n")
o.write("Lhuf_offs:\n    .word "+", ".join(str(offs[l]) for l in range(mx+1))+"\n")
o.write(".p2align 1\nLhuf_syms:   // symbols in canonical order (u16)\n")
for i in range(0,len(syms),16): o.write("    .short "+", ".join(str(s) for s in syms[i:i+16])+"\n")
o.close()
# test english compression ratio
t="Hello Fred! Meet me at the corner in ten minutes, and bring the piano."
bits=sum(L[b] for b in t.encode())+L[256]
print("example", len(t), "bytes ->", (bits+7)//8+1, "bytes")
