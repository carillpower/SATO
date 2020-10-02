#!/bin/bash

############################################
# Created by    : Shahril
# Objective     : SHAHRIL - ALter Column Online

# Requirement   :
#
# create user bkp_login@172.17.0.100 identified by 'Backup1234%';
# grant EXECUTE,SELECT,ALTER,DELETE,DROP,INSERT,UPDATE,CREATE,TRIGGER on quiz.* to bkp_login@172.17.0.100;
# grant RELOAD on *.* to bkp_login@172.17.0.100;

# mysql_config_editor set --login-path=bkp_login --host=172.17.0.100 --user=bkp_login --password

# Howto         : /opt/SACO.sh [user] [port] [db_name related] [table_name related] [column_name related] [datatype want to change] [default_value want to add] [datatype_length want to change]
# Howto         : /opt/SACO.sh bkp_login 3306 quiz results_exercises subject_id INT 0 11
# Howto         : /opt/SACO.sh bkp_login 3306 quiz test_results_exercises ts TIMESTAMP 0 "CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, ADD INDEX (ts)"
# Create date   : 01-MAR-2018
# Version       : 1.0
############################################

. /root/.bash_profile

dir=/opt
dir2=/var/lib/mysql-files
val=10000
nm=changing

user=$1
port=$2
dbnm=$3
tbl=$4
col=$5
if [ $( echo -n $8|wc -m ) -lt 5 ]; then
 dt=$( echo $6"("$8")" )
 def=$7
else
 dt=$6
 def=$8
fi


echo 'haha' $(mysql --login-path=$user -P $port -N -e "SELECT concat(',',column_name) FROM information_schema.columns a WHERE table_schema = '$dbnm' and table_name = '$tbl' ORDER BY ORDINAL_POSITION; ") > $dir/$nm
sed 's/haha ,//g' $dir/$nm > $dir/$nm.1
val1=$( cat $dir/$nm.1 )
echo 'haha' $(mysql --login-path=$user -P $port -N -e "SELECT concat(',NEW.',column_name) FROM information_schema.columns a WHERE table_schema = '$dbnm' and table_name = '$tbl' ORDER BY ORDINAL_POSITION; ") > $dir/$nm
sed 's/haha ,//g' $dir/$nm > $dir/$nm.2
val2=$( cat $dir/$nm.2 )

echo "====================================================================" >> $dir/timing.txt
echo "Start process at $(date)" >> $dir/timing.txt
sleep 1
pri=$(mysql --login-path=$user -P $port -N -e "SELECT column_name iloveu FROM information_schema.columns WHERE table_schema = '$dbnm' and table_name = '$tbl' AND column_key = 'PRI' ; " )
total=$(mysql --login-path=$user -P $port -N -e "SELECT max($pri) iloveu FROM $dbnm.$tbl ; " )
rows=$(mysql --login-path=$user -P $port -N -e "SELECT table_rows iloveu FROM information_schema.tables where table_schema = '$dbnm' and table_name = '$tbl' ; " )

wait
####### Cover for REAL TIME #########
mysql --login-path=$user -P $port $dbnm << END_ALL &
DROP TRIGGER IF EXISTS TRIG_INSERT_SACO_$tbl;
DELIMITER //
CREATE TRIGGER TRIG_INSERT_SACO_$tbl AFTER INSERT ON $dbnm.$tbl
for each row
BEGIN
IF (NEW.$pri > $total ) then
insert into $dbnm.SACO_$tbl (
$val1
) select 
$val2
;
END IF;
END;
//
DELIMITER ;
exit
END_ALL

wait
####### Start Process ######
if [ $7 == 'INDEX' ]; then
 if [ $6 == 'ADD' ]; then

echo "Start Adding index for $5 at $(date)" >> $dir/timing.txt
mysql --login-path=$user -P $port -e "ALTER TABLE $dbnm.$tbl $6 $7 ($col), ALGORITHM=INPLACE, LOCK=NONE; "

 elif [ $6 == 'DROP' ]; then

