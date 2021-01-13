git submodule update --init --remote
echo contracts/ > ./.git/modules/contracts/submodule/info/sparse-checkout
cd contracts/submodule
git config core.sparsecheckout true
git read-tree -mu HEAD


path="./contracts/*"
files=`find $path -type f`
for file in $files; do
    cat $file | (rm $file; sed -e 's/..\/..\/..\/..\/node_modules/..\/..\/node_modules/' > $file)
    cat $file | (rm $file; sed -e 's/..\/..\/node_modules/..\/..\/..\/..\/node_modules/' > $file)
done