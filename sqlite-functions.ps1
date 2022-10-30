

function Initialize-CallDatabase {
    Param(
        [string] $RootDirectory
    )
    $dbfile = Join-Path $RootDirectory "callhistory.db"
    $script:dbconn = New-SQLiteConnection -DataSource $dbfile

    # Ensure tables exists
    $createTablesQueryFile = Join-Path $PSScriptRoot "sqlite/create-tables.sql"
    Write-Verbose "Initializing tables..."
    Invoke-SqliteQuery -SQLiteConnection $dbconn -InputFile $createTablesQueryFile
}

function Add-BeneCallToDatabase {
    Param(
        [object] $Call
    )

    if (-not $dbconn) {
        Write-Warning "dbconn not initialized"
        return 
    }

    $insertCall = "
        INSERT OR REPLACE INTO calls (CallId,ANum,BNum,CallType,TimeStamp,Direction,Duration,Result,Recordings)
        VALUES (@CallId,@ANum,@BNum,@CallType,@TimeStamp,@Direction,@Duration,@Result,@Recordings)
    "
    $callTimeStamp = $call.TimeStamp.ToString("yyyy-MM-dd HH':'mm':'ss") 

    $sqlParams = @{
        CallId = $call.CallID.ToString()
        ANum = $call.ANum
        BNum = $call.BNum
        CallType = $call.CallTypeString
        TimeStamp = $callTimeStamp
        Direction = if ($call.Direction) {"Out"} else {"In"}
        Duration = $call.Duration
        Result = if ($call.EndResult) {"Unanswered"} else {"Answered"}
        Recordings = $call.RecordingIds.Count
    }

    # Add call data
    Write-Verbose "Inserting call info to SQLite`n$($sqlParams | ConvertTo-Json)"
    Invoke-SqliteQuery -SQLiteConnection $dbconn -Query $insertCall -SqlParameters $sqlParams
}

function Add-RecordingToDatabase {
    Param(
        [string] $RecordingId,
        [string] $CallId,
        [string] $FilePath
    )

    if (-not $dbconn) {
        Write-Warning "dbconn not initialized"
        return 
    }

    $insertRecording = "
    INSERT OR REPLACE INTO recordings (RecordingId,CallId,FilePath)
    VALUES (@RecordingId,@CallId,@FilePath);
    "

    $sqlParams = @{
        RecordingId = $RecordingId
        CallId = $CallId
        FilePath = $FilePath
    }

    # Add call data
    Write-Verbose "Inserting callrecording to SQLite`n$($sqlParams | ConvertTo-Json)"
    Invoke-SqliteQuery -SQLiteConnection $dbconn -Query $insertRecording -SqlParameters $sqlParams
}

function Get-LatestCall {
    if (-not $dbconn) {
        Write-Warning "dbconn not initialized"
        return 
    }
    

    $query = "SELECT count(*) as 'count', max(TimeStamp) as 'max' FROM calls;"
    $result = Invoke-SqliteQuery -SQLiteConnection $dbconn -Query $query 
    if ($result.max) {
        
        $callCount = $result.count
        $lastTimeStamp = $result.max
        Write-host "Calls in DB [$callCount] Latest: [$lastTimeStamp]"
        #inject Z to end, as timestamps are stored in UTC but PS interprets them as localtime
        $lastTimeStampZ = "$($lastTimeStamp)Z"
        return (Get-Date $lastTimeStampZ)
    }
    return (Get-Date).AddYears(-2)
    

}
