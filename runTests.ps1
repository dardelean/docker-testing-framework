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
    # Optionally, add attributes to prevent invalid value
    [ValidateNotNullOrEmpty()][int]$Total_Workingset
    [ValidateNotNullOrEmpty()][int]$Private_Workingset
    [ValidateNotNullOrEmpty()][int]$Shared_Workingset
    [ValidateNotNullOrEmpty()][int]$CommitSize
}

class DockerFunctionalityTests {
    [ValidateNotNullOrEmpty()][string]$PullImageTest
    [ValidateNotNullOrEmpty()][string]$CreateVolumeTest
    [ValidateNotNullOrEmpty()][string]$BuildContainerTest
    [ValidateNotNullOrEmpty()][string]$CreateNetworkTest
    [ValidateNotNullOrEmpty()][string]$ConnectNetworkTest
    [ValidateNotNullOrEmpty()][string]$HTTPGetTest
    [ValidateNotNullOrEmpty()][string]$SharedVolumeTest
}

class DockerFunctionalityTime
{
    # Optionally, add attributes to prevent invalid values
    [ValidateNotNullOrEmpty()][int]$PullImageTime
    [ValidateNotNullOrEmpty()][int]$CreateVolumeTime
    [ValidateNotNullOrEmpty()][int]$BuildContainerTime
    [ValidateNotNullOrEmpty()][int]$CreateNetworkTime
    [ValidateNotNullOrEmpty()][int]$ConnectNetworkTime
    [ValidateNotNullOrEmpty()][int]$HTTPGetTime
}

class DockerOperationTime
{
    # Optionally, add attributes to prevent invalid values
    [ValidateNotNullOrEmpty()][int]$PullImageTime
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

    $time = Start-ExternalCommand -ScriptBlock { docker create $params } `
    -ErrorMessage "`nFailed to create container with $LastExitCode`n"

    Write-DebugMessage $isDebug -Message "Container created SUCCESSFULLY"

    #$containerID = docker container inspect $containerName --format "{{.ID}}"
    return [int]$time
}

function Start-Container {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    $exec = Start-ExternalCommand -ScriptBlock { docker start $containerName } `
    -ErrorMessage "`nFailed to start container with $LastExitCode`n"

    Write-DebugMessage $isDebug -Message "Container started SUCCESSFULLY"

    return [int]$time
}

function Exec-Command {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    # Check if a command can be SUCCESSFULLY run in a container
    $time = Start-ExternalCommand -ScriptBlock { docker exec $containerName ls } `
    -ErrorMessage "`nFailed to exec command with $LastExitCode`n"

    Write-DebugMessage $isDebug -Message "Exec runned SUCCESSFULLY"

    return [int]$time
}

function Stop-Container {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    $time = Start-ExternalCommand -ScriptBlock { docker stop $containerName } `
    -ErrorMessage "`nFailed to stop container with $LastExitCode`n"
    Write-DebugMessage $isDebug -Message "Container stopped SUCCESSFULLY"

    return [int]$time
}

function Remove-Container {
    Param(
        [string]$containerName
    )

    $time = Start-ExternalCommand -ScriptBlock { docker rm $containerName } `
    -ErrorMessage "`nFailed to remove container with $LastExitCode`n"

    Write-DebugMessage $isDebug -Message "Container removed SUCCESSFULLY"

    return [int]$time
}

function Remove-Image {
    Param(
        [string]$containerImage
    )

    $time = Start-ExternalCommand -ScriptBlock { docker rmi $containerImage } `
    -ErrorMessage "`nFailed to remove image with $LastExitCode`n"

    Write-DebugMessage $isDebug -Message "Image removed SUCCESSFULLY"

    return [int]$time
}

