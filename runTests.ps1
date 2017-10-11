#Set-PSDebug -trace 2
# Script that tests Docker on Windows functionality
Param(
    [string]$isDebug='no' 
)

#$ErrorActionPreference = "Stop"
$WORK_PATH = Split-Path -parent $MyInvocation.MyCommand.Definition
$CONFIGS_PATH = $WORK_PATH + "\configs\"
$BINDMOUNT_PATH = $WORK_PATH + "\test\"
$CONTAINER_NAME = "container1"
$BUILD_CONTAINER_IMAGE_NAME = "containervol1"
$CONTAINER_IMAGE = "nginx"
$CONTAINER_PORT = 80
$NODE_PORT = 8080
$VOLUME_NAME = "vol1"
$NETWORK_NAME = "net1"
$HOST_IP = "10.7.1.12"
$MINIMUM_PROCESS = "vmmem"
    
Import-Module "$WORK_PATH\DockerUtils"

class WorkingSet
{
    [ValidateNotNullOrEmpty()][int]$Total_Workingset
    [ValidateNotNullOrEmpty()][int]$Private_Workingset
    [ValidateNotNullOrEmpty()][int]$Shared_Workingset
    [ValidateNotNullOrEmpty()][int]$CommitSize
}

class DockerTestsStatus
{
    [ValidateNotNullOrEmpty()][string]$PullImageTest
    [ValidateNotNullOrEmpty()][string]$CreateVolumeTest
    [ValidateNotNullOrEmpty()][string]$BuildContainerTest
    [ValidateNotNullOrEmpty()][string]$CreateNetworkTest
    [ValidateNotNullOrEmpty()][string]$ConnectNetworkTest
    [ValidateNotNullOrEmpty()][string]$HTTPGetTest
    [ValidateNotNullOrEmpty()][string]$CreateContainerTest
    [ValidateNotNullOrEmpty()][string]$StartContainerTest
    [ValidateNotNullOrEmpty()][string]$ExecProcessInContainerTest
    [ValidateNotNullOrEmpty()][string]$RestartContainerTest
    [ValidateNotNullOrEmpty()][string]$StopContainerTest
    [ValidateNotNullOrEmpty()][string]$RunContainerTest
    [ValidateNotNullOrEmpty()][string]$RemoveContainerTest
    [ValidateNotNullOrEmpty()][string]$RemoveImageTest
    [ValidateNotNullOrEmpty()][string]$SharedVolumeTest
}

class DockerTestsTimer
{
    [ValidateNotNullOrEmpty()][int]$PullImageTime
    [ValidateNotNullOrEmpty()][int]$CreateVolumeTime
    [ValidateNotNullOrEmpty()][int]$BuildContainerTime
    [ValidateNotNullOrEmpty()][int]$CreateNetworkTime
    [ValidateNotNullOrEmpty()][int]$ConnectNetworkTime
    [ValidateNotNullOrEmpty()][int]$HTTPGetTime
    [ValidateNotNullOrEmpty()][int]$CreateContainerTime
    [ValidateNotNullOrEmpty()][int]$StartContainerTime
    [ValidateNotNullOrEmpty()][int]$ExecProcessInContainerTime
    [ValidateNotNullOrEmpty()][int]$RestartContainerTime
    [ValidateNotNullOrEmpty()][int]$StopContainerTime
    [ValidateNotNullOrEmpty()][int]$RunContainerTime
    [ValidateNotNullOrEmpty()][int]$RemoveContainerTime
    [ValidateNotNullOrEmpty()][int]$RemoveImageTime
}

function Create-Container {
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

    #Start-ExternalCommand -ScriptBlock { docker pull $containerImage } `
    #-ErrorMessage "`nFailed to pull docker image`n"

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

    $exec = Start-ExternalCommand -ScriptBlock { docker create $params } `
    -ErrorMessage "`nFailed to create container with $LastExitCode`n"

    if ($exec[0] -eq '0') {
        $TestsStatus.CreateContainerTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Container created SUCCESSFULLY"
    }

    $TestsTimers.CreateContainerTime = $exec[1]
}

function Start-Container {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    $exec = Start-ExternalCommand -ScriptBlock { docker start $containerName } `
    -ErrorMessage "`nFailed to start container with $LastExitCode`n"

    if ($exec[0] -eq '0') {
        $TestsStatus.StartContainerTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Container started SUCCESSFULLY"
    }

    $TestsTimers.StartContainerTime = $exec[1]
}

