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

\l ::schema.q
\l ::converters.q

DEFAULTS_COMMON: ([letters:"A-Z"; includetestsymbols: 0b; batchsize: 10*1000*1000])
DEFAULTS_DISK: DEFAULTS_COMMON, ([compparam: `master`quote`trade!3#enlist 3#0i; linked:0b; sortbytime:0b])
DEFAULTS_MEMORY: DEFAULTS_COMMON, ([grouped: 1b; sortbytime: 1b])

MERGE_CHUNK: 1000000  / rows read per stage per iteration in the time-sort k-way merge

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
// @fileoverview k-way streaming merge of K time-sorted splayed stages into a
//   single splayed destination, applying `s#time and preserving it across upserts.
//   Peak memory is bounded by K * chunkSize rows, independent of total dataset size,
//   enabling CE-friendly (bounded-heap) time-sorted ingest of datasets larger than RAM.
// @param stagePaths list of splayed stage paths, each internally time-sorted
// @param finalDir splayed destination path
// @param chunkSize max rows to read per stage per iteration
// @param logger logger
mergeTimeStages: {[stagePaths; finalDir:`s; chunkSize:`j; logger]
  stgs:  get each stagePaths;
  times: stgs @\: `time;
  lens:  count each stgs;
  cur:   (count stgs)#0;
  .Q.dd[finalDir; `.d] set cols first stgs;
  emit:  {[fd; t] genericUpsert[peach; fd; @[t; `time; `s#]]}[finalDir];
  while[any cur < lens;
    active:   where cur < lens;
    peekIdx:  (cur[active] + chunkSize - 1) & (lens[active]) - 1;
    horizon:  min times[active] @' peekIdx;
    safeLens: 0 | 1 + (times[active] bin\: horizon) - cur[active];
    frames:   {[s;c;n] n # c _ s}'[stgs[active]; cur[active]; safeLens];
    emit `time xasc raze frames;
    cur[active]: cur[active] + safeLens];
  }

// @kind function
// @fileoverview removes a splayed directory and its column files
// @param p splayed dir path
hdelSplayed: {[p:`s]
  if[not () ~ key p;
    hdel each .Q.dd[p] each (cols get p),`.d;
    hdel p]
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

  p: defaults;
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
  processParamsCommon[params; 3; DEFAULTS_MEMORY]
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

  partKeys: key .Q.dd[dst; `$string date];
  if[$[11h = type partKeys; any partKeys like "*_stage_*"; 0b];
    '"Stage directories from a previous run exist. Clean up and rerun the script"];

  (src; date; dst; p; logger)
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
  master: symbolConv masterExtraConv master;

  postparse[`master][master; 1b];

  preparse[`trade][];
  logger[`info] "Processing trade table...";
  T: hsym `$src, "/EQY_US_ALL_TRADE_", datestr, ".psv";
  process[T; (TRADESCHEMA; extraConv symbolConv letterFilterOpt xcol[TRADERENAME]@); postparse[`trade]; p`batchsize; logger; 1b];

  preparse[`quote][];
  / We apply first letter filter in file selection
  quotePattern: "splits_us_all_bbo_[", lower[p`letters], "]_", datestr, ".psv";
  F: key hsym`$src;
  Q: hsym `$(src, "/"),/: string asc F where (lower F) like quotePattern;
  if[0<count Q;
    logger[`info] "Processing quote tables...";
    Q process[; (QUOTESCHEMA; extraConv symbolConv xcol[QUOTERENAME]@); postparse[`quote]; p`batchsize; logger]' @[count[Q]#0b;0;:;1b];
    ];
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
//       - sortbytime: boolean flag to sort the trade and quote tables by time. Default is true.
//       - grouped: boolean flag to add grouped attribute by sym to trade and quote tables. Default is true.
// @returns a list of 4 items: trade table, quote table, keyed master table and exchange names dictionary

parseToMemory: ('[{[params]
  (src; date; p; logger): processParamsMemory params;
  preparse: `master`trade`quote!3#(::);
  postparse: ([master: {[t;] master,:: t}; trade: {[t;] trade,:: t}; quote: {[t;] quote,:: t}]);

  parsePSVs[src; date; p; preparse; postparse; logger];

  (t; q; m; e): (trade; quote; master; EXNAMES);

  delete trade from .z.M;
  delete quote from .z.M;
  delete master from .z.M;

  if[p`sortbytime;
    logger[`info] "Sorting trade by time";
    t: `time xasc t;
    logger[`info] "Sorting quote by time";
    q: `time xasc q
  ];

  if[p`grouped;
    logger[`info] "Adding grouped attribute to trade";
    t: update `g#sym from t;
    logger[`info] "Adding grouped attribute to quote";
    q: update `g#sym from q;
  ];

  .Q.gc[];
  (t; q; `sym xkey m; e)
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
//       - compparam: table-specific compression parameters.
//       - linked: set `1b` to add a linked column `master` to the `trade` and `quote` tables, linking via `sym` to the `master` table.
//       - sortbytime: set `1b` to produce time-sorted output with `s#time (no `p#sym).
//                     Each parsed batch is sorted by time in memory and written to its own
//                     splayed stage (`trade_stage_N` / `quote_stage_N`); at finalize, stages
//                     are streamed into the final tables via a k-way merge that preserves
//                     `s#time across column upserts. Peak heap is bounded by K * MERGE_CHUNK
//                     rows, so CE users can ingest datasets that exceed the working-set cap.
parseToDisk: ('[{[params]
  (src; date; dst; p; logger): processParamsDisk params;
  setCompr: {[x;] .z.zd:x};

  writerWrapper: {[linked:`b; dst:`s; date:`d; tableName:`s; t; saveDotD:`b]
      if[linked; t: addLinkedColToMaster[dst; date; t]]; / TODO: refactor, `addLinkedColToMaster` is a converter
      enumAndSave[dst; date; tableName; t; saveDotD]}[p`linked; dst; date];

  / Time-sort path: each parsed batch is sorted by time in memory and written to its
  / own splayed stage ({trade,quote}_stage_N). At finalize, stages are k-way merged
  / into the final tables with `s#time preserved. Per-batch (not per-file) staging is
  / required because TAQ PSVs are sym-then-time, so batches aren't globally monotone.
  tradeStageIdx:: quoteStageIdx:: 0;
  tradeStageWriter: {[wr;t;sd] tradeStageIdx+:: 1; wr[`$"trade_stage_",string tradeStageIdx; `time xasc t; 1b]}[writerWrapper];
  quoteStageWriter: {[wr;t;sd] quoteStageIdx+:: 1; wr[`$"quote_stage_",string quoteStageIdx; `time xasc t; 1b]}[writerWrapper];

  / Stages are ephemeral; override trade/quote compression to none for stage writes,
  / and restore per-table compression before the final merge.
  compr: $[p`sortbytime; p[`compparam], `trade`quote!2#enlist 3#0i; p`compparam];
  preparse:  `master`trade`quote!(setCompr compr`master; setCompr compr`trade; setCompr compr`quote);
  postparse: `master`trade`quote!(
    enumAndSave[dst; date; `$"master/"];
    $[p`sortbytime; tradeStageWriter; writerWrapper `trade];
    $[p`sortbytime; quoteStageWriter; writerWrapper `quote]);

  parsePSVs[src; date; p; preparse; postparse; logger];

  mergeOne: {[dst; date; p; logger; tbl; nStages]
    logger[`info] "Merging ",string[nStages]," ",string[tbl]," stage(s) by time...";
    .z.zd: p[`compparam; tbl];
    stagePaths: .Q.par[dst; date;] each `$ (string[tbl],"_stage_") ,/: string 1 + til nStages;
    mergeTimeStages[stagePaths; .Q.par[dst; date; tbl]; MERGE_CHUNK; logger];
    hdelSplayed each stagePaths};
  psymOne: {[dst; date; logger; tbl]
    logger[`info] "Adding parted attribute to ", string tbl;
    psym[`sym; .Q.par[dst; date; tbl]]};

  $[p`sortbytime;
    mergeOne[dst; date; p; logger]'[`trade`quote; tradeStageIdx, quoteStageIdx];
    psymOne[dst; date; logger] each `trade`quote];

  logger[`info] "Saving exchange names...";
  .Q.dd[dst; `exnames] set EXNAMES;

  };enlist]);

export: ([parseToMemory; parseToDisk])
