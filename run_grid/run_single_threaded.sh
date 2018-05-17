#!/bin/bash

GGCHEM_DIR=/home/stanley/packages/GGchem

for logZ in `seq -1 0.05 3`
do
    trap "echo Exited!; exit;" SIGINT SIGTERM
    echo $logZ

    cd $GGCHEM_DIR
    dirname=run_grid/result_$logZ
    rm -rf $dirname
    mkdir $dirname    
    
    python run_grid/makeAbun.py run_grid/abund_solar.in $logZ > abundances.in
    cp abundances.in $dirname
    ./ggchem run_grid/model_template.in > $dirname/output
    
    cp Static_Conc_2D.dat $dirname
done


