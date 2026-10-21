TESTDATE: "D"$first .z.x

([parseToMemory]): use `...taq

t: use `kx.test;
t.setDefaults ([verbose:0b])

/ Assertion inputs are evaluated in the namespace of the test module, hence values are passed via mocks
mockAll: {[d] key[d] t.mock' value d;}

/ Asserts that each value of dictionary `checks` is true
assertChecks: {[checks]
  t.mock[`checks; checks];
  {t.assertTrue["checks`", string x; ([name: string x])]} each key checks;
  }

assertErrors: {[f; cases]
  mockAll ([f; TESTDATE]);
  {t.assertError[x`input; x`expected; ([name: x`name])]} each cases;
  }

inMemoryChecks: {[(trade; quote; master; exnames)]
  ([nonEmpty: all 0 < count each (trade; quote; master; exnames);
    simpleSelect: 0 < count asc select sum size by exch: exnames ex from trade;
    asofJoin: 0 < count aj[`sym`time; trade; select sym, time, bid, ask from quote]])
  }

///////////////////////////////////////////////////////////
t.feature `parseToMemoryParams;
assertErrors[parseToMemory; (
  ([name: "too many parameters"; input: {f["test/data/bysym"; TESTDATE; 3; `dummyparameter]}; expected: "Too many parameters passed"]);
  ([name: "dictionary type check"; input: {f["test/data/bysym"; TESTDATE; `notadictionary]}; expected: "Dictionary is expected as last parameter"]);
  ([name: "batch size check"; input: {f["test/data/bysym"; TESTDATE; ([batchsize: 499])]}; expected: "non-zero batchsize cannot be smaller than 500 (bytes), got 499"]))];

t.feature `parseToMemoryDefault;
assertChecks inMemoryChecks parseToMemory["test/data/bysym"; TESTDATE];

t.feature `parseToMemoryLetters;
assertChecks inMemoryChecks parseToMemory["test/data/bysym"; TESTDATE; ([letters:"X-Y"])];

t.feature `parseToMemoryNoBatching;
assertChecks inMemoryChecks parseToMemory["test/data/bysym"; TESTDATE; ([batchsize: 0])];

t.feature `parseToMemoryBatchSize;
assertChecks inMemoryChecks parseToMemory["test/data/bysym"; TESTDATE; ([batchsize: 500])];

t.feature `parseToMemoryCustomLogger;
logged: ();
assertChecks inMemoryChecks parseToMemory["test/data/bysym"; TESTDATE; ([logger: ([info: {logged,:: enlist x}])])];
assertChecks ([loggerCalled: 0 < count logged]);

t.feature `parseToMemoryUnsorted;
(trade; quote; ; ): parseToMemory["test/data/bysym"; TESTDATE; ([sortcols: ()])];
assertChecks ([tradeTimeNotSorted: not `s = meta[trade][`time; `a];
  quoteTimeNotSorted: not `s = meta[quote][`time; `a]]);

t.feature `parseToMemorySortedBySym;
(trade; quote; ; ): parseToMemory["test/data/bysym"; TESTDATE; ([sortcols: `sym; symattr: `p])];
assertChecks ([tradeSymParted: `p = meta[trade][`sym; `a];
  quoteSymParted: `p = meta[quote][`sym; `a]]);

t.feature `parseToMemoryNoSymAttr;
(trade; quote; ; ): parseToMemory["test/data/bysym"; TESTDATE; ([symattr: `])];
assertChecks ([tradeSymNoAttr: ` = meta[trade][`sym; `a];
  quoteSymNoAttr: ` = meta[quote][`sym; `a]]);

///////////////////////////////////////////////////////////
t.teardown[];
r: t.getReport[];
if[count f: select feature, name, status, actual: details@\:`actual from r where status<>`pass;
  -2 "Failed tests:"; -2 .Q.s f; exit 1];

-1 "All ", string[count r], " parseToMemory tests passed";

if[not any "-debug" ~/: .z.x; exit 0]
