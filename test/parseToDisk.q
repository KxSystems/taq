usage: "Usage: q parseToDisk.q <testdir> <date> [-debug]\n  testdir  directory for temporary test databases\n  date     date of the test data, e.g. 2024.01.02"
args: .z.x where not "-debug" ~/: .z.x

if[2 <> count args; -2 "Expected 2 parameters (testdir, date) but got ", string[count args], "\n", usage; exit 1];
testdir: first args
TESTDATE: "D"$last args
if[null TESTDATE; -2 "Invalid date '", last[args], "'\n", usage; exit 1];

([parseToDisk]): use `...taq

t: use `kx.test;
t.setDefaults ([verbose:0b])

/ Assertion inputs are evaluated in the namespace of the test module, hence values are passed via mocks
mockAll: {[d] key[d] t.mock' value d;}

/ Asserts that each value of dictionary `checks` is true
assertChecks: {[checks]
  t.mock[`checks; checks];
  {t.assertTrue["checks`", string x; ([name: string x])]} each key checks;
  }

/ Runs feature `name`: persists test/data/bysym into its own dbdir with `params` (:: for defaults),
/ asserts the common persistedChecks plus those of `extra` (:: or a function of dbdir), then removes the dbdir
persistTest: {[name; params; extra]
  t.feature name;
  dbdir: testdir, "/", string name;
  $[(::) ~ params; parseToDisk["test/data/bysym"; TESTDATE; dbdir]; parseToDisk["test/data/bysym"; TESTDATE; dbdir; params]];
  checks: persistedChecks dbdir;
  assertChecks $[(::) ~ extra; checks; checks, extra dbdir];
  system "rm -rf ", dbdir;
  }

assertErrors: {[f; cases]
  mockAll ([f; TESTDATE; testdir]);
  {t.assertError[x`input; x`expected; ([name: x`name])]} each cases;
  }

persistedChecks: {[dbdir]
  .Q.lo[`$dbdir; 0b; 0b];
  ([nonEmpty: all 0 < count each value each `trade`quote`master`exnames;
    partedSym: all `p = {meta[x][`sym]`a} each (trade; quote);
    simpleSelect: 0 < count asc select sum size by exch: exnames ex from trade;
    asofJoin: 0 < count aj[`sym`time; select from trade where date=min date; select sym, time, bid, ask from quote where date=min date]])
  }

///////////////////////////////////////////////////////////
t.feature `parseToDiskParams;
assertErrors[parseToDisk; (
  ([name: "too many parameters"; input: {f["test/data/bysym"; TESTDATE; testdir; 4; `dummyparameter]}; expected: "Too many parameters passed"]);
  ([name: "dictionary type check"; input: {f["test/data/bysym"; TESTDATE; testdir; `notadictionary]}; expected: "Dictionary is expected as last parameter"]))];

persistTest[`parseToDiskDefault; (::); (::)];
persistTest[`parseToDiskLetters; ([letters:"X-Y"]); (::)];
persistTest[`parseToDiskNoBatching; ([batchsize: 0]); (::)];
persistTest[`parseToDiskBatchSize; ([batchsize: 500]); (::)];

persistTest[`parseToDiskCompression; ([compparam: ([master: 0 0 0; trade: 17 2 6; quote: 17 2 6])]); {[dbdir] ([
  masterUncompressed: 0 = count -21!hsym `$dbdir,"/", string[TESTDATE],"/master/sym";
  tradeCompressed: (2 17 6i) ~ -3#value -21!hsym `$dbdir,"/", string[TESTDATE],"/trade/sym";
  quoteCompressed: (2 17 6i) ~ -3#value -21!hsym `$dbdir,"/", string[TESTDATE],"/quote/sym"])}];

persistTest[`parseToDiskLinked; ([linked: 1b]); {[dbdir] ([
  tradeLinked: (`master in cols trade) and `master = meta[trade][`master]`f;
  quoteLinked: (`master in cols quote) and `master = meta[quote][`master]`f;
  tradeLinkedSelect: 0 < count @[{select master.description, price from trade}; ::; ()];
  quoteLinkedSelect: 0 < count @[{select master.description, ask, bid from quote}; ::; ()]])}];

///////////////////////////////////////////////////////////
t.teardown[];
r: t.getReport[];
if[count f: select feature, name, status, actual: details@\:`actual from r where status<>`pass;
  -2 "Failed tests:"; -2 .Q.s f; exit 1];

-1 "All ", string[count r], " parseToDisk tests passed";

if[not any "-debug" ~/: .z.x; exit 0]
