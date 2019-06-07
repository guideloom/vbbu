# vbbu

## Virtualbox BackUp v2.11

A script to run backups on VMs running under Virtualbox on Linux.

This script will create either clones or OVA export backups on selected VMs. 

Command line options:
```bash
Usage: ./vbbu [--verbose] [--syslog] [--syslogid SYSLOG_ID_STRING] 
          [--list PATH_TO_VM_FILE_LIST] [--state running|stopped|paused|saved|poweroff] [--type ova|clone]
          [--exportdir PATH_TO_VM_EXPORT_FOLDER] [--backupdir PATH_TO_VM_BACKUP_FOLDER]
          [--acpi] [--noconf] [--nodays] [--versions N] 
          [--runbackup] [--dry-run] [--help|-h] [VMNAME|VMUUID]...

 Version : 2.11
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
```

 Note: Options can also be set in /etc/vbbu.conf or /etc/vbbu.d/VMNAME.conf
   Option evaluation order in highest to lowest priority
          command line option
          VMNAME machine config (/etc/vbbu.d/VMNAME.conf)
          global config (/etc/vbbu.conf)
          defaults (variables set in vbbu.sh file)
 
 VMs to backup come are set in the following order
   VMs passed on the command line
   VM file list specified with the --list option
   output from : vboxmanage list vms
 
 vbbu will attempt to put a running VM into "savestate" before running a backup.
 This saves the machine state and closes all attached data files so a backup can occur.
 After the initial clone is completed, the VM will be restarted into it's previous state before the backup.
 
 NOTE: SOME VMs (bug in 5.X?) will encounter a kernel panic when the system is restarted. We noticed this with Ubuntu 18.
       The work around for this is to issue the --acpi option for those Vms only.
       This will issue an acpipowerbutton (power button power off) instead of a savestate.
       IMPORTANT: the acpi daemon MUST be installed for this to work correctly.
```bash
   apt instll acpid
         
   sample acpi files
     /etc/acpi/power.sh
       #!/bin/bash
       /sbin/shutdown -h now "Power button pressed"

     /etc/acpi/events/power
       event=button/power
       action=/etc/acpi/power.sh "%e"
         
     /etc/default/acpid
        OPTIONS="-l"
        MODULES="all"
         
     restart acpid daemon with 
       /etc/init.d/acpid restart
 ```
 
 ## Examples:
 vbbu --syslog --runbackup
   run a backup on all VMs listed by vboxmanage list vms, log all output to syslog
   This should be the most common type used. I have this as my nightly cronjob
   
 vbbu --syslog --runbackup --acpi webserver
   run a backup on the VM called "webserver" and log output to syslog. Issue an acpipowerbutton instead of savestate
   
 vbbu --dry-run --runbackup --type ova --list /etc/vm.lst
   run a dry-run backup on all VMs listed in /etc/vm.lst in ova format
 
 
 
