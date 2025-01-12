rem Создание структур в базе данных для архивирования данных некоторых пользовательских таблиц
rem   Решена проблема ограничения на размер таблиц данных Oracle Database 11g в редакции XE.

set echo off
set verify off
set serveroutput on

--Директория '.../oracle_archived_oradata/' должна существовать и иметь владельца 'oracle'
--drop directory ORACLE_ARCHIVED_ORADATA;
create or replace directory ORACLE_ARCHIVED_ORADATA as '.../oracle_archived_oradata/';
/

--drop type estloc.tbl_clob force;
create or replace type estloc.tbl_clob as table of clob;
/

--drop table estloc.org_data_arch_hist;
create table estloc.org_data_arch_hist(
  arch_file_name varchar2(100) not null,
  arch_file_table_name varchar2(60) not null,
  org_table_name varchar2(60) not null,
  ext_tmp_table_name varchar2(60) not null,
  arch_period_year integer not null,
  session_uid number,
  arch_hist_status integer not null,
  process_priority integer not null,
  org_table_size_mb number not null,
  org_table_size_after_mb number,
  org_table_row_count number,
  arch_table_row_count number,
  keep_table_row_count number,
  arch_dt_copy_in_ext_tbl_start date,
  arch_dt_copy_in_ext_tbl_end date,
  arch_dt_copy_in_temp_tbl_start date,
  arch_dt_copy_from_tmp_tbl_end date,
  arch_end_dt date,
  err_msg clob,
  select_from_usr_t_to_ext_t_dml clob not null,
  select_from_usr_t_to_tmp_t_dml clob not null,
  table_desc_ddl clob not null,
  external_tbl_ddl clob not null,
  arch_file_query clob not null,
  table_columns_desc clob not null,
  table_time_filter_column varchar2(30) not null,
  from_where_clause varchar2(4000) not null,
  min_year integer not null,
  table_constraints estloc.tbl_clob,
  table_r_constraints estloc.tbl_clob,
  table_indices estloc.tbl_clob,
  table_primary_key_column varchar2(30),
  job_list estloc.tbl_clob,
  create_dt date not null,
  constraint pk_data_arch_hist primary key (arch_file_name),
  constraint uk_data_arch_hist$tbl_period unique (org_table_name, arch_period_year),
  constraint uk_data_arch_hist$archfl_tblnm unique (arch_file_table_name)
)
nested table table_constraints store as nt_data_arch_hist$cnstrnts
nested table table_r_constraints store as nt_data_arch_hist$r_cnstrnts
nested table table_indices store as nt_data_arch_hist$indices
nested table job_list store as nt_data_arch_hist$job_list
tablespace estloc rowdependencies;
comment on table estloc.org_data_arch_hist
  is 'История архивирования данных пользовательских таблиц.
  Для механизма высвобождения дисковой памяти из-за ограничения в 11 ГБ для Oracle 11.2 Express edition';
comment on column estloc.org_data_arch_hist.arch_file_name
  is 'Наименование файла-архива пользовательской таблицы, составленное из наименования таблицы и периода, например
 org_order__2019, хранит в виде внешнего файла данные таблицы org_order, созданные в 2019 году';
comment on column estloc.org_data_arch_hist.arch_file_table_name
  is 'Наименование внешней таблицы файла-архива пользовательской таблицы, составленное из наименования схемы (владельца),
 таблицы и периода, например estloc.org_order19, ссылается на файл-архив, в котором хранятся данные таблицы org_order,
 созданные в 2019 году. Не путать с arch_file_name, который в первом приближении является нименованием файла в файловой
 системе, а arch_file_table_name является наименованием объекта в СУБД Oracle, на которые наложено ограничение длины
 имени: не более 30 символов в версии 11.2. Для наименования установлена макс. количество символов 60.
 Используется для выборки данных, например "select * from estloc.org_order19"';
comment on column estloc.org_data_arch_hist.org_table_name
  is 'Наименование пользовательской таблицы';
comment on column estloc.org_data_arch_hist.ext_tmp_table_name
  is 'Наименование внешней временной таблицы для неархивируемых данных';
comment on column estloc.org_data_arch_hist.arch_period_year
  is 'Год, за который архивированы данные';
comment on column estloc.org_data_arch_hist.session_uid
  is 'Уникальный идентификатор сессии, генерируемый скриптом архивирования. Используется для исключения параллельного
  выполнения более одного экземпляра скрипта';
comment on column estloc.org_data_arch_hist.arch_hist_status
  is 'Статус архивирования таблицы в файл.
  0 - архивация запланирована
  1 - файл создается
  2 - файл создан
  3 - файл проверяется
  4 - файл проверен
  5 - данные во внешнюю временную таблицу копируются
  6 - данные во внешнюю временную таблицу копированы
  7 - внешняя временная таблица проверяется
  8 - внешняя временная таблица проверена
  9 - данные пользовательской таблицы удаляются
  10 - данные пользовательской таблицы удалены
  11 - данные из внешней временной таблицы копируются в пользовательскую
  12 - данные из внешней временной таблицы копированы в пользовательскую
  13 - пользовательская таблица проверяется
  14 - пользовательская таблица проверена
  15 - внешняя временная таблица удаляется
  16 - внешняя временная таблица удалена
  17 - архивирование успешно завершено
  -5 - ошибка (минус означает ошибку, число означает на каком этапе она произошла, в данном примере на 5 этапе))';
comment on column estloc.org_data_arch_hist.process_priority
  is 'Приоритет обработки таблицы в зависимости от связей с другими таблицами через ограничения ссылочной целостности.
  Рассчитывается из количества ссылок';
comment on column estloc.org_data_arch_hist.org_table_size_mb
  is 'Размер пользовательской таблицы из таблицы dba_segments на момент создания запроса на архивацию';
comment on column estloc.org_data_arch_hist.org_table_size_after_mb
  is 'Размер пользовательской таблицы из таблицы dba_segments после успешного окончания архивации';
comment on column estloc.org_data_arch_hist.org_table_row_count
  is 'Количество строк пользовательской таблицы';
comment on column estloc.org_data_arch_hist.arch_table_row_count
  is 'Количество строк пользовательской таблицы, которые будут архивированы за период arch_period_year';
comment on column estloc.org_data_arch_hist.keep_table_row_count
  is 'Количество строк пользовательской таблицы, которые останутся в ней после архивации';
comment on column estloc.org_data_arch_hist.arch_dt_copy_in_ext_tbl_start
  is 'Дата-время начала копирования данных в внешнюю таблицу файл-архива';
comment on column estloc.org_data_arch_hist.arch_dt_copy_in_ext_tbl_end
  is 'Дата-время окончания копирования данных в внешнюю таблицу файл-архива';
comment on column estloc.org_data_arch_hist.arch_dt_copy_in_temp_tbl_start
  is 'Дата-время начала копирования данных в временную таблицу';
comment on column estloc.org_data_arch_hist.arch_dt_copy_from_tmp_tbl_end
  is 'Дата-время окончания копирования данных из временной таблицы в пользовательскую';
comment on column estloc.org_data_arch_hist.arch_end_dt
  is 'Дата-время успешного окончания архивации';
comment on column estloc.org_data_arch_hist.err_msg
  is 'Текст ошибки';
comment on column estloc.org_data_arch_hist.select_from_usr_t_to_ext_t_dml
  is 'Выражение для выгрузки данных из пользовательской таблицы в файл-архив';
comment on column estloc.org_data_arch_hist.select_from_usr_t_to_tmp_t_dml
  is 'Выражение для выгрузки данных из пользовательской таблицы в временную';
comment on column estloc.org_data_arch_hist.table_desc_ddl
  is 'Описание пользовательской таблицы на период arch_period_year';
comment on column estloc.org_data_arch_hist.external_tbl_ddl
  is 'Выражение создания файла-архива (внешней таблицы)';
comment on column estloc.org_data_arch_hist.arch_file_query
  is 'Выражение для извлечения данных из файла-архива через внешнюю таблицу, если select * from {table_name} не работает';
comment on column estloc.org_data_arch_hist.table_columns_desc
  is 'Описание столбцов таблицы';
comment on column estloc.org_data_arch_hist.table_time_filter_column
  is 'Наименование ключевого столбца, для фильтрации данных';
comment on column estloc.org_data_arch_hist.from_where_clause
  is 'Выражение с фильтрацией данных';
comment on column estloc.org_data_arch_hist.min_year
  is 'Минимальный год логического создания среди всех строк по ключевому столбцу';
comment on column estloc.org_data_arch_hist.table_constraints
  is 'Ограничения таблицы. Список выражений для изменения состояний ограничений';
comment on column estloc.org_data_arch_hist.table_r_constraints
  is 'Ссылочные ограничения других таблиц, на первичный и уникальные ключи таблицы. Список выражений для изменения
  состояний ограничений';
comment on column estloc.org_data_arch_hist.table_indices
  is 'Индексы таблицы. Список выражений для изменения состояний индексов';
comment on column estloc.org_data_arch_hist.table_primary_key_column
  is 'Наименование ключевого столбца';
comment on column estloc.org_data_arch_hist.job_list
  is 'Список периодических заданий. Список выражений для изменения состояний работы. Задания, которые были активны
  далжны отключаться на период процесса архивации, при этом после архивации не должны быть включены задания, которые
  были неактивны до начала архивации';
comment on column estloc.org_data_arch_hist.create_dt
  is 'Дата-время создания файла';

