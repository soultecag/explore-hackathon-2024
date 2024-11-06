function get-currentAlertDefinitions {
    param (
        $existingCSV
    )
    # if this function is called, a new CSV will be created that reads out the default alerts
    $tempCSV = "$PSScriptRoot\tempCSV.csv"

    # Clear the content (just in case)
    #Clear-Variable -Name alarms

    $alarms = Get-AlarmDefinition
    # Export the alarm definitions to a CSV file
    $alarms | Select-Object Name, @{N="Description";E={$_.Description -replace "," -replace '"'}}, @{N="Priority";E={if (!$_.Enabled) {"Disabled"} else {""}}}, @{N="Notes";E={""}}, @{N="IfUsed";E={""}} | Export-Csv -Path $tempCSV -NoTypeInformation

    # Import the existing CSV
    $existingAlarms = Import-Csv -Path $existingCSV

    # Import the temporary CSV
    $tempAlarms = Import-Csv -Path $tempCSV

    # Loop through the temporary alarms and update priorities from the existing CSV
    foreach ($tempAlarm in $tempAlarms) {
        $match = $existingAlarms | Where-Object { $_.Name -eq $tempAlarm.Name }
        if ($match) {
            # Update the priority if a match is found
            if ($match.Priority -ne "") {
                $tempAlarm.Priority = $match.Priority
            }
        }
        else {
            # Add a note if no match is found
            $tempAlarm.Notes = "No match found in existing CSV"
            $tempAlarm.Priority = "Disabled"
        }
    }
    #$tempAlarms | ForEach-Object { $_ -replace '"', '' } | Export-Csv -Path $tempCSV -NoTypeInformation

    # Export the updated alarms back to the temporary CSV
    $tempAlarms | Export-Csv -Path $tempCSV -NoTypeInformation -UseQuotes Never
}
<#


Distibution/License:

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    https://github.com/mc1903/vCenter-67-Alarms/blob/master/LICENSE


This script has been tested with the following applications/versions:

    VMware vCenter Server v8.0 Update 3 (Build xy)


Credit - This script is a updated version of Aaron Margeson's original script:

    'PowerCLI Script to Configure vCenter Alarm Email Actions' which can be found at
    http://www.cloudyfuture.net/2017/08/08/powercli-script-configure-vcenter-alarm-email/


Version 1.00 - Martin Cooper 08/12/2018

    Automatically adds the vCenter Host Name to the Alarm Name where required.
    Added a progress bar.
    Added a 'Critical' priority alarm option, with a 1 hour repeating notifications.

Version 1.1 - souITec@vmware explore hackathon 2024 -  5/11/2024

    stuff

#>

# Load the PowerCLI SnapIn and set the configuration
#Add-PSSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

# Get the vCenter Server address, username and password as PSCredential
$vCenterServer = Read-Host "Enter vCenter Server host name (DNS with FQDN or IP address)"
$vCenterUser = Read-Host "Enter your user name (DOMAIN\User or user@domain.com)"
$vCenterUserPassword = Read-Host "Enter your password (this will be converted to a secure string)" -AsSecureString:$true
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $vCenterUser, $vCenterUserPassword

# Connect to the vCenter Server with collected credentials
Connect-VIServer -Server $vCenterServer -Credential $Credentials | Out-Null
Write-Host "Connected to your vCenter server $vCenterServer" -ForegroundColor Green

while ($true) {
    $response = Read-Host -Prompt "Do you want to read out the alerts or use the existing alerts from the csv? (R/E)"
    if ($response -eq "R") {
        # Call the function to read out the alerts
        $getNewAlerts = $true
        break
    }
    elseif ($response -eq "E") {
        # Use the existing CSV
        Write-Host "Using the existing CSV."
        $getNewAlerts = $false
        break
    }
    else {
        Write-Host "Invalid input. Please enter R to read out the alerts or E to use the existing one."
    }
}


if ($getNewAlerts) {
    get-currentAlertDefinitions -existingCSV "$PSScriptRoot\alerts.csv"
    $Alarmfile = Import-CSV "$PSScriptRoot\tempCSV.csv"
    Write-Host "the new CSV is populated and will now be used"
}
else {
    $Alarmfile = Import-Csv "$PSScriptRoot\alerts.csv"
    Write-Host "The existing csv will be used"
}


#SMTP
$AlertEmailRecipients = @("hackathon@vmwareexplore.com") # Multiple recipient addresses are allowed (comma)
$SMTPServer = "smtp.vmware.explore"
$SMTPPort = "25"
$SMTPSendingAddress = "hackathon@explore.local"


