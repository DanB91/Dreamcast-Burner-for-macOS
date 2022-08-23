#!/bin/bash

APP_FOLDER="DreamcastBurner.app"
EXE_NAME="dreamcast_burner"
build_app() {
        odin build . -debug -out:$EXE_NAME && 
            rm -rf $APP_FOLDER && 
            mkdir -p $APP_FOLDER && 
            mv $EXE_NAME $APP_FOLDER/ && 
            mv *.dSYM $APP_FOLDER/
}
run_app() {
    $APP_FOLDER/$EXE_NAME $@
}
case "$1" in
*)
    shift
    build_app
    ;;
"run")
    shift
    build_app
    run_app $@
    ;;
esac