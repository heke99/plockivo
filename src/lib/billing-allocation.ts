/** Exact cumulative allocation of frozen minor-unit row totals; no postings. */
export function allocateRowMinor(total:string,fulfilledMicros:string,orderedMicros:string):string{
 if(!/^\d+$/.test(total)||!/^\d+$/.test(fulfilledMicros)||!/^\d+$/.test(orderedMicros))throw Error('Invalid allocation');
 const amount=BigInt(total),fulfilled=BigInt(fulfilledMicros),ordered=BigInt(orderedMicros);
 if(ordered<=0n||fulfilled>ordered)throw Error('Invalid allocation');
 return ((amount*fulfilled*2n+ordered)/(ordered*2n)).toString();
}
