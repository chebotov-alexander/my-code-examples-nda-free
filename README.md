# About repo
Some of my notable code worth to demonstrate with no NDA restrictions
## Databases
### Oracle Database
#### [Improved custom made replication mechanism](https://github.com/chebotov-alexander/my-code-examples-nda-free/blob/main/databases/oracle-db/replicator-to-public.pck)
Replication is a custom made mechanism to copy data into one massive global database from hundreds of local databases.
Before the change the replication were using only SCN (System Change Number) - all new rows had to be replicated all at once for each table involved in the process. There were few exceptions for a couple of tables of having special column indicating when to get replicated.
The time intervals between each replication iteration were fixed.

There were three types of big annoying problems that demanded constant every day attention:
  * First: each new change in the database user code or other part of the system might cause replication to hang at some point, which in turn would lead to a thorough investigation of the code, megabytes of logs in each local and global databases, communication with teammates etc.
  * Second: from time to time new or updated data caused replication to fail on constraints check in global or local databases.
  * Third: happened rarely, but very annoying. Once big, wide table got updated all affected rows rushed from the local database to the global database just to block it for sure. At this moment the blocked global database couldn't serve requests as expected, or at all. The same thing happened if the global database was offline for at least half an hour. Next was a couple of hours annoying copying of this data chunk by chunk from the local to the global.
  For the first and second types if you are lucky and find bad data quickly (searching though the logs for example) all you have to do is to correct the data. But often all you have left is manually copying all these new/updated data line by line and waiting for bad data to fail on constraints check.

To address all these issues the replication code has been deeply modified making the whole mechanism more flexible and stable, handful of information to find replication errors.
The core idea was to copy (replicate) data in chunks of custom size, not only by changed SCN (all rows with new SCN at once). 

To achieve this objectives the follow changes have been made:
* Modes of replication were introduced:
  - SCN (default): the former way to replicate. Rows with new SCN are copied all at once.
  - SCN with portions (optional): rows with new SCN are copied in chunks.
  - SCN with portions and buffer table (optional and default): the game changer. By default for a several wide, deep and very important tables with time consuming replication process, and optional for the rest of the tables in case of errors. All rows with new SCN are copied locally in the buffer table, which has the special column that assigns an ordinal number to each row. At the moment of the next replication iteration all rows with new SCN are copied into the local buffer table, not to the global database. Each subsequent replication iteration copies only a chunk of these rows from the buffer table into the global database. As soon as the last chunk is copied, the table will be considered replicated.
  - Status column with or without SCN (optional): To support this mode, it is necessary to modify each user table by adding a new special column of replication readiness status, which is its huge disadvantage.
  - Status column with portions, with or without SCN (optional): same as before but copied in chunks.
* Added auto-tuning functionality to automatically alter some replication parameters, for example, changing the time interval between replication iteration in case of a certain number of consecutive errors, changing the replication mode in case of replication freezes, as well as changing the changing the portion/chunk size. 
* In addition to saving logs, now, in case of an error, the error message and the call stack are saved in the local table of replication that existed before.
* Added statistics gathering to auto-tune replication parameters and a better understanding of the causes of replication errors. These statistics are stored in the local table of replication, which has been greatly widened.
* The local table of replication from each local server is now included in replication. This makes possible to alter replication parameters from a single point - the global database - and access the error message for each replication error.

As a result:
  * Far fewer complaints from teammates about corrupted or stale data, almost none
  * Much faster assistance in finding the cause of problems and the development process.
  * The "phantom transaction" error occurred almost every day, now it's once a month at most.
  * A much smaller number of distributed transactions in doubts: from a few each days to once a month.
  * The global database is no longer blocked. Warming up smoothly after being offline no matter for how long, the same in case of transaction storm from database clients and local databases. The progressive replication interval tuning and the threshold on the number of consecutive errors make the job.
  * The third type of problems has been eliminated.
  * To solve problems of the first and second types first you need to set the portion/chunk size to 1 (i.e. one row per replication iteration) wait replication to hang, and then just look at the row number in the buffer table where replication is stuck. That's the row you're looking for.
  * Logging error message, call stack along with rich statistic on each replication error for each table and replication of this information from each local database to the global one greatly help to cope with problems of the second and especially the first type.

