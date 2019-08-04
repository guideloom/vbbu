# vbbu

## Virtualbox BackUp

A script to run backups on VMs running under Virtualbox on Linux.

_* Important: requires https://github.com/guideloom/gl_functions.sh to be installed *_

This script will create either clones or OVA export backups on selected VMs.  This should be run using the same user that runs the virtualbox VMs.

Command line options:
```
Usage: ./vbbu [--verbose] [--syslog] [--syslogid SYSLOG_ID_STRING] [--dryrun] [--help|-h]
          [--list PATH_TO_VM_FILE_LIST] [--state running|stopped|paused|saved|poweroff] [--type ova|clone]
          [--exportdir PATH_TO_VM_EXPORT_FOLDER] [--backupdir PATH_TO_VM_BACKUP_FOLDER] [--confdir PATH_TO_CONF_FILES
          [--acpi] [--noconf] [--nodays] [--runbackup]
          [--versions N] [--daystokeep N] [VMNAME|VMUUID]...

 Version : 2.26
       --verbose     = print lines as they run. Useful for debugging only
       --syslog      = send output to syslog as well as stdout [Default: 0]
       --syslogid    = syslog id string to send to syslog [Default: vbbu]
       --list        = full path to list of VMs to backup
       --noconf      = do not use config files. Master conf file/vm conf files under conf folder (/etc/vbbu.d) are ignored
       --nodays      = ignore days option in conf files. Translation: run every day. [Default: off]
       --state       = only backup VMs whose status is one of running|stopped|paused|saved|poweroff. [Default: not set, aka any]
       --type        = type of backup to create. One of ova|clone. [Default: ova]
       --exportdir   = path to temporary export directory, [Default: /mnt/lv001-r0/backup/vms]
       --backupdir   = path to final backup directory. [Default: /mnt/usb1/backup/vms]
       --versions    = number of versions to keep in BACKUPDIR. [Default: 2]
       --daystokeep  = number of days to keep backups for. Ones older are removed. [Default: 0]
                       Note: if daystokeep is set, this OVERRIDES the --versions option.
       --acpi        = issue acpishutdown instead of savestate. Fixes bug in vbox 5.X sometimes causes kernel panic on vm restart.
       --dryrun      = Limited run. Display commands, and do not run them. [Default: off]
       --help        = this help info
       --runbackup   = Actually run. Safety switch. Prevents accidently running backups and pausing VMs

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

_NOTE: with Virtualbox 6.0.10 (all versions of 6 earlier then 6.0.10?) there is a bug in which if the VM is on an NFS (and possibly SMB) share, AND you use "savestate", the clone of the VM will fail with error VBOX_E_IPRT_ERROR (0x80BB0005). This is a known issue. (https://www.virtualbox.org/ticket/18811). The workaround is to either run Virtualbox 5.2.X, or move your VMs to a local ext4 filesystem, or use the acpi option outlined below. Will update this if there are changes._
 
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
 * values are rotated out, with the oldest backup being deleted to make room for the new one, in syslog fashion
 * example names: vmname, vmname.1, vmname.2, vmname.3
 * EX: versions=4
 
 
  ##### daystokeep (CLI: --daystokeep N) [default: 0]
 * number of days to keep previous backups in backupdir
 * backups older than this number of days are removed
 * _If set, this option **overrides** --versions_
 * names of backup folders are also changed to reflect _timestamps_ and not versions.
 * example names: vmname.20190605-031256, vmname.20190606-030832, vnmame.20190628-134503
 * EX: daystokeep=14
 
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
 * **NOTE**: SOME VM guests (possible bug in virtualbox 5.X?) may encounter a kernel panic when the system is restarted if the guest was shutdown using "savestate". We noticed this with Ubuntu 18 guests. The work around is to issue an acpipowerbutton option instead of savestate for those VM guests only. _**IMPORTANT**: the acpi daemon MUST be installed on the VM guest for this to work correctly. (See below)_
 
 ##### runbackup (CLI: --runbackup) [default: 0]
 * safety switch
 * the script will only run if runbackup is set to 1. Otherwise this will exit immediatly
 * prevents "accidental" script runs, thus causing a VM to shutdown
 * EX: runbackup=0 (0=no, 1=yes)
 
 ##### dryrun (CLI: --dryrun) [default: 0]
 * if set, do a dry run. Do not execute commands, just show them.
 * EX: dryrun=0  (0=no, 1=yes)

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
Jul 25 23:00:01 dev01 vbbu: -- [Buildroot 2018.02] VMs with space in their names are not supported at this time. Skipping
Jul 25 23:00:01 dev01 vbbu: -- [vl001] cannot backup. VM day mismatch. [VM days:Wed Sat] [Today:Thu or 25]
Jul 25 23:00:01 dev01 vbbu: -- [vl002] cannot backup. VM day mismatch. [VM days:Wed Sat] [Today:Thu or 25]
Jul 25 23:00:01 dev01 vbbu: -- [vpn1] cannot backup. VM set to never backup. [VM days:never]
Jul 25 23:00:02 dev01 vbbu: -- [vw001] Start backup [State:running] [Days:Mon Thu] [Type:ova] [Shutdown:savestate]
Jul 25 23:00:02 dev01 vbbu:     Begin VM savestate
Jul 25 23:00:57 dev01 vbbu:     End VM savestate. 00:00:55
Jul 25 23:00:57 dev01 vbbu:     Begin Clone : [vw001-20190725-230002-vboxbu]
Jul 25 23:00:57 dev01 vbbu:      Disk free before clonevm /mnt/lv001-r0/backup/vms : 1710904MB
Jul 25 23:14:53 dev01 vbbu:       Exportdir size: 82892MB
Jul 25 23:14:53 dev01 vbbu:      Disk free after clonevm /mnt/lv001-r0/backup/vms : 1628012MB
Jul 25 23:14:53 dev01 vbbu:     End Clone export. 00:13:56
Jul 25 23:14:53 dev01 vbbu:     Begin VM restore state
Jul 25 23:15:07 dev01 vbbu:     End VM restore state. 00:00:14
Jul 25 23:15:07 dev01 vbbu:     Begin VM register for OVA export : [vw001-20190725-230002-vboxbu] [running]
Jul 25 23:15:07 dev01 vbbu:     End VM register for OVA export. 00:00:00
Jul 25 23:15:07 dev01 vbbu:     Begin OVA export: [vw001-20190725-230002.ova]
Jul 25 23:15:07 dev01 vbbu:      Disk free before OVA export /mnt/lv001-r0/backup/vms : 1628012MB
Jul 25 23:52:33 dev01 vbbu:       OVA size: 52248MB
Jul 25 23:52:33 dev01 vbbu:      Disk free after OVA export /mnt/lv001-r0/backup/vms : 1575764MB
Jul 25 23:52:33 dev01 vbbu:     End OVA export. 00:37:26
Jul 25 23:52:33 dev01 vbbu:     Begin VM unregister from OVA export : [vw001-20190725-230002-vboxbu] [running]
Jul 25 23:52:33 dev01 vbbu:     End VM unregister from OVA export. 00:00:00
Jul 25 23:52:33 dev01 vbbu:     Removing folder (+14 days old) /mnt/usb1/backup/vms/vw001/vw001.20190708-220002
Jul 25 23:52:34 dev01 vbbu:     Begin VM move from export to backup : [vw001]
Jul 25 23:52:34 dev01 vbbu:      Disk free before move to backup /mnt/usb1/backup/vms/vw001/vw001.20190725-230002 : 4895272MB
Jul 25 23:58:11 dev01 vbbu:       Backup folder size: 52248MB
Jul 25 23:58:12 dev01 vbbu:      Disk free after move to backup /mnt/usb1/backup/vms/vw001/vw001.20190725-230002 : 4843024MB
Jul 25 23:58:12 dev01 vbbu:     End VM move.  00:05:37
Jul 25 23:58:12 dev01 vbbu: -- [vw001] End backup [State:running] 00:58:10
Jul 25 23:58:12 dev01 vbbu: -- [vl005] cannot backup. VM day mismatch. [VM days:Mon] [Today:Thu or 25]
Jul 25 23:58:12 dev01 vbbu: -- [vl006] cannot backup. VM day mismatch. [VM days:Tue] [Today:Thu or 25]
Jul 25 23:58:12 dev01 vbbu: -- [vl003] cannot backup. VM day mismatch. [VM days:Sat Mon Wed Fri] [Today:Thu or 25]
Jul 25 23:58:12 dev01 vbbu: -- [vl004] cannot backup. VM day mismatch. [VM days:Sun] [Today:Thu or 25]
Jul 25 23:58:13 dev01 vbbu: -- [vl007] Start backup [State:running] [Days:Sun Tue Thu] [Type:ova] [Shutdown:savestate]
Jul 25 23:58:13 dev01 vbbu:     Begin VM savestate
Jul 25 23:58:22 dev01 vbbu:     End VM savestate. 00:00:09
Jul 25 23:58:22 dev01 vbbu:     Begin Clone : [vl007-20190725-235813-vboxbu]
Jul 25 23:58:22 dev01 vbbu:      Disk free before clonevm /mnt/lv001-r0/backup/vms : 1710904MB
Jul 26 00:41:39 dev01 vbbu:       Exportdir size: 261723MB
Jul 26 00:41:39 dev01 vbbu:      Disk free after clonevm /mnt/lv001-r0/backup/vms : 1449181MB
Jul 26 00:41:39 dev01 vbbu:     End Clone export. 00:43:17
Jul 26 00:41:39 dev01 vbbu:     Begin VM restore state
Jul 26 00:41:41 dev01 vbbu:     End VM restore state. 00:00:02
Jul 26 00:41:41 dev01 vbbu:     Begin VM register for OVA export : [vl007-20190725-235813-vboxbu] [running]
Jul 26 00:41:41 dev01 vbbu:     End VM register for OVA export. 00:00:00
Jul 26 00:41:41 dev01 vbbu:     Begin OVA export: [vl007-20190725-235813.ova]
Jul 26 00:41:41 dev01 vbbu:      Disk free before OVA export /mnt/lv001-r0/backup/vms : 1449181MB
Jul 26 02:29:11 dev01 vbbu:       OVA size: 140291MB
Jul 26 02:29:11 dev01 vbbu:      Disk free after OVA export /mnt/lv001-r0/backup/vms : 1308890MB
Jul 26 02:29:11 dev01 vbbu:     End OVA export. 01:47:30
Jul 26 02:29:11 dev01 vbbu:     Begin VM unregister from OVA export : [vl007-20190725-235813-vboxbu] [running]
Jul 26 02:29:11 dev01 vbbu:     End VM unregister from OVA export. 00:00:00
Jul 26 02:29:11 dev01 vbbu:     Removing folder (+7 days old) /mnt/usb1/backup/vms/vl007/vl007.20190716-220931
Jul 26 02:29:13 dev01 vbbu:     Begin VM move from export to backup : [vl007]
Jul 26 02:29:13 dev01 vbbu:      Disk free before move to backup /mnt/usb1/backup/vms/vl007/vl007.20190725-235813 : 4990130MB
Jul 26 02:49:14 dev01 vbbu:       Backup folder size: 140291MB
Jul 26 02:49:14 dev01 vbbu:      Disk free after move to backup /mnt/usb1/backup/vms/vl007/vl007.20190725-235813 : 4849839MB
Jul 26 02:49:14 dev01 vbbu:     End VM move.  00:20:01
Jul 26 02:49:14 dev01 vbbu: -- [vl007] End backup [State:running] 02:51:01
Jul 26 02:49:14 dev01 vbbu: -- [qemu01] cannot backup. VM day mismatch. [VM days:Sun] [Today:Thu or 25]
Jul 26 02:49:15 dev01 vbbu: -- [vl008] cannot backup. VM day mismatch. [VM days:Mon] [Today:Thu or 25]
Jul 26 02:49:15 dev01 vbbu: -- [UB-18.01.02-base] Start backup [State:poweroff] [Days:Thu] [Type:ova] [Shutdown:savestate]
Jul 26 02:49:15 dev01 vbbu:     Begin Clone : [UB-18.01.02-base-20190726-024915-vboxbu]
Jul 26 02:49:15 dev01 vbbu:      Disk free before clonevm /mnt/lv001-r0/backup/vms : 1710904MB
Jul 26 02:49:52 dev01 vbbu:       Exportdir size: 3920MB
Jul 26 02:49:52 dev01 vbbu:      Disk free after clonevm /mnt/lv001-r0/backup/vms : 1706984MB
Jul 26 02:49:52 dev01 vbbu:     End Clone export. 00:00:37
Jul 26 02:49:52 dev01 vbbu:     Begin VM register for OVA export : [UB-18.01.02-base-20190726-024915-vboxbu] [poweroff]
Jul 26 02:49:52 dev01 vbbu:     End VM register for OVA export. 00:00:00
Jul 26 02:49:52 dev01 vbbu:     Begin OVA export: [UB-18.01.02-base-20190726-024915.ova]
Jul 26 02:49:52 dev01 vbbu:      Disk free before OVA export /mnt/lv001-r0/backup/vms : 1706984MB
Jul 26 02:51:32 dev01 vbbu:       OVA size: 1462MB
Jul 26 02:51:32 dev01 vbbu:      Disk free after OVA export /mnt/lv001-r0/backup/vms : 1705521MB
Jul 26 02:51:32 dev01 vbbu:     End OVA export. 00:01:40
Jul 26 02:51:32 dev01 vbbu:     Begin VM unregister from OVA export : [UB-18.01.02-base-20190726-024915-vboxbu] [poweroff]
Jul 26 02:51:32 dev01 vbbu:     End VM unregister from OVA export. 00:00:00
Jul 26 02:51:32 dev01 vbbu:     Removing folder (+7 days old) /mnt/usb1/backup/vms/UB-18.01.02-base/UB-18.01.02-base.20190712-015009
Jul 26 02:51:32 dev01 vbbu:     Begin VM move from export to backup : [UB-18.01.02-base]
Jul 26 02:51:32 dev01 vbbu:      Disk free before move to backup /mnt/usb1/backup/vms/UB-18.01.02-base/UB-18.01.02-base.20190726-024915 : 4851301MB
Jul 26 02:51:34 dev01 vbbu:       Backup folder size: 1462MB
Jul 26 02:51:34 dev01 vbbu:      Disk free after move to backup /mnt/usb1/backup/vms/UB-18.01.02-base/UB-18.01.02-base.20190726-024915 : 4849839MB
Jul 26 02:51:34 dev01 vbbu:     End VM move.  00:00:02
Jul 26 02:51:34 dev01 vbbu: -- [UB-18.01.02-base] End backup [State:poweroff] 00:02:19
Jul 26 02:51:34 dev01 vbbu: -- [vl009] cannot backup. VM day mismatch. [VM days:Wed] [Today:Thu or 25]
Jul 26 02:51:34 dev01 vbbu: -- [di1] cannot backup. VM day mismatch. [VM days:Tue] [Today:Thu or 25]
Jul 26 02:51:34 dev01 vbbu: -- [di2] cannot backup. VM day mismatch. [VM days:Wed] [Today:Thu or 25]
Jul 26 02:51:35 dev01 vbbu: -- [di3] Start backup [State:running] [Days:Thu] [Type:ova] [Shutdown:savestate]
Jul 26 02:51:35 dev01 vbbu:     Begin VM savestate
Jul 26 02:51:39 dev01 vbbu:     End VM savestate. 00:00:04
Jul 26 02:51:39 dev01 vbbu:     Begin Clone : [di3-20190726-025135-vboxbu]
Jul 26 02:51:39 dev01 vbbu:      Disk free before clonevm /mnt/lv001-r0/backup/vms : 1710904MB
Jul 26 02:52:51 dev01 vbbu:       Exportdir size: 7625MB
Jul 26 02:52:51 dev01 vbbu:      Disk free after clonevm /mnt/lv001-r0/backup/vms : 1703279MB
Jul 26 02:52:51 dev01 vbbu:     End Clone export. 00:01:12
Jul 26 02:52:51 dev01 vbbu:     Begin VM restore state
Jul 26 02:52:53 dev01 vbbu:     End VM restore state. 00:00:02
Jul 26 02:52:53 dev01 vbbu:     Begin VM register for OVA export : [di3-20190726-025135-vboxbu] [running]
Jul 26 02:52:53 dev01 vbbu:     End VM register for OVA export. 00:00:00
Jul 26 02:52:53 dev01 vbbu:     Begin OVA export: [di3-20190726-025135.ova]
Jul 26 02:52:53 dev01 vbbu:      Disk free before OVA export /mnt/lv001-r0/backup/vms : 1703279MB
Jul 26 02:56:16 dev01 vbbu:       OVA size: 2672MB
Jul 26 02:56:16 dev01 vbbu:      Disk free after OVA export /mnt/lv001-r0/backup/vms : 1700607MB
Jul 26 02:56:16 dev01 vbbu:     End OVA export. 00:03:23
Jul 26 02:56:16 dev01 vbbu:     Begin VM unregister from OVA export : [di3-20190726-025135-vboxbu] [running]
Jul 26 02:56:16 dev01 vbbu:     End VM unregister from OVA export. 00:00:00
Jul 26 02:56:16 dev01 vbbu:     Begin VM move from export to backup : [di3]
Jul 26 02:56:16 dev01 vbbu:      Disk free before move to backup /mnt/usb1/backup/vms/di3/di3.20190726-025135 : 4849839MB
Jul 26 02:56:18 dev01 vbbu:       Backup folder size: 2672MB
Jul 26 02:56:18 dev01 vbbu:      Disk free after move to backup /mnt/usb1/backup/vms/di3/di3.20190726-025135 : 4847166MB
Jul 26 02:56:18 dev01 vbbu:     End VM move.  00:00:02
Jul 26 02:56:18 dev01 vbbu: -- [di3] End backup [State:running] 00:04:43
Jul 26 02:56:18 dev01 vbbu: -- [dvl001] Start backup [State:running] [Days:Thu] [Type:ova] [Shutdown:savestate]
Jul 26 02:56:18 dev01 vbbu:     Begin VM savestate
Jul 26 02:56:21 dev01 vbbu:     End VM savestate. 00:00:03
Jul 26 02:56:21 dev01 vbbu:     Begin Clone : [dvl001-20190726-025618-vboxbu]
Jul 26 02:56:21 dev01 vbbu:      Disk free before clonevm /mnt/lv001-r0/backup/vms : 1710904MB
Jul 26 02:58:09 dev01 vbbu:       Exportdir size: 11368MB
Jul 26 02:58:09 dev01 vbbu:      Disk free after clonevm /mnt/lv001-r0/backup/vms : 1699536MB
Jul 26 02:58:09 dev01 vbbu:     End Clone export. 00:01:48
Jul 26 02:58:09 dev01 vbbu:     Begin VM restore state
Jul 26 02:58:11 dev01 vbbu:     End VM restore state. 00:00:02
Jul 26 02:58:11 dev01 vbbu:     Begin VM register for OVA export : [dvl001-20190726-025618-vboxbu] [running]
Jul 26 02:58:11 dev01 vbbu:     End VM register for OVA export. 00:00:00
Jul 26 02:58:11 dev01 vbbu:     Begin OVA export: [dvl001-20190726-025618.ova]
Jul 26 02:58:11 dev01 vbbu:      Disk free before OVA export /mnt/lv001-r0/backup/vms : 1699536MB
Jul 26 03:03:52 dev01 vbbu:       OVA size: 4499MB
Jul 26 03:03:52 dev01 vbbu:      Disk free after OVA export /mnt/lv001-r0/backup/vms : 1695036MB
Jul 26 03:03:52 dev01 vbbu:     End OVA export. 00:05:41
Jul 26 03:03:52 dev01 vbbu:     Begin VM unregister from OVA export : [dvl001-20190726-025618-vboxbu] [running]
Jul 26 03:03:52 dev01 vbbu:     End VM unregister from OVA export. 00:00:00
Jul 26 03:03:52 dev01 vbbu:     Begin VM move from export to backup : [dvl001]
Jul 26 03:03:52 dev01 vbbu:      Disk free before move to backup /mnt/usb1/backup/vms/dvl001/dvl001.20190726-025618 : 4847166MB
Jul 26 03:03:56 dev01 vbbu:       Backup folder size: 4499MB
Jul 26 03:03:56 dev01 vbbu:      Disk free after move to backup /mnt/usb1/backup/vms/dvl001/dvl001.20190726-025618 : 4842667MB
Jul 26 03:03:56 dev01 vbbu:     End VM move.  00:00:04
Jul 26 03:03:56 dev01 vbbu: -- [dvl001] End backup [State:running] 00:07:38
Jul 26 03:03:56 dev01 vbbu: -- [scbase] cannot backup. VM day mismatch. [VM days:Sun] [Today:Thu or 25]
Jul 26 03:03:56 dev01 vbbu: -- [di4] Start backup [State:running] [Days:] [Type:ova] [Shutdown:savestate]
Jul 26 03:03:56 dev01 vbbu:     Begin VM savestate
Jul 26 03:04:00 dev01 vbbu:     End VM savestate. 00:00:04
Jul 26 03:04:00 dev01 vbbu:     Begin Clone : [di4-20190726-030356-vboxbu]
Jul 26 03:04:00 dev01 vbbu:      Disk free before clonevm /mnt/lv001-r0/backup/vms : 1710904MB
Jul 26 03:05:03 dev01 vbbu:       Exportdir size: 6289MB
Jul 26 03:05:03 dev01 vbbu:      Disk free after clonevm /mnt/lv001-r0/backup/vms : 1704615MB
Jul 26 03:05:03 dev01 vbbu:     End Clone export. 00:01:03
Jul 26 03:05:03 dev01 vbbu:     Begin VM restore state
Jul 26 03:05:05 dev01 vbbu:     End VM restore state. 00:00:02
Jul 26 03:05:05 dev01 vbbu:     Begin VM register for OVA export : [di4-20190726-030356-vboxbu] [running]
Jul 26 03:05:05 dev01 vbbu:     End VM register for OVA export. 00:00:00
Jul 26 03:05:05 dev01 vbbu:     Begin OVA export: [di4-20190726-030356.ova]
Jul 26 03:05:05 dev01 vbbu:      Disk free before OVA export /mnt/lv001-r0/backup/vms : 1704615MB
Jul 26 03:08:10 dev01 vbbu:       OVA size: 2514MB
Jul 26 03:08:10 dev01 vbbu:      Disk free after OVA export /mnt/lv001-r0/backup/vms : 1702101MB
Jul 26 03:08:10 dev01 vbbu:     End OVA export. 00:03:05
Jul 26 03:08:10 dev01 vbbu:     Begin VM unregister from OVA export : [di4-20190726-030356-vboxbu] [running]
Jul 26 03:08:10 dev01 vbbu:     End VM unregister from OVA export. 00:00:00
Jul 26 03:08:10 dev01 vbbu:     Begin VM move from export to backup : [di4]
Jul 26 03:08:10 dev01 vbbu:      Disk free before move to backup /mnt/usb1/backup/vms/di4/di4.20190726-030356 : 4842667MB
Jul 26 03:08:12 dev01 vbbu:       Backup folder size: 2514MB
Jul 26 03:08:12 dev01 vbbu:      Disk free after move to backup /mnt/usb1/backup/vms/di4/di4.20190726-030356 : 4840152MB
Jul 26 03:08:12 dev01 vbbu:     End VM move.  00:00:02
Jul 26 03:08:12 dev01 vbbu: -- [di4] End backup [State:running] 00:04:16
Jul 26 03:08:12 dev01 vbbu: -- [dvl002] cannot backup. VM day mismatch. [VM days:Fri] [Today:Thu or 25]
```
---
   Copyright (C) 2019  GuideLoom Inc./Trevor Paquette

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.