function Exec-Command {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    # Check if a command can be SUCCESSFULLY run in a container
    $exec = Start-ExternalCommand -ScriptBlock { docker exec $containerName ls } `
    -ErrorMessage "`nFailed to exec command with $LastExitCode`n"

    if ($exec[0] -eq '0') {
        $TestsStatus.ExecProcessInContainerTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Exec runned SUCCESSFULLY"
    }

    $TestsTimers.ExecProcessInContainerTime = $exec[1]
}

function Stop-Container {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    $exec = Start-ExternalCommand -ScriptBlock { docker stop $containerName } `
    -ErrorMessage "`nFailed to stop container with $LastExitCode`n"

    if ($exec[0] -eq '0') {
        $TestsStatus.StopContainerTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Container stopped SUCCESSFULLY"
    }

    $TestsTimers.StopContainerTime = $exec[1]
}

function Remove-Container {
    Param(
        [string]$containerName
    )

    $exec = Start-ExternalCommand -ScriptBlock { docker rm $containerName } `
    -ErrorMessage "`nFailed to remove container with $LastExitCode`n"

    if ($exec[0] -eq '0') {
        $TestsStatus.RemoveContainerTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Container removed SUCCESSFULLY"
    }

    $TestsTimers.RemoveContainerTime = $exec[1]
}

function Remove-Image {
    Param(
        [string]$containerImage
    )

    $exec = Start-ExternalCommand -ScriptBlock { docker rmi $containerImage } `
    -ErrorMessage "`nFailed to remove image with $LastExitCode`n"

    if ($exec[0] -eq '0') {
        $TestsStatus.RemoveImageTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Image removed SUCCESSFULLY"
    }

    $TestsTimers.RemoveImageTime = $exec[1]
}

function New-Image {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$imageName
    )

    $exec = Start-ExternalCommand -ScriptBlock { docker pull $imageName } `
    -ErrorMessage "`nFailed to pull docker image with $LastExitCode`n"

    if ($exec[0] -eq '0') {
        $TestsStatus.PullImageTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Image pulled SUCCESSFULLY"
    }

    $TestsTimers.PullImageTime = $exec[1]
}

function New-Volume {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$volumeName
    )

    $exec = Start-ExternalCommand -ScriptBlock { docker volume create $volumeName } `
    -ErrorMessage "`nFailed to create docker volume with $LastExitCode`n"

    if ($exec[0] -eq 0) {
        $TestsStatus.CreateVolumeTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Volume created SUCCESSFULLY"
    }

    $TestsTimers.CreateVolumeTime = $exec[1]
}

function New-Network {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$networkName
    )

    # driver type is 'nat', bridge equivalent for Linux
    $exec = Start-ExternalCommand -ScriptBlock { docker network create -d nat $networkName } `
    -ErrorMessage "`nFailed to create network with $LastExitCode`n"

    if ($exec[0] -eq 0) {
        $TestsStatus.CreateNetworkTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Network created SUCCESSFULLY"
    }

    $TestsTimers.CreateNetworkTime = $exec[1]
}

function Get-HTTPGet {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$host_ip
    )

    $address = 'http://' + $host_ip + ':8080'
    $stopwatch=[System.Diagnostics.Stopwatch]::startNew()
    $res = Invoke-WebRequest -Uri $address
    $stopwatch.Stop()
    $exectime = $stopwatch.ElapsedMilliseconds

    if (!$res) {
        TestsStatus.HTTPGetTest = "FAILED"
    } else {
        Write-DebugMessage $isDebug -Message "Container responded to HTTP GET SUCCESSFULLY"
        #Write-Output "`nExecuting: HTTPGet`t`tPASSED  elpased time:`t$exectime ms`n" >> tests.log
        $TestsStatus.HTTPGetTest = "PASSED"
        $TestsTimers.HTTPGetTime = $exectime
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
    -ErrorMessage "`nCould not get attributes of $elementType $elementName"

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
        $TestsStatus.SharedVolumeTest = "FAILED"
        
    } else {
        Write-DebugMessage $isDebug -Message "Container shared volume accessed SUCCESSFULLY"
        $TestsStatus.SharedVolumeTest = "PASSED"
    }
}

