file=$1
echo $0 $1
LD_PRELOAD=$2 ./bin/$file;
