#!/bin/bash
#
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

# load GL functions
# See https://github.com/guideloom/gl_functions.sh

glfunc_path=/home/vbox/bin/gl_functions.sh

if [[ ! -f ${glfunc_path} ]]; then
  echo "Error: Cannot find GL functions script."
  echo "       Check path ${glfunc_path}."
  echo "       Additional info in gl_functions.sh project @ https://github.com/guideloom"
  echo "       Exiting."
  exit 1
fi

## set umask for folders/files
## not working??
##umask u=rwx,g=rwx,o=rx

# load up the functions
. ${glfunc_path}
    
# version number of script
version=2.32

# variables can be set in one of 4 places, in order of increasing precedent.
# 1) Default     value in this file.
# 2) Global      value in masterconffile
# 3) VM specific value in confdir/vmname.conf
# 4) CLI         value on the commandline
#
# translation: command line options overrides vm conf file, overrides global conf file, which overrides defaults
#
# Naming of a variable.
#   default value      : dflt_var
#   global config file : glob_var
#   vm config file     : vm_var
#   command line       : cli_var
#   actual var used    : var 
#
# example
#   type default       -> clone
#   global config file -> ova  
#   vm config file     -> clone
#   command line       -> ova  
#       
#   Command line wins. var will be set to ova

# conf file
masterconffile=/etc/vbbu.conf

# location of individual VM overrides/options
# this is set here OR in masterconffile only
confdir=/etc/vbbu.d

# filename of VMs to backup
list=""

# MASTER safety run switch.
# this MUST be set to 1 in order for the script to do anything.
# Too many time I've "accidently" kicked off a backup without menaing to.
# and put machines into a "paused" state.. grr..
dflt_runbackup="no"
glob_runbackup=
vm_runbackup=
cli_runbackup=
runbackup=

# set to 1 if --nodays set. Ignore Day option in conf file
dflt_nodays=0
glob_nodays=
vm_nodays=
cli_nodays=
nodays=

# ignore VM config files under confdir
dflt_noconf=0
glob_noconf=
vm_noconf=
cli_noconf=
noconf=

# should we send logs to syslog; 0=no, 1=yes
dflt_syslog=0
glob_syslog=
vm_syslog=
cli_syslog=
syslog=

# syslog identifier, default vbbu
dflt_syslogid="vbbu"
glob_syslogid=
vm_syslogid=
cli_syslogid=
syslogid=

# export dir
# Ideally this is FAST ssd disk for writing. Initial exports are stored here. This minimizes "downtime" for a VM.
# You'll need enough space to export a clone of your largest system + if doing ova backups, additional space to write the OVA export to.
# Both exportdir and backupdir should already exist, and be writeable by the user running this backup
# Which should also be the same user running the virtualbox process(es)
# this is set here OR in masterconffile only
dflt_exportdir="/mnt/lv001-r0/backup/vms"
glob_exportdir=
vm_exportdir=
cli_exportdir=
exportdir=

# When export is complete, the file is moved to backupdir
# actual VM backups are in a new subfolder named for each VM
# this is set here OR in masterconffile only
dflt_backupdir="/mnt/usb1/backup/vms"
glob_backupdir=
vm_backupdir=
cli_backupdir=
backupdir=

# backups are actually moved to a "group" folder under backupdir
dflt_backupgroup=""
glob_backupgroup=
vm_backupgroup=
cli_backupgroup=
backupgroup=

# number of versions to keep, in addition to main backup
# versions are numbered folder, folder.1, folder.2.. etc. highest number is cycled out and others are renamed. Think syslog.
dflt_versions=2
glob_versions=
vm_versions=
cli_versions=
versions=
# OR
# number of days to keep
# this changes the versioning scheme to use ACTUAL date the folder is created. EX: folder.YYYYMMDDHHMM
# folder older then ${daystokeep} are removed.
# **** If set (aka greater than 0) this OVERRIDES ${versions}
dflt_daystokeep=0
glob_daystokeep=
vm_daystokeep=
cli_daystokeep=
daystokeep=

# where to send email to
# future placeholder
dflt_email="root"
glob_email=
vm_email=
cli_email=
email=

# backup only VMs in this state.
# default is not set, aka any state
dflt_state=""
glob_state=
vm_state=
cli_state=
state=

# type of backup to create. ova or clone
dflt_backuptype="ova"
glob_backuptype=
vm_backuptype=
cli_backuptype=
backuptype=

# dryrun setting.. default is off
dflt_dryrun=0
glob_dryrun=
vm_dryrun=
cli_dryrun=
dryrun=

# noconf setting.. default is off
dflt_noconf=""
glob_noconf=
vm_noconf=
cli_noconf=
noconf=

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
dflt_acpi=0
glob_acpi=
vm_acpi=
cli_acpi=
acpi=

# seconds to wait between acpi shutdown checks
dflt_acpiwaittime=5
glob_acpiwaittime=
vm_acpiwaittime=
cli_acpiwaittime=
acpiwaittime=

# number of times to wait for check, otherwise possible infinite loop
dflt_acpiwaitcycles=50
glob_acpiwaitcycles=
vm_acpiwaitcycles=
cli_acpiwaitcycles=
acpiwaitcycles=

