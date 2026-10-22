import { withWorkflow } from 'workflow/next';
export default withWorkflow({poweredByHeader:false, async headers(){return [{source:'/(.*)',headers:[{key:'X-Content-Type-Options',value:'nosniff'},{key:'Referrer-Policy',value:'no-referrer'},{key:'X-Frame-Options',value:'DENY'}]}]}});