#Please DO NOT change anything below this line!

#Import PowerCLI module
#Import-Module -name VMware.PowerCLI

#----These Alarms will be disabled and not send any email messages at all ----
$DisabledAlarms = $Alarmfile | Where-Object priority -EQ "Disabled"
Write-Host "Found $($DisabledAlarms.Count) Disabled Alarms."

#----These Alarms will send a single email message and not repeat ----
$LowPriorityAlarms = $Alarmfile | Where-Object priority -EQ "Low"
Write-Host "Found $($LowPriorityAlarms.Count) Low Priority Alarms."

#----These Alarms will repeat every 24 hours----
$MediumPriorityAlarms = $Alarmfile | Where-Object priority -EQ "Medium"
Write-Host "Found $($MediumPriorityAlarms.Count) Medium Priority Alarms."

#----These Alarms will repeat every 4 hours----
$HighPriorityAlarms = $Alarmfile | Where-Object priority -EQ "High"
Write-Host "Found $($HighPriorityAlarms.Count) High Priority Alarms."

#----These Alarms will repeat every hour----
$CriticalPriorityAlarms = $Alarmfile | Where-Object priority -EQ "Critical"
Write-Host "Found $($CriticalPriorityAlarms.Count) Critical Priority Alarms."

#Clear-Host



#ForEach ($vCenterServer in $vCenterServers) {
#if ($global:DefaultVIServers.Count -gt 0) { Disconnect-VIServer * -Confirm:$false }
#Connect-VIserver $vCenterServer -User $vCenterUser -Password $vCenterUserPassword  | Out-Null
#Write-Host "Debug #1"
#$hostname = $vCenterServer.split(".")[0]
#ForEach ($Alarm in $Alarmfile) { $Alarm.Name = $Alarm.Name -replace "vCenterServerHostname", $vCenterServer }
Get-AdvancedSetting -Entity $vCenterServer -Name mail.smtp.server | Set-AdvancedSetting -Value $SMTPServer -Confirm:$false | Out-Null
Get-AdvancedSetting -Entity $vCenterServer -Name mail.smtp.port | Set-AdvancedSetting -Value $SMTPPort -Confirm:$false | Out-Null
Get-AdvancedSetting -Entity $vCenterServer -Name mail.sender | Set-AdvancedSetting -Value $SMTPSendingAddress -Confirm:$false | Out-Null

#---Disable Alarm Action for Disabled Alarms---
$DisabledAlarmsProgress = 1
Foreach ($DisabledAlarm in $DisabledAlarms) {
    #Write-Host "Debug #2"
    Write-Progress -Id 1 -Activity "Configuring vCenter Alarm Settings" -Status "Disabling Alarm: $($DisabledAlarm.name)" -PercentComplete ($DisabledAlarmsProgress / $DisabledAlarms.count * 100)
    Get-AlarmDefinition -Name $DisabledAlarm.name | Get-AlarmAction -ActionType SendEmail | Remove-AlarmAction -Confirm:$false | Out-Null
    $DisabledAlarmsProgress++
}

#---Set Alarm Action for Low Priority Alarms---
$LowPriorityAlarmsProgress = 1
Foreach ($LowPriorityAlarm in $LowPriorityAlarms) {
    #Write-Host "Debug #3"
    Write-Progress -Id 1 -Activity "Configuring vCenter Alarm Settings" -Status "Configuring Low Priority Alarm: $($LowPriorityAlarm.name)" -PercentComplete ($LowPriorityAlarmsProgress / $LowPriorityAlarms.count * 100)
    Get-AlarmDefinition -Name $LowPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | Remove-AlarmAction -Confirm:$false | Out-Null
    Get-AlarmDefinition -Name $LowPriorityAlarm.name | New-AlarmAction -Email -To @($AlertEmailRecipients) | Out-Null
    Get-AlarmDefinition -Name $LowPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Green" -EndStatus "Yellow" | Out-Null
    #Get-AlarmDefinition -Name $LowPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Red" | Out-Null  # This ActionTrigger is enabled by default.
    Get-AlarmDefinition -Name $LowPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Red" -EndStatus "Yellow" | Out-Null
    Get-AlarmDefinition -Name $LowPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Green" | Out-Null
    $LowPriorityAlarmsProgress++
}

