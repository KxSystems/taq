# NYSE TAQ Data Loader module

This module provides high-performance utilities for parsing [NYSE TAQ (Trade and Quote) PSV files](https://ftp.nyse.com/Historical%20Data%20Samples/DAILY%20TAQ/), performing data transformations, and persisting the results into a date-partitioned kdb+ database (aka. HDB).

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

The following table provides an estimate of the data footprint based on the `SIZE` parameter:

| `SIZE` | Symbol Range (First Letter) | Uncompressed PSVs Size | Uncompressed HDB Size | Symbol Nr | Quote Nr |
| --- | ---: | ---: | ---: | ---: | ---: |
| `small` | Z | ~10 GB | ~0.3 GB | 246 | 4,041,795 |
| `medium` | I | ~20 GB | ~8.1 GB | 1,313 | 125,442,373 |
| `large` | A-H | ~51 GB | ~36 GB | 10,693 | 516,394,615 |
| `full` | A-Z | ~133 GB | ~106 GB | 24,377 | 1,570,602,937 |

## Quickstart

The primary interface for this module is the `parseToDisk` function, which requires at least three parameters.

```q
([parseToDisk]): use `kx.taq
```

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

## Configuration Options

You can pass a dictionary as the fourth argument to `parseToDisk` to customize the ingestion process.

| Key | Default | Description |
| --- | ---: | --- |
| `letters` | "A-Z" | Restricts ingestion to symbols starting with specific letters (e.g., "K-N") |
| `includetestsymbols` | 0b | If `1b`, includes instruments flagged as test symbols in the `master` PSV. |
| `batchsize`| 10 000 000 | Number of rows processed in memory per chunk. Set to `0` to read the entire file at once for faster processing if RAM permits. |
| `compparam` | `3#0`, i.e. no compression | Compression settings for [.z.zd](https://code.kx.com/q/ref/dotz/#zzd-compressionencryption-defaults). Example: `(17;2;6)` for logical block size, algorithm, and level. You can also pass a dictionary if you would like to specify column-level compression |
| `logger` | logger created by `.logger.createLog[]` of the [KX log module](https://code.kx.com/kdb-x/modules/logging/overview.html) | A logger used for status updates during the long running process |

## Performance Notes

* **Multithreading**: The PSV parsing engine leverages multithreading. Ensure you start your ingestion process with the `-s` flag (e.g., `q -s 8`) to utilize available CPU cores.
* **Memory Management**: If you encounter memory pressure, reduce the `batchSize` in the options dictionary. Conversely, increasing it (or setting it to `0`) will speed up the process.
