os: use`os;

t: use `kx.test;
t.setDefaults ([verbose:0b])

TESTDATE: "D"$first .z.x

([streamToPubSub; parseToMemory]): use `...taq;

.t.eol:` sv enlist"";

/ replay requires PSV files sorted by time (generated from test/data/bysym with ./scripts/sort.sh)
psvdir: "test/data/bytime";

tp: os.proc.start["q ./test/mocktp.q -p localhost:0W "; / use a free port
    ([async:1b; stdin:`pipe; stdout:`text; stderr:`text; env: os.env[], ([KX_TTY: enlist "1"])])];
.z.exit: {[x] tp[`stdin] "exit 0", .t.eol}
read0 tp`stdout;    / discard startup messages

tp[`stdin] "\\p", .t.eol;     / fetch the port obtained
freeport: -1_last read0 tp`stdout;

-1 "mock TP started on port ", freeport;

tpH: hopen "J"$freeport

/ a short time window keeps the real-time replay short
window: ([starttime: 0D15:59:59; endtime: 0D16:00:06]);
batchsize: 500;     / bytes, i.e. a few rows per batch
(trade; quote; master; ): parseToMemory[psvdir; TESTDATE];
expected: ([trade: select from trade where time within window`starttime`endtime;
  quote: select from quote where time within window`starttime`endtime;
  master: master]);

/ time differences between rows and between time columns are preserved by the replay
timeDeltas: {1_deltas exec time from x}
tsDiffs: {asc exec participantTimestamp - time from x}

///////////////////////////////////////////////////////////
t.feature `streamToPubSubParams;
t.mock[`f; streamToPubSub];
t.mock[`TESTDATE; TESTDATE];
t.assertError[{f["test/data/bytime"; TESTDATE]};
  "Too few parameters passed to streamToPubSub. At least source directory, date and connection handle must be provided";
  ([name: "too few parameters"])];
t.assertError[{f["test/data/bytime"; TESTDATE; 0i; ([foo: 1])]}; "Unknown parameter(s): foo"; ([name: "unknown parameter"])];

///////////////////////////////////////////////////////////
-1 "starting realtime streaming to TP";
start: .z.p;
streamToPubSub[psvdir; TESTDATE; tpH; window, ([batchsize])];
duration: .z.p - start;
-1 "realtime streaming to TP finished in ", string duration;

t.feature `streamToPubSubTP;
received: tpH "`master`trade`quote!(master; delete rcvt, batchidx from trade; delete rcvt, batchidx from quote)";
t.mock[`counts; value count each received];
t.assertTrue[{all 0 < counts}; ([name: "tables have data"])];
t.assertMatch[{counts}; count each expected `master`trade`quote; ([name: "row counts match the time window"])];

t.mock[`deltasOk; all timeDeltas'[received `trade`quote] ~' timeDeltas each expected `trade`quote];
t.assertTrue[{deltasOk}; ([name: "time differences preserved"])];

t.mock[`tsDiffsOk; all tsDiffs'[received `trade`quote] ~' tsDiffs each expected `trade`quote];
t.assertTrue[{tsDiffsOk}; ([name: "participantTimestamp shifted with time"])];

t.mock[`multiBatch; all 1 < tpH "{count distinct exec batchidx from x} each `trade`quote"];
t.assertTrue[{multiBatch}; ([name: "data sent in multiple batches"])];

t.mock[`realtimeOk; all (0D00:00:00.1 > max@) each tpH "{exec last rcvt-time by batchidx from x} each `trade`quote"];
t.assertTrue[{realtimeOk}; ([name: "realtime: delay below threshold"])];

/ quotes are replayed after trades, each starting its own clock when its first batch is sent
span: sum tpH "{(last x`time) - last exec time from x where batchidx=0} each `trade`quote";
t.mock[`durationOk; duration within span + -0D00:00:00.1 0D00:00:01];
t.assertTrue[{durationOk}; ([name: "replay follows the original timing"])];

///////////////////////////////////////////////////////////
t.feature `streamToPubSubRT;
rtMsgs: ();
rtPub: {[msg] rtMsgs,:: enlist msg};    / mock of an RT publisher, e.g. returned by .rt.pub
streamToPubSub[psvdir; TESTDATE; rtPub; window, ([batchsize; tbls: `master`trade; updFn: `.rt.upd])];

/ mocked values are evaluated, so symbols are compared before mocking
t.mock[`updFnOk; all `.rt.upd = rtMsgs[;0]];
t.assertTrue[{updFnOk}; ([name: "custom update function"])];
t.mock[`tablesOk; `master`trade ~ distinct rtMsgs[;1]];
t.assertTrue[{tablesOk}; ([name: "only selected tables published"])];
t.mock[`tradeCount; sum count each rtMsgs[where `trade = rtMsgs[;1]; 2]];
t.assertMatch[{tradeCount}; count expected`trade; ([name: "trade row count matches the time window"])];

///////////////////////////////////////////////////////////
t.teardown[];
r: t.getReport[];
if[count f: select feature, name, status, actual: details@\:`actual from r where status<>`pass;
  -2 "Failed tests:"; -2 .Q.s f; exit 1];

-1 "All ", string[count r], " streamToPubSub tests passed";

if[not any "-debug" ~/: 1_.z.x; exit 0]
