#!/bin/bash

##############################################
# Script to run the test plan using jmeter
#
# Runs will be grouped according to $1 so they
# can be compared easily. The run description
# will be useful to identify them.
#
# Usage:
#   cd /path/to/moodle-performance-comparison
#   ./test_runner.sh [OPTIONS] {run_group_name} {run_description} {test_plan_file_path} {users_file_path}
#
# Arguments:
# * $1 => The run group name, there will be comparision graphs by this group name
# * $2 => The run description, useful to identify the changes between runs.
# * $3 => The test plan file path
# * $4 => The path to the file with user's login data
#
# Options:
# * -u => Force the number of users (threads)
# * -l => Force the number of loops
# * -r => Force the ramp-up period
# * -t => Force the throughput
#
##############################################

set -e

# Dependencies.
. ./lib/lib.sh

# Load properties.
load_properties "jmeter_config.properties"

# Load the generated files locations (when jmeter is running in the same server than the web server).
if [ -e "test_files.properties" ]; then
    load_properties "test_files.properties"
fi

if [ "$#" -lt 2 ]; then
    echo "Error: Not enough arguments. Open test_runner.sh for more details."
    exit 1
fi

# Getting jmeter custom options.
while [ $# -gt 0 ]; do
    case $1 in
        -u)
            users=" -Jusers=$2"
            shift 2
            ;;
        -l)
            loops=" -Jloops=$2"
            shift 2
            ;;
        -r)
            rampup=" -Jrampup=$2"
            shift 2
            ;;
        -t)
            throughput=" -Jthroughput=$2"
            shift 2
            ;;
        *)
            # Wrong argument; True... we don't support "-[a-zA-Z] arguments.
            if [ "${1:0:1}" == "-" ]; then
                echo "Error: Unsupported option $1"
                exit 1
            fi

            if [ -z "$group" ] && [ "${1:0:1}" != "-" ]; then
                group=$1
                shift
            fi

            if [ -z "$description" ] && [ "${1:0:1}" != "-" ]; then
                description=$1
                shift
            fi

            if [ ! -z "$1" ] && [ -z "$testplanarg" ] && [ "${1:0:1}" != "-" ]; then
                testplanarg=$1
                shift
            fi

            if [ ! -z "$1" ] && [ -z "$testusersfilearg" ] && [ "${1:0:1}" != "-" ]; then
                testusersfilearg=$1
                shift
            fi
            ;;
    esac
done

# We give priority to the ones that comes as arguments.
if [ ! -z "$testplanarg" ]; then
    $testplanfile = $testplanarg
fi
if [ ! -z "$testusersfilearg" ]; then
    $testusersfile = $testusersfilearg
fi

# If there is no test_files.properties and no files were provided we throw an error.
if [ -z "$testplanfile" ] || [ -z "$testusersfile" ]; then
    echo "Usage: `basename $0` {run_group} {run_description} {test_plan_file_path} {users_file_path}"
    exit 1
fi

# Creating the results cache directory for images.
if [ ! -d "cache" ]; then
    mkdir -m 777 "cache"
else
    chmod 777 "cache"
fi

# Uses the test plan specified in the CLI call.
datestring=`date '+%Y%m%d%H%M'`
logfile="logs/jmeter.$datestring.log"
runoutput="runs_outputs/$datestring.output"

# Getting the current site data.
cd moodle
siteversion="$(cat version.php | grep '$version' | grep -o '[0-9].[0-9]\+')"
sitebranch="$(cat version.php | grep '$branch' | grep -o '[0-9]\+')"
sitecommit="$(git show --oneline | head -n 1)"
cd ..

# Run it baby! (without GUI).
echo "Test running... (time for a coffee?)"
jmeterbin=$jmeter_path/bin/jmeter
$jmeterbin -n -j "$logfile" -t "$testplanfile" -Jusersfile="$testusersfile" -Jgroup="$group" -Jdesc="$description" -Jsiteversion="$siteversion" -Jsitebranch="$sitebranch" -Jsitecommit="$sitecommit" $users $loops $rampup $throughput > $runoutput
jmeterexitcode=$?
if [ "$jmeterexitcode" -ne "0" ]; then
    echo "Error: Jmeter can not run, ensure that:"
    echo "* The test plan and the users files are ok"
    echo "* You provide correct arguments to the script"
    exit $jmeterexitcode
fi

outputinfo="
#######################################################################
Test plan completed successfully.

To compare this run with others remember to execute after_run_setup.sh before it to clean the site restoring the database and the dataroot.
"
echo "$outputinfo"
exit 0