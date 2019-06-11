#!/bin/bash

#   vbbu - Virtualbox Backup
#
#   Copyright (C) 2019  GuideLoom Inc./Trevor Paquette
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# version number of script
version=2.15

# option eval order
#    commandline > machine config > global config > defaults
# translation: command line options override conf file options which override defaults
#
# ex:  type default       -> clone
#      global config file -> ova
#      machine config file-> clone
#      command line       -> ova
#  
#     Command line wins. Type will be set to ova

# conf file
masterconffile=/etc/vbbu.conf

# location of individual VM overrides/options
confdir=/etc/vbbu.d

# ignore VM config files under confdir
noconf=0

# export dir
# Ideally this is FAST ssd disk for writing. Initial exports are stored here. This minimizes "downtime" for a VM.
# You'll need enough space to export a clone of your largest system + if doing ova backups, additional space to write the OVA export to.
# Both exportdir and backupdir should already exist, and be writeable by the user running this backup
# Which should also be the same user running the virtualbox process(es)
exportdir=/mnt/lv001-r0/backup/vms

# When export is complete, the file is moved to backupdir
# actual VM backups are in a new subfolder named for each VM
backupdir=/mnt/usb1/backup/vms

# number of versions to keep, in addition to main backup
versions=2

# should we send logs to syslog; 0=no, 1=yes
syslog=0

# syslog identifier
syslogid=vbbu

# where to send email to
# future placeholder
email=root

# filename of VMs to backup
list=""

# backup only VMs in this state.
clistate=""
confstate=""

# type of backup to create. ova or clone
clitype=""
conftype=""
backuptype="ova"

# DRY run/echo commands, don't run them.
# 0 = off, 1 = on
dryrun=0

# MASTER safety run switch.
# this MUST be set to 1 in order for the script to do anything.
# Too many time I've "accidently" kicked off a backup without menaing to.
# and put machines into a "paused" state.. grr..
runbackup=0

# list of VMs to backup
vms=""
vm=""

#sed command to strip blank lines and comments
sedsbc='sed -e '/^\s*#.*$/d' -e '/^\s*$/d''

# set timeformat to display
timeformat="%Y%m%d-%H%M%S"

# low level scheduling. Set day(s) to run
# If number, then day is day of month: value from 01 to 31
#    hint:  day number must be 2 digits long; ex: 02
# If string, then day is shortforn day of week: Sun, Mon, Tue, Wed, Thu, Fri, Sat
# all values are SPACE or comma seperated 
# if the word "never" is present, then this VM is never backed up
days=""
daysarray=""

# get todays name: Sun..Sat
dayname=$(date +%a)
# get todays number: 01..31
daynum=$(date +%d)

# set to 1 if --nodays set. Ignore Day option in conf file
nodays=0

# backupvm flag. set on case by case basis
backupvm=0
# if backup not allowed, set this to the reason why
backupreason=""

# tag to use to identify clones and backups created by us. We don't back these up at all
# vms ending this this, we ignore completly, in case backups "overlap"
backuptag="-vboxbu"

# issue acpishutdown instead of savestate.
# Fixes bug in vbox 5.X sometimes causes kernel panic on vm restart for Ubuntu 18
# Fixed in virtualbox 6.0.8(?)
# ** acpid MUST be installed for this to work correctly
# sample acpi files
#/etc/acpi/power.sh
#  #!/bin/bash
#  /sbin/shutdown -h now "Power button pressed"
#
#/etc/acpi/events/power
#  event=button/power
#  action=/etc/acpi/power.sh "%e"
#
#/etc/default/acpid
#  OPTIONS="-l"
#  MODULES="all"
#
# restart acpid daemon : /etc/init.d/acpid restart
acpi=0

