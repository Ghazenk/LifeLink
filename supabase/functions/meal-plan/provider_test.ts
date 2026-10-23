import {providerRequest,parseProviderResult} from './provider.ts';
import {validatePlan,clinicianQuestions} from './validation.ts';
function assert(ok: unknown) {if(!ok) throw new Error('Assertion failed');}
function rejects(fn:()=>unknown) {try {fn();} catch (_) {return;} throw new Error('Expected rejection');}
const plan=()=>({meals:['Breakfast','Lunch','Dinner'].map(label=>({label,idea:'Rice with vegetables',ingredients:['Rice','Carrots']})),questions:['What portions work for me?','Which ingredients should I avoid?']});
const response=()=>({choices:[{finish_reason:'stop',message:{content:JSON.stringify({meals:plan().meals})}}]});
Deno.test('Groq GPT OSS uses strict output schema without tools or identity',()=>{
 const req=providerRequest('groq','openai/gpt-oss-120b',{cuisine:'Pakistani',preference:'Vegetarian'});
 assert(req.response_format.type==='json_schema');assert(!('tools' in req));assert(req.messages.length===2);
 assert(parseProviderResult(response(),'Vegetarian').meals.length===3);
 assert(JSON.stringify(parseProviderResult(response(),'Vegetarian').questions)===JSON.stringify(clinicianQuestions));
 rejects(()=>parseProviderResult({choices:[{finish_reason:'stop',message:{content:JSON.stringify(plan())}}]},'Vegetarian'));
});
Deno.test('Refused, truncated, tool and oversized completions fail closed',()=>{
 for(const finish_reason of ['length','content_filter','tool_calls','']) rejects(()=>parseProviderResult({choices:[{finish_reason,message:{content:JSON.stringify({meals:plan().meals})}}]},'Vegetarian'));
 rejects(()=>parseProviderResult({choices:[{finish_reason:'stop',message:{refusal:'no',content:JSON.stringify({meals:plan().meals})}}]},'Vegetarian'));
 rejects(()=>parseProviderResult({choices:[{finish_reason:'stop',message:{tool_calls:[{}],content:JSON.stringify({meals:plan().meals})}}]},'Vegetarian'));
 rejects(()=>parseProviderResult({choices:[{finish_reason:'stop',message:{content:'x'.repeat(12001)}}]},'Vegetarian'));
 rejects(()=>parseProviderResult(null,'Vegetarian'));
});
Deno.test('Clinical claims, unicode obfuscation and unexpected fields are rejected',()=>{
 for(const text of ['Iron supplements','Take 20 mg daily','Cures thalassemia','Adjust transfusions','Medically safe meal','Allergy-safe meal','Fortified powder','Weight loss meal','Ｉｒｏｎ pills','www.example.com','ri\u200bon']) {
  const draft=plan();draft.meals[0].idea=text;rejects(()=>validatePlan(draft));
 }
 rejects(()=>validatePlan({...plan(),prescription:'extra'}));
 const draft=plan();Object.assign(draft.meals[0],{advice:'extra'});rejects(()=>validatePlan(draft));
});
Deno.test('Vegetarian choice is checked and ordinary ingredients still pass',()=>{
 const draft=plan();draft.meals[1].ingredients=['Chicken','Rice'];rejects(()=>validatePlan(draft,'Vegetarian'));
 draft.meals[1].ingredients=['Chickpeas','Rice'];assert(validatePlan(draft,'Vegetarian').meals.length===3);
});
