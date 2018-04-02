CKPT_TO_LOAD=""
PLAY_TO_LOAD=""
for repetition in {1..100}; do
    CKPT_TO_SAVE="saves/self.${repetition}0.ckpt"
    PLAY_TO_SAVE="saves/self.play"
    _build/default/main.exe -X "(td (td_config ((hidden_layer_sizes (40)) (ckpt_to_load ($CKPT_TO_LOAD)))) (look_ahead 2))" -O "same" -train "(same (replay_memory_config ((capacity (50_000)) (play_to_load ($PLAY_TO_LOAD)))))" -instructions "((games 10) (train (minibatch_size 128) (minibatches_number 500)) (save_ckpt $CKPT_TO_SAVE) (save_play $PLAY_TO_SAVE))" -abandon-after-move "500"
    CKPT_TO_LOAD="$CKPT_TO_SAVE"
    PLAY_TO_LOAD="$PLAY_TO_SAVE"
done
