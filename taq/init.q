// Improvement of tq.q available at https://github.com/KxSystems/kdb-taq
// Improvements include:
//    * k code is rewritten to q
//    * destination directory is not hardcoded
//    * new parameter to filter on the first letter of the Symbol
//    * improved error handling
//    * code quality improvements
//    * option to drop test Symbols
//    * columns are written in parallel
//    * support of batch processing for smaller memory usage

\l ::schema.q
\l ::converters.q

DEFAULTS: ([letters:"A-Z"; includetestsymbols: 0b; batchsize: 10*1000*1000; compparam: 3#0i])

// @kind function
// @fileoverview parses a file and applies necessary conversions to the resulting table
// @param fileName path to the psv file to be parsed
// @param schema schema of the file to be parsed, for example TRADESCHEMA or QUOTESCHEMA
// @param conv conversion function to be applied to the parsed table, for example symbolConv or letterFilter
// @param logger logger to log info messages
parseAndConvert: {[fileName:`s; schema; conv; logger]
  logger[`info] "  Parsing file ", 1_string fileName;
  raw: flip key[schema]!value flip(value schema; enlist"|") 0:fileName;
  logger[`info] "  Converting";
  conv raw
  }

// @kind function
// @fileoverview upsert that supports parallel writing of columns
// @param iter iterator function, for example `peach` or `each`
// @param path path to a table partition
// @param tab table to be saved
genericUpsert:{[iter; path:`s; tab]
	iter[{[path;tab;c] .Q.dd[path;c] upsert tab c}[path;tab]; cols tab];
	}

enumAndSave: {[t; dst:`s; tableName:`s; saveDotD:`b; date:`d]
  path: .Q.par[dst;date;tableName];
  if[saveDotD; .Q.dd[path;`.d] set cols t];
  genericUpsert[peach; path; .Q.en[dst] t];
  }

// @kind function
// @fileoverview adds parted attribute to a column on disk
// @param c column name (symbol)
// @param x path to a table partition
psym: {[c:`s; x:`s]
  if[null @[@[;c;`p#];x;`];
    broken:x where not(x?x)=til count x@:where not=':[x@:c];
    '"parted attribute cannot be applied on ", string[c], " due to ", "," sv string broken]
  }

batchProcess: {[schema; conv; dst:`s; tableName:`s; date:`d; rows]
  $[FirstRow; [
    t: conv flip key[schema]!(value schema; "|") 0:1_rows; / drop header
    enumAndSave[t; dst; tableName; 1b; date];
    FirstRow:: 0b;
  ]; [
    t: conv flip key[schema]!(value schema; "|") 0:rows;
    if[count t; enumAndSave[t; dst; tableName; 0b; date]];
  ]]
  };

process: {[fileName:`s; (schema; conv); date:`d; dst:`s; tableName:`s; batchsize: `j; logger; saveDotD:`b]
  $[batchsize=0; [
    t: parseAndConvert[fileName; schema; conv; logger];
    logger[`info] "  Enumerating and saving ", string[count t], " rows";
    enumAndSave[t; dst; tableName; saveDotD; date]];
    [
    logger[`info] "  Starting batch processing ", 1_string fileName;
    FirstRow:: 1b;
    .Q.fsn[batchProcess[schema; conv; dst; tableName; date]; fileName; batchsize];
    ]]
  logger[`info] "  Data successfully persisted";
  }

processParams: {[params]
  if[4<count params; '"Too many parameters passed to parseToDisk"];
  if[3>count params; '"Too few parameters passed to parseToDisk. ",
    "At least source directory, date and destination directory must be provided"];

  src: params 0;
  if["S" ~ .Q.ty src; src: string src];
  date: params 1;
  dst: params 2;
  if["c" ~ .Q.ty dst; dst:`$dst];
  dst: hsym dst;

  p: DEFAULTS;
  if[3<count params;
    if[not 99h ~ type last params; '"Dictionary is expected as fourth parameter"];
    unknownParams: (key last params) except key DEFAULTS;
    if[count unknownParams; '"Unknown parameter(s): ", "," sv string unknownParams];
    p,: last params];
  logger: $[`logger in key p; p`logger; [
    .logger: use`kx.log;
    .logger.createLog[]]];

  if[any (count key .Q.par[dst; date]@) each `master`quote`trade;
    '"Destination directories exist. Clean up and rerun the script"];

  if[not p[`letters] like "?-?";
    '"Invalid letter format. Must be in form START-END, for example A-K, got ", p `letters];

  (src; date; dst; p; logger)
  }
// @kind function
// @fileoverview parses and persists NYSE TAQ data into a date-partitioned kdb+ database.
// @param params {list} parameters:
//    * source directory (string or symbol)
//    * date
//    * destination directory (string or symbol)
//    * optional parameters (in form of a dictionary):
//       - letters: filter on the first letter of the Symbol, in form START-END, for example A-K. Default is A-Z (all letters).
//       - includetestsymbols: boolean flag to include test symbols in the output. Default is false (test symbols are excluded).
//       - batchsize: number of rows to process in each batch. Default is 10 million rows.
//                    Set to 0 to disable batch processing and process all rows at once (not recommended if you don't have large amount of memory).
//       - logger: optional custom logger that implements info method. If not passed then a simple kx.log is used.
parseToDisk: ('[{[params]
  (src; date; dst; p; logger): processParams params;
  datestr: string[date] except ".";

  logger[`info] "Saving exchange names...";
  .Q.dd[dst; `exnames] set (raze string key EXNAMES)!`$value EXNAMES; / convert keys to characters

  letterFilterOpt: $["A-Z" ~ p`letters; ::; letterFilter[p[`letters] except "-"]];

  logger[`info] "Processing master table...";
  M: hsym `$src, "/EQY_US_ALL_REF_MASTER_", datestr, ".psv";
  master: parseAndConvert[M; MASTERSCHEMA; letterFilterOpt xcol[MASTERRENAME]@; logger];
  (masterExtraConv; extraConv): $[p`includetestsymbols; (::; ::); [
    testSymbols: asc first flip symbolConv select sym from master where testFlag;
    (masterTestSymbolFilter; testSymbolFilter[testSymbols])]];

  enumAndSave[symbolConv masterExtraConv master; dst; `$"master/"; 1b; date];

  .z.zd: p`compparam; / apply compression to quote and trade
  / We apply first letter filter in file selection
  quotePattern: "splits_us_all_bbo_[", lower[p`letters], "]_", datestr, ".psv";
  F: key hsym`$src;
  Q: hsym `$(src, "/"),/: string asc F where (lower F) like quotePattern;
  if[0<count Q;
    logger[`info] "Processing quote tables...";
    Q process[; (QUOTESCHEMA; extraConv symbolConv xcol[QUOTERENAME]@); date; dst; `quote; p`batchsize; logger]' @[count[Q]#0b;0;:;1b];
    logger[`info] "  Adding parted attribute...";
    psym[`sym; .Q.par[dst; date; `quote]]];

  logger[`info] "Processing trade table...";
  T: hsym `$src, "/EQY_US_ALL_TRADE_", datestr, ".psv";
  process[T; (TRADESCHEMA; extraConv symbolConv letterFilterOpt xcol[TRADERENAME]@); date; dst; `trade; p `batchsize; logger; 1b];
  logger[`info] "  Adding parted attribute...";
  psym[`sym; .Q.par[dst; date; `trade]];
  };enlist]);

export: ([parseToDisk])
