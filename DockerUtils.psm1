function Start-ExternalCommand {
    <#
    .SYNOPSIS
    Helper function to execute a script block and throw an exception in case of error.
    .PARAMETER ScriptBlock
    Script block to execute
    .PARAMETER ArgumentList
    A list of parameters to pass to Invoke-Command
    .PARAMETER ErrorMessage
    Optional error message. This will become part of the exception message we throw in case of an error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Alias("Command")]
        [ScriptBlock]$ScriptBlock,
        [array]$ArgumentList=@(),
        [string]$ErrorMessage
    )
    PROCESS {
        if($LASTEXITCODE){
            # Leftover exit code. Some other process failed, and this
            # function was called before it was resolved.
            # There is no way to determine if the ScriptBlock contains
            # a powershell commandlet or a native application. So we clear out
            # the LASTEXITCODE variable before we execute. By this time, the value of
            # the variable is not to be trusted for error detection anyway.
            $LASTEXITCODE = ""
        }

        $stopwatch=[System.Diagnostics.Stopwatch]::startNew()
        $res = Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        $stopwatch.Stop()
        $exectime = $stopwatch.ElapsedMilliseconds

        if ($LASTEXITCODE) {
            if(!$ErrorMessage){
                Throw ("Command exited with status: {0}" -f $LASTEXITCODE)
            }
            throw ("{0} (Exit code: $LASTEXITCODE)" -f $ErrorMessage)
        }

        Write-Host "`nExecuting: `"$ScriptBlock`" elpased time:`t$exectime ms`n"
        return $exectime
    }
}

function Write-DebugMessage {
    <#
    .SYNOPSIS
    Helper function to write a message if debug is enabled.
    .PARAMETER isDebug
    If this is true, write the debug message, if not, don't
    .PARAMETER Message
    Message to be outputed
    #>
    [CmdletBinding()]
    Param
    (
        [string]$isDebug,
        [string]$Message
    )

        if ($isDebug -eq 'yes') { Write-Output "`n$Message`n" }
}

Export-ModuleMember -Function * -Alias *