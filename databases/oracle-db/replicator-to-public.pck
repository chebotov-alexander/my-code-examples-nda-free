create or replace package replicator is
/**
 * Пакет для обновления данных глобального сервера
 */

/** Информация из upload_tables о репликации реплицируемой таблицы */
subtype t_upload_table_info is upload_tables%rowtype;

/** Переменная окружения, которую необходимо выставить для деактивации триггеров вставки/обновления реплицируемых таблиц */
g_is_up_replication_on boolean := false;

/**
 * Возвращает в виде строки наименование столбца, который является первичным ключом таблицы. Не учитывает составные ключи
 *
 * @param loc_table_name_ [not null] - Наименование реплицируемой таблицы
 *
 * @return [nullable] Наименование столбца, null - простой первичный ключ не найден
 */
function get_pk_column_name(loc_table_name_ varchar2) return varchar2;

/*
* Для возможности модульного тестирования внутренних функций пакета
* на девелоперском и тестовом окружениях объявляем спецификации внутренних функций
*/

$if not est_ident.is_prod_env $then
/** Возвращает последний переданный scn */
function get_upload_table_dbscn(table_name_ varchar2) return integer;
$end

$if not est_ident.is_prod_env $then
/**
 * Возвращает наименование временной
 * репликационной таблицы для указанной таблицы
 *
 * @param table_name_ [not null] - Наименование передаваемой таблицы
 *
 * @return Наименование временной репликационной таблицы
 */
function get_temporary_table_name(table_name_ varchar2) return varchar2;
$end

$if not est_ident.is_prod_env $then
/**
 * Возвращает случайным образом выбранный столбец для тривиального обновления.
 *   Столбец не может быть первичным или вторичным ключом.
 *   Столбец не может иметь наименование 'END_DT', 'DELETE_DT', 'REP_UP_STATUS'
 *   Менее приоритетны индексируемые.
 *   Приоритетны столбцы: с наименованием 'CREATE_DT', поддерживающие null значения, имеющие наименьший размер
 *
 * @param table_name_ [not null] - Наименование реплицируемой таблицы
 *
 * @return [not null] Наименование столбца для тривиального обновления
 */
function get_random_loc_tbl_column_name(table_name_ varchar2) return varchar2;
$end

$if not est_ident.is_prod_env $then
/**
 * Возвращает наименование фильтрующего представления
 *
 * @param table_name_ [not null] - Наименование передаваемой таблицы
 *
 * @return Наименование фильтрующего представления
 */
function get_filter_view_name(table_name_ varchar2) return varchar2;
$end

$if not est_ident.is_prod_env $then
/**
 * Производит тривиальное обновление (увеличение scn) записей "родительской таблицы" по полю parent_table_key_column_name_,
 *   значения которых равно значениям в поле child_table_key_column_name_ "дочерней таблицы" всех записей, scn которых
 *   больше child_table_err_scn_.
 *   Необходимо в случае, если "родительская таблица" реплицируется порциями и переданная порция не может покрыть
 *   все значения "родительской таблицы", на которые ссылается "дочерняя таблица". Тривиальное обновление "родительской
 *   таблицы" повлечет повторную репликацию её строк, scn которых был увеличен этим обновлением (количество таких строк
 *   равно размеру порции, в которую попали строки, на которых сработало ограничение сслочной целостности "дочерней таблицы".
 * Автономная транзакция
 *
 * @param parent_table_name_ [not null] - Наименование "родительской таблицы"

 * @param child_table_name_  [nullable] - Наименование "дочерней" (реплицируемой таблицы)
 * @param fk_constraint_     [nullable] - Наименование ссылочного ограничения дочерней таблицы
 * @param log_               [nullable] - Объект логера
 *
 * @throws ORA-20718 - Ошибка репликации. Не найдена информация о репликации реплицируемой таблицы
 */
procedure update_parent_table_scn(
  parent_table_name_           varchar2,
  parent_table_key_column_name_ varchar2,
  child_table_name_            varchar2,
  child_table_key_column_name_  varchar2,
  child_table_err_scn_         integer,
  log_                         dblogger default null
);
$end

$if not est_ident.is_prod_env $then
/**
 * Получает наименование передаваемой таблицы по имени реальной таблицы (локальной или глобальной)
 * Для таблиц, которые передаются несколькими способами возбудит исключение too_many_rows
 * <br>
 * Обязательно должен быть указан только один из параметров loc_table_name_ или main_table_name_
 *
 * @param loc_table_name_  [nullable] - Имя локальной таблицы
 * @param main_table_name_ [nullable] - Имя глобальной таблицы
 */
function get_table_name(
  loc_table_name_  varchar2 default null,
  main_table_name_ varchar2 default null
) return varchar2;
$end

$if not est_ident.is_prod_env $then
/** Функция возвращает информацию о ссылочном ограничении на глобальной базе */
function get_main_fk_constraint_info(errmessage_ varchar2) return replicator.t_fk_constraint_info;
$end

$if not est_ident.is_prod_env $then
/** Отключает отложенность ограничений, чтобы ловить ошибки до commit */
procedure set_constraints_all_immediate;
$end

$if not est_ident.is_prod_env $then
/**
 * Производит заполнение локальной временной или буферной таблицы в зависимости от режима работы репликатора
 *
 * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
 * @param log_               [nullable] - Объект логера
 *
 * @return [not null] Количество вставленных записей
 */
function populate_tmp_buf_table(
  upload_table_info_ replicator.t_upload_table_info,
  log_ dblogger default null
) return integer;
$end

$if not est_ident.is_prod_env $then
/**
 * Выполняет передачу данных из локальной временной или буферной таблицы в глобальную временную таблицу
 *   и возвращает количество реплицированных строк (sql%rowcount после оператора merge)
 *
 * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
 *
 * @return [not null] количество реплицированных строк
 */
function transfer_table_data(upload_table_info_ replicator.t_upload_table_info) return integer;
$end

$if not est_ident.is_prod_env $then
/**
 * Передает управление глоабльным функциям-загрузчикам, которые из глобальных временных таблиц загружают данные на ГБД
 *
 * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
 */
procedure upload_table_data(upload_table_info_ replicator.t_upload_table_info);
$end

$if not est_ident.is_prod_env $then
/**
 * Производит загрузку изменившихся данных для указанной таблицы
 *
 * @param table_name_ [not null] - Наименование реплицируемой таблицы
 * @param log_        [nullable] - Объект логера
 *
 * @throws ORA-20717 - Ошибка репликации. Признак репликации (значение столбца-признака_репликации) не был изменен
 * @throws ORA-20718 - Ошибка репликации. Не найдена информация о репликации реплицируемой таблицы
 */
procedure upload_one_table(table_name_ varchar2, log_ dblogger default null);
$end

$if not est_ident.is_prod_env $then
/**
 * Реплицирует указанную таблицу, на первичный ключ которой ссылается таблица, при репликации которой произошло нарушение
 *   ссылочной целостности в ГБД
 *
 * @param child_table_name_ [not null] - Наименование таблицы, которую нужно реплицировать
 * @param sqlerrm_          [not null] - Текс ошибки
 * @param level_            [not null] - Уровень вложенности
 * @param log_              [nullable] - Объект логера
 */
procedure upload_parent_table(
  child_table_name_ varchar2,
  sqlerrm_          varchar2,
  level_            integer  default 1,
  log_              dblogger default null
);
$end

$if not est_ident.is_prod_env $then
/**
 * Загружает обновленные данные для всех таблиц
 *
 * @param check_offline_ [not null] - Признак: true - проверять офлайн, false - не проверять офлайн
 * @param log_           [nullable] - Объект логера
 */
procedure upload_all_tables(check_offline_ boolean default true, log_ dblogger default null);
$end

/**
 * Загружает в ГБД одну запись произвольной таблицы по ключу
 * <br>
 * Ограничения: ключ может быть только простым (одноколоночными) целочисленным
 *
 * @param loc_table_name_   [not null] - Имя передаваемой таблицы, как оно задано на локальной базе
 * @param id_key_value_     [not null] - Значение ключа записи для передачи
 */
procedure upload_one_record(
  loc_table_name_  varchar2,
  id_key_value_    integer
);

/**
 * Тип для отображения информации о ссылочных ограничениях
 *
 * @param fk_constraint      Наименование ограничения внешнего ключа
 * @param child_table        Имя дочерней таблицы
 * @param child_key_columns  Описания колонок, на которые наложено ограничение ссылочной целостности
 * @param pk_constraint      Наименование первичного (альтернативного) ключа, на которое ссылается ограничение
 * @param parent_table       Имя родительской таблицы
 * @param parent_key_columns Описания колонок, на которые ссылается ограничение ссылочной целостности
 */
type t_fk_constraint_info is record (
  fk_constraint      varchar2(30),
  child_table        varchar2(30),
  child_key_columns  tbl_column_description,
  pk_constraint      varchar2(30),
  parent_table       varchar2(30),
  parent_key_columns tbl_column_description
);

/** Репликация вверх всех таблиц с измененными данными для запуска джобиком */
procedure upload_all_tables_job;

/**
 * Передает изменившиеся данные таблицы на глобальный сервер
 *
 * @param table_name_      [nullable] наименование реплицируемой таблицы
 * @param loc_table_name_  [nullable] локальное имя реплицируемой таблицы
 * @param main_table_name_ [nullable] глобальное имя реплицируемой таблицы
 * Должен быть задан один из параметров и только один
 */
procedure upload_table(
  table_name_      varchar2 default null,
  loc_table_name_  varchar2 default null,
  main_table_name_ varchar2 default null
);

/**
 * Форсирует репликацию таблицы на следующем цикле передачи данных
 * @param table_name_      [nullable] наименование реплицируемой таблицы
 * @param loc_table_name_  [nullable] локальное имя реплицируемой таблицы
 * @param main_table_name_ [nullable] глобальное имя реплицируемой таблицы
 * Должен быть задан один из параметров и только один
 */
procedure force_table_upload(
  table_name_      varchar2 default null,
  loc_table_name_  varchar2 default null,
  main_table_name_ varchar2 default null
);

end replicator;
/

create or replace package body replicator is

/* Локальная автонастройка репликации. Этапы итерации. В начале итерации репликации */
TUNE_ON_STAGE_BEGIN constant integer := 0;
/* Локальная автонастройка репликации. Этапы итерации. В конце итерации репликации */
TUNE_ON_STAGE_END constant integer := 1;
/*
 * Если реплицируемая таблица не имеет простого первичного ключа, то полям upload_tables.pk_column_name_changed
 *   и upload_tables.pk_column_name присваивается значение "UNKNOWN". Столбец upload_tables.pk_column_name_changed
 *   имеет ограничение not null
 */
PK_SIMPLE_COLUMN_NAME_UNKNOWN constant upload_tables.pk_column_name%type := 'UNKNOWN';
/*
 * Пороговое значение количества ошибок подряд, больше которого производится проверка/корректировка sql операторов и
 *   информации о структурах, участвующих в репликации реплицируемой таблицы
 */
ERR_CNT_CONSECUTIVE_CHECKUP constant integer := 10;
/*
 * Пороговое значение количества ошибок подряд, больше которого следующая попытка репликации будет произведена через
 *   вычисляемый таймаут
 */
ERR_CNT_CONSECUTIVE_THRESHOLD constant integer := 15;
/*
 * Пороговое значение количества ошибок подряд при попытке репликации "родительской таблицы" функцией
 *   replicator.upload_parent_table, больше которого производится тривиальное обновление (увеличение scn) "родительской таблицы"
 */
ERR_CNT_CONSECUTIVE_UPD_PARENT constant integer := 5;
/*
 * Пороговое значение количества ошибок подряд, при превышении которого процедура автонастройки изменяет
 *   режим репликации и/или действующее количество строк в порции (upload_tables.portion_size_default) для режимов
 *   работы, предусматривающих передачу порциями
 */
ERR_CNT_CONSECUTIVE_TUNE_LNK constant integer := 3;
/*
 * Множитель интервала периода обновления таблицы (upload_tables.refresh_interval) для расчета таймаута при превышении
 *   порогового количества ошибок подряд
 */
REFRESH_INTERVAL_FACTOR constant integer := 10;
/*
 * Минимальный таймаут при превышении порогового количества ошибок подряд или ошибок, связанных с распределенной
 *   транзакцией, в секундах
 */
TIMEOUT_MAX constant integer := 300; --5 мин
/*
 * Максимальное время в секундах, по истечении которого статус итерации репликации (upload_tables.run_status) переводится
 *   в значение 2 - завершена ошибкой.
 *   Используется для разблокировки репликации конкретной таблицы в случае сбоя при превышении временного предела,
 *     например, ошибка БД, т.е. не обрабатываемое репликатором исключение
 */
RESET_RUN_STATUS_TIME_LIMIT constant integer := 900; --15 мин
/* Максимальное время простоя репликации таблицы (без учета периода для обновления таблицы), в секундах */
REFRESH_TIME_MAX_OVERDUE constant integer := 1800; --30 мин
/* Максимальное количество строк, при превышении которого производится сброс статистических счетчиков */
RESET_CNT_ON_ROWS_REPLICATED constant integer := 100000000;
/* Суммарное количество дней работы репликатора, при превышении которого производится сброс статистических счетчиков */
BASE_DATE constant date := to_date('2018-01-01 00:00:01', 'YYYY-MM-DD HH24:MI:SS');
/* Суммарное количество дней работы репликатора, при превышении которого производится сброс статистических счетчиков */
RESET_CNT_ON_DURATION constant integer := 90;

/**
 * Генерирует и возвращает уникальный идентификатор сессии (идентификатор вызывающей функции/процедуры).
 *   Если репликация конкретной таблицы уже выполняется функцией/процедурой, другая функция/процедура
 *   не может иницировать репликацию этой таблицы, пока первая не снимет свою блокировку, или блокировка не будет снята
 *   по таймауту
 *
 * @return [not null] уникальный идентификатор сессии (идентификатор вызывающей функции/процедуры)
 */
function generate_session_uid return integer is
begin
  return trunc(dbms_random.value(1, 10) * 10000);
end generate_session_uid;

/**
 * Меняет (блокирует/снимает блокировку) статус итерации репликации реплицируемой таблицы.
 *   и устанавливает время начала/завершения итерации репликации
 * Автономная транзакция, обновляет upload_tables
 *
 * @param table_name_  [not null] - Наименование передаваемой таблицы
 * @param session_uid_ [not null] - Уникальный идентификатор сессии, не связан с сессией БД.
 *                                    Вывести из состояния блокировки может только сессия, заблокировавшая таблицу, т.е.
 *                                    значение параметра session_uid_ должно совпадать с значением в upload_tables.
 *                                    Изменение из других статусов не требуют такого совпадения
 * @param run_status_  [not null] - Статус итерации репликации:
 *                                    1 - выполняется/заблокирована (const.REP_UP_RUN_STATUS_RUNNING),
 *                                    0 - завершена успешно (const.REP_UP_RUN_STATUS_COMPLETE),
 *                                    2 - завершена ошибкой (const.REP_UP_RUN_STATUS_ERROR)
 */
procedure change_upload_table_run_status(
  table_name_  varchar2,
  session_uid_ integer,
  run_status_  integer
) is
  pragma autonomous_transaction;
  l_success integer;
  DT constant timestamp := systimestamp;
begin
  update upload_tables ut
  set
    ut.run_status  = run_status_,
    ut.session_uid = session_uid_,
    ut.run_start_datetime = decode(run_status_, const.REP_UP_RUN_STATUS_RUNNING, DT, null),
    ut.run_end_datetime   = decode(run_status_, const.REP_UP_RUN_STATUS_RUNNING, null, DT)
  where
    ut.table_name = table_name_
    and (
      -- разблокировать может только заблокировавший
      ut.session_uid = session_uid_
      or ut.run_status <> const.REP_UP_RUN_STATUS_RUNNING
      -- или в случае сбоя при превышении установленного временного предела,
      --   например, ошибка БД, т.е. не обрабатываемое репликатором исключение
      or coalesce(cast(coalesce(ut.run_start_datetime, ut.run_end_datetime) as date), ut.refresh_dt)
        + replicator.RESET_RUN_STATUS_TIME_LIMIT * const.TIME_DAYS_IN_SECOND < cast(DT as date)
    );

  l_success := sql%rowcount;

  --  обязателен для автономной транзакции
  commit;
  assert.assert_true(
    value_ => l_success > 0,
    comment_ => 'Таблица уже в процессе репликации (в случае параллельного выполнения задания)'
  );
end change_upload_table_run_status;

/**
 * Вспомогательная функция
 * Возвращает наименование локальной таблицы для реплицируемой таблицы
 *
 * @param table_name_ [not null] - Наименование реплицируемой таблицы
 *
 * @return [nullable] Наименование локальной таблицы
 */
function get_loc_table_name(table_name_ varchar2) return varchar2 is
begin
//
end get_loc_table_name;

/**
 * Возвращает в виде строки наименование столбца, который является первичным ключом таблицы. Не учитывает составные ключи
 *
 * @param loc_table_name_ [not null] - Наименование реплицируемой таблицы
 *
 * @return [nullable] Наименование столбца, null - простой первичный ключ не найден
 */
function get_pk_column_name(loc_table_name_ varchar2) return varchar2 is
begin
//
end get_pk_column_name;

/** Возвращает последний переданный scn */
function get_upload_table_dbscn(table_name_ varchar2) return integer is
begin
//
end get_upload_table_dbscn;

/**
 * Возвращает наименование временной репликационной таблицы для указанной таблицы
 *
 * @param table_name_ [not null] - Наименование передаваемой таблицы
 *
 * @return [not null] наименование временной репликационной таблицы
 */
