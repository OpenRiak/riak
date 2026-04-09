# shellcheck disable=all
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
#   Common variables used by test scripts
#

# names
CA_NAME="TestCA"
CA_DIR="/tmp/output"

NAME="test"
OUT_DIR=$CA_DIR

# artifacts
CA_CRT_FILE="$CA_DIR/$CA_NAME.ca.crt.pem"
CA_KEY_FILE="$CA_DIR/$CA_NAME.ca.key.pem"

KEY_FILE="$OUT_DIR/$NAME.key.pem"
CSR_FILE="$OUT_DIR/$NAME.csr"
CRT_FILE="$CA_DIR/$NAME.crt.pem"
