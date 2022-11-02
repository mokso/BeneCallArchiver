function Get-Transciption {
    Param(
        [string] $mp3File
    )

    $workDir = "$PSScriptRoot\work"

    # ensure file exists
    if (-not (Test-Path $mp3File)) {
        Write-Warning "File not found [$mp3File]"
        return 
    }

    #convertto wav + split channels
    $left = Join-Path $workDir "left.wav"
    $right = Join-Path $workDir "right.wav"

    ffmpeg -hide_banner -y -i $mp3File -map_channel 0.0.0 $left -map_channel 0.0.1 $right


    $leftslices = Get-AudioSlices -File $left -Participant "A"
    $rightslices = Get-AudioSlices -File $right -Participant "B"

    $allSlices = ($rightslices + $leftslices) | Sort-Object  Start
    return $allSlices
}

function Get-AudioSlices {
    param (
        [string] $File, 
        [String] $Participant
    )

    #Detect silences with ffpeg, output to file
    $silenceFile = "$PSScriptRoot\work\silences-$((Get-ChildItem $File).BaseName).txt"
    Write-host "wirtingsilences to $silenceFile"
    ffmpeg -hide_banner -y -i $File -af silencedetect=noise=-30dB:d=2 -f null - 2> $silenceFile 
  

    <# reuslt will be something like this:
[silencedetect @ 00000000006291c0] silence_start: -0.208
[silencedetect @ 00000000006291c0] silence_end: 4.096 | silence_duration: 4.304
[silencedetect @ 00000000006291c0] silence_start: 7.216
[silencedetect @ 00000000006291c0] silence_end: 9.216 | silence_duration: 2
[silencedetect @ 00000000006291c0] silence_start: 11.312
[silencedetect @ 00000000006291c0] silence_end: 14.592 | silence_duration: 3.28    
    #>

    #analyze silence detection result and split to slices
    $slices = @() # gather here slices
    $start = 0
    $stop = 0

    foreach ($r in (get-content $silenceFile)) {   
        if ($r -match ".+ silence_start: ([\d\.]+).*"){
            $stop = $Matches[1]
            Write-host "Start $stop"
            $slices += [pscustomobject]@{
                Party = $Participant
                Start = [double] $start
                Length = $stop - $start
                Text = ""
            }
        }
        if ($r -match ".+ silence_end: ([\d\.]+).*"){
            $start = $Matches[1]
            Write-host "End $start"
        }
    }

    Write-host "Found $($slices.count) slices"

    #gather here all slices having succesful speech to text result
    $goodSlices = @()

    foreach ($s in $slices) {
        #Split wav-file with ffmpeg
        $outname = "$PSScriptRoot\work\$((Get-ChildItem $File).BaseName)_slice_$($s.Index).wav"
        ffmpeg -hide_banner -y -ss $s.Start -i $File -t $s.Length -c copy $outname 

        # Get Speech-to-text for this slice
        $stt = Get-STT -File $outname
        if ($stt.DisplayText) {
            $s.Text = $stt.DisplayText
            $goodSlices += $s
        }
    }
    return $goodSlices
}


function Get-STT {
    param (
        [string] $File,
        [string] $Language = "fi-FI"
    )
    $region = $env:AZURE_SPEECH_REGION
    
    $audioBytes = [System.IO.File]::ReadAllBytes($File)
    $url = "https://$region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=$Language&format=detailed"

    $headers = @{
        "Ocp-Apim-Subscription-Key" = $env:AZURE_SPEECH_KEY
    }

    $resultdetailed = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -ContentType "audio/wav" -Body $audioBytes
    return $resultdetailed
}

# $file = "C:\Users\mokso\OneDrive\BeneCallArchive\2022-11-02\ee27c673-c95a-ed11-b838-0050569e6df2.mp3"
# $result = Get-Transciption -mp3File $file