function get_temporary_table_name(table_name_ varchar2) return varchar2 is
begin
//
end get_temporary_table_name;

/**
 * Возвращает наименование буферной таблицы для указанной реплицируемой таблицы
 *
 * @param table_name_ [not null] - Наименование реплицируемой таблицы
 *
 * @return [not null] наименование буферной таблицы
 */
function get_buffer_table_name(table_name_ varchar2) return varchar2 is
begin
//
end get_buffer_table_name;

/**
 * Возвращает наименование фильтрующего представления
 *
 * @param table_name_ [not null] - Наименование передаваемой таблицы
 *
 * @return [not null] наименование фильтрующего представления
 */
function get_filter_view_name(table_name_ varchar2) return varchar2 is
begin
//
end get_filter_view_name;

/**
 * Получает наименование передаваемой таблицы по имени реальной таблицы (локальной или глобальной)
 * Для таблиц, которые передаются несколькими способами возбудит исключение too_many_rows
 *
 * Обязательно должен быть указан только один из параметров loc_table_name_ или main_table_name_
 *
 * @param loc_table_name_  [nullable] - Имя локальной таблицы
 * @param main_table_name_ [nullable] - Имя глобальной таблицы
 */
function get_table_name(
  loc_table_name_  varchar2 default null,
  main_table_name_ varchar2 default null
) return varchar2 is
begin
//
end get_table_name;

/** Функция возвращает информацию о ссылочном ограничении на глобальной базе */
function get_main_fk_constraint_info(errmessage_ varchar2)
return replicator.t_fk_constraint_info is
begin
//
end get_main_fk_constraint_info;

/** Отключает отложенность ограничений, чтобы ловить ошибки до commit */
procedure set_constraints_all_immediate is
begin
  execute immediate 'set constraints all immediate';
end set_constraints_all_immediate;

/**
 * Формирует список столбцов локальной временной таблицы
 * Явное указание столбцов позволяет поддерживать обратную совместимость
 *
 * @param temporary_table_name_ [not null] - Наименование временной таблицы
 * @param with_rep_up_status_   [nullable] - Включить в список столбец_признак-репликации - 1, иначе 0 (по умолчанию)
 * @param with_row_num_         [nullable] - Включить в список столбец "Номер строки для режима репликации порциями"
 *                                             для временных таблиц реплицируемых таблиц - 1, иначе 0 (по умолчанию)
 *
 * @return [not null] список столбцов локальной временной таблицы
 */
function get_temporary_table_columns(
  temporary_table_name_ varchar2,
  with_rep_up_status_   integer default 0,
  with_row_num_         integer default 0
) return util.sqlstring is
  l_result util.sqlstring default null;
begin
  select listagg(tc.column_name, ', ') within group (order by tc.column_id asc)
  into l_result
  from user_tab_columns tc
  where
    tc.table_name = temporary_table_name_
    and (tc.column_name <> const.REP_UP_ROW_NUM_COLUMN_NAME and with_row_num_ = 0 or with_row_num_ = 1)
    and (tc.column_name <> const.REP_UP_STATUS_COLUMN_NAME and with_rep_up_status_ = 0 or with_rep_up_status_ = 1);

  return l_result;
end get_temporary_table_columns;

/**
 * Возвращает случайным образом выбранный столбец реплицируемой таблицы для тривиального обновления строк (увеличения scn).
 *   Столбец не может быть первичным или вторичным ключом.
 *   Столбец не может иметь наименование 'END_DT', 'DELETE_DT', 'REP_UP_STATUS'
 *   Менее приоритетны индексируемые.
 *   Приоритетны столбцы: с наименованием 'CREATE_DT', поддерживающие null значения, имеющие наименьший размер
 *
 * @param table_name_ [not null] - Наименование реплицируемой таблицы
 *
 * @return [not null] наименование столбца
 */
function get_random_loc_tbl_column_name(table_name_ varchar2) return varchar2 is
  l_column_name upload_tables.trivia_upd_column_name%type;
begin
  for rec in (
    select tc.column_name
    from all_tab_columns tc
      left join all_cons_columns cc on (cc.column_name = tc.column_name and cc.table_name = tc.table_name)
      left join all_constraints ct on (ct.constraint_name = cc.constraint_name and ct.table_name = tc.table_name)
      left join all_ind_columns ic on (ic.table_name = tc.table_name and ic.column_name = tc.column_name)
      left join all_indexes ix on (ix.index_name = ic.index_name)
    where
      tc.table_name = upper(table_name_)
      and coalesce(ct.constraint_type, const.NULL_CHAR) not in ('P', 'R')
      and tc.column_name not in ('END_DT', 'DELETE_DT', const.REP_UP_STATUS_COLUMN_NAME)
      order by
        decode(tc.column_name, 'CREATE_DT', 1, 2),
        decode(ct.constraint_name, null, 1, 2),
        decode(ic.index_name, null, 1, 2),
        decode(ix.index_name, null, 1, 2),
        decode(tc.nullable, 'Y', 1, 2),
        tc.data_length asc
  ) loop
    return rec.column_name;
  end loop;

  assert.assert_not_null(
    value_   => l_column_name,
    comment_ => 'Не удалось определить случайный столбец для тривиального обновления строк (увеличения scn)'
  );
  return null;
end get_random_loc_tbl_column_name;

/**
 * Производит заполнение локальной временной или буферной таблицы в зависимости от режима работы репликатора
 *
 * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
 * @param log_               [nullable] - Объект логера
 *
 * @return [not null] количество вставленных записей
 */
function populate_tmp_buf_table(
  upload_table_info_ replicator.t_upload_table_info,
  log_ dblogger default null
) return integer is
  l_log dblogger := log_;
  SQL_CLEAN_TMP_TABLE constant util.sqlstring := 'truncate table '||upload_table_info_.temporary_table_name;
  l_cnt_rows_tmp integer;
begin
  if (l_log is null) then
    l_log := dblog_util.get_dblogger(
      acronym_   => 'REPLICATOR',
      fcbuilder_ => fcbuilder('POPULATE_TMP_BUF_TABLE')
       .param('upload_table_info_', upload_table_info_.table_name)
    );
  else
    l_log.l_acronym := 'REPLICATOR';
    l_log.l_logger_name := 'REPLICATOR.POPULATE_TMP_BUF_TABLE';
  end if;

  if(upload_table_info_.rep_up_mode_current = const.REP_UP_M_SCN) then
    execute immediate SQL_CLEAN_TMP_TABLE;
    execute immediate upload_table_info_.sql_pop_tmp_scn
      using upload_table_info_.dbscn;
    l_cnt_rows_tmp := sql%rowcount;
  elsif(upload_table_info_.rep_up_mode_current = const.REP_UP_M_SCN_PRT) then
    execute immediate SQL_CLEAN_TMP_TABLE;
    execute immediate upload_table_info_.sql_pop_tmp_scn_prt
      using upload_table_info_.dbscn, upload_table_info_.portion_size_actual;
    l_cnt_rows_tmp := sql%rowcount;
  elsif(upload_table_info_.rep_up_mode_current = const.REP_UP_M_BUFFER_PRT) then
    -- не заполнять таблицу, если общее количество переданных порций (upload_table_info_.cnt_rows_prt_series) еще
    --   не сравнялось или не превысило количество строк в буферной таблице - это гарантируется процедурой
    --   upload_one_table, если последнее выполняется, то upload_table_info_.cnt_rows_tmp обнуляется при успешном
    --   завершении репликации всех строк из буферной таблицы за одну или более итераций. До того момента буферная
    --   таблица не очищается и содержит не менее одной строки
    -- использование upload_table_info_.cnt_rows_tmp безопасно, т.к. изменение информации о репликации реплицируемой
    --   таблицы блокируется текущей итерацией
    declare
      l_is_not_empty_buf_tbl integer;
    begin
      execute immediate upload_table_info_.sql_is_not_empty_buf_tbl into l_is_not_empty_buf_tbl;
      -- TO-DO: добавить проверку: если upload_table_info_.cnt_rows_tmp <> upload_table_info_.cnt_rows_prt_series и
      --          буферная таблица не имеет строк upload_table_info_.cnt_rows_prt_series, то возможно нарушена логика
      --          или буферная таблица была очищена до завершения репликации всех порций, что, скорее всего ошибка
      if (not util.int2bool(l_is_not_empty_buf_tbl)) then
        execute immediate upload_table_info_.sql_pop_buf_prt
          using upload_table_info_.dbscn;
        l_cnt_rows_tmp := sql%rowcount;
      else
        -- ниже транзакция подтверждается, и если после этого произойдет необрабатываемый сбой БД?, сбой связанный с
        --   распределенной транзакцией, сбой доступа к ГБД, то буферная таблица будет заполнена, но в upload_tables
        --   не будет записно количество строк в буферной таблице, и в результате таблица никогда не будет реплицирована.
        --   В этом случае необхиодимо получить количество строк в буферной таблице и записать его в upload_tables
        if (upload_table_info_.cnt_rows_tmp = 0) then
          execute immediate 'select count(*) from '||upload_table_info_.buffer_table_name into l_cnt_rows_tmp;
        else
          l_cnt_rows_tmp := upload_table_info_.cnt_rows_tmp;
        end if;
      end if;
    end;
  elsif(upload_table_info_.rep_up_mode_current = const.REP_UP_M_STATUS) then
    execute immediate SQL_CLEAN_TMP_TABLE;
    execute immediate upload_table_info_.sql_pop_tmp_rep_up_status
      using upload_table_info_.dbscn;
    l_cnt_rows_tmp := sql%rowcount;
  elsif(upload_table_info_.rep_up_mode_current = const.REP_UP_M_STATUS_PRT) then
    execute immediate SQL_CLEAN_TMP_TABLE;
    execute immediate upload_table_info_.sql_pop_tmp_rep_up_status_prt
      using upload_table_info_.dbscn, upload_table_info_.portion_size_actual;
    l_cnt_rows_tmp := sql%rowcount;
  end if;

  -- без подтверждения транзакции функция update_table_rep_up_status не найдет строки в temporary_table,
  --   при этом коммит в целом не дает побочных эффектов на репликацию таблицы, так как строки в temporary_table
  --   сохраняются до конца сессии, независимо от выражений управляющих транзакциями, а при каждом вызове функции
  --   populate_tmp_buf_table очищает таблицу temporary_table
  -- кроме того, подтверждение транзакции необходимо, если при вставке в временную таблицу используется
  --   хинт append (используется по умолчанию)
  commit;
  return coalesce(l_cnt_rows_tmp, 0);
exception when others then
  l_log.l_acronym := 'REPLICATOR';
  l_log.l_logger_name := 'REPLICATOR.POPULATE_TMP_BUF_TABLE';
  l_log.error(message_ => error.get_error_info());
  raise;
end populate_tmp_buf_table;

/**
 * Проверяет допустимость использования режимов работы репликатора
 *
 * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
 */
procedure check_rep_up_modes(upload_table_info_ replicator.t_upload_table_info) is
begin
  assert.assert_not_null(
    value_      => upload_table_info_.rep_up_mode_current,
    value_name_ => 'rep_up_mode_current'
  );
  assert.assert_in_set(
    value_ => upload_table_info_.rep_up_mode_current,
    set_ => const.REP_UP_MODES,
    value_name_ => 'rep_up_mode_current'
  );
  if (upload_table_info_.rep_up_mode_prev is not null) then
    assert.assert_in_set(
      value_ => upload_table_info_.rep_up_mode_current,
      set_ => const.REP_UP_MODES,
      value_name_ => 'rep_up_mode_current'
    );
  end if;
  if (upload_table_info_.rep_up_mode_default is not null) then
    assert.assert_in_set(
      value_ => upload_table_info_.rep_up_mode_default,
      set_ => const.REP_UP_MODES,
      value_name_ => 'rep_up_mode_current'
    );
  end if;

  assert.assert_true(
    value_ => upload_table_info_.rep_up_mode_current <> const.REP_UP_M_STATUS
      or (
        upload_table_info_.rep_up_mode_current = const.REP_UP_M_STATUS
        and
        util.int2bool(upload_table_info_.is_rep_up_status_column_exists)
      ),
    comment_ => 'В режиме репликации "по признаку репликации" реплицируемая таблица должна иметь столбец "признак репликации"'
  );

  assert.assert_false(
    value_ => (upload_table_info_.rep_up_mode_current = const.REP_UP_M_BUFFER_PRT)
      and util.int2bool(upload_table_info_.is_rep_up_status_column_exists),
    comment_ => 'В режиме репликации "с постоянной буферной таблицей" реплицируемая таблица должна не иметь столбец "признак репликации"'
  );
end check_rep_up_modes;

/**
 * Создает/изменяет и возвращает созданную/измененную информацию о репликации реплицируемой таблицы.
 * Автономная транзакция
 *
 * @param upload_table_info_ [nullable] - Информация о репликации реплицируемой таблицы
 * @param log_               [nullable] - Объект логера
 *
 * @return [not null] Измененная информация о репликации реплицируемой таблицы
 */
