#!/bin/bash

export PROJECT_ROOT=$(pwd) # FIXME

export LST_DIR=${PROJECT_ROOT}/localstack
export BUILD_DIR=${PROJECT_ROOT}/build

export LST_LOG=${BUILD_DIR}/localstack.log
export TEST_LOG=${BUILD_DIR}/test.log

export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

export TF_ACC=1
export ACCTEST_PARALLELISM=1

function run_test() {
    log="build/$1.log"
    TF_LOG=debug bin/run-tests -t $t &> $log
}

function run_checker() {
    log="build/$1.log"

    while true; do
        sleep 1
        if grep --max-count=1 -q "attempt 4/25" ${log} &> /dev/null; then
            pkill -f "aws.test"
            echo "[ltt-runner] terminated $1"
            break
        fi
    done
}

function run_localstack() {
    cd ${LST_DIR}
    source .venv/bin/activate
    exec bin/localstack start --host
}

function main() {
    rm -f ${LST_LOG}
    # start localstack in the background
    run_localstack > >(tee ${LST_LOG}) 2>&1 &
    export lst_pid=$! # returns the pid of run_localstack https://stackoverflow.com/a/8048493/804840

    # TODO: subprocesses will stay open if interrupted

    # wait for localstack to be ready
    echo "waiting on localstack to start on process ${lst_pid}"

    while true; do
        sleep 1

        if `grep --max-count=1 -q "Ready\." ${LST_LOG}`; then
            break
        fi
        if ! ps -p ${lst_pid} > /dev/null; then
            echo "localstack terminated while waiting"
            exit 1
        fi
    done

    tail -F build/test.log 2> /dev/null | egrep "(FAIL|PASS|SKIP)" &

    for t in `bin/list-tests`; do
        run_checker $t &
        cpid=$!

        echo "[ltt-runner] running $t"
        run_test $t

        echo "[ltt-runner] completed"

        kill $cpid &> /dev/null
        rm "build/${t}.log"
    done
}

trap 'kill $(jobs -p)' EXIT
main "$@"
