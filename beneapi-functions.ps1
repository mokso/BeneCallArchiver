
class BeneAPIAuth {
    [string] $APIUrl
    [string] $UserId
    [string] $UserName
    [string] $OrganizationalUnitId
    [hashtable] $Headers 
}

################### Functions ########################

##############################
#.SYNOPSIS
#Get BeneAPI enpoint address from Benemen discovery service
#
#.DESCRIPTION
#Get BeneAPI endpoin address from Benemen discovery service. Detailed documentations can be found
#from: https://doc.beneservices.com/beneapi-documentation/#service-discovery
#
#.EXAMPLE
#Get-BeneAPIEndpoint -UserName example.user@company.xyz
#
##############################

function Get-BeneAPIEndpoint {
    Param(
        #Username of the user
        [Parameter(Mandatory=$true)]
        [String] $UserName
    )

    $url = "https://discover.enreachvoice.com/api/user?user=$UserName"
    try {
        Write-verbose "Invoking GET [$url]"
        $data = Invoke-RestMethod -Uri $url
        if ($data) {
            # trim ending slash, as we might get apiEndpoint with it or without...
            return ($data.apiEndpoint -replace "/$","")
        }
    }
    catch {
        Write-Warning "Discovery request failed`n$_"
    }
}

##############################
#.SYNOPSIS
#Authenticate user to BeneAPI
#
#.DESCRIPTION
#Handle BeneAPI API-secretkey retrieval described here https://doc.beneservices.com/beneapi-documentation/#authentication-and-authorization.
#Returns object having all relevant info such as userId, orgID and BasicAuth authorization header.
#
##############################

function Get-BeneAPIAuth {
    Param(        
        #Credentials for Authenticating to api        
        [Parameter(Mandatory=$false)]
        [pscredential] $Credentials,

        #Is credential UserPassword or API secretkey. Defaults to UserPassword
        [Parameter(Mandatory=$false)]
        [ValidateSet("Password","SecretKey")]
        [string] $AuthType = "Password",

        #BeneAPI Url, if want to skip discovery
        [Parameter(Mandatory=$false)]
        [string] $ApiBaseUrl
        
    )

    if (-not $Credentials) {
        #get credential from envs
        # create credential from env-variables
        if (-not ($env:BENEAPI_USERNAME -and $env:BENEAPI_APISECRET)) {
            Write-Warning "Env-variables BENEAPI_USERNAME and BENEAPI_APISECRET must be set"
            return
        }
        $Credentials = New-Object System.Management.Automation.PSCredential ($env:BENEAPI_USERNAME, (ConvertTo-SecureString $env:BENEAPI_APISECRET -AsPlainText -Force))
        $AuthType = "SecretKey"
    }

    if (-not $ApiBaseUrl) {
        $ApiBaseUrl = Get-BeneAPIEndpoint -UserName $Credentials.UserName
    }
    if (-not $ApiBaseUrl) {
        Write-Warning "API url discoovery failed"
        return
    }

    $ApiInfo = [BeneAPIAuth]::new()    
    
    $ApiInfo.Headers = @{
        "Accept" = "application/json"
        "Content-Type" = "application/json"
    }
    $ApiInfo.APIUrl = $ApiBaseUrl
    $ApiInfo.UserName = $Credentials.UserName

    if ($AuthType -eq "Password") {
        # Retrieve API secretkey using user-password
        $url = "$ApiBaseUrl/authuser/$($Credentials.UserName)/"
    
        $postData = @{
            UserName = $Credentials.UserName
            Password = $Credentials.GetNetworkCredential().Password
        } | Convertto-json -Compress
    
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $postData -Headers $ApiInfo.Headers
        Write-Verbose ($response | ConvertTo-Json)
        $secretKey = $response.SecretKey
    }
    else {
        # API secretkey already provided
        $secretKey = $Credentials.GetNetworkCredential().Password
    }

    if ($secretKey) {
        # generate HTTP Basic Auth header for easier use later
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Credentials.UserName,$secretKey)))

        $ApiInfo.Headers["Authorization"] = "Basic $base64AuthInfo"

        if (-not $ApiInfo.UserId) {
            $user = GetBeneUser -ApiInfo $ApiInfo -UserId "me"
            $ApiInfo.UserId = $user.Id
            $ApiInfo.OrganizationalUnitId = $user.OrganizationID

        }
        return $ApiInfo
    }
}

