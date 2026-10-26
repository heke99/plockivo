# FULFILLMENT-019/020 — testkontroll och beständigt testanspråk

Endast syntetiska testorder. SQL kräver aktivt explicit personal-/handlaradministratörsmandat, aal2 och aktuell MFA, rätt handlare/butik/konto samt testläge i både order och handlare. Inköpspermission ger inte utlämningspermission. TEST_FULFILLMENT_ENABLED är false som standard i API; fysisk utlämning är inte öppnad.

Kontrollresultat, rader, mängder och mottagarreferens binds till orderns revision. Anspråk kräver exakt samma normaliserade rader och referens som godkänd kontroll. Orderraden får beständig claimed-mängd före bekräftelse. Bekräftelse flyttar claimed till fulfilled. Pending claims har ingen automatisk timeout eller release; avbrott innebär fortsatt spärrad mängd. Ingen automatisk återställning av ett oklart fysiskt utfall finns.

Alla kritiska operationer låser ordern först och använder version samt beständig kommandonyckel. CHECK håller claimed+fulfilled+cancelled<=accepted och returned<=fulfilled. Annullerings- och returmoduler använder samma orderlås. Ingen operation frigör kredit/budget eller ändrar lager. Kod-/identitetskontroll och fysisk pilotpolicy är inte verifierade.

Migration serverversion 20261026004427_test_fulfillment_core.sql tillämpad. tests/fulfillment.sql terminal PASS med riktig authenticated-roll och rollback: okontrollerat anspråk nekas, mottagaravvikelse nekas, exakt kontroll→anspråk→bekräftelse, replay, revisionskonflikt, en claim/audit, korshandlare och produktionsläge nekas. Transporttester nekar extra actor, dubbla rader, noll och för fin decimalprecision. Separata samtidiga DB-sessioner har INTE körts; sekventiell revisionstestning och constraints är inte samtidighetsbevis.

Kontrakt GET /v1/fulfillment/{id}; POST inspect, claim och claims/{claim_id}/confirm. Separata cancel/returns endpoints. INTEGRATION_NOT_READY503 om gate är av. Cancellation gate TEST_CANCELLATION_ENABLED är oberoende och false tills särskilt godkänd schemaändring tillämpats. Pending cancellation har flyttats efter tillämpad core i migrationsordningen.