--drop procedure archive_oradata_to_ext_file;
create or replace procedure archive_oradata_to_ext_file(
  p_years_qty_archive_data integer default null,
  p_year_archive_data_by   integer default null,
  p_ignore_existing_errors integer default 0,
  p_session_uid            number  default null
) is
/**
 * Создает файл-архив (внешнюю таблицу) данных пользовательской таблицы. Не архивируются данные за последние два года
 *   при любых значениях параметров. Архивированные данные удаляются из пользовательской таблицы.
 *
 * @param p_years_qty_archive_data  [nullable] - Количество лет, за которые архивировать данные. Значения [1-99].
 *                                                 По умолчанию: 1, если не указан p_year_archive_data_by, иначе null.
 *                                                 Если значение указано, то p_year_archive_data_by должен быть null.
 *                                                 Например, если в таблице храняться данные с 2018 года, то при
 *                                                 значении 2, будут архивированы данные за 2018 и 2019 годы.
 * @param p_year_archive_data_by    [nullable] - Год, до которого архивировать данные в четырехзначном формате.
 *                                                 По умолчанию: null.
 *                                                 Если значение указано, то p_years_qty_archive_data должен быть null.
 *                                                 Например, если в таблице храняться данные с 2017 года, то при
 *                                                 значении 2019, будут архивированы данные за 2017 и 2018 годы.
 * @param p_ignore_existing_errors  [nullable] - Игнорировать ранее возникшие ошибки архивирования и продолжить с шага,
 *                                                 на котором произошла ошибка для каждого файла:
 *                                                 - 1 - игнорировать
 *                                                 - 0 (по умолчанию) - если ошибки есть, скрипт прервет выполнение
 *                                                   работы для всех таблиц
 * @param p_session_uid             [nullable] -  Уникальный идентификатор сессии (идентификатор вызывающей функции/
 *                                                  процедуры). Используется для исключения параллельного выполнения
 *                                                  более одного экземпляра скрипта, иначе данные таблиц могут быть
 *                                                  утеряны безвозвратно (т.е. могут быть восстановлены только из бэкапа).
 *                                                  По умолчанию не указывается.
 *                                                    Если выполнение скрипта было прервано нештатно, например командой
 *                                                    завершения процесса на уровне ОС или БД или потерей электропитания
 *                                                    и т.п., то повторно успешно запустить скрипт можно только, указав
 *                                                    последний перед сбоем сгенерированный идентификатор, который
 *                                                    выводится в строку вывода и зранится в логе и таблице об "История
 *                                                    архивирования данных пользовательских таблиц" для каждой таблицы.
 *
 * @throws ORAERR_CODE_OTHERS -
 */

  /**
   * Описание таблицы
   *
   * @param table_name               [not null] {varchar2} - Наименование, включая наименование владельца
   * @param process_priority         [not null] {integer}  - Приоритет обработки таблицы в зависимости от связей с другими
   *                                                           таблицами через ограничения ссылочной целостности
   * @param table_time_filter_column [not null] {varchar2} - Наименование ключевого столбца, для фильтрации данных
   * @param from_where_clause        [not null] {varchar2} - Выражение с фильтрацией данных
   * @param min_year                 [not null] {integer}  - Минимальный год логического создания строки по ключевому столбцу
   */
  type t_table_desc is record (
    table_name               util.sqlstring  not null default ESTLOC.const.NULL_CHAR,
    process_priority         integer         not null default ESTLOC.const.NULL_NUMBER,
    table_time_filter_column util.identifier not null default ESTLOC.const.NULL_CHAR,
    from_where_clause        util.sqlstring  not null default ESTLOC.const.NULL_CHAR,
    min_year                 integer         not null default ESTLOC.const.NULL_NUMBER
  );
  /** Список таблиц с их описанием */
  type t_table_list is table of t_table_desc;
  /** Информация о архивировании данных пользовательской таблицы за конкретный год */
  subtype t_arch_file_table_desc is estloc.org_data_arch_hist%rowtype;
  l_log estloc.dblogger := estloc.dblog_util.get_dblogger(
    acronym_ => 'SYS_CONFIG',
    fcbuilder_ => estloc.fcbuilder('archive_oradata_to_ext_file')
     .param('p_years_qty_archive_data', p_years_qty_archive_data)
     .param('p_year_archive_data_by', p_year_archive_data_by)
     .param('p_ignore_existing_errors', p_ignore_existing_errors)
     .param('p_session_uid', p_session_uid)
  );
  /**
   * Уникальный идентификатор сессии (идентификатор вызывающей функции/процедуры).
   *   Используется для исключения параллельного выполнения более одного экземпляра скрипта, иначе данные таблиц могут
   *   быть утеряны безвозвратно (т.е. могут быть восстановлены только из бэкапа)
   */
  G_SESSION_UID constant integer := coalesce(p_session_uid, trunc(dbms_random.value(1, 10) * 1000000));
  PROCEDURE_INSTANCE_RUNNING util.sqlstring := 'sys.archive_oradata_to_ext_file(...) procedure running';
  ARCH_ST_SCHEDULED         constant integer := 0;
  ARCH_ST_FILE_CREATING     constant integer := 1;
  ARCH_ST_FILE_CREATED      constant integer := 2;
  ARCH_ST_FILE_CHECKING     constant integer := 3;
  ARCH_ST_FILE_CHECKED      constant integer := 4;
  ARCH_ST_EXT_TMP_COPYING   constant integer := 5;
  ARCH_ST_EXT_TMP_COPIED    constant integer := 6;
  ARCH_ST_EXT_TMP_CHECKING  constant integer := 7;
  ARCH_ST_EXT_TMP_CHECKED   constant integer := 8;
  ARCH_ST_TBL_DATA_DELETING constant integer := 9;
  ARCH_ST_TBL_DATA_DELETED  constant integer := 10;
  ARCH_ST_TBL_COPYING       constant integer := 11;
  ARCH_ST_TBL_COPIED        constant integer := 12;
  ARCH_ST_TBL_CHECKING      constant integer := 13;
  ARCH_ST_TBL_CHECKED       constant integer := 14;
  ARCH_ST_EXT_TMP_DROPING   constant integer := 15;
  ARCH_ST_EXT_TMP_DROPED    constant integer := 16;
  ARCH_ST_SUCCESS           constant integer := 17;
  ARCH_DIRECTORY constant util.string := 'oracle_archived_oradata';
  FULL_ARCH_DIRECTORY constant util.string := '.../oracle_archived_oradata';
  FILE_EXTENTION constant util.string := '.oracle_datapump';
  LOG_FILENAME constant util.string := 'DO_NOT_DELETE_oracle_archived_oradata.log_DO_NOT_DELETE';
  EXT_TMP_PREFIX constant util.identifier := 'ET';
  SCHEMA_PREFIX constant util.identifier := 'ESTLOC';
  MAX_YEAR constant integer := 9999;
  CURRENT_YEAR constant integer := extract(year from estloc.kernel.get_sysdate());
  EXCEPT_CURRENT_AND_YEAR_BEFORE constant integer := 2;
  YEAR_EXCEPT_CUR_AND_YEAR_BEF constant integer := CURRENT_YEAR - EXCEPT_CURRENT_AND_YEAR_BEFORE;
  START_PROC constant util.sqlstring :=
    estloc.sbuilder(
      '========================================================================' || util.SMBL_LINEEND ||
      'Начата процедура архивирования данных в файлы-архивы '||
      '?{period}за ${years_qty_archive_data} год(а)/лет{:}до ${year_archive_data_by} года{period}?'
    )
      .fill('years_qty_archive_data', p_years_qty_archive_data)
      .fill('year_archive_data_by', p_year_archive_data_by)
      .fillif('period', p_years_qty_archive_data is not null)
      .fillif('period', p_year_archive_data_by is not null)
      .to_string();
  START_PROC_ONE_TABLE constant util.sqlstring :=
    'Начата процедура архивирования данных в файл-архив ${file_directory}/${file_name} за ${period} год';
  FINISH_SUCCESSFUL constant util.sqlstring := 'Очистка таблиц завершена успешно';
  FINISH_ERROR constant util.sqlstring := 'Очистка таблиц завершена ошибкой';
  YEAR_NULL_ERR constant util.sqlstring :=
    'Может быть указан только один из параметров p_years_qty_archive_data и p_year_archive_data_by';
  YEARS_QTY_ARCHIVE_DATA_ERR constant util.sqlstring :=
    'Количество лет, за которые архивировать данные, не может быть меньше 1 и больше 99';
  YEAR_ARCHIVE_DATA_BY_ERR constant util.sqlstring :=
    'Год, до которого архивировать данные, указан в неверном формате';
  EXT_TBL_NAME_PLACEHOLDER constant util.string := ' ${ext_tbl_name} ';
  EXT_TBL_LOCATION_PLACEHOLDER constant util.string := ' ${ext_tbl_location} ';
  EXT_TBL_AS_SELECT_PLACEHOLDER constant util.string := ' ${ext_tbl_as_select} ';
  YEAR_PLACEHOLDER constant util.sqlstring := ' ${year} ';
  JOIN_PLACEHOLDER constant util.sqlstring := ' ${join} ';
  JOIN_LEFT constant util.sqlstring := ' left join ';
  COMPARE_MAIN_PLACEHOLDER constant util.sqlstring := ' ${compare_main} ';
  COMPARE_JOIN_PLACEHOLDER constant util.sqlstring := ' ${compare_join} ';
  COMPARE_MAIN_EQUAL constant util.sqlstring := ' = ';
  COMPARE_JOIN_LESSOREQUAL constant util.sqlstring := ' <= ';
  NOT_PLACEHOLDER constant util.sqlstring := ' ${not} ';
  NOT_OPERATOR constant util.sqlstring := ' not ';
  ACTION_PLACEHOLDER constant util.sqlstring := ' ${action} ';
  CONSTRAINT_NAME_PLACEHOLDER constant util.sqlstring := ' ${constraint_name} ';
  ERR_CODE_OTHERS integer := -20999;
  SOURCE_TABLE_ALIAS_PLACEHOLDER constant util.sqlstring := ' ${source_table_alias} ';
  SOURCE_TABLE_ALIAS constant util.sqlstring := ' src_tbl';
  SOURCE_TABLE_ALIAS_FOR_EXT_TBL constant util.sqlstring := ' src_ext_tbl';
  lg_message clob;
  l_year_archive_data_by date;
  lg_currnt_arch_file_table_desc t_arch_file_table_desc;
  l_space_freed number := 0;

  procedure write_log(lp_message clob) is
    ll_file_handler utl_file.file_type;
    ll_message util.string;
  begin
    ll_message := util.prependstr(
      str_ => coalesce(lp_message, 'INIT_MESSAGE'),
      prefix_ => estloc.kernel.get_sysdate(),
      separator_ => ':  ',
      lengthb_ => util.VARCHAR2_MAX_LENGTH
    );
    dbms_output.put_line(ll_message);
    ll_file_handler := utl_file.fopen(upper(ARCH_DIRECTORY), LOG_FILENAME, 'a', util.VARCHAR2_MAX_LENGTH);
    utl_file.put(ll_file_handler, ll_message);
    utl_file.fclose(ll_file_handler);
  exception when others then
    utl_file.fclose(ll_file_handler);
  end write_log;

  /**
   * Возвращает сообщение об ошибке в обратном хронологическом порядке
   *
   * @param lp_message      [nullable] - Сообщение об ошибке
   * @param lp_with_err_stack [nullable] - Признак:
   *                                         true  - вернуть сообщение об ошибке со стеком
   *                                         false - вернуть обычное сообщение об ошибке (по умолчанию)
   *
   * @return [nullable] Сообщение об ошибке
   */
  function prepend_message(
    lp_message clob,
    lp_with_err_stack boolean default false
  ) return varchar2 is
  begin
    return
      util.prependstr(
        str_ => coalesce(lg_message, 'INIT_ERROR_MESSAGE'),
        prefix_ => lp_message || util.ternop(lp_with_err_stack, util.SMBL_LINEEND || error.get_error_info(), ' '),
        separator_ => util.SMBL_LINEEND,
        lengthb_ => util.VARCHAR2_MAX_LENGTH
      );
  exception when others then
    null;
  end prepend_message;

  /**
   * Проверяет вложенную plsql таблицу на не null
   *
   * @param lp_string_nested_table [not null] - Вложенная plsql таблица
   * @param lp_value_name          [nullable] - Наименование таблицы (константы или переменной) для сообщения об ошибке
   */
  procedure check_nested_table_notnull(
    lp_string_nested_table util.strarray,
    lp_value_name varchar2 default 'Вложенная plsql таблица'
  ) is
  begin
    assert.assert_true(
      value_      => lp_string_nested_table is not null,
      value_name_ => lp_value_name,
      comment_    => 'не может быть null'
    );
  end check_nested_table_notnull;

  /**
   * Проверяет вложенная plsql таблица не пустая
   *
   * @param lp_string_nested_table [not null] - Вложенная plsql таблица
   * @param lp_value_name          [nullable] - Наименование таблицы (константы или переменной) для сообщения об ошибке
   */
  procedure check_nested_table_notempty(
    lp_string_nested_table util.strarray,
    lp_value_name varchar2 default 'Вложенная plsql таблица'
  ) is
  begin
    assert.assert_true(
      value_      => lp_string_nested_table is not empty,
      value_name_ => lp_value_name,
      comment_    => 'должна иметь хотя бы один элемент'
    );
  end check_nested_table_notempty;

  /**
   * Возвращает наименование пользовательской таблицы без подстроки о наименовании владельца таблицы
   *
   * @param lp_table_name [not null] - Наименование пользовательской таблицы
   *
   * @return [not null] Описание столбцов пользовательской таблицы
   */
  function cutoff_schema_prefix(lp_table_name varchar2) return varchar2 is
    ll_table_name_wo_prefix util.identifier;
  begin
    assert.assert_not_null(
      value_      => lp_table_name,
      value_name_ => 'lp_table_name'
    );
    ll_table_name_wo_prefix := replace(lp_table_name, SCHEMA_PREFIX || '.', '');
    assert.assert_not_null(
      value_      => ll_table_name_wo_prefix,
      value_name_ => 'll_table_name_wo_prefix',
      comment_ => 'cutoff_schema_prefix вернула null'
    );
    return ll_table_name_wo_prefix;
  end cutoff_schema_prefix;

  /** Проверяет уникальный идентификатор сессии */
  procedure check_session_uid is
    ll_session_uid number;
    ll_soft_kill_session util.sqlstring;
    ll_hard_kill_session util.sqlstring;
    ll_session_info util.sqlstring;
  begin
    begin
      select
        '[alter System Kill Session '''|| to_char(ses."SID") || ',' || to_char(ses."SERIAL#") || ''' IMMEDIATE]',
        '[kill -9 '||to_char(proc."SPID") || ']' hard_kill_command,
        'session info=[' ||
          'machine=' || ses."MACHINE" ||
          '; program=' || ses."PROGRAM" ||
          '; client_info=' || ses."CLIENT_INFO" ||
          '; status=' || ses."STATUS" ||
          '; seconds_in_wait=' || ses."SECONDS_IN_WAIT" ||
          '; logon_time=' || ses."LOGON_TIME" ||
          '; tracefile=' || proc."TRACEFILE" ||
        ']'
      into
        ll_soft_kill_session,
        ll_hard_kill_session,
        ll_session_info
      from v$session ses
        join v$process proc on (proc."ADDR" = ses."PADDR")
      where upper(ses."CLIENT_INFO") = upper(PROCEDURE_INSTANCE_RUNNING);
      exception
        when no_data_found then
          null;
        when too_many_rows then
          lg_message := prepend_message(
            lp_message =>
              'Скрипт архивирования прерван, т.к. существует более одной сессии, в которых уже выполняются другие '||
              'экземпляры скрипта, что является следствием ошибки в коде скрипта. ' ||
              'Требуется вмешательство разработчика БД'
          );
          raise;
        when others then
          raise;
    end;
    assert.assert_true(
      value_      => ll_session_info is null,
      comment_    =>
        'Скрипт архивирования прерван, т.к. в другой сессии уже выполняется другой экземпляр скрипта: ' ||
          ll_session_info || '. Дождитесь завершения или принудительно завершите работу через sqlplus (предпочтительно) ' ||
          ' командой: ' || ll_soft_kill_session || ' или средствами ОС командой: ' || ll_hard_kill_session
    );

    dbms_application_info.set_client_info(PROCEDURE_INSTANCE_RUNNING);

    write_log(lp_message =>
      'Уникальный идентификатор сессии (идентификатор вызывающей функции/процедуры)=[' || G_SESSION_UID || ']'
    );

    begin
      select dah.session_uid
      into ll_session_uid
      from estloc.org_data_arch_hist dah
      where dah.session_uid is not null
      group by dah.session_uid;
    exception
      when no_data_found then
        null;
      when too_many_rows then
        lg_message := prepend_message(
          lp_message =>
            'Скрипт архивирования прерван из-за конфликта значений уникального идентификатора сессии. Таблица истории '||
              'архивирования содержит строки с несколькими разными значениями уникального идентификатора сессии, что '||
              'является следствием ошибки в коде скрипта или ручным изменением данных таблицы. '||
              'Требуется вмешательство разработчика БД'
        );
        raise;
      when others then
        raise;
    end;
    assert.assert_true(
      value_      => coalesce(ll_session_uid, estloc.const.NULL_NUMBER) = coalesce(p_session_uid, estloc.const.NULL_NUMBER),
      comment_    => 'Скрипт архивирования прерван из-за конфликта значений уникального идентификатора сессии. '||
        'Таблица истории архивирования содержит индентификатор = [' || ll_session_uid || '], указанный индентификатор '||
        '= [' || util.ternop(p_session_uid is not null, to_char(p_session_uid), 'null') || '], что является возможным '||
        'признаком недопустимого параллельного выполнения скрипта. Требуется вмешательство разработчика БД'
    );
  exception when others then
    lg_message := prepend_message(
      lp_message =>
        'check_session_uid(' || util.SMBL_LINEEND ||
        '  p_session_uid = ' || p_session_uid || util.SMBL_LINEEND ||
        '  G_SESSION_UID = ' || G_SESSION_UID || util.SMBL_LINEEND ||
        '  ll_session_uid = ' || ll_session_uid || util.SMBL_LINEEND ||
        ')'
    );
    raise;
  end check_session_uid;

  /** Проверяет наличие ранее возникших ошибок архивирования. При наличии выбрасывает исключение */
  procedure check_existing_errors is
    ll_err_count integer := 0;
  begin
    select count(*)
    into ll_err_count
    from estloc.org_data_arch_hist dah
    where dah.arch_hist_status < 0;
    assert.assert_true(
      value_ => ll_err_count = 0,
      comment_ => 'Скрипт архивирования прерван из-за наличия ранее возникших ошибок архивирования. Для игнорирования '||
         'ошибок требуется установить значение параметра "p_ignore_existing_errors" в значение "1"'
    );
  end check_existing_errors;

  /** Удаляет информацию о ранее возникших ошибках архивирования и позволяет скрипту продолжить процесс архивирования
   *    с шага, на котором произошла ошибка
   */
  procedure clear_existing_errors is
  begin
    update estloc.org_data_arch_hist dah
    set
      dah.err_msg = null,
      dah.arch_hist_status = dah.arch_hist_status * -1
    where dah.arch_hist_status < 0;
    commit;
  end clear_existing_errors;

  /** Валидирует входные параметры */
  procedure check_parameters is
  begin
    if (p_years_qty_archive_data is not null and p_year_archive_data_by is not null) then
      write_log(lp_message => YEAR_NULL_ERR);
      dbms_standard.raise_application_error(num => ERR_CODE_OTHERS, msg => YEAR_NULL_ERR, keeperrorstack => true);
    end if;
    if (p_years_qty_archive_data is not null and (p_years_qty_archive_data < 1 or p_years_qty_archive_data > 99)) then
      write_log(lp_message => YEARS_QTY_ARCHIVE_DATA_ERR);
      dbms_standard.raise_application_error(num => ERR_CODE_OTHERS, msg => YEARS_QTY_ARCHIVE_DATA_ERR, keeperrorstack => true);
    end if;
    if (p_year_archive_data_by is not null) then
      begin
        l_year_archive_data_by := to_date(p_year_archive_data_by, 'YYYY');
      exception when others then
        write_log(lp_message => YEAR_ARCHIVE_DATA_BY_ERR);
        dbms_standard.raise_application_error(num => ERR_CODE_OTHERS, msg => YEAR_ARCHIVE_DATA_BY_ERR, keeperrorstack => true);
      end;
    end if;
    check_session_uid();
    if (p_ignore_existing_errors = 1) then
      clear_existing_errors();
    else
      check_existing_errors();
    end if;
  end check_parameters;

  procedure save_error_msg_update_status is
  begin
    update estloc.org_data_arch_hist dah
    set
      dah.err_msg = lg_message,
      dah.arch_hist_status = dah.arch_hist_status * -1
    where dah.arch_file_name = lg_currnt_arch_file_table_desc.arch_file_name;
    commit;
  exception when others then
    null;
  end save_error_msg_update_status;

  /**
   * Возвращает описание статуса архивирования таблицы в файл
   *
   * @param lp_arch_hist_status [not null] - Статус архивирования таблицы в файл
   *
   * @return [not null] Описание статуса
   */
  function get_arch_hist_status_desc(lp_arch_hist_status integer) return varchar2 is
    ll_status_desc util.sqlstring;
  begin
    assert.assert_not_null(
      value_      => lp_arch_hist_status,
      value_name_ => 'lp_arch_hist_status'
    );
    ll_status_desc :=
      case lp_arch_hist_status
        when 0 then 'архивация запланирована'
        when 1 then 'файл создается'
        when 2 then 'файл создан'
        when 3 then 'файл проверяется'
        when 4 then 'файл проверен'
        when 5 then 'данные во внешнюю временную таблицу копируются'
        when 6 then 'данные во внешнюю временную таблицу копированы'
        when 7 then 'внешняя временная таблица проверяется'
        when 8 then 'внешняя временная таблица проверена'
        when 9 then 'данные пользовательской таблицы удаляются'
        when 10 then 'данные пользовательской таблицы удалены'
        when 11 then 'данные из внешней временной таблицы копируются в пользовательскую'
        when 12 then 'данные из внешней временной таблицы копированы в пользовательскую'
        when 13 then 'пользовательская таблица проверяется'
        when 14 then 'пользовательская таблица проверена'
        when 15 then 'внешняя временная таблица удаляется'
        when 16 then 'внешняя временная таблица удалена'
        when 17 then 'архивирование успешно завершено'
        else null
      end;
    assert.assert_not_null(
      value_      => ll_status_desc,
      value_name_ => 'get_arch_hist_status_desc вернула null'
    );
    return ll_status_desc;
  end get_arch_hist_status_desc;

  /**
   * Возвращает статус архивирования таблицы в файл
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   *
   * @return [not null] Статус архивирования
   */
  function get_arch_hist_status(lp_arch_file_table_desc t_arch_file_table_desc) return integer is
    ll_status integer;
  begin
    assert.assert_not_null(
      value_      => lp_arch_file_table_desc.arch_file_name,
      value_name_ => 'lp_arch_file_table_desc.arch_file_name'
    );
    begin
      select dah.arch_hist_status
      into ll_status
      from estloc.org_data_arch_hist dah
      where dah.arch_file_name = lp_arch_file_table_desc.arch_file_name;
    exception
      when no_data_found then
        lg_message := prepend_message(
          lp_message => 'Таблица истории архивирования данных пользовательских таблиц не содержит запись для [' ||
            lp_arch_file_table_desc.arch_file_name || ']'
        );
        raise;
      when others then
        raise;
    end;
    return ll_status;
  exception when others then
    lg_message := prepend_message(
      lp_message => 'get_arch_hist_status(lp_arch_file_table_desc.arch_file_name = ' || lp_arch_file_table_desc.arch_file_name || ')'
    );
    raise;
  end get_arch_hist_status;

  /**
   * Возвращает размер пользовательской таблицы из таблицы dba_segments на момент создания запроса на архивацию
   *
   * @param lp_table_name [not null] - Наименование пользовательской таблицы
   *
   * @return [not null] Размер пользовательской таблицы
   */
  function get_org_table_size_mb(lp_table_name varchar2) return number is
    ll_org_table_size_mb number;
  begin
    assert.assert_not_null(
      value_      => lp_table_name,
      value_name_ => 'lp_table_name'
    );
    select sg.bytes/1024/1024
    into ll_org_table_size_mb
    from dba_segments sg
    where upper(sg.owner || '.' || sg.segment_name) = upper(lp_table_name);
    assert.assert_not_null(
      value_      => ll_org_table_size_mb,
      value_name_ => 'get_org_table_size_mb вернула null'
    );
    return ll_org_table_size_mb;
  exception when others then
    lg_message := prepend_message(
      lp_message => 'get_org_table_size_mb(lp_table_name = ' || lp_table_name || ')'
    );
    raise;
  end get_org_table_size_mb;

  /**
   * Возвращает объем дисковой памяти (в МБ), освобожденный в процессе архивации
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   *
   * @return [not null] Объем дисковой памяти (в МБ)
   */
  function get_freed_space(lp_arch_file_table_desc t_arch_file_table_desc) return number is
    ll_freed_space number := 0;
  begin
    assert.assert_not_null(
      value_ => lp_arch_file_table_desc.arch_file_name,
      value_name_ => 'lp_arch_file_table_desc.arch_file_name'
    );
    select dah.org_table_size_mb - dah.org_table_size_after_mb
    into ll_freed_space
    from estloc.org_data_arch_hist dah
    where dah.arch_file_name = lp_arch_file_table_desc.arch_file_name;
    assert.assert_not_null(
      value_ => ll_freed_space,
      value_name_ => 'get_freed_space вернула null'
    );
    return ll_freed_space;
  end get_freed_space;

  /**
   * Возвращает объем свободной дисковой памяти (в МБ) для объектов ESTLOC
   *
   * @return [not null] Объем дисковой памяти (в МБ)
   */
  function get_estloc_free_space return number is
    ll_free_space number := 0;
  begin
    select round(sum(fs.bytes)/1048576) freespace
    into ll_free_space
    from dba_free_space fs
    where fs.tablespace_name = SCHEMA_PREFIX
    group by fs.tablespace_name;
    return ll_free_space;
  end get_estloc_free_space;

  /**
   * Возвращает описание столбцов пользовательской таблицы
   *
   * @param lp_table_name   [not null] - Наименование пользовательской таблицы
   * @param lp_column_types [nullable] - Тип данных столбца:
   *                                       0 - тип данных не учитывается
   *                                       1 - считать все типы данных как varchar2(4000) - для создания внешнего
   *                                             файла-таблицы в текстовом представлении, например, csv
   *                                       2 - указываются текущие типы данных
   *
   * @return [not null] Описание столбцов пользовательской таблицы
   */
  function get_select_columns_from_usr_t(lp_table_name varchar2, lp_column_types integer default 0) return clob is
    ll_columns clob;
    ll_appendix varchar(100);
    ll_column_qty integer;
    ll_column_counter integer := 0;
    TABLE_NAME_WO_PREFIX util.identifier := cutoff_schema_prefix(lp_table_name => lp_table_name);
  begin
    assert.assert_not_null(
      value_      => TABLE_NAME_WO_PREFIX,
      value_name_ => 'lp_table_name'
    );
    assert.assert_in_set(
      value_      => lp_column_types,
      set_        => util.numarray(0, 1, 2),
      value_name_ => lp_column_types
    );
    select count(*)
    into ll_column_qty
    from all_tab_cols t
    where
      t.table_name = TABLE_NAME_WO_PREFIX
      and t.owner = SCHEMA_PREFIX
      --and coalesce(t.data_type_owner, 'SYS') = 'SYS'
      and t.virtual_column = 'NO'
      and t.hidden_column = 'NO';

    for i in (
      select t.column_name, t.data_type, t.data_length, t.data_precision, t.data_scale
      from all_tab_cols t
      where
        ll_column_qty > 0
        and t.table_name = TABLE_NAME_WO_PREFIX
        and t.owner = SCHEMA_PREFIX
        --and coalesce(t.data_type_owner, 'SYS') = 'SYS'
        and t.virtual_column = 'NO'
        and t.hidden_column = 'NO'
      order by t.column_id
    ) loop
      ll_column_counter := ll_column_counter + 1;
      ll_appendix := null;
      if (lp_column_types = 1) then
        ll_appendix := i.column_name || '(varchar2(4000))';
      elsif (lp_column_types = 2) then
        ll_appendix := i.column_name || ' ' || i.data_type;
        if (i.data_type like 'VARCHAR%') then
          ll_appendix := ll_appendix || '(' || i.data_length || ')';
        elsif (i.data_type = 'NUMBER' and i.data_precision is not null and i.data_scale > 0) then
          ll_appendix := ll_appendix || '(' || i.data_precision || ',' || i.data_scale || ')';
        elsif (i.data_type = 'NUMBER' and i.data_precision is null and i.data_scale > 0) then
          ll_appendix := ll_appendix || '(*,' || i.data_scale || ')';
        elsif (i.data_type = 'NUMBER' and i.data_precision is not null and i.data_scale = 0) then
          ll_appendix := ll_appendix || '(' || i.data_precision || ')';
        end if;
      else
        ll_appendix := SOURCE_TABLE_ALIAS_PLACEHOLDER || '.' || i.column_name;
      end if;
      ll_columns := ll_columns || ll_appendix || estloc.util.ternop(ll_column_qty = ll_column_counter, '', ', ');
    end loop;
    assert.assert_not_null(
      value_      => ll_columns,
      value_name_ => 'lp_table_name',
      comment_ => 'get_select_columns_from_usr_t вернула null'
    );
    return ll_columns;
  exception when others then
    lg_message := prepend_message(
      lp_message =>
        'get_select_columns_from_usr_t(' || util.SMBL_LINEEND ||
        '  lp_table_name = ' || lp_table_name || util.SMBL_LINEEND ||
        '  lp_column_types = ' || lp_column_types || util.SMBL_LINEEND ||
        ')'
    );
    raise;
  end get_select_columns_from_usr_t;

  /**
   * Возвращает наименование ключевого столбца
   *
   * @param lp_table_name [not null] - Наименование пользовательской таблицы
   *
   * @return [nullable] Наименование ключевого столбца (некоторые таблицы, например ESTLOC.ORG_ACCOUNT_SALDO не имеют ни)
   *                      ни первичных ключей, ни уникальных индексов, или ключ может быть составной, например таблица
   *                      ESTLOC.ORG_SMS_ACTION
   */
  function get_primary_key_column(lp_table_name varchar2) return util.identifier is
    TABLE_NAME_WO_PREFIX constant util.identifier := cutoff_schema_prefix(lp_table_name => lp_table_name);
    ll_primary_key_column util.identifier;
  begin
    assert.assert_not_null(
      value_      => lp_table_name,
      value_name_ => 'lp_table_name'
    );
    select cc.column_name
    into ll_primary_key_column
    from dba_cons_columns cc
      join dba_constraints c on (
        c.constraint_name = cc.constraint_name
        and c.owner = cc.owner
        and c.table_name = cc.table_name
      )
    where
      c.constraint_type = 'P'
      and c.status = 'ENABLED'
      and c.owner = SCHEMA_PREFIX
      and c.table_name = TABLE_NAME_WO_PREFIX;
    return ll_primary_key_column;
  exception
    when no_data_found then
      return null;
    when too_many_rows then
      return null;
    when others then
    lg_message := prepend_message(
      lp_message => 'get_primary_key_column(lp_table_name = ' || lp_table_name || ')'
    );
    raise;
  end get_primary_key_column;

  /**
   * Возвращает список периодических заданий. Список выражений для изменения состояний работы. Задания, которые были
   *   активны далжны отключаться на период процесса  архивации, при этом после архивации не должны быть включены
   *   задания, которые были неактивны до начала архивации
   *
   * @return [not null] Список выражений для изменения состояний работы периодических заданий
   */
  function get_job_list return estloc.tbl_clob is
    ll_job_list estloc.tbl_clob := estloc.tbl_clob();
  begin
    select j.owner || '.' || j.job_name
    bulk collect into ll_job_list
    from dba_scheduler_jobs j
    where j.owner = SCHEMA_PREFIX and j.enabled = 'TRUE'
    order by j.run_count;
    return ll_job_list;
  exception when others then
    lg_message := prepend_message(lp_message => 'get_job_list()');
    raise;
  end get_job_list;

  /**
   * Изменяет состояния периодических заданий
   *
   * @param lp_action [not null] Действие, "disable" или "enable"
   */
  procedure alter_jobs(lp_action varchar2) is
    ll_idx integer;
    ll_job_list estloc.tbl_clob := estloc.tbl_clob();
  begin
    assert.assert_true(
      value_   => lower(lp_action) in ('disable', 'enable'),
      comment_ => 'lp_action должен иметь значение "disable" или "enable"'
    );
    begin
      select job_list
      into ll_job_list
      from (
        select dah.job_list
        from estloc.org_data_arch_hist dah
        where dah.job_list is not empty
        order by dah.create_dt desc
      )
      where rownum = 1;
    exception when no_data_found then
      write_log(lp_message => 'Нет периодических заданий для обработки');
    end;

    ll_idx := ll_job_list.first;
    while ll_idx is not null loop
      if (lower(lp_action) = 'disable') then
        dbms_scheduler.disable(name => ll_job_list(ll_idx), force => true);
      else
        dbms_scheduler.enable(name => ll_job_list(ll_idx));
      end if;
      ll_idx := ll_job_list.next(ll_idx);
    end loop;
  exception when others then
    lg_message := prepend_message(lp_message => 'alter_jobs(lp_action = ' || lp_action || ')');
  end alter_jobs;

  /** Останавливает работу периодических заданий */
  procedure disable_jobs is
  begin
    alter_jobs(lp_action => 'disable');
  end disable_jobs;

  /** Восстанавливает работу периодических заданий */
  procedure enable_jobs is
  begin
    alter_jobs(lp_action => 'enable');
  end enable_jobs;

  /**
   *  Останавливает репликацию вверх.
   *  Активация производится вручную вне этого скрипта после тестирования диспетчерами и водителями
   */
  procedure disable_replication_up is
  begin
    update estloc.upload_tables t
    set t.block_dt = estloc.kernel.get_sysdate()
    where t.block_dt is null;
    commit;
  end disable_replication_up;

  /**
   * Возвращает список ограничений пользовательской таблицы. Список выражений для изменения состояний ограничений
   *
   * @param lp_table_name [not null] - Наименование пользовательской таблицы
   *
   * @return [not null] Список выражений для изменения состояний ограничений
   */
  function get_constraint_list(lp_table_name varchar2) return estloc.tbl_clob is
    TABLE_NAME_WO_PREFIX constant util.identifier := cutoff_schema_prefix(lp_table_name => lp_table_name);
    STATEMENT_PATTERN constant util.string :=
      'alter table ' || lp_table_name || ' ' || ACTION_PLACEHOLDER || ' constraint ' || CONSTRAINT_NAME_PLACEHOLDER;
    ll_constraint_list estloc.tbl_clob := estloc.tbl_clob();
  begin
    assert.assert_not_null(
      value_      => lp_table_name,
      value_name_ => 'lp_table_name'
    );
    select replace(STATEMENT_PATTERN, CONSTRAINT_NAME_PLACEHOLDER, c.constraint_name)
    bulk collect into ll_constraint_list
    from dba_constraints c
    where
      c.constraint_type <> 'P'
      and c.status = 'ENABLED'
      and c.owner = SCHEMA_PREFIX
      and c.table_name = TABLE_NAME_WO_PREFIX
    order by
      c.constraint_type;

    return ll_constraint_list;
  exception when others then
    lg_message := prepend_message(
      lp_message => 'get_constraint_list(lp_table_name = ' || lp_table_name || ')'
    );
    raise;
  end get_constraint_list;

  /**
   * Возвращает список ссылочных ограничений других таблиц, на первичный и уникальные ключи пользовательской таблицы.
   *   Список выражений для изменения состояний ограничений
   *
   * @param lp_table_name [not null] - Наименование пользовательской таблицы
   *
   * @return [not null] Список выражений для изменения состояний ограничений
   */
  function get_r_constraint_list(lp_table_name varchar2) return estloc.tbl_clob is
    TABLE_NAME_WO_PREFIX constant util.identifier := cutoff_schema_prefix(lp_table_name => lp_table_name);
    TABLE_NAME_PLACEHOLDER constant util.string := '${table_name}';
    STATEMENT_PATTERN constant util.string :=
      'alter table ' || SCHEMA_PREFIX || '.' || TABLE_NAME_PLACEHOLDER ||
        ' ' || ACTION_PLACEHOLDER || ' constraint ' || CONSTRAINT_NAME_PLACEHOLDER;
    ll_r_constraint_list estloc.tbl_clob := estloc.tbl_clob();
  begin
    assert.assert_not_null(
      value_      => lp_table_name,
      value_name_ => 'lp_table_name'
    );
    select
      replace(
        replace(STATEMENT_PATTERN, TABLE_NAME_PLACEHOLDER, rc.table_name),
        CONSTRAINT_NAME_PLACEHOLDER,
        rc.constraint_name
      )
    bulk collect into ll_r_constraint_list
    from dba_constraints rc
      join dba_constraints c on (rc.r_owner = c.owner and rc.r_constraint_name = c.constraint_name)
    where
      rc.constraint_type = 'R'
      and rc.status = 'ENABLED'
      and c.owner = SCHEMA_PREFIX
      and c.table_name = TABLE_NAME_WO_PREFIX
      and c.constraint_type in ('P', 'U')
    order by
      rc.table_name,
      c.constraint_type;

    return ll_r_constraint_list;
  exception when others then
    lg_message := prepend_message(
      lp_message => 'get_r_constraint_list(lp_table_name = ' || lp_table_name || ')'
    );
    raise;
  end get_r_constraint_list;

  /**
   * Возвращает список индексов пользовательской таблицы. Список выражений для изменения состояний индексов
   *
   * @param lp_table_name [not null] - Наименование пользовательской таблицы
   *
   * @return [not null] Список выражений для изменения состояний индексов
   */
  function get_indices(lp_table_name varchar2) return estloc.tbl_clob is
    TABLE_NAME_WO_PREFIX constant util.identifier := cutoff_schema_prefix(lp_table_name => lp_table_name);
    INDEX_NAME_PLACEHOLDER constant util.string := '${index_name}';
    STATEMENT_PATTERN constant util.string :=
      'alter index ' || SCHEMA_PREFIX || '.' || INDEX_NAME_PLACEHOLDER || ' ' || ACTION_PLACEHOLDER;
    ll_indices_list estloc.tbl_clob := estloc.tbl_clob();
  begin
    assert.assert_not_null(
      value_      => lp_table_name,
      value_name_ => 'lp_table_name'
    );
    select replace(STATEMENT_PATTERN, INDEX_NAME_PLACEHOLDER, idx.index_name)
    bulk collect into ll_indices_list
    from dba_indexes idx
    where idx.owner = SCHEMA_PREFIX
      and idx.table_name = TABLE_NAME_WO_PREFIX
      and idx.index_type in ('NORMAL', 'FUNCTION-BASED NORMAL')
      and idx.status = 'VALID'
      and not exists (
        select null
        from dba_constraints dc
        where dc.owner = SCHEMA_PREFIX
          and dc.table_name = TABLE_NAME_WO_PREFIX
          and dc.index_name = idx.index_name
      );

    return ll_indices_list;
  exception when others then
    lg_message := prepend_message(
      lp_message => 'get_indices(lp_table_name = ' || lp_table_name || ')'
    );
    raise;
  end get_indices;

  /**
   * Возвращает список таблиц с их описанием
   *
   * @return [not null] Список таблиц с их описанием
   */
  function get_table_list return t_table_list is
    ll_table_list t_table_list := t_table_list();
  begin
    ll_table_list.extend(14);
    ll_table_list(1).table_name := SCHEMA_PREFIX || '.ORG_ORDER';
    ll_table_list(1).process_priority := 99;
    ll_table_list(1).table_time_filter_column := 'ORDER_DT';
    ll_table_list(1).from_where_clause :=
      ' from estloc.org_order ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.order_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      '   and ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.id_order_status in (12, 99, 100)' ||
      ' )';
    ll_table_list(2).table_name := SCHEMA_PREFIX || '.ORG_PAY';
    ll_table_list(2).process_priority := 1;
    ll_table_list(2).table_time_filter_column := 'PAY_DT';
    ll_table_list(2).from_where_clause :=
      ' from estloc.org_pay ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
          JOIN_PLACEHOLDER || ' estloc.org_order ord on (ord.id_order = ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.id_order) ' ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.pay_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      '   and (ord.id_order_status in (12, 99, 100) or ord.id_order_status is null)' ||
      ' )';
    ll_table_list(3).table_name := SCHEMA_PREFIX || '.ORG_ORDER_ACTION';
    ll_table_list(3).process_priority := 0;
    ll_table_list(3).table_time_filter_column := 'ORDER_ACTION_DT';
    ll_table_list(3).from_where_clause :=
      ' from estloc.org_order_action ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
          JOIN_PLACEHOLDER || ' estloc.org_order ord on (ord.id_order = ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.id_order)' ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.order_action_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      '   and (ord.id_order_status in (12, 99, 100) or ord.id_order_status is null)' ||
      ' )';
    ll_table_list(4).table_name := SCHEMA_PREFIX || '.ORG_SMS';
    ll_table_list(4).process_priority := 1;
    ll_table_list(4).table_time_filter_column := 'SEND_DT';
    ll_table_list(4).from_where_clause :=
      ' from estloc.org_sms ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.send_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      ' )';
    ll_table_list(5).table_name := SCHEMA_PREFIX || '.ORG_ACCOUNT_SALDO';
    ll_table_list(5).process_priority := 0;
    ll_table_list(5).table_time_filter_column := 'PAY_DT';
    ll_table_list(5).from_where_clause :=
      ' from estloc.org_account_saldo ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
          JOIN_PLACEHOLDER || ' estloc.org_pay pay on (pay.id_pay = ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.id_pay)' ||
          JOIN_PLACEHOLDER || ' estloc.org_order ord on (ord.id_order = pay.id_order)' ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.pay_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      '   and (extract(year from pay.pay_dt) ' || COMPARE_JOIN_PLACEHOLDER || YEAR_PLACEHOLDER || ' or pay.pay_dt is null) ' ||
      '   and (ord.id_order_status in (12, 99, 100) or ord.id_order_status is null)' ||
      ' )';
    ll_table_list(6).table_name := SCHEMA_PREFIX || '.ORG_USER_SHIFT';
    ll_table_list(6).process_priority := 0;
    ll_table_list(6).table_time_filter_column := 'END_DT';
    ll_table_list(6).from_where_clause :=
      ' from estloc.org_user_shift ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.end_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      ' )';
    ll_table_list(7).table_name := SCHEMA_PREFIX || '.ORG_CALL';
    ll_table_list(7).process_priority := 0;
    ll_table_list(7).table_time_filter_column := 'CALL_DT';
    ll_table_list(7).from_where_clause :=
      ' from estloc.org_call ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.call_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      ' )';
    ll_table_list(8).table_name := SCHEMA_PREFIX || '.ORG_SMS_ACTION';
    ll_table_list(8).process_priority := 0;
    ll_table_list(8).table_time_filter_column := 'ACTION_DT';
    ll_table_list(8).from_where_clause :=
      ' from estloc.org_sms_action ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
          JOIN_PLACEHOLDER || ' estloc.org_sms sms on (sms.id_sms = ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.id_sms)' ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '    extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.action_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      '    and (extract(year from sms.send_dt) ' || COMPARE_JOIN_PLACEHOLDER || YEAR_PLACEHOLDER || ' or sms.send_dt is null) ' ||
      '  )';
    ll_table_list(9).table_name := SCHEMA_PREFIX || '.ORG_DRIVER_SHIFT';
    ll_table_list(9).process_priority := 3;
    ll_table_list(9).table_time_filter_column := 'END_DT';
    ll_table_list(9).from_where_clause :=
      ' from estloc.org_driver_shift ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
          JOIN_PLACEHOLDER || ' estloc.org_order ord on (ord.id_order = ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.id_last_order)' ||
          JOIN_PLACEHOLDER || ' estloc.org_pda_session pdases on (pdases.id_profile_session = ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.id_profile_session)' ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.end_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      '   and (extract(year from pdases.end_dt) ' || COMPARE_JOIN_PLACEHOLDER || YEAR_PLACEHOLDER || ' or pdases.end_dt is null) ' ||
      '   and (ord.id_order_status in (12, 99, 100) or ord.id_order_status is null)' ||
      ' )';
    ll_table_list(10).table_name := SCHEMA_PREFIX || '.ORG_PDA_SESSION';
    ll_table_list(10).process_priority := 2;
    ll_table_list(10).table_time_filter_column := 'END_DT';
    ll_table_list(10).from_where_clause :=
      ' from estloc.org_pda_session ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
          JOIN_PLACEHOLDER || ' estloc.org_driver_shift drvsh on (drvsh.id_profile_session = ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.id_profile_session)' ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.end_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      '   and (extract(year from drvsh.end_dt) ' || COMPARE_JOIN_PLACEHOLDER || YEAR_PLACEHOLDER || ' or drvsh.end_dt is null) ' ||
      ' )';
    ll_table_list(11).table_name := SCHEMA_PREFIX || '.ORG_DRIVER_SHIFT_STATUS';
    ll_table_list(11).process_priority := 0;
    ll_table_list(11).table_time_filter_column := 'END_DT';
    ll_table_list(11).from_where_clause :=
      ' from estloc.org_driver_shift_status ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
          JOIN_PLACEHOLDER || ' estloc.org_driver_shift drvsh on (drvsh.id_driver_shift = ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.id_driver_shift)' ||
          JOIN_PLACEHOLDER || ' estloc.org_order ord on (ord.id_order = drvsh.id_last_order)' ||
          JOIN_PLACEHOLDER || ' estloc.org_pda_session pdases on (pdases.id_profile_session = drvsh.id_profile_session)' ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.end_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      '   and (extract(year from drvsh.end_dt) ' || COMPARE_JOIN_PLACEHOLDER || YEAR_PLACEHOLDER || ' or drvsh.end_dt is null) ' ||
      '   and (extract(year from pdases.end_dt) ' || COMPARE_JOIN_PLACEHOLDER || YEAR_PLACEHOLDER || ' or pdases.end_dt is null) ' ||
      '   and (ord.id_order_status in (12, 99, 100) or ord.id_order_status is null)' ||
      ' )';
    ll_table_list(12).table_name := SCHEMA_PREFIX || '.ORG_MESSAGE';
    ll_table_list(12).process_priority := 1;
    ll_table_list(12).table_time_filter_column := 'CREATE_DT';
    ll_table_list(12).from_where_clause :=
      ' from estloc.org_message ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
          JOIN_PLACEHOLDER || ' estloc.org_order ord on (ord.id_order = ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.id_order)' ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.create_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      '   and (ord.id_order_status in (12, 99, 100) or ord.id_order_status is null)' ||
      ' )';
    ll_table_list(13).table_name := SCHEMA_PREFIX || '.ORG_MESSAGE_ACTION';
    ll_table_list(13).process_priority := 0;
    ll_table_list(13).table_time_filter_column := 'ACTION_DT';
    ll_table_list(13).from_where_clause :=
      ' from estloc.org_message_action ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
          JOIN_PLACEHOLDER || ' estloc.org_message msg on (msg.id_message = ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.id_message)' ||
          JOIN_PLACEHOLDER || ' estloc.org_order ord on (ord.id_order = msg.id_order)' ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.action_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      '   and (extract(year from msg.create_dt) ' || COMPARE_JOIN_PLACEHOLDER || YEAR_PLACEHOLDER || ' or msg.create_dt is null) ' ||
      '   and (ord.id_order_status in (12, 99, 100) or ord.id_order_status is null)' ||
      ' )';
    ll_table_list(14).table_name := SCHEMA_PREFIX || '.ORG_DRIVER_AREA';
    ll_table_list(14).process_priority := 0;
    ll_table_list(14).table_time_filter_column := 'END_DT';
    ll_table_list(14).from_where_clause :=
      ' from estloc.org_driver_area ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||
          JOIN_PLACEHOLDER || ' estloc.org_driver_shift drvsh on (drvsh.id_driver_shift = ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.id_driver_shift)' ||
          JOIN_PLACEHOLDER || ' estloc.org_order ord on (ord.id_order = drvsh.id_last_order)' ||
      ' where ' || NOT_PLACEHOLDER || ' (' ||
      '   extract(year from ' || SOURCE_TABLE_ALIAS_PLACEHOLDER ||'.end_dt) ' || COMPARE_MAIN_PLACEHOLDER || YEAR_PLACEHOLDER ||
      '   and (extract(year from drvsh.end_dt) ' || COMPARE_JOIN_PLACEHOLDER || YEAR_PLACEHOLDER || ' or drvsh.end_dt is null) ' ||
      '   and (ord.id_order_status in (12, 99, 100) or ord.id_order_status is null)' ||
      ' )';
    return ll_table_list;
  end get_table_list;

  /**
   * Возвращает список таблиц с их описанием с обновленной информацией о минимальном годе логического создания строки по
   *   ключевому столбцу в списке таблиц
   *
   * @param lp_table_list [not null] - Список таблиц с их описанием
   *
   * @return [not null] Список таблиц с их описанием с обновленной информацией.
   *                      Вернет "-1" (ESTLOC.const.NULL_NUMBER), если таблица пустая
   */
  function calc_tables_min_years(lp_table_list t_table_list) return t_table_list is
    ll_table_list t_table_list := lp_table_list;
    ll_min_year_from_hist integer;
    ll_min_year_from_table integer;
    ll_statement clob;
  begin
    assert.assert_true(
      value_      => lp_table_list is not empty,
      value_name_ => 'lp_table_list',
      comment_    => 'должна иметь хотя бы один элемент'
    );
    for i in ll_table_list.first .. ll_table_list.last loop
      assert.assert_true(
        value_      =>
          ll_table_list(i).table_name is not null
          and ll_table_list(i).table_time_filter_column is not null,
        comment_    => 'll_table_list(i).table_name и ll_table_list(i).table_time_filter_column не должны быть null'
      );
      select max(dah.arch_period_year) + 1
      into ll_min_year_from_hist
      from estloc.org_data_arch_hist dah
      where dah.org_table_name = ll_table_list(i).table_name;
      ll_statement :=
        'select extract(year from min(' || ll_table_list(i).table_time_filter_column || ')) from ' || ll_table_list(i).table_name;
      execute immediate ll_statement into ll_min_year_from_table;
      --ll_min_year_from_table запрос мог обнаружить строки, которые появились в таблице и соответствуют фильтру позже
      --  создания файла-архива и поэтому вызовут ошибку при повторном создании архива. Или в таблице есть строки,
      --  несоответствующие фильтру и которые должны остаться в таблице после архивации
      if (ll_min_year_from_table is not null) then
      ll_table_list(i).min_year :=
        greatest(ll_min_year_from_table, coalesce(ll_min_year_from_hist, ESTLOC.const.NULL_NUMBER));
      else
        ll_table_list(i).min_year := ESTLOC.const.NULL_NUMBER;
      end if;
    end loop;
    return ll_table_list;
  exception when others then
    lg_message := prepend_message(
      lp_message => 'calc_tables_min_years(lp_table_list.count = ' || lp_table_list.count || ')'
    );
    raise;
  end calc_tables_min_years;

  /**
   * Возвращает минимальный год логического создания строки всех таблиц списка
   *
   * @param lp_table_list [not null] - Список таблиц с их описанием
   *
   * @return [not null] Год, минимальный для всех таблиц
   */
  function get_all_tables_min_year(lp_table_list t_table_list) return integer is
    ll_min_year integer := MAX_YEAR;
    ll_idx integer;
  begin
    assert.assert_true(
      value_      => lp_table_list is not empty,
      value_name_ => 'lp_table_list',
      comment_    => 'должна иметь хотя бы один элемент'
    );
    ll_idx := lp_table_list.first;
    while ll_idx is not null loop
      ll_min_year := least(
        ll_min_year,
        util.ternop(
          lp_table_list(ll_idx).min_year = estloc.const.NULL_NUMBER,
          ll_min_year,
          lp_table_list(ll_idx).min_year
        )
      );
      ll_idx := lp_table_list.next(ll_idx);
    end loop;
    assert.assert_true(
      value_      => ll_min_year > 0,
      value_name_ => 'get_all_tables_min_year вернула null'
    );
    return ll_min_year;
  exception when others then
    lg_message := prepend_message(
      lp_message => 'get_all_tables_min_year(lp_table_list.count = ' || lp_table_list.count || ')' || util.SMBL_LINEEND ||
        'll_min_year = ' || ll_min_year || util.SMBL_LINEEND ||
        'lp_table_list(ll_idx).table_name = ' || lp_table_list(ll_idx).table_name
    );
    raise;
  end get_all_tables_min_year;

  /**
   * Возвращает максимально возможный год, данные за который могут быть архивированы
   *
   * @param lp_table_list [not null] - Список таблиц с их описанием
   *
   * @return [not null] Максимально возможный год, данные за который могут быть архивированы
   */
  function get_all_tbls_max_year_possible(lp_table_list t_table_list) return integer is
    ll_min_year integer := 0;
    ll_max_year integer := MAX_YEAR;
  begin
    assert.assert_true(
      value_      => lp_table_list is not empty,
      value_name_ => 'lp_table_list',
      comment_    => 'должна иметь хотя бы один элемент'
    );
    ll_min_year := get_all_tables_min_year(lp_table_list => lp_table_list);
    ll_max_year :=
      least(YEAR_EXCEPT_CUR_AND_YEAR_BEF, coalesce(ll_min_year + p_years_qty_archive_data, p_year_archive_data_by)) - 1;
    assert.assert_not_null(
      value_   => ll_max_year,
      comment_ => 'get_all_tbls_max_year_possible вернула null'
    );
    if (ll_max_year < coalesce(ll_min_year + p_years_qty_archive_data, p_year_archive_data_by)) then
      write_log(lp_message => 'Максимально возможный год, данные за который могут быть архивированы = ' || ll_max_year);
    end if;
    return ll_max_year;
  exception when others then
    lg_message := prepend_message(
      lp_message => 'get_all_tbls_max_year_possible(lp_table_list.count = ' || lp_table_list.count || ')' || util.SMBL_LINEEND ||
        'll_max_year = ' || ll_max_year
    );
    raise;
  end get_all_tbls_max_year_possible;

  /**
   * Возвращает количество строк пользовательской таблицы
   *
   * @param lp_table_name [not null] - Наименование пользовательской таблицы
   *
   * @return [not null] Количество строк
   */
  function get_table_row_count(lp_table_name varchar2) return integer is
    ll_row_count integer;
    ll_statement clob;
  begin
    assert.assert_not_null(
      value_      => lp_table_name,
      value_name_ => 'lp_table_name'
    );
    ll_statement := 'select count(*) from ' || lp_table_name;
    execute immediate ll_statement into ll_row_count;
    return ll_row_count;
  exception when others then
    lg_message := prepend_message(
      lp_message => 'get_table_row_count(lp_table_name = ' || lp_table_name || ')'
    );
    raise;
  end get_table_row_count;

  /**
   * Возвращает строку from where выражения с подставленными значениями
   *
   * @param lp_string [not null] - Строка from where с масками-заполнителями (placeholders)
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   *
   * @return [not null] Строка from where выражения с подставленными значениями
   */
  function fill_from_where_clause(lp_string clob, lp_arch_file_table_desc t_arch_file_table_desc) return clob is
    ll_string clob := lp_string;
  begin
    assert.assert_not_null(
      value_      => ll_string,
      value_name_ => 'll_string'
    );
    assert.assert_not_null(
      value_      => lp_arch_file_table_desc.arch_period_year,
      value_name_ => 'lp_arch_file_table_desc.arch_period_year'
    );
    ll_string := replace(ll_string, YEAR_PLACEHOLDER, lp_arch_file_table_desc.arch_period_year);
    ll_string := replace(ll_string, SOURCE_TABLE_ALIAS_PLACEHOLDER, SOURCE_TABLE_ALIAS);
    ll_string := replace(ll_string, JOIN_PLACEHOLDER, JOIN_LEFT);
    ll_string := replace(ll_string, COMPARE_MAIN_PLACEHOLDER, COMPARE_MAIN_EQUAL);
    ll_string := replace(ll_string, COMPARE_JOIN_PLACEHOLDER, COMPARE_JOIN_LESSOREQUAL);
    ll_string := replace(ll_string, NOT_PLACEHOLDER, estloc.const.NULL_CHAR);
    assert.assert_not_null(
      value_      => ll_string,
      value_name_ => 'fill_from_where_clause вернула null'
    );
    return ll_string;
  end fill_from_where_clause;

  /**
   * Возвращает количество строк пользовательской таблицы с фильтрацией по ключевому столбцу, которые будут архивированы
   *   за указанный год
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   *
   * @return [not null] Количество строк
   */
  function get_arch_table_row_count(lp_arch_file_table_desc t_arch_file_table_desc) return integer is
    ll_row_count integer;
    ll_statement clob;
  begin
    assert.assert_not_null(
      value_ => lp_arch_file_table_desc.select_from_usr_t_to_ext_t_dml,
      value_name_ => 'lp_arch_file_table_desc.select_from_usr_t_to_ext_t_dml'
    );
    ll_statement := 'select count(*) from (' || lp_arch_file_table_desc.select_from_usr_t_to_ext_t_dml || ')';
    execute immediate ll_statement into ll_row_count;
    return ll_row_count;
  exception when others then
    lg_message := prepend_message(
      lp_message =>
        'get_arch_table_row_count(' || util.SMBL_LINEEND ||
        '  lp_arch_file_table_desc.select_from_usr_t_to_ext_t_dml = ' || lp_arch_file_table_desc.select_from_usr_t_to_ext_t_dml || util.SMBL_LINEEND ||
        ')' || util.SMBL_LINEEND ||
        'll_statement=' || ll_statement
    );
    raise;
  end get_arch_table_row_count;

  /**
   * Возвращает sql выражение для выгрузки данных из пользовательской таблицы в файл-архив с фильтрацией по ключевому
   *   столбцу за указанный год
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   *
   * @return [not null] sql выражение
   */
  function get_select_from_usr_t_to_ext_t(lp_arch_file_table_desc t_arch_file_table_desc) return clob is
    ll_statement clob;
  begin
    assert.assert_true(
      value_ => lp_arch_file_table_desc.table_columns_desc is not null and lp_arch_file_table_desc.from_where_clause is not null,
      comment_ => 'lp_arch_file_table_desc.table_columns_desc и lp_arch_file_table_desc.from_where_clause и не могут быть null'
    );
    ll_statement := 'select distinct ' || lp_arch_file_table_desc.table_columns_desc || ' ' || lp_arch_file_table_desc.from_where_clause;
    ll_statement := fill_from_where_clause(lp_string => ll_statement, lp_arch_file_table_desc => lp_arch_file_table_desc);
    assert.assert_not_null(
      value_      => ll_statement,
      value_name_ => 'get_select_from_usr_t_to_ext_t вернула null'
    );
    return ll_statement;
  end get_select_from_usr_t_to_ext_t;

  /**
   * Возвращает sql выражение для выгрузки данных из пользовательской таблицы в временную с фильтрацией по ключевому
   *   столбцу за указанный год
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   *
   * @return [not null] sql выражение
   */
  function get_select_from_usr_t_to_tmp_t(lp_arch_file_table_desc t_arch_file_table_desc) return clob is
    ll_statement clob;
  begin
    assert.assert_true(
      value_ => lp_arch_file_table_desc.table_columns_desc is not null and lp_arch_file_table_desc.arch_period_year is not null,
      comment_ => 'lp_arch_file_table_desc.table_columns_desc и lp_arch_file_table_desc.arch_period_year не могут быть null'
    );
    ll_statement :=
      'select ' || util.SMBL_LINEEND ||
        replace(lp_arch_file_table_desc.table_columns_desc, SOURCE_TABLE_ALIAS_PLACEHOLDER, SOURCE_TABLE_ALIAS_FOR_EXT_TBL) || util.SMBL_LINEEND ||
      'from ' || lp_arch_file_table_desc.org_table_name || SOURCE_TABLE_ALIAS_FOR_EXT_TBL;
    if (lp_arch_file_table_desc.table_primary_key_column is null) then
      ll_statement := ll_statement || util.SMBL_LINEEND ||
        'minus ' || util.SMBL_LINEEND ||
        'select ' || util.SMBL_LINEEND ||
        replace(lp_arch_file_table_desc.table_columns_desc, SOURCE_TABLE_ALIAS_PLACEHOLDER, SOURCE_TABLE_ALIAS) || util.SMBL_LINEEND ||
        'from ' || lp_arch_file_table_desc.arch_file_table_name || SOURCE_TABLE_ALIAS;
    else
      ll_statement := ll_statement || util.SMBL_LINEEND ||
        'where not exists (' || util.SMBL_LINEEND ||
        '  select null' || util.SMBL_LINEEND ||
        '  from ' || lp_arch_file_table_desc.arch_file_table_name || util.SMBL_LINEEND || ' ' || SOURCE_TABLE_ALIAS || util.SMBL_LINEEND ||
        '  where ' || util.SMBL_LINEEND ||
             SOURCE_TABLE_ALIAS || '.' || lp_arch_file_table_desc.table_primary_key_column ||
             ' = ' ||
             SOURCE_TABLE_ALIAS_FOR_EXT_TBL || '.' || lp_arch_file_table_desc.table_primary_key_column || util.SMBL_LINEEND ||
        ')';
    end if;
    assert.assert_not_null(
      value_      => ll_statement,
      value_name_ => 'get_select_from_usr_t_to_tmp_t вернула null'
    );
    return ll_statement;
  end get_select_from_usr_t_to_tmp_t;

  /**
   * Возвращает sql ddl выражение создания пользовательской таблицы
   *
   * @param lp_table_name [not null] - Наименование пользовательской таблицы
   *
   * @return [not null] sql ddl выражение
   */
  function get_table_desc_ddl(lp_table_name varchar2) return clob is
    ll_ddl clob;
  begin
    assert.assert_not_null(
      value_      => lp_table_name,
      value_name_ => 'lp_table_name'
    );
    ll_ddl :=
      dbms_metadata.get_ddl(
      object_type => 'TABLE',
      name        => cutoff_schema_prefix(lp_table_name => lp_table_name),
      schema      => SCHEMA_PREFIX
    );
    assert.assert_not_null(
      value_      => ll_ddl,
      value_name_ => 'get_table_desc_ddl вернула null'
    );
    return ll_ddl;
  end get_table_desc_ddl;

  /**
   * Возвращает sql ddl выражение создания нешней таблицы (файла)
   *
   * @return [not null] sql ddl выражение
   */
  function get_external_tbl_ddl return clob is
    ll_ddl clob;
  begin
    ll_ddl :=
      'create table ' || EXT_TBL_NAME_PLACEHOLDER ||
      '  organization external ' ||
      '  (type oracle_datapump default directory ' || ARCH_DIRECTORY ||
      '    location(''' || EXT_TBL_LOCATION_PLACEHOLDER || FILE_EXTENTION || ''')) ' ||
      '  as ' || EXT_TBL_AS_SELECT_PLACEHOLDER;
    assert.assert_not_null(
      value_      => ll_ddl,
      value_name_ => 'get_external_tbl_ddl вернула null'
    );
    return ll_ddl;
  exception when others then
    lg_message := prepend_message(
      lp_message => 'get_external_tbl_ddl()' || util.SMBL_LINEEND || 'll_ddl = ' || util.SMBL_LINEEND || ll_ddl
    );
    raise;
  end get_external_tbl_ddl;

  /**
   * Обновляет статус архивирования таблицы в файл
   *
   * @param lp_arch_file_name [not null] - Наименование файла-архива
   * @param lp_arch_hist_status     [not null] - Новый статус
   */
  procedure update_data_arch_hist_status(
    lp_arch_file_name varchar2,
    lp_arch_hist_status integer
  ) is
  begin
    assert.assert_not_null(
      value_      => lp_arch_file_name,
      value_name_ => 'lp_arch_file_name'
    );
    assert.assert_not_null(
      value_      => lp_arch_hist_status,
      value_name_ => 'lp_arch_hist_status'
    );
    update estloc.org_data_arch_hist dah
    set
      dah.arch_hist_status = lp_arch_hist_status,
      dah.session_uid = decode(lp_arch_hist_status, ARCH_ST_SUCCESS, null, session_uid),
      dah.arch_dt_copy_in_ext_tbl_start =
        decode(lp_arch_hist_status, ARCH_ST_FILE_CREATING, estloc.kernel.get_sysdate(), dah.arch_dt_copy_in_ext_tbl_start),
      dah.arch_dt_copy_in_ext_tbl_end =
        decode(lp_arch_hist_status, ARCH_ST_FILE_CREATED, estloc.kernel.get_sysdate(), dah.arch_dt_copy_in_ext_tbl_end),
      dah.arch_dt_copy_in_temp_tbl_start =
        decode(lp_arch_hist_status, ARCH_ST_EXT_TMP_COPYING, estloc.kernel.get_sysdate(), dah.arch_dt_copy_in_temp_tbl_start),
      dah.arch_dt_copy_from_tmp_tbl_end =
        decode(lp_arch_hist_status, ARCH_ST_TBL_COPIED, estloc.kernel.get_sysdate(), dah.arch_dt_copy_from_tmp_tbl_end),
      dah.arch_end_dt =
        decode(lp_arch_hist_status, ARCH_ST_SUCCESS, estloc.kernel.get_sysdate(), dah.arch_end_dt)
    where dah.arch_file_name = lp_arch_file_name;
    commit;
    write_log(lp_message =>
      'Таблица: [' || lp_arch_file_name || ']' ||
        ', новое состояние: [' ||
          lp_arch_hist_status || '-"' || get_arch_hist_status_desc(lp_arch_hist_status => lp_arch_hist_status) || '"]'
    );
  end update_data_arch_hist_status;

  /**
   * Возвращает наименование внешней временной таблицы для неархивируемых данных
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   *
   * @return [not null] Наименование внешней временной таблицы
   */
  function get_ext_tmp_table_name(lp_arch_file_table_desc t_arch_file_table_desc) return varchar2 is
    ll_ext_tmp_table_name util.sqlstring;
  begin
    assert.assert_true(
      value_ =>
        lp_arch_file_table_desc.arch_file_name is not null
        and lp_arch_file_table_desc.arch_period_year is not null,
      comment_ => 'lp_arch_file_table_desc.arch_file_name и lp_arch_file_table_desc.arch_period_year не может быть null'
    );
    ll_ext_tmp_table_name :=
      SCHEMA_PREFIX || '.' ||
      substr(cutoff_schema_prefix(lp_table_name => lp_arch_file_table_desc.org_table_name), 1, 26) ||
      substr(lp_arch_file_table_desc.arch_period_year, 3, 2) ||
      EXT_TMP_PREFIX;
    assert.assert_not_null(
      value_      => ll_ext_tmp_table_name,
      value_name_ => 'get_ext_tmp_table_name вернула null'
    );
    return ll_ext_tmp_table_name;
  end get_ext_tmp_table_name;

  /**
   * Удаляет таблицу
   *
   * @param lp_table_name [not null] - Наименование таблицы
   */
  procedure drop_table(lp_table_name varchar2) is
  begin
    assert.assert_not_null(
      value_      => lp_table_name,
      value_name_ => 'lp_table_name'
    );
    execute immediate 'drop table ' || lp_table_name;
    write_log(lp_message => 'Удалена таблица [' || lp_table_name || ']');
  exception when others then
    if (sqlcode = -00942) then
      write_log(lp_message => 'Не удалось удалить таблицу (не существует) [' || lp_table_name || ']');
    else
      write_log(lp_message => 'Не удалось удалить таблицу (другая ошибка) [' || lp_table_name || ']');
      raise;
    end if;
  end drop_table;

  /**
   * Удаляет внешнюю таблицу и файл в файловой системе
   *
   * @param lp_table_name [not null] - Наименование таблицы
   * @param lp_file_name  [not null] - Наименование файла (без расширения)
   */
  procedure drop_ext_table(lp_table_name varchar2, lp_file_name varchar2) is
    FILE_LOCATION constant util.sqlstring := lp_file_name || FILE_EXTENTION;
    ll_fexists boolean;
    ll_file_length number;
    ll_block_size binary_integer;
  begin
    assert.assert_not_null(
      value_      => lp_table_name,
      value_name_ => 'lp_table_name'
    );
    assert.assert_not_null(
      value_      => lp_file_name,
      value_name_ => 'lp_file_name'
    );
    drop_table(lp_table_name => lp_table_name);
    utl_file.fgetattr(
      location    => upper(ARCH_DIRECTORY),
      filename    => FILE_LOCATION,
      fexists     => ll_fexists,
      file_length => ll_file_length,
      block_size  => ll_block_size
    );
    if ll_fexists then
      utl_file.fremove(upper(ARCH_DIRECTORY), FILE_LOCATION);
      write_log(lp_message => 'Удален файл [' || FULL_ARCH_DIRECTORY || '/' || FILE_LOCATION || ']');
    else
      write_log(lp_message => 'Не удалось найти файл [' || FULL_ARCH_DIRECTORY || '/' || FILE_LOCATION || ']');
    end if;
  end drop_ext_table;

  /**
   * Создает файл-архив (внешюю таблицу)
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure create_arch_file(lp_arch_file_table_desc t_arch_file_table_desc) is
    ll_statement clob;
    ll_arch_hist_status integer;
  begin
    assert.assert_not_null(
      value_      => lp_arch_file_table_desc.arch_file_name,
      value_name_ => 'lp_arch_file_table_desc.arch_file_name'
    );
    ll_arch_hist_status := get_arch_hist_status(lp_arch_file_table_desc => lp_arch_file_table_desc);
    if (ll_arch_hist_status in (ARCH_ST_FILE_CREATING, ARCH_ST_FILE_CREATING - 1)) then
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_FILE_CREATING
      );
      if (ll_arch_hist_status = ARCH_ST_FILE_CREATING) then
        drop_ext_table(
          lp_table_name => lp_arch_file_table_desc.arch_file_table_name,
          lp_file_name => lp_arch_file_table_desc.arch_file_name
        );
      end if;
      ll_statement := lp_arch_file_table_desc.external_tbl_ddl;
      ll_statement := replace(ll_statement, EXT_TBL_AS_SELECT_PLACEHOLDER, lp_arch_file_table_desc.select_from_usr_t_to_ext_t_dml);
      ll_statement := replace(ll_statement, EXT_TBL_NAME_PLACEHOLDER, lp_arch_file_table_desc.arch_file_table_name);
      ll_statement := replace(ll_statement, EXT_TBL_LOCATION_PLACEHOLDER, lp_arch_file_table_desc.arch_file_name);
      ll_statement := replace(ll_statement, NOT_PLACEHOLDER, estloc.const.NULL_CHAR);
      execute immediate ll_statement;
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_FILE_CREATED
      );
    end if;
  exception when others then
    lg_message := prepend_message(
      lp_message =>
        'create_arch_file(' || util.SMBL_LINEEND ||
        '  lp_arch_file_table_desc.arch_file_name = ' || lp_arch_file_table_desc.arch_file_name || util.SMBL_LINEEND ||
        '  ll_statement = ' || ll_statement || util.SMBL_LINEEND ||
        ')'
    );
    raise;
  end create_arch_file;

  /**
   * Создает внешюю временную таблицу для неархивируемых данных
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure create_ext_tmp_table(lp_arch_file_table_desc t_arch_file_table_desc) is
    ll_statement clob;
    ll_arch_hist_status integer;
  begin
    assert.assert_true(
      value_ =>
        lp_arch_file_table_desc.arch_file_name is not null
        and lp_arch_file_table_desc.ext_tmp_table_name is not null,
      comment_ => 'lp_arch_file_table_desc.arch_file_name и lp_arch_file_table_desc.ext_tmp_table_name не могут быть null'
    );
    ll_arch_hist_status := get_arch_hist_status(lp_arch_file_table_desc => lp_arch_file_table_desc);
    if (ll_arch_hist_status in (ARCH_ST_EXT_TMP_COPYING, ARCH_ST_EXT_TMP_COPYING - 1)) then
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_EXT_TMP_COPYING
      );
      if (ll_arch_hist_status = ARCH_ST_EXT_TMP_COPYING) then
        drop_ext_table(
          lp_table_name => lp_arch_file_table_desc.ext_tmp_table_name,
          lp_file_name => lp_arch_file_table_desc.ext_tmp_table_name
        );
      end if;
      ll_statement := lp_arch_file_table_desc.external_tbl_ddl;
      ll_statement := replace(ll_statement, EXT_TBL_AS_SELECT_PLACEHOLDER, lp_arch_file_table_desc.select_from_usr_t_to_tmp_t_dml);
      ll_statement := replace(ll_statement, EXT_TBL_NAME_PLACEHOLDER, lp_arch_file_table_desc.ext_tmp_table_name);
      ll_statement := replace(ll_statement, EXT_TBL_LOCATION_PLACEHOLDER, lp_arch_file_table_desc.ext_tmp_table_name);
      ll_statement := replace(ll_statement, NOT_PLACEHOLDER, estloc.const.NULL_CHAR);
      execute immediate ll_statement;
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_EXT_TMP_COPIED
      );
    end if;
  exception when others then
    lg_message := prepend_message(
      lp_message =>
        'create_ext_tmp_table(' || util.SMBL_LINEEND ||
        '  lp_arch_file_table_desc.arch_file_name = ' || lp_arch_file_table_desc.arch_file_name || util.SMBL_LINEEND ||
        '  ll_statement = ' || ll_statement || util.SMBL_LINEEND ||
        ')'
    );
    raise;
  end create_ext_tmp_table;

  /**
   * //TO-DO: Переиспользовать для оптимизации включения индексов, если чистка происходит за несколько лет при одном вызове скрипта.
   * Возвращает описание таблицы
   *
   * @param lp_table_list [not null] - Список таблиц с их описанием
   * @param lp_table_name [not null] - Наименование пользовательской таблицы
   *
   * @return [not null] Описание таблицы
   */
  function get_table_desc(lp_table_list t_table_list, lp_table_name varchar2) return t_table_desc is
    ll_table_desc t_table_desc;
  begin
    assert.assert_true(
      value_      => lp_table_list is not null and lp_table_list is not empty,
      value_name_ => 'lp_table_list is not null and lp_table_list is not empty',
      comment_    => 'не может быть null и должна иметь хотя бы один элемент'
    );
    assert.assert_not_null(
      value_      => lp_table_name,
      value_name_ => 'lp_table_name'
    );
    for tb in lp_table_list.first .. lp_table_list.last loop
      if (lp_table_list(tb).table_name = lp_table_name) then
        ll_table_desc := lp_table_list(tb);
        --exit;
      end if;
    end loop;
    assert.assert_true(
      value_      => ll_table_desc.table_name is not null,
      value_name_ => 'll_table_desc',
      comment_    => 'get_table_desc вернула null'
    );
    return ll_table_desc;
  end get_table_desc;

  /**
   * Проверяет файл-архив (внешюю таблицу)
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure check_arch_file(lp_arch_file_table_desc t_arch_file_table_desc) is
    ll_arch_table_row_count integer;
    ll_arch_hist_status integer;
  begin
    assert.assert_not_null(
      value_      => lp_arch_file_table_desc.arch_file_name,
      value_name_ => 'lp_arch_file_table_desc.arch_file_name'
    );
    ll_arch_hist_status := get_arch_hist_status(lp_arch_file_table_desc => lp_arch_file_table_desc);
    if (ll_arch_hist_status in (ARCH_ST_FILE_CHECKING, ARCH_ST_FILE_CHECKING - 1)) then
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_FILE_CHECKING
      );
      ll_arch_table_row_count := get_table_row_count(lp_table_name => lp_arch_file_table_desc.arch_file_table_name);
      assert.assert_true(
        value_ => ll_arch_table_row_count = lp_arch_file_table_desc.arch_table_row_count,
        comment_ => 'Количество строк в файле-архиве (' || ll_arch_table_row_count ||
          ') не соответствует ожидаемому количеству строк ('|| lp_arch_file_table_desc.arch_table_row_count || ')'
      );
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_FILE_CHECKED
      );
    end if;
  end check_arch_file;

  /**
   * Проверяет внешнюю временную таблицу с неархивируемыми данными
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure check_ext_tmp_table(lp_arch_file_table_desc t_arch_file_table_desc) is
    ll_keep_table_row_count integer;
    ll_arch_hist_status integer;
  begin
    assert.assert_true(
      value_ =>
        lp_arch_file_table_desc.arch_file_name is not null
        and lp_arch_file_table_desc.ext_tmp_table_name is not null,
      comment_ => 'lp_arch_file_table_desc.arch_file_name и lp_arch_file_table_desc.ext_tmp_table_name не могут быть null'
    );
    ll_arch_hist_status := get_arch_hist_status(lp_arch_file_table_desc => lp_arch_file_table_desc);
    if (ll_arch_hist_status in (ARCH_ST_EXT_TMP_CHECKING, ARCH_ST_EXT_TMP_CHECKING - 1)) then
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_EXT_TMP_CHECKING
      );
      ll_keep_table_row_count := get_table_row_count(lp_table_name => lp_arch_file_table_desc.ext_tmp_table_name);
      assert.assert_true(
        value_ => ll_keep_table_row_count = lp_arch_file_table_desc.keep_table_row_count,
        comment_ => 'Количество строк в внешней временной таблице с неархивируемыми данными (' || ll_keep_table_row_count ||
          ') не соответствует ожидаемому количеству строк ('|| lp_arch_file_table_desc.keep_table_row_count || ')'
      );
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_EXT_TMP_CHECKED
      );
    end if;
  end check_ext_tmp_table;

  /**
   * Проверяет пользовательскую таблицу
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure check_table(lp_arch_file_table_desc t_arch_file_table_desc) is
    ll_arch_table_row_count integer;
    ll_keep_table_row_count integer;
    ll_table_row_count integer;
    ll_arch_hist_status integer;
  begin
    assert.assert_true(
      value_ =>
        lp_arch_file_table_desc.arch_file_name is not null
        and lp_arch_file_table_desc.ext_tmp_table_name is not null,
      comment_ => 'lp_arch_file_table_desc.arch_file_name и lp_arch_file_table_desc.ext_tmp_table_name не могут быть null'
    );
    ll_arch_hist_status := get_arch_hist_status(lp_arch_file_table_desc => lp_arch_file_table_desc);
    if (ll_arch_hist_status in (ARCH_ST_TBL_CHECKING, ARCH_ST_TBL_CHECKING - 1)) then
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_TBL_CHECKING
      );
      ll_arch_table_row_count := get_table_row_count(lp_table_name => lp_arch_file_table_desc.arch_file_table_name);
      ll_keep_table_row_count := get_table_row_count(lp_table_name => lp_arch_file_table_desc.ext_tmp_table_name);
      ll_table_row_count := get_table_row_count(lp_table_name => lp_arch_file_table_desc.org_table_name);
      assert.assert_true(
        value_ =>
          ll_keep_table_row_count = lp_arch_file_table_desc.keep_table_row_count
          and lp_arch_file_table_desc.org_table_row_count = ll_arch_table_row_count + ll_table_row_count,
        comment_ => 'Количество строк в внешней временной таблице с неархивируемыми данными (' || ll_keep_table_row_count ||
          ') не соответствует количеству строк в пользовательской таблице ('|| ll_table_row_count || ') или сумма ' ||
          'количества строк в пользовательской таблице после операции копирования ('|| ll_table_row_count || ') и ' ||
          'количества строк в файле-архиве ('|| ll_arch_table_row_count || ') не соотвествует количеству строк до ' ||
          'начала всех операций ('|| lp_arch_file_table_desc.org_table_row_count || ')'
      );
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_TBL_CHECKED
      );
    end if;
  end check_table;

  /**
   * Изменяет состояния ограничений целостности таблиц
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   * @param lp_is_reference_constraint [not null] - Ссылочный тип ограничений связанных таблиц:
   *                                                  true - да (действия производятся только для связанный таблиц),
   *                                                  null или false - нет (действия производятся для указанной таблицы)
   * @param lp_action                  [not null] - Действие, например "disable"
   */
  procedure alter_constraints(
    lp_arch_file_table_desc t_arch_file_table_desc,
    lp_is_reference_constraint boolean default false,
    lp_action varchar2
  ) is
    ll_idx integer;
    ll_constraint_list estloc.tbl_clob := estloc.tbl_clob();
    ll_statement clob;
  begin
    assert.assert_not_null(
      value_ => lp_arch_file_table_desc.arch_file_name,
      value_name_ => 'lp_arch_file_table_desc.arch_file_name'
    );
    assert.assert_not_null(
      value_      => lp_action,
      value_name_ => 'lp_action'
    );
    if (lp_is_reference_constraint) then
      ll_constraint_list := lp_arch_file_table_desc.table_r_constraints;
    else
      ll_constraint_list := lp_arch_file_table_desc.table_constraints;
    end if;
    ll_idx := ll_constraint_list.first;
    if (ll_idx is null) then
      write_log(lp_message =>
        lp_arch_file_table_desc.arch_file_name || ': нет ограничений для обработки (lp_is_reference_constraint = ' ||
          util.bool2char(lp_is_reference_constraint) || ')'
      );
    end if;
    while ll_idx is not null loop
      ll_statement := ll_constraint_list(ll_idx);
      begin
        execute immediate replace(ll_statement, ACTION_PLACEHOLDER, lp_action);
      exception when others then
        if (sqlcode = -02298 and lp_action = 'enable') then
          execute immediate replace(ll_statement, ACTION_PLACEHOLDER, 'enable novalidate');
          write_log(lp_message => 'Перевод ограничения в состояние enable novalidate [' || ll_statement || ']');
        else
          raise;
        end if;
      end;
      ll_idx := ll_constraint_list.next(ll_idx);
    end loop;
  end alter_constraints;

  /**
   * Деактивировать ссылочные ограничения связанных таблиц
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure disable_r_constraints(lp_arch_file_table_desc t_arch_file_table_desc) is
  begin
    alter_constraints(
      lp_arch_file_table_desc => lp_arch_file_table_desc,
      lp_is_reference_constraint => true,
      lp_action => 'disable'
    );
  end disable_r_constraints;

  /**
   * Активировать ссылочные ограничения связанных таблиц
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure enable_r_constraints(lp_arch_file_table_desc t_arch_file_table_desc) is
  begin
    alter_constraints(
      lp_arch_file_table_desc => lp_arch_file_table_desc,
      lp_is_reference_constraint => true,
      lp_action => 'enable'
    );
  end enable_r_constraints;

  /**
   * Деактивировать ограничения таблицы
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure disable_constraints(lp_arch_file_table_desc t_arch_file_table_desc) is
  begin
    alter_constraints(
      lp_arch_file_table_desc => lp_arch_file_table_desc,
      lp_action => 'disable'
    );
  end disable_constraints;

  /**
   * Активировать ограничения таблицы
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure enable_constraints(lp_arch_file_table_desc t_arch_file_table_desc) is
  begin
    alter_constraints(
      lp_arch_file_table_desc => lp_arch_file_table_desc,
      lp_action => 'enable'
    );
  end enable_constraints;

  /**
   * Изменяет состояния индексов таблицы
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   * @param lp_action     [not null] - Действие, например "unusable"
   */
  procedure alter_indices(lp_arch_file_table_desc t_arch_file_table_desc, lp_action varchar2) is
    ll_idx integer;
    ll_index_list estloc.tbl_clob  := estloc.tbl_clob();
    ll_statement clob;
  begin
    assert.assert_not_null(
      value_ => lp_arch_file_table_desc.arch_file_name,
      value_name_ => 'lp_arch_file_table_desc.arch_file_name'
    );
    assert.assert_not_null(
      value_      => lp_action,
      value_name_ => 'lp_action'
    );
    ll_index_list := lp_arch_file_table_desc.table_indices;
    ll_idx := ll_index_list.first;
    if (ll_idx is null) then
      write_log(lp_message => lp_arch_file_table_desc.arch_file_name || ': нет индексов для обработки');
    end if;
    while ll_idx is not null loop
      ll_statement := ll_index_list(ll_idx);
      execute immediate replace(ll_statement, ACTION_PLACEHOLDER, lp_action);
      ll_idx := ll_index_list.next(ll_idx);
    end loop;
  end alter_indices;

  /**
   * Деактивирует индексы таблицы
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure disable_indices(lp_arch_file_table_desc t_arch_file_table_desc) is
  begin
    alter_indices(lp_arch_file_table_desc => lp_arch_file_table_desc, lp_action => 'unusable');
  end disable_indices;

  /**
   * Активирует индексы таблицы
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure enable_indices(lp_arch_file_table_desc t_arch_file_table_desc) is
  begin
    alter_indices(lp_arch_file_table_desc => lp_arch_file_table_desc, lp_action => 'rebuild');
  end enable_indices;

  /**
   * Удаляет данные пользовательской таблицы с использованием truncate
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure delete_table_data(lp_arch_file_table_desc t_arch_file_table_desc) is
    ll_arch_hist_status integer;
  begin
    assert.assert_not_null(
      value_      => lp_arch_file_table_desc.arch_file_name,
      value_name_ => 'lp_arch_file_table_desc.arch_file_name'
    );
    ll_arch_hist_status := get_arch_hist_status(lp_arch_file_table_desc => lp_arch_file_table_desc);
    if (ll_arch_hist_status in (ARCH_ST_TBL_DATA_DELETING, ARCH_ST_TBL_DATA_DELETING - 1)) then
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_TBL_DATA_DELETING
      );
      disable_r_constraints(lp_arch_file_table_desc => lp_arch_file_table_desc);
      execute immediate 'truncate table ' || lp_arch_file_table_desc.org_table_name;
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_TBL_DATA_DELETED
      );
    end if;
  end delete_table_data;

  /**
   * Копирует данные в пользовательскую таблицу из внешней временной таблицы
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure copy_from_ext_tmp_table(lp_arch_file_table_desc t_arch_file_table_desc) is
    ll_statement clob;
    ll_arch_hist_status integer;
    procedure main_body is
    begin
      disable_constraints(lp_arch_file_table_desc => lp_arch_file_table_desc);
      disable_indices(lp_arch_file_table_desc => lp_arch_file_table_desc);
      if (ll_arch_hist_status = ARCH_ST_TBL_COPYING) then
        disable_r_constraints(lp_arch_file_table_desc => lp_arch_file_table_desc);
        execute immediate 'truncate table ' || lp_arch_file_table_desc.org_table_name;
      end if;
      ll_statement :=
        'insert /*+ append */ into ' || lp_arch_file_table_desc.org_table_name || util.SMBL_LINEEND ||
        '(' || lp_arch_file_table_desc.table_columns_desc || ')' || util.SMBL_LINEEND ||
        'select ' || util.SMBL_LINEEND ||
        lp_arch_file_table_desc.table_columns_desc || util.SMBL_LINEEND ||
        'from ' || lp_arch_file_table_desc.ext_tmp_table_name;
      ll_statement := replace(ll_statement, SOURCE_TABLE_ALIAS_PLACEHOLDER || '.', '');
      execute immediate ll_statement;
      commit;
    end main_body;
  begin
    assert.assert_true(
      value_ =>
        lp_arch_file_table_desc.arch_file_name is not null
        and lp_arch_file_table_desc.org_table_name is not null
        and lp_arch_file_table_desc.table_columns_desc is not null
        and lp_arch_file_table_desc.ext_tmp_table_name is not null,
      value_name_ => 'lp_arch_file_table_desc не содержит необходимой информации'
    );
    ll_arch_hist_status := get_arch_hist_status(lp_arch_file_table_desc => lp_arch_file_table_desc);
    if (ll_arch_hist_status in (ARCH_ST_TBL_COPYING, ARCH_ST_TBL_COPYING - 1)) then
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_TBL_COPYING
      );
      begin
        main_body();
      exception when others then
        --ORA-29913: error in executing ODCIEXTTABLEFETCH callout
        --ORA-26026: unique index ESTLOC.UK_ORG_ORDER$ID_ORDER_IF_ACTV initially in unusable state
        if (sqlcode in (-26026, -29913)) then
          commit;
          ll_arch_hist_status := get_arch_hist_status(lp_arch_file_table_desc => lp_arch_file_table_desc);
          main_body();
        else
          raise;
        end if;
      end;
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_TBL_COPIED
      );
    end if;
  exception when others then
    lg_message := prepend_message(
      lp_message =>
        'copy_from_ext_tmp_table(' || util.SMBL_LINEEND ||
        '  lp_arch_file_table_desc.arch_file_name = ' || lp_arch_file_table_desc.arch_file_name || util.SMBL_LINEEND ||
        '  ll_statement = ' || ll_statement || util.SMBL_LINEEND ||
        ')'
    );
    raise;
  end copy_from_ext_tmp_table;

  /**
   * Завершает процесс архивации
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   */
  procedure finalize_archiving(lp_arch_file_table_desc t_arch_file_table_desc) is
    ll_arch_hist_status integer;
    ll_ext_tmp_table_name util.sqlstring;
    ll_table_size_after_mb number;
  begin
    assert.assert_true(
      value_ =>
        lp_arch_file_table_desc.arch_file_name is not null
        and lp_arch_file_table_desc.ext_tmp_table_name is not null
        and lp_arch_file_table_desc.org_table_name is not null,
      comment_ =>
        'lp_arch_file_table_desc.arch_file_name и lp_arch_file_table_desc.ext_tmp_table_name и ' ||
          'lp_arch_file_table_desc.org_table_name не могут быть null'
    );
    ll_arch_hist_status := get_arch_hist_status(lp_arch_file_table_desc => lp_arch_file_table_desc);
    if (
      ll_arch_hist_status in (
        ARCH_ST_EXT_TMP_DROPED,
        ARCH_ST_EXT_TMP_DROPING,
        ARCH_ST_EXT_TMP_DROPING - 1
      )
    ) then
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_EXT_TMP_DROPING
      );
      enable_indices(lp_arch_file_table_desc => lp_arch_file_table_desc);
      enable_constraints(lp_arch_file_table_desc => lp_arch_file_table_desc);
      enable_r_constraints(lp_arch_file_table_desc => lp_arch_file_table_desc);
      ll_ext_tmp_table_name := lp_arch_file_table_desc.ext_tmp_table_name;
      drop_ext_table(
        lp_table_name => ll_ext_tmp_table_name,
        lp_file_name => ll_ext_tmp_table_name
      );
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_EXT_TMP_DROPED
      );
      ll_table_size_after_mb := get_org_table_size_mb(lp_table_name => lp_arch_file_table_desc.org_table_name);
      update estloc.org_data_arch_hist dah
      set dah.org_table_size_after_mb = ll_table_size_after_mb
      where dah.arch_file_name = lp_arch_file_table_desc.arch_file_name;
      commit;
      update_data_arch_hist_status(
        lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
        lp_arch_hist_status => ARCH_ST_SUCCESS
      );
    end if;
  exception when others then
    lg_message := prepend_message(lp_message => 'finalize_archiving(...)');
    raise;
  end finalize_archiving;

  /**
   * Показывает наличие неархивированных пользовательских таблиц в таблице "История архивирования данных пользовательских таблиц"
   *
   * @return [not null] "true" - записи есть, "false" - записей нет
   */
  function exists_unprocessed_files return boolean is
    ll_count integer := 0;
  begin
    select count(*)
    into ll_count
    from estloc.org_data_arch_hist dah
    where dah.arch_hist_status < ARCH_ST_SUCCESS;
    return ll_count > 0;
  end exists_unprocessed_files;

  /**
   * Показывает наличие неархивированной пользовательской таблицы за кокретный год в таблице "История архивирования данных 
   *   пользовательских таблиц"
   *
   * @param lp_arch_file_name [not null] - Наименование файла-архива пользовательской таблицы
   *
   * @return [not null] "true" - запись есть, "false" - записи нет
   */
  function exists_arch_file_name(lp_arch_file_name varchar2) return boolean is
    ll_count integer := 0;
  begin
    assert.assert_not_null(
      value_      => lp_arch_file_name,
      value_name_ => 'lp_arch_file_name'
    );
    select count(*)
    into ll_count
    from estloc.org_data_arch_hist dah
    where dah.arch_file_name = lp_arch_file_name;
    if (ll_count > 0) then
      write_log(lp_message => 'Таблица "история архивирования данных пользовательских таблиц" содержит таблицы/файлы ' ||
        'необработанные полностью. Дальнейшее выполнение скрипта только попытается завершить обработку. Для создания ' ||
        'новых файлов (другие годы архивирования, которые не существуют в указанной таблице) потребуется дополнительный ' ||
        'запуск скрипта'
      );
    end if;
    return ll_count > 0;
  end exists_arch_file_name;

  /**
   * Обновляет/добавляет информацию об архивировании данных пользовательских таблиц
   *
   * @param lp_table_list [not null] - Список таблиц с их описанием
   */
  procedure update_data_arch_hist(lp_table_list t_table_list) is
    ll_arch_file_table_desc t_arch_file_table_desc;
    ll_years_qty integer default 0;
    ll_max_year integer;
  begin
    assert.assert_true(
      value_      => lp_table_list is not null and lp_table_list is not empty,
      value_name_ => 'lp_table_list',
      comment_    => 'должна иметь хотя бы один элемент'
    );
    ll_max_year := get_all_tbls_max_year_possible(lp_table_list => lp_table_list);
    for tb in lp_table_list.first .. lp_table_list.last loop
      if (lp_table_list(tb).min_year <> ESTLOC.const.NULL_NUMBER) then
        ll_years_qty :=
          coalesce(
            least(YEAR_EXCEPT_CUR_AND_YEAR_BEF, p_year_archive_data_by) - lp_table_list(tb).min_year,
            least(YEAR_EXCEPT_CUR_AND_YEAR_BEF - lp_table_list(tb).min_year, p_years_qty_archive_data)
          );
        if (ll_years_qty > 0) then
          for tb_year in (
            select arch_period_year
            from (
              select lp_table_list(tb).min_year - 1 + level arch_period_year
              from dual connect by level <= ll_years_qty
            )
            where arch_period_year <= ll_max_year
          ) loop
            ll_arch_file_table_desc.arch_file_name :=
              estloc.kernel.get_schema_name() || '.' ||
              lp_table_list(tb).table_name || '__' ||
              tb_year.arch_period_year;
            if (not exists_arch_file_name(lp_arch_file_name => ll_arch_file_table_desc.arch_file_name)) then
              ll_arch_file_table_desc.arch_file_table_name :=
                SCHEMA_PREFIX || '.' ||
                substr(cutoff_schema_prefix(lp_table_name => lp_table_list(tb).table_name), 1, 26) ||
                tb_year.arch_period_year;
              ll_arch_file_table_desc.org_table_name := lp_table_list(tb).table_name;
              ll_arch_file_table_desc.process_priority := lp_table_list(tb).process_priority;
              ll_arch_file_table_desc.arch_period_year := tb_year.arch_period_year;
              ll_arch_file_table_desc.ext_tmp_table_name :=
                get_ext_tmp_table_name(lp_arch_file_table_desc => ll_arch_file_table_desc);
              ll_arch_file_table_desc.session_uid := G_SESSION_UID;
              ll_arch_file_table_desc.arch_hist_status := ARCH_ST_SCHEDULED;
              ll_arch_file_table_desc.table_columns_desc :=
                get_select_columns_from_usr_t(lp_table_name => lp_table_list(tb).table_name);
              ll_arch_file_table_desc.table_time_filter_column := lp_table_list(tb).table_time_filter_column;
              ll_arch_file_table_desc.from_where_clause := lp_table_list(tb).from_where_clause;
              ll_arch_file_table_desc.min_year := lp_table_list(tb).min_year;
              ll_arch_file_table_desc.table_constraints :=
                get_constraint_list(lp_table_name => lp_table_list(tb).table_name);
              ll_arch_file_table_desc.table_r_constraints :=
                get_r_constraint_list(lp_table_name => lp_table_list(tb).table_name);
              ll_arch_file_table_desc.table_indices := get_indices(lp_table_name => lp_table_list(tb).table_name);
              ll_arch_file_table_desc.job_list := get_job_list();
              ll_arch_file_table_desc.table_primary_key_column :=
                get_primary_key_column(lp_table_name => lp_table_list(tb).table_name);
              ll_arch_file_table_desc.org_table_size_mb := get_org_table_size_mb(lp_table_name => lp_table_list(tb).table_name);
              ll_arch_file_table_desc.select_from_usr_t_to_ext_t_dml :=
                get_select_from_usr_t_to_ext_t(lp_arch_file_table_desc => ll_arch_file_table_desc);
              ll_arch_file_table_desc.select_from_usr_t_to_tmp_t_dml :=
                get_select_from_usr_t_to_tmp_t(lp_arch_file_table_desc => ll_arch_file_table_desc);
              ll_arch_file_table_desc.table_desc_ddl := get_table_desc_ddl(lp_table_name => lp_table_list(tb).table_name);
              ll_arch_file_table_desc.external_tbl_ddl := get_external_tbl_ddl();
              ll_arch_file_table_desc.arch_file_query := 'na';
              ll_arch_file_table_desc.create_dt := estloc.kernel.get_sysdate();
              merge into estloc.org_data_arch_hist t
              using (select null from dual) s on (ll_arch_file_table_desc.arch_file_name = t.arch_file_name)
              when not matched then insert values ll_arch_file_table_desc;
            else
              write_log(lp_message =>
                'ВНИМАНИЕ: для таблицы [' || lp_table_list(tb).table_name || '] уже создан файл-архив [' ||
                ll_arch_file_table_desc.arch_file_name || ']'
              );
            end if;
          end loop;
        else
          write_log(lp_message =>
            'Для таблицы [' || lp_table_list(tb).table_name || '] архивация не требуется.' ||
            ' Минимальный год логического создания строк таблицы для архивации [' || lp_table_list(tb).min_year || ']' ||
            ' максимально возможный год, данные за который могут быть архивированы для всех таблиц [' || ll_max_year || ']'
          );
        end if;
      else
        write_log(lp_message =>
          'ВНИМАНИЕ: для таблицы [' || lp_table_list(tb).table_name || '] не определен минимальный год логического' ||
          ' создания строк таблицы для архивации. Вероятно таблица пустая'
        );
      end if;
    end loop;
    commit;
  end update_data_arch_hist;

  /**
   * Обновляет информацию о размерах таблиц и количестве строк и возвращает информацию об архивировании данных пользовательских таблиц
   *
   * @param lp_arch_file_table_desc [not null] - Информация о архивировании данных пользовательской таблицы за конкретный год
   *
   * @return [not null] Список таблиц с их описанием с обновленной информацией
   */
  function update_arch_file_table_desc(lp_arch_file_table_desc t_arch_file_table_desc) return t_arch_file_table_desc is
    ll_arch_file_table_desc t_arch_file_table_desc;
    ll_arch_hist_status integer;
  begin
    assert.assert_true(
      value_      =>
        lp_arch_file_table_desc.arch_file_name is not null
        and lp_arch_file_table_desc.org_table_name is not null,
      value_name_ => 'lp_arch_file_table_desc.arch_file_name и lp_arch_file_table_desc.org_table_name',
      comment_    => 'не может быть null'
    );
    ll_arch_file_table_desc := lp_arch_file_table_desc;
    ll_arch_hist_status := get_arch_hist_status(lp_arch_file_table_desc => lp_arch_file_table_desc);
    if (ll_arch_hist_status = ARCH_ST_SCHEDULED) then
      ll_arch_file_table_desc.org_table_size_mb :=
        get_org_table_size_mb(lp_table_name => lp_arch_file_table_desc.org_table_name);
      ll_arch_file_table_desc.org_table_row_count :=
        get_table_row_count(lp_table_name => lp_arch_file_table_desc.org_table_name);
      ll_arch_file_table_desc.arch_table_row_count :=
        get_arch_table_row_count(lp_arch_file_table_desc => lp_arch_file_table_desc);
      ll_arch_file_table_desc.keep_table_row_count :=
        ll_arch_file_table_desc.org_table_row_count - ll_arch_file_table_desc.arch_table_row_count;

      update estloc.org_data_arch_hist dah
      set
        dah.org_table_size_mb = ll_arch_file_table_desc.org_table_size_mb,
        dah.org_table_row_count = ll_arch_file_table_desc.org_table_row_count,
        dah.arch_table_row_count = ll_arch_file_table_desc.arch_table_row_count,
        dah.keep_table_row_count = ll_arch_file_table_desc.keep_table_row_count
      where dah.arch_file_name = lp_arch_file_table_desc.arch_file_name;
      commit;
      if (ll_arch_file_table_desc.arch_table_row_count = 0) then
        update_data_arch_hist_status(
          lp_arch_file_name => lp_arch_file_table_desc.arch_file_name,
          lp_arch_hist_status => ARCH_ST_SUCCESS
        );
      end if;
    end if;
    assert.assert_not_null(
      value_   => ll_arch_file_table_desc.arch_file_name,
      comment_ => 'update_arch_file_table_desc вернула null'
    );
    return ll_arch_file_table_desc;
  end update_arch_file_table_desc;
begin
  write_log(lp_message => START_PROC);
  l_log.info(message_ => START_PROC);
  execute immediate 'alter session set nls_date_format=''yyyy-mm-dd hh24:mi:ss'' ';
  check_parameters();
  if (not exists_unprocessed_files()) then
    update_data_arch_hist(lp_table_list => calc_tables_min_years(lp_table_list => get_table_list()));
  end if;
  disable_jobs();
  disable_replication_up();

  for i in (
    select dah.*
    from estloc.org_data_arch_hist dah
    where dah.arch_hist_status between ARCH_ST_SCHEDULED and ARCH_ST_TBL_CHECKED - 1
    order by dah.arch_period_year, dah.process_priority, dah.org_table_size_mb desc, dah.org_table_name
  ) loop
    write_log(lp_message =>
      estloc.sbuilder(START_PROC_ONE_TABLE)
        .fill('file_directory', FULL_ARCH_DIRECTORY)
        .fill('file_name', i.arch_file_name)
        .fill('period', i.arch_period_year)
        .to_string()
    );
    execute immediate 'alter system archive log current';
    execute immediate 'alter system  switch logfile';
    --Если параметрами p_years_qty_archive_data или p_year_archive_data_by установлено обработать более одного года, то
    --  процедура update_data_arch_hist не сможет корректно рассчитать размер таблицы и количество строк для каждого года,
    --  поэтому необходимо обновить эти данные после обработки каждого года
    lg_currnt_arch_file_table_desc := update_arch_file_table_desc(lp_arch_file_table_desc => i);
    --1. Создать внешнюю файл-таблицу
    create_arch_file(lp_arch_file_table_desc => lg_currnt_arch_file_table_desc);
    --2. Проверить файл-таблицу
    check_arch_file(lp_arch_file_table_desc => lg_currnt_arch_file_table_desc);
    --3. Копировать неархивируемые данные в внешнюю временную таблицу из пользовательской таблицы, которая будет очищена
    --     с помощью truncate, а данные возвращены обратно
    create_ext_tmp_table(lp_arch_file_table_desc => lg_currnt_arch_file_table_desc);
    --4. Проверить внешнюю временную таблицу
    check_ext_tmp_table(lp_arch_file_table_desc => lg_currnt_arch_file_table_desc);
    --5. Удалить данные из пользовательской таблицы
    delete_table_data(lp_arch_file_table_desc => lg_currnt_arch_file_table_desc);
    --6. Копировать данные из внешней временной таблицы в пользовательскую
    copy_from_ext_tmp_table(lp_arch_file_table_desc => lg_currnt_arch_file_table_desc);
    --7. Проверить пользовательскую таблицу
    check_table(lp_arch_file_table_desc => lg_currnt_arch_file_table_desc);
  end loop;

  for i in (
    select dah.*
    from estloc.org_data_arch_hist dah
    where dah.arch_hist_status between ARCH_ST_TBL_CHECKED and ARCH_ST_SUCCESS - 1
    order by dah.arch_period_year, dah.process_priority, dah.org_table_size_mb desc, dah.org_table_name
  ) loop
    lg_currnt_arch_file_table_desc := i;
    --8. Завершить архивацию
    finalize_archiving(lp_arch_file_table_desc => lg_currnt_arch_file_table_desc);
    l_space_freed := l_space_freed + get_freed_space(lp_arch_file_table_desc => lg_currnt_arch_file_table_desc);
  end loop;
  enable_jobs();
  lg_message :=
    FINISH_SUCCESSFUL || util.SMBL_LINEEND ||
    '  Освобождено: ' || l_space_freed || ' МБ' || util.SMBL_LINEEND ||
    '  Всего доступно: ' || get_estloc_free_space() || ' МБ';
  write_log(lp_message => lg_message);
  l_log.info(message_ => lg_message);
  dbms_application_info.set_client_info(null);
exception when others then
  rollback;
  lg_message := prepend_message(
    lp_message => FINISH_ERROR || util.SMBL_LINEEND,
    lp_with_err_stack => true
  );
  write_log(lp_message => lg_message);
  l_log.error(message_ => lg_message);
  save_error_msg_update_status();
  dbms_application_info.set_client_info(null);
  raise;
end archive_oradata_to_ext_file;
/

begin
  dbms_output.put_line(
    estloc.dblog_util.set_dblog_default_settings(
      replication_log_level_ => estloc.dblog_util.LOG_LEVEL_NONE,
      logger_name_           => 'archive_oradata_to_ext_file',
      acronym_               => 'SYS_CONFIG',
      log_level_             => estloc.dblog_util.LOG_LEVEL_INFO,
      log_destination_       => estloc.dblog_util.LOG_DESTINATION_TABLE
    )
  );
  commit;
end;
/

exit