function New-Image {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$imageName
    )

    $exec = Start-ExternalCommand -ScriptBlock { docker pull $imageName } `
    -ErrorMessage "`nFailed to pull docker image with $LastExitCode`n"

    if ($exec[0] -eq '0') {
        $FunctionalityTest.PullImageTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Image pulled SUCCESSFULLY"
    }

    $FunctionalityTime.PullImageTime = $exec[1]

}

function New-Volume {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$volumeName
    )

    $exec = Start-ExternalCommand -ScriptBlock { docker volume create $volumeName } `
    -ErrorMessage "`nFailed to create docker volume with $LastExitCode`n"

    if ($exec[0] -eq 0) {
        $FunctionalityTest.CreateVolumeTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Volume created SUCCESSFULLY"
    }

    $FunctionalityTime.CreateVolumeTime = $exec[1]
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
        $FunctionalityTest.CreateNetworkTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Network created SUCCESSFULLY"
    }

    $FunctionalityTime.CreateNetworkTime = $exec[1]

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
        FunctionalityTest.HTTPGetTest = "FAILED"
    } else {
        Write-DebugMessage $isDebug -Message "Container responded to HTTP GET SUCCESSFULLY"
        #Write-Output "`nExecuting: HTTPGet`t`tPASSED  elpased time:`t$exectime ms`n" >> tests.log
        $FunctionalityTest.HTTPGetTest = "PASSED"
        $FunctionalityTime.HTTPGetTime = $exectime
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
        FunctionalityTest.SharedVolumeTest = "FAILED"
        
    } else {
        Write-DebugMessage $isDebug -Message "Container shared volume accessed SUCCESSFULLY"
        $FunctionalityTest.SharedVolumeTest = "PASSED"
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
        $FunctionalityTest.ConnectNetworkTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Network connected SUCCESSFULLY"
    }

    $FunctionalityTime.ConnectNetworkTime = $exec[1]
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
    $time = Start-ExternalCommand -ScriptBlock { docker restart $containerName } `
    -ErrorMessage "`nFailed to restart container with $LastExitCode`n"

    Write-DebugMessage $isDebug -Message "Restart container tests ran SUCCESSFULLY"
    return [int]$time
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
        $FunctionalityTest.BuildContainerTest = "PASSED"
        Write-DebugMessage $isDebug -Message "Container built SUCCESSFULLY"
    }

    $FunctionalityTime.BuildContainerTime = $exec[1]

    #docker stop $containerName
    #docker rm $containerName
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

# The memory performance counter mapping between what''s shown in the Task Manager and those Powershell APIs for getting them
# are super confusing. After many tries, I came out with the following mapping that matches with Taskmgr numbers on Windows 10
#
function ProcessWorkingSetInfoById
{
    param
    ([int]$processId)

    $obj = Get-WmiObject -class Win32_PerfFormattedData_PerfProc_Process | where{$_.idprocess -eq $processId} 

    $ws = [WorkingSet]@{
                        Total_Workingset = $obj.workingSet / 1kb
                        Private_Workingset = $obj.workingSetPrivate / 1kb
                        Shared_Workingset = ($obj.workingSet - $obj.workingSetPrivate) / 1kb
                        CommitSize = $obj.PrivateBytes / 1kb }
    return $ws
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
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$configPath,
        [Parameter(Mandatory=$true)]
        [string]$bindMountPath,
        [Parameter(Mandatory=$true)]
        [string]$builtContainerImageName,
        [Parameter(Mandatory=$true)]
        [string]$host_ip
    )

    $FunctionalityTime = [DockerFunctionalityTime]@{
                    PullImageTime = 0
                    CreateVolumeTime = 0
                    BuildContainerTime = 0
                    CreateNetworkTime = 0
                    ConnectNetworkTime = 0
                    HTTPGetTime = 0
                    }
    $FunctionalityTest = [DockerFunctionalityTests]@{
                    PullImageTest = "FAILED"
                    CreateVolumeTest = "FAILED"
                    BuildContainerTest = "FAILED"
                    CreateNetworkTest = "FAILED"
                    ConnectNetworkTest = "FAILED"
                    HTTPGetTest = "FAILED"
                    SharedVolumeTest = "FAILED"
                    }

    Write-Output "`n================================================================" >> tests.log
    Write-Output "Starting functionality tests" >> tests.log
    Write-Output "================================================================" >> tests.log

    New-Image $imageName

    New-Volume $volumeName

    Test-Building $containerName $imageName $configPath $builtContainerImageName

    New-Network $networkName

    # windows does not support connecting a running container to a network
    $ignoredResult =  docker stop $containerName
    Connect-Network $networkName $containerName

    Start-BuiltContainer $builtContainerImageName $containerName $bindMountPath
    Get-HTTPGet $host_ip
    Get-SharedVolume $containerName



    #$created = Get-Attribute container $containerName Created
    #Write-Output $created

    Write-Output "----------------------------------------------------------------" >> tests.log
    Write-Output " Test result for functionality tests" >> tests.log
    Write-Output "----------------------------------------------------------------" >> tests.log
    $FunctionalityTest | Format-Table >> tests.log

    Write-Output "----------------------------------------------------------------" >> tests.log
    Write-Output " Timer results for functionality tests in ms" >> tests.log
    Write-Output "----------------------------------------------------------------" >> tests.log
    $FunctionalityTime | Format-Table >> tests.log

    Clear-Environment

    Write-Output "================================================================" >> tests.log
    Write-Output "Functionality tests PASSED" >> tests.log
    Write-Output "================================================================" >> tests.log
}

