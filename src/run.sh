#!/bin/bash
# grabbing our defaults and defining the new output directory outside of src
SEED=${SEED:-$RANDOM}
WIDTH=${WIDTH:-16}
DRVS=${DRVS:-6}
OUT_DIR="../Resultados"

mkdir -p $OUT_DIR
SCRIPT_DIR="$PWD"

# nuking old junk from previous runs in both locations just to be totally safe
echo "[RUN] Limpiando artefactos de corridas anteriores..."
rm -f $OUT_DIR/*.csv $OUT_DIR/*.log $OUT_DIR/*.png $OUT_DIR/*.vpd $OUT_DIR/ucli.key $OUT_DIR/vc_hdrs.h
rm -rf $OUT_DIR/csrc $OUT_DIR/*.vdb $OUT_DIR/*.daidir $OUT_DIR/DVEfiles $OUT_DIR/simv* $OUT_DIR/salida* $OUT_DIR/novas.* $OUT_DIR/verdiLog $OUT_DIR/*.fsdb
rm -f *.csv *.log *.png *.vpd ucli.key vc_hdrs.h
rm -rf csrc *.vdb *.daidir DVEfiles simv* salida* novas.* verdiLog *.fsdb

# hitting the vcs compiler but forcing all the garbage output files to dump into the new folder
if [ -z "$SKIP_COMPILE" ]; then
    echo "[RUN] Compilando (p_width=$WIDTH, p_drvs=$DRVS) ..."
    vcs -Mupdate -sverilog -full64 \
        testbench.sv -o $OUT_DIR/salida \
        -Mdir=$OUT_DIR/csrc \
        -pvalue+testbench.p_width=$WIDTH \
        -pvalue+testbench.p_drvs=$DRVS \
        -kdb -lca -debug_acc+all -debug_region+cell+encrypt \
        -l $OUT_DIR/comp.log +lint=TFIPC-L \
        -cm line+tgl+cond+fsm+branch+assert \
        -cm_dir $OUT_DIR/salida.vdb \
        -P ${VERDI_HOME}/share/PLI/VCS/linux64/verdi.tab \
        > /dev/null \
        || { echo "Error de compilacion (ver $OUT_DIR/comp.log)"; exit 1; }
fi

# helper function running a single test case
run_case () {
    local case_name=$1
    shift

    local log="$OUT_DIR/run_${case_name}_w${WIDTH}_seed${SEED}.log"

    printf "[RUN] %-10s " "$case_name"

    $OUT_DIR/salida -cm line+tgl+cond+fsm+branch+assert \
        -cm_dir $OUT_DIR/salida.vdb \
        -cm_name $case_name \
        +ntb_random_seed=$SEED +TEST_CASE=$case_name "$@" \
        -l $log > /dev/null

    local expected_csv="reporte_${case_name,,}_w${WIDTH}_seed${SEED}.csv"
    if [ -f "$expected_csv" ]; then
        mv "$expected_csv" $OUT_DIR/
    fi

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

echo "[RUN] ===== p_width=$WIDTH  p_drvs=$DRVS  semilla=$SEED ====="

# TEST SELECTOR
run_case GENERAL  +NUM_TX=0
run_case BCAST    +NUM_TX=0
run_case INVALID  +NUM_TX=0
run_case SELF     +NUM_TX=0
run_case OVERFLOW


echo "[RUN] Generando los Histogramas."

for f in "$OUT_DIR"/reporte_*_w${WIDTH}_seed${SEED}.csv; do
    [ -f "$f" ] || continue
    [ "$(wc -l < "$f")" -gt 1 ] || { echo "[RUN] $(basename "$f") sin datos, se omite"; continue; }
    
    
    (cd "$OUT_DIR" && gnuplot -e "csvfile='$(basename "$f")'" "$SCRIPT_DIR/histograma.gp")
done

# sweeping up any rogue verdi files
mv novas.* verdiLog $OUT_DIR/ 2>/dev/null || true

echo "[RUN] Listo (p_width=$WIDTH, semilla=$SEED)."
echo "      Logs:        $OUT_DIR/run_<caso>_w${WIDTH}_seed${SEED}.log"
echo "      CSV:         $OUT_DIR/reporte_<caso>_w${WIDTH}_seed${SEED}.csv"
echo "      Histogramas: $OUT_DIR/reporte_<caso>_w${WIDTH}_seed${SEED}_histograma.png"
echo "      Cobertura:   verdi -cov -covdir $OUT_DIR/salida.vdb &"
