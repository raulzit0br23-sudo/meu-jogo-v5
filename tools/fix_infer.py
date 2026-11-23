import re,subprocess
for it in range(15):
    out=subprocess.run("tools/check_all.sh",shell=True,capture_output=True,text=True).stdout
    lines=out.splitlines(); fixes=set()
    for i,l in enumerate(lines):
        if ("Cannot infer the type" in l or "inferred from a Variant" in l) and i+1<len(lines):
            m=re.search(r"res://(\S+\.gd):(\d+)",lines[i+1])
            if m: fixes.add((m.group(1),int(m.group(2))))
    if not fixes:
        print("\n".join(l for l in lines if "Identifier not found: " not in l)); break
    for f,n in fixes:
        src=open(f).read().split("\n"); src[n-1]=src[n-1].replace(":=","=",1); open(f,"w").write("\n".join(src))
    print("fixed",sorted(fixes))