#---Set Alarm Action for Medium Priority Alarms---
$MediumPriorityAlarmsProgress = 1
Foreach ($MediumPriorityAlarm in $MediumPriorityAlarms) {
    #Write-Host "Debug #4"
    Write-Progress -Id 1 -Activity "Configuring vCenter Alarm Settings" -Status "Configuring Medium Priority Alarm: $($MediumPriorityAlarm.name)" -PercentComplete ($MediumPriorityAlarmsProgress / $MediumPriorityAlarms.count * 100)
    Get-AlarmDefinition -Name $MediumPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | Remove-AlarmAction -Confirm:$false | Out-Null
    Get-AlarmDefinition -Name $MediumPriorityAlarm.name | Set-AlarmDefinition -ActionRepeatMinutes (60 * 24) | Out-Null  # 24 Hours
    Get-AlarmDefinition -Name $MediumPriorityAlarm.name | New-AlarmAction -Email -To @($AlertEmailRecipients) | Out-Null
    Get-AlarmDefinition -Name $MediumPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Green" -EndStatus "Yellow" | Out-Null
    Get-AlarmDefinition -Name $MediumPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | Get-AlarmActionTrigger | Select-Object -First 1 | Remove-AlarmActionTrigger -Confirm:$false | Out-Null
    Get-AlarmDefinition -Name $MediumPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Red" -Repeat | Out-Null
    Get-AlarmDefinition -Name $MediumPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Red" -EndStatus "Yellow" | Out-Null
    Get-AlarmDefinition -Name $MediumPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Green" | Out-Null
    $MediumPriorityAlarmsProgress++
}

#---Set Alarm Action for High Priority Alarms---
$HighPriorityAlarmsProgress = 1
Foreach ($HighPriorityAlarm in $HighPriorityAlarms) {
    #Write-Host "Debug #5"
    Write-Progress -Id 1 -Activity "Configuring vCenter Alarm Settings" -Status "Configuring High Priority Alarm: $($HighPriorityAlarm.name)" -PercentComplete ($HighPriorityAlarmsProgress / $HighPriorityAlarms.count * 100)
    Get-AlarmDefinition -Name $HighPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | Remove-AlarmAction -Confirm:$false | Out-Null
    Get-AlarmDefinition -name $HighPriorityAlarm.name | Set-AlarmDefinition -ActionRepeatMinutes (60 * 4)  | Out-Null  # 4 hours
    Get-AlarmDefinition -Name $HighPriorityAlarm.name | New-AlarmAction -Email -To @($AlertEmailRecipients) | Out-Null
    Get-AlarmDefinition -Name $HighPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Green" -EndStatus "Yellow" | Out-Null
    Get-AlarmDefinition -Name $HighPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | Get-AlarmActionTrigger | Select-Object -First 1 | Remove-AlarmActionTrigger   -Confirm:$false | Out-Null
    Get-AlarmDefinition -Name $HighPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Red" -Repeat | Out-Null
    Get-AlarmDefinition -Name $HighPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Red" -EndStatus "Yellow" | Out-Null
    Get-AlarmDefinition -Name $HighPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Green" | Out-Null
    $HighPriorityAlarmsProgress++
}

#---Set Alarm Action for Critical Priority Alarms---
$CriticalPriorityAlarmsProgress = 1
Foreach ($CriticalPriorityAlarm in $CriticalPriorityAlarms) {
    #Write-Host "Debug #6"
    Write-Progress -Id 1 -Activity "Configuring vCenter Alarm Settings" -Status "Configuring Critical Priority Alarm: $($CriticalPriorityAlarm.name)" -PercentComplete ($CriticalPriorityAlarmsProgress / $CriticalPriorityAlarms.count * 100)
    Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | Remove-AlarmAction -Confirm:$false | Out-Null
    Get-AlarmDefinition -name $CriticalPriorityAlarm.name | Set-AlarmDefinition -ActionRepeatMinutes (60) | Out-Null  # 1 hour
    Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | New-AlarmAction -Email -To @($AlertEmailRecipients) | Out-Null
    Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Green" -EndStatus "Yellow" | Out-Null
    Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | Get-AlarmActionTrigger | Select-Object -First 1 | Remove-AlarmActionTrigger   -Confirm:$false | Out-Null
    Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Red" -Repeat | Out-Null
    Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Red" -EndStatus "Yellow" | Out-Null
    Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Green" | Out-Null
    $CriticalPriorityAlarmsProgress++
}

Disconnect-VIServer $vCenterServer -Confirm:$false

#}
