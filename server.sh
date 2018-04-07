#!/bin/bash
{
set -e
export LIBRARY_PATH=~/libtensorflow/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=~/libtensorflow/lib:$LD_LIBRARY_PATH
set -u
DIR=~/backgammon_server
if ! [[ -p "${DIR}/stdin.fifo" ]]; then
  mkfifo "${DIR}/stdin.fifo"
  chmod a+w "${DIR}/stdin.fifo"
fi
while sleep 1; do
  if [[ -f "${DIR}/output.txt" ]]; then
    cat "${DIR}/output.txt" >> "${DIR}/output.log"
  fi
  > "${DIR}/output.txt"
  tee -a "${DIR}/output.txt" <> "${DIR}/stdin.fifo" | {
    "${DIR}/backgammon.exe"\
      -X "human"\
      -O "(td (td_config ((hidden_layer_sizes (40)) (ckpt_to_load (${DIR}/self.ckpt)))) (look_ahead 1))"\
      -instructions "((Games 1))"
    printf "Press enter to begin a new game. "
  } 2>> "${DIR}/stderr.log" >> "${DIR}/output.txt"
done
exit 0;
}
