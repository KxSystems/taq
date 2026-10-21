batchIdx: ()!()

.u.upd: {
    x insert update rcvt:.z.n, batchidx: 0^batchIdx[x] from y;
    batchIdx[x]+: 1;
 }

-1 "mock TP started";
