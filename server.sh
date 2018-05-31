#!/bin/bash
{
set -e
export LIBRARY_PATH=~/libtensorflow/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=~/libtensorflow/lib:$LD_LIBRARY_PATH
set -u
DIR=~/backgammon_server
EXE="${DIR}/backgammon.exe"
STDIN_FIFO="${DIR}/stdin.fifo"
OUTPUT_TXT="${DIR}/output.txt"
OUTPUT_LOG="${DIR}/output.log"
STDERR_LOG="${DIR}/stderr.log"
TD_CONFIG="((hidden_layer_sizes (400 400 400 400 400)) (activation Relu) (representation Expanded) (ckpt_to_load (${DIR}/large.5000.ckpt)))"
if ! [[ -p "${STDIN_FIFO}" ]]; then
  mkfifo "${STDIN_FIFO}"
  chmod a+w "${STDIN_FIFO}"
fi
while sleep 1; do
  if [[ -f "${OUTPUT_TXT}" ]]; then
    cat "${OUTPUT_TXT}" >> "${OUTPUT_LOG}"
  fi
  > "${OUTPUT_TXT}"
  tee -a "${OUTPUT_TXT}" <> "${STDIN_FIFO}" | {
    "${EXE}" \
      -X "human" \
      -O "(td (td_config ${TD_CONFIG}) (look_ahead 1))" \
      -instructions "((Games 1))"
    printf "Press enter to begin a new game. "
  } 2>> "${STDERR_LOG}" >> "${OUTPUT_TXT}"
done
exit 0;
}
