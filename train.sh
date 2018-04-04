#!/bin/bash
set -e
METHOD="$1"
START="$2"
END="$3"
if [ "$METHOD" != "pcr" ] && [ "$METHOD" != "self" ] && [ "$METHOD" != "hybrid" ]; then
    echo "Please specify the pcr, self or hybrid training method."
    exit 1
elif [ -z "$START" ] || [ -z "$END" ]; then
    echo "Please specify the start and end number of games."
    exit 1
else
    for PLAYED in $(eval echo {$START..$(($END-10))..10}); do
	if [ "$PLAYED" == "0" ]; then
	    CKPT_TO_LOAD=""
	    PLAY_TO_LOAD=""
	else
	    CKPT_TO_LOAD="saves/$METHOD.$PLAYED.ckpt"
	    PLAY_TO_LOAD="saves/$METHOD.play"
	fi
	CKPT_TO_SAVE="saves/$METHOD.$(($PLAYED+10)).ckpt"
	PLAY_TO_SAVE="saves/$METHOD.play"
	TD_CONFIG="((hidden_layer_sizes (40)) (ckpt_to_load ($CKPT_TO_LOAD)))"
	REPLAY_MEMORY_CONFIG="((capacity (50_000)) (play_to_load ($PLAY_TO_LOAD)))"
	INSTRUCTIONS="((games 10) (train (minibatch_size 128) (minibatches_number 500)) (save_ckpt $CKPT_TO_SAVE) (save_play $PLAY_TO_SAVE))"
	if [ "$METHOD" == "pcr" ] || ([ "$METHOD" == "hybrid" ] && [ "$PLAYED" -lt 500 ]); then
	    _build/default/main.exe\
		-X "(pip_count_ratio (look_ahead 2))"\
		-O "same"\
		-train "(td (td_config $TD_CONFIG) (replay_memory_config $REPLAY_MEMORY_CONFIG))"\
		-instructions "$INSTRUCTIONS"
	else
	    _build/default/main.exe\
		-X "(td (td_config $TD_CONFIG) (look_ahead 2))"\
		-O "same"\
		-train "(same (replay_memory_config $REPLAY_MEMORY_CONFIG))"\
		-instructions "$INSTRUCTIONS"
	fi
    done | tee -a "saves/$METHOD.train.log"
fi
