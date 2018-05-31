#!/bin/bash
{
set -euo pipefail
ACTION="$1"
SIZE="$2"
START="$3"
END="$4"
EXE="${BASH_SOURCE%/*}/_build/default/main.exe"
SAVES="${BASH_SOURCE%/*}/saves"
if [[ "${ACTION}" != "train" ]] && [[ "${ACTION}" != "test" ]]; then
  echo "Please specify whether to train or test."
  exit 1
elif [[ "${SIZE}" != "small" ]] && [[ "${SIZE}" != "medium" ]] && [[ "${SIZE}" != "large" ]]; then
  echo "Please specify the small, medium or large neural network architecture."
  exit 1
elif [[ -z "${START}" ]] || [[ -z "${END}" ]]; then
  echo "Please specify the start and end number of games."
  exit 1
else
  for PLAYED in $(eval echo {${START}..$((${END}-10))..10}); do
    if [[ "${ACTION}" == "test" ]]; then
      PLAYED="$((${PLAYED}+10))"
    fi
    if [[ "${PLAYED}" == "0" ]]; then
      CKPT_TO_LOAD=""
      PLAY_TO_LOAD=""
    else
      CKPT_TO_LOAD="${SAVES}/${SIZE}.${PLAYED}.ckpt"
      PLAY_TO_LOAD="${SAVES}/${SIZE}.play"
    fi
    CKPT_TO_SAVE="${SAVES}/${SIZE}.$((${PLAYED}+10)).ckpt"
    PLAY_TO_SAVE="${SAVES}/${SIZE}.play"
    if [[ "${SIZE}" == "small" ]]; then
      TD_CONFIG="((hidden_layer_sizes (40)) (activation Sigmoid) (representation Modified) (ckpt_to_load (${CKPT_TO_LOAD})))"
    elif [[ "${SIZE}" == "medium" ]]; then
      TD_CONFIG="((hidden_layer_sizes (80 80)) (activation Sigmoid) (representation Expanded) (ckpt_to_load (${CKPT_TO_LOAD})))"
    else
      TD_CONFIG="((hidden_layer_sizes (400 400 400 400 400)) (activation Relu) (representation Expanded) (ckpt_to_load (${CKPT_TO_LOAD})))"
    fi
    if [[ "${ACTION}" == "train" ]]; then
      "${EXE}" \
        -X "(td (td_config ${TD_CONFIG}) (look_ahead 2))" \
        -O "same" \
        -train "(same (replay_memory_config ((capacity (50_000)) (play_to_load (${PLAY_TO_LOAD})))))" \
        -instructions "((games 10) (train (minibatch_size 128) (minibatches_number 500)) (save_ckpt ${CKPT_TO_SAVE}) (save_play ${PLAY_TO_SAVE}))" \
        -abandon-after "500"
    elif [[ "${ACTION}" == "test" ]]; then
      echo "After ${PLAYED} games:"
      "${EXE}" \
        -X "(td (td_config ${TD_CONFIG}) (look_ahead 1))" \
        -O "(td (td_config ((hidden_layer_sizes (40)) (activation Sigmoid) (representation Modified) (ckpt_to_load (${SAVES}/small.5000.ckpt)))) (look_ahead 1))" \
        -instructions "((Games 100))"
    fi
  done | tee -a "${SAVES}/${SIZE}.${ACTION}.log"
fi
exit 0;
}
