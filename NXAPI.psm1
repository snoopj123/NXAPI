function Set-NXAPIEnv {

    [CmdletBinding()][OutputType('System.Collections.Hashtable')]

    param(
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [string]$Switch,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [string]$Username,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [SecureString]$Password,
        [parameter(Mandatory = $false)]
        [switch]$Secure,
        [parameter(Mandatory = $false)][ValidateNotNullOrEmpty()]
        [int]$Port
    )

    $env_variables = @{}
    if ($Secure) {
        # For use if certificates are installed on switches
        if ($Port -eq "") {
            $uri = "https://$($Switch)/ins"
        }
        else {
            $uri = "https://$($Switch):$($Port)/ins"
        }
    }
    else {
        # Default to lower security setting, although, please look into certificates for your NX-OS switches and NX-API
        if ($Port -eq "") { 
            $uri = "http://$($Switch)/ins"
        }
        else {
            $uri = "http://$($Switch):$($Port)/ins"
        }
    }
    $auth_header = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($Username):$((New-Object -TypeName PSCredential "$($Username)",$Password).GetNetworkCredential().Password)"))
    $env_variables.Add("URI", $uri)
    $env_variables.Add("auth_header", "Basic $($auth_header)")
    $env_variables.Add("content-type", "application/json-rpc")

    return $env_variables
}

function Get-JsonBody {

    [CmdletBinding()][OutputType("System.String")]

    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][ValidateNotNullOrEmpty()]
        [string]$Commands
    )

    Begin {}
    Process {
        $full_body = @()
        $counter = 1

        foreach ($cmd in $Commands.Split(";")) {
            $inner_obj = [PSCustomObject]@{
                'cmd'     = $cmd;
                'version' = 1.2
            }
            $outer_obj = @()
            $outer_obj = [PSCustomObject]@{
                'jsonrpc' = '2.0';
                'method'  = 'cli';
                'params'  = $inner_obj;
                'id'      = $counter
            }
            $full_body += $outer_obj
            $counter++
        }

        $json_body = $full_body | ConvertTo-Json -Depth 2

        return $json_body
    }
    End {}
}

function Initialize-NXAPICall {

    [CmdletBinding()]

    param(
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [string]$URI,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [hashtable]$Headers,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [string]$Body,
        [parameter(Mandatory = $false)]
        [switch]$EnableVerbose,
        [parameter(Mandatory = $false)]
        [switch]$EnableResponse,
        [parameter(Mandatory = $false)]
        [switch]$EnableJsonResponse
    )
    Begin {
        if ($EnableVerbose) {
            $oldverbose = $VerbosePreference
            $VerbosePreference = "Continue"
        }
    }
    Process {
        $login_retry = 0
        do {
            try {
                $response = Invoke-WebRequest -Uri $URI -Headers $Headers -Body $Body -Method Post
            }
            catch [System.Net.WebException] {
                if ($_.Exception -match "401") {
                    # 401 Authorization Required; potential bad password/authentication issue
                    Write-Verbose "Authentication Failed.  Retrying..."
                    Write-Verbose "Sleeping 10 seconds before trying authentication again..."
                    Start-Sleep 10
                    $login_retry++
                }
                elseif ($_.Exception -match "500") {
                    # A 500 error message could mean anything from bad command structure to a failure in the JSON formatting
                    Write-Verbose "An error 500 has occurred; waiting on error reason..."
                    $ret_Failure = Failure
                    Write-Verbose $ret_Failure
                    if ($EnableResponse) {
                        $ret_string = "500;$($ret_Failure)"
                        return $ret_string
                    }
                    else {
                        break
                    }
                    
                }
                elseif ($_.Exception -match "Unable to connect to the remote server") {
                    # This is there in case we have a complete inability to connect to the endpoint (maybe NX-API is not enabled on the switch)
                    Write-Verbose "Unable to communicate with the switch $($Switch)..."
                    if ($EnableResponse) {
                        $ret_string = "999;Unable to communicate"
                        return $ret_string
                    }
                    else {
                        break
                    }
                    
                }  
            }
            if ($response.StatusCode -eq 200) {
                if ($EnableResponse) {
                    if ($EnableJsonResponse) {
                        $char_index = $response.RawContent.IndexOf("{")
                        $sub_response = ($response.RawContent.Substring($char_index)) | ConvertFrom-Json
                        if ($sub_response.result -eq $null) {
                            $ret_response = "200;Object not found"
                        }
                        else {
                            $found_item = $sub_response.result.body.TABLE_vlanbriefid.ROW_vlanbriefid
                            $ret_response = "200;Object Found,$($found_item.'vlanshowbr-vlanname'),$($found_item.'vlanshowbr-vlanid')"
                        }
                    }
                    else {
                        $ret_response = "200;Successful"
                    }
                    
                    return $ret_response
                }
                else {
                    break
                }
            }
        }
        while ($login_retry -ne 2)    # This is a personal decision here for my environment where we've got some rogue problems with RADIUS authentication. Retrying twice, just in case it's a RADIUS issue.

        if ($EnableResponse) {
            # Only way to get to this point is to have a 401 Authorization issue
            $ret_string = "401;Authorization"
            return $ret_string
        }
        
    }
    End {
        if ($EnableVerbose) {
            $VerbosePreference = $oldverbose
        }
    }
}

