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
# shellcheck disable=SC2164

function usage {
    echo "Usage: deploy [-n nodes] [-t]"
    echo "  -n nodes: number of nodes to deploy (default: 5)"
    echo "  -t: deploy all 8 nodes for use with riak_test"
    echo "  -h: show help"
}

end=5 # default to 5 nodes
rt=false
while getopts "n:th" opt; do
    case $opt in
        n)
            end=$OPTARG
            ;;
        t)
            rt=true
            export ENABLE_SECURITY=false
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

dev_vars_config_src=./rel/vars/dev_vars.config.src
# if rt is true, then update all 8 nodes
if [ "$rt" = true ]; then
    end=8
fi
echo "Deploying $end node""$([ "${end}" -gt 1 ] && echo "s")"

(
cd /root
./stop_nodes.sh
cd $HOME/riak
for ((i=1; i<=end; i++))
do
    ./rel/gen_tls_dev dev${i} $dev_vars_config_src ./rel/vars/${i}_vars.config
    rebar3 as stagedev release -o ./dev/dev${i} --overlay_vars ./rel/vars/${i}_vars.config
done
cd /root
echo -n "Copying..."
rm -rf $HOME/rt/riak/openriak/dev/dev?
cp -p -P -R $HOME/riak/dev $HOME/rt/riak/openriak/

# if this is the fist deployment since creating the container, then warn about running the following
# but only if rt is false
if [ "$rt" = false ]; then
    echo "done"
    ./start_nodes.sh
    echo "=============================================================================================="
    echo "=== To keep these changes, you can commit them to the local git repository                 ==="
    echo "===                       Stop the nodes first.                                            ==="
    echo "===     git -C $HOME/rt/riak/openriak/ add -A                                              ==="
    echo "===     git -C $HOME/rt/riak/openriak/ commit -m \"My Changes\"                            ==="
    echo "===                                                                                        ==="
    echo "===    ********************************************************************************    ==="
    echo "===        To run the test suite, you must commit the changes to the git repository        ==="
    echo "===    ********************************************************************************    ==="
    echo "===                                                                                        ==="
    echo "=============================================================================================="
    if [ ! -f /root/deployed ]; then
        echo ""
        echo "================================================================================"
        echo "==  NOTICE: This is the first deployment since creating the container.        =="
        echo "==  You must run the following commands to complete the deployment            =="
        echo "==  if you want the default configuration to be recreated:                    =="
        echo "================================================================================"
        echo "==  ./create_cluster.sh                                                       =="
        echo "==  ./enable_security.sh                                                      =="
        echo "================================================================================"
        echo "Would you like to run these commands now? (y/n)"
        read -n 1 -s answer
        if [ "$answer" = "y" ]; then
            ./create_cluster.sh
            ./enable_security.sh
        fi
    fi
else
    # if deploying for riak_test, force a git commit of changes
    git -C $HOME/rt/riak/openriak/ add -A
    git -C $HOME/rt/riak/openriak/ commit -m \"Sync\"
    echo "done - ready for riak_test"
fi
touch /root/deployed
)