# if after acpiwaitcycles, the VM still hasn't shutdown, try a forced poweroff
# yes = try forced poweroff
# no = abandon backup of VM, contineue to next
dflt_acpiwaitpoweroff="no"
glob_acpiwaitpoweroff=
vm_acpiwaitpoweroff=
cli_acpiwaitpoweroff=
acpiwaitpoweroff=

# list of VMs to backup
# just here to initialize the variables
vms=""
vm=""

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

# set timeformat for daystokeep option folder extension
timeformat="%Y%m%d-%H%M%S"

# backupvm flag. set on case by case basis
backupvm=0
# if backup not allowed, set this to the reason why
nobackupreason=""

# tag to use to identify clones and backups created by us. We don't back these up at all
# vms ending in this, we ignore completly, in case backups "overlap"
backuptag="-vbbu"

# =======================================================
usage () {
  echo "Usage: $0 [--verbose] [--syslog] [--syslogid SYSLOG_ID_STRING] [--dryrun] [--help|-h]"
  echo "          [--list PATH_TO_VM_FILE_LIST] [--state running|stopped|paused|saved|poweroff] [--type ova|clone]"
  echo "          [--exportdir PATH_TO_VM_EXPORT_FOLDER] [--backupdir PATH_TO_VM_BACKUP_FOLDER] [--confdir PATH_TO_CONF_FILES]"
  echo "          [--acpi] [--noconf] [--nodays] [--runbackup] [--backupgroup GROUPNAME]"
  echo "          [--acpiwaittime N] [--acpiwaitcycles N] [--acpiwaitpoweroff]"
  echo "          [--versions N] [--daystokeep N] [VMNAME|VMUUID]..."
  echo ""
  echo " Version : ${version}"
  echo "       --verbose      = print lines as they run. Useful for debugging only"
  echo "       --syslog       = send output to syslog as well as stdout [Default: ${dflt_syslog}]"
  echo "       --syslogid     = syslog id string to send to syslog [Default: ${dflt_syslogid}]"
  echo "       --list         = full path to list of VMs to backup"
  echo "       --noconf       = do not use config files. Master conf file/vm conf files under conf folder (/etc/vbbu.d) are ignored"
  echo "       --nodays       = ignore days option in conf files. Translation: run every day. [Default: off]"
  echo "       --state        = only backup VMs whose status is one of running|stopped|paused|saved|poweroff. [Default: not set, aka any]"
  echo "       --type         = type of backup to create. One of ova|clone. [Default: ${dflt_backuptype}]" 
  echo "       --exportdir    = path to temporary export directory, [Default: ${dflt_exportdir}]"
  echo "       --backupdir    = path to final backup directory. [Default: ${dflt_backupdir}]"
  echo "       --backupgroup  = group folder under backup directory. [Default: ${dflt_backupgroup}]"
  echo "       --versions     = number of versions to keep in BACKUPDIR. [Default: ${dflt_versions}]"
  echo "       --daystokeep   = number of days to keep backups for. Ones older are removed. [Default: ${dflt_daystokeep}]"
  echo "                        Note: if daystokeep is set, this OVERRIDES the --versions option."
  echo "       --acpi         = issue acpishutdown instead of savestate. Fixes bug in vbox 5.X sometimes causes kernel panic on vm restart."
  echo "       --acpiwaittime     = number of seconds to wait between acpi shutdown checks. [Default: ${dflt_acpiwaittime}]"
  echo "       --acpiwaitcycles   = number of cycles to check for acpi shutdown. [Default: ${dflt_acpiwaitcycles}]"
  echo "       --acpiwaitpoweroff = if after acpiwaitcycles, the VM still hasn't shutdown, try a forced poweroff, otherwise skip"
  echo "       --dryrun       = Limited run. Display commands, and do not run them. [Default: off]"
  echo "       --help         = this help info"
  echo "       --runbackup    = Actually run. Safety switch. Prevents accidently running backups and pausing VMs"
  echo ""
  echo "       VMNAME|VMUUID  = VM to backup. Can list more then one. If not set, fallback to list."
  echo ""
  echo "  Note: Options can also be set in ${masterconffile} or ${confdir}/VMNAME.conf"
  echo ""
}

