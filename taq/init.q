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
//    * option to store tables in memory instead of on disk
//    * improved logging

\l ::inputSchema.q
\l ::converters.q

DEFAULTS_COMMON: ([letters:"A-Z"; includetestsymbols: 0b; batchsize: 10*1000*1000; tbls: `trade`quote`master])
DEFAULTS_DISK: ([compparam: `master`quote`trade!3#enlist 3#0i; linked:0b])
DEFAULTS_MEMORY: ([symattr: `g; sortcols: `time])
DEFAULTS_TOTP: ([starttime: 0D04:00])

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

enumAndSave: {[dst:`s; date:`d; tableName:`s; t; saveDotD:`b]
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

batchProcess: {[postparse; schema; conv; rows]
  t: conv flip key[schema]!(value schema; "|") 0:FirstBatch _ rows; / drop header in all batches except the first one
  if[count t;
    postparse[t; FirstBatch];
    FirstBatch:: 0b];
  };

process: {[fileName:`s; (schema; conv); postparse; batchsize: `j; logger; saveDotD:`b]
  $[batchsize; [
    logger[`info] "  Starting batch processing ", 1_string fileName;
    FirstBatch:: 1b;
    .Q.fsn[batchProcess[postparse; schema; conv]; fileName; batchsize];
    ]; [
    logger[`info] "  Parsing and converting in one go";
    t: parseAndConvert[fileName; schema; conv; logger];
    logger[`info] "  Enumerating and saving ", string[count t], " rows";
    postparse[t; saveDotD]]
    ]
  logger[`info] "  Data successfully persisted";
  }

processParamsCommon: {[params; paramNr: `j; defaults]
  if[paramNr<count params; '"Too many parameters passed"];

  src: params 0;
  if["S" ~ .Q.ty src; src: string src];
  date: params 1;

  p: defaults: DEFAULTS_COMMON, defaults;
  if[paramNr = count params;
    if[not 99h ~ type last params; '"Dictionary is expected as last parameter"];
    unknownParams: (key last params) except key defaults;
    if[count unknownParams; '"Unknown parameter(s): ", "," sv string unknownParams];
    p,: last params];
  logger: $[`logger in key p; p`logger; [
    .logger: use`kx.log;
    .logger.createLog[]]];

  if[p[`batchsize] within 1 499; '"non-zero batchsize cannot be smaller than 500 (bytes), got ", string p`batchsize];

  if[not p[`letters] like "?-?";
    '"Invalid letter format. Must be in form START-END, for example A-K, got ", p `letters];

  (src; date; p; logger)
  }

processParamsMemory: {[params]
  if[2>count params; '"Too few parameters passed to parseToDisk. ",
    "At least source directory and date must be provided"];
  (src; date; p; logger): processParamsCommon[params; 3; DEFAULTS_MEMORY];
  if[not p[`symattr] in ``g`p; '"Invalid symattr value. Must be `,`g or `p, got ", string p`symattr];
  if[not all p[`sortcols] in `time`ex`sym`cond`corr`seq`source`participantTimestamp;
    '"Invalid sort column(s). Only subsets of `time`ex`sym`cond`corr`seq`source`participantTimestamp are allowed, got: ",
      $[0<type p`sortcols; "," sv ;] string p`sortcols];
  (src; date; p; logger)
  }

processParamsDisk: {[params]
  if[3>count params; '"Too few parameters passed to parseToDisk. ",
    "At least source directory, date and destination directory must be provided"];

  (src; date; p; logger): processParamsCommon[params; 4; DEFAULTS_DISK];

  dst: params 2;
  if["c" ~ .Q.ty dst; dst:`$dst];
  dst: hsym dst;

  if[any (count key .Q.par[dst; date]@) each `master`quote`trade;
    '"Destination directories exist. Clean up and rerun the script"];

  (src; date; dst; p; logger)
  }

processParamsTP: {[params]
  if[3>count params; '"Too few parameters passed to parseToTP. ",
    "At least source directory and date must be provided"];
  (src; date; p; logger): processParamsCommon[params; 4; DEFAULTS_TOTP];

  tpH: hopen params 2;
  (src; date; tpH; p; logger)
  }

parsePSVs: {[src:`C; date:`d; p; preparse; postparse; logger]
  datestr: string[date] except ".";
  letterFilterOpt: $["A-Z" ~ p`letters; ::; letterFilter[p[`letters] except "-"]];

  preparse[`master][];
  logger[`info] "Processing master table...";
  M: hsym `$src, "/EQY_US_ALL_REF_MASTER_", datestr, ".psv";
  master: parseAndConvert[M; MASTERSCHEMA; letterFilterOpt xcol[MASTERRENAME]@; logger];
  (masterExtraConv; extraConv): $[p`includetestsymbols; (::; ::); [
    testSymbols: asc first flip symbolConv select sym from master where testFlag;
    (masterTestSymbolFilter; testSymbolFilter[testSymbols])]];
  if[`master in p`tbls;
    master: symbolConv masterExtraConv master;
    postparse[`master][master; 1b]];

  if[`trade in p`tbls;
    preparse[`trade][];
    logger[`info] "Processing trade table...";
    T: hsym `$src, "/EQY_US_ALL_TRADE_", datestr, ".psv";
    process[T; (TRADESCHEMA; extraConv symbolConv letterFilterOpt xcol[TRADERENAME]@); postparse[`trade]; p`batchsize; logger; 1b]];

  if[`quote in p`tbls;
    preparse[`quote][];
    / We apply first letter filter in file selection
    quotePattern: "splits_us_all_bbo_[", lower[p`letters], "]_", datestr, ".psv";
    F: key hsym`$src;
    Q: hsym `$(src, "/"),/: string asc F where (lower F) like quotePattern;
    if[0 = count Q; Q: hsym `$(src, "/"),/: string asc F where (lower F) like "eqy_us_all_bbo_", datestr, ".psv"];
    if[0<count Q;
      logger[`info] "Processing quote tables...";
      Q process[; (QUOTESCHEMA; extraConv symbolConv xcol[QUOTERENAME]@); postparse[`quote]; p`batchsize; logger]' @[count[Q]#0b;0;:;1b];
      ]];
  }

// @kind function
// @fileoverview parses and returns one day of NYSE TAQ data.
// @param params {list} parameters:
//    * source directory (string or symbol)
//    * date
//    * optional parameters (in form of a dictionary):
//       - letters: filter on the first letter of the Symbol, in form START-END, for example A-K. Default is A-Z (all letters).
//       - includetestsymbols: boolean flag to include test symbols in the output. Default is false (test symbols are excluded).
//       - batchsize: number of rows to process in each batch. Default is 10 million rows.
//                    Set to 0 to disable batch processing and process all rows at once (not recommended if you don't have large amount of memory).
//       - logger: optional custom logger that implements info method. If not passed then a simple kx.log is used.
//       - tbls: list of tables to be parsed. Default is `trade`quote`master (all tables).
//       - sortcols: list of sort columns for the trade and quote tables. Default is `time.
//       - symattr: attribute for the sym column of trade and quote tables. Default is `g.
// @returns a list of 4 items: trade table, quote table, keyed master table and exchange names dictionary
parseToMemory: ('[{[params]
  (src; date; p; logger): processParamsMemory params;
  preparse: `master`trade`quote!3#(::);
  postparse: ([master: {[t;] master,:: t}; trade: {[t;] trade,:: t}; quote: {[t;] quote,:: t}]);

  parsePSVs[src; date; p; preparse; postparse; logger];

  res: .z.M p`tbls;

  delete trade from .z.M;
  delete quote from .z.M;
  delete master from .z.M;

  toUpdate: p[`tbls] except `master;
  res[p[`tbls]?toUpdate]: {[p;res;logger;tableName]
    t: res p[`tbls]?tableName;
    if[count p`sortcols;
      logger[`info] "sorting ", string[tableName], " by ", $[0<type p`sortcols; "," sv ;] string p`sortcols;
      t: p[`sortcols] xasc t];
    if[not null p`symattr;
      logger[`info] "Adding attribute ", string[p `symattr], " to sym of ", string tableName;
      t: update p[`symattr]#sym from t];
    t}[p;res;logger] each toUpdate;

  .Q.gc[];

  res, enlist EXNAMES
  };enlist]);

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
//       - logger: custom logger that implements info method. If not passed then a simple kx.log is used.
//       - tbls: list of tables to be parsed. Default is `trade`quote`master (all tables).
//       - compparam: table-specific compression parameters.
//       - linked: set `1b` to add a linked column `master` to the `trade` and `quote` tables, linking via `sym` to the `master` table.
parseToDisk: ('[{[params]
  (src; date; dst; p; logger): processParamsDisk params;
  setCompr: {[x;] .z.zd:x};
  preparse: ([master: setCompr p[`compparam; `master]; quote: setCompr p[`compparam; `quote]; trade: setCompr p[`compparam; `trade]]);
  writerWrapper: {[linked:`b; dst:`s; date:`d; tableName:`s; t; saveDotD:`b]
      if[linked; t: addLinkedColToMaster[dst; date; t]]; / TODO: refactor, `addLinkedColToMaster` is a converter
      enumAndSave[dst; date; tableName; t; saveDotD]}[p`linked; dst; date];
  postparse: ([master: enumAndSave[dst; date; `$"master/"];
    trade: writerWrapper `trade;
    quote: writerWrapper `quote]);

  parsePSVs[src; date; p; preparse; postparse; logger];

  logger[`info] "Adding parted attribute to trade";
  psym[`sym; .Q.par[dst; date; `trade]];

  logger[`info] "Adding parted attribute to quote";
  psym[`sym; .Q.par[dst; date; `quote]];

  logger[`info] "Saving exchange names...";
  .Q.dd[dst; `exnames] set EXNAMES;

  };enlist]);

NANO: 1000*1000*1000;
waitAndFire: {[tpH; tableName; starttime; timecols; rows;]
  rows: select from rows where time > starttime;
  if[0 = count rows; :()]; / no rows before start time, skip

  if[null offset; offset:: (.z.p-`timestamp$`date$.z.p) - last rows`time];
  / adjust time columns as if was generated in real-time
  rows: ![rows; (); 0b; timecols!(+;;offset) each timecols];
  / 2 msec is system call overhead
  waittime: -0D00:00:00.002 + (last[rows`time] - lasttn) - .z.p - lastfire;
  if[0 < waittime; system "sleep ", string (`long$waittime) % NANO];
  neg[tpH] (".u.upd"; tableName; rows);
  neg[tpH] (::);
  lastfire:: .z.p;
  lasttn:: last rows`time;
  }

// @kind function
// @fileoverview parses and sends NYSE TAQ data to TP in batches real-time.
// @param params {list} parameters:
//    * source directory (string or symbol)
//    * date
//    * TP address (parameter is passed to hopen, so it can be in many formats).
//    * optional parameters (in form of a dictionary):
//       - letters: filter on the first letter of the Symbol, in form START-END, for example A-K. Default is A-Z (all letters).
//       - includetestsymbols: boolean flag to include test symbols in the output. Default is false (test symbols are excluded).
//       - batchsize: number of rows to process in each batch. Default is 10 million rows.
//                    Set to 0 to disable batch processing and process all rows at once (not recommended if you don't have large amount of memory).
//       - logger: custom logger that implements info method. If not passed then a simple kx.log is used.
//       - tbls: list of tables to be parsed. Default is `trade`quote`master (all tables).
parseToTP: ('[{[params]
  (src; date; tpH; p; logger): processParamsTP[params];
  preparse: `master`trade`quote!(::), 2#{lastfire:: `timestamp$0; lasttn:: `timespan$0; offset:: 0Nn};
  postparse: `master`trade`quote!{[tpH;t;] tpH (".u.upd";`master; t)}[tpH],
    waitAndFire[tpH;`trade; p`starttime; `time`participantTimestamp],
    waitAndFire[tpH;`quote; p`starttime; `time`participantTimestamp];

  parsePSVs[src; date; p; preparse; postparse; logger];

  hclose tpH;

  };enlist]);

export: ([parseToMemory; parseToDisk; parseToTP]), use `.schema
