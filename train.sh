if [ "$1" -gt "$2" ]; then
    STEP="$2"
    END="$1"
else
    STEP="$1"
    END="$2"
fi
for I in $(eval echo {$STEP..$END..$STEP}); do
    echo "Games $(($I-$STEP+1)) to $I:"
    _build/default/main.exe train -games "$STEP" -load-file "td_$(($I-$STEP)).ckpt" -save-file "td_$I.ckpt"
done
