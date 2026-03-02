testdir: first .z.x

([parseToDisk]): use `$"..taq"

fail: {-2 x;'`failed}

PWD: first system "pwd";

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

res: .[parseToDisk;("testdata"; 2025.07.01; testdir; 4; `dummyparameter); ::]
if[not res like "Too many parameters passed to parseToDisk";
  fail "Too many parameters check failure"]

res: .[parseToDisk;("testdata"; 2025.07.01; testdir; `notadictionary); ::]
if[not res like "Dictionary is expected as fourth parameter";
  fail "Dictionary type check failure"]

dbdir: testdir, "/test1"
parseToDisk["testdata"; 2025.07.01; dbdir]
testPersistedTables dbdir
system "rm -rf ", dbdir

dbdir: testdir, "/test2"
parseToDisk["testdata"; 2025.07.01; dbdir; ([letters:"X-Y"])]
testPersistedTables dbdir
system "rm -rf ", dbdir

-1 "All tests passed";
exit 0