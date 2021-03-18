#!/usr/bin/env bash
#set -ev

BLUE='\033[0;36m'
PURPLE='\033[0;95m'
LIGHT_GREEN='\033[0;92m'
NC='\033[0m' # No Color
_TAB='    '
underline=`tput smul`
nounderline=`tput rmul`
bold=`tput bold`
normal=`tput sgr0`

################################################
################# SETUP ########################
################################################

usage() {
  echo -e "" 1>&2;
  echo -e "${underline}Info:${nounderline}" 1>&2;
  echo -e "" 1>&2;
  echo -e "${_TAB} Runs Unit tests and extracts any captured images to the ./screenshots directory, relative to the xcode project or workspace." 1>&2;
  echo -e "" 1>&2;
  echo -e "${underline}Usage:${nounderline}" 1>&2;
  echo -e "" 1>&2;
  echo -e "${_TAB} \$${LIGHT_GREEN}./screenshots.sh --argument ${PURPLE}CommandLineArgument${NC}" 1>&2;
  echo -e "" 1>&2;
  echo -e "${underline}Options:${nounderline}" 1>&2;
  echo -e "" 1>&2;
  echo -e "${_TAB}${BLUE}--project${NC}\t\t The name of the Xcode project" 1>&2;
  echo -e "" 1>&2;
  echo -e "${_TAB}${BLUE}--workspace${NC}\t\t The name of the Xcode workspace" 1>&2;
  echo -e "" 1>&2;
  echo -e "${_TAB}${BLUE}--scheme${NC}\t\t the project Scheme to build" 1>&2;
  echo -e "" 1>&2;
  echo -e "${_TAB}${BLUE}--argument${NC}\t\t Command line argument that will be passed directly to your Unit tests." 1>&2;
  echo -e "${_TAB}${_TAB}${BLUE}${NC}\t\t You should wrap the argument in quotes. You may pass as many arguments as needed." 1>&2;
  echo -e "" 1>&2;
  echo -e "${_TAB}${BLUE}--testLanguage${NC}\t the language to run the simulator / unit tests as." 1>&2;
  echo -e "" 1>&2;
  echo -e "${_TAB}${BLUE}--usage${NC}\t\t Prints this usage information" 1>&2;
  echo -e "" 1>&2;
  exit -1;
}

declare -a CMD_LINE_ARGUMENTS=()
TEST_LANGUAGE="en"
while getopts "a:t:p:w:s:x-:" optchar
do
  case "${optchar}" in
  a)
    ARG=${OPTARG}
    CMD_LINE_ARGUMENTS+=("${ARG}") ;;
  t)
    TEST_LANGUAGE=${OPTARG} ;;
  p)
    PROJECT_NAME=${OPTARG} ;;
  w)
    WORKSPACE_NAME=${OPTARG} ;;
  s)
    SCHEME=${OPTARG} ;;
  -)
    case "${OPTARG}"
    in
      usage)
        usage;;
      argument)
        ARG="${!OPTIND}";
        CMD_LINE_ARGUMENTS+=("${ARG}")
        OPTIND=$(( $OPTIND + 1 ));;
      testLanguage)
        TEST_LANGUAGE="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ));;
      project)
        PROJECT_NAME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ));;
      workspace)
        WORKSPACE_NAME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ));;
      scheme)
        SCHEME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ));;
    esac;;

  esac
done


if [[ -z "${PROJECT_NAME}" ]] && [[ -z "${WORKSPACE_NAME}" ]]; then
  echo "No Xcode project or workspace provided!";
  usage
fi;

if [[ -z "${SCHEME}" ]]; then
  echo "Invalid scheme!";
  usage
fi;

