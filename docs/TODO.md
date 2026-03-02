# TAQ Loader TODO

- Add an option to create linked columns.
- Add an option to store data in memory:

    1. Sorted by `time`.
    2. Sorted by `time` and grouped by the `sym` column.
    3. Stored in table dictionary format. The distinct `sym` column values are the keys of the dictionary.
- Add an option to store data in IDB format, i.e. partition by 10 minutes, having parted attribute on `sym`
