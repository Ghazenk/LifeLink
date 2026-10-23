import {requireAgeEligibility} from './age.ts';
import {HttpError} from './http.ts';
Deno.test('age gate accepts only a literal true declaration', () => {
  requireAgeEligibility({age_13_or_older:true});
  for (const value of [undefined,null,false,0,1,'true','false',{},[]]) {
    let rejected=false;
    try { requireAgeEligibility({age_13_or_older:value}); }
    catch(e) { rejected=e instanceof HttpError && e.status===400; }
    if(!rejected) throw new Error('Age gate accepted an invalid declaration');
  }
});