function Connect-Network {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$networkName,
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    $exec = Start-ExternalCommand -ScriptBlock { docker network connect $networkName $containerName } `
    -ErrorMessage "`nFailed to connect network to container with $LastExitCode`n"

    if ($exec[0] -eq 0) {
        $TestsStatus.ConnectNetworkTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Network connected SUCCESSFULLY"
    }

    $TestsTimers.ConnectNetworkTime = $exec[1]
}

function Clear-Environment {
    # Delete existing containers, volumes or images if any
    if($(docker ps -a -q).count -ne 0) {
        $ignoredResult = docker stop $(docker ps -a -q)
        $ignoredResult = docker rm $(docker ps -a -q)  
    }

    if($(docker volume list -q).count -ne 0) {
        $ignoredResult = docker volume rm $(docker volume list -q)
    }

    if ($(docker images -a -q).count -ne 0) {
        $ignoredResult = docker rmi -f (docker images -a -q)
    }

    $ignoredResult = docker network prune --force

    Write-DebugMessage $isDebug -Message "Cleanup SUCCSESSFULL"
}

function Test-Restart {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )
    # Restart container and see if all the functionalities
    # are available
    $exec = Start-ExternalCommand -ScriptBlock { docker restart $containerName } `
    -ErrorMessage "`nFailed to restart container with $LastExitCode`n"

    if ($exec[0] -eq 0) {
        $TestsStatus.RestartContainerTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Restart container tests ran SUCCESSFULLY"
    }

    $TestsTimers.RestartContainerTime = $exec[1]
}

function Test-Building {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$containerImage,
        [Parameter(Mandatory=$true)]
        [string]$configPath,
        [Parameter(Mandatory=$true)]
        [string]$imageName
    )

    (Get-Content "$configPath\Dockerfile").replace('image', $containerImage) `
    | Set-Content "$configPath\Dockerfile"

    $exec = Start-ExternalCommand -ScriptBlock { docker build -f "$configPath\Dockerfile" -t $imageName . } `
    -ErrorMessage "`nFailed to build docker image with $LastExitCode`n"

    if ($exec[0] -eq 0) {
        $TestsStatus.BuildContainerTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Container built SUCCESSFULLY"
    }

    $TestsTimers.BuildContainerTime = $exec[1]
}

