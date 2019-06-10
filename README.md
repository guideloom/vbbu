# vbbu

## Virtualbox BackUp v2.13

A script to run backups on VMs running under Virtualbox on Linux.

This script will create either clones or OVA export backups on selected VMs.  This should be run using the same user that runs the virtualbox VMs.

Command line options:
```
Usage: ./vbbu [--verbose] [--syslog] [--syslogid SYSLOG_ID_STRING] 
          [--list PATH_TO_VM_FILE_LIST] [--state running|stopped|paused|saved|poweroff] [--type ova|clone]
          [--exportdir PATH_TO_VM_EXPORT_FOLDER] [--backupdir PATH_TO_VM_BACKUP_FOLDER]
          [--acpi] [--noconf] [--nodays] [--versions N] 
          [--runbackup] [--dry-run] [--help|-h] [VMNAME|VMUUID]...

 Version : 2.13
       --verbose     = print lines as they run. Useful for debugging only
       --syslog      = send output to syslog as well as stdout [Default: Off]
       --syslogid    = syslog id string to send to syslog [Default: vbbu]
       --list        = full path to list of VMs to backup.
                          ONE VM per line. Comments (lines starting with #) allowed.
       --noconf      = do not use config files. Global conf file/vm conf files under conf folder (/etc/vbbu.d) are ignored.
       --nodays      = ignore days option in all conf files. Translation: run every day. [Default: off]
       --state       = only backup VMs whose status is one of running|stopped|paused|saved|poweroff. [Default: not set, aka any]
       --type        = type of backup to create. One of ova|clone. [Default: ova]
       --exportdir   = path to temporary export directory, [Default: /mnt/lv001-r0/backup/vms]
                         Initial export location and for systems that require minimal downtime, make this local SSD for speed
       --backupdir   = path to final backup directory. [Default: /mnt/usb1/backup/vms]
                         Once export is completed, and systems are running again, backup files are moved here.
       --versions    = number of versions to keep in BACKUPDIR. [Default: 4]
       --acpi        = issue acpishutdown instead of savestate. Fixes bug in vbox 5.X sometimes causes kernel panic on vm restart.
       --runbackup   = Actually run. Safety switch. Prevents accidently running backups and "pausing" VMs
       --dry-run     = Limited run. Display commands, and do not run them. [Default: off]
       --help        = this help info

       VMNAME|VMUUID = VM to backup. Can list more then one. If not set, fallback to list.

 Note: Options can also be set in /etc/vbbu.conf or /etc/vbbu.d/VMNAME.conf
 ```

 Option evaluation order in highest to lowest priority
 * command line option
 * VMNAME machine config (/etc/vbbu.d/VMNAME.conf)
 * global config (/etc/vbbu.conf)
 * defaults (variables set in vbbu.sh file)
 
 VMs to backup come are set in the following order
 * VMs passed on the command line
 * VM file list specified with the --list option
 * output from : vboxmanage list vms
 
 *note: VMs with spaces " " in their name are not supported at this time. Sorry.*
  
 vbbu will attempt to put a running VM into "savestate" before running a backup. This saves the machine state and closes all attached data files so a backup can occur. After the initial clone is completed, the VM will be restarted into it's previous state before the backup.
 
 ### Config Variables
 These variables are set either by default (in the shell script itself), the master config file (/etc/vbbu.conf), the individual VM config file (under /etc/vbbu.d) or on the command line.
 
 _Config variable names are always converted to lower case._
 
 ##### confdir (CLI: --confdir FOLDERPATH) [default: /etc/vbbu.d]
 * path to the individual VM config files; naming VMNAME.conf
   * conffile for VM called "webserver" would be /etc/vbbu.d/webserver.conf
 * EX: confdir=/etc/vbbu.d
  
 ##### noconf (CLI: --noconf) [default: 0]
 * do not use config files.
   * /etc/vbbu.conf and confdir files are ignored
 * EX: noconf=0 (0=no, 1=yes)
 
 ##### exportdir (CLI: --exportdir FOLDERPATH) [default: /mnt/lv001-r0/backup/vms]
 * path to "fast" local disk. Ideally this is local SSD.
 * This is the initial VM export. The disk must have enough space to hold a clone, and possibly an OVA export. 
 * in order to minimize downtime on any VM, vbbu will try to restart the VM being backed up as soon as it can.
 * Once restarted, the clone, or OVA export is moved to the slower long term storage, backupdir.
 * exportdir should already exist, and be writeable by the user running the backup script.
 * EX: exportdir=/path/to/local/ssd/vmbackup
 
 ##### backupdir (CLI: --backupdir FOLDERPATH) [default: /mnt/usb1/backup/vms]
  * path to long term backup disk.
  * After the initial clone or OVA export, backups are moved here. This disk must be sized to accomodate the current and previous versions of backups. (see "versions" config variable).
 * backupdir should already exist, and be writeable by the user running the backup script.
 * EX: backupdir=/path/to/externalnas/vmbackup
 
 ##### versions (CLI: --versions N) [default: 4]
 * number of previous versions of backups to keep in backupdir
 * values are rotated out, with the oldest backup being deleted to make room for the new one
 * EX: versions=4
 
 ##### syslog (CLI: --syslog) [default: 0]
 * logs are normally just sent to the local stdout. Enabling this option will also send logs to syslog
 * EX: syslog=0 (0=no, 1=yes)
 
 ##### syslogid (CLI: --syslogid SYSLOGID_STRING) [default: vbbu]
 * if syslog is enabled, the syslog id to tag all syslog entries with
 * EX: syslogid=vbbu
 
 ##### list (CLI: --list FILEPATH) [default: not set]
 * if set, grab the list of VMs to backup from the file.
 * One VM per line
 * comments allowed
  
 ##### state (CLI: --state STATE) [default: not set]
 * if set, only backup VMs in the state passed
 * Current supported states are : running, stopped, paused, saved, poweroff
 * EX: state=running
 
 ##### type (CLI: --type TYPE) [default: ova]
 * the backup type to run on a VM
 * current supported types are : ova, clone
 * clone backups MUST be done for all backups as a first step. One the clone is compelted, the VM is restarted.
 * clone backups are a simple clone of the VM. These run the fastest, but take the most disk.
 * ova backups are an OVA export of the clone created above. These take longer, but can take 50% less disk. These are also much easier to import into virtualbox (or other VM techs)
 * EX: type=ova
  
 ##### days [default: not set]
 * Simple scheduling. Run backups for the VMs on the days listed. Not set = all days.
 * day name (Mon, Tue, ..) whatever `date +%a` returns, or day of month number (01..31), or combination
 * if the word "never" is set, the VM is never backed up
 * EX: days=Mon,Wed,01,15
 
 ##### nodays (CLI: --nodays) [default: 0]
 * if set, ignore any "days" setting in the config files
 * EX: nodays=0 (0=no, 1=yes)
 
 ##### acpi (CLI: --acpi) [default: 0]
 * if set, issue an "acpipowerbutton" to shutdown the VM instead of a "savestate"
 * **NOTE**: SOME VMs (bug in 5.X?) may encounter a kernel panic when the system is restarted if you used "savestate" to shutdown the VM. We noticed this with Ubuntu 18. The work around is to issue an acpipowerbutton option for those VMs only.	_**IMPORTANT**: the acpi daemon MUST be installed on the VM guest for this to work correctly. (See below)_
 
 ##### runbackup (CLI: --runbackup) [default: 0]
 * safety switch
 * the script will only run if runbackup is set to 1. Otherwise this will exit immediatly
 * prevents "accidental" script runs, thus causing a VM to shutdown
 * EX: runbackup=0 (0=no, 1=yes)
 
 ##### dryrun

 #### ACPI daemon install
	
