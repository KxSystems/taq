// @kind function
// @fileoverview conversion function to
//   1) replace whitespace in sym column values with dots (for better compatibility with kdb+ column naming conventions),
//   2) convert sym column to symbol type.
// @param t table with a sym column to be converted
symbolConv: {[t] update `$"."^sym from t}

// @kind function
// @fileoverview conversion function to filter out test symbols
// @param testSymbols list of test symbols to be filtered out
// @param t table with a sym column used for the filtering
testSymbolFilter: {[testSymbols:`S; t]
  ?[t;enlist (not; (in; `sym; enlist testSymbols));0b;()]
  }

masterTestSymbolFilter: ?[;enlist (not; `testFlag);0b;()]

// @kind function
// @fileoverview conversion function to filter out based on the first letter of the sym column
// @param l string in format like "LM" representing the range of the first letter of the sym column values to be included
// @param t table with a sym column used for the filtering
letterFilter: {[l;t] select from t where sym[;0] within l}