echo "Start Dropping index for $5 at $(date)" >> $dir/timing.txt
index=$(mysql --login-path=$user -P $port -N -e "SELECT index_name FROM (SELECT index_schema, index_name, GROUP_CONCAT( column_name ORDER BY seq_in_index ASC SEPARATOR ',' ) haha FROM information_schema.statistics WHERE table_name = '$tbl' and table_schema = '$dbnm' GROUP BY index_schema, index_name ) a WHERE haha = '$col' limit 1 ; ")
wait
mysql --login-path=$user -P $port -e "ALTER TABLE $dbnm.$tbl $6 $7 $index, ALGORITHM=INPLACE, LOCK=NONE; "

 fi

else
echo "Start change datatype for $5 at $(date)" >> $dir/timing.txt
##################################
mysql --login-path=$user -P $port $dbnm << END_ALL &
DELIMITER //
CREATE PROCEDURE PROC_SACO_$tbl ( 
fst INT , lst INT 
) 
BEGIN
insert ignore into $dbnm.SACO_$tbl ( $val1 ) 
select SQL_NO_CACHE  $val1  
from $dbnm.$tbl where $pri between fst and lst ; 
END;
//
DELIMITER ;
exit
END_ALL
##################################

rotate=$( echo "$total/$val"|bc ) 
rotate2=$( echo "$rotate + 2"|bc ) 
rotate3=$( echo "($rotate2/15)+1"|bc)

mysql --login-path=$user -P $port -e "set global slow_query_log = 0; "
mysql --login-path=$user -P $port -e "drop table if exists $dbnm.SACO_$tbl ;"
mysql --login-path=$user -P $port -e "create table $dbnm.SACO_$tbl like $dbnm.$tbl; "
if [ $( echo -n $8|wc -m ) -lt 5 ]; then
 mysql --login-path=$user -P $port -e "alter table $dbnm.SACO_$tbl modify column $col $dt default '$def' ; "
else
 mysql --login-path=$user -P $port -e "alter table $dbnm.SACO_$tbl modify column $col $dt default $def ; "
fi

wait
for x in {1..15..1} ; do
loop=$( echo "$rotate3 * $x"|bc )

if [ $x == 1 ]; then 
xx=1
else
xx=$( echo "($loop - $rotate3)+1"|bc )
fi

while [ $xx -le $loop ] ; do
start_dt=$(date +%Y-%m-%d" "%H:%M:%S)
lst=$(echo "$xx*$val"|bc)
fst=$(echo "($lst-$val)+1"|bc)

mysql --login-path=$user -P $port $dbnm -e "SET UNIQUE_CHECKS = 0; CALL PROC_SACO_$tbl( $fst, $lst ); " &
xx=$(( $xx + 1 ))
done
wait
echo "Round $x done at $(date) " >> $dir/timing.txt
mysql --login-path=$user -P $port -N -e "flush tables $dbnm.SACO_$tbl ; "
done

######################################################################################
mysql --login-path=$user -P $port $dbnm -e "DROP PROCEDURE IF EXISTS PROC_SACO_$tbl; "
mysql --login-path=$user -P $port $dbnm -e "DROP TRIGGER IF EXISTS TRIG_INSERT_SACO_$tbl; "
mysql --login-path=$user -P $port $dbnm -e "RENAME TABLE $tbl TO backup_$tbl; "
mysql --login-path=$user -P $port $dbnm -e "RENAME TABLE SACO_$tbl TO $tbl; "
mysql --login-path=$user -P $port -e "set global slow_query_log = 1; "
rm -f $dir/$nm*
rm -f $dir2/$dbnm.$tbl.*
rm -f $dir2/split.$dbnm.$tbl.*
rm -f $dir2/$dbnm.SACO_$tbl.*
fi


echo "Process for $dbnm.$tbl end at $(date) for roughly $rows rows " >> $dir/timing.txt


