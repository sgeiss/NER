#!/bin/bash

# realise un apprentissage non supervise; base sur en2.hier et en2.c

# objectif=faire ceci sur le gigaword + ESTER2 train + ESTER2 test
# en forcant les classes E seulement sur la partie ESTER2 train
# puis en recuperant les samples de E sur la partie ESTER2 test
# reste a moyenner ces samples sur ESTER2 test et a garder le meilleur comme feature pour le CRF

# en2.c doit etre modifie pour:
# 1- lire les "gold E" sur la partie ESTER2 train (cf. en.c qui fait ca)
# 2- modifier le sampling de H: forcer H a ne prendre des valeurs QUE sur le voisinnage de w

JCP="bin:../utils/bin:../../git/jsafran/jsafran.jar"
allens="pers fonc org loc prod time amount"
dest2="/home/ubuntu/windisk/data/corpus/ESTER2ftp/package_scoring_ESTER2-v1.7/information_extraction_task"
export PATH=$PATH:$dest2/tools

if [ "1" == "0" ]; then
echo "save Gigaword as .xml"
for (( i=1; i<341; i++ ))
do
java -cp "$JCP" GigawordIO $i
java -cp "$JCP" jsafran.JSafran -retag c$i.xml
mv -f output.xml c$i.xml
done
fi

if [ "1" == "0" ]; then
echo "unsup clustering"
#echo "c0b.conll" > unlab.xmll
cat gw.xmll > unlab.xmll
rm -f train.xmll test.xmll
touch train.xmll test.xmll
ls train/*_mate.xml > train.xmll
ls test/*.xml | grep -v -e merged > test.xmll
java -Xmx2500m -cp "$JCP" ester2.Unsup -creeObs unlab.xmll train.xmll test.xmll > creeobs.log

gcc -g stats.c samplib.c en2.c -o en2.exe -lm
./en2.exe | tee en.log
java -cp "$JCP" ester2.Unsup -analyse en.log > an.log
fi

if [ "1" == "0" ]; then
echo "creation fichiers de train du CRF"
cat gw.xmll > unlab.xmll
rm -f train.xmll test.xmll
touch train.xmll test.xmll
ls train/*_mate.xml > train.xmll
ls test/*.xml | grep -v -e merged > test.xmll

for i in $allens
do
  java -Xmx2500m -cp "$JCP" ester2.Unsup -inserttab en.log groups.$i.tab.train groups.$i.tab.test unlab.xmll train.xmll test.xmll
done
fi

if [ "0" == "0" ]; then
echo "train CRF"
for en in $allens
do
  sed 's,trainFile=synfeats0.tab,trainFile=groups.'$en'.tab.train.out,g' syn.props > tmp.props
  java -Xmx20g -cp detcrf.jar edu.stanford.nlp.ie.crf.CRFClassifier -prop tmp.props
  mv kiki.mods en.$en.mods
done
fi

if [ "0" == "0" ]; then
for en in $allens
do
  echo "test the CRF for $en"
  java -Xmx20g -cp detcrf.jar edu.stanford.nlp.ie.crf.CRFClassifier -loadClassifier en.$en.mods -testFile groups.$en.tab.test.out > test.$en.log
done
fi

# merge les res dans un seul stmne
if [ "0" == "0" ]; then
echo "put all CRF outputs into a single xml file"
java -Xmx20g -cp "$JCP" ester2.ESTER2EN -mergeens test.xmll $allens
echo "convert the graph.xml into a .stm-ne file"
nl=`wc -l test/trs2xml.list | cut -d' ' -f1`
for (( c=1; c<=$nl; c++ ))
do
  trs=`awk '{if (NR=='$c') print $1}' test/trs2xml.list`
  grs=`awk '{if (NR=='$c') print $2}' test/trs2xml.list | sed 's,\.xml,.xml.merged.xml,g'`
  out=`echo $grs | sed 's,\.xml\.merged\.xml,,g'`".stm-ne"
  echo "build stmne from $trs $grs $out"
  java -Xmx20g -cp "$JCP" ester2.STMNEParser -project2stmne $grs $trs $out
done
fi

# eval selon protocole ESTER2
if [ "0" == "0" ]; then
score-ne -rd $dest2/../../EN/test/ -cfg $dest2/example/ref/NE-ESTER2.cfg -dic $dest2/tools/ESTER1-dictionnary-v1.9.1.dic test/*.stm-ne
fi

