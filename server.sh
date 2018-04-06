#!/bin/bash
{
set -euo pipefail
DIR="${HOME}/backgammon_server"
if ! [[ -p "${DIR}/stdin.fifo" ]]; then
    mkfifo "${DIR}/stdin.fifo"
fi
if [[ -f "${DIR}/output.txt" ]]; then
    cat "${DIR}/output.txt" >> "${DIR}/output.log"
fi
> "${DIR}/output.txt"
tee -a "${DIR}/output.txt" <> "${DIR}/stdin.fifo" | while sleep 1; do
    "${DIR}/backgammon.exe"\
	-X "human"\
	-O "(td (td_config ((hidden_layer_sizes (40)) (ckpt_to_load (${DIR}/self.ckpt)))) (look_ahead 1))"\
	-instructions "((Games 1))"
done 2>> "${DIR}/stderr.log" >> "${DIR}/output.txt"
exit 0;
}
