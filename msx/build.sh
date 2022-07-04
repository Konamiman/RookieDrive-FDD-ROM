VERSION=2.1
SRC_PATH=$(dirname "$0")
BIN_PATH=$SRC_PATH/bin

mkdir -p $BIN_PATH

echo RookieDrive FDD ROM version $VERSION
echo

sjasm $SRC_PATH/rookiefdd.asm $BIN_PATH/rookiefdd${VERSION}_normal.rom

sed 's/INVERT_CTRL_KEY: equ 0/INVERT_CTRL_KEY: equ 1/g' $SRC_PATH/config.asm > $SRC_PATH/temp.asm
sjasm $SRC_PATH/temp.asm $BIN_PATH/rookiefdd${VERSION}_inverted_ctrl.rom

sed 's/DISABLE_OTHERS_BY_DEFAULT: equ 0/DISABLE_OTHERS_BY_DEFAULT: equ 1/g' $SRC_PATH/config.asm > $SRC_PATH/temp.asm
sjasm $SRC_PATH/temp.asm $BIN_PATH/rookiefdd${VERSION}_exclusive.rom

sed 's/USE_ALTERNATIVE_PORTS: equ 0/USE_ALTERNATIVE_PORTS: equ 1/g' $SRC_PATH/config.asm > $SRC_PATH/temp.asm
sjasm $SRC_PATH/temp.asm $BIN_PATH/rookiefdd${VERSION}_alt_ports.rom

sed 's/INVERT_CTRL_KEY: equ 0/INVERT_CTRL_KEY: equ 1/g' $SRC_PATH/config.asm > $SRC_PATH/temp.asm
sed -i 's/DISABLE_OTHERS_BY_DEFAULT: equ 0/DISABLE_OTHERS_BY_DEFAULT: equ 1/g' $SRC_PATH/temp.asm
sjasm $SRC_PATH/temp.asm $BIN_PATH/rookiefdd${VERSION}_exclusive_inverted_ctrl.rom

sed 's/INVERT_CTRL_KEY: equ 0/INVERT_CTRL_KEY: equ 1/g' $SRC_PATH/config.asm > $SRC_PATH/temp.asm
sed -i 's/USE_ALTERNATIVE_PORTS: equ 0/USE_ALTERNATIVE_PORTS: equ 1/g' $SRC_PATH/temp.asm
sjasm $SRC_PATH/temp.asm $BIN_PATH/rookiefdd${VERSION}_alt_ports_inverted_ctrl.rom

sed 's/DISABLE_OTHERS_BY_DEFAULT: equ 0/DISABLE_OTHERS_BY_DEFAULT: equ 1/g' $SRC_PATH/config.asm > $SRC_PATH/temp.asm
sed -i 's/USE_ALTERNATIVE_PORTS: equ 0/USE_ALTERNATIVE_PORTS: equ 1/g' $SRC_PATH/temp.asm
sjasm $SRC_PATH/temp.asm $BIN_PATH/rookiefdd${VERSION}_alt_ports_exclusive.rom

sed 's/INVERT_CTRL_KEY: equ 0/INVERT_CTRL_KEY: equ 1/g' $SRC_PATH/config.asm > $SRC_PATH/temp.asm
sed -i 's/DISABLE_OTHERS_BY_DEFAULT: equ 0/DISABLE_OTHERS_BY_DEFAULT: equ 1/g' $SRC_PATH/temp.asm
sed -i 's/USE_ALTERNATIVE_PORTS: equ 0/USE_ALTERNATIVE_PORTS: equ 1/g' $SRC_PATH/temp.asm
sjasm $SRC_PATH/temp.asm $BIN_PATH/rookiefdd${VERSION}_alt_ports_exclusive_inverted_ctrl.rom

rm $SRC_PATH/temp.*