BUILD_FLAG=""
PROJECT_ABS_PATH=""
if [[ ! -z "${PROJECT_NAME}" ]]; then
  PROJECT_PATH="$(dirname "${PROJECT_NAME}")"
  PROJECT_ABS_PATH=$(cd ${PROJECT_PATH} && pwd)
  BASE_PROJECT_NAME=$(echo ${PROJECT_NAME} | sed -e "s/\${PROJECT_PATH}//")
  BUILD_FLAG="-project ${PROJECT_ABS_PATH}/${BASE_PROJECT_NAME}.xcproject"
elif [[ ! -z "${WORKSPACE_NAME}" ]]; then
  PROJECT_PATH="$(dirname "${WORKSPACE_NAME}")"
  PROJECT_ABS_PATH=$(cd ${PROJECT_PATH} && pwd)
  BASE_PROJECT_NAME=$(echo ${WORKSPACE_NAME} | sed -e "s/\${PROJECT_PATH}//")
  BUILD_FLAG="-workspace $(cd "${PROJECT_ABS_PATH}/${BASE_PROJECT_NAME}.xcworkspace"; pwd)"
fi;

###########################
# Env Variables
###########################
# run `xcrun simctl list devicetypes` to get a list of available deviceTypes
SIMULATOR_TYPES=com.apple.CoreSimulator.SimDeviceType.iPhone-SE--2nd-generation-
#,com.apple.CoreSimulator.SimDeviceType.iPhone-6-Plus,com.apple.CoreSimulator.SimDeviceType.iPhone-XS-Max,com.apple.CoreSimulator.SimDeviceType.iPhone-11,com.apple.CoreSimulator.SimDeviceType.iPhone-6,com.apple.CoreSimulator.SimDeviceType.iPhone-X,com.apple.CoreSimulator.SimDeviceType.iPad-Pro--12-9-inch---2nd-generation-,com.apple.CoreSimulator.SimDeviceType.iPad-Pro--12-9-inch---3rd-generation-
###########################

###########################
DEPLOY_DIR="${PROJECT_ABS_PATH}/build"
SCREENSHOTS_PATH="${PROJECT_ABS_PATH}/screenshots/"
TESTS_PATH="${DEPLOY_DIR}/Tests/"
XCRESULT_PATH="${TESTS_PATH}${SCHEME}.xcresult"
# run `xcrun simctl list runtimes` to get a list of available runtimes
iOS12Runtime="$(xcrun simctl list runtimes | grep -o 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-12.*$' | tail -n 1)"
iOS13Runtime="$(xcrun simctl list runtimes | grep -o 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-13.*$' | tail -n 1)"
iOS14Runtime="$(xcrun simctl list runtimes | grep -o 'com\.apple\.CoreSimulator\.SimRuntime\.iOS.*$' | tail -n 1)"
###########################
CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"

###########################
# The array of created simulator UUID's. These must be deleted at of the end of the script
declare -a BOOTED_SIMULATORS=()
###########################

prepare() {
# test flag and delete if set
cleanup

# start by shutting down all simulators so we have a clean starting environment.
xcrun simctl shutdown all
}

