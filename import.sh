# Based on https://dba.stackexchange.com/questions/83125/mysql-any-way-to-import-a-huge-32-gb-sql-dump-faster/83385#83385

mysqlStateFile="$HOME/mysql.optimized.for.exports"
mysqlConfigLocation="/etc/mysql/my.cnf" # <-- change to the correct for your system, should be for global mysql settings

function mysqlOptimizeForImports {
  echo 'Configuring Mysql for faster imports'
  
  __optimize && echo '1' >> "$mysqlStateFile"
}
function __optimize {
  if [ -f "$mysqlStateFile" ]; then
    __restore
  fi
  echo '[mysqld]' | tee -a "$mysqlConfigLocation"                            # rows added 1
  echo 'innodb_buffer_pool_size = 2G' | tee -a "$mysqlConfigLocation"        # rows added 2
  echo 'innodb_log_buffer_size = 256M' | tee -a "$mysqlConfigLocation"       # rows added 3
  echo 'innodb_log_file_size = 1G' | tee -a "$mysqlConfigLocation"           # rows added 4
  echo 'innodb_write_io_threads = 12' | tee -a "$mysqlConfigLocation"        # rows added 5
  echo 'innodb_flush_log_at_trx_commit = 0' | tee -a "$mysqlConfigLocation"  # rows added 6
  service mysql restart --innodb-doublewrite=0

  echo
  echo 'Sanity checkout, should be 12 ==>'
  echo 
  mysql --user=espespesp --password=espespesp --execute="SHOW GLOBAL VARIABLES LIKE '%innodb_write_io_threads%'"
}
function __restore {
  sed -i '$ d' "$mysqlConfigLocation"    # row removed 1
  sed -i '$ d' "$mysqlConfigLocation"    # row removed 2
  sed -i '$ d' "$mysqlConfigLocation"    # row removed 3
  sed -i '$ d' "$mysqlConfigLocation"    # row removed 4
  sed -i '$ d' "$mysqlConfigLocation"    # row removed 5
  sed -i '$ d' "$mysqlConfigLocation"    # row removed 6
}

function mysqlDefaultSettings {
  if [ -f "$mysqlStateFile" ]; then
    echo "restoring settings"
    __restore

    rm -- "$mysqlStateFile"
  fi

  service mysql restart

  echo
  echo 'Sanity checkout, should be 4 ==>'
  mysql --user=espespesp --password=espespesp --execute="SHOW GLOBAL VARIABLES LIKE '%innodb_write_io_threads%'"
}


printf "Starting new loop\n"
startDate=$(date "+%s")

today=$(date +"%Y-%m-%d") 
# today="2022-05-13"

mysqldump --user=espespesp --password=espespesp --verbose KOM user deck user_card card_deck > "./dumps/database-dump-$today.sql"

wget  -O "./sources/AllPrintings-$today.sql.gz" "https://mtgjson.com/api/v5/AllPrintings.sql.gz"

gzip -d -k "./sources/AllPrintings-$today.sql.gz"

mysqlOptimizeForImports

mysql --user=espespesp --password=espespesp --database=KOM --verbose --execute="drop table meta;"
mysql --user=espespesp --password=espespesp --database=KOM --verbose --execute="drop table set_translations;"
mysql --user=espespesp --password=espespesp --database=KOM --verbose --execute="drop table foreign_data;"
mysql --user=espespesp --password=espespesp --database=KOM --verbose --execute="drop table legalities;"
mysql --user=espespesp --password=espespesp --database=KOM --verbose --execute="drop table rulings;"
mysql --user=espespesp --password=espespesp --database=KOM --verbose --execute="drop table tokens;"
# mysql --user=espespesp --password=espespesp --database=KOM --verbose --execute="drop table cards;" 
mysql --user=espespesp --password=espespesp --database=KOM --verbose --execute="drop table sets;"

# mysql --user=espespesp --password=espespesp --database=KOM --verbose --execute="source ./sources/AllPrintings-$today.sql;"
# mysql --user=espespesp --password=espespesp --database=KOM --execute="source ./sources/AllPrintings-$today.sql;"
mysql --user=espespesp --password=espespesp --database=KOM --force < "./sources/AllPrintings-$today.sql"

mysqlDefaultSettings

rm "./sources/AllPrintings-$today.sql"

endDate=$(date "+%s")
let duration=endDate-startDate
let seconds=duration%60
let minutes=duration/60
echo
echo "import finished in $minutes m $seconds s"
echo 