import {systemPrompt, validatePlan, clinicianQuestions} from './validation.ts';

// Strict schema improves format reliability, not medical correctness.
const schema = {
 type:'object', additionalProperties:false, required:['meals'],
 properties:{
  meals:{type:'array',items:{type:'object',additionalProperties:false,required:['label','idea','ingredients'],properties:{label:{type:'string',enum:['Breakfast','Lunch','Dinner']},idea:{type:'string'},ingredients:{type:'array',items:{type:'string'}}}}}
 }
};
export function providerRequest(provider:string,model:string,preferences:{cuisine:string;preference:string}) {
 const strict=provider==='groq' && ['openai/gpt-oss-20b','openai/gpt-oss-120b'].includes(model);
 return {model,messages:[{role:'system',content:systemPrompt},{role:'user',content:JSON.stringify(preferences)}],
  temperature:0.2,max_completion_tokens:3000,
  ...(strict?{reasoning_effort:'low',response_format:{type:'json_schema',json_schema:{name:'meal_inspiration',strict:true,schema}}}:{response_format:{type:'json_object'}})
 };
}
export function parseProviderResult(value:unknown,preference:string) {
 const result=value as {choices?:{finish_reason?:string;message?:{content?:unknown;refusal?:unknown;tool_calls?:unknown[]}}[]};
 const choice=result?.choices?.[0];
 if(choice?.finish_reason!=='stop'||choice.message?.refusal||choice.message?.tool_calls?.length||typeof choice.message?.content!=='string'||choice.message.content.length>12000) throw new Error('Incomplete or refused draft');
 const draft=JSON.parse(choice.message.content);
 if(!draft||typeof draft!=='object'||Array.isArray(draft)||Object.keys(draft).some(k=>k!=='meals')) throw new Error('Unexpected provider fields');
 // Clinician questions are fixed app copy, never untrusted generated advice.
 return validatePlan({...draft,questions:clinicianQuestions},preference);
}
