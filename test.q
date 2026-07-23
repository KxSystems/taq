testdir: first .z.x
TESTDATE: "D"$last .z.x

([parseToMemory; parseToDisk]): use `$"..taq"

fail: {-2 x;'`failed}

PWD: first system "pwd";

testInMemoryTables: {[(trade; quote; master; exnames)]
    if[not all count each (trade; quote; master; exnames);
    fail "empty table(s) found"];

    / Check if we can run some basic queries
    if[0=count asc select sum size by exch: exnames ex from trade;
        fail "simple select failed"];
    if[0=count aj[`sym`time; trade; select sym, time, bid, ask from quote];
        fail "aj failed"];
    }

testPersistedTables: {[dbdir]
    .Q.lo[`$dbdir; 0b; 0b];
    / Check if all kdb objects have data
    obj: `trade`quote`master`exnames;
    empty: obj where not count each value each obj;
    if[count empty;
        fail "empty table(s) found: ", "," sv string empty];

    / check attributes
    if[not all `p = {meta[x][`sym]`a} each (trade; quote);
        fail "missing `p attribute from `sym"];

    / Check if we can run some basic queries
    if[0=count asc select sum size by exch: exnames ex from trade;
        fail "simple select failed"];
    if[0=count aj[`sym`time; select from trade where date=min date; select sym, time, bid, ask from quote where date=min date];
        fail "aj failed"];
    }

///////////////////////////////////////////////////////////

res: .[parseToMemory;("test/data"; TESTDATE; 3; `dummyparameter); ::]
if[not res like "Too many parameters passed";
  fail "Too many parameters check failure"]

res: .[parseToMemory;("test/data"; TESTDATE; `notadictionary); ::]
if[not res like "Dictionary is expected as last parameter";
  fail "Dictionary type check failure"]

res: .[parseToMemory;("test/data"; TESTDATE; ([batchsize: 499])); ::]
if[not res like "non-zero batchsize cannot be smaller than 500 (bytes), got 499";
  fail "Batch size check failure"]

-1 "Testing with default parameters";
testInMemoryTables parseToMemory["test/data"; TESTDATE]

-1 "Testing with custom `letters` parameters";
testInMemoryTables parseToMemory["test/data"; TESTDATE; ([letters:"X-Y"])]

-1 "Testing without batching";
testInMemoryTables parseToMemory["test/data"; TESTDATE; ([batchsize: 0])]

-1 "Testing without custom batch size";
testInMemoryTables parseToMemory["test/data"; TESTDATE; ([batchsize: 500])]

-1 "Testing without sorted time";
(trade; quote; ; ): parseToMemory["test/data"; TESTDATE; ([sortcols: ()])]
if[`s = meta[trade][`time; `a];
    fail "trade time has sorted attribute"];
if[`s = meta[quote][`time; `a];
    fail "quote time has sorted attribute"];

-1 "Testing without sorted by sym";
(trade; quote; ; ): parseToMemory["test/data"; TESTDATE; ([sortcols: `sym; symattr: `p])]
if[not `p = meta[trade][`sym; `a];
    fail "trade sym has parted attribute"];
if[not `p = meta[quote][`sym; `a];
    fail "quote sym has parted attribute"];

-1 "Testing without grouped sym";
(trade; quote; ; ): parseToMemory["test/data"; TESTDATE; ([symattr: `])]
if[not ` = meta[trade][`sym; `a];
    fail "trade sym has an attribute"];
if[not ` = meta[quote][`sym; `a];
    fail "quote sym has an attribute"];

-1 "All in-memory tests passed";
///////////////////////////////////////////////////////////
res: .[parseToDisk;("test/data"; TESTDATE; testdir; 4; `dummyparameter); ::]
if[not res like "Too many parameters passed";
  fail "Too many parameters check failure"]

res: .[parseToDisk;("test/data"; TESTDATE; testdir; `notadictionary); ::]
if[not res like "Dictionary is expected as last parameter";
  fail "Dictionary type check failure"]

-1 "Testing with default parameters";
dbdir: testdir, "/test1"
parseToDisk["test/data"; TESTDATE; dbdir]
testPersistedTables dbdir
system "rm -rf ", dbdir

-1 "Testing with custom `letters` parameters";
dbdir: testdir, "/test2"
parseToDisk["test/data"; TESTDATE; dbdir; ([letters:"X-Y"])]
testPersistedTables dbdir
system "rm -rf ", dbdir

-1 "Testing without batching";
dbdir: testdir, "/test3"
parseToDisk["test/data"; TESTDATE; dbdir; ([batchsize: 0])]
testPersistedTables dbdir
system "rm -rf ", dbdir

-1 "Testing without custom batch size";
dbdir: testdir, "/test4"
parseToDisk["test/data"; TESTDATE; dbdir; ([batchsize: 500])]
testPersistedTables dbdir
system "rm -rf ", dbdir

-1 "Testing with custom `compparam` parameters";
dbdir: testdir, "/test5"
parseToDisk["test/data"; TESTDATE; dbdir; ([compparam: ([master: 0 0 0; trade: 17 2 6; quote: 17 2 6])])]
testPersistedTables dbdir
if[not 0 = count -21!hsym `$dbdir,"/", string[TESTDATE],"/master/sym";
    fail "master is not uncompressed"];
if[not (2 17 6i) ~ -3#value -21!hsym `$dbdir,"/", string[TESTDATE],"/trade/sym";
    fail "trade is not compressed with expected parameters"];
if[not (2 17 6i) ~ -3#value -21!hsym `$dbdir,"/", string[TESTDATE],"/quote/sym";
    fail "quote is not compressed with expected parameters"];
system "rm -rf ", dbdir

-1 "Testing with linked column";
dbdir: testdir, "/test6"
parseToDisk["test/data"; TESTDATE; dbdir; ([linked: 1b])]
testPersistedTables dbdir
$[`master in cols trade;
    if[not `master = meta[trade][`master]`f; fail "trade column master is not a linked column to table master"];
    fail "missing linked column master from trade"];
$[`master in cols quote;
    if[not `master = meta[quote][`master]`f; fail "quote column master is not a linked column to table master"];
    fail "missing linked column master from quote"];
if[0=count select master.description, price from trade;
    fail "using linked column in a select failed"];
if[0=count select master.description, ask, bid from quote;
    fail "using linked column in a select failed"];
system "rm -rf ", dbdir


///////////////////////////////////////////////////////////
-1 "All persistent DB tests passed";

if[not "-debug" in .z.x; exit 0]