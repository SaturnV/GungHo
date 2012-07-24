#! /bin/bash

cd `dirname "$0"`

export PERL5LIB=../lib

n=0
ok=0
failed_test=''

for i in *.t
do
  if [[ -x "$i" ]]
  then
    echo "######## $i"
    ((n++))

    if ! "./$i"
    then
      failed_test="$failed_test $i"
    else
      ((ok++))
    fi
  fi
done

echo "Successfully ran $ok/$n tests."

if [[ -n "$failed_test" ]]
then
  echo "!!!! FAILED TESTS:$failed_test"
  exit 1
fi
