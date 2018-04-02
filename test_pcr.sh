TD_LOOK_AHEAD=$1
PIP_COUNT_RATIO_LOOK_AHEAD=$2
if [ -z $PIP_COUNT_RATIO_LOOK_AHEAD ]; then PIP_COUNT_RATIO_LOOK_AHEAD=2; fi
if [ -z $TD_LOOK_AHEAD ]; then TD_LOOK_AHEAD=1; fi
for repetition in {1..100}; do
    echo "After ${repetition}00 minibatches:"
    _build/default/main.exe -X "(td (td_config ((hidden_layer_sizes (40)) (ckpt_to_load (saves/pcr.${repetition}00.ckpt)))) (look_ahead ${TD_LOOK_AHEAD}))" -O "(pip_count_ratio (look_ahead ${PIP_COUNT_RATIO_LOOK_AHEAD}))" -instructions "((Games 100))" -abandon-after-move "500"
done
