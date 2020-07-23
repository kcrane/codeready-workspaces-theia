#!/bin/bash
NODE_VER=10.19.0
JOBIDS=""
#for a in x86_64 s390x ppc64le ; do
for a in x86_64 ; do
#for a in s390x ; do
    [ "$a" == "x86_64" ] && NODE_ARCH=x64 || NODE_ARCH=$a
    sed 's|${ARCH}|'$a'|g;s|${GITHUB_TOKEN}|'${GITHUB_TOKEN}'|g;s|${NODE_ARCH}|'${NODE_ARCH}'|g;s|${NODE_VER}|'${NODE_VER}'|g;s|&|&amp;|g' beaker-job.xml > beaker-job-$a.xml
    JOBID=$(bkr job-submit beaker-job-$a.xml | sed -E "s|.*(J:[0-9]*).*|\1|")
    JOBIDS="$JOBIDS $JOBID"
    rm beaker-job-$a.xml
done
for j in $JOBIDS ; do
    bkr job-watch $j
done
