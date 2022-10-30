CREATE TABLE IF NOT EXISTS calls (
    CallId TEXT PRIMARY KEY,
    ANum TEXT NOT NULL,
    BNum TEXT NOT NULL,
    TimeStamp TEXT,
    CallType TEXT,
    Direction TEXT,
    Duration INTEGER,
    Result TEXT,
    Recordings INTEGER
);

CREATE TABLE IF NOT EXISTS recordings (
    RecordingId TEXT PRIMARY KEY,
    CallId TEXT,
    FilePath TEXT
);