# --------------------------------------------------------------------------------
loadconfdefaults() {
  local file
  local value
    
  # if global no config is set.. don't load anything
  if [[ "${gl_noconf}" -eq 1 ]]; then
    return 1
  fi

  # load config defaults that may override the builtin defaults above
  # set global variables accordingly

  file="$1"

  # if conf file not found.. don't load anything
  if [[ "${file}" != "" ]]; then
    if [[ ! -f "${file}" ]]; then
      return 1
    fi
  fi

  # start loading up values
  
  # look for conf dir
  value=$(gl_getconfopt "${file}" "confdir")
  if [[ "${value}" != "" ]]; then confdir="${value}"; fi

  # look for VM list file
  value=$(gl_getconfopt "${file}" "list")
  if [[ "${value}" != "" ]]; then list="${value}"; fi

  # look for exportdir
  value=$(gl_getconfopt "${file}" "exportdir")
  if [[ "${value}" != "" ]]; then glob_exportdir="${value}"; fi

  # look for backupdir
  value=$(gl_getconfopt "${file}" "backupdir")
  if [[ "${value}" != "" ]]; then glob_backupdir="${value}"; fi

  # look for backupgroup
  value=$(gl_getconfopt "${file}" "backupgroup")
  if [[ "${value}" != "" ]]; then glob_backupgroup="${value}"; fi

  # look for versions
  value=$(gl_getconfopt "${file}" "versions")
  if [[ "${value}" != "" ]]; then glob_versions="${value}"; fi

  # look for syslog
  value=$(gl_getconfopt "${file}" "syslog")
  if [[ "${value}" != "" ]]; then glob_syslog="${value}"; fi

  # look for syslog identifier
  value=$(gl_getconfopt "${file}" "syslogid")
  if [[ "${value}" != "" ]]; then glob_syslogid="${value}"; fi

  # look for daystokeep
  value=$(gl_getconfopt "${file}" "daystokeep")
  if [[ "${value}" != "" ]]; then glob_daystokeep="${value}"; fi

  # look for email to send to
  value=$(gl_getconfopt "${file}" "email")
  if [[ "${value}" != "" ]]; then glob_email="${value}"; fi

  # look for state
  value=$(gl_getconfopt "${file}" "state")
  if [[ "${value}" != "" ]]; then glob_state="${value}"; fi

  # look for backup type
  value=$(gl_getconfopt "${file}" "backuptype")
  if [[ "${value}" != "" ]]; then glob_backuptype="${value}"; fi

  # look for dryrun
  value=$(gl_getconfopt "${file}" "dryrun")
  if [[ "${value}" != "" ]]; then glob_dryrun="${value}"; fi

  # look for runbackup
  value=$(gl_getconfopt "${file}" "runbackup")
  if [[ "${value}" != "" ]]; then glob_runbackup="${value}"; fi

  # look for acpi
  value=$(gl_getconfopt "${file}" "acpi")
  if [[ "${value}" != "" ]]; then glob_acpi="${value}"; fi

  # look for acpiwaittime
  value=$(gl_getconfopt "${file}" "acpiwaittime")
  if [[ "${value}" != "" ]]; then glob_acpiwaittime="${value}"; fi

  # look for acpiwaitcycles
  value=$(gl_getconfopt "${file}" "acpiwaitcycles")
  if [[ "${value}" != "" ]]; then glob_acpiwaitcycles="${value}"; fi

  # look for acpiwaitpoweroff
  value=$(gl_getconfopt "${file}" "acpiwaitpoweroff")
  if [[ "${value}" != "" ]]; then glob_acpiwaitpoweroff="${value}"; fi

  # look for nodays
  value=$(gl_getconfopt "${file}" "nodays")
  if [[ "${value}" != "" ]]; then glob_nodays="${value}"; fi

  return 0
}


# --------------------------------------------------------------------------------
# main start

# get configuration overrides from master conf file
loadconfdefaults "${masterconffile}"

# display command line used to run
gl_log "$0 ($version) command line : $0 $*"

# get any commandline arguments
while [ "$1" != "" ]; do
  case $1 in
    --verbose )     set -vx
                    ;;
    --list )        shift; list=$1
                    ;;
    --dryrun )      cli_dryrun=1
                    ;;
    --state )       shift; cli_state=$1
                    ;;
    --versions )    shift; cli_versions=$1
                    ;;
    --daystokeep )  shift; cli_daystokeep=$1
                    ;;
    --exportdir )   shift; cli_exportdir=$1
                    ;;
    --backupdir )   shift; cli_backupdir=$1
                    ;;
    --type )        shift; cli_backuptype=$1
                    ;;
    --syslog )      cli_syslog=1
                    ;;
    --noconf )      cli_noconf=1
                    ;;
    --runbackup )   cli_runbackup="yes"
                    ;;
    --nodays )      cli_nodays=1
                    ;;
    --acpi )        cli_acpi=1
                    ;;
    --acpiwaittime )shift; cli_acpiwaittime=$1
                    ;;
    --acpiwaitcycles )  shift; cli_acpiwaitcycles=$1
                    ;;
    --acpiwaitpoweroff ) cli_acpiwaitpoweroff="yes"
                    ;;
    --syslogid )    shift; cli_syslogid=$1
                    ;;
    --confdir )     shift; cli_confdir=$1
                    ;;
    -h | --help )   usage
                    exit
                    ;;
    -* )            echo "Unknown option \"$1\""
                    echo
                    usage
                    exit
                    ;;
    * )             vm="${vm} $1"
                    ;;
  esac
  shift
done

# set some inital values
# set gl_dryrun
dryrun=$(gl_getvar "number" "${dflt_dryrun}" 0 "${glob_dryrun}" 0 "${vm_dryrun}" 0 "${cli_dryrun}" 0)
# set global gl_dryrun variable; used in gl_run and other places
gl_dryrun=${dryrun}

# set gl_syslog
syslog=$(gl_getvar "number" "${dflt_syslog}" 0 "${glob_syslog}" 0 "${vm_syslog}" 0 "${cli_syslog}" 0)
# set global gl_syslog variable; used in gl_run and other places
gl_syslog=${syslog}

