#!/bin/bash
# usage: run.sh profile extra-args...
cd /Users/stevin/Documents/Projects/MyChickenArmy/tools/sim
P=$1; shift
case $P in
 typical) A="pullGap=45 rollPatience=120 sellEvery=90 eff=0.6 treeGap=120 treePerVisit=1 feed=false";;
 engaged) A="pullGap=15 rollPatience=45 sellEvery=60 eff=0.85 treeGap=30 treePerVisit=2 feed=true feedAfter=300";;
esac
exec /private/tmp/claude-501/-Users-stevin-Documents-Projects-MyChickenArmy/70572320-9165-4b1f-96d7-cb14a06f4185/scratchpad/lune-bin/lune run harness.luau ../.. /private/tmp/claude-501/-Users-stevin-Documents-Projects-MyChickenArmy/70572320-9165-4b1f-96d7-cb14a06f4185/scratchpad/retention/ws2/early.luau seeds=30 $A "$@"