# creates simulators to deploy the app to
createSimulators() {
# stash the possible runtimes we should try and load, attempted in decending order
declare -a RUNTIMES=()
RUNTIMES+=("${iOS14Runtime}")
RUNTIMES+=("${iOS13Runtime}")
RUNTIMES+=("${iOS12Runtime}")

# loop through the simulator types we want to create
declare -a ARR=(${SIMULATOR_TYPES//,/ })
for DEVICE_TYPE in "${ARR[@]}"; do
  # grep the device name from the list of device types, based on the input device type. This is only used for a user friendly display value.
  DEVICE_NAME="$(xcrun simctl list devicetypes | grep " (${DEVICE_TYPE})" | sed -e "s/[[:space:]](${DEVICE_TYPE})//g")"

  # this will be the simulators UUID after it's created
  SIM_UUID=""

  # loop through each runtime type and create the simulaotrs for the devices
  for RUNTIME in "${RUNTIMES[@]}"; do
    # create a user friendly printable version of the runtime
    USER_FRIENDLY_RUNTIME=$(echo ${RUNTIME} | cut -d "." -f5-)
    echo -ne "\033[KCreating Simulator... [${DEVICE_NAME}] - Runtime [${USER_FRIENDLY_RUNTIME}]";

    # attempt to create the simulator
    CREATE_SIMULATOR_OUTPUT=$(xcrun simctl create "${DEVICE_NAME}" "${DEVICE_TYPE}" "${RUNTIME}") # > /dev/null 2>&1 # fails when sending output to /dev/null ?
    # regex check the output for the UUID value
    CREATE_SIM_OUTPUT=$(echo "${CREATE_SIMULATOR_OUTPUT}" | awk -F ' ' '{ print $0 }')
    SIM_UUID=$(echo "${CREATE_SIM_OUTPUT}" | grep -E '[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}')
    unset IFS

    # if we found a simulators UUID then we created the simulator and can break the loop
    if [[ ! -z "${SIM_UUID}" ]]; then
      break
    fi
  done

  if [[ -z "${SIM_UUID}" ]]; then
    # if we got here and do not have a uuid, we failed and just show a message
    echo -e "\\r\033[KFailed to Boot Simulator ${DEVICE_NAME} using ${USER_FRIENDLY_RUNTIME} runtime";
  else
    # we created the simulator, boot it now and store the UUID for later
    echo -e "\\r\033[K${CHECK_MARK} Booted! [${DEVICE_NAME}] - Runtime [${USER_FRIENDLY_RUNTIME}] - UUID [${SIM_UUID}]";
    xcrun simctl boot "${SIM_UUID}"
    BOOTED_SIMULATORS+=("${SIM_UUID}")
  fi
done
# turn off verbose logs
# disableVerboseLogs
# print out the booted simulators. We should only see the ones we created above
# xcrun simctl list devices | grep "(Booted)"
}

# clean up our environment by deleting any simulators we created
deleteSimulators() {
for SIMULATOR_ID in "${BOOTED_SIMULATORS[@]}"; do
  echo "Deleting Simulator... ${SIMULATOR_ID}"
  xcrun simctl delete "${SIMULATOR_ID}"
done
}

# build the project using the requested simulators
build() {
#construct the destinations parameter for xcodebuild
declare -a DESTINATIONS=()
for UUID in "${BOOTED_SIMULATORS[@]}"; do
  DESTINATIONS+=("-destination 'platform=iOS Simulator,id='${UUID}")
done

#construct the xcodebuild command
BUILD_CMD="xcodebuild \
"${BUILD_FLAG}" \
-scheme ${SCHEME} \
-derivedDataPath ${DEPLOY_DIR} \
-parallel-testing-enabled NO \
-testLanguage ${TEST_LANGUAGE} \
"${DESTINATIONS[*]}" \
-maximum-concurrent-test-simulator-destinations "${#BOOTED_SIMULATORS[@]}" \
build-for-testing \
| xcpretty"
eval "${BUILD_CMD}"

if [ $? -ne 0 ]; then
   echo "Looks like building the project failed. Please ensure the project is buildable and stable"
   exit 1
fi

}

# test the project using the requested simulators
test() {
#construct the destinations parameter for xcodebuild
declare -a DESTINATIONS=()
for UUID in "${BOOTED_SIMULATORS[@]}"; do
  DESTINATIONS+=("-destination 'platform=iOS Simulator,id='${UUID}")
done

# add flag to xctestrun by creating swift plist parsing program and running it over .xctestrun file
XCRUN_FILEPATH=$(find "${DEPLOY_DIR}"/Build/Products -name '*.xctestrun')

configureCommandLineArguments "${XCRUN_FILEPATH}"

# run tests
TEST_CMD="xcodebuild \
"${DESTINATIONS[*]}" \
-maximum-concurrent-test-simulator-destinations "${#BOOTED_SIMULATORS[@]}" \
-xctestrun ${XCRUN_FILEPATH} \
-resultBundlePath ${XCRESULT_PATH} \
test-without-building \
| xcpretty -r html --output '${DEPLOY_DIR}/Tests/test-results.html'"
eval $TEST_CMD

}

# constructs the swift script that injects the command line arguments into the xcrun build file
configureCommandLineArguments() {
# the .xctestrun file path
XCRUN_FILEPATH=$1
# construct the list.add block of code
SWIFT_LISTADD_BLOCK=""
for ARG in "${CMD_LINE_ARGUMENTS[@]}"; do
SWIFT_LISTADD_BLOCK+="    list.add(\"${ARG}\")
"
done
SWIFT_CODE_BLOCK="
import Foundation
let file = ProcessInfo.processInfo.arguments[1]
guard let dict = NSDictionary(contentsOfFile: file) else {
    fatalError(\"Cant read dict\")
}
let argsKey = \"CommandLineArguments\"
let keys = dict.allKeys as! [String]
for key in keys {
    let content = dict[key] as! NSDictionary
    let list = (content[argsKey] as? NSArray)?.mutableCopy() as? NSMutableArray ?? NSMutableArray()
"${SWIFT_LISTADD_BLOCK}"
    content.setValue(list, forKey: argsKey)
}
dict.write(toFile: file, atomically: true)
"

echo "${SWIFT_CODE_BLOCK}" > plistUpdate.swift
swiftc plistUpdate.swift

PLIST_UPDATE_CMD="./plistUpdate ${XCRUN_FILEPATH}"
eval "${PLIST_UPDATE_CMD}"

rm plistUpdate.swift
rm plistUpdate

}

# perform the screenshot extraction process using xcparse
extractScreenshots() {
if [[ -d "${SCREENSHOTS_PATH}" ]]; then
  rm -rf ${SCREENSHOTS_PATH}
fi
if [[ -d "${XCRESULT_PATH}" ]]; then
  xcparse attachments --os --model "${XCRESULT_PATH}" "${SCREENSHOTS_PATH}"
fi
if [[ -d "${SCREENSHOTS_PATH}" ]]; then
  find "${SCREENSHOTS_PATH}" -type f -exec mv {} {}.png \;
  open "${SCREENSHOTS_PATH}"
fi
}

# deletes build, screenshot, and intermediate test files
cleanup() {
if [[ -d "${TESTS_PATH}" ]]; then
  rm -rf ${TESTS_PATH}
fi
if [[ -d "${DEPLOY_DIR}" ]]; then
  rm -rf ${DEPLOY_DIR}
fi
}

# fails....
setLanguage() {
for SIMULATOR_ID in "${BOOTED_SIMULATORS[@]}"; do
  # set the simulators local!
  PLIST_FILE="$HOME/Library/Developer/CoreSimulator/Devices/${SIMULATOR_ID}/data/Library/Preferences/.GlobalPreferences.plist"
  plutil -p "${PLIST_FILE}"
  plutil -replace AppleLocale -string ${TEST_LANGUAGE} ${PLIST_FILE}
  plutil -replace AppleLanguages -json "[ \"{$TEST_LANGUAGE}\" ]" ${PLIST_FILE}
done
}

# does not work....
disableVerboseLogs() {
for SIMULATOR_UUID in "${BOOTED_SIMULATORS[*]}"; do
  xcrun simctl shutdown "${SIMULATOR_UUID}"
done
xcrun simctl logverbose disable
for SIMULATOR_UUID in "${BOOTED_SIMULATORS[*]}"; do
  xcrun simctl boot "${SIMULATOR_UUID}"
done
}

##########
# Script #
##########

prepare

createSimulators
# Build the project
build
# run the tests
test
# delete the simulators
deleteSimulators
# exract the captured screenshots
extractScreenshots

cleanup

# Play "Ping" sound when tests done
afplay /System/Library/Sounds/Glass.aiff