# set gl_syslogid
syslogid=$(gl_getvar "string" "${dflt_syslogid}" 0 "${glob_syslogid}" 0 "${vm_syslogid}" 0 "${cli_syslogid}" 0)
# set global gl_syslogid variable; used in gl_run and other places
gl_syslogid=${syslogid}

# set gl_noconf
noconf=$(gl_getvar "number" "${dflt_noconf}" 0 "${glob_noconf}" 0 "${vm_noconf}" 0 "${cli_noconf}" 0)
# set global gl_noconf variable; used in gl_run and other places
gl_noconf=${noconf}

# set initial runbackup var
runbackup=$(gl_getvar "string" "${dflt_runbackup}" 0 "${glob_runbackup}" 0 "${vm_runbackup}" 0 "${cli_runbackup}" 0)
# check master safety switch first. Must be set to 1 to continue
if [[ "${runbackup}" != "yes" ]]; then
  gl_err "Runbackup not set to yes. Safety switch kicking in. Exiting."
  exit 1
fi

# sanity checks
# make sure the commands we need to run are available
commlist="vboxmanage df du logger cat gawk grep chmod"
for comm in ${commlist}; do
  command -v ${comm} >& /dev/null
  status=$?
  if [[ ${status} -ne 0 ]]; then
    gl_err "${comm} command not found. Check your executable path or not installed. Exiting."
    exit 1
  fi
done

# check arguments to make sure they make sense

# check state
state=$(gl_getvar "string" "${dflt_state}" 0 "${glob_state}" 0 "${vm_state}" 0 "${cli_state}" 0)
case "${state}" in
  running | stopped | paused | saved | poweroff | "" ) ;;
  * ) gl_err "Unknown state \"${state}\""
      usage
      exit
esac

# check backup type
backuptype=$(gl_getvar "string" "${dflt_backuptype}" 0 "${glob_backuptype}" 0 "${vm_backuptype}" 0 "${cli_backuptype}" 0)
case "${backuptype}" in
  ova | clone | "" ) ;;
  * ) gl_err "Unknown type \"${backuptype}\""
      usage
      exit
esac

# check versions
versions=$(gl_getvar "number" "${dflt_versions}" 0 "${glob_versions}" 0 "${vm_versions}" 0 "${cli_versions}" 0)
if [[ $(gl_isnum "${versions}") != "1" ]]; then
  gl_err "versions must be a number. Exiting."
  exit 1
fi

# check daystokeep
daystokeep=$(gl_getvar "number" "${dflt_daystokeep}" 0 "${glob_daystokeep}" 0 "${vm_daystokeep}" 0 "${cli_daystokeep}" 0)
if [[ $(gl_isnum "${daystokeep}") != "1" ]]; then
  gl_err "daystokeep must be a number. Exiting."
  exit 1
fi

# check backupgroup
backupgroup=$(gl_getvar "string" "${dflt_backupgroup}" 0 "${glob_backupgroup}" 0 "${vm_backupgroup}" 0 "${cli_backupgroup}" 0)

# check backupdir
backupdir=$(gl_getvar "string" "${dflt_backupdir}" 0 "${glob_backupdir}" 0 "${vm_backupdir}" 0 "${cli_backupdir}" 0)
# Make sure backupdir is set
if [[ "${backupdir}" == "" ]]; then

  gl_err "Variable backupdir not set. Exiting."
  exit 1

elif [[ ! -d "${backupdir}" ]]; then

  # backupdir does not exist. Try to create it.
  gl_run mkdir -p "${backupdir}"
  status=$?

  if [[ ${status} -ne 0 ]]; then
    gl_err "Backupdir [${backupdir}] not found or cannot create. Exiting."
    exit 1
  fi

fi

# backupdir exists. Make sure we can create files in it
testfile="${backupdir}"/testfile$$
gl_run touch "${testfile}"
status=$?
if [[ ${status} -ne 0 ]]; then
  gl_err "Cannot create files under ${backupdir}. Exiting."
  exit 1
else
  # Success. We have a working BACKUPDIR. Remove testfile
  gl_run /bin/rm -f "${testfile}"
fi

# Make sure exportdir is set
exportdir=$(gl_getvar "string" "${dflt_exportdir}" 0 "${glob_exportdir}" 0 "${vm_exportdir}" 0 "${cli_exportdir}" 0)
if [[ "${exportdir}" == "" ]]; then
  # If not set, fall back to folder under backupdir
  exportdir=${backupdir}/export$$
  gl_log "Exportdir not set. Using ${exportdir} instead."
fi
# check if exportdir exists or we can create it
if [[ ! -d "${exportdir}" ]]; then
  # exportdir does not exist. Try to create it.
  gl_run mkdir -p "${exportdir}"
  status=$?
  if [[ ${status} -ne 0 ]]; then
    gl_err "Exportdir [${exportdir}] not found or cannot create. Exiting."
    exit 1
  fi
fi

# exportdir exists. Make sure we can create files in it
testfile="${exportdir}"/testfile$$
gl_run touch "${testfile}"
status=$?
if [[ ${status} -ne 0 ]]; then
  gl_err "Cannot create files under ${exportdir}. Exiting."
  exit 1
