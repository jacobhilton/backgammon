START="$1"
STEP="$2"
END="$3"
GAMES="$4"
for EXPONENT in {1..9}; do
    for BASE in 1 3; do
	LEARNING_RATE="${BASE}e-$EXPONENT"
	echo "Using a learning rate of $LEARNING_RATE."
	for I in $(eval echo {$(($START+$STEP))..$(($END+$STEP))..$STEP}); do
	    if [ "$I" -eq "$STEP" ]; then TO_LOAD=""; else TO_LOAD="ckpt/td_mod_$(($I-$STEP)).ckpt"; fi
	    echo "After $(($I-$STEP)) games:"
	    _build/default/main.exe -X "(td (look_ahead 1) (hidden_layer_sizes (40)) (representation Modified) (ckpt_to_load ($TO_LOAD)))" -O '(pip_count_ratio (look_ahead 0))' -games "$GAMES"
	    if [ "$I" -ne "$(($END+$STEP))" ]; then
		echo "Games $(($I-$STEP+1)) to $I:"
		_build/default/main.exe -X '(pip_count_ratio (look_ahead 2))' -O 'same' -train "(td (hidden_layer_sizes (40)) (representation Modified) (ckpt_to_load ($TO_LOAD)) (ckpt_to_save ckpt/td_mod_$I.ckpt) (learning_rate $LEARNING_RATE))" -games "$STEP"
	    fi
	done
    done
done | tee "ckpt/learning_rate_search_$1_$2_$3_$4.txt"