function Add-NXAPIVlan {

    [CmdletBinding()][OutputType('PSCustomObject')]

    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][ValidateNotNullOrEmpty()]
        [string]$Switch,
        [parameter(Mandatory = $true)][ValidateNotNullorEmpty()][ValidateRange(1, 4094)]
        [int]$VLANID,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][ValidateLength(1, 32)]
        [ValidateScript( {$_ -match "^[a-zA-Z0-9_]+$"})]
        [string]$VLANName,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [string]$Username,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [securestring]$Password,
        [parameter(Mandatory = $false)]
        [switch]$EnableVerbose,
        [parameter(Mandatory = $false)]
        [switch]$Overwrite
    )
    Begin {
        if ($EnableVerbose) {
            $oldverbose = $VerbosePreference
            $VerbosePreference = "Continue"
        }
        $pso_object = @()
    }
    Process {
        Write-Verbose "*********************************************************************************************************"        
        Write-Verbose "Gathering NX-API Environmental Variables for NX-OS switch: $($Switch)"
        $env_var = Set-NXAPIEnv -Switch $Switch -Username $Username -Password $Password
        if ($EnableVerbose) {
            $vlan_found = Find-NXAPIVlan -EnvironmentVariables $env_var -Switch $Switch -VLANID $VLANID -EnableVerbose
        }
        else {
            $vlan_found = Find-NXAPIVlan -EnvironmentVariables $env_var -Switch $Switch -VLANID $VLANID
        }

        if (($Overwrite -eq $false) -and ($vlan_found -eq $true)) {
            if ($EnableVerbose) {
                Write-Verbose "This means we will not overwrite the found VLAN..."
                $command = "show vlan id $($VLANID)"
                $pso_object += [PSCustomObject]@{Switch = $Switch; Command = $command; Code = "200"; Reason = "Found VLAN;Not Overwriting"}
                $VerbosePreference = $oldverbose
            }
            else {
                $command = "show vlan id $($VLANID)"
                $pso_object += [PSCustomObject]@{Switch = $Switch; Command = $command; Code = "200"; Reason = "Found VLAN;Not Overwriting"} 
            }
        }
        else {
            $headers = @{}
            Write-Verbose "Creating HTTP Header..."
            $headers.Add("Authorization", $env_var["auth_header"])
            $headers.Add("Content-Type", $env_var["content-type"])
            Write-Verbose "Obtaining NX-API URI..."
            $uri = $env_var["URI"]
            Write-Verbose "URI = $($uri)"
            Write-Verbose "Creating JSON Payload of NX-OS Commands..."
            $command = "vlan $($VLANID);name $($VLANName);mode fabricpath"
            $body = Get-JsonBody -Commands $command
            Write-Verbose $body
            if ($EnableVerbose) {
                $api_return = Initialize-NXAPICall -URI $uri -Headers $headers -Body $body -EnableVerbose -EnableResponse
            }
            else {
                $api_return = Initialize-NXAPICall -URI $uri -Headers $headers -Body $body -EnableResponse
            }
            $pso_object += [PSCustomObject]@{Switch = $Switch; Command = $command; Code = ($api_return.Split(";")[0]); Reason = ($api_return.Split(";")[1])}
        }
        # return $pso_object
    }
    End {
        if ($EnableVerbose) {
            $VerbosePreference = $oldverbose
        }

        return $pso_object
    }
}

