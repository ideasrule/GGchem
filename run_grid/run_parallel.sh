#!/bin/bash

GGCHEM_DIR=/home/stanley/packages/GGchem

for logZ in `seq -1 0.05 3`
do
    trap "echo Exited!; exit;" SIGINT SIGTERM
    echo $logZ

    dirname=result_$logZ
    rm -rf $dirname
    mkdir $dirname
    cd $dirname
    
    python ../makeAbun.py ../abund_solar.in $logZ > abundances.in
    cp ../model_template.in model.in
    ln -s $GGCHEM_DIR/data data
    $GGCHEM_DIR/ggchem model.in > output  &
    cd ..
done

wait
