#!/bin/bash
set -x

MYHOSTNAME=`hostname`

if [ $MYHOSTNAME == "MBP-von-Andreas.fritz.box" ]
then
    echo "auf´m Mac '$MYHOSTNAME'"
else
    echo "in Multipass '$MYHOSTNAME'"
fi 

if false; then
    echo Niemals
else
    echo Immer
fi

echo Done