import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
// Use psql's script mode: CLI db query prepares one statement and rejects transaction scripts.
const project=readFileSync('supabase/config.toml','utf8').match(/^project_id\s*=\s*"([a-zA-Z0-9_-]+)"/m)?.[1];
if(!project)throw Error('Missing local Supabase project ID');
for(const file of ['tests/database.sql','tests/carts.sql','tests/mfa.sql','tests/invitations.sql','tests/profile.sql','tests/domains.sql','tests/branding.sql']){
 const result=spawnSync('docker',['exec','-i','supabase_db_'+project,'psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:readFileSync(file),stdio:['pipe','inherit','inherit']});
 if(result.error)throw result.error;
 if(result.status!==0)process.exit(result.status??1);
}

