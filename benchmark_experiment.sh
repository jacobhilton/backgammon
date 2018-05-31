#!/bin/bash
{
set -euo pipefail
LOOKAHEAD="$1"
START="$2"
END="$3"
EXE="${BASH_SOURCE%/*}/_build/default/main.exe"
SAVES="${BASH_SOURCE%/*}/saves"
if [[ -z "${LOOKAHEAD}" ]]; then
  echo "Please specify the look-ahead."
  exit 1
elif [[ -z "${START}" ]] || [[ -z "${END}" ]]; then
  echo "Please specify the start and end number of games."
  exit 1
else
  for PLAYED in $(eval echo {${START}..$((${END}-10))..10}); do
    PLAYED="$((${PLAYED}+10))"
    TD_CONFIG=""
    echo "After ${PLAYED} games:"
    "${EXE}" \
      -X "(td (td_config ((hidden_layer_sizes (400 400 400 400 400)) (activation Relu) (representation Expanded) (ckpt_to_load (${SAVES}/large.${PLAYED}.ckpt)))) (look_ahead ${LOOKAHEAD}))" \
      -O "(gnubg (display false) (command gnubg) (import_file /tmp/snowie.import.txt) (export_file /tmp/snowie.export.txt))" \
      -instructions "((Games 100))"
  done | tee -a "${SAVES}/benchmark.${LOOKAHEAD}.log"
fi
exit 0;
}