function Remove-NXAPIVlan {
    
    [CmdletBinding()][OutputType('PSCustomObject')]
    
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][ValidateNotNullOrEmpty()]
        [string]$Switch,
        [parameter(Mandatory = $true)][ValidateNotNullorEmpty()][ValidateRange(1, 4094)]
        [int]$VLANID,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [string]$Username,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [securestring]$Password,
        [parameter(Mandatory = $false)]
        [switch]$EnableVerbose
    )
    Begin {
        if ($EnableVerbose) {
            $oldverbose = $VerbosePreference
            $VerbosePreference = "Continue"
        }
        $pso_object = @()
    }
    Process {
        Write-Verbose "*********************************************************************************************************"        
        Write-Verbose "Gathering NX-API Environmental Variables for NX-OS switch: $($Switch)"
        $env_var = Set-NXAPIEnv -Switch $Switch -Username $Username -Password $Password
        $headers = @{}
        Write-Verbose "Creating HTTP Header..."
        $headers.Add("Authorization", $env_var["auth_header"])
        $headers.Add("Content-Type", $env_var["content-type"])
        Write-Verbose "Obtaining NX-API URI..."
        $uri = $env_var["URI"]
        Write-Verbose "URI = $($uri)"
        Write-Verbose "Creating JSON Payload of NX-OS Commands..."
        $command = "no vlan $($VLANID)"
        $body = Get-JsonBody -Commands $command
        Write-Verbose $body
        if ($EnableVerbose) {
            $api_return = Initialize-NXAPICall -URI $uri -Headers $headers -Body $body -EnableVerbose -EnableResponse
        }
        else {
            $api_return = Initialize-NXAPICall -URI $uri -Headers $headers -Body $body -EnableResponse
        }
        $pso_object += [PSCustomObject]@{Switch = $Switch; Command = $command; Code = ($api_return.Split(";")[0]); Reason = ($api_return.Split(";")[1])}
    }
    End {
        if ($EnableVerbose) {
            $VerbosePreference = $oldverbose
        }
        return $pso_object
    }
}

function Find-NXAPIVlan {

    [CmdletBinding()][OutputType('System.Boolean')]

    param (
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [hashtable]$EnvironmentVariables,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [string]$Switch,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [int]$VLANID,
        [parameter(Mandatory = $false)]
        [switch]$EnableVerbose
    )
    Begin {
        if ($EnableVerbose) {
            $oldverbose = $VerbosePreference
            $VerbosePreference = "Continue"
        }
    }
    Process {
        Write-Verbose "*********************************************************************************************************"
        Write-Verbose "Beginning check for existing VLAN on switch: $($Switch)"
        Write-Verbose "Creating HTTP Header..."
        $headers = @{}
        $headers.Add("Authorization", $EnvironmentVariables["auth_header"])
        $headers.Add("Content-Type", $EnvironmentVariables["content-type"])
        Write-Verbose "Configuring NX-API URI..."
        $uri = $EnvironmentVariables["URI"]
        Write-Verbose "URI = $($uri)"
        Write-Verbose "Creating JSON payload for command to check for VLAN"
        $command = "show vlan id $($VLANID)"
        $body = Get-JsonBody -Commands $command
        Write-Verbose $body
        if ($EnableVerbose) {
            Write-Verbose "Initialize NX-API call to check for existing VLAN..."
            $api_return = Initialize-NXAPICall -URI $uri -Headers $headers -Body $body -EnableVerbose -EnableResponse -EnableJsonResponse
        }
        else {
            $api_return = Initialize-NXAPICall -URI $uri -Headers $headers -Body $body -EnableResponse -EnableJsonResponse
        }

        if ($api_return.Split(";")[1] -match "Object Found") {
            if ($EnableVerbose) {
                Write-Verbose "*************************************************************************************************"
                Write-Verbose "VLAN Information Found = VLAN: [$(($api_return.Split(";")[1]).Split(",")[2])] VLAN NAME: [$(($api_return.Split(";")[1]).Split(",")[1])]"
                Write-Verbose "*************************************************************************************************"
            }
            return $true
        }
        else {
            if ($EnableVerbose) {
                Write-Verbose "*************************************************************************************************"
                Write-Verbose "VLAN $($VLANID) Was Not Found on Switch: $($Switch)"
                Write-Verbose "*************************************************************************************************"
            }
            return $false
        }

    }
    End {
        if ($EnableVerbose) {
            $VerbosePreference = $oldverbose
        }
    }
}

