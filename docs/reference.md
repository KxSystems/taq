# NYSE TAQ Data Loader module

This module provides high-performance utilities for parsing [NYSE TAQ (Trade and Quote) PSV files](https://ftp.nyse.com/Historical%20Data%20Samples/DAILY%20TAQ/), performing data transformations, and loading the results either into a date-partitioned kdb+ database (HDB) or directly into in-memory tables (RDB).

## Prerequisites: Input PSV Files

The module requires NYSE TAQ master, trade, and quote PSV files. These can be downloaded from the [NYSE FTP server](https://ftp.nyse.com/Historical%20Data%20Samples/DAILY%20TAQ/) and extracted into a local directory.

> [!WARNING]
> The NYSE TAQ files are large. Depending on your network bandwidth, downloading them may take a long time and may require tens of gigabytes of disk space. Consider passing `SIZE=small` to `getCSVs.sh`.

A utility script, `getCSVs.sh` (located in directory `scripts`), is provided to automate the download and extraction process via `curl`. To download and unzip all available TAQ files to `/tmp/nysetaqpsv`:

```bash
# Extract available dates from the NYSE FTP
DATES=$(curl -s "https://ftp.nyse.com/Historical%20Data%20Samples/DAILY%20TAQ/" |  grep -oE '"EQY_US_ALL_TRADE_[0-9]{8}\.gz"' |  grep -oE '[0-9]{8}' |paste -sd,)
./scripts/getCSVs.sh /tmp/nysetaqpsv "$DATES"
```

To manage disk space and bandwidth, you can restrict the download scope by:

   1. **Limiting Dates:** Target a specific date (e.g., the most recent available).
   1. **Using the `SIZE` Variable**: Filter by symbol ranges using the `SIZE` environment variable.

```bash
# Example: Download PSVs for only a single date
DATES=$(curl -s https://ftp.nyse.com/Historical%20Data%20Samples/DAILY%20TAQ/| grep -oE 'EQY_US_ALL_TRADE_2[0-9]{7}' | grep -oE '2[0-9]{7}'|head -1)
SIZE=small ./scripts/getCSVs.sh /tmp/nysetaqpsv "$DATES"
```

### Dataset Statistics (Reference: 2025.07.01)

The following table estimates the data footprint by `SIZE` parameter:

| `SIZE` | Symbol Range (First Letter) | Uncompressed PSVs Size | Uncompressed HDB Size | Symbol Nr | Quote Nr |
| --- | ---: | ---: | ---: | ---: | ---: |
| `small` | Z | ~10 GB | ~0.3 GB | 246 | 4,041,795 |
| `medium` | I | ~20 GB | ~8.1 GB | 1,313 | 125,442,373 |
| `large` | A-H | ~51 GB | ~36 GB | 10,693 | 516,394,615 |
| `full` | A-Z | ~133 GB | ~106 GB | 24,377 | 1,570,602,937 |

## Quickstart

This module exposes two primary functions:

- **`parseToDisk`** — parses TAQ data and persists it into a date-partitioned HDB on disk.
- **`parseToMemory`** — parses TAQ data and loads it directly into in-memory tables, suitable for RDB-style workflows.

```q
([parseToMemory; parseToDisk]): use `kx.taq
```

### parseToDisk

`parseToDisk` requires at least three parameters.

To create the `trade`, `quote`, `master` tables and `exnames` dictionary for October 2, 2025, and save them to `/tmp/kdbdb`:

```q
parseToDisk["/tmp/nysetaqpsv"; 2025.10.02; "/tmp/kdbdb"]
```

Once the data is generated, you can load it into a q session with 4 [worker threads](https://code.kx.com/kdb-x/reference/syscmds.html#s-number-of-secondary-threads) using the following command (or by `\l` in a running q session):

```bash
$ q /tmp/kdbdb -s 4
```

You can then execute standard q queries against the partitioned data:

```q
/ Calculate total size by exchange names for the most recent date
q)asc select sum size by exch: exnames ex from trade where date=last date
exch                              | size
----------------------------------| ----------
New York Stock Exchange           | 738731806
Long-Term Stock Exchange          | 1364829
NASDAQ OMX PSX                    | 23555592
...

/ Perform an as-of join (aj) between trades and quotes
q)aj[`sym`time; select sym, time, price, size from trade where date=first date, sym in `MSFT`GOOG`AMZN; select sym, time, bid, ask from quote where date=first date]
sym  time                 price  size bid    ask
---------------------------------------------------
AMZN 0D04:00:00.009709706 219.5  3    219.41 219.98
AMZN 0D04:00:00.010213563 219.7  3    219.41 219.98
AMZN 0D04:00:00.010379075 219.7  2    219.41 219.98
AMZN 0D04:00:00.010640417 219.98 100  219.41 219.98
..
```

### parseToMemory

`parseToMemory` requires at least two parameters — no destination path is needed as data is loaded directly into memory.

To load the `trade`, `quote`, `master` tables and `exnames` dictionary for October 2, 2025, into memory:

```q
(trade; quote; master; exnames): parseToMemory["/tmp/nysetaqpsv"; 2025.10.02]
```

The resulting `trade` and `quote` tables are sorted by `time` and carry a grouped attribute on `sym`, matching the layout of a typical RDB. Unlike the HDB tables produced by `parseToDisk`, in-memory tables do not include a `date` column.

```q
/ Perform an as-of join (aj) between the in-memory trades and quotes
q)aj[`sym`time; select sym, time, price, size from trade where sym in `MSFT`GOOG`AMZN; select sym, time, bid, ask from quote]
sym  time                 price  size bid    ask
---------------------------------------------------
AMZN 0D04:00:00.009709706 219.5  3    219.41 219.98
AMZN 0D04:00:00.010213563 219.7  3    219.41 219.98
AMZN 0D04:00:00.010379075 219.7  2    219.41 219.98
AMZN 0D04:00:00.010640417 219.98 100  219.41 219.98
...
```

Storing a full day of NYSE TAQ data in memory is RAM-intensive. The table below shows approximate memory requirements by `SIZE` parameter, measured against data from 2025.10.02.

| `SIZE` | Symbol Range (First Letter) | Memory need |
| --- | ---: | ---: |
| `small` | Z | ~2 GB |
| `medium` | I | ~14 GB |
| `large` | A-H | ~79 GB |
| `full` | A-Z | ~170 GB |

## Configuration Options

Both `parseToDisk` and `parseToMemory` accept an optional dictionary as their last argument to customize the ingestion process.

### Common parameters

| Key | Default | Description |
| --- | ---: | --- |
| `letters` | `"A-Z"` | Restricts ingestion to symbols whose first letter falls within the specified range (e.g., `"K-N"`). |
| `includetestsymbols` | `0b` | If `1b`, includes instruments flagged as test symbols in the `master` PSV. |
| `batchsize` | `10 000 000` | Number of rows processed per chunk. Set to `0` to read the entire file in one pass for faster throughput if RAM permits. |
| `logger` | logger created by `.logger.createLog[]` of the [KX log module](https://code.kx.com/kdb-x/modules/logging/overview.html) | Logger used for status updates during the ingestion process. |

### parseToDisk extra parameters

| Key | Default | Description |
| --- | ---: | --- |
| `compparam` | `([master: 0 0 0; trade: 0 0 0; quote: 0 0 0])`, i.e. no compression | Table-specific compression settings for [.z.zd](https://code.kx.com/q/ref/dotz/#zzd-compressionencryption-defaults). Example: `([master: 0 0 0; trade: 17 2 6; quote: 17 2 6])`. Pass a dictionary of dictionaries to specify column-level compression. |
| `linked` | `0b` | Set `1b` to add a linked column `master` to the `trade` and `quote` tables, linking via `sym` to the `master` table. |
| `sortbytime` | `0b` | If `1b`, produces time-sorted `trade` and `quote` tables with the `` `s#`` attribute on `time` instead of the default `` `p#`` on `sym`. Each parsed batch is sorted by time in memory, staged under `trade_stage_N` / `quote_stage_N` splayed dirs, then streamed into the final table via a bounded-memory k-way merge — enabling CE-friendly ingest of datasets that do not fit in the working-set cap. Choose this mode for replay, streaming, or range-scan workflows; keep the default `0b` for per-symbol query patterns that benefit from the parted index. |

### parseToMemory extra parameters

| Key | Default | Description |
| --- | ---: | --- |
| `grouped` | `1b` | If `1b`, applies the grouped attribute to the `sym` column in the `trade` and `quote` tables. |
| `sortbytime` | `1b` | If `1b`, sorts `trade` and `quote` by `time` and applies the sorted attribute. |


## Performance Notes

* **Multithreading**: The PSV parsing engine is multithreaded. Start your ingestion process with the `-s` flag (e.g., `q -s 8`) to make use of available CPU cores.
* **Memory Management**: If you encounter memory pressure, reduce `batchsize` in the options dictionary. Conversely, increasing it (or setting it to `0`) will speed up the process.
