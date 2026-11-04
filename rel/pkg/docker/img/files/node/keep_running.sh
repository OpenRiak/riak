#!/bin/bash
# -------------------------------------------------------------------
#
# Copyright (c) 2026 Workday, Inc.
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

# Script for keeping a container running until shutdown signal
# Usage: keep_running.sh

echo "Container is now running. Waiting for shutdown signal..."

# Keep container running
while true; do
  if [ -f /root/shutdown ]; then
    echo "Shutdown signal received, stopping container..."
    rm /root/shutdown
    break
  fi
  sleep 5
done

echo "Container shutdown complete"
