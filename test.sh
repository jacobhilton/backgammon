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
    for PLAYED in $(eval echo {$(($START+10))..$END..10}); do
	echo "After $PLAYED games:"
	TD_CONFIG="((hidden_layer_sizes (40)) (ckpt_to_load (saves/$METHOD.$PLAYED.ckpt)))"
	_build/default/main.exe\
	    -X "(td (td_config $TD_CONFIG) (look_ahead 1))"\
	    -O "(pip_count_ratio (look_ahead 2))"\
	    -instructions "((Games 100))"
    done | tee -a "saves/$METHOD.test.log"
fi
