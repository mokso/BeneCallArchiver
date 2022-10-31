$requiredModules = "PSSQLite"


foreach ($moduleName in $requiredModules){
    $moduleExists = Get-Module -Name $moduleName -ListAvailable

    if (-not $moduleExists) {
        Write-host "Installing module $moduleName"
        Install-Module -Name $moduleName -Scope CurrentUser -Force
    }
}