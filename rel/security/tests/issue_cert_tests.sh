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
#   A script to test issue_cert functionality.
#

ROOT_DIR=$(cd "$(dirname $0)"/.. && pwd)
TEST_PROGRAM_NAME="$ROOT_DIR/bin/issue_cert"

CA_TEST_PROGRAM_NAME="$ROOT_DIR/tests/ca_tests.sh"
CSR_TEST_PROGRAM_NAME="$ROOT_DIR/tests/issue_csr_tests.sh"

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
echo -e "\nTesting show_help function..."
"$TEST_PROGRAM_NAME" -h | grep "path to the certificate" > /dev/null
if [[ $? == 0 ]]; then
  echo -e "\tTest passed: Help message contains expected string"
else
  echo -e "\tTest failed: Help message does not contain expected string"
  exit 1
fi

# Test 2: Missing csr
echo -e "\nTesting missing csr..."
set +e  # Disable exiting on error
"$TEST_PROGRAM_NAME" -c test -k test -o "$CA_DIR" > /dev/null
if [[ $? != 0 ]]; then
  echo -e "\tTest passed: Script exited with an error"
else
  echo -e "\tTest failed: Script did not exit with an error"
  exit 1
fi
set -e  # Enable exiting on error

# Test 3: Missing ca cert
echo -e "\nTesting missing ca cert..."
set +e  # Disable exiting on error
"$TEST_PROGRAM_NAME" -r test -k test -o "$CA_DIR" > /dev/null
if [[ $? != 0 ]]; then
  echo -e "\tTest passed: Script exited with an error"
else
  echo -e "\tTest failed: Script did not exit with an error"
  exit 1
fi
set -e  # Enable exiting on error

# Test 4: Missing ca key
echo -e "\nTesting missing ca key..."
set +e  # Disable exiting on error
"$TEST_PROGRAM_NAME" -r test -c test -o "$CA_DIR" > /dev/null
if [[ $? != 0 ]]; then
  echo -e "\tTest passed: Script exited with an error"
else
  echo -e "\tTest failed: Script did not exit with an error"
  exit 1
fi
set -e  # Enable exiting on error

# Test 5: Missing output directory
echo -e "\nTesting missing output directory..."
set +e  # Disable exiting on error
"$TEST_PROGRAM_NAME" -r test -c test -k test > /dev/null
if [[ $? != 0 ]]; then
  echo -e "\tTest passed: Script exited with an error"
else
  echo -e "\tTest failed: Script did not exit with an error"
  exit 1
fi
set -e  # Enable exiting on error

# Test 6: Invalid output directory
echo -e "\nTesting invalid output directory..."
touch /tmp/output_file
set +e  # Disable exiting on error
"$TEST_PROGRAM_NAME" -r test -c test -k test -o /tmp/output_file > /dev/null
if [[ $? != 0 ]]; then
  echo -e "\tTest passed: Script exited with an error"
else
  echo -e "\tTest failed: Script did not exit with an error"
  exit 1
fi
rm /tmp/output_file
set -e  # Enable exiting on error

# Test 7: Successful execution
echo -e "\nTesting successful execution..."
# First, run ca test and csr tests in order to create necessary artifacts
"$CA_TEST_PROGRAM_NAME" > /dev/null 2>&1
assert_exists "$CA_CRT_FILE"
assert_exists "$CA_KEY_FILE"
"$CSR_TEST_PROGRAM_NAME" > /dev/null 2>&1
assert_exists "$KEY_FILE"
assert_exists "$CSR_FILE"
"$TEST_PROGRAM_NAME" \
  -r "$CSR_FILE" \
  -c "$CA_CRT_FILE" \
  -k "$CA_KEY_FILE" \
  -o "$CA_DIR" > /dev/null
assert_exists "$CRT_FILE"

echo "All tests passed!"