# =======================================================
usage () {
  echo "Usage: $0 [--verbose] [--syslog] [--syslogid SYSLOG_ID_STRING] [--dryrun] [--help|-h]"
  echo "          [--list PATH_TO_VM_FILE_LIST] [--state running|stopped|paused|saved|poweroff] [--type ova|clone]"
  echo "          [--exportdir PATH_TO_VM_EXPORT_FOLDER] [--backupdir PATH_TO_VM_BACKUP_FOLDER] [--confdir PATH_TO_CONF_FILES"
  echo "          [--acpi] [--noconf] [--nodays] [--runbackup]"
  echo "          [--versions N] [VMNAME|VMUUID]..."
  echo ""
  echo " Version : ${version}"
  echo "       --verbose     = print lines as they run. Useful for debugging only"
  echo "       --syslog      = send output to syslog as well as stdout [Default: Off]"
  echo "       --syslogid    = syslog id string to send to syslog [Default: ${syslogid}]"
  echo "       --list        = full path to list of VMs to backup."
  echo "                          ONE VM per line. Comments (lines starting with #) allowed. Format is:"
  echo "                              vmname"
  echo "       --noconf      = do not use config files. Master conf file/vm conf files under conf folder (/etc/vbbu.d) are ignored."
  echo "       --nodays      = ignore days option in all conf files. Translation: run every day. [Default: off]"
  echo "       --state       = only backup VMs whose status is one of running|stopped|paused|saved|poweroff. [Default: not set, aka any]"
  echo "       --type        = type of backup to create. One of ova|clone. [Default: ${backuptype}]" 
  echo "       --exportdir   = path to temporary export directory, [Default: ${exportdir}]"
  echo "                         Initial export location and for systems that require minimal downtime, make this local SSD for speed"
  echo "       --backupdir   = path to final backup directory. [Default: ${backupdir}]"
  echo "                         Once export is completed, and systems are running again, backup files are moved here."
  echo "       --versions    = number of versions to keep in BACKUPDIR. [Default: ${versions}]"
  echo "       --acpi        = issue acpishutdown instead of savestate. Fixes bug in vbox 5.X sometimes causes kernel panic on vm restart."
  echo "       --dryrun     = Limited run. Display commands, and do not run them. [Default: off]"
  echo "       --help        = this help info"
  echo "       --runbackup   = Actually run. Safety switch. Prevents accidently running backups and "pausing" VMs"
  echo ""
  echo "       VMNAME|VMUUID = VM to backup. Can list more then one. If not set, fallback to list."
  echo ""
  echo "  Note: Options can also be set in ${masterconffile} or ${confdir}/VMNAME.conf"
  echo ""
}

# =======================================================
run () {
  if [[ "${dryrun}" -eq 1 ]]; then
    printf "%s\n" "$*"
    return 0
  fi

  eval "$@"
}

# =======================================================
# log a single line function
log() {

  local logtimestamp

  logtimestamp=$(date +${timeformat})
    
  # echo the log message
  printf "%s\n" "${logtimestamp} $*"

  # If syslog is enabled, also log the message to syslog
  if [[ "${syslog}" -eq 1 ]]; then
    printf "%s\n" "$*" | logger -t "${syslogid}"
  fi
}

# =======================================================
# log a complete file
logfile() {

  local file

  file="$*"
    
  if [[ "${file}" != "" ]]; then 
    if [[ -f "${file}" ]]; then
      cat "${file}" | gawk -v TIMEFORMAT="${timeformat}" '{ print strftime(TIMEFORMAT), $0 }'
      # If syslog is enabled, also log the message to syslog
      if [[ "${syslog}" -eq 1 ]]; then
        logger -t "${syslogid}" -f "$@"
      fi
    else
      log "logfile ${file} not found. Cannot log it."
    fi
  fi
}

# =======================================================
secstohms() {
  local h
  local m
  local s
    
  ((h=${1}/3600))
  ((m=(${1}%3600)/60))
  ((s=${1}%60))

  printf "%02d:%02d:%02d\n" $h $m $s
}

# =======================================================
# is arguement passed a number
isnum() {
 gawk -v a="$1" 'BEGIN {print (a == a + 0)}';
}

# =======================================================
array_contains () {
  # return 1 if sucessful, found
  # return 0 if error, not found
    
  local array="$1[@]"
  local item=$2
  local in=0
  local element
  
  for element in "${!array}"; do
    if [[ $element == $item ]]; then
      in=1
      break
    fi
  done

  echo $in
}

# =======================================================
getconfopt () {
  # get config option from conf file
  # 1st arg = filename to use
  # 2nd arg = option to search for
    
  # option to look for in the files is option=value

  local file=$1
  local option=$2
  local result=""
  
  result=""

  # read config file value, only if --noconf is not set
  if [[ "${noconf}" -eq 0 ]]; then
  
    # convert option to lowercase
    option=$(printf "%s" "${option}" | tr '[A-Z]' '[a-z]')
  
    if [[ -f "${file}" ]]; then
      result=$(grep -E "^${option}=" ${file} | cut -d= -f2)
    fi
  fi
  
  echo "${result}"
}