Here are most notable changes in code.
Brand new functions/procedures:
  * :exclamation: function initialize_upload_table_info(...)
  * :exclamation: procedure finalize_upload_table(...)
  * :exclamation: function tune_upload_table_info(...)
  * function set_upload_table_info(...)
  * procedure change_upload_table_run_status(...)
  * procedure check_rep_up_modes(...)
  * function generate_session_uid()
  * function is_parent_table_update_allowed(...)
  * function get_upload_table_info(...)
  * function get_pk_column_name(...)
  * function get_random_loc_tbl_column_name(...)
  * function get_buffer_table_name(...)

Significantly modified functions/procedures:
  * :exclamation: procedure upload_one_table(...)
  * :exclamation: function populate_temporary_table(...) -> populate_tmp_buf_table(...)
  * function get_locked_table_scn(...) -> get_upload_table_dbscn(...)
  * function transfer_table_data(...)
  * procedure upload_table_data(...)
  * procedure update_table_scn(...) -> update_parent_table_scn(...)
  * procedure upload_table_dict(...) -> upload_parent_table(...)
  * procedure upload_all_tables(...)
  * function get_temporary_table_columns(...)


#### ["Trim" solution to 11g XE limit on storage size](https://github.com/chebotov-alexander/my-code-examples-nda-free/blob/main/databases/oracle-db/archive_oradata_create_table_and_procedure-to-public.sql)
The sql script creates schema objects a system admin can call to migrate data from main database storage to external file storage in order to overcome Oracle Database 11g XE's 11 gigabyte storage size limitation.

The data being migrated can be read and copied from the external file back to the main database storage.

The set of user tables the data to be migrated is predefined so that only local specific data will be migrated and that data will be at least two years older from the moment of the procedure call.

Further improvement should rebuild the indexes and enable constraints for all tables involved, only once at the end of migration regardless of how many years this procedure should transfer data for. Currently, the data is transferred table by table for each year, which is specified in the procedure call with a parameter. After all data is transferred, the procedure runs the indexes rebuild and enables constraints
as much time as the number of years for which data is transferred for each table. Simply put, there is redundancy that should be eliminated. Thus, after such an improvement, the time spent on the procedure should be significantly reduced.


#### [Functions that find similarities between address objects as strings](https://github.com/chebotov-alexander/my-code-examples-nda-free/blob/main/databases/oracle-db/merge-addresses-to-public.pck)
Utilizes "Nested Tables", "Pipelined Table Functions", "Analytic Functions" to significally alter and improve user-defined functions that find similarities between address objects as strings. A couple of helper functions prepare external raw data to extract semantically different parts. Then new core function "addobj_similarity()" assigns a weights to each string pair - the ones from internal address data storage with external ones - where meaningful similarity have been found. The tigher similarity the pair has, the more weight it gets. In the end the person responsible for the city map using desktop client can verify the result and make informative decision if there is some doubts.

Further improvement of the similarity accuracy should be base on comparing the coordinates of the address objects.


### MySQL
#### [Locking functionality in MySQL like its GET_LOCK() but free of its notorious bugs before MySQL 5.7](https://github.com/chebotov-alexander/my-code-examples-nda-free/blob/main/databases/mysql/execution_lock-to-public.sql)
Introduced locking functionality prevents execution of user code and put this execution in queue by name as GET_LOCK() does.

Before MySQL 5.7 its GET_LOCK() and RELEASE_LOCK() functions have bugs - the second lock clear the first one and two named locks aren't possible.

The task behind was to effectivly clean two multi-million tables each with intensive write workload. The idea was iteratively delete rows in chunks with "low_priority" mode using "GET_LOCK()"/"RELEASE_LOCK()" and "event" with the "scheduler". But the bug mentioned above fail this idea. Upgrade to bug-free MySQL release was not possible.

[The bug - https://bugs.mysql.com/bug.php?id=1118](https://bugs.mysql.com/bug.php?id=1118)

[MySQL 5.7 locking-functions - https://dev.mysql.com/doc/refman/5.7/en/locking-functions.html](https://dev.mysql.com/doc/refman/5.7/en/locking-functions.html)