```bash
   # apt install acpid
```
#### Sample acpi files

/etc/acpi/power.sh
```
  #!/bin/bash
  /sbin/shutdown -h now "Power button pressed"
```
/etc/acpi/events/power
```
  event=button/power
  action=/etc/acpi/power.sh "%e"
```
/etc/default/acpid
```
  OPTIONS="-l"
  MODULES="all"
```
restart acpid daemon with
```
  /etc/init.d/acpid restart
```
 
 ## Examples:
 ```
 vbbu --syslog --runbackup
 ```
 run a backup on all VMs listed by vboxmanage list vms, log all output to syslog. This should be the most common type used. I have this as my nightly cronjob
 ```
 vbbu --syslog --runbackup --acpi webserver
 ```
 run a backup on the VM called "webserver" and log output to syslog. Issue an acpipowerbutton instead of savestate
 ```  
 vbbu --dry-run --runbackup --type ova --list /etc/vm.lst
 ```
 run a dry-run backup on all VMs listed in /etc/vm.lst in ova format
  
 
#### Sample syslog output
```
Jun  6 23:00:01 devops01 CRON[59388]: (vbox) CMD (/home/vbox/bin/vbbu --syslog --runbackup)
Jun  6 23:00:02 devops01 vbbu: -- [Buildroot 2018.02] VMs with space in their names are not supported at this time. Skipping
Jun  6 23:00:02 devops01 vbbu: -- [vl001] cannot backup. VM day mismatch. [VM days:Wed] [Today:Thu or 06]
Jun  6 23:00:02 devops01 vbbu: -- [vl002] cannot backup. VM day mismatch. [VM days:Wed] [Today:Thu or 06]
Jun  6 23:00:02 devops01 vbbu: -- [-vpn1] cannot backup. VM set to never backup. [VM days:never]
Jun  6 23:00:02 devops01 vbbu: -- [vw001] cannot backup. VM day mismatch. [VM days:Mon] [Today:Thu or 06]
Jun  6 23:00:03 devops01 vbbu: -- [vl005] cannot backup. VM day mismatch. [VM days:Mon] [Today:Thu or 06]
Jun  6 23:00:03 devops01 vbbu: -- [vl006] cannot backup. VM day mismatch. [VM days:Tue] [Today:Thu or 06]
Jun  6 23:00:03 devops01 vbbu:    [vl003] config file acpi override : 1
Jun  6 23:00:03 devops01 vbbu: -- [vl003] cannot backup. VM day mismatch. [VM days:Sat Mon Wed Fri] [Today:Thu or 06]
Jun  6 23:00:03 devops01 vbbu: -- [vl004] cannot backup. VM day mismatch. [VM days:Sun] [Today:Thu or 06]
Jun  6 23:00:03 devops01 vbbu: -- [vl007] Start backup [State:running] [Days:Sun Tue Thu] [Type:ova] [Shutdown:savestate]
Jun  6 23:00:03 devops01 vbbu:     Begin VM savestate
Jun  6 23:00:12 devops01 vbbu:     End VM savestate. 00:00:09
Jun  6 23:00:12 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  6 23:00:12 devops01 vbbu:     Begin Clone : [vl007-20190606-230003-vboxbu]
Jun  6 23:43:52 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.6T
Jun  6 23:43:52 devops01 vbbu:     End Clone export. 00:43:40
Jun  6 23:43:52 devops01 vbbu:     Begin VM restore state
Jun  6 23:43:55 devops01 vbbu:     End VM restore state. 00:00:03
Jun  6 23:43:55 devops01 vbbu:     Begin VM register for OVA export : [vl007-20190606-230003-vboxbu] [running]
Jun  6 23:43:55 devops01 vbbu:     End VM register for OVA export. 00:00:00
Jun  6 23:43:55 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.6T
Jun  6 23:43:55 devops01 vbbu:     Begin OVA export: [vl007-20190606-230003.ova]
Jun  7 01:36:41 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.4T
Jun  7 01:36:41 devops01 vbbu:     End OVA export. 01:52:46
Jun  7 01:36:41 devops01 vbbu:     Begin VM unregister from OVA export : [vl007-20190606-230003-vboxbu] [running]
Jun  7 01:36:41 devops01 vbbu:     End VM unregister from OVA export. 00:00:00
Jun  7 01:36:43 devops01 vbbu:     Disk free for /mnt/usb1/backup/vms/vl007/vl007 : 4.5T
Jun  7 01:36:43 devops01 vbbu:     Begin VM move from export to backup : [vl007]
Jun  7 01:50:09 devops01 vbbu:     Disk free for /mnt/usb1/backup/vms/vl007/vl007 : 4.3T
Jun  7 01:50:09 devops01 vbbu:     End VM move.  00:13:26
Jun  7 01:50:09 devops01 vbbu: -- [vl007] End backup [running] 02:50:06
Jun  7 01:50:09 devops01 vbbu: -- [qemu01] Start backup [State:poweroff] [Days:] [Type:ova] [Shutdown:savestate]
Jun  7 01:50:10 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 01:50:10 devops01 vbbu:     Begin Clone : [qemu01-20190607-015009-vboxbu]
Jun  7 01:52:19 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 01:52:19 devops01 vbbu:     End Clone export. 00:02:09
Jun  7 01:52:19 devops01 vbbu:     Begin VM register for OVA export : [qemu01-20190607-015009-vboxbu] [poweroff]
Jun  7 01:52:19 devops01 vbbu:     End VM register for OVA export. 00:00:00
Jun  7 01:52:19 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 01:52:19 devops01 vbbu:     Begin OVA export: [qemu01-20190607-015009.ova]
Jun  7 01:59:15 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 01:59:15 devops01 vbbu:     End OVA export. 00:06:56
Jun  7 01:59:15 devops01 vbbu:     Begin VM unregister from OVA export : [qemu01-20190607-015009-vboxbu] [poweroff]
Jun  7 01:59:16 devops01 vbbu:     End VM unregister from OVA export. 00:00:00
Jun  7 01:59:16 devops01 vbbu:     Disk free for /mnt/usb1/backup/vms/qemu01/qemu01 : 4.3T
Jun  7 01:59:16 devops01 vbbu:     Begin VM move from export to backup : [qemu01]
Jun  7 01:59:20 devops01 vbbu:     Disk free for /mnt/usb1/backup/vms/qemu01/qemu01 : 4.3T
Jun  7 01:59:20 devops01 vbbu:     End VM move.  00:00:04
Jun  7 01:59:20 devops01 vbbu: -- [qemu01] End backup [poweroff] 00:09:11
Jun  7 01:59:20 devops01 vbbu:    [vl008] config file acpi override : 1
Jun  7 01:59:20 devops01 vbbu: -- [vl008] cannot backup. VM day mismatch. [VM days:Mon] [Today:Thu or 06]
Jun  7 01:59:21 devops01 vbbu: -- [UB-18.01.02-base] Start backup [State:poweroff] [Days:Thu] [Type:ova] [Shutdown:savestate]
Jun  7 01:59:21 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 01:59:21 devops01 vbbu:     Begin Clone : [UB-18.01.02-base-20190607-015921-vboxbu]
Jun  7 01:59:58 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 01:59:58 devops01 vbbu:     End Clone export. 00:00:37
Jun  7 01:59:58 devops01 vbbu:     Begin VM register for OVA export : [UB-18.01.02-base-20190607-015921-vboxbu] [poweroff]
Jun  7 01:59:58 devops01 vbbu:     End VM register for OVA export. 00:00:00
Jun  7 01:59:58 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 01:59:58 devops01 vbbu:     Begin OVA export: [UB-18.01.02-base-20190607-015921.ova]
Jun  7 02:01:38 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:01:38 devops01 vbbu:     End OVA export. 00:01:40
Jun  7 02:01:38 devops01 vbbu:     Begin VM unregister from OVA export : [UB-18.01.02-base-20190607-015921-vboxbu] [poweroff]
Jun  7 02:01:38 devops01 vbbu:     End VM unregister from OVA export. 00:00:00
Jun  7 02:01:38 devops01 vbbu:     Disk free for /mnt/usb1/backup/vms/UB-18.01.02-base/UB-18.01.02-base : 4.3T
Jun  7 02:01:38 devops01 vbbu:     Begin VM move from export to backup : [UB-18.01.02-base]
Jun  7 02:01:39 devops01 vbbu:     Disk free for /mnt/usb1/backup/vms/UB-18.01.02-base/UB-18.01.02-base : 4.3T
Jun  7 02:01:39 devops01 vbbu:     End VM move.  00:00:01
Jun  7 02:01:39 devops01 vbbu: -- [UB-18.01.02-base] End backup [poweroff] 00:02:18
Jun  7 02:01:39 devops01 vbbu: -- [vl009] cannot backup. VM day mismatch. [VM days:Wed] [Today:Thu or 06]
Jun  7 02:01:40 devops01 vbbu: -- [base] Start backup [State:poweroff] [Days:] [Type:ova] [Shutdown:savestate]
Jun  7 02:01:40 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:01:40 devops01 vbbu:     Begin Clone : [base-20190607-020140-vboxbu]
Jun  7 02:02:34 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:02:34 devops01 vbbu:     End Clone export. 00:00:54
Jun  7 02:02:34 devops01 vbbu:     Begin VM register for OVA export : [base-20190607-020140-vboxbu] [poweroff]
Jun  7 02:02:34 devops01 vbbu:     End VM register for OVA export. 00:00:00
Jun  7 02:02:34 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:02:34 devops01 vbbu:     Begin OVA export: [base-20190607-020140.ova]
Jun  7 02:05:21 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:05:21 devops01 vbbu:     End OVA export. 00:02:47
Jun  7 02:05:21 devops01 vbbu:     Begin VM unregister from OVA export : [base-20190607-020140-vboxbu] [poweroff]
Jun  7 02:05:21 devops01 vbbu:     End VM unregister from OVA export. 00:00:00
Jun  7 02:05:21 devops01 vbbu:     Disk free for /mnt/usb1/backup/vms/base/base : 4.3T
Jun  7 02:05:21 devops01 vbbu:     Begin VM move from export to backup : [base]
Jun  7 02:05:23 devops01 vbbu:     Disk free for /mnt/usb1/backup/vms/base/base : 4.3T
Jun  7 02:05:23 devops01 vbbu:     End VM move.  00:00:02
Jun  7 02:05:23 devops01 vbbu: -- [base] End backup [poweroff] 00:03:43
Jun  7 02:05:23 devops01 vbbu: -- [d01] cannot backup. VM day mismatch. [VM days:Tue] [Today:Thu or 06]
Jun  7 02:05:23 devops01 vbbu: -- [d02] cannot backup. VM day mismatch. [VM days:Wed] [Today:Thu or 06]
Jun  7 02:05:24 devops01 vbbu: -- [d03] Start backup [State:running] [Days:Thu] [Type:ova] [Shutdown:savestate]
Jun  7 02:05:24 devops01 vbbu:     Begin VM savestate
Jun  7 02:05:28 devops01 vbbu:     End VM savestate. 00:00:04
Jun  7 02:05:28 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:05:28 devops01 vbbu:     Begin Clone : [d03-20190607-020524-vboxbu]
Jun  7 02:06:34 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:06:34 devops01 vbbu:     End Clone export. 00:01:06
Jun  7 02:06:34 devops01 vbbu:     Begin VM restore state
Jun  7 02:06:36 devops01 vbbu:     End VM restore state. 00:00:02
Jun  7 02:06:36 devops01 vbbu:     Begin VM register for OVA export : [d03-20190607-020524-vboxbu] [running]
Jun  7 02:06:36 devops01 vbbu:     End VM register for OVA export. 00:00:00
Jun  7 02:06:36 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:06:36 devops01 vbbu:     Begin OVA export: [d03-20190607-020524.ova]
Jun  7 02:09:32 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:09:32 devops01 vbbu:     End OVA export. 00:02:56
Jun  7 02:09:32 devops01 vbbu:     Begin VM unregister from OVA export : [d03-20190607-020524-vboxbu] [running]
Jun  7 02:09:32 devops01 vbbu:     End VM unregister from OVA export. 00:00:00
Jun  7 02:09:32 devops01 vbbu:     Disk free for /mnt/usb1/backup/vms/d03/d03 : 4.3T
Jun  7 02:09:32 devops01 vbbu:     Begin VM move from export to backup : [d03]
Jun  7 02:09:34 devops01 vbbu:     Disk free for /mnt/usb1/backup/vms/d03/d03 : 4.3T
Jun  7 02:09:34 devops01 vbbu:     End VM move.  00:00:02
Jun  7 02:09:34 devops01 vbbu: -- [d03] End backup [running] 00:04:10
Jun  7 02:09:34 devops01 vbbu: -- [dvl001] Start backup [State:running] [Days:Thu] [Type:ova] [Shutdown:savestate]
Jun  7 02:09:34 devops01 vbbu:     Begin VM savestate
Jun  7 02:09:39 devops01 vbbu:     End VM savestate. 00:00:05
Jun  7 02:09:39 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:09:39 devops01 vbbu:     Begin Clone : [dvl001-20190607-020934-vboxbu]
Jun  7 02:11:12 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:11:12 devops01 vbbu:     End Clone export. 00:01:33
Jun  7 02:11:12 devops01 vbbu:     Begin VM restore state
Jun  7 02:11:15 devops01 vbbu:     End VM restore state. 00:00:03
Jun  7 02:11:15 devops01 vbbu:     Begin VM register for OVA export : [dvl001-20190607-020934-vboxbu] [running]
Jun  7 02:11:15 devops01 vbbu:     End VM register for OVA export. 00:00:00
Jun  7 02:11:15 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:11:15 devops01 vbbu:     Begin OVA export: [dvl001-20190607-020934.ova]
Jun  7 02:16:16 devops01 vbbu:     Disk free for /mnt/lv001-r0/backup/vms : 1.8T
Jun  7 02:16:16 devops01 vbbu:     End OVA export. 00:05:01
Jun  7 02:16:16 devops01 vbbu:     Begin VM unregister from OVA export : [dvl001-20190607-020934-vboxbu] [running]
Jun  7 02:16:17 devops01 vbbu:     End VM unregister from OVA export. 00:00:01
Jun  7 02:16:17 devops01 vbbu:     Disk free for /mnt/usb1/backup/vms/dvl001/dvl001 : 4.3T
Jun  7 02:16:17 devops01 vbbu:     Begin VM move from export to backup : [dvl001]
Jun  7 02:16:20 devops01 vbbu:     Disk free for /mnt/usb1/backup/vms/dvl001/dvl001 : 4.3T
Jun  7 02:16:20 devops01 vbbu:     End VM move.  00:00:03
Jun  7 02:16:20 devops01 vbbu: -- [dvl001] End backup [running] 00:06:46
```
