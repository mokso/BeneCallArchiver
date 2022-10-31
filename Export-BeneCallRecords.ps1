# dotsource functions
. "$PSScriptRoot\install-modules.ps1"
. "$PSScriptRoot\beneapi-functions.ps1"
. "$PSScriptRoot\sqlite-functions.ps1"

# Load the tag-lib assembly for tagging mp3 files
[Reflection.Assembly]::LoadFrom( (Resolve-Path ("$PSScriptRoot\TagLibSharp.dll"))) | Out-Null

# Check configuration
if (-not $env:BENECALLARCHIVER_ROOTPATH) {
  Write-Warning "Env-variable BENECALLARCHIVER_ROOTPATH must be set"
  return 
}

$RootPath = $env:BENECALLARCHIVER_ROOTPATH

#how many days to process in one query
$BeneAPIDays = 30

############### Functions ###############

function WriteLog {
  Param(
    [string] $Message,
    [String] $LogLevel = "Info"
  )

  $logPath = Join-Path $env:BENECALLARCHIVER_ROOTPATH "Logs"
  $logFile = Join-Path $logPath "BeneCallArchiver_$(Get-Date -Format "yyyyMMdd").log"

  if (-not (Test-Path $logPath)){
    New-Item $logPath -ItemType Directory
  }

  $logRow = "$(Get-Date -Format "yyyy-MM-dd HH':'mm':'ss") [$LogLevel] $Message"
  write-host $logRow
  $logRow | Out-File $logFile -Append

}

function Invoke-BeneCallArchive {
  param (
    #
    [datetime] $MinDate,
    [datetime] $MaxDate
  )

  WriteLog "Getting calls from $MinDate to $MaxDate"
  
  $calls = Get-BeneUserCalls -ApiInfo $api -TimeFrom $MinDate -TimeTo $MaxDate
  WriteLog "Retrieved $($calls.Count) call records"

  foreach ($c in $calls) {
    Add-BeneCallToDatabase -Call $c 

    #construct folder where recordings should be saved
    $callDate = ($c.TimeStamp).ToString("yyyy-MM-dd")
    $callFolder = Join-Path $env:BENECALLARCHIVER_ROOTPATH $callDate
      
    foreach ($r in $c.RecordingIds) {
      $filePath = Join-Path $callFolder "$r.mp3"
      Get-BeneUserCallRecording -ApiInfo $api -RecordingId $r -Path $filePath
      
      # add id3 tags
      if (Test-Path $filePath) {
        #set file timestamps
        (Get-ChildItem $filePath).CreationTime = $c.TimeStamp
        
        $timestring = $c.TimeStamp.ToShortTimeString()
        
        $mp3 = [TagLib.File]::Create((resolve-path $filePath))
        $mp3.Tag.Artists = $c.UserName
        $mp3.Tag.Title = "$($c.CallTypeString) $($c.ANum) -> $($c.BNum) at $timestring"
        $mp3.Save()
      }
      else {
        Write-Warning "Recording file does not exists $filePath"
      }
    }
  }
}

############### Process ###############
#Process starts here

WriteLog "Starting CallExporter"

WriteLog "Root-path [$RootPath]"
if (-not (Test-Path $RootPath)) {
  New-Item $RootPath -ItemType Directory
}

# initialize BeneAPI connection
$script:api = Get-BeneAPIAuth 

#initialize SQLite DB

$dbok = Initialize-CallDatabase -rootDirectory $RootPath

if (-not $dbok) {
  WriteLog "No DB, exiting..." -LogLevel "Error"
  return
}


#get latest call stored in database
$latest = Get-LatestCall 
WriteLog "Latest call in database $latest"
$now = get-date

while ($latest -lt $now) {
  $min = $latest.AddSeconds(1)
  $max = $latest.AddDays($BeneAPIDays)
  if ($max -gt $now) {
    $max = $now
  }
  
  Invoke-BeneCallArchive -MinDate $min -MaxDate $max 
  $latest = $max
}


