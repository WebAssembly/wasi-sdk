#!/bin/bash
#
# Copyright 2004-2026 Free Software Foundation, Inc.
# Contributed by Ben Elliston <bje@gnu.org>.
#
# This test reads pairs from config-sub.data: an alias and its
# canonical triplet.  config.sub is invoked and the test checks that
# the alias expands to the expected canonical triplet.

set -eu
shopt -s lastpipe
verbose=false
maxprocs=16

# Run a single config.sub invocation.
run_one_config_sub()
{
	alias=$1
	canonical=$2
	output=$(sh -eu ../config.sub "$alias")
	if test "$output" != "$canonical" ; then
	    echo "FAIL: $alias -> $output, but expected $canonical"
	    return 1
	else
	    $verbose && echo "PASS: $alias -> $canonical"
	fi
	return 0
}

run_config_sub()
{
	local -i rc=0 jobs=0
	numtests=0
	name="checks"
	while read -r alias canonical ; do
		run_one_config_sub "$alias" "$canonical" &
		numtests+=1 jobs+=1
		if test $jobs -eq $maxprocs ; then
			for pid in $(jobs -p) ; do
				wait "$pid"
				rc=$((rc || $?))
			done
			jobs=0
		fi
	done < config-sub.data
	for pid in $(jobs -p) ; do
		wait "$pid"
		rc=$((rc || $?))
	done
	return $rc
}

# Run a single config.sub invocation for idempotency checks.
run_one_config_sub_idempotent()
{
    canonical=$1
    output=$(sh -eu ../config.sub "$canonical")
    if test "$output" != "$canonical" ; then
	echo "FAIL: $canonical -> $output, but $canonical should map to itself"
	return 1
    else
	$verbose && echo "PASS: $canonical -> $canonical"
    fi
    return 0
}

run_config_sub_idempotent()
{
	local -i rc=0 jobs=0
	numtests=0
	name="idempotency checks"
	sed -r 's/\t+/\t/g' < config-sub.data | cut -f 2 | uniq | while read -r canonical ; do
		run_one_config_sub_idempotent "$canonical" &
		numtests+=1 jobs+=1
		if test $jobs -eq $maxprocs ; then
			for pid in $(jobs -p) ; do
				wait "$pid"
				rc=$((rc || $?))
			done
			jobs=0
		fi
	done
	for pid in $(jobs -p) ; do
		wait "$pid"
		rc=$((rc || $?))
	done
	return $rc
}

run_config_sub_with_guess_triplets()
{
	local -i rc=0
	numtests=0
	name="canonicalise each config.guess testcase"

	awk -F '|' '{ print $6 }' < config-guess.data | while read -r triplet ; do
	    output=$(sh -eu ../config.sub "$triplet")
	    if test "$triplet" != "$output" ; then
		echo "FAIL: $triplet -> $output, but $triplet should map to itself"
		rc=1
	    fi
	    numtests+=1
	done
	return $rc
}


declare -i rc=0 numtests
declare name

for testsuite in run_config_sub run_config_sub_idempotent run_config_sub_with_guess_triplets ; do
	if $testsuite; then
		$verbose || echo "PASS: config.sub $name ($numtests tests)"
	else
		rc=1
	fi
done

exit $rc