function Invoke-NXAPICall {
    [CmdletBinding()][OutputType('PSCustomObject')]

    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)][ValidateNotNullOrEmpty()]
        [string]$Switch,
        [parameter(Mandatory = $true)][ValidateNotNullorEmpty()]
        [string]$Commands,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [string]$Username,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [SecureString]$Password,
        [parameter(Mandatory = $false)]
        [switch]$EnableVerbose
    )   
    Begin {
        if ($EnableVerbose) {
            $oldverbose = $VerbosePreference
            $VerbosePreference = "Continue"
        }
        $pso_object = @()
    }
    Process {
        Write-Verbose "*********************************************************************************************************"        
        Write-Verbose "Gathering NX-API Environmental Variables for NX-OS switch: $($Switch)"
        $env_var = Set-NXAPIEnv -Switch $Switch -Username $Username -Password $Password
        $headers = @{}
        Write-Verbose "Creating HTTP Header..."
        $headers.Add("Authorization", $env_var["auth_header"])
        $headers.Add("Content-Type", $env_var["content-type"])
        Write-Verbose "Obtaining NX-API URI..."
        $uri = $env_var["URI"]
        Write-Verbose "URI = $($uri)"
        Write-Verbose "Creating JSON Payload of NX-OS Commands..."
        $body = Get-JsonBody -Commands $Commands
        Write-Verbose $body
        if ($EnableVerbose) {
            $api_return = Initialize-NXAPICall -URI $uri -Headers $headers -Body $body -EnableVerbose -EnableResponse
        }
        else {
            $api_return = Initialize-NXAPICall -URI $uri -Headers $headers -Body $body -EnableResponse
        }
        $pso_object += [PSCustomObject]@{Switch = $Switch; Command = $command; Code = ($api_return.Split(";")[0]); Reason = ($api_return.Split(";")[1])}
    }
    End {
        if ($EnableVerbose) {
            $VerbosePreference = $oldverbose
        }
        return $pso_object
    }
}

function Failure {
    # Function borrowed from Chris Wahl (http://wahlnetwork.com/2015/02/19/using-try-catch-powershells-invoke-webrequest/)  Twitter:  @ChrisWahl
    # I added the line that does the ConvertFrom-Json and gets the specific error from NX-API
    $global:result = $_.Exception.Response.GetResponseStream()
    $global:reader = New-Object System.IO.StreamReader($global:result)
    $global:responseBody = $global:reader.ReadToEnd()
    #Write-Host -BackgroundColor:Black -ForegroundColor:Red "Status: A system exception was caught."
    #Write-Host -BackgroundColor:Black -ForegroundColor:Red $global:responsebody
    #Write-host -BackgroundColor:Black -ForegroundColor:Red "$(($global:responseBody | ConvertFrom-Json).error.data.msg)"
    $ret_string = "$(($global:responseBody | ConvertFrom-Json).error.data.msg)"
    return $ret_string
    #break
}