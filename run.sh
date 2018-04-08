#!/bin/bash
{
set -euo pipefail
ACTION="$1"
METHOD="$2"
START="$3"
END="$4"
EXE="${BASH_SOURCE%/*}/_build/default/main.exe"
SAVES="${BASH_SOURCE%/*}/saves"
if [[ "${ACTION}" != "train" ]] && [[ "${ACTION}" != "test" ]]; then
  echo "Please specify whether to train or test."
  exit 1
elif [[ "${METHOD}" != "pcr" ]] && [[ "${METHOD}" != "self" ]] && [[ "${METHOD}" != "hybrid" ]]; then
  echo "Please specify the pcr, self or hybrid training method."
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
      CKPT_TO_LOAD="${SAVES}/${METHOD}.${PLAYED}.ckpt"
      PLAY_TO_LOAD="${SAVES}/${METHOD}.play"
    fi
    CKPT_TO_SAVE="${SAVES}/${METHOD}.$((${PLAYED}+10)).ckpt"
    PLAY_TO_SAVE="${SAVES}/${METHOD}.play"
    TD_CONFIG="((hidden_layer_sizes (40)) (activation Sigmoid) (ckpt_to_load (${CKPT_TO_LOAD})))"
    ABANDON_AFTER="500"
    if [[ "${ACTION}" == "train" ]]; then
      REPLAY_MEMORY_CONFIG="((capacity (50_000)) (play_to_load (${PLAY_TO_LOAD})))"
      INSTRUCTIONS="((games 10) (train (minibatch_size 128) (minibatches_number 500)) (save_ckpt ${CKPT_TO_SAVE}) (save_play ${PLAY_TO_SAVE}))"
      if [[ "${METHOD}" == "pcr" ]] || ([[ "${METHOD}" == "hybrid" ]] && [[ "${PLAYED}" -lt 500 ]]); then
        "${EXE}" \
          -X "(pip_count_ratio (look_ahead 2))" \
          -O "same" \
          -train "(td (td_config ${TD_CONFIG}) (replay_memory_config ${REPLAY_MEMORY_CONFIG}))" \
          -instructions "${INSTRUCTIONS}" \
          -abandon-after "${ABANDON_AFTER}"
      else
        "${EXE}" \
          -X "(td (td_config ${TD_CONFIG}) (look_ahead 2))" \
          -O "same" \
          -train "(same (replay_memory_config ${REPLAY_MEMORY_CONFIG}))" \
          -instructions "${INSTRUCTIONS}" \
          -abandon-after "${ABANDON_AFTER}"
      fi
    elif [[ "${ACTION}" == "test" ]]; then
      echo "After ${PLAYED} games:"
      "${EXE}" \
        -X "(td (td_config ${TD_CONFIG}) (look_ahead 1))" \
        -O "(pip_count_ratio (look_ahead 2))" \
        -instructions "((Games 100))" \
        -abandon-after "${ABANDON_AFTER}"
    fi
  done | tee -a "${SAVES}/${METHOD}.${ACTION}.log"
fi
exit 0;
}