##############################
#.SYNOPSIS
#Get USer from BeneAPI
#
#.DESCRIPTION
#Get User from BeneAPI 
#Returns object having all relevant info such as userId, orgID and BasicAuth authorization header.
#
##############################

function GetBeneUser {
    Param (
        #ApiInfo object
        [Parameter(Mandatory=$true)]
        [BeneAPIAuth] $ApiInfo,
        #UserId to get, you can use 'me' as userid if targeting self
        [string] $UserId = "me"
    )
    try {
        $url = "$($ApiInfo.APIUrl)/users/$UserId"
        Write-Verbose "Invoking GET $url"
        return Invoke-RestMethod -Uri $url -Method Get -Headers $ApiInfo.Headers        
    }
    catch {
        Write-Warning "API call failed`n$_"
    }    
}


function Get-BeneUserCalls {
    Param(
        #ApiInfo object
        [Parameter(Mandatory=$true)]
        [BeneAPIAuth] $ApiInfo,
        
        #UserId of user, whose calls should be set. If not give, user username of ApiInfo object will be used
        [Parameter(Mandatory=$false)]
        [string] $UserId,

        #Start time for searching calls
        [Parameter(Mandatory=$false)]
        [datetime] $TimeFrom,

        #End time for searching calls
        [Parameter(Mandatory=$false)]
        [datetime] $TimeTo
    )

    if (-not $UserId){
        $UserId = $ApiInfo.UserId
    }

    if (-not $TimeFrom) {
        $TimeFrom = (Get-Date).Date
    }

    if (-not $TimeTo) {
        $TimeTo = Get-Date
    }

    $TimeFromString = $TimeFrom.ToUniversalTime().ToString("yyyy-MM-dd+HH':'mm':'ss")
    $TimeToString = $TimeTo.ToUniversalTime().ToString("yyyy-MM-dd+HH':'mm':'ss")

    $url = "$($ApiInfo.APIUrl)/calls/?StartTime=$TimeFromString&EndTime=$TimeToString&UserIDs=$UserId"
    try {
        Write-Verbose "Invoking GET $url"
        return (Invoke-RestMethod -Uri $url -Method Get -Headers $ApiInfo.Headers)
    }
    catch {
        Write-Warning "Error while invoking BeneAPI`n$_"
    }
}

function Get-BeneUserCallRecording {
    Param(
        #ApiInfo object
        [Parameter(Mandatory=$true)]
        [BeneAPIAuth] $ApiInfo,
        
        #RecordingId
        [Parameter(Mandatory=$true)]
        [String] $RecordingId,

        #Path to file where recording should be downlaoded in mp3-format
        [Parameter(Mandatory=$true)]
        [String] $Path    
    )

    try {
        $url = "$($ApiInfo.APIUrl)/calls/recordings/$RecordingId"
        Write-Verbose "Invoking GET $url"
        $recInfo = Invoke-RestMethod -Uri $url -Method Get -Headers $ApiInfo.Headers

        if ($recInfo.URL) {
            # ensure folder exists
            $targetFolder = Split-Path $Path
            if (-not (Test-Path $targetFolder)) {
                New-Item $targetFolder -ItemType Directory
            }
            #Save file to target path
            
            $url = "$($ApiInfo.APIUrl)/$($recInfo.URL)"
            Write-Verbose "Invoking GET $url"
            Start-BitsTransfer $url -Destination $Path 
        }
    }
    catch {
        Write-Warning "Error while invoking BeneAPI`n$_"
    }
    
}

