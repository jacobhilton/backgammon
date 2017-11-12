if [ "$1" -gt "$2" ]; then
    STEP="$2"
    END="$1"
else
    STEP="$1"
    END="$2"
fi
for I in $(eval echo {$STEP..$END..$STEP}); do
    echo "Games $(($I-$STEP+1)) to $I:"
    if [ "$I" -eq "$STEP" ]; then TO_LOAD=""; else TO_LOAD="ckpt/td_mod_$(($I-$STEP)).ckpt"; fi
    _build/default/main.exe -X '(pip_count_ratio (look_ahead 2))' -O 'same' -train "(td (hidden_layer_sizes (40)) (representation Modified) (ckpt_to_load ($TO_LOAD)) (ckpt_to_save ckpt/td_mod_$I.ckpt) (learning_rate 0.1))" -game "$STEP"
done
