<#
.SYNOPSIS
Builds and runs a Docker image.
.PARAMETER Compose
Runs docker-compose.
.PARAMETER Build
Builds a Docker image.
.PARAMETER Clean
Removes the image test and kills all containers based on that image.
.PARAMETER ComposeForDebug
Builds the image and runs docker-compose.
.PARAMETER StartDebugging
Finds the running container and starts the debugger inside of it.
.PARAMETER Environment
The enviorment to build for (Debug or Release), defaults to Debug
.EXAMPLE
C:\PS> .\dockerTask.ps1 -Build
Build a Docker image named test
#>

Param(
    [Parameter(Mandatory=$True,ParameterSetName="Compose")]
    [switch]$Compose,
    [Parameter(Mandatory=$True,ParameterSetName="ComposeForDebug")]
    [switch]$ComposeForDebug,
    [Parameter(Mandatory=$True,ParameterSetName="Build")]
    [switch]$Build,
    [Parameter(Mandatory=$True,ParameterSetName="Clean")]
    [switch]$Clean,
    [parameter(ParameterSetName="Compose")]
    [Parameter(ParameterSetName="ComposeForDebug")]
    [parameter(ParameterSetName="Build")]
    [parameter(ParameterSetName="Clean")]
    [ValidateNotNullOrEmpty()]
    [String]$Environment = "Debug"
)

# Kills all running containers of an image and then removes them.
function CleanAll () {
    $composeFileName = "docker-compose.yml"
    if ($Environment -ne "Release") {
        $composeFileName = "docker-compose.$Environment.yml"
    }

    if (Test-Path $composeFileName) {
        docker-compose -f "$composeFileName" down --rmi all

        $danglingImages = $(docker images -q --filter 'dangling=true')
        if (-not [String]::IsNullOrWhiteSpace($danglingImages)) {
            docker rmi -f $danglingImages
        }
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$composeFileName' does not exist." -Category InvalidArgument
    }
}

# Builds the Docker image.
function BuildImage () {
    $composeFileName = "docker-compose.yml"
    if ($Environment -ne "Release") {
        $composeFileName = "docker-compose.$Environment.yml"
    }

    if (Test-Path $composeFileName) {
        Write-Host "Building the project ($ENVIRONMENT)."

        docker-compose -f "$composeFileName" build
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$composeFileName' does not exist." -Category InvalidArgument
    }
}

# Runs docker-compose.
function Compose () {
    $composeFileName = "docker-compose.yml"
    if ($Environment -ne "Release") {
        $composeFileName = "docker-compose.$Environment.yml"
    }

    if (Test-Path $composeFileName) {
        Write-Host "Running compose file $composeFileName"
        docker-compose -f $composeFileName kill
        docker-compose -f $composeFileName up -d
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$composeFileName' does not exist." -Category InvalidArgument
    }
}

# Opens the remote site
function OpenSite () {
    Write-Host "Opening site" -NoNewline
    $status = 0

    #Check if the site is available
    while($status -ne 200) {
        try {
            $response = Invoke-WebRequest -Uri $url -Headers @{"Cache-Control"="no-cache";"Pragma"="no-cache"} -UseBasicParsing
            $status = [int]$response.StatusCode
        }
        catch [System.Net.WebException] { }
        if($status -ne 200) {
            Write-Host "." -NoNewline
            Start-Sleep 1
        }
    }

    Write-Host
    # Open the site.
    Start-Process $url
}

$Environment = $Environment.ToLowerInvariant()

# Call the correct function for the parameter that was used
if($Compose) {
    Compose
    OpenSite
}
elseif($ComposeForDebug) {
    BuildImage
    Compose
}
elseif($Build) {
    BuildImage
}
elseif ($Clean) {
    CleanAll
}