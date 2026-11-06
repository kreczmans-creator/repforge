import json,sys,collections
ROOT='/home/user/repforge/'
lib={e['id']:e for e in json.load(open(ROOT+'app/assets/seed/exercise_library.json'))['exercises']}
doc=json.load(open(ROOT+'docs/workout-catalogue/workout-templates-draft.json'))
CATS="chestTriceps backBiceps legs upperBody lowerBody push pull fullBody arms shouldersCore".split()
errs=[]
def e(m): errs.append(m)
T=doc['templates']
if doc.get('formatVersion')!=1: e('formatVersion')
if len(lib)!=89: e('library size')
if len(T)!=30: e(f'{len(T)} templates')
c=collections.Counter(t['category'] for t in T)
for k in CATS:
    if c[k]!=3: e(f'{k}: {c[k]}')
if set(c)-set(CATS): e('unknown category')
ids=[t['id'] for t in T]
if len(set(ids))!=len(ids): e('dup template ids')
names=[t['name'] for t in T]
if len(set(names))!=len(names): e('dup names')
def isint(v): return isinstance(v,int) and not isinstance(v,bool)
for t in T:
    p=t['id']
    if t['difficulty'] not in('beginner','intermediate','advanced'): e(p+' difficulty')
    if t['emphasis'] not in('strength','hypertrophy','endurance'): e(p+' emphasis')
    if not isint(t['estimatedMinutes']) or not 15<=t['estimatedMinutes']<=90: e(p+' minutes')
    ex=t['exercises']
    if not 4<=len(ex)<=8: e(p+' exercise count')
    if [x['order'] for x in ex]!=list(range(1,len(ex)+1)): e(p+' order')
    seen=set();eq=set();mu=[]
    for x in ex:
        i=x['exerciseId'];q=f'{p}#{x["order"]}'
        if i not in lib: e(q+' unknown '+i);continue
        if i in seen: e(q+' duplicate exercise')
        seen.add(i);L=lib[i];ty=L['type'];eq.update(L['equipment'])
        if L['primaryMuscle'] not in mu: mu.append(L['primaryMuscle'])
        if not(isint(x['targetSets']) and 1<=x['targetSets']<=20): e(q+' sets')
        if not(isint(x['restSeconds']) and 0<=x['restSeconds']<=3600): e(q+' rest')
        has={k:k in x for k in('repsMin','repsMax','targetDurationSec','targetMetres')}
        if has['repsMin']!=has['repsMax']: e(q+' reps pair')
        if ty in('weighted','bodyweight','assisted'):
            if not(has['repsMin'] and not has['targetDurationSec'] and not has['targetMetres']): e(q+' needs reps only')
        elif ty in('timed','cardio'):
            if not(has['targetDurationSec'] and not has['repsMin'] and not has['targetMetres']): e(q+' needs duration only')
        elif ty=='distance':
            if not(has['targetMetres'] and not has['repsMin'] and not has['targetDurationSec']): e(q+' needs metres only')
        if has['repsMin']:
            a,b=x['repsMin'],x['repsMax']
            if not(isint(a) and isint(b) and 1<=a<=b<=100): e(q+' reps range')
        if has['targetDurationSec'] and not(x['targetDurationSec']>0): e(q+' dur')
        if has['targetMetres'] and not(x['targetMetres']>0): e(q+' metres')
        ev=x.get('exertion','MISSING')
        if ev=='MISSING': e(q+' exertion key missing')
        elif ev is not None:
            v=ev['value']
            if ev['scale']=='rpe':
                if not(1<=v<=10 and (v*2)==int(v*2)): e(q+' rpe')
            elif ev['scale']=='rir':
                if not(isint(v) and 0<=v<=5): e(q+' rir')
            else: e(q+' scale')
        if 'load' in json.dumps(x).lower() or 'targetLoad' in x: e(q+' load')
        if 'instructions' not in x: e(q+' instructions key')
    if sorted(eq)!=t['equipment']: e(f'{p} equipment {t["equipment"]} vs {sorted(eq)}')
    if mu!=t['targetMuscles'] or len(set(mu))!=len(mu): e(p+' targetMuscles')
print('templates',len(T),dict(c))
if errs:
    print('FAIL');[print(' ',m) for m in errs];sys.exit(1)
print('OK: all checks passed')
