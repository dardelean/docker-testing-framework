# Script that tests Docker on Windows functionality
Param(
    [string]$isDebug='no' 
)

$ErrorActionPreference = "Stop"
$WORK_PATH = Split-Path -parent $MyInvocation.MyCommand.Definition
$CONFIGS_PATH = $WORK_PATH + "\configs\"
$CONTAINER_NAME = "container1"
$CONTAINER_IMAGE = "nginx"
$CONTAINER_PORT = 80
$NODE_PORT = 8080
$VOLUME_NAME = "vol1"
$NETWORK_NAME = "net1"

Import-Module "$WORK_PATH\DockerUtils"

function New-Container {
    # Container can be created with or without volumes or ports exposed
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$containerImage,
        [switch]$exposePorts,
        [int]$nodePort,
        [int]$containerPort,
        [switch]$attachVolume,
        [string]$volumeName,
        [switch]$bindMount,
        [string]$mountPath
    )

    Start-ExternalCommand -ScriptBlock { docker pull $containerImage } `
    -ErrorMessage "`nFailed to pull docker image`n"

    $params = @("--name", $containerName, $containerImage)

    if($exposePorts) {
        $params = ("-p", "$nodePort`:$containerPort") + $params
    }

    if($attachVolume) {
        $params = ("-v", "$volumeName`:/data") + $params
    }

    if($bindMount) {
        $params = ("-v", "$mountPath`:/data") + $params
    }

    Start-ExternalCommand -ScriptBlock { docker run -d $params } `
    -ErrorMessage "`nFailed to create container`n"

    Write-DebugMessage $isDebug -Message "Container created SUCCSESSFULLY"

    $containerID = docker container inspect $containerName --format "{{.ID}}"
    return $containerID
}

function New-Volume {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$volumeName
    )

    Start-ExternalCommand -ScriptBlock { docker volume create $volumeName } `
    -ErrorMessage "`nFailed to create docker volume with $LastExitCode`n"

    Write-DebugMessage $isDebug -Message "Volume created SUCCSESSFULLY"

    # docker does not asign an ID to volume so cannot return one
}

function New-Image {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$imageName
    )

    Start-ExternalCommand -ScriptBlock { docker pull $imageName } `
    -ErrorMessage "`nFailed to pull docker image with $LastExitCode`n"

    Write-DebugMessage $isDebug -Message "Image pulled SUCCSESSFULLY"

    $imageID = docker images $imageName --format "{{.ID}}"
    return $imageID
}

function New-Network {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$networkName
    )

    Start-ExternalCommand -ScriptBlock { docker network create $networkName } `
    -ErrorMessage "`nFailed to create network with $LastExitCode`n"

    Write-DebugMessage $isDebug -Message "Network created SUCCSESSFULLY"

    $networkID = docker network inspect $networkName --format "{{.ID}}"
    return $networkID
}

function Get-HTTPGet {
    # Check if the container responds on 8080
    $res = Invoke-WebRequest -Uri http://localhost:8080
    if ($res.StatusCode -gt 400) {
        throw "`nContainer did NOT respond to HTTP GET`n"
        exit
    } else {
        Write-DebugMessage $isDebug -Message "Container responded to HTTP GET SUCCSESSFULLY"
    }
}

function Get-Attribute {
    # get the attributes of a container, network, volume
        Param
    (
        [ValidateSet("container", "network", "volume", "image")]
        [string]$elementType,
        [string]$elementName,
        [string]$attribute
    )

    $attribute = Start-ExternalCommand -ScriptBlock { docker $elementType inspect `
    $elementName --format "{{.$attribute}}"} `
    -ErrorMessage "`nCould not get attributes of $elementType $elementName`n"

    return $attribute
}

function Get-SharedVolume {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )
    # Check if data in the shared volume is accessible 
    # from containers mountpoint
    $volumeData = docker exec $containerName ls /data
    if(!$volumeData) {
        throw "`nCannot access shared volume`n"
        
    } else {
        Write-DebugMessage $isDebug -Message "Container shared volume accessed SUCCSESSFULLY"
    }
}

