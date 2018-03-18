START="$1"
STEP="$2"
END="$3"
GAMES="$4"
for I in $(eval echo {$(($START+$STEP))..$END..$STEP}); do
    echo "After $(($I-$STEP)) games:"
    if [ "$I" -eq "$STEP" ]; then TO_LOAD=""; else TO_LOAD="ckpt/td_orig_$(($I-$STEP)).ckpt"; fi
    _build/default/main.exe -X "(td (look_ahead 1) (hidden_layer_sizes (40)) (representation Original) (ckpt_to_load ($TO_LOAD)))" -O '(pip_count_ratio (look_ahead 0))' -games "$GAMES"
done | tee -a "ckpt/test_td_orig_vs_random_$1_$2_$3_$4.txt"
