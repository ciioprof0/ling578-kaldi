#!/bin/bash

#kaldi run script for speech commands dataset
#mike hammond, u. of arizona, 8/2021

#define a bunch of variables
datadir=/mhdata/commands/
mfccdir=mfcc
train_cmd="utils/run.pl"
decode_cmd="utils/run.pl"
nj=15
lm_order=1
trainnum=1000
testnum=100

#variable for digits to translate file names
declare -a arr=("zero" "one" "two" "three" "four"
	"five" "six" "seven" "eight" "nine")

#specify where programs are and how they interact
. ./path.sh || exit 1
. ./cmd.sh || exit 1

#make data directory
mkdir data
#where to put the wave files
mkdir data/wavefiles
#make test directory
mkdir data/test
#make train directory
mkdir data/train

#create wav.scp (specify location of wav files)
touch data/test/wav.scp
touch data/train/wav.scp

#rename and copy wave files
echo copying wave files
echo creating wav.scp, text, utt2spk files

#make the text files (what's in each wav file)
touch data/test/text
touch data/train/text

#make utt2spk files (specify speaker for each file)
touch data/test/utt2spk
touch data/train/utt2spk

#loop through the files doing all that
for q in "${arr[@]}"
do
	filenames=`ls $datadir$q/*0.wav`
	filenames=($filenames)
	#training files
	for filename in ${filenames[@]:0:${trainnum}}
	do
		speaker=`echo $filename | sed 's/.*\///'`
		speaker=`echo $speaker | sed 's/_.*//'`
		pfx="${speaker}_${q}"
		cp $filename data/wavefiles/${pfx}.wav
		echo ${pfx} data/wavefiles/${pfx}.wav >> data/train/wav.scp
		echo ${pfx} ${q} >> data/train/text
		echo -e "${pfx} ${speaker}" >> data/train/utt2spk
	done
	#testing files
	for filename in ${filenames[@]:${trainnum}:${testnum}}
	do
		speaker=`echo $filename | sed 's/.*\///'`
		speaker=`echo $speaker | sed 's/_.*//'`
		pfx="${speaker}_${q}"
		cp $filename data/wavefiles/${pfx}.wav
		echo ${pfx} data/wavefiles/${pfx}.wav >> data/test/wav.scp
		echo ${pfx} ${q} >> data/test/text
		echo -e "${pfx} ${speaker}" >> data/test/utt2spk
	done
done

#create corpus file (list all word tokens in wav files)
echo Creating corpus file
mkdir data/local
touch data/local/corpus.txt

for i in "${arr[@]}"
do
	echo $i >> data/local/corpus.txt
done

#check/fix data directories
echo Fixing, validating, sorting
cp -r ../wsj/s5/utils .
./utils/validate_data_dir.sh data/test
./utils/fix_data_dir.sh data/test
./utils/validate_data_dir.sh data/train
./utils/fix_data_dir.sh data/train

#copy trivial language model files
echo Moving language model files
mkdir data/local/dict
cp verylang/*.txt data/local/dict

#making MFCCs
echo Creating mfccs
cp -r ../wsj/s5/steps .
cp -r ../an4/s5/conf .

#make MFCC log directories
mkdir exp
mkdir exp/make_mfcc
mkdir exp/make_mfcc/train
mkdir exp/make_mfcc/test

#make the mfccs themselves
steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" \
	data/train exp/make_mfcc/train $mfccdir
steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" \
	data/test exp/make_mfcc/test $mfccdir

#cepstral mean/variance statistics per speaker (cmvn)
steps/compute_cmvn_stats.sh data/train \
	exp/make_mfcc/train $mfccdir
steps/compute_cmvn_stats.sh data/test \
	exp/make_mfcc/test $mfccdir

#prepare language data (trivial here)
echo Preparing language data
utils/prepare_lang.sh data/local/dict "<UNK>" \
	data/local/lang data/lang

#build language model
echo Building language model

local=data/local

#make arpa/binary version of LM
mkdir $local/tmp
../../tools/srilm/bin/i686-m64/ngram-count -order $lm_order \
	-write-vocab $local/tmp/vocab-full.txt -wbdiscount -text \
	$local/corpus.txt -lm $local/tmp/lm.arpa

#make G.fst file (binary version for language model)
lang=data/lang
../../src/lmbin/arpa2fst --disambig-symbol=#0 \
	--read-symbol-table=$lang/words.txt $local/tmp/lm.arpa \
	$lang/G.fst

#monophone/letter unigram training (HMM-GMMs)
steps/train_mono.sh --nj $nj --cmd "$train_cmd" data/train \
	data/lang exp/mono || exit 1

#mono decoding/testing

#copy scripts
cp -r ../an4/s5/local .
#do decision trees
utils/mkgraph.sh --mono data/lang exp/mono \
	exp/mono/graph || exit 1
#score
steps/decode.sh --config conf/decode.config --nj $nj --cmd \
	"$decode_cmd" exp/mono/graph data/test exp/mono/decode

#mono alignment (for building triphones)
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train \
	data/lang exp/mono exp/mono_ali || exit 1

#triphone training (collect segment HMMs into triphones)
steps/train_deltas.sh --cmd "$train_cmd" 2000 11000 data/train \
	data/lang exp/mono_ali exp/tri1 || exit 1

#triphone decoding/testing

#make decision trees
utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph || exit 1
#score
steps/decode.sh --config conf/decode.config --nj $nj --cmd \
	"$decode_cmd" exp/tri1/graph data/test exp/tri1/decode

echo '
All done!'