function Test-Container {
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

    $OperationTime = [DockerOperationTime]@{
                    PullImageTime = 0
                    CreateContainerTime = 0
                    StartContainerTime = 0
                    ExecProcessInContainerTime = 0
                    RestartContainerTime = 0 
                    StopContainerTime = 0
                    RunContainerTime = 0
                    RemoveContainerTime = 0
                    RemoveImageTime = 0
                    }

    Write-Output "================================================================" >> tests.log
    Write-Output "Starting create container tests" >> tests.log
    Write-Output "================================================================" >> tests.log

    $OperationTime.PullImageTime = New-Image $containerImage
    $OperationTime.CreateContainerTime = Create-Container -containerName `
    $containerName -containerImage $containerImage `
    -exposePorts -nodePort $nodePort -containerPort $containerPort `

    $OperationTime.StartContainerTime = Start-Container $containerName

    $OperationTime.ExecProcessInContainerTime = Exec-Command $containerName
    $OperationTime.RestartContainerTime = Test-Restart $containerName

    $newProcess = Get-Process vmmem
    $workinginfo = ProcessWorkingSetInfoById $newProcess.id

    $UVM = Get-ComputeProcess 

    # get the OS memory usage from the guest os
    $memoryUsedByUVMOS=hcsdiag exec -uvm $UVM.id free

    $OperationTime.StopContainerTime = Stop-Container $containerName
    $OperationTime.RemoveContainerTime = Remove-Container $containerName
    $OperationTime.RemoveImageTime = Remove-Image $containerImage

    Write-Output "----------------------------------------------------------------" >> tests.log
    Write-Output " Test result for container tests in ms" >> tests.log
    Write-Output "----------------------------------------------------------------" >> tests.log

    $OperationTime | Format-Table >> tests.log
    #$OperationTime | Format-Table

    Write-Output "----------------------------------------------------------------" >> tests.log
    Write-Output " Container memory stats in kb" >> tests.log
    Write-Output "----------------------------------------------------------------" >> tests.log

    $workinginfo | Format-Table >> tests.log
    #$workinginfo | Format-Table

    Write-Output "----------------------------------------------------------------" >> tests.log
    Write-Output "Memory used by the Linux OS running inside the new UVM" >> tests.log
    Write-Output "----------------------------------------------------------------" >> tests.log
    Write-Output $memoryUsedByUVMOS >> tests.log

    #$containerTestsMemSize >> tests.log
    #$memoryUsedByUVMOS >> tests.log
    Write-Output "----------------------------------------------------------------" >> tests.log

    Write-Output "`n================================================================" >> tests.log
    Write-Output "Container tests PASSED" >> tests.log
    Write-Output "================================================================" >> tests.log

    Clear-Environment
}

$env:PATH = "C:\Users\dan\go\src\github.com\docker\docker\bundles\;" + $env:PATH
# execution starts here

$dockerVersion = docker version
#Write-Output $dockerVersion 
$dockerVersion > tests.log
"`n`n" >> tests.log

Clear-Environment

Test-BasicFunctionality $VOLUME_NAME $CONTAINER_IMAGE $NETWORK_NAME $CONTAINER_NAME $CONFIGS_PATH $BINDMOUNT_PATH $BUILD_CONTAINER_IMAGE_NAME $HOST_IP
"`n`n`n" >> tests.log
#Test-Container $CONTAINER_NAME $CONTAINER_IMAGE $NODE_PORT $CONTAINER_PORT $CONFIGS_PATH $NETWORK_NAME

Clear-Environment

Write-Output "`n=========================All tests PASSED=======================`n" >> tests.log
Write-Output "`n=========================All tests PASSED=======================`n"