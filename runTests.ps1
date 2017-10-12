#Set-PSDebug -trace 2
# Script that tests Docker on Windows functionality
Param(
    [string]$isDebug='no' 
)

#$ErrorActionPreference = "Stop"
$WORK_PATH = Split-Path -parent $MyInvocation.MyCommand.Definition
$CONFIGS_PATH = $WORK_PATH + "\configs\Dockerfile"
$BINDMOUNT_PATH = $WORK_PATH + "\test:/test"
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
    [ValidateNotNullOrEmpty()][string]$StartBuiltContainerTest
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
    [ValidateNotNullOrEmpty()][int]$StartBuiltContainerTime
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
    [ValidateNotNullOrEmpty()][int]$SharedVolumeTime
}

function Test-CreateContainer {
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
        [string]$command,
        [string]$time,
        [string]$test
    )

    $exec = Start-ExternalCommand -ScriptBlock { Invoke-Expression $command } `
    -ErrorMessage "`nFailed test with $LastExitCode`n"

    if ($time -ne 'none') {
        if ($exec[0] -eq 0) {
            $TestsStatus.$test = "PASSED"
            Write-DebugMessage $isDebug -Message "$test ran SUCCESSFULLY"
        }
        $TestsTimers.$time = $exec[1]
    }
}

function Test-Executor {
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
                    StartBuiltContainerTime = 0
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
                    SharedVolumeTime = 0
                    }

    $TestsStatus = [DockerTestsStatus]@{
                    PullImageTest = "FAILED"
                    CreateVolumeTest = "FAILED"
                    BuildContainerTest = "FAILED"
                    CreateNetworkTest = "FAILED"
                    StartBuiltContainerTest = "FAILED"
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

    (Get-Content "$configPath").replace('image', $imageName) `
    | Set-Content "$configPath"

    Test-Runner "docker pull $imageName"  "PullImageTime"  "PullImageTest"
    Test-Runner "docker volume create $volumeName"  "CreateVolumeTime" "CreateVolumeTest"
    Test-Runner "docker network create -d nat $networkName" "CreateNetworkTime" "CreateNetworkTest"
    Test-Runner "docker build -f $configPath -t $imageName ." "BuildContainerTime" "BuildContainerTest"
    Test-Runner "docker network connect $networkName $containerName" "ConnectNetworkTime" "ConnectNetworkTest"
    Test-Runner "docker run --name $containerName -d -p 8080:80 -v $bindMountPath $imageName" "StartBuiltContainerTime" "StartBuiltContainerTest"
    Test-Runner "docker exec $containerName ls /test" "SharedVolumeTime" "SharedVolumeTest"

    $ignoredResult = docker stop $containerName
    $ignoredResult = docker rm $containerName

    $ignoredResult = Test-CreateContainer -containerName `
    $containerName -containerImage $imageName `
    -exposePorts -nodePort $nodePort -containerPort $containerPort `

    Test-Runner "docker start $containerName" "StartContainerTime" "StartContainerTest"
    Test-Runner "docker exec $containerName ls" "ExecProcessInContainerTime" "ExecProcessInContainerTest"
    Test-Runner "docker restart $containerName" "RestartContainerTime" "RestartContainerTest"

    $newProcess = Get-Process vmmem
    $workinginfo = ProcessWorkingSetInfoById $newProcess.id

    $UVM = Get-ComputeProcess
    $memoryUsedByUVMOS=hcsdiag exec -uvm $UVM.id free

    Get-HTTPGet $host_ip

    Test-Runner "docker stop $containerName" "StopContainerTime" "StopContainerTest"
    Test-Runner "docker rm $containerName" "RemoveContainerTime" "RemoveContainerTest"
    Test-Runner "docker rmi $imageName" "RemoveImageTime" "RemoveImageTest"

    #left functions: Test-CreateContainer, Get-HTTPGet

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

Test-Executor $VOLUME_NAME $CONTAINER_IMAGE $NETWORK_NAME $CONTAINER_NAME $CONFIGS_PATH $BINDMOUNT_PATH $BUILD_CONTAINER_IMAGE_NAME $HOST_IP $NODE_PORT $CONTAINER_PORT

Clear-Environment