function initialize_upload_table_info(
  upload_table_info_ replicator.t_upload_table_info,
  log_ dblogger default null
) return replicator.t_upload_table_info is
  pragma autonomous_transaction;
  l_log dblogger := log_;
  l_upload_table_info replicator.t_upload_table_info;

  /**
   * Проверяет существование столбца-признака_репликации ("Признак репликации строки")
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] true - существует, false - не существует
   */
  function is_rep_up_status_exists(upload_table_info_ replicator.t_upload_table_info) return boolean is
    ll_column_name util.sqlstring;
  begin
    for rec in (
      select tc.column_name from all_tab_columns tc where tc.table_name = upper(upload_table_info_.loc_table_name)
      order by decode(tc.column_name, const.REP_UP_STATUS_COLUMN_NAME, 1, 2)
    ) loop
      ll_column_name := rec.column_name;
      exit;
    end loop;

    assert.assert_not_null(value_ => ll_column_name, comment_ => 'Реплицируемая таблица не найдена');
    return (ll_column_name = const.REP_UP_STATUS_COLUMN_NAME);
  end is_rep_up_status_exists;

  /**
   * Создает или получает sql оператор вставки данных в временную таблицу из реплицируемой таблицы
   *   в режиме "по scn"
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] sql оператор
   */
  function set_sql_pop_tmp_scn(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    ll_temporary_table_columns util.sqlstring;
    ll_sql_where util.sqlstring;
    ll_sql_pop_tmp_scn util.sqlstring;
  begin
    -- для корректной работы replicator.update_table_rep_up_status требуются значения столбца-признака_репликации
    if(util.int2bool(upload_table_info_.is_rep_up_status_column_exists)) then
      ll_temporary_table_columns := upload_table_info_.temporary_table_columns||', '||const.REP_UP_STATUS_COLUMN_NAME;
      ll_sql_where := 'where ${rep_up_status_column_name} = decode(${rep_up_status}, null, null, ${rep_up_status}) or dbscn > ${dbscn} ';
    else
      ll_temporary_table_columns := upload_table_info_.temporary_table_columns;
      ll_sql_where := 'where dbscn > ${dbscn}';
    end if;

    ll_sql_pop_tmp_scn :=
      sbuilder(
        'insert /*+ append */ into ${temporary_table_name} (${temporary_table_columns}) '||
        'select ${temporary_table_columns} from ${filter_view_name} ${where_sql}'
      )
        .fill(
          'temporary_table_name',    upload_table_info_.temporary_table_name,
          'temporary_table_columns', ll_temporary_table_columns,
          'filter_view_name',        upload_table_info_.filter_view_name,
          'where_sql',               ll_sql_where,
          'rep_up_status_column_name', const.REP_UP_STATUS_COLUMN_NAME,
          'rep_up_status',             const.REP_UP_STATUS_NON_REPLICATED,
          'dbscn',                   ':dbscn'
        )
        .to_string();

      assert.assert_not_null(
        value_ => ll_sql_pop_tmp_scn,
        value_name_ => 'll_sql_pop_tmp_scn',
        comment_ => 'Не установлен sql оператор вставки данных в временную таблицу из реплицируемой таблицы'
      );

      update upload_tables ut
      set ut.sql_pop_tmp_scn = ll_sql_pop_tmp_scn
      where ut.table_name = upload_table_info_.table_name;

    return ll_sql_pop_tmp_scn;
  end set_sql_pop_tmp_scn;


  /**
   * Создает или получает sql оператор вставки данных в временную таблицу из реплицируемой таблицы
   *   в режиме "по scn порциями"
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] sql оператор
   */
  function set_sql_pop_tmp_scn_prt(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    ll_temporary_table_columns util.sqlstring;
    ll_sql_where util.sqlstring;
    ll_sql_pop_tmp_scn_prt util.sqlstring;
  begin
    -- для корректной работы replicator.update_table_rep_up_status требуются значения столбца-признака_репликации
    if(util.int2bool(upload_table_info_.is_rep_up_status_column_exists)) then
      ll_temporary_table_columns := upload_table_info_.temporary_table_columns||', '||const.REP_UP_STATUS_COLUMN_NAME;
      ll_sql_where := 'where ${rep_up_status_column_name} = decode(${rep_up_status}, null, null, ${rep_up_status}) or dbscn > ${dbscn} ';
    else
      ll_temporary_table_columns := upload_table_info_.temporary_table_columns;
      ll_sql_where := 'where dbscn > ${dbscn}';
    end if;

    ll_sql_pop_tmp_scn_prt :=
      sbuilder(
        'insert /*+ append */ into ${temporary_table_name} (${temporary_table_columns}) '||
        'select * from ('||
        '  select ${temporary_table_columns} from ${filter_view_name} '||
        '  ${where_sql} '||
        ') '||
        'where rownum < ${portion_size}'
      )
        .fill(
          'temporary_table_name',    upload_table_info_.temporary_table_name,
          'temporary_table_columns', ll_temporary_table_columns,
          'filter_view_name',        upload_table_info_.filter_view_name,
          'where_sql',               ll_sql_where,
          'rep_up_status_column_name', const.REP_UP_STATUS_COLUMN_NAME,
          'rep_up_status',             const.REP_UP_STATUS_NON_REPLICATED,
          'portion_size',            ':portion_size',
          'dbscn',                   ':dbscn'
        )
        .to_string();

      assert.assert_not_null(
        value_ => ll_sql_pop_tmp_scn_prt,
        value_name_ => 'll_sql_pop_tmp_scn_prt',
        comment_ => 'Не установлен sql оператор вставки данных в временную таблицу из реплицируемой таблицы'
      );

      update upload_tables ut
      set ut.sql_pop_tmp_scn_prt = ll_sql_pop_tmp_scn_prt
      where ut.table_name = upload_table_info_.table_name;

    return ll_sql_pop_tmp_scn_prt;
  end set_sql_pop_tmp_scn_prt;


  /**
   * Создает или получает sql оператор вставки данных в временную таблицу из реплицируемой таблицы
   *   в режиме "по признаку репликации"
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] sql оператор
   */
  function set_sql_pop_tmp_rep_up_st(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    ll_temporary_table_columns util.sqlstring;
    ll_sql_where util.sqlstring;
    ll_sql_pop_tmp_rep_up_st util.sqlstring;
  begin
    -- для корректной работы replicator.update_table_rep_up_status требуются значения столбца-признака_репликации
    if(util.int2bool(upload_table_info_.is_rep_up_status_column_exists)) then
      ll_temporary_table_columns := upload_table_info_.temporary_table_columns||', '||const.REP_UP_STATUS_COLUMN_NAME;
      ll_sql_where := 'where ${rep_up_status_column_name} = decode(${rep_up_status}, null, null, ${rep_up_status}) or dbscn > ${dbscn} ';
    else
      ll_temporary_table_columns := upload_table_info_.temporary_table_columns;
      ll_sql_where := 'where dbscn > ${dbscn}';
    end if;

    ll_sql_pop_tmp_rep_up_st :=
      sbuilder(
        'insert /*+ append */ into ${temporary_table_name} (${temporary_table_columns}) '||
        'select ${temporary_table_columns} from ${filter_view_name} ${where_sql}'
      )
        .fill(
          'temporary_table_name',      upload_table_info_.temporary_table_name,
          'temporary_table_columns',   ll_temporary_table_columns,
          'filter_view_name',          upload_table_info_.filter_view_name,
          'where_sql',                 ll_sql_where,
          'rep_up_status_column_name', const.REP_UP_STATUS_COLUMN_NAME,
          'rep_up_status',             const.REP_UP_STATUS_NON_REPLICATED,
          'dbscn',                     ':dbscn'
        )
        .to_string();

      assert.assert_not_null(
        value_ => ll_sql_pop_tmp_rep_up_st,
        value_name_ => 'll_sql_pop_tmp_rep_up_st',
        comment_ => 'Не установлен sql оператор вставки данных в временную таблицу из реплицируемой таблицы'
      );

      update upload_tables ut
      set ut.sql_pop_tmp_rep_up_status = ll_sql_pop_tmp_rep_up_st
      where ut.table_name = upload_table_info_.table_name;

    return ll_sql_pop_tmp_rep_up_st;
  end set_sql_pop_tmp_rep_up_st;

 /**
   * Создает или получает sql оператор вставки данных в временную таблицу из реплицируемой таблицы
   *   в режиме "по признаку репликации порциями"
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] sql оператор
   */
  function set_sql_pop_tmp_rep_up_st_prt(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    ll_temporary_table_columns util.sqlstring;
    ll_sql_where util.sqlstring;
    ll_sql_pop_tmp_rep_up_st_prt util.sqlstring;
  begin
    -- для корректной работы replicator.update_table_rep_up_status требуются значения столбца-признака_репликации
    if(util.int2bool(upload_table_info_.is_rep_up_status_column_exists)) then
      ll_temporary_table_columns := upload_table_info_.temporary_table_columns||', '||const.REP_UP_STATUS_COLUMN_NAME;
      ll_sql_where := 'where ${rep_up_status_column_name} = decode(${rep_up_status}, null, null, ${rep_up_status}) or dbscn > ${dbscn} ';
    else
      ll_temporary_table_columns := upload_table_info_.temporary_table_columns;
      ll_sql_where := 'where dbscn > ${dbscn}';
    end if;

    ll_sql_pop_tmp_rep_up_st_prt :=
      sbuilder(
        'insert /*+ append */ into ${temporary_table_name} (${temporary_table_columns}) '||
        'select * from ('||
        '  select ${temporary_table_columns} from ${filter_view_name} '||
        '  ${where_sql} '||
        '  order by dbscn asc'||
        ') '||
        'where rownum < ${portion_size}'
      )
        .fill(
          'temporary_table_name',    upload_table_info_.temporary_table_name,
          'temporary_table_columns', ll_temporary_table_columns,
          'filter_view_name',        upload_table_info_.filter_view_name,
          'where_sql',               ll_sql_where,
          'rep_up_status_column_name', const.REP_UP_STATUS_COLUMN_NAME,
          'rep_up_status',             const.REP_UP_STATUS_NON_REPLICATED,
          'portion_size',            ':portion_size',
          'dbscn',                   ':dbscn'
        )
        .to_string();

      assert.assert_not_null(
        value_ => ll_sql_pop_tmp_rep_up_st_prt,
        value_name_ => 'll_sql_pop_tmp_rep_up_st_prt',
        comment_ => 'Не установлен sql оператор вставки данных в временную таблицу из реплицируемой таблицы'
      );

      update upload_tables ut
      set ut.sql_pop_tmp_rep_up_status_prt = ll_sql_pop_tmp_rep_up_st_prt
      where ut.table_name = upload_table_info_.table_name;

    return ll_sql_pop_tmp_rep_up_st_prt;
  end set_sql_pop_tmp_rep_up_st_prt;

  /**
   * Создает или получает sql оператор вставки данных в буферную таблицу из реплицируемой таблицы
   *   в режиме "с буферной таблицей порциями"
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] sql оператор
   */
  function set_sql_pop_buf_prt(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    ll_temporary_table_columns util.sqlstring;
    ll_sql_where util.sqlstring;
    ll_sql_pop_buf_prt util.sqlstring;
  begin
    -- для корректной работы replicator.update_table_rep_up_status требуются значения столбца-признака_репликации
    if(util.int2bool(upload_table_info_.is_rep_up_status_column_exists)) then
      ll_temporary_table_columns := upload_table_info_.temporary_table_columns||', '||const.REP_UP_STATUS_COLUMN_NAME;
      ll_sql_where := 'where ${rep_up_status_column_name} = decode(${rep_up_status}, null, null, ${rep_up_status}) or dbscn > ${dbscn} ';
    else
      ll_temporary_table_columns := upload_table_info_.temporary_table_columns;
      ll_sql_where := 'where dbscn > ${dbscn}';
    end if;

    -- Если обнаружатся проблемы с временной таблицей, использовать постоянную буферную
    ll_sql_pop_buf_prt :=
      sbuilder(
        'insert /*+ append */ into ${temporary_table_name} (${temporary_table_columns}, ${rep_up_row_num_column_name}) '||
        'select ${temporary_table_columns}, rownum from ('||
        '  select ${temporary_table_columns} from ${filter_view_name} ${where_sql})'
      )
        .fill(
          'temporary_table_name',       upload_table_info_.buffer_table_name,
          'temporary_table_columns',    ll_temporary_table_columns,
          'filter_view_name',           upload_table_info_.filter_view_name,
          'where_sql',                  ll_sql_where,
          'rep_up_row_num_column_name', const.REP_UP_ROW_NUM_COLUMN_NAME,
          'rep_up_status_column_name',  const.REP_UP_STATUS_COLUMN_NAME,
          'rep_up_status',              const.REP_UP_STATUS_NON_REPLICATED,
          'dbscn',                      ':dbscn'
        )
        .to_string();

      assert.assert_not_null(
        value_ => ll_sql_pop_buf_prt,
        value_name_ => 'll_sql_pop_buf_prt',
        comment_ => 'Не установлен sql оператор вставки данных в буферную таблицу из реплицируемой таблицы'
      );

      update upload_tables ut
      set ut.sql_pop_buf_prt = ll_sql_pop_buf_prt
      where ut.table_name = upload_table_info_.table_name;

    return ll_sql_pop_buf_prt;
  end set_sql_pop_buf_prt;

  /**
   * Создает или получает sql оператор поиска максимального значения scn строк, загруженных в временную таблицу
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] Максимальное значение scn
   */
  function set_sql_get_max_scn_tmp_tbl(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    ll_sql_get_max_scn_tmp_tbl util.sqlstring;
  begin
    ll_sql_get_max_scn_tmp_tbl := 'select max(dbscn) from '||upload_table_info_.temporary_table_name;

    assert.assert_not_null(
      value_ => ll_sql_get_max_scn_tmp_tbl,
      value_name_ => 'll_sql_get_max_scn_tmp_tbl',
      comment_ => 'Не установлен sql оператор поиска максимального значения scn строк, загруженных в временную таблицу'
    );

    update upload_tables ut
    set ut.sql_get_max_scn_tmp_tbl = ll_sql_get_max_scn_tmp_tbl
    where ut.table_name = upload_table_info_.table_name;

    return ll_sql_get_max_scn_tmp_tbl;
  end set_sql_get_max_scn_tmp_tbl;

  /**
   * Создает или получает sql оператор поиска минимального значения scn тривиально обновленных нереплицированных
   *   (не вошедших в порцию) записей в реплицируемой таблице в режиме "по scn порциями".
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] Минимальное значение scn
   */
  function set_sql_get_min_scn_prt(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    ll_sql_get_min_scn_prt util.sqlstring;
  begin
    ll_sql_get_min_scn_prt := 'select min(dbscn) from '||upload_table_info_.loc_table_name;

    assert.assert_not_null(
      value_ => ll_sql_get_min_scn_prt,
      value_name_ => 'll_sql_get_min_scn_prt',
      comment_ => 'Не установлен sql оператор поиска минимального значения scn строк в реплицируемой таблице'
    );

    update upload_tables ut
    set ut.sql_get_min_scn_prt = ll_sql_get_min_scn_prt
    where ut.table_name = upload_table_info_.table_name;

    return ll_sql_get_min_scn_prt;
  end set_sql_get_min_scn_prt;

  /**
   * Создает или получает sql оператор поиска максимального значения scn строк, загруженных в буферную таблицу
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] Максимальное значение scn
   */
  function set_sql_get_max_scn_buf_tbl(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    ll_sql_get_max_scn_buf_tbl util.sqlstring;
  begin
    -- Если обнаружатся проблемы с временной таблицей, использовать постоянную буферную
    ll_sql_get_max_scn_buf_tbl := 'select max(dbscn) from '||upload_table_info_.buffer_table_name;

    assert.assert_not_null(
      value_ => ll_sql_get_max_scn_buf_tbl,
      value_name_ => 'll_sql_get_max_scn_buf_tbl',
      comment_ => 'Не установлен sql оператор поиска максимального значения scn строк, загруженных в буферную таблицу'
    );

    update upload_tables ut
    set ut.sql_get_max_scn_buf_tbl = ll_sql_get_max_scn_buf_tbl
    where ut.table_name = upload_table_info_.table_name;

    return ll_sql_get_max_scn_buf_tbl;
  end set_sql_get_max_scn_buf_tbl;

  /**
   * Создает или получает sql оператор поиска максимального значения scn строк, загруженных в временную таблицу
   *   для режима репликатора "по признаку репликации" или "по признаку репликации порциями"
   *   Учитывает случаи, когда значения первичного ключа меняется в процессе репликации, например org_account,
   *     upload_tables.pk_column_name_changed хранит наименование столбца, где храниться старое значение
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] Максимальное значение scn
   */
  function set_sql_get_max_scn_rep_up_st(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    -- автономная транзакция не требуется, т.к. родительская транзакция знает об изменениях инициированной ею автономной транзакции
    SQL_SELECT_REP_MAX constant util.sqlstring :=
      'select min(src.ora_rowscn) rowscn from ${loc_table_name} src '||
      'where '||
         -- в случае если менялись режимы работы репликатора, например с "по признаку репликации" на "по scn", и до
         --   момента выполнения SQL_UPD_PATTERN были обновлены/вставлены строки без признака репликации (признак
         --   репликации имеет значение "не реплицирована"), то на следующей итерации такие строки должны быть учтены,
         --   поэтому производит поиск строк, где scn больше upload_table_info_.dbscn. В эту же категорию попадут строки
         --   соответствующие строкам временной таблицы, но которые могли быть обновлены (увеличится их scn) между
         --   commit'а после выполнения SQL_UPD_PATTERN и моментом вызова get_rep_rows_max_scn.
         --   В таком случае на следующей итерации репликации во временную таблицу будут копированы строки, у которых
         --   на предыдущей итерации признак имел значение "не реплицирована"
      '  src.ora_rowscn > ${dbscn}'||
         --   при этом не должны учитываться строки scn, которых больше scn реплицированных строк текущей итерации репликации
      '  and src.ora_rowscn <= ('||
      '    select max(ora_rowscn) rowscn from ${loc_table_name} t '||
      '    where exists ('||
      '      select null from ${temporary_table_name} tmp '||
      '      where tmp.${pk_column_name} = '||
      '        ?{pk_column_name_changed} t.${pk_column_name} {:} t.${pk_column_name_changed} {pk_column_name_changed}?'||
      '    )'||
      '    and ${rep_up_status_column_name} '||
      '      ?{rep_up_status_column_name} is null {:} = ${rep_up_status_replicated} {rep_up_status_column_name}?'||
      ')';
    ll_sql_get_max_scn_rep_up_st util.sqlstring;
  begin
    ll_sql_get_max_scn_rep_up_st :=
      sbuilder(SQL_SELECT_REP_MAX)
        .fillif(
          'pk_column_name_changed',
          upload_table_info_.pk_column_name = upload_table_info_.pk_column_name_changed
        )
        .fillif('rep_up_status_column_name', const.REP_UP_STATUS_REPLICATED is null)
        .fill(
          'loc_table_name',            upload_table_info_.loc_table_name,
          'temporary_table_name',      upload_table_info_.temporary_table_name,
          'pk_column_name',            upload_table_info_.pk_column_name,
          'pk_column_name_changed',    upload_table_info_.pk_column_name_changed,
          'rep_up_status_column_name', const.REP_UP_STATUS_COLUMN_NAME,
          'rep_up_status_replicated',  const.REP_UP_STATUS_REPLICATED,
          'dbscn',                     ':dbscn'
        )
        .to_string();

    assert.assert_not_null(
      value_ => ll_sql_get_max_scn_rep_up_st,
      value_name_ => 'll_sql_get_max_scn_rep_up_st',
      comment_ => 'Не установлен sql оператор поиска максимального значения scn строк, загруженных в временную '||
        'таблицу для режима репликатора "по признаку репликации" или "по признаку репликации порциями"'
    );

    update upload_tables ut
    set ut.sql_get_max_scn_rep_up_status = ll_sql_get_max_scn_rep_up_st
    where ut.table_name = upload_table_info_.table_name;

    return ll_sql_get_max_scn_rep_up_st;
  end set_sql_get_max_scn_rep_up_st;

  /**
   * Создает или получает sql оператор изменения значения столбца-признака_репликации указанной таблицы
   *   (если у таблицы такой признак существует)
   *   Учитывает случаи, когда значения первичного ключа меняется в процессе репликации, например org_account,
   *     upload_tables.pk_column_name_changed хранит наименование столбца, где храниться старое значение
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] sql оператор
   */
  function set_sql_upd_rep_up_status(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    SQL_UPD_PATTERN constant util.sqlstring :=
      'update ${loc_table_name} t '||
      'set t.rep_up_status = decode(${rep_up_status}, null, null, ${rep_up_status}) '||
      'where '||
         -- не производить тривиальные обновления строк, в противном случае их scn увеличится
      '  coalesce(t.rep_up_status, ${null_number}) not in ( '||
      '    coalesce(${rep_up_status}, ${null_number}), coalesce(${rep_up_status_dont_count}, ${null_number})'||
      '  ) '||
      '  and exists ('||
      '      select null from ${temporary_table_name} tmp '||
      '      where tmp.${pk_column_name} = '||
               -- для случая изменения значений первичного ключа в процессе репликации
      '        ?{pk_column_name_changed} t.${pk_column_name} {:} t.${pk_column_name_changed} {pk_column_name_changed}?'||
      '  )';
    ll_sql_upd_rep_up_status util.sqlstring;
  begin
    ll_sql_upd_rep_up_status :=
      sbuilder(SQL_UPD_PATTERN)
        .fillif(
          'pk_column_name_changed',
          upload_table_info_.pk_column_name = upload_table_info_.pk_column_name_changed
        )
        .fill(
          'loc_table_name',               upload_table_info_.loc_table_name,
          'null_number',                  const.NULL_NUMBER,
          'rep_up_status',                ':rep_up_status',
          'rep_up_status_dont_count',     const.REP_UP_STATUS_DONT_COUNT,
          'temporary_table_name',         upload_table_info_.temporary_table_name,
          'pk_column_name',               upload_table_info_.pk_column_name,
          'pk_column_name_changed',       upload_table_info_.pk_column_name_changed
        )
        .to_string();

    assert.assert_not_null(
      value_ => ll_sql_upd_rep_up_status,
      value_name_ => 'll_sql_upd_rep_up_status',
      comment_ => 'Не установлен sql оператор изменения значения столбца-признака_репликации указанной таблицы'
    );

    update upload_tables ut
    set ut.sql_upd_rep_up_status = ll_sql_upd_rep_up_status
    where ut.table_name = upload_table_info_.table_name;

    return ll_sql_upd_rep_up_status;
  end set_sql_upd_rep_up_status;

  /**
   * Создает или получает sql оператор тривиального обновления (увеличения scn) записей в реплицируемой таблице
   *   в режиме "по scn порциями"
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] sql оператор
   */
  function set_sql_upd_get_loc_table_scn(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    ll_sql_upd_get_loc_table_scn util.sqlstring;
  begin
    ll_sql_upd_get_loc_table_scn :=
      sbuilder(
        'update ${loc_table_name} t '||
        'set t.${column_name} = t.${column_name} '||
        'where not exists ('||
        '  select null from ${temporary_table_name} tmp '||
        '  where tmp.${pk_column_name} = '||
        '        ?{pk_column_name_changed} t.${pk_column_name} {:} t.${pk_column_name_changed} {pk_column_name_changed}?'||
        '  )'
      )
        .fillif(
          'pk_column_name_changed',
          upload_table_info_.pk_column_name = upload_table_info_.pk_column_name_changed
        )
        .fill(
          'loc_table_name',         upload_table_info_.loc_table_name,
          'column_name',            upload_table_info_.trivia_upd_column_name,
          'temporary_table_name',   upload_table_info_.temporary_table_name,
          'pk_column_name',         upload_table_info_.pk_column_name,
          'pk_column_name_changed', upload_table_info_.pk_column_name_changed
        )
        .to_string();

    assert.assert_not_null(
      value_ => ll_sql_upd_get_loc_table_scn,
      value_name_ => 'll_sql_upd_get_loc_table_scn',
      comment_ => ''
    );

    update upload_tables ut
    set ut.sql_upd_get_loc_table_scn = ll_sql_upd_get_loc_table_scn
    where ut.table_name = upload_table_info_.table_name;

    return ll_sql_upd_get_loc_table_scn;
  end set_sql_upd_get_loc_table_scn;

  /**
   * Создает или получает sql оператор получения количество строк со статусом "не реплицирована" во временной таблице,
   *   (если у таблицы такой признак существует)
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] sql оператор
   */
  function set_sql_cnt_non_rep_rows_tmp_t(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    SQL_SELECT_PATTERN constant util.sqlstring :=
      'select count(*) from ${temporary_table_name} '||
      'where ${rep_up_status_column_name} ?{rep_up_status} is null {:} = ${rep_up_status_non_replicated} {rep_up_status}?';
    ll_sql_cnt_non_rep_rows_tmp_t util.sqlstring;
  begin
    ll_sql_cnt_non_rep_rows_tmp_t :=
      sbuilder(SQL_SELECT_PATTERN)
        .fillif('rep_up_status', const.REP_UP_STATUS_NON_REPLICATED is null)
        .fill(
          'temporary_table_name',         upload_table_info_.temporary_table_name,
          'rep_up_status_column_name',    const.REP_UP_STATUS_COLUMN_NAME,
          'rep_up_status_non_replicated', const.REP_UP_STATUS_NON_REPLICATED
        )
        .to_string();

    assert.assert_not_null(
      value_ => ll_sql_cnt_non_rep_rows_tmp_t,
      value_name_ => 'll_sql_cnt_non_rep_rows_tmp_t',
      comment_ => 'Не установлен sql оператор получения количество строк со статусом "не реплицирована" во временной таблице'
    );

    update upload_tables ut
    set ut.sql_cnt_non_rep_rows_tmp_tbl = ll_sql_cnt_non_rep_rows_tmp_t
    where ut.table_name = upload_table_info_.table_name;

    return ll_sql_cnt_non_rep_rows_tmp_t;
  end set_sql_cnt_non_rep_rows_tmp_t;

  /**
   * Создает или получает sql оператор передачи данных из локальной временной таблицы в глобальную временную таблицу
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] sql оператор
   */
  function set_sql_transfer_tmp_tbl(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    ll_sql_transfer_tmp_tbl util.sqlstring;
  begin
    ll_sql_transfer_tmp_tbl :=
      'insert into '||upload_table_info_.temporary_table_name||'@org ('||upload_table_info_.temporary_table_columns||') '||
      'select '||upload_table_info_.temporary_table_columns||' from '||upload_table_info_.temporary_table_name;

    assert.assert_not_null(
      value_ => ll_sql_transfer_tmp_tbl,
      value_name_ => 'll_sql_transfer_tmp_tbl',
      comment_ => ''
    );

    update upload_tables ut
    set ut.sql_transfer_tmp_tbl = ll_sql_transfer_tmp_tbl
    where ut.table_name = upload_table_info_.table_name;

    return ll_sql_transfer_tmp_tbl;
  end set_sql_transfer_tmp_tbl;

  /**
   * Создает или получает sql оператор передачи данных из буферной таблицы в глобальную временную таблицу
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] sql оператор
   */
  function set_sql_transfer_buf_tbl(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    ll_sql_transfer_buf_tbl util.sqlstring;
  begin
      ll_sql_transfer_buf_tbl :=
        sbuilder(
          'insert into '||upload_table_info_.temporary_table_name||'@org ('||upload_table_info_.temporary_table_columns||') '||
          'select ${temporary_table_columns} from ${temporary_table_name} '||
          'where ${rep_up_row_num_column_name} between :rownum_from and :rownum_to'
        )
          .fill(
            'temporary_table_name',       upload_table_info_.buffer_table_name,
            'temporary_table_columns',    upload_table_info_.temporary_table_columns,
            'rep_up_row_num_column_name', const.REP_UP_ROW_NUM_COLUMN_NAME
          )
          .to_string();

    assert.assert_not_null(
      value_ => ll_sql_transfer_buf_tbl,
      value_name_ => 'll_sql_transfer_buf_tbl',
      comment_ => ''
    );

    update upload_tables ut
    set ut.sql_transfer_buf_tbl = ll_sql_transfer_buf_tbl
    where ut.table_name = upload_table_info_.table_name;

    return ll_sql_transfer_buf_tbl;
  end set_sql_transfer_buf_tbl;

  /**
   * Создает или получает sql оператор проверки буферной таблицы на наличие по крайней мере одной записи
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] sql оператор
   */
  function set_sql_is_not_empty_buf_tbl(upload_table_info_ replicator.t_upload_table_info) return util.sqlstring is
    ll_sql_is_not_empty_buf_tbl util.sqlstring;
  begin
    ll_sql_is_not_empty_buf_tbl := 'select count(*) from '||upload_table_info_.buffer_table_name||' where rownum = 1';

    assert.assert_not_null(
      value_ => ll_sql_is_not_empty_buf_tbl,
      value_name_ => 'll_sql_is_not_empty_buf_tbl',
      comment_ => ''
    );

    update upload_tables ut
    set ut.sql_is_not_empty_buf_tbl = ll_sql_is_not_empty_buf_tbl
    where ut.table_name = upload_table_info_.table_name;

    return ll_sql_is_not_empty_buf_tbl;
  end set_sql_is_not_empty_buf_tbl;

  /**
   * Проверяет, изменяет информацию о структурах, участвующих в репликации реплицируемой таблицы
   *
   * @param upload_table_info_          [not null] - Информация о репликации реплицируемой таблицы
   * @param rewrite_sql_and_structures_ [not null] - Перезаписать информацию о структурах данными из ГБД таблицы
   *                                                   main_upload_tables_setup: true - да, false - нет
   *
   * @return [not null] информация о репликации реплицируемой таблицы после проверки/изменения информации о структурах,
   *                      участвующих в репликации реплицируемой таблицы
   */
  function set_sructures(
    upload_table_info_ replicator.t_upload_table_info,
    rewrite_sql_and_structures_ boolean
  ) return replicator.t_upload_table_info is
    ll_upload_table_info replicator.t_upload_table_info := upload_table_info_;
    ll_pk_column_name_new           upload_tables.pk_column_name%type;
    ll_filter_view_name_new         upload_tables.filter_view_name%type;
    ll_trivia_upd_column_name_new   upload_tables.trivia_upd_column_name%type;
    ll_temporary_table_name_new     upload_tables.temporary_table_name%type;
    ll_temporary_table_columns_new  upload_tables.temporary_table_columns%type;
    ll_buffer_table_name_new        upload_tables.buffer_table_name%type;
    ll_is_rep_up_st_clmn_exists     integer;
  begin
    ll_pk_column_name_new := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.pk_column_name,
      coalesce(
        replicator.get_pk_column_name(loc_table_name_ => upload_table_info_.loc_table_name),
        upload_table_info_.pk_column_name
      )
    );
    ll_filter_view_name_new := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.filter_view_name,
      replicator.get_filter_view_name(table_name_ => upload_table_info_.table_name)
    );
    ll_trivia_upd_column_name_new := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.trivia_upd_column_name,
      replicator.get_random_loc_tbl_column_name(table_name_ => upload_table_info_.loc_table_name)
    );
    ll_temporary_table_name_new := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.temporary_table_name,
      replicator.get_temporary_table_name(table_name_ => upload_table_info_.table_name)
    );
    ll_temporary_table_columns_new := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.temporary_table_columns,
      replicator.get_temporary_table_columns(temporary_table_name_ => ll_temporary_table_name_new)
    );
    ll_buffer_table_name_new := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.buffer_table_name,
      replicator.get_buffer_table_name(table_name_ => upload_table_info_.table_name)
    );
    ll_is_rep_up_st_clmn_exists := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.is_rep_up_status_column_exists,
      util.ternop(
        replicator.initialize_upload_table_info.is_rep_up_status_exists(upload_table_info_ => upload_table_info_), 1, 0
      )
    );

    -- TO-DO: добавить проверки наменования временной/буферной и реплицируемой таблиц

    assert.assert_false(
      value_ => (
        ll_temporary_table_name_new = upload_table_info_.loc_table_name
        or ll_buffer_table_name_new = upload_table_info_.loc_table_name
      ),
      comment_ => 'Наименования временной и/или буферной таблицы репликации не могут совпадат с '||
        'наименованием таблицы репликации'
    );

    assert.assert_not_null(
      value_ => upload_table_info_.pk_column_name_changed,
      value_name_ => 'pk_column_name_changed',
      comment_ => 'Не переопределено наименование столбца старого (до репликации) значения первичного ключа'
    );

    assert.assert_true(
      value_ => (
        ll_trivia_upd_column_name_new <> upload_table_info_.pk_column_name_changed
      ),
      comment_ => 'Наименование столбца для тривиального обновления не должно совпадать с наименованием столбца старого '||
        '(до репликации) значения первичного ключа и/или наименованием первичного ключа'
    );

    update upload_tables ut
    set
      ut.pk_column_name                 = ll_pk_column_name_new,
      ut.filter_view_name               = ll_filter_view_name_new,
      ut.trivia_upd_column_name         = ll_trivia_upd_column_name_new,
      ut.temporary_table_name           = ll_temporary_table_name_new,
      ut.temporary_table_columns        = ll_temporary_table_columns_new,
      ut.buffer_table_name              = ll_buffer_table_name_new,
      ut.is_rep_up_status_column_exists = ll_is_rep_up_st_clmn_exists
    where ut.table_name = ll_upload_table_info.table_name;

    ll_upload_table_info.pk_column_name                 := ll_pk_column_name_new;
    ll_upload_table_info.filter_view_name               := ll_filter_view_name_new;
    ll_upload_table_info.trivia_upd_column_name         := ll_trivia_upd_column_name_new;
    ll_upload_table_info.temporary_table_name           := ll_temporary_table_name_new;
    ll_upload_table_info.temporary_table_columns        := ll_temporary_table_columns_new;
    ll_upload_table_info.buffer_table_name              := ll_buffer_table_name_new;
    ll_upload_table_info.is_rep_up_status_column_exists := ll_is_rep_up_st_clmn_exists;

    return ll_upload_table_info;
  end set_sructures;

  /**
   * Создает/проверяет sql операторы, участвующие в репликации реплицируемой таблицы
   *
   * @param upload_table_info_          [not null] - Информация о репликации реплицируемой таблицы
   * @param rewrite_sql_and_structures_ [not null] - Перезаписать sql операторы данными из ГБД таблицы
   *                                                   main_upload_tables_setup: true - да, false - нет
   *
   * @return [not null] информация о репликации реплицируемой таблицы после создания/проверки sql операторов,
   *                      участвующих в репликации реплицируемой таблицы
   */
  function set_sql_clauses(
    upload_table_info_ replicator.t_upload_table_info,
    rewrite_sql_and_structures_ boolean
  ) return replicator.t_upload_table_info is
    ll_upload_table_info replicator.t_upload_table_info := upload_table_info_;
  begin
    ll_upload_table_info.sql_pop_tmp_scn := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_pop_tmp_scn,
      replicator.initialize_upload_table_info.set_sql_pop_tmp_scn(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_pop_tmp_scn_prt := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_pop_tmp_scn_prt,
      replicator.initialize_upload_table_info.set_sql_pop_tmp_scn_prt(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_pop_tmp_rep_up_status := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_pop_tmp_rep_up_status,
      replicator.initialize_upload_table_info.set_sql_pop_tmp_rep_up_st(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_pop_tmp_rep_up_status_prt := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_pop_tmp_rep_up_status_prt,
      replicator.initialize_upload_table_info.set_sql_pop_tmp_rep_up_st_prt(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_pop_buf_prt := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_pop_buf_prt,
      replicator.initialize_upload_table_info.set_sql_pop_buf_prt(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_transfer_tmp_tbl := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_transfer_tmp_tbl,
      replicator.initialize_upload_table_info.set_sql_transfer_tmp_tbl(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_transfer_buf_tbl := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_transfer_buf_tbl,
      replicator.initialize_upload_table_info.set_sql_transfer_buf_tbl(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_upd_get_loc_table_scn := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_upd_get_loc_table_scn,
      replicator.initialize_upload_table_info.set_sql_upd_get_loc_table_scn(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_upd_rep_up_status := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_upd_rep_up_status,
      replicator.initialize_upload_table_info.set_sql_upd_rep_up_status(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_get_max_scn_tmp_tbl := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_get_max_scn_tmp_tbl,
      replicator.initialize_upload_table_info.set_sql_get_max_scn_tmp_tbl(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_get_min_scn_prt := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_get_min_scn_prt,
      replicator.initialize_upload_table_info.set_sql_get_min_scn_prt(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_get_max_scn_rep_up_status := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_get_max_scn_rep_up_status,
      replicator.initialize_upload_table_info.set_sql_get_max_scn_rep_up_st(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_get_max_scn_buf_tbl := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_get_max_scn_buf_tbl,
      replicator.initialize_upload_table_info.set_sql_get_max_scn_buf_tbl(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_cnt_non_rep_rows_tmp_tbl := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_cnt_non_rep_rows_tmp_tbl,
      replicator.initialize_upload_table_info.set_sql_cnt_non_rep_rows_tmp_t(upload_table_info_ => upload_table_info_)
    );

    ll_upload_table_info.sql_is_not_empty_buf_tbl := util.ternop(
      rewrite_sql_and_structures_,
      upload_table_info_.sql_is_not_empty_buf_tbl,
      replicator.initialize_upload_table_info.set_sql_is_not_empty_buf_tbl(upload_table_info_ => upload_table_info_)
    );

    return ll_upload_table_info;
  end set_sql_clauses;

  /**
   * Устанавливает режимы репликации реплицируемой таблицы
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] информация о репликации реплицируемой таблицы после установки режимов репликации
   */
  function set_rep_up_modes(upload_table_info_ replicator.t_upload_table_info) return replicator.t_upload_table_info is
    ll_upload_table_info replicator.t_upload_table_info := upload_table_info_;
  begin

    if (ll_upload_table_info.rep_up_mode_current is null) then
      ll_upload_table_info.rep_up_mode_current := ll_upload_table_info.rep_up_mode_default;
      ll_upload_table_info.rep_up_mode_prev    := ll_upload_table_info.rep_up_mode_default;
      ll_upload_table_info.rep_up_mode_next    := ll_upload_table_info.rep_up_mode_default;
    end if;

    if (upload_table_info_.portion_size_actual is null or upload_table_info_.portion_size_actual = 0) then
      ll_upload_table_info.portion_size_actual := upload_table_info_.portion_size_default;
    end if;

    replicator.check_rep_up_modes(upload_table_info_ => ll_upload_table_info);

    return ll_upload_table_info;
  end set_rep_up_modes;

begin
  if (l_log is null) then
    l_log := dblog_util.get_dblogger(
      acronym_   => 'REPLICATOR',
      fcbuilder_ => fcbuilder('UPDATE_UPLOAD_TABLE_INFO')
        .param('table_name_', upload_table_info_.table_name)
    );
  else
    l_log.l_acronym := 'REPLICATOR';
    l_log.l_logger_name := 'INITIALIZE_UPLOAD_TABLE_INFO';
  end if;

  savepoint sp_init_upload_table_info;

  l_upload_table_info :=
    replicator.initialize_upload_table_info.set_sructures(
      upload_table_info_ => upload_table_info_,
      rewrite_sql_and_structures_ => util.int2bool(upload_table_info_.rewrite_sql_and_structures)
    );

  l_upload_table_info :=
    replicator.initialize_upload_table_info.set_sql_clauses(
      upload_table_info_ => l_upload_table_info,
      rewrite_sql_and_structures_ => util.int2bool(l_upload_table_info.rewrite_sql_and_structures)
    );

  l_upload_table_info :=
    replicator.initialize_upload_table_info.set_rep_up_modes(upload_table_info_ => l_upload_table_info);

  assert.assert_false(
    value_ => (
      l_upload_table_info.pk_column_name = replicator.PK_SIMPLE_COLUMN_NAME_UNKNOWN
      and l_upload_table_info.rep_up_mode_current <> const.REP_UP_M_SCN
      and l_upload_table_info.rep_up_mode_current is not null
    ),
    comment_ => 'Наименование столбца первичного ключа может быть неопределено (в случае составного первичного ключа '||
      'или отсутствии первичного ключа) только в режиме репликации "по scn"'
  );

  commit;
  return l_upload_table_info;
exception when others then
  l_log.l_acronym := 'REPLICATOR';
  l_log.l_logger_name := 'INITIALIZE_UPLOAD_TABLE_INFO';
  l_log.error(message_ => error.get_error_info());
  rollback to sp_init_upload_table_info;
  raise;
end initialize_upload_table_info;

/**
 * Возвращает информацию о репликации реплицируемой таблицы
 *
 * @param table_name_  [not null] - Наименование реплицируемой таблицы
 * @param log_         [nullable] - Объект логера
 *
 * @throws ORA-20718 - Ошибка репликации. Не найдена информация о репликации реплицируемой таблицы
 *
 * @return [not null] информация о репликации реплицируемой таблицы
 */
function get_upload_table_info(
  table_name_   varchar2,
  log_ dblogger default null
) return replicator.t_upload_table_info is
  l_log dblogger := log_;
  l_upload_table_info replicator.t_upload_table_info;
begin
  if (l_log is null) then
    l_log := dblog_util.get_dblogger(
      acronym_   => 'REPLICATOR',
      fcbuilder_ => fcbuilder('GET_UPLOAD_TABLE_INFO')
        .param('table_name_', table_name_)
    );
  else
    l_log.l_acronym := 'REPLICATOR';
    l_log.l_logger_name := 'SET_UPLOAD_TABLE_INFO';
  end if;

  begin
    select ut.* into l_upload_table_info from upload_tables ut where ut.table_name = table_name_;
  exception when no_data_found then
    l_log.error(message_ => error.get_error_info());
    error.raise_error(
      errcode_ => -20718,
      errmessage_ => 'Ошибка репликации. Не найдена информация о репликации реплицируемой таблицы'
    );
  end;
  return l_upload_table_info;
exception when others then
  l_log.l_acronym := 'REPLICATOR';
  l_log.l_logger_name := 'GET_UPLOAD_TABLE_INFO';
  l_log.error(message_ => error.get_error_info());
  raise;
end get_upload_table_info;

/**
 * Автоматически настраивает (изменяет) и возвращает информацию о репликации реплицируемой таблицы согласно режиму
 *   работы локальной автонастройки репликации upload_tables.tune_mode_flag
 *
 * @param upload_table_info_ [not null] - Наименование реплицируемой таблицы
 * @param tune_stage_        [not null] - Этапы итерации:
 *                                          0 (replicator.TUNE_ON_STAGE_BEGIN) - вызывается функцией set_upload_table_info
 *                                          1 (replicator.TUNE_ON_STAGE_END) - вызывается процедурой finalize_upload_table
 * @param log_               [nullable] - Объект логера
 *
 * @return [not null] информация о репликации реплицируемой таблицы
 */
function tune_upload_table_info(
  upload_table_info_ replicator.t_upload_table_info,
  tune_stage_ integer,
  log_ dblogger default null
) return replicator.t_upload_table_info is
  PORTION_ONERR_LNK_FACTOR   constant integer := 1/3;
  PORTION_ONTIME_LIMIT_UP    constant integer := 4/3;
  PORTION_ONTIME_FACTOR_UP   constant integer := 1/10;
  PORTION_ONTIME_LIMIT_DOWN  constant integer := 2;
  PORTION_ONTIME_FACTOR_DOWN constant integer := 1/3;
  PORTION_SIZE_MAX_FACTOR    constant integer := 10;
  PORTION_SIZE_MIN_FACTOR    constant integer := 1/10;
  PORTION_SIZE_MIN           constant integer := 10;
  l_log dblogger := log_;
  l_upload_table_info_tuned replicator.t_upload_table_info := upload_table_info_;
  l_error_link boolean := false;
begin
  if (l_log is null) then
    l_log := dblog_util.get_dblogger(
      acronym_   => 'REPLICATOR',
      fcbuilder_ => fcbuilder('TUNE_UPLOAD_TABLE_INFO')
        .param('table_name', upload_table_info_.table_name)
        .param('tune_stage_', tune_stage_)
    );
  else
    l_log.l_acronym := 'REPLICATOR';
    l_log.l_logger_name := 'TUNE_UPLOAD_TABLE_INFO';
  end if;

  assert.assert_true(
    value_ =>
      bitand(
        upload_table_info_.tune_mode_flag,
          const.REP_UP_TUNE_OFF
        + const.REP_UP_TUNE_MODE_ONERR_FK
        + const.REP_UP_TUNE_MODE_ONERR_LNK
        + const.REP_UP_TUNE_MODE_ONERR_OTHERS
        + const.REP_UP_TUNE_REFRESH_ONERR_LNK
        + const.REP_UP_TUNE_PORTION_ONERR_FK
        + const.REP_UP_TUNE_PORTION_ONERR_LNK
        + const.REP_UP_TUNE_PORTION_ONTIME
      ) <> 0,
    comment_ => 'Режим работы локальной автонастройки репликации не задан или задан неверно'
  );

  -- в начале каждой итерации репликации
  if (tune_stage_ = replicator.TUNE_ON_STAGE_BEGIN) then
    -- изменить режим работы репликатора, если требуется
    if (upload_table_info_.rep_up_mode_current <> upload_table_info_.rep_up_mode_next) then
      -- не допускать изменение режима репликатора из режима "с буферной таблицей порциями", пока не реплицированы
      --   все строки в буферной таблице. Не сообщать об ошибке, завершить репликацию строк в буферной таблице в прежнем
      --   режиме, о том, что режим не был изменен наблюдателю сообщает неравенство rep_up_mode_next и rep_up_mode_current
      declare
        l_is_not_empty_buf_tbl integer;
      begin
        -- на случай, если из-за сбоев значение upload_table_info_.cnt_rows_tmp не соответствует действительности
        --   или после репликации всех строк из буферной таблицы не произвелась её очистка. Во втором случае, после смены
        --   режима на "по scn" и репликации в этом режиме новых/обновленных строк из реплицируемой таблицы с последующим
        --   изменением upload_tables.dbcsn, произойдет смена режима на "с буферной таблицей порциями", буферная таблица
        --   не заполнится новыми строками, но реплицируются оставшиеся там старые строки старыми данными и
        --   upload_tables.dbcsn примет максимальное значение scn этих "старых" строк. Поэтому не производить переключение
        --   режима с "с буферной таблицей порциями" пока не устранена указанная аномалия
        if (
          upload_table_info_.rep_up_mode_current = const.REP_UP_M_BUFFER_PRT and upload_table_info_.cnt_rows_tmp = 0
        ) then
          execute immediate upload_table_info_.sql_is_not_empty_buf_tbl into l_is_not_empty_buf_tbl;
        end if;
        if (
          not (
            upload_table_info_.rep_up_mode_current = const.REP_UP_M_BUFFER_PRT
            and (upload_table_info_.cnt_rows_tmp <> 0 or util.int2bool(l_is_not_empty_buf_tbl))
          )
        ) then
          l_upload_table_info_tuned.rep_up_mode_prev := upload_table_info_.rep_up_mode_current;
          l_upload_table_info_tuned.rep_up_mode_current :=
            coalesce(upload_table_info_.rep_up_mode_next, upload_table_info_.rep_up_mode_default);
        end if;
        -- проверить допустимость изменений. Если обнаружится ошибка, репликатор не продолжит работу в старом режиме, но
        --   выбросит исключение, чтобы не маскировать неправильные настройки, кроме того, производится проверка поддержки
        --   таблицей нового режима
        replicator.check_rep_up_modes(upload_table_info_ => l_upload_table_info_tuned);
      end;
    end if;

    if (
      upload_table_info_.rep_up_mode_current in (const.REP_UP_M_SCN_PRT, const.REP_UP_M_STATUS_PRT, const.REP_UP_M_BUFFER_PRT)
    ) then
      assert.assert_true(
      value_ => (
        l_upload_table_info_tuned.portion_size_actual > 0
        and l_upload_table_info_tuned.cnt_rows_prt_series >= 0
      ),
      comment_ => 'Действующий размер порции должен быть положительным числом и количество строк переданных в серии '||
        'должно быть неотрицательным числом'
      );
    end if;

  -- в конце каждой итерации репликации
  elsif (tune_stage_ = replicator.TUNE_ON_STAGE_END) then
    -- проверка, связана ли ошибка с распределенной транзакцией (dblink соедиенения)
    if (
      upload_table_info_.error_message is not null
      and upload_table_info_.error_cnt_consecutive > replicator.ERR_CNT_CONSECUTIVE_TUNE_LNK
      and bitand(
        upload_table_info_.tune_mode_flag,
        const.REP_UP_TUNE_MODE_ONERR_LNK + const.REP_UP_TUNE_REFRESH_ONERR_LNK + const.REP_UP_TUNE_PORTION_ONERR_LNK
      ) <> 0
    ) then
      -- вынесен в отдельный if для производительности
      if (
        regexp_instr(
          srcstr => upload_table_info_.error_message,
          pattern => (
            '('||
            error.CODE_RESOURCE_BUSY||'|'||
            error.CODE_RESOURCE_BUSY||'|'||
            error.CODE_RESOURCE_BUSY_WAIT||'|'||
            error.CODE_RESOURCE_BUSY||'|'||
            error.CODE_RESOURCE_BUSY_WAIT||'|'||
            error.CODE_TRANSACTION_ROLLED_BACK||'|'||
            error.CODE_TRANSACTION_IN_DOUBT||'|'||
            error.CODE_DISTRIBUTED_LOCK_TIMEOUT||'|'||
            error.CODE_LOCK_HELD_BY_IN_DOUBT_TR||'|'||
            error.CODE_REMOTE_DB_IN_DOUBT||'|'||
            error.CODE_TNS_CONNECTION_CLOSED||'|'||
            error.CODE_TNS_OPERATION_TIMED_OUT||'|'||
            error.CODE_TNS_CONNECTION_TIMEOUT||'|'||
            error.CODE_RESTRICTED_MODE||'|'||
            error.CODE_LOST_CONTACT||'|'||
            error.CODE_DBLINK_LOST_CONTACT||'|'||
            error.CODE_NO_LISTENER||
            ')'
          )
        ) <> 0
      ) then
        l_error_link := true;
      else
        l_error_link := false;
      end if;
    end if;

    if (upload_table_info_.tune_mode_flag = const.REP_UP_TUNE_OFF) then
      l_upload_table_info_tuned.rep_up_mode_next := upload_table_info_.rep_up_mode_default;
      l_upload_table_info_tuned.portion_size_actual := upload_table_info_.portion_size_default;
    else
      -- в случае ошибки, связанной с распределенной транзакцией
      if (l_error_link) then
        if (
          upload_table_info_.rep_up_mode_current in (const.REP_UP_M_SCN_PRT, const.REP_UP_M_STATUS_PRT, const.REP_UP_M_BUFFER_PRT)
        ) then
          -- изменить размер порции
          if (bitand(upload_table_info_.tune_mode_flag, const.REP_UP_TUNE_PORTION_ONERR_LNK) <> 0) then
            l_upload_table_info_tuned.portion_size_actual :=
              l_upload_table_info_tuned.portion_size_actual
                - l_upload_table_info_tuned.portion_size_actual * PORTION_ONERR_LNK_FACTOR;
          end if;
        else
          --изменить на режим с порциями
          if (bitand(upload_table_info_.tune_mode_flag, const.REP_UP_TUNE_MODE_ONERR_LNK) <> 0) then
            l_upload_table_info_tuned.rep_up_mode_next := const.REP_UP_M_BUFFER_PRT;
          else
            l_upload_table_info_tuned.rep_up_mode_next := upload_table_info_.rep_up_mode_default;
          end if;
        end if;
        -- изменить время последнего обновления
        if (bitand(upload_table_info_.tune_mode_flag, const.REP_UP_TUNE_REFRESH_ONERR_LNK) <> 0) then
          l_upload_table_info_tuned.refresh_dt_timeout :=
            (kernel.get_sysdate() - l_upload_table_info_tuned.refresh_dt) * const.TIME_SECONDS_IN_DAY
              + least(replicator.TIMEOUT_MAX, replicator.REFRESH_INTERVAL_FACTOR * upload_table_info_.refresh_interval);
        end if;
      else
        l_upload_table_info_tuned.rep_up_mode_next := upload_table_info_.rep_up_mode_default;
      end if;

      if (bitand(upload_table_info_.tune_mode_flag, const.REP_UP_TUNE_PORTION_ONTIME) <> 0) then
        if (
          upload_table_info_.error_message is null
          and (upload_table_info_.run_duration
            / util.ternop(
              upload_table_info_.run_avg_duration = 0,
              1,
              upload_table_info_.run_avg_duration
            ) < PORTION_ONTIME_LIMIT_UP
          )
        ) then
          l_upload_table_info_tuned.portion_size_actual :=
            least(
              l_upload_table_info_tuned.portion_size_default * PORTION_SIZE_MAX_FACTOR,
              l_upload_table_info_tuned.portion_size_actual
                + l_upload_table_info_tuned.portion_size_actual * PORTION_ONTIME_FACTOR_UP
            );
        elsif (
          upload_table_info_.error_message is null
          and (upload_table_info_.run_duration
            / util.ternop(
              upload_table_info_.run_avg_duration = 0,
              1,
              upload_table_info_.run_avg_duration
            ) > PORTION_ONTIME_LIMIT_DOWN
          )
        ) then
          l_upload_table_info_tuned.portion_size_actual :=
            l_upload_table_info_tuned.portion_size_actual
            - l_upload_table_info_tuned.portion_size_actual * PORTION_ONTIME_FACTOR_DOWN;
        end if;
        l_upload_table_info_tuned.portion_size_actual :=
          coalesce(
            least(
              l_upload_table_info_tuned.portion_size_default * PORTION_SIZE_MIN_FACTOR,
              l_upload_table_info_tuned.portion_size_actual
            )
            , PORTION_SIZE_MIN
          );
      else
        l_upload_table_info_tuned.portion_size_actual := upload_table_info_.portion_size_default;
      end if;
      if (
        bitand(
          upload_table_info_.tune_mode_flag,
          const.REP_UP_TUNE_MODE_ONERR_FK + const.REP_UP_TUNE_PORTION_ONERR_FK
        ) <> 0
      ) then
        -- TO-DO: добавить изменение режима/порции репликации "родительских таблиц"
        null;
      end if;

      l_upload_table_info_tuned.rep_up_mode_prev := upload_table_info_.rep_up_mode_current;

      l_upload_table_info_tuned.portion_size_actual :=
        util.ternop(
          coalesce(l_upload_table_info_tuned.portion_size_actual, 0) <> 0,
          l_upload_table_info_tuned.portion_size_actual,
          l_upload_table_info_tuned.portion_size_default
        );
    end if;
  else
    assert.assert_true(
      value_ =>
        tune_stage_ is not null and tune_stage_ in (replicator.TUNE_ON_STAGE_BEGIN, replicator.TUNE_ON_STAGE_END),
      comment_ => 'Этап итерации не задан или задан неверно'
    );
  end if;

  return l_upload_table_info_tuned;
exception when others then
  l_log.l_acronym := 'REPLICATOR';
  l_log.l_logger_name := 'TUNE_UPLOAD_TABLE_INFO';
  l_log.error(message_ => error.get_error_info());
  raise;
end tune_upload_table_info;

/**
 * Собирает (инициирует) и возвращает информацию о репликации реплицируемой таблицы
 *   Подтверждает изменения в таблице upload_tables, если сделаны (делает commit), через вызов функции
 *   replicator.initialize_upload_table_info
 *
 * @param table_name_  [not null] - Наименование реплицируемой таблицы
 * @param log_         [nullable] - Объект логера
 *
 * @throws ORA-20718 - Ошибка репликации. Не найдена информация о репликации реплицируемой таблицы
 *
 * @return [not null] информация о репликации реплицируемой таблицы
 */
function set_upload_table_info(
  table_name_   varchar2,
  log_ dblogger default null
) return replicator.t_upload_table_info is
  l_log dblogger := log_;
  l_upload_table_info replicator.t_upload_table_info;
begin
  if (l_log is null) then
    l_log := dblog_util.get_dblogger(
      acronym_   => 'REPLICATOR',
      fcbuilder_ => fcbuilder('SET_UPLOAD_TABLE_INFO')
        .param('table_name_', table_name_)
    );
  else
    l_log.l_acronym := 'REPLICATOR';
    l_log.l_logger_name := 'SET_UPLOAD_TABLE_INFO';
  end if;

  l_upload_table_info := replicator.get_upload_table_info(table_name_ => table_name_, log_ => l_log);

  if (
    -- если о репликации таблицы нет информации, она неполная или должна быть изменена
    l_upload_table_info.sql_pop_tmp_scn is null
    -- или требуется обновить информацию о структурах репликации и/или sql операторах
    or util.int2bool(l_upload_table_info.rewrite_sql_and_structures)
    -- или превышено максимально допустимое количество ошибок подряд
    or l_upload_table_info.error_cnt_consecutive > replicator.ERR_CNT_CONSECUTIVE_CHECKUP
    -- или превышено максимальное время простоя репликации таблицы
    or (
      l_upload_table_info.refresh_dt
        + (l_upload_table_info.refresh_interval + replicator.REFRESH_TIME_MAX_OVERDUE) * const.TIME_DAYS_IN_SECOND
      < kernel.get_sysdate()
    )
    --TO-DO: если меняется режим репликации, тоже проверять, тогда assert'ы выше и ниже можно внести под этот if
  ) then
    -- инициализировать данные о репликации таблицы, выполнив проверки
    l_upload_table_info :=
      replicator.initialize_upload_table_info(upload_table_info_ => l_upload_table_info, log_ => l_log);
  end if;

  -- произвести автонастройку информации о репликации, если допустимо и необходимо
  l_upload_table_info :=
    replicator.tune_upload_table_info(
      upload_table_info_ => l_upload_table_info,
      tune_stage_ => replicator.TUNE_ON_STAGE_BEGIN,
      log_ => l_log
    );

  return l_upload_table_info;
exception when others then
  l_log.l_acronym := 'REPLICATOR';
  l_log.l_logger_name := 'SET_UPLOAD_TABLE_INFO';
  l_log.error(message_ => error.get_error_info());
  raise;
end set_upload_table_info;

/**
 * Производит завершающие операции при репликации реплицируемой таблицы такие как, но не ограничиваясь:
 *   1. обновляет информацию о репликации таблицы, например:
 *      1.1. обновляет сообщение об ошибке (поле сообщения об ошибке примет значение null, если не задан параметр
 *           error_message_ и репликация завершилась без ошибок)
 *      1.2. обновляет scn
 *      1.3. обновялет статистические счетчикии
 *   2. производит автонастройку, согласно установленным режимам автонастройки, например:
 *      2.1. рассчитывает и устанавливает таймаут следующей итерации репликации
 *      2.2. рассчитывает и устанавливает порцию строк для следующей итерации в режимах передачи порциями
 *      2.3. меняет режимы репликации, если необходимо
 *   3. снимает блокировку репликации реплицируемой таблицы, обновляя статус итерации в автономной транзакции
 *
 * Оба или один из параметров upload_table_info_ и table_name_ должен быть не null. Предпочтительно указывать
 *   оба параметра. Параметр table_name_ обязателен в случае, если есть веротность, что данные для upload_table_info_
 *   не были скопированы из таблицы upload_tables вызовом set_upload_table_info. Параметр table_name_ обязателен при
 *   обработке ошибок в блоках exception
 *
 * Автономная транзакция, обновляет upload_tables
 *
 * @param upload_table_info_last_    [not null] - Информация о репликации реплицируемой таблицы до начала текущей итерации
 * @param upload_table_info_current_ [nullable] - Информация о репликации реплицируемой таблицы на текущий момент
 * @param table_name_                [nullable] - Наименование реплицируемой таблицы
 * @param with_error_                [nullable] - Завершить с ошибкой и добавить информацию о последнем возникшем
 *                                                  исключении из стека ошибок: true  - да, false - нет (по умолчанию)
 * @param error_message_             [nullable] - Дополнительный текст сообщения об ошибке при репликации реплицируемой таблицы.
 *                                                  Задается, если with_error_ имеет значение true.
 * @param session_uid_               [not null] - Уникальный идентификатор сессии, не связан с сессией БД
 */
procedure finalize_upload_table(
  upload_table_info_last_    replicator.t_upload_table_info,
  upload_table_info_current_ replicator.t_upload_table_info default null,
  table_name_        varchar2 default null,
  error_message_     varchar2 default null,
  with_error_        boolean default false,
  session_uid_       integer
) is
  pragma autonomous_transaction;
  l_error_info varchar2(4000);
  l_upload_table_info_next    replicator.t_upload_table_info;
  l_upload_table_info_last    replicator.t_upload_table_info;
begin
  assert.assert_true(
    value_ => upload_table_info_current_.table_name is not null or table_name_ is not null,
    comment_ => 'Оба или один из параметров upload_table_info_ и table_name_ должен быть не null'
  );

  if (with_error_) then
    l_error_info := util.prependstr(
      str_ => error.get_error_info(),
      prefix_ => error_message_,
      separator_ => util.SMBL_LINEEND,
      lengthb_ => util.VARCHAR2_SQL_MAX_LENGTH
    );
  end if;

  -- upload_table_info_last_ используется для формирования новой информации о реплицируемой таблице и в тех случаях,
  --   когда upload_table_info_current_ не была инициализирована из-за ошибки
  l_upload_table_info_last := upload_table_info_last_;
  -- upload_table_info_last_ может быть передана вызывающим, но не инициализирована из-за ошибки, тогда попытаться
  --   получить информацию еще раз прямым запросом к таблице
  if (upload_table_info_last_.table_name is null) then
    begin
      select ut.* into l_upload_table_info_last from upload_tables ut where ut.table_name = table_name_;
    exception when no_data_found then
      --l_log.error(message_ => error.get_error_info());
      error.raise_error(
        errcode_ => -20718,
        errmessage_ => 'Ошибка репликации. Не найдена информация о репликации реплицируемой таблицы'
      );
    end;
  end if;

  -- всё полезное, что было сделано до текущего момента, установка sql операторов, структур репликации,
  --   некоторых счетчиков и т. д. копируется без дополнительной обработки здесь
  l_upload_table_info_next := upload_table_info_current_;

  -- рассчитать run_duration и run_avg_duration
  if (upload_table_info_current_.run_start_datetime is not null) then
    declare
      DTS constant timestamp := systimestamp;
      TIME_MILLISECONDS_IN_SECOND constant integer := 1000;
      l_run_duration number;
      l_run_avg_duration number;
    begin
      l_run_duration :=
          const.TIME_SECONDS_IN_DAY    * (extract(day from DTS)    - extract(day    from upload_table_info_current_.run_start_datetime))
        + const.TIME_SECONDS_IN_HOUR   * (extract(hour from DTS)   - extract(hour   from upload_table_info_current_.run_start_datetime))
        + const.TIME_SECONDS_IN_MINUTE * (extract(minute from DTS) - extract(minute from upload_table_info_current_.run_start_datetime))
        + const.TIME_SECONDS_IN_SECOND  * (extract(second from DTS) - extract(second from upload_table_info_current_.run_start_datetime));
      l_run_duration := coalesce(trunc(TIME_MILLISECONDS_IN_SECOND * l_run_duration, 2), 0);

      -- не менять среднее время, если не были реплицированы строки (итерация завершилась ошибкой,
      --   нет строк для репликации и т.д.)
      if (l_error_info is null and coalesce(upload_table_info_current_.cnt_rows_replicated, 0) > 0) then
        -- (среднее_время * (всего_итераций - итерации_с_ошибкой)) + время_текущей_итерации / (всего_итераций + 1 - итерации_с_ошибкой)
        l_run_avg_duration :=
          (l_upload_table_info_last.run_avg_duration
            * (l_upload_table_info_last.run_cnt - l_upload_table_info_last.error_cnt_total) + l_run_duration
          ) /
          (l_upload_table_info_last.run_cnt + 1 - l_upload_table_info_last.error_cnt_total);
      end if;

      l_run_avg_duration := trunc(coalesce(l_run_avg_duration, l_upload_table_info_last.run_avg_duration, 0), 2);

      l_upload_table_info_next.run_duration := l_run_duration;
      l_upload_table_info_next.run_avg_duration := l_run_avg_duration;
    end;
  else
    l_upload_table_info_next.run_duration := l_upload_table_info_last.run_duration;
    l_upload_table_info_next.run_avg_duration := l_upload_table_info_last.run_avg_duration;
  end if;

  -- рассчитать вермя следующей итерации, если необходимо учесть таймаут на количество последовательных ошибок
  if (
    l_error_info is not null
    and l_error_info = upload_table_info_current_.error_message
    and l_upload_table_info_last.error_cnt_consecutive > replicator.ERR_CNT_CONSECUTIVE_THRESHOLD
  ) then
    l_upload_table_info_next.refresh_dt :=
      coalesce(upload_table_info_current_.refresh_dt, l_upload_table_info_last.refresh_dt);
    l_upload_table_info_next.refresh_dt_timeout :=
      (kernel.get_sysdate() - coalesce(upload_table_info_current_.refresh_dt, l_upload_table_info_last.refresh_dt))
        * const.TIME_SECONDS_IN_DAY
        + least(replicator.TIMEOUT_MAX, replicator.REFRESH_INTERVAL_FACTOR
          * coalesce(upload_table_info_current_.refresh_interval, l_upload_table_info_last.refresh_interval));
  else
    l_upload_table_info_next.refresh_dt :=
      coalesce(upload_table_info_current_.refresh_dt, l_upload_table_info_last.refresh_dt);
    l_upload_table_info_next.refresh_dt_timeout := 0;
  end if;
  l_upload_table_info_next.refresh_dt_timeout := coalesce(l_upload_table_info_next.refresh_dt_timeout, 0);

  l_upload_table_info_next.merge_dt := coalesce(upload_table_info_current_.merge_dt, l_upload_table_info_last.merge_dt);

  l_upload_table_info_next.dbscn := coalesce(upload_table_info_current_.dbscn, l_upload_table_info_last.dbscn);

  -- информация о репликации (upload_tables) в части update_dict_by_main_fk обновялется процедурой upload_parent_table
  --   в случае ошибки ссылочной целостности.
  --   Заналить поле, если ошибки нет
  l_upload_table_info_next.update_dict_by_main_fk :=
    util.ternop(
      l_error_info is not null,
      l_upload_table_info_last.update_dict_by_main_fk,
      null
    );

  l_upload_table_info_next.run_cnt := l_upload_table_info_last.run_cnt + 1;

  l_upload_table_info_next.cnt_rows_replicated :=
    util.ternop(
      -- даже в случае ошибки после передачи в ГБД и коммита, должны быть записаны значения на начало итерации
      l_error_info is not null,
      l_upload_table_info_last.cnt_rows_replicated,
      coalesce(
        l_upload_table_info_last.cnt_rows_replicated + upload_table_info_current_.cnt_rows_replicated,
        l_upload_table_info_last.cnt_rows_replicated
      )
    );

  l_upload_table_info_next.cnt_rows_tmp :=
    coalesce(upload_table_info_current_.cnt_rows_tmp, l_upload_table_info_last.cnt_rows_tmp);

  l_upload_table_info_next.cnt_rows_prt_series :=
    coalesce(upload_table_info_current_.cnt_rows_prt_series, l_upload_table_info_last.cnt_rows_prt_series);

  l_upload_table_info_next.error_message := l_error_info;

  l_upload_table_info_next.error_cnt_total :=
    util.ternop(
      l_error_info is not null,
      l_upload_table_info_last.error_cnt_total + 1,
      l_upload_table_info_last.error_cnt_total
    );

  l_upload_table_info_next.error_cnt_consecutive :=
    util.ternop(
      l_error_info is not null and l_upload_table_info_last.error_message is not null,
      l_upload_table_info_last.error_cnt_consecutive + 1,
      0
    );

  l_upload_table_info_next.error_cnt_consecutive_max :=
    util.ternop(
      l_error_info is not null
        and l_upload_table_info_last.error_cnt_consecutive_max < l_upload_table_info_last.error_cnt_consecutive + 1,
      l_upload_table_info_last.error_cnt_consecutive + 1,
      l_upload_table_info_last.error_cnt_consecutive_max
    );

  -- произвести автонастройку информации о репликации, если допустимо и необходимо
  l_upload_table_info_next :=
    replicator.tune_upload_table_info(
      upload_table_info_ => coalesce(l_upload_table_info_next, l_upload_table_info_last),
      tune_stage_    => replicator.TUNE_ON_STAGE_END
    );

  -- сбрасывать статистические счетчики каждые RESET_CNT_ON_ROWS_REPLICATED реплицированных строк или каждые RESET_CNT_ON_DURATION дней
  if (
    l_upload_table_info_next.cnt_rows_replicated > replicator.RESET_CNT_ON_ROWS_REPLICATED
    or mod(trunc(kernel.get_sysdate(), 'DD') - replicator.BASE_DATE, replicator.RESET_CNT_ON_DURATION)
      > replicator.RESET_CNT_ON_DURATION
  ) then
    l_upload_table_info_next.run_cnt := 0;
    l_upload_table_info_next.cnt_rows_replicated := 0;
    l_upload_table_info_next.run_duration := 0;
    l_upload_table_info_next.run_avg_duration := 0;
    l_upload_table_info_next.error_cnt_total := 0;
    l_upload_table_info_next.error_cnt_consecutive := 0;
    l_upload_table_info_next.error_cnt_consecutive_max := 0;
  end if;

  update upload_tables ut
  set
    ut.refresh_dt                = l_upload_table_info_next.refresh_dt,
    ut.refresh_dt_timeout        = l_upload_table_info_next.refresh_dt_timeout,
    ut.merge_dt                  = l_upload_table_info_next.merge_dt,
    ut.dbscn                     = l_upload_table_info_next.dbscn,
    ut.update_dict_by_main_fk    = l_upload_table_info_next.update_dict_by_main_fk,
    ut.run_cnt                   = l_upload_table_info_next.run_cnt,
    ut.cnt_rows_replicated       = l_upload_table_info_next.cnt_rows_replicated,
    ut.cnt_rows_tmp              = l_upload_table_info_next.cnt_rows_tmp,
    ut.cnt_rows_prt_series       = l_upload_table_info_next.cnt_rows_prt_series,
    ut.portion_size_actual       = l_upload_table_info_next.portion_size_actual,
    ut.run_duration              = l_upload_table_info_next.run_duration,
    ut.run_avg_duration          = l_upload_table_info_next.run_avg_duration,
    ut.error_message             = l_upload_table_info_next.error_message,
    ut.error_cnt_total           = l_upload_table_info_next.error_cnt_total,
    ut.error_cnt_consecutive     = l_upload_table_info_next.error_cnt_consecutive,
    ut.error_cnt_consecutive_max = l_upload_table_info_next.error_cnt_consecutive_max,
    ut.rep_up_mode_prev          = l_upload_table_info_next.rep_up_mode_prev,
    ut.rep_up_mode_current       = l_upload_table_info_next.rep_up_mode_current,
    ut.rep_up_mode_next          = l_upload_table_info_next.rep_up_mode_next,
    ut.rep_up_mode_default       = l_upload_table_info_next.rep_up_mode_default
  where ut.table_name = coalesce(l_upload_table_info_last.table_name, table_name_);

  commit;

  replicator.change_upload_table_run_status(
    table_name_  => coalesce(l_upload_table_info_last.table_name, table_name_),
    session_uid_ => session_uid_,
    run_status_  => util.ternop(l_error_info is not null, const.REP_UP_RUN_STATUS_ERROR, const.REP_UP_RUN_STATUS_COMPLETE)
  );
exception when others then
  update upload_tables ut
  set
    ut.refresh_dt_timeout =
      case
        when (ut.error_cnt_consecutive > replicator.ERR_CNT_CONSECUTIVE_THRESHOLD) then
          (kernel.get_sysdate() - ut.refresh_dt) * const.TIME_SECONDS_IN_DAY
          + least(replicator.TIMEOUT_MAX, replicator.REFRESH_INTERVAL_FACTOR * ut.refresh_interval)
        else
          0
      end,
    ut.cnt_rows_tmp = coalesce(l_upload_table_info_next.cnt_rows_tmp, ut.cnt_rows_tmp),
    ut.run_cnt = ut.run_cnt + 1,
    ut.error_message = error.get_error_info(), --sqlerrm,
    ut.error_cnt_total = ut.error_cnt_total + 1,
    ut.error_cnt_consecutive = ut.error_cnt_consecutive + 1,
    ut.error_cnt_consecutive_max =
      case
        when (ut.error_cnt_consecutive_max < ut.error_cnt_consecutive + 1) then
          ut.error_cnt_consecutive + 1
        else
          ut.error_cnt_consecutive_max
      end
  where ut.table_name = coalesce(upload_table_info_last_.table_name, l_upload_table_info_last.table_name, table_name_);
  commit;

  replicator.change_upload_table_run_status(
    table_name_  => coalesce(upload_table_info_last_.table_name, l_upload_table_info_last.table_name, table_name_),
    session_uid_ => session_uid_,
    run_status_  => const.REP_UP_RUN_STATUS_ERROR
  );
  raise;
end finalize_upload_table;

/**
 * Выполняет передачу данных из локальной временной или буферной таблицы в глобальную временную таблицу
 *   и возвращает количество реплицированных строк (sql%rowcount после оператора merge)
 *
 * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
 *
 * @return [not null] количество реплицированных строк
 */
function transfer_table_data(upload_table_info_ replicator.t_upload_table_info) return integer is
  l_cnt_rows_replicated integer := 0;
begin
  execute immediate 'delete from '||upload_table_info_.temporary_table_name||'@org';
  if(upload_table_info_.rep_up_mode_current = const.REP_UP_M_BUFFER_PRT) then
    execute immediate upload_table_info_.sql_transfer_buf_tbl
      using
        upload_table_info_.cnt_rows_prt_series + 1,
        upload_table_info_.cnt_rows_prt_series + upload_table_info_.portion_size_actual;
    l_cnt_rows_replicated := sql%rowcount;
  elsif(
    upload_table_info_.rep_up_mode_current in (
      const.REP_UP_M_SCN,
      const.REP_UP_M_SCN_PRT,
      const.REP_UP_M_STATUS,
      const.REP_UP_M_STATUS_PRT
    )
  ) then
    execute immediate upload_table_info_.sql_transfer_tmp_tbl;
    l_cnt_rows_replicated := sql%rowcount;
  end if;

  return l_cnt_rows_replicated;
end transfer_table_data;

/**
 * Передает управление глобальным функциям-загрузчикам, которые из глобальных временных таблиц загружают данные на ГБД
 *
 * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
 */
procedure upload_table_data(upload_table_info_ replicator.t_upload_table_info) is
begin
//
end upload_table_data;

/**
 * Производит загрузку изменившихся данных для указанной таблицы
 *
 * @param table_name_ [not null] - Наименование реплицируемой таблицы
 * @param log_        [nullable] - Объект логера
 *
 * @throws ORA-20717 - Ошибка репликации. Признак репликации (значение столбца-признака_репликации) не был изменен
 * @throws ORA-20718 - Ошибка репликации. Не найдена информация о репликации реплицируемой таблицы
 */
procedure upload_one_table(table_name_ varchar2, log_ dblogger default null) is
  l_log dblogger := log_;
  l_upload_table_info_current replicator.t_upload_table_info;
  l_upload_table_info_last replicator.t_upload_table_info;
  l_scn_new integer;
  l_cnt_rows_tmp integer := 0;
  l_cnt_rows_replicated integer := 0;
  l_rep_timeout integer := 0;
  SESSION_UID constant integer := replicator.generate_session_uid();

  /**
   * Увеличивает (тривиальное обновление) и возвращает scn нереплицированных (не вошедших в порцию) записей
   *   реплицируемой таблицы.
   * Автономная транзакция.
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   *
   * @return [not null] scn тривиально обновленных нереплицированных (не вошедших в порцию) записей
   */
  function upd_and_get_loc_table_scn(upload_table_info_ replicator.t_upload_table_info) return integer is
    -- UPDATE выражение переводит scn в значение null, автономная транзакция позволяет получить scn
    --    до подтверждения/отмены родительской транзакции
    pragma autonomous_transaction;
    --ll_cnt_non_rep_rows_tmp_tbl integer := 0;
    ll_rows_updated integer := 0;
    ll_max_scn integer;
  begin
    execute immediate upload_table_info_.sql_upd_get_loc_table_scn;
    ll_rows_updated := sql%rowcount;
    assert.assert_true(
      value_ => ll_rows_updated > 0,
      comment_ => 'Не удалось увеличить (тривиально обновить) scn нереплицированных (не вошедших в порцию) записей '||
        'реплицируемой таблицы'
    );
    -- подтвердить транзакцию, чтобы получить scn после тривиального обновления
    commit;
    execute immediate upload_table_info_.sql_get_min_scn_prt into ll_max_scn;
    -- обязательный коммит, поскольку функция выполняется в автономной транзакции
    commit;

    return ll_max_scn;
  exception when others then
    rollback;
    raise;
  end upd_and_get_loc_table_scn;

  /**
   * Меняет значение столбца-признака_репликации реплицируемой таблицы (если у таблицы такой признак существует)
   *   и возвращает максимальное значение scn для загруженных данных.
   *   Признак меняется только для строк, которые были копированы во временную таблицу на предыдущих шагах.
   *   Учитывает случаи, когда значения первичного ключа меняется в процессе репликации, например org_account,
   *     upload_tables.pk_column_name_changed хранит наименование столбца, где храниться старое значение
   * Автономная транзакция.
   *
   * @param upload_table_info_ [not null] - Информация о репликации реплицируемой таблицы
   * @param rep_up_status_     [not null] - Признак репликации:
   *                                          0    - не учитывать строку (const.REP_UP_STATUS_DONT_COUNT),
   *                                          1    - строка не реплицирована (const.REP_UP_STATUS_NON_REPLICATED),
   *                                          null - строка реплицирована (const.REP_UP_STATUS_REPLICATED)
   *
   * @return [not null] -1, если признак репликации для указанной таблицы не существует;
   *                    иначе максимальное значение scn для загруженных данных
   */
  function update_loc_table_rep_up_status(
    upload_table_info_ replicator.t_upload_table_info,
    rep_up_status_ integer
  ) return integer is
    -- UPDATE выражение переводит scn в значение null, автономная транзакция позволяет получить scn
    --    до подтверждения/отмены родительской транзакции
    pragma autonomous_transaction;
    ll_cnt_non_rep_rows_tmp_tbl integer := 0;
    ll_rows_updated integer := 0;
    ll_max_scn integer;
  begin
    assert.assert_in_set(
      value_ => rep_up_status_,
      set_ => const.REP_UP_STATUSES,
      value_name_ => 'rep_up_status_ = '||coalesce(to_char(rep_up_status_), 'null')
    );

    -- получить количество строк со статусом "не реплицирована" во временной таблице, если такой столбец существует.
    if (util.int2bool(upload_table_info_.is_rep_up_status_column_exists)) then
      execute immediate upload_table_info_.sql_cnt_non_rep_rows_tmp_tbl into ll_cnt_non_rep_rows_tmp_tbl;
    end if;

    if (ll_cnt_non_rep_rows_tmp_tbl > 0) then
      execute immediate upload_table_info_.sql_upd_rep_up_status using rep_up_status_, rep_up_status_, rep_up_status_;
      ll_rows_updated := sql%rowcount;
      assert.assert_true(
        value_ => ll_rows_updated > 0,
        comment_ => 'Не удалось изменить значение столбца-признака_репликации реплицируемой таблицы'
      );
      -- подтвердить транзакцию, чтобы получить scn после изменения значения столбца-признака_репликации
      commit;
      execute immediate upload_table_info_.sql_get_max_scn_rep_up_status into ll_max_scn using upload_table_info_.dbscn;
    else
      execute immediate upload_table_info_.sql_get_max_scn_tmp_tbl into ll_max_scn;
    end if;

    -- обязательный коммит, поскольку функция выполняется в автономной транзакции
    commit;

    return ll_max_scn;
    -- если на одном из следующих шагов случится ошибка, необходимо еще раз вызвать функцию со значением параметра
    --   rep_up_status_ = const.REP_UP_STATUS_NON_REPLICATED (1 - строка не реплицирована)
  exception when others then
    rollback;
    raise;
  end update_loc_table_rep_up_status;

begin
  if (log_ is null) then
    l_log := dblog_util.get_dblogger(
      acronym_ => 'REPLICATOR',
      fcbuilder_ => fcbuilder('UPLOAD_ONE_TABLE')
        .param('table_name_', table_name_)
    );
  else
    l_log.l_acronym := 'REPLICATOR';
    l_log.l_logger_name := 'UPLOAD_ONE_TABLE';
  end if;

  l_upload_table_info_last := replicator.get_upload_table_info(
    table_name_  => table_name_,
    log_         => l_log
  );

  replicator.change_upload_table_run_status(
    table_name_  => table_name_,
    session_uid_ => SESSION_UID,
    run_status_  => const.REP_UP_RUN_STATUS_RUNNING
  );

  l_upload_table_info_current := replicator.set_upload_table_info(
    table_name_  => table_name_,
    log_         => l_log
  );

  l_cnt_rows_tmp := replicator.populate_tmp_buf_table(upload_table_info_ => l_upload_table_info_current, log_ => l_log);
  -- на случай сбоя/ошибки, например при передаче данных в ГБД, количество строк в буферной таблице будет записано
  --   upload_tales функцией finalize_upload_table
  if (l_upload_table_info_current.rep_up_mode_current = const.REP_UP_M_BUFFER_PRT) then
    l_upload_table_info_current.cnt_rows_tmp := l_cnt_rows_tmp;
  end if;
  if (l_cnt_rows_tmp > 0) then
    -- в случае, если при пополнении временной таблицы было
    -- добавлено больше 0 строк, производим передачу данных
    -- из локальной временной таблицы в глобальную временную таблицу
    l_cnt_rows_replicated := replicator.transfer_table_data(upload_table_info_ => l_upload_table_info_current);
    -- передаем управление глобальной функции-загрузчику
    replicator.upload_table_data(upload_table_info_ => l_upload_table_info_current);
    -- в случае сбоя блок exception не отработает, однако статус строк в реплицируемой таблице уже будет изменен в статус
    --   "реплицированы", т.к. следующим шагом replicator.update_table_rep_up_status выполянется в автономной транзакции.
    --   Без коммит в ГБД изменения будут отменены, т.е. данные реплицированы не будут. С коммит в худшем случае (сбой),
    --   при следующей после сбоя репликации уже реплицированные предыдущей репликацией данные снова будут участвовать в
    --   репликации, т.к. upload_tables.dbscn не изменится (не касается случая работы репликатора в режиме испольщования
    --   rep_up_status).
    --   При этом блокировка таблицы upload_tables снимается
    commit;
    -- получить новый максимальный scn и обновить данные в реплицируемой таблице, если необходимо. Эти два действия
    --   необходимо выполнять как можно ближе друг к другу, т.к. между моментом после подтверждения обновления данных
    --   (commit) предусмотренных текущей итерацией репликации и получением scn после обновления, обновленные репликатором
    --   данные (строки) могут быть обновлены другими пользователями и потому их scn не должен быть использован
    if(
      l_upload_table_info_current.rep_up_mode_current in (const.REP_UP_M_STATUS, const.REP_UP_M_STATUS_PRT)
      -- в других режимах репликации могут быть таблицы, которые имеют столбец-признак_репликации, который должен быть обновлен
      or util.int2bool(l_upload_table_info_current.is_rep_up_status_column_exists)
    ) then
      -- изменив признак репликации
      l_scn_new := replicator.upload_one_table.update_loc_table_rep_up_status(
        upload_table_info_ => l_upload_table_info_current,
        rep_up_status_ => const.REP_UP_STATUS_REPLICATED
      );
    end if;

    if(l_scn_new is null) then
      if(l_upload_table_info_current.rep_up_mode_current = const.REP_UP_M_SCN) then
        -- получить максимальный scn в временной таблице
        execute immediate l_upload_table_info_current.sql_get_max_scn_tmp_tbl into l_scn_new;
      elsif(l_upload_table_info_current.rep_up_mode_current = const.REP_UP_M_SCN_PRT) then
        -- получить максимальный scn в временной таблице и поднять scn записей в реплицируемой таблице, не вошедших в порцию
        l_scn_new := replicator.upload_one_table.upd_and_get_loc_table_scn(upload_table_info_ => l_upload_table_info_current);
      elsif(l_upload_table_info_current.rep_up_mode_current = const.REP_UP_M_BUFFER_PRT) then
        -- если в временной таблице строк меньше, чем в переданной порции, то очистить временную таблицу и взять
        --   максимальный scn её строк
        if (l_cnt_rows_tmp <= l_upload_table_info_current.portion_size_actual
          or l_cnt_rows_tmp <= l_upload_table_info_current.cnt_rows_prt_series + l_upload_table_info_current.portion_size_actual
        ) then
          execute immediate l_upload_table_info_current.sql_get_max_scn_buf_tbl into l_scn_new;
          begin
            execute immediate 'truncate table '||l_upload_table_info_current.buffer_table_name;
          exception when others then
            -- на случай, если у реплицируемой таблицы есть зависимые таблицы
            execute immediate 'delete from table '||l_upload_table_info_current.buffer_table_name;
            commit;
          end;
          l_upload_table_info_current.cnt_rows_tmp := 0;
          l_upload_table_info_current.cnt_rows_prt_series := 0;
        -- если передалось не всё, то l_scn_new не обновлять
        else
          l_upload_table_info_current.cnt_rows_tmp := l_cnt_rows_tmp;
          l_upload_table_info_current.cnt_rows_prt_series :=
            l_upload_table_info_current.cnt_rows_prt_series + l_upload_table_info_current.portion_size_actual;
          l_rep_timeout := l_upload_table_info_current.rep_timeout;
          l_scn_new := null;
        end if;
      end if;
    end if;
  end if;

  replicator.set_constraints_all_immediate();

  <<finalize_upload_table>>
  declare
    DT constant date := kernel.get_sysdate();
  begin
    l_upload_table_info_current.dbscn := coalesce(l_scn_new, l_upload_table_info_current.dbscn);
    l_upload_table_info_current.refresh_dt := DT;
    l_upload_table_info_current.refresh_dt_timeout :=
      l_upload_table_info_current.refresh_dt_timeout + util.ternop(l_scn_new is not null, 0, (coalesce(l_rep_timeout, 0)));
    l_upload_table_info_current.merge_dt := util.ternop(l_scn_new is not null, DT, l_upload_table_info_current.merge_dt);
    l_upload_table_info_current.cnt_rows_replicated := l_cnt_rows_replicated;
    replicator.finalize_upload_table(
      upload_table_info_last_ => l_upload_table_info_last,
      upload_table_info_current_ => l_upload_table_info_current,
      session_uid_ => SESSION_UID
    );
  end finalize_upload_table;
exception when others then
  -- в случае ошибки признак репликации строки должен быть "не реплицирована"
  if(l_scn_new > 0
    and (
      l_upload_table_info_current.rep_up_mode_current in (const.REP_UP_M_STATUS, const.REP_UP_M_STATUS_PRT)
      or util.int2bool(l_upload_table_info_current.is_rep_up_status_column_exists)
    )
  ) then
    declare
      l_dummy integer;
    begin
      l_dummy := replicator.upload_one_table.update_loc_table_rep_up_status(
        upload_table_info_ => l_upload_table_info_current,
        rep_up_status_ => const.REP_UP_STATUS_NON_REPLICATED
      );
    end;
  end if;

  l_log.l_acronym := 'REPLICATOR';
  l_log.l_logger_name := 'UPLOAD_ONE_TABLE';
  l_log.error(message_ => error.get_error_info());
  replicator.finalize_upload_table(
    upload_table_info_last_    => l_upload_table_info_last,
    upload_table_info_current_ => l_upload_table_info_current,
    table_name_  => table_name_,
    with_error_  => true,
    session_uid_ => SESSION_UID
  );
  raise;
end upload_one_table;

/**
 * Производит тривиальное обновление (увеличение scn) записей "родительской таблицы" по полю parent_table_key_column_name_,
 *   значения которых равно значениям в поле child_table_key_column_name_ "дочерней таблицы" всех записей, scn которых
 *   больше child_table_err_scn_.
 *   Необходимо в случае, если "родительская таблица" реплицируется порциями и переданная порция не может покрыть
 *   все значения "родительской таблицы", на которые ссылается "дочерняя таблица". Тривиальное обновление "родительской
 *   таблицы" повлечет повторную репликацию её строк, scn которых был увеличен этим обновлением (количество таких строк
 *   равно размеру порции, в которую попали строки, на которых сработало ограничение сслочной целостности "дочерней таблицы".
 * Автономная транзакция
 *
 * @param parent_table_name_ [not null] - Наименование "родительской таблицы"

 * @param child_table_name_  [nullable] - Наименование "дочерней" (реплицируемой таблицы)
 * @param fk_constraint_     [nullable] - Наименование ссылочного ограничения дочерней таблицы
 * @param log_               [nullable] - Объект логера
 *
 * @throws ORA-20718 - Ошибка репликации. Не найдена информация о репликации реплицируемой таблицы
 */
procedure update_parent_table_scn(
  parent_table_name_           varchar2,
  parent_table_key_column_name_ varchar2,
  child_table_name_            varchar2,
  child_table_key_column_name_  varchar2,
  child_table_err_scn_         integer,
  log_                         dblogger default null
) is
  pragma autonomous_transaction;
  l_log dblogger := log_;
  l_upload_table_info_parent replicator.t_upload_table_info;
begin
  if (log_ is null) then
    l_log := dblog_util.get_dblogger(
      acronym_ => 'REPLICATOR',
      fcbuilder_ => fcbuilder('UPDATE_PARENT_TABLE_SCN')
        .param('parent_table_name_', parent_table_name_)
        .param('parent_table_key_column_name_', parent_table_key_column_name_)
        .param('child_table_name_', child_table_name_)
        .param('child_table_key_column_name_', child_table_key_column_name_)
        .param('child_table_err_scn_', child_table_err_scn_)
    );
  else
    l_log.l_acronym := 'REPLICATOR';
    l_log.l_logger_name := 'UPLOAD_PARENT_TABLE';
  end if;

  l_upload_table_info_parent := replicator.set_upload_table_info(table_name_ => parent_table_name_, log_ => l_log);

  execute immediate
    sbuilder(
      'merge into ${parent_table_name} t '||
      'using (select ${child_table_key_column_name} from ${filter_view_name} where dbscn > :dbscn) s '||
      'on (t.${parent_table_key_column_name} = s.${child_table_key_column_name}) '||
      'when matched then update set '||
      '  ${parent_trivia_upd_column_name} = ${parent_trivia_upd_column_name}'
    )
      .fill(
        'parent_table_name',             replicator.get_loc_table_name(table_name_ => parent_table_name_),
        'child_table_key_column_name',   child_table_key_column_name_,
        'filter_view_name',              replicator.get_filter_view_name(child_table_name_),
        'parent_table_key_column_name',  parent_table_key_column_name_,
        'parent_trivia_upd_column_name', l_upload_table_info_parent.trivia_upd_column_name
      )
      .to_string()
    using child_table_err_scn_;
  commit;
exception when others then
  l_log.l_acronym := 'REPLICATOR';
  l_log.l_logger_name := 'UPDATE_PARENT_TABLE_SCN';
  l_log.error(message_ => error.get_error_info());
  rollback;
  raise;
end update_parent_table_scn;

/**
 * Проверяет допустимость тривиального обновления (увеличение scn) "родительской таблицы".
 *   Необходимо в случае, если "родительская таблица" реплицируется порциями и переданная порция не может покрыть
 *   все значения "родительской таблицы", на которые ссылается "дочерняя таблица". Тривиальное обновление "родительской
 *   таблицы" повлечет повторную репликацию её строк, scn которых был увеличен этим обновлением (количество таких строк
 *   равно размеру порции, в которую попали строки, на которых сработало ограничение сслочной целостности "дочерней таблицы".
 * Автономная транзакция
 *
 * @param parent_table_name_ [not null] - Наименование "родительской таблицы"
 * @param child_table_name_  [nullable] - Наименование "дочерней" (реплицируемой таблицы)
 * @param fk_constraint_     [nullable] - Наименование ссылочного ограничения дочерней таблицы
 * @param log_               [nullable] - Объект логера
 *
 * @throws ORA-20718 - Ошибка репликации. Не найдена информация о репликации реплицируемой таблицы
 *
 * @return [not null] true - обновление допустимо, иначе false
 */
function is_parent_table_update_allowed(
  parent_table_name_ varchar2,
  child_table_name_  varchar2,
  fk_constraint_     varchar2,
  log_               dblogger default null
) return boolean is
  -- автономная транзакция, иначе информация о репликации "дочерней таблицы", например параметр error_cnt_consecutive,
  --   будет неактуальной, т.к. эта информация обновляется в атономной транзакции процедурой finalize_upload_table
  pragma autonomous_transaction;
  l_log dblogger := log_;
  l_upload_table_info_parent replicator.t_upload_table_info;
  l_upload_table_info_child  replicator.t_upload_table_info;
begin
  if (log_ is null) then
    l_log := dblog_util.get_dblogger(
      acronym_ => 'REPLICATOR',
      fcbuilder_ => fcbuilder('UPLOAD_PARENT_TABLE')
        .param('parent_table_name_', parent_table_name_)
        .param('child_table_name_', child_table_name_)
        .param('fk_constraint_', fk_constraint_)
    );
  else
    l_log.l_acronym := 'REPLICATOR';
    l_log.l_logger_name := 'IS_PARETN_TABLE_UPDATE_ALLOWED';
  end if;

  l_upload_table_info_parent := replicator.set_upload_table_info(table_name_ => parent_table_name_, log_ => l_log);
  l_upload_table_info_child  := replicator.set_upload_table_info(table_name_ => child_table_name_, log_ => l_log);

  return
    not (
      -- любой из режимов передачи порциями
      l_upload_table_info_parent.rep_up_mode_current in (
        const.REP_UP_M_SCN_PRT,
        const.REP_UP_M_STATUS_PRT,
        const.REP_UP_M_BUFFER_PRT
      )
      -- при репликации "родительской таблицы" порциями "дочерняя таблица" может быть не реплицирована за одну итерацию
      --   при этом между этими итерацми могут проявиться другие ошибки, поэтому тривиальное обновление "родительской
      --   таблицы" должно быть отложено в разумных пределах
      and l_upload_table_info_child.error_cnt_consecutive < replicator.ERR_CNT_CONSECUTIVE_UPD_PARENT
      and (
        upper(l_upload_table_info_child.error_message) like '%'||fk_constraint_||'%'
        -- наименования равнозначных ограничений ссылочной целостности между одинаковыми сущностями могут отличаться
        --   на ГБД и ЛБД, что является плохой практикой, однако такие случаи должны быть учтены и обработаны. Например
        --   в ГБД ограничение FK_MAIN_PDA_PROFILE_OWNER$PROF соответствует ограничению в ЛБД FK_ORG_PDA_PROFILE_OWNER$PROF
        or upper(l_upload_table_info_child.error_message)
          like '%'||replace(srcstr => upper(fk_constraint_), oldsub => '_MAIN_', newsub => '_ORG_')||'%'
      )
    );
exception when others then
  l_log.l_acronym := 'REPLICATOR';
  l_log.l_logger_name := 'IS_PARETN_TABLE_UPDATE_ALLOWED';
  l_log.error(message_ => error.get_error_info());
  raise;
end is_parent_table_update_allowed;

/**
 * Реплицирует указанную таблицу, на первичный ключ которой ссылается таблица, при репликации которой произошло нарушение
 *   ссылочной целостности в ГБД
 *
 * @param child_table_name_ [not null] - Наименование таблицы, которую нужно реплицировать
 * @param sqlerrm_          [not null] - Текс ошибки
 * @param level_            [not null] - Уровень вложенности
 * @param log_              [nullable] - Объект логера
 */
procedure upload_parent_table(
  child_table_name_ varchar2,
  sqlerrm_          varchar2,
  level_            integer  default 1,
  log_              dblogger default null
) is
  type t_parent_table_info is record (
    parent_table_name     upload_tables.table_name%type,
    loc_parent_table_name upload_tables.loc_table_name%type,
    parent_table_block_dt upload_tables.block_dt%type
  );
  type tbl_parent_table_info is table of t_parent_table_info;
  type tbl_updated_parent_table is table of integer index by upload_tables.table_name%type;
  l_updated_parent_table tbl_updated_parent_table;

  l_log                 dblogger := log_;
  l_child_table_fk_info t_fk_constraint_info;
  l_parent_tables       tbl_parent_table_info;
  l_parent_table_info   t_parent_table_info;
  l_child_table_err_scn integer;

  /**
   * Проверяет необходимость тривиального обновления (увеличение scn) "родительской таблицы".
   *   Необходимость сводится статусу завершения репликации "родительской таблицы", которая была вызвана
   *   ошибкой репликации "дочерней таблицы" из-за ссылочного ограничения (replicator.upload_parent_table завершилась ошибкой).
   *   Т.е поле update_dict_by_main_fk в таблице upload_tables отлично от null
   *
   * @param child_table_name_   [not null] - Наименование "дочерней таблицы" (реплицируемой таблицы)
   * @param child_table_fk_name [nullable] - Наименование ссылочного ограничения "дочерней таблицы" (реплицируемой таблицы)
   *
   * @return [not null] true - требуется обновление, иначе false
   */
  function is_parent_tbl_scn_upd_required(
    child_table_name_   varchar2,
    child_table_fk_name varchar2
  ) return boolean is
    l_count integer;
  begin
    select count(*)
    into l_count
    from upload_tables t
    where t.table_name = child_table_name_ and update_dict_by_main_fk = child_table_fk_name;

    return l_count > 0;
  end is_parent_tbl_scn_upd_required;

  procedure raise_upload_parent_table_err (err_message_ varchar2) is
  begin
    error.raise_error(
      errcode_ => -20203,
      errmessage_ =>
        sbuilder('Ошибка при репликации родительской таблицы для "${table_name}" для исключения ссылочной целостности <${sqlerrm}>: ${err_message}')
        .fill(
          'table_name',  child_table_name_,
          'sqlerrm',     util.cutstr(sqlerrm_, 100, '...'),
          'err_message', err_message_
        )
        .to_string()
    );
  end raise_upload_parent_table_err;
begin
  if (log_ is null) then
    l_log := dblog_util.get_dblogger(
      acronym_ => 'REPLICATOR',
      fcbuilder_ => fcbuilder('UPLOAD_PARENT_TABLE')
        .param('child_table_name_', child_table_name_)
        .param('sqlerrm_', sqlerrm_)
        .param('level_', level_)
    );
  else
    l_log.l_acronym := 'REPLICATOR';
    l_log.l_logger_name := 'UPLOAD_PARENT_TABLE';
  end if;

  --savepoint sp_upload_parent_table;

  if (level_ >= 5) then
    raise_upload_parent_table_err('Достигнута предельная глубина рекурсии ' || to_char(level_));
  end if;

  l_child_table_fk_info := replicator.get_main_fk_constraint_info(sqlerrm_);

  if (l_child_table_fk_info.parent_table is null) then
    raise_upload_parent_table_err('Не найдена родительская таблица для репликации в информации о ссылочном огрничении');
  end if;

  -- достаем информацию о словарях
  select
    t.table_name     parent_table_name,
    t.loc_table_name loc_parent_table_name,
    t.block_dt       parent_table_block_dt
  bulk collect into
    l_parent_tables
  from upload_tables t
  where t.main_table_name = l_child_table_fk_info.parent_table;

  if (l_parent_tables is null or l_parent_tables.count = 0) then
    raise_upload_parent_table_err('Не удалось опеределить родительскую таблицу в информации о реплицируемых таблицах'||
      l_child_table_fk_info.parent_table
    );
  end if;

  if (l_child_table_fk_info.child_key_columns.count = 0) then
    raise_upload_parent_table_err('На найдены столбцы по ссылочному ограничению');
  elsif (l_child_table_fk_info.child_key_columns.count > 1) then
    raise_upload_parent_table_err('Составные ссылочные ограничения не поддерживаются');
  elsif (
    l_child_table_fk_info.child_key_columns(1).data_type <> 'NUMBER'
    or coalesce(l_child_table_fk_info.child_key_columns(1).data_scale, const.NULL_NUMBER) <> 0) then
    raise_upload_parent_table_err('Ссылочное ограничение с нецелочисленным ключом не поддерживается');
  end if;

  for i in 1 .. l_parent_tables.count loop
    if (l_parent_tables(i).parent_table_block_dt < kernel.get_sysdate()) then
      raise_upload_parent_table_err('"Родительская таблица" заблокирована для репликации '||l_parent_tables(i).parent_table_name);
    end if;
  end loop;

  -- Проверка необходимости тривиального обновления "родительской таблицы", обновление необходимо в случае, если
  --   предыдущая итерация репликации "родительской таблицы" завершилась ошибкой
  if (
    replicator.upload_parent_table.is_parent_tbl_scn_upd_required(
      child_table_name_   => child_table_name_,
      child_table_fk_name => l_child_table_fk_info.fk_constraint
    )
  ) then
    l_child_table_err_scn := replicator.get_upload_table_dbscn(table_name_ => child_table_name_);
    for i in 1 .. l_parent_tables.count loop
      l_parent_table_info := l_parent_tables(i);
      if(
        -- не обновлять несколько раз одну и ту же таблицу
        not l_updated_parent_table.exists(l_parent_table_info.parent_table_name)
        -- отложить тривиальное обновление "родительской таблицы"
        and replicator.is_parent_table_update_allowed(
          parent_table_name_ => l_parent_table_info.parent_table_name,
          child_table_name_  => child_table_name_,
          fk_constraint_     => l_child_table_fk_info.fk_constraint
        )
      ) then
        -- Здесь должно соблюдаться условие, что имена колонок локальной базы должны совпадать с таковыми на глобальной базы.
        -- Если будет найден контрпример, то стоит постараться заточить его под основную массу.
        -- Если не удастся, то необходимо будет дорабатывать механизм репликации: реализовывать сопоставления колонок.
        replicator.update_parent_table_scn(
          parent_table_name_            => l_parent_table_info.parent_table_name,
          parent_table_key_column_name_ => l_child_table_fk_info.parent_key_columns(1).column_name,
          child_table_name_             => child_table_name_,
          child_table_key_column_name_  => l_child_table_fk_info.child_key_columns(1).column_name,
          child_table_err_scn_          => l_child_table_err_scn,
          log_                          => l_log
        );
        l_updated_parent_table(l_parent_table_info.parent_table_name) := 1;
      end if;
    end loop;
  end if;

  -- Реплицируем справочники
  for i in 1 .. l_parent_tables.count loop
    l_parent_table_info := l_parent_tables(i);
    begin
      --точка отката не требуется и даже может привести к ошибке, т.к. в replicator.upload_one_table есть коммиты
      --savepoint sp_upload_parent_table;
      replicator.upload_one_table(table_name_ => l_parent_table_info.parent_table_name, log_ => l_log);
      -- если функция replicator.is_parent_table_update_allowed действует не в автономной тразакции, тогда необходимо
      --   подтверждение транзакции, иначе функция replicator.is_parent_table_update_allowed не увидит изменения,
      --   и значение error_cnt_consecutive будет ошибочным
      --commit;
    exception
      when error.EXC_PARENT_KEY_NOT_FOUND then
        -- при ошибке репликации справочника реплицируем справочник для него
        replicator.upload_parent_table(
          child_table_name_ => l_parent_table_info.parent_table_name,
          sqlerrm_          => sqlerrm,
          level_            => level_ + 1,
          log_              => l_log
        );
        -- форсируем передачу справочника на следующем шаге репликации
        replicator.force_table_upload(table_name_ => l_parent_table_info.parent_table_name);
      when others then
        l_log.l_acronym := 'REPLICATOR';
        l_log.l_logger_name := 'UPLOAD_PARENT_TABLE';
        l_log.error(message_ => error.get_error_info());
        --rollback to sp_upload_parent_table;
        raise;
    end;
    -- в любом случае сохраняем наши достижения по одному справочнику
    --savepoint sp_upload_parent_table;
  end loop;

  -- запоминаем, что для таблицы, при репликации которой произошла ошибка была попытка передачи справочников
  -- и в следующий раз, если потребуется репликация со справочником, то на ГБ будут обновлены базовые таблицы
  update upload_tables t
  set t.update_dict_by_main_fk = l_child_table_fk_info.fk_constraint
  where t.table_name = child_table_name_;
exception when others then
  l_log.l_acronym := 'REPLICATOR';
  l_log.l_logger_name := 'UPLOAD_PARENT_TABLE';
  l_log.error(message_ => error.get_error_info());
  raise;
end upload_parent_table;

/**
 * Загружает обновленные данные для всех таблиц
 *
 * @param check_offline_ [not null] - Признак: true - проверять офлайн, false - не проверять офлайн
 * @param log_           [nullable] - Объект логера
 */
procedure upload_all_tables(check_offline_ boolean default true, log_ dblogger default null) is
  DT constant date := kernel.get_sysdate();
  l_log dblogger := log_;
begin
  if (l_log is null) then
    l_log := dblog_util.get_dblogger(
      acronym_ => 'REPLICATOR',
      fcbuilder_ => fcbuilder('UPLOAD_ALL_TABLES')
        .param('check_offline_', check_offline_)
    );
  else
    l_log.l_acronym := 'REPLICATOR';
    l_log.l_logger_name := 'REPLICATOR.UPLOAD_ALL_TABLES';
  end if;
  if (check_offline_ and server.is_offline()) then
    error.raise_error(-20008, 'При работе оффлайн невозможно изменять данные, нет доступа к серверу');
  end if;


  -- разобраться зачем это нужно, 2016-08-17 AleshinV
  kernel.set_current_user(0);

  for tbl in (
    select ut.table_name
    from upload_tables ut
    where
      -- пропустить, если таблица уже в процессе репликации, в случае параллельного выполнения задания или репликации
      --   "вручную". Однако такое поведение не сообщит об ошибке и не сбросит блокировку по таймауту, поэтому такие
      --   случаи обрабатываются в replicator.change_upload_table_run_status
      --ut.run_status <> const.REP_UP_RUN_STATUS_RUNNING
      -- пропустить, если репликация таблицы заблокирована
      (ut.block_dt is null or ut.block_dt > DT)
      -- пропустить, если не время репликации таблицы
      and coalesce(ut.refresh_dt, const.INFINITY_DATE_NEGATIVE)
        + (ut.refresh_interval + ut.refresh_dt_timeout) * const.TIME_DAYS_IN_SECOND < DT
    order by ut.table_order
  ) loop
    begin
      replicator.upload_one_table(table_name_ => tbl.table_name);
    exception
      when error.EXC_PARENT_KEY_NOT_FOUND then
        replicator.upload_parent_table(child_table_name_ => tbl.table_name, sqlerrm_ => sqlerrm, log_ => l_log);
        -- остальные исключения ингнорируются, т.к. они не должны мешать передаче других таблиц,
        --   а залогированны они будут внутри replicator.upload_one_table.
      when others then
        null;
    end;
    -- upload_one_table и upload_parent_table откатывают сами свою ненужную работу,
    -- поэтому нужно закоммитить то, что они наделали полезного
    commit;
  end loop;
exception when others then
  l_log.l_acronym := 'REPLICATOR';
  l_log.l_logger_name := 'REPLICATOR.UPLOAD_ALL_TABLES';
  l_log.error(message_ => error.get_error_info());
  rollback;
  raise;
end upload_all_tables;

/**
 * Передает изменившиеся данные таблицы на глобальный сервер
 *
 * @param table_name_      [nullable] наименование реплицируемой таблицы
 * @param loc_table_name_  [nullable] локальное имя реплицируемой таблицы
 * @param main_table_name_ [nullable] глобальное имя реплицируемой таблицы
 * Должен быть задан один из параметров и только один
*/
procedure upload_table(
  table_name_      varchar2 default null,
  loc_table_name_  varchar2 default null,
  main_table_name_ varchar2 default null
) is
begin
//
end upload_table;

/** Репликация вверх всех таблиц с измененными данными для запуска джобиком */
procedure upload_all_tables_job is
//
end upload_all_tables_job;

/**
 * Функция возвращает наименование колонки первичного ключа таблицы
 * для неподходящих первичных ключей возбуждает исключение
 */
function get_key_column_name(loc_table_name_ varchar2) return varchar2 is
//
end get_key_column_name;

/**
 * Загружает в ГБД одну запись произвольной таблицы по ключу
 * <br>
 * Ограничения: ключ может быть только простым (одноколоночными) целочисленным
 *
 * @param loc_table_name_   [not null] - Имя передаваемой таблицы, как оно задано на локальной базе
 * @param id_key_value_     [not null] - Значение ключа записи для передачи
 */
procedure upload_one_record(
  loc_table_name_  varchar2,
  id_key_value_    integer
) is
begin
//
end upload_one_record;

/**
 * Форсирует репликацию таблицы на следующем цикле передачи данных
 * @param table_name_      [nullable] наименование реплицируемой таблицы
 * @param loc_table_name_  [nullable] локальное имя реплицируемой таблицы
 * @param main_table_name_ [nullable] глобальное имя реплицируемой таблицы
 * Должен быть задан один из параметров и только один
 */
procedure force_table_upload(
  table_name_      varchar2 default null,
  loc_table_name_  varchar2 default null,
  main_table_name_ varchar2 default null
) is
begin
//
end force_table_upload;

end replicator;
/
