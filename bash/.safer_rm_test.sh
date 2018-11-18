SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

source ".safer_rm.sh"

run_test() {
    cd "${SCRIPT_DIR}"
    fn="${1}"
    echo "================================================================================" &&
        echo "fn: ${fn}" &&
        mkdir --parents "testdir/" &&
        mkdir --parents "testdir/Some Folder/" &&
        mkdir --parents "testdir/somedir/" &&
        touch "testdir/Some Folder/file inside folder.txt" &&
        touch "testdir/anotherfile.txt" &&
        touch "testdir/file.txt" &&
        touch "testdir/notes.txt" &&
        touch "testdir/notes2.txt" &&
        touch "testdir/notes3.txt" &&
        touch "testdir/table of contents.txt" &&
        cd "testdir/" &&
        eval "${fn}"
}

test_all() {
    set -x

    run_test 'rm "file.txt"'
    test $? = 0 || return 1

    run_test 'rm * my\ file.txt'
    test $? = 1 || return 1

    run_test 'rm "file.txt" table\ of\ contents.txt'
    test $? = 0 || return 1

    run_test 'rm "file.txt" table\ of\ contents.txt *'
    test $? = 1 || return 1

    run_test 'rm *'
    test $? = 1 || return 1

    run_test 'rm file.txt'
    test $? = 0 || return 1

    run_test 'rm notes*.txt'
    test $? = 0 || return 1

    run_test 'rm notes*.txt file.txt'
    test $? = 0 || return 1

    run_test 'rm notes*.txt file.txt table\ of\ contents.txt'
    test $? = 0 || return 1

    run_test 'rm --verbose notes*.txt file.txt table\ of\ contents.txt'
    test $? = 0 || return 1

    set +x
}

test_all
if [[ $? -eq 0 ]]; then
    echo "pass"
else
    echo "fail"
fi

cd "${SCRIPT_DIR}"
