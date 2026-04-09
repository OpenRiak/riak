#!/bin/bash
# -------------------------------------------------------------------
#
# Copyright (c) 2025 Workday, Inc.
#
# This file is provided to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file
# except in compliance with the License.  You may obtain
# a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# -------------------------------------------------------------------
#
#   A script to test ca functionality.
#

ROOT_DIR=$(cd "$(dirname $0)"/.. && pwd)
TEST_PROGRAM_NAME="$ROOT_DIR/bin/ca"

# source common variables
source "$ROOT_DIR/etc/variables.sh"

# Test functions

assert_exists() {
  if [[ -e "$1" ]]; then
    echo -e "\t\tAssertion passed: $1 exists"
  else
    echo -e "\t\tAssertion failed: $1 does not exist"
    exit 1
  fi
}

# Test cases

echo "Running tests..."

# Test 1: Help function
echo -e "\nTesting help function..."
"$TEST_PROGRAM_NAME" -h | grep "common name to place" > /dev/null
if [[ $? == 0 ]]; then
  echo -e "\tTest passed: Help message contains expected string"
else
  echo -e "\tTest failed: Help message does not contain expected string"
  exit 1
fi

# Test 2: Missing name
echo -e "\nTesting missing name..."
set +e  # Disable exiting on error
"$TEST_PROGRAM_NAME" -o "$CA_DIR" > /dev/null
if [[ $? != 0 ]]; then
  echo -e "\tTest passed: Script exited with an error"
else
  echo -e "\tTest failed: Script did not exit with an error"
  exit 1
fi
set -e  # Enable exiting on error

# Test 3: Missing output directory
echo -e "\nTesting missing output directory..."
set +e  # Disable exiting on error
"$TEST_PROGRAM_NAME" -n "$CA_NAME" > /dev/null
if [[ $? != 0 ]]; then
  echo -e "\tTest passed: Script exited with an error"
else
  echo -e "\tTest failed: Script did not exit with an error"
  exit 1
fi
set -e  # Enable exiting on error

# Test 4: Invalid output directory
echo -e "\nTesting invalid output directory..."
touch /tmp/output_file
set +e  # Disable exiting on error
"$TEST_PROGRAM_NAME" -n "$CA_NAME" -o /tmp/output_file > /dev/null
if [[ $? != 0 ]]; then
  echo -e "\tTest passed: Script exited with an error"
else
  echo -e "\tTest failed: Script did not exit with an error"
  exit 1
fi
rm /tmp/output_file
set -e  # Enable exiting on error

# Test 5: Successful execution
echo -e "\nTesting successful execution..."
"$TEST_PROGRAM_NAME" -n "$CA_NAME" -o "$CA_DIR" > /dev/null
assert_exists "$CA_CRT_FILE"
assert_exists "$CA_KEY_FILE"

echo "All tests passed!"