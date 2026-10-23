export const clinicianQuestions=['Which portions and ingredients fit my individual care plan?','Do any of these ingredients conflict with my allergies or clinician instructions?'];
import {HttpError} from '../_shared/http.ts';
export const doctorNotice='Please confirm this draft with your doctor or registered dietitian before following it. AI can be wrong. This is general meal inspiration, not a medical diet or treatment plan.';
export const systemPrompt=`You create general adult meal inspiration for review with a clinician, never clinical nutrition advice. Return ONLY JSON with a meals array of exactly three objects: {label: Breakfast|Lunch|Dinner, idea: string, ingredients: string[]} only. Do not include questions or extra fields. Use the requested cuisine and dietary preference. This app may be used by people with thalassemia: never assume anemia means iron deficiency. Do not recommend iron, supplements, pills, dosages, calorie targets, weight loss, fasting, treatment, fluid limits, transfusion changes, or chelation changes. Do not claim the meals are medically safe, suitable for a disease, or allergy-safe. No clinical, nutritional, or disease claims. No links or instructions to contact third parties. Keep each meal idea below 250 characters, 2-8 ingredients,. Do not generate a plan for children or a therapeutic diet. Avoid supplement powders and fortified products.`;
export function validateInput(body: Record<string, unknown>) {
 if(body.consent!==true||body.adult_and_clinician_confirmed!==true) throw new HttpError(400,'Confirm consent and clinician suitability first.');
 if(!['Pakistani','Mediterranean','Mixed'].includes(body.cuisine as string)||!['Vegetarian','No preference'].includes(body.preference as string)) throw new HttpError(400,'Choose one of the supported preferences.');
 if(Object.keys(body).some(k=>!['consent','adult_and_clinician_confirmed','cuisine','preference'].includes(k))) throw new HttpError(400,'Do not include personal or medical information.');
 return {cuisine:body.cuisine as string,preference:body.preference as string};
}
export function validatePlan(value: unknown, preference?: string) {
 if(!value||typeof value!=='object'||Array.isArray(value)) throw new Error('Invalid plan');
 const p=value as Record<string, unknown>;
 if(Object.keys(p).some(k=>!['meals','questions'].includes(k))) throw new Error('Unexpected fields');
 if(!Array.isArray(p.meals)||p.meals.length!==3||!Array.isArray(p.questions)||p.questions.length!==2) throw new Error('Invalid structure');
 const prohibited=/\b(supplements?|chelat(?:ion|or|ors)|dosages?|dos(?:e|es)|cur(?:e|es)|treat(?:ment|ments|s)?|iron|fasting|calories?|kcal|mg|mcg|medications?|medicines?|pills?|tablets?|capsules?|transfusions?|fortified)\b|\b(?:medically safe|allergy[- ]safe|safe for thalassemia|boost.{0,20}h(?:a?e)moglobin|fluid restriction|weight loss)\b|https?:|www\.|<[^>]*>|[\u0000-\u001F\u007F\u200B-\u200F\u202A-\u202E\u2066-\u2069]/i;
 const text=(v:unknown,max:number)=> {if(typeof v!=='string'||v.trim().length<2||v.length>max||prohibited.test(v.normalize('NFKC')))throw new Error('Invalid content');return v.trim();};
 const meals=p.meals.map((raw,index)=>{
  if(!raw||typeof raw!=='object'||Array.isArray(raw)||Object.keys(raw).some(k=>!['label','idea','ingredients'].includes(k)))throw new Error('Invalid meal');
  if(raw.label!==['Breakfast','Lunch','Dinner'][index]||!Array.isArray(raw.ingredients)||raw.ingredients.length<2||raw.ingredients.length>8)throw new Error('Invalid meal');
  return {label:raw.label,idea:text(raw.idea,250),ingredients:raw.ingredients.map((x:unknown)=>text(x,80))};
 });
 if(preference==='Vegetarian' && meals.some(m=>/\b(chicken|beef|mutton|lamb|fish|prawn|shrimp|meat|gelatin|pork|bacon|tuna|salmon)\b/i.test(m.idea+' '+m.ingredients.join(' ')))) throw new Error('Preference mismatch');
 return {meals,questions:p.questions.map((x:unknown)=>text(x,180))};
}