else
  # Success. we have a working exportdir. Remove testfile
  gl_run /bin/rm -f "${testfile}"
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
      vms=$(cat "${list}" | ${gl_sedsbc} | awk '{print $1}')
    else
      gl_err "VM list [${list}] is not a file. Exiting."
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
    gl_log "-- ${vm} does not exist or not found? Skipping."
  elif [[ ${vmname} = *" "* ]]; then
    gl_log "-- [${vmname}] VMs with space in their names are not supported at this time. Skipping"
  else 
 
    # set name of vm conf file
    vm_conf_file="${confdir}/${vmname}.conf"

    # we have a candidate to backup
    # set the backupvm flag to 1
    # check backup conditions. If any fail, set backupvm flag to 0, and nobackupreason to the reason
    backupvm=1
    nobackupreason=""  

    # Get the vm state
    foundstate=$(vboxmanage showvminfo "${vmname}" --machinereadable | grep -E "^VMState=" | cut -d'"' -f2)
 
    # check state match
    # get preferred vm state, if set
    vm_state=$(gl_getconfopt "${vm_conf_file}" "state")
    state=$(gl_getvar "string" "${dflt_state}" 0 "${glob_state}" 0 "${vm_state}" 0 "${cli_state}" 0)

    # check for cli state oerride
    if [[ "${state}" != "" ]]; then
      if [[ "${state}" != "${foundstate}" ]]; then
        backupvm=0
        nobackupreason="-- [${vmname}] cannot backup. VM state and Backup state mismatch. [VM State:${foundstate}] [Backup State:${state}]"
      fi
    fi

    # check day match
    # get preferred vm nodays, if set
    vm_nodays=$(gl_getconfopt "${vm_conf_file}" "nodays")
    nodays=$(gl_getvar "number" "${dflt_nodays}" 0 "${glob_nodays}" 0 "${vm_nodays}" 0 "${cli_nodays}" 0)

    # if nodays not set
    if [[ "${nodays}" -eq 0 ]]; then
      # get days to run backup for this vm
      days=$(printf "%s" $(gl_getconfopt "${vm_conf_file}" "days") | sed -e 's/,/ /g')

      # if days is set, check if "today" matches
      if [[ "${days}" != "" ]]; then
        daysarray=($days)

        # check to see if "today" (name or number) is in the days array
        if [[ $(gl_array_contains daysarray ${dayname}) -eq 0 && $(gl_array_contains daysarray ${daynum}) -eq 0 ]]; then
          backupvm=0
          nobackupreason="-- [${vmname}] cannot backup. VM day mismatch. [VM days:${days}] [Today:${dayname} or ${daynum}]"
        fi

        # check to see if days has keyword "never"
        if [[ $(gl_array_contains daysarray "never") -eq 1 ]]; then
          backupvm=0
          nobackupreason="-- [${vmname}] cannot backup. VM set to never backup. [VM days:${days}]"
        fi

      fi
    fi
    
    # by default we issue a savestate
    shutcomm="savestate"

    vm_acpi=$(gl_getconfopt "${vm_conf_file}" "acpi")
    acpi=$(gl_getvar "number" "${dflt_acpi}" 0 "${glob_acpi}" 0 "${vm_acpi}" 0 "${cli_acpi}" 0)
    #    echo ${vmname} acpi: D:${dflt_acpi},G:${glob_acpi},V:${vm_acpi},C:${cli_acpi},R:${acpi}
    
    # check for acpi override
    if [[ "${acpi}" -eq 1 ]]; then
      shutcomm="acpipowerbutton"
    fi


    # check for acpiwaittime override
    vm_acpiwaittime=$(gl_getconfopt "${vm_conf_file}" "acpiwaittime")
    acpiwaittime=$(gl_getvar "number" "${dflt_acpiwaittime}" 0 "${glob_acpiwaittime}" 0 "${vm_acpiwaittime}" 0 "${cli_acpiwaittime}" 0)

    # check for acpiwaitcycles override
    vm_acpiwaitcycles=$(gl_getconfopt "${vm_conf_file}" "acpiwaitcycles")
    acpiwaitcycles=$(gl_getvar "number" "${dflt_acpiwaitcycles}" 0 "${glob_acpiwaitcycles}" 0 "${vm_acpiwaitcycles}" 0 "${cli_acpiwaitcycles}" 0)

    # check for acpiwaitpoweroff override
    vm_acpiwaitpoweroff=$(gl_getconfopt "${vm_conf_file}" "acpiwaitpoweroff")
    acpiwaitpoweroff=$(gl_getvar "string" "${dflt_acpiwaitpoweroff}" 0 "${glob_acpiwaitpoweroff}" 0 "${vm_acpiwaitpoweroff}" 0 "${cli_acpiwaitpoweroff}" 0)

    # check for backup type override
    vm_backuptype=$(gl_getconfopt "${vm_conf_file}" "backuptype")
    backuptype=$(gl_getvar "string" "${dflt_backuptype}" 0 "${glob_backuptype}" 0 "${vm_backuptype}" 0 "${cli_backuptype}" 0)

    # check for backupgroup override
    vm_backupgroup=$(gl_getconfopt "${vm_conf_file}" "backupgroup")
    backupgroup=$(gl_getvar "string" "${dflt_backupgroup}" 0 "${glob_backupgroup}" 0 "${vm_backupgroup}" 0 "${cli_backupgroup}" 0)

    # check for versions override
    vm_versions=$(gl_getconfopt "${vm_conf_file}" "versions")
    versions=$(gl_getvar "number" "${dflt_versions}" 0 "${glob_versions}" 0 "${vm_versions}" 0 "${cli_versions}" 0)

    # check for daystokeep override
    vm_daystokeep=$(gl_getconfopt "${vm_conf_file}" "daystokeep")
    daystokeep=$(gl_getvar "number" "${dflt_daystokeep}" 0 "${glob_daystokeep}" 0 "${vm_daystokeep}" 0 "${cli_daystokeep}" 0)


    # ignore vms having the backuptag at the end. These are leftovers from previous backups, or are still running
    if [[ "${vmname}" =~ ${backuptag}$ ]]; then
      backupvm=0
      nobackupreason="-- [${vmname}] cannot backup. This is a leftover(?) clone from a previous backup. [VM State:${state}]"
    fi

    # if all backup checks passed.. backup the VM
    if [[ "${backupvm}" -eq 1 ]]; then
      # start time of vm loop
      vmstartsec=$(date +%s)

      timestamp=$(date +${timeformat})
       
      # We have a match.. begin backup
      gl_log "-- [${vmname}] Start backup [State:${foundstate}] [Days:${days}] [Type:${backuptype}] [Group:${backupgroup}] [Shutdown:${shutcomm}]"

      # Delete old TMPLOG, jic
      gl_run /bin/rm -f "${tmplog}"

      savestatestatus=0
      # If the VM is running or paused, save its state. Need this to "resume" it after backing up
      if [[ "${foundstate}" == "running" || "${foundstate}" == "paused" ]]; then

        gl_log "-- [${vmname}]    Begin VM ${shutcomm}"
        SECONDS=0
        if [[ "${gl_dryrun}" -eq 1 ]]; then
          echo vboxmanage controlvm "${vmname}" "${shutcomm}"
          savestatestatus=0
        else
          vboxmanage controlvm "${vmname}" "${shutcomm}" >& "${tmplog}"
          savestatestatus=$?
        fi

        # if acpi shutdown we MUST wait for the VM state to change to "poweroff"
        if [[ "${shutcomm}" == "acpipowerbutton" ]]; then
          if [[ "${gl_dryrun}" -eq 1 ]]; then
            waitstate="poweroff"
          else
            waitstate=$(vboxmanage showvminfo "${vmname}" --machinereadable | grep -E "^VMState=" | cut -d'"' -f2)
          fi

          ## possible infinite loop here if waitstate never changes
          ## fix this later
          cyclenum=0
          savestatestatus=1
          while [[ "${waitstate}" != "poweroff" && ${savestatestatus} -ne 0 ]]; do
            gl_log "-- [${vmname}]     Waiting for VM to shutdown [${cyclenum}/${acpiwaitcycles}]"
            sleep ${acpiwaittime}
            cyclenum=$(( cyclenum + 1 ))
            if [[ ${cyclenum} -eq ${acpiwaitcycles} ]]; then
              # issue "forced" poweroff if set
              if [[ "${acpiwaitpoweroff}" != "yes" ]]; then
                # skip VM
                gl_log "-- [${vmname}]     ACPI wait cycles exceeded. Skipping VM."
                savestatestatus=1
              else
                # force VM poweroff
                if [[ "${gl_dryrun}" -eq 1 ]]; then
                  echo vboxmanage controlvm "${vmname}" "poweroff"
                  savestatestatus=0
                else
                  vboxmanage controlvm "${vmname}" "poweroff" >& "${tmplog}"
                  savestatestatus=$?
                  # sleep a bit, giving the VM time to poweroff
                  sleep ${acpiwaittime}
                fi
              fi
            fi
            waitstate=$(vboxmanage showvminfo "${vmname}" --machinereadable | grep -E "^VMState=" | cut -d'"' -f2)
          done
        fi

        if [[ "${waitstate}" == "poweroff" ]]; then
          savestatestatus=0
        fi

        duration=$(gl_secstohms $SECONDS)
        # only logoutput if error
        if [[ ${savestatestatus} -ne 0 ]]; then gl_logfile "${tmplog}" ; fi
        gl_log "-- [${vmname}]    End VM ${shutcomm}. $duration"
      fi
      
      # If savestate was sucessfull, being the backup
      if [[ ${savestatestatus} -eq 0 ]]; then

        # create backup
        # Step 1 create VM clone. MUCH faster then exporting to OVA.
        # Reasoning: Minimize system downtime. Convert to OVA, if needed, AFTER cloning is completed

        backupname="${vmname}-${timestamp}${backuptag}"
        gl_log "-- [${vmname}]    Begin Clone : [${backupname}]"

        freedisk=0
        if [[ -d "${exportdir}"/. ]]; then
          freedisk=$(df -k "${exportdir}"/. | grep /dev | awk '{print $4}')
        fi
        gl_log "-- [${vmname}]     Disk free before clonevm ${exportdir} : $(( ${freedisk} / 1024 ))MB"

        SECONDS=0
        if [[ "${gl_dryrun}" -eq 1 ]]; then
          echo vboxmanage clonevm "${vmname}" --mode all \
                    --basefolder "${exportdir}" --name "${backupname}"
          backupstatus=0
        else
          vboxmanage clonevm "${vmname}" --mode all \
                    --basefolder "${exportdir}" --name "${backupname}" >& "${tmplog}"
          backupstatus=$?
        fi
        duration=$(gl_secstohms $SECONDS)
        # only log output if error
        if [[ ${backupstatus} -ne 0 ]]; then gl_logfile "${tmplog}" ; fi

        exportdirsize=0
        if [[ -d "${exportdir}"/"${backupname}" ]]; then
          exportdirsize=$(du -sk "${exportdir}"/"${backupname}" | awk '{print $1}')
        fi
        gl_log "-- [${vmname}]      Exportdir size: $(( ${exportdirsize} / 1024 ))MB"

        freedisk=0
        if [[ -d "${exportdir}"/. ]]; then
          freedisk=$(df -k "${exportdir}"/. | grep /dev | awk '{print $4}')
        fi
        gl_log "-- [${vmname}]     Disk free after clonevm ${exportdir} : $(( ${freedisk} / 1024 ))MB"

        gl_log "-- [${vmname}]    End Clone export. $duration"

        # put vm back into original state, regardless of backupstatus
        if [[ "${foundstate}" == "running" || "${foundstate}" == "paused" ]]; then
          gl_log "-- [${vmname}]    Begin VM restore state"
          SECONDS=0
          if [[ "${gl_dryrun}" -eq 1 ]]; then
            echo vboxmanage startvm "${vmname}" --type headless
            startstatus=0
          else
            vboxmanage startvm "${vmname}" --type headless >& "${tmplog}"
            startstatus=$?
          fi
          # only log output if error
          if [[ ${startstatus} -ne 0 ]]; then gl_logfile "${tmplog}" ; fi

          # if state was paused.. put it back into a paused state
          if [[ "${foundstate}" == "paused" ]]; then
            if [[ "${gl_dryrun}" -eq 1 ]]; then
              echo vboxmanage controlvm "${vmname}" pause
              pausestatus=0
            else
              vboxmanage controlvm "${vmname}" pause >& "${tmplog}"
              pausestatus=$?
            fi
            # only log output if error
            if [[ ${pausestatus} -ne 0 ]]; then gl_logfile "${tmplog}" ; fi
          fi
          duration=$(gl_secstohms $SECONDS)
          gl_log "-- [${vmname}]    End VM restore state. $duration"
        fi
             
        # if clone was sucessful and we have to export to OVA
        if [[ "${backuptype}" == "ova" && ${backupstatus} -eq 0 ]]; then
          # create OVA export from VM
          # We can only create an export from a "registered" vm.
          # register this "clone", then create an OVA eport from it.

          gl_log "-- [${vmname}]    Begin VM register for OVA export : [${backupname}] [${foundstate}]"
          SECONDS=0
          if [[ "${gl_dryrun}" -eq 1 ]]; then
            echo vboxmanage registervm "${exportdir}/${backupname}/${backupname}.vbox"
            registerstatus=0
          else
            vboxmanage registervm "${exportdir}/${backupname}/${backupname}.vbox" >& "${tmplog}"
            registerstatus=$?
          fi
          duration=$(gl_secstohms $SECONDS)
          # only log output if error
          if [[ ${registerstatus} -ne 0 ]]; then gl_logfile "${tmplog}" ; fi
          gl_log "-- [${vmname}]    End VM register for OVA export. $duration"
            
          ovaname="${vmname}-${timestamp}.ova"
          gl_log "-- [${vmname}]    Begin OVA export: [${ovaname}]"

          freedisk=0
          if [[ -d "${exportdir}"/. ]]; then
            freedisk=$(df -k "${exportdir}"/. | grep /dev | awk '{print $4}')
          fi
          gl_log "-- [${vmname}]     Disk free before OVA export ${exportdir} : $(( ${freedisk} / 1024 ))MB"

          SECONDS=0
          if [[ "${gl_dryrun}" -eq 1 ]]; then
            echo vboxmanage export "${backupname}" --output "${exportdir}/${ovaname}"
            backupstatus=0
          else
            vboxmanage export "${backupname}" --output "${exportdir}/${ovaname}" &> "${tmplog}"
            backupstatus=$?
          fi
          duration=$(gl_secstohms $SECONDS)
          # only log output if error
          if [[ ${backupstatus} -ne 0 ]]; then gl_logfile "${tmplog}" ; fi

          exportovasize=0
          if [[ -f "${exportdir}"/"${ovaname}" ]]; then
            exportovasize=$(du -sk "${exportdir}"/"${ovaname}" | awk '{print $1}')
          fi
          gl_log "-- [${vmname}]      OVA size: $(( ${exportovasize} / 1024 ))MB"

          freedisk=0
          if [[ -d "${exportdir}"/. ]]; then
            freedisk=$(df -k "${exportdir}"/. | grep /dev | awk '{print $4}')
          fi
          gl_log "-- [${vmname}]     Disk free after OVA export ${exportdir} : $(( ${freedisk} / 1024 ))MB"

          gl_log "-- [${vmname}]    End OVA export. $duration"

          gl_log "-- [${vmname}]    Begin VM unregister from OVA export : [${backupname}] [${foundstate}]"
          SECONDS=0
          if [[ "${gl_dryrun}" -eq 1 ]]; then
            echo vboxmanage unregistervm "${backupname}"
            registerstatus=0
          else
            vboxmanage unregistervm "${backupname}" >& "${tmplog}"
            registerstatus=$?
          fi
          duration=$(gl_secstohms $SECONDS)
          # only log output if error
          if [[ ${registerstatus} -ne 0 ]]; then gl_logfile "${tmplog}" ; fi
          gl_log "-- [${vmname}]    End VM unregister from OVA export. $duration"
        fi

        if [[ ${backupstatus} -eq 0  ]]; then
          # backup was sucessful
          # move export to backup folder

          # set backup folder name based on daystokeep setting
          if [[ ${daystokeep} -eq 0  ]]; then       
            # daystokeep not set, use standard versioning numbering ala syslog
            # yes.. double up on the vmname. this puts all the backups for the same vm in the same folder
            backupfolder=${backupdir}/${backupgroup}/${vmname}/${vmname}
          
            # remove oldest verison, and cycle rest
            for ((i=${versions}; i>=0; i--)); do
              if [[ ${i} -eq ${versions} ]]; then
                if [[ -d "${backupfolder}.${i}" ]]; then
                  gl_log "-- [${vmname}]    Removing folder (version wrap) ${backupfolder}.${i}."
                  gl_run /bin/rm -rf "${backupfolder}.${i}"
                fi
              elif [[ ${i} -eq 0 && ${versions} -gt 0 ]]; then
                if [[ -d "${backupfolder}" ]]; then
                  gl_run mv "${mvbackupfolder}" "${backupfolder}.1"
                fi
              else
                j=$(( i + 1 ))
                if [[ -d "${backupfolder}.${i}" ]]; then
                  gl_run mv "${backupfolder}.${i}" "${backupfolder}.${j}"
                fi
              fi
            done
          else
            # remove backups older than daystokeep
            if [[ -d "${backupdir}/${backupgroup}/${vmname}" ]]; then
              # get list of folders to delete
              deldirs=$(find "${backupdir}/${backupgroup}/${vmname}" -type d -mtime +${daystokeep})
              for deldir in ${deldirs}; do
                gl_log "-- [${vmname}]    Removing folder (+${daystokeep} days old) ${deldir}"
                gl_run /bin/rm -rf "${deldir}"
              done
            fi
            backupfolder=${backupdir}/${backupgroup}/${vmname}/${vmname}.${timestamp}
          fi


          # move export file to backup folder
          gl_log "-- [${vmname}]    Begin VM move from export to backup : [${vmname}]"
          # Make latest backup folder
          gl_run mkdir -p "${backupfolder}"

          freedisk=0
          if [[ -d "${backupfolder}"/. ]]; then
            freedisk=$(df -k "${backupfolder}"/. | grep /dev | awk '{print $4}')
          fi
          gl_log "-- [${vmname}]     Disk free before move to backup ${backupfolder} : $(( ${freedisk} / 1024 ))MB"

          SECONDS=0
          if [[ "${type}" == "clone" ]]; then
            # move clone
            gl_run mv "${exportdir}/${backupname}" "${backupfolder}"
          else
            # move ova file
            gl_run mv "${exportdir}/${ovaname}" "${backupfolder}"
            # remove clone as no longer needed
            gl_run /bin/rm -rf "${exportdir}/${backupname}"
          fi
          # chmod files in backupfolder as "umask" way above does not work??
          gl_run chmod u+rw,g+r "${backupfolder}"/*
          
          duration=$(gl_secstohms $SECONDS)

          backupfoldersize=0
          if [[ -d "${backupfolder}"/. ]]; then
            backupfoldersize=$(du -sk "${backupfolder}"/. | awk '{print $1}')
          fi
          gl_log "-- [${vmname}]      Backup folder size: $(( ${backupfoldersize} / 1024 ))MB"

          freedisk=0
          if [[ -d "${backupfolder}"/. ]]; then
            freedisk=$(df -k "${backupfolder}"/. | grep /dev | awk '{print $4}')
          fi
          gl_log "-- [${vmname}]     Disk free after move to backup ${backupfolder} : $(( ${freedisk} / 1024 ))MB"

          gl_log "-- [${vmname}]    End VM move.  $duration"

        else
          gl_log "-- [${vmname}]  Backup failed for ${backupname}. Check log."
          # remove possible failed clone remnants..
          gl_run /bin/rm -rf "${exportdir}/${backupname}"
        fi
            
      else
        gl_log "-- [${vmname}]  Savestate failed. Cannot backup [${vmname}]. See log."
      fi

      gl_run /bin/rm -f "${tmplog}"

      # end time of vm loop
      vmendsec=$(date +%s)
      duration=$(gl_secstohms $(( vmendsec - vmstartsec )))
      gl_log "-- [${vmname}] End backup [State:${foundstate}] $duration"

    else
      gl_log "${nobackupreason}"
    fi
  fi
done

exit 0
