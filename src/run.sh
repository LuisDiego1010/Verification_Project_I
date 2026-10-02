#!/bin/bash
# quick hacky script to compile and run stuff once per width and seed. can override vars from the terminal if you need to test specific stuff
SEED=${SEED:-$RANDOM}
WIDTH=${WIDTH:-16}
DRVS=${DRVS:-6}

CASES=${CASES:-"GENERAL BCAST INVALID SELF OVERFLOW"}

# nuking old junk from previous runs so we start fresh
echo "[RUN] Limpiando archivos de las corridas anteriores"
rm -f *.csv *.log *.png *.vpd ucli.key vc_hdrs.h
rm -rf csrc *.vdb *.daidir DVEfiles simv* salida* novas.* verdiLog *.fsdb

# Start the compilation by running the line to open VCS.
if [ -z "$SKIP_COMPILE" ]; then
    echo "[RUN] Compilando (p_width=$WIDTH, p_drvs=$DRVS) ..."
    vcs -Mupdate -sverilog -full64 \
        testbench.sv -o salida \
        -pvalue+testbench.p_width=$WIDTH \
        -pvalue+testbench.p_drvs=$DRVS \
        -kdb -lca -debug_acc+all -debug_region+cell+encrypt \
        -l comp.log +lint=TFIPC-L \
        -cm line+tgl+cond+fsm+branch+assert \
        -P ${VERDI_HOME}/share/PLI/VCS/linux64/verdi.tab \
        > /dev/null \
        || { echo "Error de compilacion (ver comp.log)"; exit 1; }
fi

# helper function to actually run a single test case, parse the logs, and grep out the delays so we can see them right in the terminal
run_case () {
    local case_name=$1
    shift

    local log="run_${case_name}_w${WIDTH}_seed${SEED}.log"

    printf "[RUN] %-10s " "$case_name"

    ./salida -cm line+tgl+cond+fsm+branch+assert \
        +ntb_random_seed=$SEED +TEST_CASE=$case_name "$@" \
        -l $log > /dev/null

    local res
    res=$(grep -o 'RESULTADO: [A-Z]*' $log | head -1)
    echo -n "${res:-SIN RESULTADO}"

    local ret
    ret=$(grep -o 'retardo min=.*' $log | head -1)
    [ -n "$ret" ] && echo -n "  | $ret"
    echo

    if [ "$case_name" == "OVERFLOW" ]; then
        grep "ocupacion maxima" $log | sed 's/^/         -> /'
    fi
}


# looping through our test cases. checking if we need to do the zero num_tx trick for per-terminal random generation or if we run direct tests like overflow
echo "[RUN] ===== p_width=$WIDTH  p_drvs=$DRVS  semilla=$SEED ====="

for C in $CASES; do
    case $C in
        GENERAL)  run_case GENERAL  +NUM_TX=0 ;;
        BCAST)    run_case BCAST    +NUM_TX=0 ;;
        INVALID)  run_case INVALID  +NUM_TX=0 ;;
        SELF)     run_case SELF     +NUM_TX=0 ;;
        OVERFLOW) run_case OVERFLOW ;;
        *)        run_case $C ;;
    esac
done

echo "[RUN] Generando histogramas..."

# plotting out the histograms but skipping empty csv files because some tests dont actually receive packets
for f in reporte_*_w${WIDTH}_seed${SEED}.csv; do
    [ -f "$f" ] || continue
    # Saltar los CSV sin datos (INVALID y SELF no tienen recepciones)
    [ "$(wc -l < "$f")" -gt 1 ] || { echo "[RUN] $f sin datos, se omite"; continue; }
    gnuplot -e "csvfile='$f'" histograma.gp
done

echo "[RUN] Listo (p_width=$WIDTH, semilla=$SEED)."
echo "      Logs:        run_<caso>_w${WIDTH}_seed${SEED}.log"
echo "      CSV:         reporte_<caso>_w${WIDTH}_seed${SEED}.csv"
echo "      Histogramas: reporte_<caso>_w${WIDTH}_seed${SEED}_histograma.png"
echo "      Cobertura:   verdi -cov -covdir salida.vdb &"