loadconfdefaults() {
  local value
    
  # load config defaults that may override the builtin defaults above
  # set global variables accordingly

  if [[ ! -f "${masterconffile}" ]]; then
    return 1
  fi
  
  # look far conf dir
  value=$(getconfopt "${masterconffile}" "confdir")
  if [[ "${value}" != "" ]]; then confdir="${value}"; fi

  # look for exportdir
  value=$(getconfopt "${masterconffile}" "exportdir")
  if [[ "${value}" != "" ]]; then exportdir="${value}"; fi

  # look for backupdir
  value=$(getconfopt "${masterconffile}" "backupdir")
  if [[ "${value}" != "" ]]; then backupdir="${value}"; fi

  # look for versions
  value=$(getconfopt "${masterconffile}" "versions")
  if [[ "${value}" != "" ]]; then versions="${value}"; fi

  # look for syslog
  value=$(getconfopt "${masterconffile}" "syslog")
  if [[ "${value}" != "" ]]; then syslog="${value}"; fi

  # look for syslog identifier
  value=$(getconfopt "${masterconffile}" "syslogid")
  if [[ "${value}" != "" ]]; then syslogid="${value}"; fi

  # look for email to send to
  value=$(getconfopt "${masterconffile}" "email")
  if [[ "${value}" != "" ]]; then email="${value}"; fi

  # look for VM list file
  value=$(getconfopt "${masterconffile}" "list")
  if [[ "${value}" != "" ]]; then list="${value}"; fi

  # look for state
  value=$(getconfopt "${masterconffile}" "state")
  if [[ "${value}" != "" ]]; then state="${value}"; fi

  # look for backup type
  value=$(getconfopt "${masterconffile}" "backuptype")
  if [[ "${value}" != "" ]]; then backuptype="${value}"; fi

  # look for dryrun
  value=$(getconfopt "${masterconffile}" "dryrun")
  if [[ "${value}" != "" ]]; then dryrun="${value}"; fi

  # look for runbackup
  value=$(getconfopt "${masterconffile}" "runbackup")
  if [[ "${value}" != "" ]]; then runbackup="${value}"; fi

  # look for runbackup
  value=$(getconfopt "${masterconffile}" "acpi")
  if [[ "${value}" != "" ]]; then acpi="${value}"; fi

  return 0
}

# --------------------------------------------------------------------------------
# main start

# display command line used to run
log "$0 ($version) command line : $0 $*"

# get configuration overrides from master conf file
loadconfdefaults

# get any commandline arguments
while [ "$1" != "" ]; do
  case $1 in
    --state ) shift; clistate=$1
                ;;
    --list ) shift; list=$1
               ;;
    --vm ) shift; vm="${vm} $1"
           ;;
    --versions ) shift; versions=$1
                 ;;
    --exportdir ) shift; exportdir=$1
                 ;;
    --backupdir ) shift; backupdir=$1
                 ;;
    --type ) shift; clitype=$1
                 ;;
    --verbose ) set -vx
                ;;
    --syslog ) syslog=1
               ;;
    --noconf ) noconf=1
               ;;
    --runbackup ) runbackup=1
                  ;;
    --nodays ) nodays=1
               ;;
    --acpi ) acpi=1
             ;;
    --syslogid ) shift; syslogid=$1
                 ;;
    --confdir ) shift; confdir=$1
                 ;;
    --dryrun ) dryrun=1
                   ;;
    -h | --help ) usage
                  exit
                  ;;
    -* ) echo "Unknown option \"$1\""
         usage
         exit
         ;;
    * ) vm="${vm} $1"
        ;;

  esac
  shift
done

# check master safety switch first. Must be set to 1 to continue
if [[ "${runbackup}" == "0" ]]; then
  echo "Runbackup not set. Safety switch executing. Exiting."
  exit 1
fi

# sanity checks
# make sure the commands we need to run are available
commlist="vboxmanage df logger cat gawk grep"
for comm in ${commlist}; do
  command -v ${comm} >& /dev/null
  status=$?
  if [[ ${status} -ne 0 ]]; then
    log "Error: ${comm} command not found. Check your executable path or not installed. Exiting."
    exit 1
  fi