function Get-Command {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    # Check if a command can be succsessfully run in a container
    Start-ExternalCommand -ScriptBlock { docker exec $containerName ls } `
    -ErrorMessage "`nFailed to exec command with $LastExitCode`n"

    Write-DebugMessage $isDebug -Message "Exec runned SUCCSESSFULLY"
}

function Connect-Network {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$networkName,
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    New-Network $networkName

    Start-ExternalCommand -ScriptBlock { docker network connect $networkName $containerName } `
    -ErrorMessage "`nFailed to connect network to container with $LastExitCode`n "

    Write-DebugMessage $isDebug -Message "Network conneted SUCCSESSFULLY"
}

function Clear-Environment {
    # Delete existing containers, volumes or images if any
    if($(docker ps -a -q).count -ne 0) {
        docker stop $(docker ps -a -q)
        docker rm $(docker ps -a -q)  
    }

    if($(docker volume list -q).count -ne 0) {
        docker volume rm $(docker volume list -q)
    }

    if ($(docker images -a -q).count -ne 0) {
        docker rmi -f (docker images -a -q)
    }

    docker network prune --force
}

function Test-Restart {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )
    # Restart container and see if all the functionalities
    # are available
    Start-ExternalCommand -ScriptBlock { docker restart $containerName } `
    -ErrorMessage "`nFailed to restart container`n"

    Get-HTTPGet
    #Get-SharedVolume $containerName

    Write-DebugMessage $isDebug -Message "Restart container tests ran SUCCSESSFULLY"
}

function Test-Building {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$containerImage,
        [Parameter(Mandatory=$true)]
        [string]$configPath
    )

    (Get-Content "$configPath\Dockerfile").replace('image', $containerImage) `
    | Set-Content "$configPath\Dockerfile"

    Start-ExternalCommand -ScriptBlock { docker build -f "$configPath\Dockerfile" -t testingimage . } `
    -ErrorMessage "`nFailed to build docker image`n"

    docker stop $containerName
    docker rm $containerName

    Write-DebugMessage $isDebug -Message "Container built SUCCSESSFULLY"
}

function Test-BasicFunctionality {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$volumeName,
        [Parameter(Mandatory=$true)]
        [string]$imageName,
        [Parameter(Mandatory=$true)]
        [string]$networkName,
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )
    Write-Output "`n============Starting functionality tests===============`n"
    
    # Run the functionalities tests, no containers yet
    New-Volume $volumeName
    New-Image $imageName
    New-Network $networkName

    Clear-Environment

    Write-Output "`n============Functionality tests PASSED===============`n"
}

function Test-BasicContainers {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$containerImage,
        [Parameter(Mandatory=$true)]
        [int]$nodePort,
        [Parameter(Mandatory=$true)]
        [int]$containerPort,
        [Parameter(Mandatory=$true)]
        [string]$configPath,
        [Parameter(Mandatory=$true)]
        [string]$networkName
    )

    Write-Output "`n============Starting create container tests===============`n"

    Test-Building $containerName $containerImage $configPath
    # Create container and test all the functionalities on it

    New-Container -containerName $containerName -containerImage $containerImage `
    -exposePorts -nodePort $nodePort -containerPort $containerPort `
    -bindMount -mountPath $configPath

    # Execute functionality tests
    Get-Command $containerName
    Get-HTTPGet
    #Get-SharedVolume $containerName
    Test-Restart $containerName
    Connect-Network $networkName $containerName

    #$created = Get-Attribute container $containerName Created
    #Write-Output $created

    Write-Output "`n============Create container tests PASSED===============`n"

    # Cleanup container
    Clear-Environment
}

# execution starts here
cls

$dockerVersion = docker version
Write-Output $dockerVersion

Clear-Environment

Test-BasicFunctionality $VOLUME_NAME $CONTAINER_IMAGE $NETWORK_NAME $CONTAINER_NAME
Test-BasicContainers $CONTAINER_NAME $CONTAINER_IMAGE $NODE_PORT $CONTAINER_PORT $CONFIGS_PATH $NETWORK_NAME

Write-Output "`n============All tests PASSED===============`n"