function Start-BuiltContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$imageName,
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$bindMount
    )

    $exec = Start-ExternalCommand -ScriptBlock { docker run --name $containerName -d -p 8080:80 -v "$bindMount`:/data" $imageName } `
    -ErrorMessage "`nFailed to run built docker image with $LastExitCode`n"
}

function ProcessWorkingSetInfoById {
    param
    ([int]$processId)

    # The memory performance counter mapping between what''s shown in the Task Manager and those Powershell APIs for getting them
    # are super confusing. After many tries, I came out with the following mapping that matches with Taskmgr numbers on Windows 10

    $obj = Get-WmiObject -class Win32_PerfFormattedData_PerfProc_Process | where{$_.idprocess -eq $processId} 

    $ws = [WorkingSet]@{
                        Total_Workingset = $obj.workingSet / 1kb
                        Private_Workingset = $obj.workingSetPrivate / 1kb
                        Shared_Workingset = ($obj.workingSet - $obj.workingSetPrivate) / 1kb
                        CommitSize = $obj.PrivateBytes / 1kb }
    return $ws
}

function Test-Runner {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$volumeName,
        [Parameter(Mandatory=$true)]
        [string]$imageName,
        [Parameter(Mandatory=$true)]
        [string]$networkName,
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$configPath,
        [Parameter(Mandatory=$true)]
        [string]$bindMountPath,
        [Parameter(Mandatory=$true)]
        [string]$builtContainerImageName,
        [Parameter(Mandatory=$true)]
        [string]$host_ip,
        [Parameter(Mandatory=$true)]
        [int]$nodePort,
        [Parameter(Mandatory=$true)]
        [int]$containerPort
    )

    $TestsTimers = [DockerTestsTimer]@{
                    PullImageTime = 0
                    CreateVolumeTime = 0
                    BuildContainerTime = 0
                    CreateNetworkTime = 0
                    ConnectNetworkTime = 0
                    HTTPGetTime = 0
                    CreateContainerTime = 0
                    StartContainerTime = 0
                    ExecProcessInContainerTime = 0
                    RestartContainerTime = 0
                    StopContainerTime = 0
                    RunContainerTime = 0
                    RemoveContainerTime = 0
                    RemoveImageTime = 0
                    }

    $TestsStatus = [DockerTestsStatus]@{
                    PullImageTest = "FAILED"
                    CreateVolumeTest = "FAILED"
                    BuildContainerTest = "FAILED"
                    CreateNetworkTest = "FAILED"
                    ConnectNetworkTest = "FAILED"
                    HTTPGetTest = "FAILED"
                    CreateContainerTest = "FAILED"
                    StartContainerTest = "FAILED"
                    ExecProcessInContainerTest = "FAILED"
                    RestartContainerTest = "FAILED"
                    StopContainerTest = "FAILED"
                    RunContainerTest = "FAILED"
                    RemoveContainerTest = "FAILED"
                    RemoveImageTest = "FAILED"
                    SharedVolumeTest = "FAILED"
                    }


    Write-Output "`n================================================================" >> tests.log
    Write-Output "Starting tests" >> tests.log
    Write-Output "================================================================" >> tests.log

    New-Image $imageName

    New-Volume $volumeName

    New-Network $networkName

    Test-Building $containerName $imageName $configPath $builtContainerImageName
    #Start-BuiltContainer $builtContainerImageName $containerName $bindMountPath

    # windows does not support connecting a running container to a network
    $ignoredResult =  docker stop $containerName
    Connect-Network $networkName $containerName

    Start-BuiltContainer $builtContainerImageName $containerName $bindMountPath
    Get-SharedVolume $containerName

    $ignoredResult = docker stop $containerName
    $ignoredResult = docker rm $containerName

    $ignoredResult = Create-Container -containerName `
    $containerName -containerImage $imageName `
    -exposePorts -nodePort $nodePort -containerPort $containerPort `

    Start-Container $containerName

    Exec-Command $containerName
    Test-Restart $containerName

    $newProcess = Get-Process vmmem
    $workinginfo = ProcessWorkingSetInfoById $newProcess.id

    $UVM = Get-ComputeProcess 

    # get the OS memory usage from the guest os
    $memoryUsedByUVMOS=hcsdiag exec -uvm $UVM.id free
    Get-HTTPGet $host_ip

    Stop-Container $containerName
    Remove-Container $containerName
    Remove-Image $imageName



    #$created = Get-Attribute container $containerName Created
    #Write-Output $created

    Write-Output "----------------------------------------------------------------" >> tests.log
    Write-Output " Test results for the tests" >> tests.log
    Write-Output "----------------------------------------------------------------" >> tests.log
    $TestsStatus | Format-Table >> tests.log

    Write-Output "----------------------------------------------------------------" >> tests.log
    Write-Output " Timer results for the tests in ms" >> tests.log
    Write-Output "----------------------------------------------------------------" >> tests.log
    $TestsTimers | Format-Table >> tests.log

    Clear-Environment

    Write-Output "================================================================" >> tests.log
    Write-Output "Tests PASSED" >> tests.log
    Write-Output "================================================================" >> tests.log
}

$env:PATH = "C:\Users\dan\go\src\github.com\docker\docker\bundles\;" + $env:PATH
# execution starts here

$dockerVersion = docker version
#Write-Output $dockerVersion 
$dockerVersion > tests.log
"`n`n" >> tests.log

Clear-Environment

Test-Runner $VOLUME_NAME $CONTAINER_IMAGE $NETWORK_NAME $CONTAINER_NAME $CONFIGS_PATH $BINDMOUNT_PATH $BUILD_CONTAINER_IMAGE_NAME $HOST_IP $NODE_PORT $CONTAINER_PORT

Clear-Environment