done

# check arguments to make sure they make sense
# check clistate
case "${clistate}" in
  running | stopped | paused | saved | poweroff | "" ) ;;
  * ) usage
      exit
esac

# check backup type
case "${clitype}" in
  ova | clone | "" ) ;;
  * ) usage
      exit
esac

#check versions
if [[ $(isnum "${versions}") != "1" ]]; then
  echo "Error: versions must be a number. Exiting."
  exit 1
fi

# Make sure BACKUPDIR is set
if [[ "${backupdir}" == "" ]]; then
  log "Error: Variable backupdir not set. Exiting."
  exit 1
elif [[ ! -d "${backupdir}" ]]; then
  # backupdir does not exist. Try to create it.
  run mkdir -p "${backupdir}"
  status=$?
  if [[ ${status} -ne 0 ]]; then
    log "Backupdir [${backupdir}] not found or cannot create. Exiting."
    exit 1
  fi
fi

# backupdir exists. Make sure we can create files in it
testfile="${backupdir}"/testfile$$
run touch "${testfile}"
status=$?
if [[ ${status} -ne 0 ]]; then
  log "Cannot create files under ${backupdir}. Exiting."
  exit 1
else
  # Success. We have a working BACKUPDIR. Remove testfile
  run /bin/rm -f "${testfile}"
fi

# Make sure EXPORTDIR is set
if [[ "${exportdir}" == "" ]]; then
  # Not set? Fall back to folder under BACKUPDIR
  exportdir=${backupdir}/export$$
  log "Exportdir not set. Using ${exportdir} instead."
fi
# check if EXPORTDIR exists or we can create it
if [[ ! -d "${exportdir}" ]]; then
  # exportdir does not exist. Try to create it.
  run mkdir -p "${exportdir}"
  status=$?
  if [[ ${status} -ne 0 ]]; then
    log "Exportdir [${exportdir}] not found or cannot create. Exiting."
    exit 1
  fi
fi

# Exportdir exists. Make sure we can create files in it
testfile="${exportdir}"/testfile$$
run touch "${testfile}"
status=$?
if [[ ${status} -ne 0 ]]; then
  log "Cannot create files under ${exportdir}. Exiting."
  exit 1
else
  # Success. We have a working EXPORTDIR. Remove testfile
  run /bin/rm -f "${testfile}"
fi

# Temporary working folder and log file location
tmplog="${exportdir}"/tmpvbackup$$.log

# figure out what VMs to backup
# VM UUIDs passwd?
if [[ "${vm}" != "" ]]; then
  vms="${vm}"
else
  # get list of VMs from file
  if [[ "${list}" != "" ]]; then
    # if list of VMs exists use that
    if [[ -f "${list}" ]]; then
      # grab the candidate list from the file
      vms=$(cat "${list}" | ${sedsbc} | awk '{print $1}')
    else
      log "VM list [${list}] is not a file. Exiting."
      exit 1
    fi
  else
    if [[ "${vms}" == "" ]]; then
      vms=$(vboxmanage list vms | rev | cut -d' ' -f1 | rev)
    fi
  fi
fi

