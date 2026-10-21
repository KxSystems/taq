# NYSE TAQ Data Loader module

This module provides high-performance utilities for parsing [NYSE TAQ (Trade and Quote) PSV files](https://ftp.nyse.com/Historical%20Data%20Samples/DAILY%20TAQ/) and performing data transformations. Results can be:

- persisted into a date-partitioned kdb+ database (HDB)
- loaded into in-memory tables (RDB)
- streamed to a [tickerplant](https://code.kx.com/q/architecture/tickq/) (TP) or a [Reliable Transport](https://code.kx.com/insights/microservices/rt/) (RT) publisher

<details>
<summary>Note: OS module dependency</summary>

This module uses the `OS` module, which is installed by default by recent KDB-X installers. If the `OS` module is not installed, update your KDB-X environment to pick up the latest changes.

</details>

## Prerequisites: Input PSV Files

The module requires NYSE TAQ master, trade, and quote PSV files. These can be downloaded from the [NYSE FTP server](https://ftp.nyse.com/Historical%20Data%20Samples/DAILY%20TAQ/) and extracted into a local directory.

> [!WARNING]
> The NYSE TAQ files are large. Depending on your network bandwidth, downloading them may take a long time and may require tens of gigabytes of disk space. Consider passing `--size tiny` or `--size small` to `getPSVs.sh`.

A utility script, `getPSVs.sh` (located in the `scripts` directory), is provided to automate the download and extraction process using `curl`, `gawk` and `gunzip`. To download and unzip all available TAQ files to `/tmp/nysetaqpsv`:

```bash
# Extract available dates from the NYSE FTP
DATES=$(curl -s "https://ftp.nyse.com/Historical%20Data%20Samples/DAILY%20TAQ/" |  grep -oE '"EQY_US_ALL_TRADE_[0-9]{8}\.gz"' |  grep -oE '[0-9]{8}' |paste -sd, -)
./scripts/getPSVs.sh --csvdir /tmp/nysetaqpsv --dates "$DATES"
```

To manage disk space and bandwidth, you can restrict the download scope by:

   1. **Limiting Dates:** Target a specific date (e.g., the most recent available).
   1. **Using the `--size` flag**: Filter by symbol ranges using the `--size` flag (or `-s`).

```bash
# Example: Download PSVs for only a single date
DATES=$(curl -s https://ftp.nyse.com/Historical%20Data%20Samples/DAILY%20TAQ/| grep -oE 'EQY_US_ALL_TRADE_2[0-9]{7}' | grep -oE '2[0-9]{7}'|head -1)
./scripts/getPSVs.sh --csvdir /tmp/nysetaqpsv --dates "$DATES" --size tiny
```

### For streaming: sorting by time

To stream NYSE TAQ data to TP or RT, input PSV files must be sorted by time. `./scripts/sort.sh` sorts trade and individual quote files using the [sort](https://man7.org/linux/man-pages/man1/sort.1.html) command, then merges the quote files into a single large file in linear time via `sort -m`.

> **Note:** `sort` requires temporary disk space during sorting. If the default `/tmp` directory has insufficient space, set the `TMPDIR` environment variable to a directory with more space before running the script.

```bash
./scripts/sort.sh --csvdir /tmp/nysetaqpsv --dates "$DATES" --size tiny
```

### Dataset Statistics (Reference: 2026.04.01)

The following table provides some statistics by `SIZE` parameter:

| `SIZE` | Symbol first letters | Memory (GB) | Disk (GB) | Nr of quote symbols | Nr of quotes |
| --- | --- | ---: | ---: | ---: | ---: |
| `tiny` | Z | 1 | 1 | 259 | 9,422,051 |
| `small` | X-Z | 17 | 9 | 909 | 143,336,607 |
| `medium` | T-Z | 70 | 39 | 4,018 | 588,006,863 |
| `large` | P-Z | 142 | 83 | 8,964 | 1,283,196,520 |
| `xlarge` | I-Z | 153 | 124 | 15,127 | 1,901,235,410 |
| `full` | A-Z | 296 | 187 | 26,396 | 2,860,612,301 |


Column `Memory (GB)` shows the required memory of trade and quote tables if the data is stored in memory and has grouped attribute. `Disk (GB)` shows the disk requirement of the data with parted attribute.

## Quickstart

This module exposes four functions:

- **`parseToDisk`** — parses TAQ data and persists it into a date-partitioned HDB on disk.
- **`parseToMemory`** — parses TAQ data and loads it directly into in-memory tables, suitable for RDB-style workflows.
- **`streamToPubSub`** — parses TAQ data and streams it in batches to a TP or RT, as if data arrived from the exchange. Input PSV files must be [sorted by time](#for-streaming-sorting-by-time).
- **`getSchemas`** - return the schemas of `master`, `trade` and `quote` tables. Useful for [streaming to a tickerplant](#streamtopubsub).

```q
taq: use `kx.taq
```

### parseToDisk

`parseToDisk` requires at least three parameters.

To create the `trade`, `quote`, `master` tables, and `exnames` dictionary for October 2, 2025, and save them to `/tmp/kdbdb`:

```q
taq.parseToDisk["/tmp/nysetaqpsv"; 2025.10.02; "/tmp/kdbdb"]
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
...
```

### parseToMemory

`parseToMemory` requires at least two parameters — no destination path is needed as data is loaded directly into memory.

To load the `trade`, `quote`, `master` tables, and `exnames` dictionary for October 2, 2025, into memory:

```q
(trade; quote; master; exnames): taq.parseToMemory["/tmp/nysetaqpsv"; 2025.10.02]
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

### streamToPubSub

`streamToPubSub` publishes `master` immediately, then drip-feeds the `trade` and `quote` rows to a running tickerplant (TP) or Reliable Transport (RT), pacing the publishes to match the original inter-event timing. Input PSV files must be [sorted by time](#for-streaming-sorting-by-time).

`streamToPubSub` requires at least three parameters:

| Position | Name | Type | Description |
| :--- | :--- | :--- | :--- |
| 0 | source directory | string or symbol | Directory of the PSV files. |
| 1 | date | date | Date of the PSV files. |
| 2 | `connH` | int handle or function | Connection handle to publish to. An int handle (e.g. from [hopen](https://code.kx.com/kdb-x/ref/hopen.html)) is treated as a TP connection, and messages are sent asynchronously. Anything else (e.g. an RT publish function) is treated as an RT connection. |
| 3 (optional) | — | dictionary | [Configuration options](#configuration-options). |

For example, to stream data to a tickerplant listening on port 5010, in batches of 5000 bytes:

```q
tpH: hopen 5010
taq.streamToPubSub["/tmp/nysetaqpsv"; 2025.10.02; tpH; ([batchsize: 5000])]
hclose tpH
```

`streamToPubSub` calls `.u.upd` (or the function set by [`updFn`](#streamtopubsub-extra-parameters)) with the table name as the first parameter and the records (as a table) as the second parameter. The simplest way to test this function is to start a mock TP process on the provided port (5010), that defines a basic `.u.upd`:

```bash
q ./test/mocktp.q -p 5010
```

Alternatively, stream to a plain q process by passing `insert` as `updFn`:

```q
taq.streamToPubSub["/tmp/nysetaqpsv"; 2025.10.02; tpH; ([batchsize: 5000; updFn: insert])]
```

In classic kdb+ tick, the tables are predefined. You can get the schema by `taq.getSchemas[]`

```bash
$ q -p 5010
...
q)taq: use `kx.taq
q)(master;trade;quote): taq.getSchemas[]
q).u.upd: insert
```

Stream to a [KX Database Service](https://code.kx.com/kdb-x/services/db-service/introduction.html) via an RT publisher. The tables must be [created](https://code.kx.com/kdb-x/services/db-service/manage-tables.html#create) in DB Service before any data is published to them:

```bash
$ q startq.q
q)rtPub: .rt.pub ([path: "/tmp/rtpub"; stream: "data"; cluster: enlist ":localhost:5002"; publisher_id: "taq"])
q)taq.streamToPubSub["/tmp/nysetaqpsv"; 2025.10.02; rtPub; ([batchsize: 5000])]
```

You can get `startq.q` by unzipping [`rt.qpk`](https://code.kx.com/insights/1.20/microservices/rt/examples/run-rt-locally.html#publish).

#### Timing

The time columns (`time` and `participantTimestamp`) are shifted as if the data was generated in real-time: the first batch is sent immediately, and each subsequent batch is sent when the current time reaches the (shifted) time of its last row. The schedule is anchored to the first batch, so processing time does not accumulate as drift.

`streamToPubSub` publishes quotes after trades, and the quote stream starts its own clock. If you prefer simultaneous publication, start two kdb+ processes and use the `tbls` optional parameter to control which tables each process publishes.

Use `starttime` and `endtime` to stream a slice of the trading day, for example the closing auction:

```q
taq.streamToPubSub["/tmp/nysetaqpsv"; 2025.10.02; tpH; ([starttime: 0D15:55; endtime: 0D16:05])]
```

`streamToPubSub` has no return value; it publishes until every row in the time window has been sent. It is intended for demos rather than stress testing.

## Configuration Options

All three functions accept an optional dictionary as their last argument to customize the ingestion process.

### Common parameters

| Key | Default | Description |
| --- | ---: | --- |
| `letters` | `"A-Z"` | Restricts ingestion to symbols whose first letter falls within the specified range (e.g., `"K-N"`). |
| `batchsize` | `10 000 000` | Number of bytes processed per chunk (minimum `500`). Set to `0` to read the entire file in one pass for faster throughput if RAM permits. For `streamToPubSub`, each chunk is published as one batch. |
| `tbls` | ``` `master`trade`quote ``` | Tables to process. |
| `includetestsymbols` | `0b` | If `1b`, includes instruments flagged as test symbols in the `master` PSV. |
| `logger` | logger created by `.logger.createLog[]` of the [KX log module](https://code.kx.com/kdb-x/modules/logging/overview.html) | Logger used for status updates during the ingestion process. |

### parseToDisk extra parameters

| Key | Default | Description |
| --- | ---: | --- |
| `compparam` | `([master: 0 0 0; trade: 0 0 0; quote: 0 0 0])`, i.e. no compression | Table-specific compression settings for [.z.zd](https://code.kx.com/q/ref/dotz/#zzd-compressionencryption-defaults). Example: `([master: 0 0 0; trade: 17 2 6; quote: 17 2 6])`. Pass a dictionary of dictionaries to specify column-level compression. |
| `linked` | `0b` | Set `1b` to add a linked column `master` to the `trade` and `quote` tables, linking via `sym` to the `master` table. |

### parseToMemory extra parameters

| Key | Default | Description | Options
| --- | ---: | --- | --- |
| `symattr` | ``` `g``` | Attribute for the `sym` column of `trade` and `quote` tables. | either of ``` `g`p` ``` |
| `sortcols` | ``` `time``` | Sort column or a list of sort columns for the `trade` and `quote` tables. | Any subset of ``` `time`ex`sym`cond`corr`seq`source`participantTimestamp```|

#### Example usages

Sorting by `sym` and having a parted attribute on `sym`:

```q
(trade; quote; master; exnames): taq.parseToMemory["/tmp/nysetaqpsv"; 2025.10.02; ([letters: "Y-Z"; sortcols: `sym; symattr: `p])]
```

The original data is sorted by time within each symbol, so sorting by `sym` actually means sorting by `sym` and `time`.

### streamToPubSub extra parameters

| Key | Default | Description |
| --- | ---: | --- |
| `starttime` | `0D04:00` | Records before `starttime` are ignored. |
| `endtime` | `0Wn` | Records after `endtime` are ignored. By default there is no limit. |
| `updFn` | `` `.u.upd `` | Update function called on the TP or RT side. For a TP connection, a function (e.g. `insert`) is also accepted. |

## Performance Notes

- **Multithreading**: The PSV parsing engine is multithreaded. Start your ingestion process with the `-s` flag (e.g., `q -s 8`) to make use of available CPU cores.
- **Memory Management**: If you encounter memory pressure, reduce `batchsize` in the options dictionary. Conversely, increasing it (or setting it to `0`) will speed up the process.
