# BeneCallArchiver
Store personal call history and call recordings to local filesyste and SQLite database.


## Requirements

- PSSQLite module
- User account on BeneCloud with  Callrecording on

### Env variables

| Variable | Description |
|---|---|
| BENEAPI_USERNAME | Username of account |
| BENEAPI_APISECRET | API SecretKey, [more info](https://doc.enreachvoice.com/beneapi/#key-acquisition) |
| BENECALLARCHIVER_ROOTPATH | Path to folder where call-info database, and possible callrecordings are stored |


### Folder structure

```
Rootpath
│   callhistory.db
│
├───2020-11-10
│       30629cdf-6023-eb11-b821-0050569e6df2.mp3
│       46475ea5-4523-eb11-b821-0050569e6df2.mp3
│       684a0970-4723-eb11-b821-0050569e6df2.mp3
│
├───2020-11-12
│       8fc8fdf3-c724-eb11-b821-0050569e6df2.mp3
│
└───2020-11-13
        b2213627-ad25-eb11-b821-0050569e6df2.mp3
```