# loop through the list of VMs to backup
for vm in ${vms}; do

  # get VM UUID
  vmuuid=$(vboxmanage showvminfo --machinereadable "${vm}" | grep -E "^UUID=" | cut -d'"' -f2)
  # Get VM friendly name
  vmname=$(vboxmanage showvminfo --machinereadable "${vm}" | grep -E "^name=" | cut -d'"' -f2)
  
  if [[ "${vmuuid}" == ""  || "${vmname}" == "" ]]; then
    log "-- ${vm} does not exist or not found? Skipping."
  elif [[ ${vmname} = *" "* ]]; then
    log "-- [${vmname}] VMs with space in their names are not supported at this time. Skipping"
  else 
 
    # we have a candidate to backup
    # set the backupvm flag to 1
    # check the backup condisitons. If any fail, set backupvm flag to 0  
    backupvm=1
    backupreason=""  

    # Get the vm state
    state=$(vboxmanage showvminfo "${vmname}" --machinereadable | grep -E "^VMState=" | cut -d'"' -f2)
 
    # check state match
    # check for cli state oerride
    if [[ "${clistate}" != "" ]]; then
      if [[ "${clistate}" != "${state}" ]]; then
        backupvm=0
        backupreason="-- [${vmname}] cannot backup. VM and cli state mismatch. [VM State:${state}] [CLI State:${clistate}]"
      fi
    else
      # check for config file state override
      confstate=$(getconfopt "${confdir}/${vmname}.conf" "state")

      if [[ "${confstate}" != "" ]]; then
        log "   ["${vmname}"] config file state override : ${confstate}"
        if [[ "${confstate}" != "${state}" ]]; then
          backupvm=0
          backupreason="-- [${vmname}] cannot backup. VM and conf file mismatch. [VM State:${state}] [Conf State:${confstate}]"
        fi
      fi
    fi

    # check day match
    # if --nodays not set
    if [[ "${nodays}" -eq 0 ]]; then
      # get days to run backup for this vm
      days=$(printf "%s" $(getconfopt "${confdir}/${vmname}.conf" "days") | sed -e 's/,/ /g')

      # if days is set, check if "today" matches
      if [[ "${days}" != "" ]]; then
        daysarray=($days)

        # check to see if "today" (name or number) is in the days array
        if [[ $(array_contains daysarray ${dayname}) -eq 0 && $(array_contains daysarray ${daynum}) -eq 0 ]]; then
          backupvm=0
          backupreason="-- [${vmname}] cannot backup. VM day mismatch. [VM days:${days}] [Today:${dayname} or ${daynum}]"
        fi

        # check to see if "today" (name or number) is in the days array
        if [[ $(array_contains daysarray "never") -eq 1 ]]; then
          backupvm=0
          backupreason="-- [${vmname}] cannot backup. VM set to never backup. [VM days:${days}]"
        fi

      fi
    fi
    
    # by default we issue a savestate
    shutcomm="savestate"

    # check for acpi override
    if [[ "${acpi}" -eq 1 ]]; then
      shutcomm="acpipowerbutton"
    else
      # check for config file state override
      confacpi=$(getconfopt "${confdir}/${vmname}.conf" "acpi")

      if [[ "${confacpi}" -eq 1 ]]; then
        log "   ["${vmname}"] config file acpi override : ${confacpi}"
        shutcomm="acpipowerbutton"
      fi
    fi

    # check for backup type override
    if [[ "${clitype}" != "" ]]; then
      backuptype="${clitype}"
    else
      # check for config file state override
      conftype=$(getconfopt "${confdir}/${vmname}.conf" "type")

      if [[ "${conftype}" != "" ]]; then
        log "   ["${vmname}"] config file type override : ${conftype}"
        backuptype="${conftype}"
      fi
    fi
    
    # ignore vms having the backuptag at the end. These are leftovers from previous backups, or are still running
    if [[ "${vmname}" =~ ${backuptag}$ ]]; then
      backupvm=0
      backupreason="-- [${vmname}] cannot backup. This is a leftover? clone from a previous backup. [VM State:${state}]"
    fi

    # if all backup checks passed.. backup the VM
    if [[ "${backupvm}" -eq 1 ]]; then
      # start time of vm loop
      vmstartsec=$(date +%s)

      timestamp=$(date +${timeformat})
       
      # We have a match.. begin backup
      log "-- [${vmname}] Start backup [State:${state}] [Days:${days}] [Type:${backuptype}] [Shutdown:${shutcomm}]"

      # Delete old TMPLOG, jic
      run /bin/rm -f "${tmplog}"

      savestatestatus=0
      # If the VM is running or paused, save its state. Need this to "resume" it after backing up
      if [[ "${state}" == "running" || "${state}" == "paused" ]]; then

        log "    Begin VM ${shutcomm}"
        SECONDS=0
        if [[ "${dryrun}" -eq 1 ]]; then
          echo vboxmanage controlvm "${vmname}" "${shutcomm}"
          savestatestatus=0
        else
          vboxmanage controlvm "${vmname}" "${shutcomm}" >& "${tmplog}"
          savestatestatus=$?
        fi


        # if acpi shutdown we MUST wait for the VM state to change to "poweroff"
        if [[ "${shutcomm}" == "acpipowerbutton" ]]; then
          if [[ "${dryrun}" -eq 1 ]]; then
            waitstate="poweroff"
          else
            waitstate=$(vboxmanage showvminfo "${vmname}" --machinereadable | grep -E "^VMState=" | cut -d'"' -f2)
          fi

          while [ "${waitstate}" != "poweroff" ]; do
            log "    Waiting for VM to shutdown"
            sleep 5
            waitstate=$(vboxmanage showvminfo "${vmname}" --machinereadable | grep -E "^VMState=" | cut -d'"' -f2)
          done
        fi

        duration=$(secstohms $SECONDS)
        # only log output if error
        if [[ ${savestatestatus} -ne 0 ]]; then logfile "${tmplog}" ; fi
        log "    End VM ${shutcomm}. $duration"
      fi
      
      # If savestate was sucessfull, being the backup
      if [[ ${savestatestatus} -eq 0 ]]; then

        # create backup
        # Step 1 create VM clone. MUCH faster then exporting to OVA.
        # Reasoning: Minimize system downtime. Convert to OVA, if needed, AFTER cloning is completed

        freedisk=$(df -k "${exportdir}"/. | grep /dev | awk '{print $4}')
        log "    Disk free before clonevm ${exportdir} : $(( ${freedisk} / 1024 ))MB"

        backupname="${vmname}-${timestamp}${backuptag}"
        log "    Begin Clone : [${backupname}]"
        SECONDS=0
        if [[ "${dryrun}" -eq 1 ]]; then
          echo vboxmanage clonevm "${vmname}" --mode all \
                    --basefolder "${exportdir}" --name "${backupname}"
          backupstatus=0
        else
          vboxmanage clonevm "${vmname}" --mode all \
                    --basefolder "${exportdir}" --name "${backupname}" >& "${tmplog}"
          backupstatus=$?
        fi
        duration=$(secstohms $SECONDS)
        # only log output if error
        if [[ ${backupstatus} -ne 0 ]]; then logfile "${tmplog}" ; fi
        freedisk=$(df -k "${exportdir}"/. | grep /dev | awk '{print $4}')
        log "    Disk free after clonevm ${exportdir} : $(( ${freedisk} / 1024 ))MB"
        log "    End Clone export. $duration"

        # put vm back into original state, regardless of backupstatus
        if [[ "${state}" == "running" || "${state}" == "paused" ]]; then
          log "    Begin VM restore state"
          SECONDS=0
          if [[ "${dryrun}" -eq 1 ]]; then
            echo vboxmanage startvm "${vmname}" --type headless
            startstatus=0
          else
            vboxmanage startvm "${vmname}" --type headless >& "${tmplog}"
            startstatus=$?
          fi
          # only log output if error
          if [[ ${startstatus} -ne 0 ]]; then logfile "${tmplog}" ; fi

          # you have to "start the VM becore you can put it back a pause state again..
          if [[ "${state}" == "paused" ]]; then
            # if state was pasued.. put it back into a paused state
            if [[ "${dryrun}" -eq 1 ]]; then
              echo vboxmanage controlvm "${vmname}" pause
              pausestatus=0
            else
              vboxmanage controlvm "${vmname}" pause >& "${tmplog}"
              pausestatus=$?
            fi
            # only log output if error
            if [[ ${pausestatus} -ne 0 ]]; then logfile "${tmplog}" ; fi
            log "    End VM restore state. $duration"
          fi
          duration=$(secstohms $SECONDS)
          log "    End VM restore state. $duration"
        fi
             
        # if clone was sucessful and we have to export to OVA
        if [[ "${backuptype}" == "ova" && ${backupstatus} -eq 0 ]]; then
          # create OVA export from VM
          # We can only create an export from a "registered" vm.
          # register this "clone", then create an OVA eport from it.

          log "    Begin VM register for OVA export : [${backupname}] [${state}]"
          SECONDS=0
          if [[ "${dryrun}" -eq 1 ]]; then
            echo vboxmanage registervm "${exportdir}/${backupname}/${backupname}.vbox"
            registerstatus=0
          else
            vboxmanage registervm "${exportdir}/${backupname}/${backupname}.vbox" >& "${tmplog}"
            registerstatus=$?
          fi
          duration=$(secstohms $SECONDS)
          # only log output if error
          if [[ ${registerstatus} -ne 0 ]]; then logfile "${tmplog}" ; fi
          log "    End VM register for OVA export. $duration"
            
          freedisk=$(df -k "${exportdir}"/. | grep /dev | awk '{print $4}')
          log "    Disk free before OVA export ${exportdir} : $(( ${freedisk} / 1024 ))MB"

          ovaname="${vmname}-${timestamp}.ova"
          log "    Begin OVA export: [${ovaname}]"
          SECONDS=0
          if [[ "${dryrun}" -eq 1 ]]; then
            echo vboxmanage export "${backupname}" --output "${exportdir}/${ovaname}"
            backupstatus=0
          else
            vboxmanage export "${backupname}" --output "${exportdir}/${ovaname}" &> "${tmplog}"
            backupstatus=$?
          fi
          duration=$(secstohms $SECONDS)
          # only log output if error
          if [[ ${backupstatus} -ne 0 ]]; then logfile "${tmplog}" ; fi

          freedisk=$(df -k "${exportdir}"/. | grep /dev | awk '{print $4}')
          log "    Disk free after OVA export ${exportdir} : $(( ${freedisk} / 1024 ))MB"

          log "    End OVA export. $duration"

          log "    Begin VM unregister from OVA export : [${backupname}] [${state}]"
          SECONDS=0
          if [[ "${dryrun}" -eq 1 ]]; then
            echo vboxmanage unregistervm "${backupname}"
            registerstatus=0
          else
            vboxmanage unregistervm "${backupname}" >& "${tmplog}"
            registerstatus=$?
          fi
          duration=$(secstohms $SECONDS)
          # only log output if error
          if [[ ${registerstatus} -ne 0 ]]; then logfile "${tmplog}" ; fi
          log "    End VM unregister from OVA export. $duration"
        fi

        if [[ ${backupstatus} -eq 0  ]]; then
          # backup was sucessful
          # move export to backup folder
          # yes.. double up on the vmname. this puts all the backups for the same vm in the same folder
          backupfolder=${backupdir}/${vmname}/${vmname}

          # remove oldest verison, and cycle rest
          for ((i=${versions}; i>=0; i--)); do
            if [[ ${i} -eq ${versions} ]]; then
              run /bin/rm -rf "${backupfolder}.${i}"
            elif [[ ${i} -eq 0 && ${versions} -gt 0 ]]; then
              if [[ -d "${backupfolder}" ]]; then
                run mv "${backupfolder}" "${backupfolder}.1"
              fi
            else
              j=$(( i + 1 ))
              if [[ -d "${backupfolder}.${i}" ]]; then
                run mv "${backupfolder}.${i}" "${backupfolder}.${j}"
              fi
            fi
          done
                    
          # Make latest backup folder
          run mkdir -p "${backupfolder}"

          freedisk=$(df -k "${backupfolder}"/. | grep /dev | awk '{print $4}')
          log "    Disk free before move to backup ${backupfolder} : $(( ${freedisk} / 1024 ))MB"

          # move export file to backup folder
          log "    Begin VM move from export to backup : [${vmname}]"
          SECONDS=0
          if [[ "${type}" == "clone" ]]; then
            # move clone
            run mv "${exportdir}/${backupname}" "${backupfolder}"
          else
            # move ova file
            run mv "${exportdir}/${ovaname}" "${backupfolder}"
            # remove clone as no longer needed
            run /bin/rm -rf "${exportdir}/${backupname}"
          fi
          duration=$(secstohms $SECONDS)
          freedisk=$(df -k "${backupfolder}"/. | grep /dev | awk '{print $4}')
          log "    Disk free after move to backup ${backupfolder} : $(( ${freedisk} / 1024 ))MB"

          log "    End VM move.  $duration"

        else
          log "  Backup failed for ${backupname}. Check log."
          # remove possible failed clone remnants..
          run /bin/rm -rf "${exportdir}/${backupname}"
        fi
            
      else
        log "  Savestate failed. Cannot backup [${vmname}]. See log."
      fi
      run /bin/rm -f "${tmplog}"
      # end time of vm loop
      vmendsec=$(date +%s)
      duration=$(secstohms $(( vmendsec - vmstartsec )))

      log "-- [${vmname}] End backup [${state}] $duration"
    else
      log "${backupreason}"
    fi
  fi
done

exit 0
