<#

The Official Home for this Project is https://github.com/mc1903/vCenter-67-Alarms

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

    VMware vCenter Server v6.7 Update 1 (Build 10244745)


Credit - This script is a updated version of Aaron Margeson's original script:

    'PowerCLI Script to Configure vCenter Alarm Email Actions' which can be found at
    http://www.cloudyfuture.net/2017/08/08/powercli-script-configure-vcenter-alarm-email/


Version 1.00 - Martin Cooper 08/12/2018

    Automatically adds the vCenter Host Name to the Alarm Name where required.
    Added a progress bar.
    Added a 'Critical' priority alarm option, with a 1 hour repeating notifications.

#>

#Set Working Variables Below
$vCenterServers = "mc-vcsa-v-202.momusconsulting.com" # MUST use the FQDN
$vCenterUsername = "administrator@vsphere.local"
$vCenterUserPwd = "Pa55word5!"
$Alarmfile = Import-Csv "$PSScriptRoot\vsphere67u2-alarms.csv"
$AlertEmailRecipients = @("vCenter-Notify-1@momusconsulting.com","vCenter-Notify-2@momusconsulting.com") # Multiple recipient addresses are allowed
$SMTPServer = "mc-smtp-v-102.momusconsulting.com"
$SMTPPort = "25"
$SMTPSendingAddress = "mc-vcsa-v-202@momusconsulting.com"

#Please DO NOT change anything below this line!

#Import PowerCLI module
Import-Module -name VMware.PowerCLI

#----These Alarms will be disabled and not send any email messages at all ----
$DisabledAlarms = $Alarmfile | Where-Object priority -EQ "Disabled"

#----These Alarms will send a single email message and not repeat ----
$LowPriorityAlarms = $Alarmfile | Where-Object priority -EQ "Low"

#----These Alarms will repeat every 24 hours----
$MediumPriorityAlarms = $Alarmfile | Where-Object priority -EQ "Medium"

#----These Alarms will repeat every 4 hours----
$HighPriorityAlarms = $Alarmfile | Where-Object priority -EQ "High"

#----These Alarms will repeat every hour----
$CriticalPriorityAlarms = $Alarmfile | Where-Object priority -EQ "Critical"

Clear-Host

ForEach ($vCenterServer in $vCenterServers){
    if ($global:DefaultVIServers.Count -gt 0) {Disconnect-VIServer * -Confirm:$false}
    Connect-VIserver $vCenterServer -User $vCenterUsername -Password $vCenterUserPwd  | Out-Null
    $hostname = $vCenterServer.split(".")[0]
    ForEach($Alarm in $Alarmfile) {$Alarm.Name = $Alarm.Name -replace "vCenterServerHostname",$Hostname}
    Get-AdvancedSetting -Entity $vCenterServer -Name mail.smtp.server | Set-AdvancedSetting -Value $SMTPServer -Confirm:$false | Out-Null
    Get-AdvancedSetting -Entity $vCenterServer -Name mail.smtp.port | Set-AdvancedSetting -Value $SMTPPort -Confirm:$false | Out-Null
    Get-AdvancedSetting -Entity $vCenterServer -Name mail.sender | Set-AdvancedSetting -Value $SMTPSendingAddress -Confirm:$false | Out-Null

    #---Disable Alarm Action for Disabled Alarms---
    $DisabledAlarmsProgress = 1
    Foreach ($DisabledAlarm in $DisabledAlarms) {
        Write-Progress -Id 1 -Activity "Configuring vCenter Alarm Settings" -Status "Disabling Alarm: $($DisabledAlarm.name)" -PercentComplete ($DisabledAlarmsProgress/$DisabledAlarms.count*100)
        Get-AlarmDefinition -Name $DisabledAlarm.name | Get-AlarmAction -ActionType SendEmail| Remove-AlarmAction -Confirm:$false | Out-Null
        $DisabledAlarmsProgress++
    }

    #---Set Alarm Action for Low Priority Alarms---
    $LowPriorityAlarmsProgress = 1
    Foreach ($LowPriorityAlarm in $LowPriorityAlarms) {
        Write-Progress -Id 1 -Activity "Configuring vCenter Alarm Settings" -Status "Configuring Low Priority Alarm: $($LowPriorityAlarm.name)" -PercentComplete ($LowPriorityAlarmsProgress/$LowPriorityAlarms.count*100)
        Get-AlarmDefinition -Name $LowPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail| Remove-AlarmAction -Confirm:$false | Out-Null
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
        Write-Progress -Id 1 -Activity "Configuring vCenter Alarm Settings" -Status "Configuring Medium Priority Alarm: $($MediumPriorityAlarm.name)" -PercentComplete ($MediumPriorityAlarmsProgress/$MediumPriorityAlarms.count*100)
        Get-AlarmDefinition -Name $MediumPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail| Remove-AlarmAction -Confirm:$false | Out-Null
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
        Write-Progress -Id 1 -Activity "Configuring vCenter Alarm Settings" -Status "Configuring High Priority Alarm: $($HighPriorityAlarm.name)" -PercentComplete ($HighPriorityAlarmsProgress/$HighPriorityAlarms.count*100)
        Get-AlarmDefinition -Name $HighPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail| Remove-AlarmAction -Confirm:$false | Out-Null
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
        Write-Progress -Id 1 -Activity "Configuring vCenter Alarm Settings" -Status "Configuring Critical Priority Alarm: $($CriticalPriorityAlarm.name)" -PercentComplete ($CriticalPriorityAlarmsProgress/$CriticalPriorityAlarms.count*100)
        Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail| Remove-AlarmAction -Confirm:$false | Out-Null
        Get-AlarmDefinition -name $CriticalPriorityAlarm.name | Set-AlarmDefinition -ActionRepeatMinutes (60) | Out-Null  # 1 hour
        Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | New-AlarmAction -Email -To @($AlertEmailRecipients) | Out-Null
        Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Green" -EndStatus "Yellow" | Out-Null
        Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | Get-AlarmActionTrigger | Select-Object -First 1 | Remove-AlarmActionTrigger   -Confirm:$false | Out-Null
        Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Red" -Repeat | Out-Null
        Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Red" -EndStatus "Yellow" | Out-Null
        Get-AlarmDefinition -Name $CriticalPriorityAlarm.name | Get-AlarmAction -ActionType SendEmail | New-AlarmActionTrigger -StartStatus "Yellow" -EndStatus "Green" | Out-Null
        $CriticalPriorityAlarmsProgress++
    }

}
