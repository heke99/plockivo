/** Never log upstream error messages: gateways may include request details. */
export function workerErrorKind(error:{code?:string;message?:string},status?:number):'fatal'|'retryable' {
 if(status===401||status===403)return 'fatal';
 if(['42501','PGRST202','PGRST301'].includes(error.code??''))return 'fatal';
 if(['PERMISSION_DENIED','NOT_FOUND','INTEGRATION_NOT_READY'].includes(error.message??''))return 'fatal';
 return 'retryable';
}
