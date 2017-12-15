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
$MINIMUM_PROCESS = "vmmem"

Import-Module "$WORK_PATH\DockerUtils"

class WorkingSet
{
    [ValidateNotNullOrEmpty()][int]$Total_Workingset
    [ValidateNotNullOrEmpty()][int]$Private_Workingset
    [ValidateNotNullOrEmpty()][int]$Shared_Workingset
    [ValidateNotNullOrEmpty()][int]$CommitSize
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
        $test_status = "PASSED"
        $test_time = $exec[1]
        Write-DebugMessage $isDebug -Message "Container created SUCCESSFULLY"
    } else {
        $test_status = "FAILED"
        $test_time = 0
        Write-DebugMessage $isDebug -Message "$test ran FAILED"
    }

    $test_dict = @{TestName = "CreateContainerTest"; Status = $test_status; Time = $test_time}

    return $test_dict
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
        [string]$test
    )

    $exec = Start-ExternalCommand -ScriptBlock { Invoke-Expression $command } `
    -ErrorMessage "`nFailed test with $LastExitCode`n"

    if ($exec[0] -eq 0) {
        $test_status = "PASSED"
        $test_time = $exec[1]
        Write-DebugMessage $isDebug -Message "$test ran SUCCESSFULLY"
    } else {
        $test_status = "FAILED"
        $test_time = 0
        Write-DebugMessage $isDebug -Message "$test ran FAILED"
    }

    $test_dict = @{TestName = $test; Status = $test_status; Time = $test_time}

    return $test_dict
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
        [int]$nodePort,
        [Parameter(Mandatory=$true)]
        [int]$containerPort
    )

    Write-Output "`n================================================================" >> tests.log
    Write-Output "Starting tests" >> tests.log
    Write-Output "================================================================" >> tests.log

    (Get-Content "$configPath").replace('image', $imageName) `
    | Set-Content "$configPath"

    # the array that holds the tests
    $testsArray = @()

    $testsArray += Test-Runner "docker pull $imageName" "PullImageTest"
    $testsArray += Test-Runner "docker volume create $volumeName"  "CreateVolumeTest"
    $testsArray += Test-Runner "docker network create -d nat $networkName" "CreateNetworkTest"
    $testsArray += Test-Runner "docker build -f $configPath -t $imageName ." "BuildContainerTest"
    $testsArray += Test-Runner "docker run --name $containerName -d -p 8080:80 -v $bindMountPath $imageName" "StartBuiltContainerTest"
    $testsArray += Test-Runner "docker exec $containerName ls /test" "SharedVolumeTest"

    $ignoredResult = docker stop $containerName
    $ignoredResult = docker rm $containerName

    $testsArray += Test-CreateContainer -containerName $containerName -containerImage $imageName -exposePorts -nodePort $nodePort -containerPort $containerPort

    # TODO
    #$testsArray += Test-Runner "docker network connect $networkName $containerName" "ConnectNetworkTest"
    $testsArray += Test-Runner "docker start $containerName" "StartContainerTest"
    $testsArray += Test-Runner "docker exec $containerName ls" "ExecProcessInContainerTest"
    $testsArray += Test-Runner "docker restart $containerName" "RestartContainerTest"

    $newProcess = Get-Process vmmem
    $workinginfo = ProcessWorkingSetInfoById $newProcess.id

    $UVM = Get-ComputeProcess
    $memoryUsedByUVMOS=hcsdiag exec -uvm $UVM.id free

    $testsArray += Test-Runner "docker stop $containerName" "StopContainerTest"
    $testsArray += Test-Runner "docker rm $containerName" "RemoveContainerTest"
    $testsArray += Test-Runner "docker rmi $imageName" "RemoveImageTest"

    Write-Output "----------------------------------------------------------------" >> tests.log
    Write-Output " Test results for the tests" >> tests.log
    Write-Output "----------------------------------------------------------------" >> tests.log
    $testsArray | ConvertTo-Json > tests.json


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

Test-Executor $VOLUME_NAME $CONTAINER_IMAGE $NETWORK_NAME $CONTAINER_NAME $CONFIGS_PATH $BINDMOUNT_PATH $BUILD_CONTAINER_IMAGE_NAME $NODE_PORT $CONTAINER_PORT

Clear-Environment