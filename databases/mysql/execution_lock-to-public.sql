# Механизм именных блокировок, лишенный недостатков встроенного механизма "get_lock".
#   До версии MySQL 5.7.5 каждый следующий вызов "GET_LOCK()" безусловно и без ожидания снимает блокировку 
#   предыдущего вызова. Более того, без учета такого поведения вызов RELEASE_LOCK() для уже снятой блокировки 
#   приведет к ошибке.
# О баге в "get_lock" MySQL до версии 5.7 здесь https://dev.mysql.com/doc/refman/5.7/en/locking-functions.html {
#   Before MySQL 5.7, only a single simultaneous lock can be acquired and GET_LOCK() releases any existing lock. 
#   For example:
#     SELECT GET_LOCK('lock1',10);
#     SELECT GET_LOCK('lock2',10);
#     SELECT RELEASE_LOCK('lock2');
#     SELECT RELEASE_LOCK('lock1');
#   In MySQL 5.7 or later, the second GET_LOCK() acquires a second lock and both RELEASE_LOCK() calls 
#   return 1 (success). Before MySQL 5.7, the second GET_LOCK() releases the first lock ('lock1') and the second
#   RELEASE_LOCK() returns NULL (failure) because there is no 'lock1' to release. 
# }
# И здесь https://bugs.mysql.com/bug.php?id=1118: {
#   GET_LOCK() currently releases any existing lock upon subsequent calls, reducing the usefulness of this method 
#   of implementing application locks.  It may be desirable for one part of the application to wait for (and block)
#   other portions of the application, which could identify themselves with unique lock tags, by attempting to 
#   acquire all of those seperate locks.
#     Connection1: SELECT GET_LOCK('lockone',0); SELECT GET_LOCK('locktwo',0);
#     Connection2: SELECT GET_LOCK('lockone',0);
#   Connection2 will acquire the lock because connection1's second GET_LOCK() call releases 'lockone'.
# }

# Описание созданного механизма блокировок.
# Создает блокировку выполнения. Если блокировка уже установлена другим владельцем, ждет заданное время, пытаясь
#   установить блокировку с заданным интервалом. Механизм блокировок выполнения является альтернативой встроенному 
#   механизму "get_lock", т.к. до версии MySQL 5.7.5 (согласно документации) сервера нельзя активировать более одной
#   "get_lock" в одной сессии. Механизм может быть использован для установки в одной сессии нескольких блокировок 
#   повторного одновременного выполнения задания/функции/процедуры.
########################################################################################################################
# Механизм логирования
########################################################################################################################
create database if not exists log default character set utf8 collate utf8_unicode_ci;

drop table if exists log.t_log;
create table log.t_log (
  id_log bigint unsigned not null auto_increment,
  id_connection bigint unsigned
    comment 'ID подключения (thread ID)',
  user_host_name char(250)
    comment 'Имя MySQL пользователя и имя хоста для текущего подключения клиента',
  log_name char(250)
    comment 'Наименование действия, события и пр.',
  log_type tinyint unsigned not null
    comment 'Уровень логирования: 4 - error, 3 - warning, 2 - info, 1 - debug',
  log_time datetime not null,
  log_message char(250)
    comment 'Сообщение. Если длина сообщения превышает 250 символов, сообщение и id_log записываются в журнал t_log_extended',
  primary key pk_id_log (id_log),
  key idx_log_time (log_time)
)
engine=myisam
default charset=utf8 collate=utf8_unicode_ci
checksum=1
comment='Журнал (лог) функций, процедур, заданий и пр.';

# С целью повышения производительности при работе с таблицей log.t_log поле log_message фиксировано,
# что накладывает ограничение на длину сообщения (250 символов). Для сообщений большей длины
# (до 10000 символов) записываются t_log_extended, в log.t_log записываются первые 250 символов
drop table if exists log.t_log_extended;
create table log.t_log_extended (
  id_log bigint unsigned,
  log_time datetime not null, # Для использования партиционирования по диапазону времени
  log_message varchar(10000)
    comment 'Сообщение. Длина сообщения не более 10000 символов',
  key idx_id_log (id_log),
  key idx_log_time (log_time)
)
engine=myisam
default charset=utf8 collate=utf8_unicode_ci
checksum=1
comment='Расширение журнала (лога) log.t_log, где длина сообщений превышает 250 символов';

drop table if exists log.t_log_level;
create table log.t_log_level (
  log_level       tinyint unsigned not null comment 'Уровень логирования',
  log_level_desc  varchar(250)     not null comment 'Описание уровня',
  primary key log_level (log_level)
)
engine=myisam
default charset=utf8 collate=utf8_unicode_ci
checksum=1
comment='Уровни логирования';
insert into log.t_log_level(log_level, log_level_desc)
values
(1, 'debug. Для тестирования, отладки'),
(2, 'info. Для фиксации начала выполнения процедуры/функции и пр.'),
(3, 'warning. Допустимое событие, но требующее внимания'),
(4, 'error. Событие, которое не должно произойти при нормальном выполнении');

drop procedure if exists log.create_log;
delimiter $$
create procedure log.create_log(
  p_log_name    char(250),
  p_log_type    tinyint unsigned,
  p_log_message varchar(10000)
)
  comment 'Создает запись в журнале.
    Параметры:
      p_log_name    [nullable] - Наименование действия, события и пр.;
      p_log_type    [not null] - Уровень лога: 4 - error, 3 - warning, 2 - info, 1 - debug;
      p_log_message [nullable] - Сообщение. Сообщение длиной более 10000 символов отсекается справа'
begin
  # Ошибка выполнения запроса
  declare exit handler for sqlexception begin end;
  # Только с версии mysql 5.6.4 и выше
  #declare error_code char(5) default '00000';
  #declare error_messgae text;
  #  get diagnostics condition 1
  #    error_code = returned_sqlstate, error_messgae = message_text;
  insert into log.t_log(id_connection, user_host_name, log_name, log_type, log_time, log_message)
  values(connection_id(), user(), left(p_log_name, 250), p_log_type, now(), left(p_log_message, 250));
  if (row_count() = 1 and char_length(p_log_message) > 250) then
    insert into log.t_log_extended(id_log, log_time, log_message)
    values(last_insert_id(), now(), left(p_log_message, 10000));
  end if;

end$$
delimiter ;


########################################################################################################################
# Механизм блокировки выполнения
########################################################################################################################
create database if not exists util default character set utf8 collate utf8_unicode_ci;

# Функциональность sequence в СУБД Oracle может быть заменена использованием пользовательской таблицы с auto_increment или uuid.
# Использование auto_increment требует полного понимания его работы и накладываемых ограничений (операции insert, truncate, транзакционность)
drop table if exists util.t_sequence;
create table util.t_sequence (
  id bigint unsigned not null auto_increment comment 'Сгенерированный уникальный идентификатор',
  primary key pk_id (id)
)
engine=myisam
default charset=utf8 collate=utf8_unicode_ci
checksum=1
comment='Уникальные идентификаторы. Реализует функциональность sequence в СУБД Oracle';
# Вставляет первую запись
insert into util.t_sequence() values();

drop function if exists util.next_sequence;
delimiter $$
create function util.next_sequence() returns bigint
  comment 'Генерирует и возвращает уникальный идентификатор из возрастающей последовательности целых чисел.
    Таблица util.next_sequence.'
begin
  declare l_lock_status tinyint unsigned;
  insert into util.t_sequence() values();
  return last_insert_id();
end$$
delimiter ;

drop function if exists util.current_sequence;
delimiter $$
create function util.current_sequence() returns bigint
  comment 'Возвращает текущий максимальный сгенерированный уникальный идентификатор из таблицы util.next_sequence.'
begin
  declare l_lock_status tinyint unsigned;
  return (select max(t.id) from util.t_sequence t);
end$$
delimiter ;


drop table if exists util.t_execution_lock;
create table util.t_execution_lock (
  execution_lock_name   varchar(250)     not null comment 'Наименование блокировки',
  execution_lock_status tinyint unsigned not null comment 'Статус блокировки',
  execution_lock_owner  varchar(250)     not null comment 'Владелец блокировки',
  create_dt             datetime         not null comment 'Время блокировки',
  primary key pk_execution_lock_name (execution_lock_name)
)
engine=InnoDB
default charset=utf8 collate=utf8_unicode_ci
comment='Время и статус блокировки.
  Механизм блокировок выполнения является альтернативой механизму get_lock(),
  т.к. до версии 5.7.5 mysql сервера (согласно документации) нельзя
  активировать более одной get_lock() в одной сессии.
  Механизм может быть использован для установки в одной сессии нескольких блокировок
  повторного одновременного выполнения задания/функции/процедуры.';

drop table if exists util.t_execution_lock_status;
create table util.t_execution_lock_status (
  execution_lock_status       tinyint unsigned not null comment 'Статус блокировки',
  execution_lock_status_desc  varchar(250)     not null comment 'Описание статуса',
  primary key pk_execution_lock_status (execution_lock_status)
)
engine=myisam
default charset=utf8 collate=utf8_unicode_ci
checksum=1
comment='Статусы блокировки.
  Механизм блокировок выполнения является альтернативой механизму get_lock(),
  т.к. до версии 5.7.5 mysql (согласно документации) сервера нельзя
  активировать более одной get_lock() в одной сессии.
  Механизм может быть использован для установки в одной сессии нескольких блокировок
  повторного одновременного выполнения задания/функции/процедуры.';
insert into util.t_execution_lock_status(execution_lock_status, execution_lock_status_desc)
values(0, 'Блокировка не установлена'), (1, 'Блокировка установлена'), (2, 'Истек таймаут'), (3, 'Ошибка выполнения');


drop function if exists util.create_execution_lock;
delimiter $$
create function util.create_execution_lock(
  p_lock_name  varchar(250),
  p_lock_owner varchar(250),
  p_lock_wait_timeout  int unsigned,
  p_lock_wait_interval int unsigned
) returns tinyint
  comment 'Создает блокировку выполнения. Если блокировка уже установлена другим владельцем, ждет
    заданное время, пытаясь установить блокировку с заданным интервалом.
    Механизм блокировок выполнения является альтернативой механизму get_lock(), т.к. до версии 5.7.5 mysql (согласно документации)
    сервера нельзя активировать более одной get_lock() в одной сессии.
    Механизм может быть использован для установки в одной сессии нескольких блокировок
    повторного одновременного выполнения задания/функции/процедуры.

    Параметры:
      p_lock_name          [not null] - Наименование блокировки;
      p_lock_owner         [not null] - Наименование владельца блокировки. Значения "-1", "-2", "-3", "-4", "-5" зарезервированы;
      p_lock_wait_timeout  [nullable] - Общее время ожидания освобождения блокировки (в секундах), по умолчанию 0;
      p_lock_wait_interval [nullable] - Интервал проверки освобождения блокировки (в секундах), по умолчанию 0.
                                          Если интервал больше общего времени ожидания, время интервала игнорируется.
    Возвращаемое значение:
      1    - Блокировка установлена;
      2    - Истек таймаут;
      3    - Блокировка установлена для другого наименования владельца;
      иначе:
        -1   - Ошибка выполнения запроса;
        -2   - Наименование владельца должно отличаться от "-1", "-2", "-3", "-4", "-5"
        null - Не задано одно или оба значения параметров p_lock_name, p_lock_owner'
begin

  # Общее время ожидания освобождения блокировки (в секундах), по истечении которого основное тело процедуры выполнено не будет
  declare l_lock_wait_timeout int;
  # Интервал проверки освобождения блокировки (в секундах)
  declare l_lock_wait_interval int;
  declare l_lock_status tinyint unsigned;
  declare l_lock_owner  varchar(250);
  # Результат вставки/обновления таблицы util.t_execution_lock
  declare l_insert_update_result tinyint;

  # Ошибка выполнения запроса
  declare exit handler for sqlexception
  begin
    call log.create_log(
      'util.create_execution_lock',
      4,
      concat(
        'Ошибка выполнения запроса',
        ', p_lock_name='  ,coalesce(p_lock_name,  'cast as null'),
        ', p_lock_owner=' ,coalesce(p_lock_owner, 'cast as null'),
        ', p_lock_wait_timeout='  ,coalesce(p_lock_wait_timeout,  'cast as null'),
        ', p_lock_wait_interval=' ,coalesce(p_lock_wait_interval, 'cast as null')
      )
    );
    #rollback;
    return -1;
  end;

  # Продолжить выполнение, если наименование блокировки не создано
  declare continue handler for not found begin end;

  call log.create_log(
    'util.create_execution_lock',
    1,
    concat(
      'p_lock_name='    ,coalesce(p_lock_name,  'cast as null'),
      ', p_lock_owner=' ,coalesce(p_lock_owner, 'cast as null'),
      ', p_lock_wait_timeout='  ,coalesce(p_lock_wait_timeout,  'cast as null'),
      ', p_lock_wait_interval=' ,coalesce(p_lock_wait_interval, 'cast as null')
    )
  );

  # Наименование владельца должно отличаться от "-1", "-2", "-3", "-4", "-5"
  if (p_lock_owner in ('-1', '-2', '-3', '-4', '-5')) then
    return -2;
  end if;

  # Управление транзакциями (start, commit, rollback) поддерживатся в процедурах, но не функциях
  #start transaction;
  # Принудительная установка уровня изоляции транзакции
  set transaction isolation level read committed;

  # Не задано одно или оба значения параметров p_lock_name, p_lock_owner
  if(p_lock_name is null or p_lock_owner is null) then
    #commit;
    return null;
  end if;

  set l_lock_wait_timeout = coalesce(p_lock_wait_timeout, 0);
  set l_lock_wait_interval =
    case
      when (p_lock_wait_interval > p_lock_wait_timeout)
        then l_lock_wait_timeout
      else coalesce(p_lock_wait_interval, 0)
    end;

  # Создать наименование блокировки, если не существует,
  # или обновить данные для заданного наименования владельца,
  # или оставить без изменений данные для другого наименования владельца со статусом execution_lock_status = 1

  select t.execution_lock_status, t.execution_lock_owner
  into l_lock_status, l_lock_owner
  from util.t_execution_lock t
  where t.execution_lock_name = p_lock_name;

  set l_lock_status = coalesce(l_lock_status, 0);

  # Если принадлежит другому наименованию владельца, ждать освобождения блокировки
  while (l_lock_status = 1 and l_lock_owner <> p_lock_owner and l_lock_wait_timeout > 0) do
    do sleep(l_lock_wait_interval);
    set l_lock_wait_timeout = l_lock_wait_timeout - l_lock_wait_interval;
    select t.execution_lock_status, t.execution_lock_owner
    into l_lock_status, l_lock_owner
    from util.t_execution_lock t
    where t.execution_lock_name = p_lock_name;
  end while;

  # Таймаут ожидания не превышен, блокировка не установлена
  if ((p_lock_wait_timeout = 0 or l_lock_wait_timeout > 0) and l_lock_status <> 1) then
    # Создать или обновить блокировку
    # For INSERT ... ON DUPLICATE KEY UPDATE statements,
    #   the affected-rows value per row is
    #   1 if the row is inserted as a new row,
    #   2 if an existing row is updated, and
    #   0 if an existing row is set to its current values.
    # If you specify the CLIENT_FOUND_ROWS flag, the affected-rows value is 1 (not 0) if an existing row is set to its current values.
    insert into util.t_execution_lock(execution_lock_name, execution_lock_status, execution_lock_owner, create_dt)
    select
      coalesce(src.execution_lock_name_el,   src.execution_lock_name_s)   execution_lock_name,
      coalesce(src.execution_lock_status_el, src.execution_lock_status_s) execution_lock_status,
      coalesce(src.execution_lock_owner_el,  src.execution_lock_owner_s)  execution_lock_owner,
      coalesce(src.create_dt_el,             src.create_dt_s)             create_dt
    from (
      # Новые данные
      select
        el.execution_lock_name_el,
        el.execution_lock_status_el,
        el.execution_lock_owner_el,
        el.create_dt_el,
        s.execution_lock_name_s,
        s.execution_lock_status_s,
        s.execution_lock_owner_s,
        s.create_dt_s
      from (
        select
          p_lock_name  execution_lock_name_s,
          1            execution_lock_status_s,
          p_lock_owner execution_lock_owner_s,
          now()        create_dt_s
      ) s
      left join (
        # Данные ранее созданной блокировки выполнения для другого или заданного наименования владельца.
        # Данные могли измениться с момента последней проверки в цикле while
        select
          el_inner.execution_lock_name   execution_lock_name_el,
          el_inner.execution_lock_status execution_lock_status_el,
          el_inner.execution_lock_owner  execution_lock_owner_el,
          el_inner.create_dt             create_dt_el
        from util.t_execution_lock el_inner
        # Не имеет значение наименование владельца. Если статус "блокировка установлена" для заданного наименования блокировки,
        # то должны быть использованы текущие данные.
        where
          el_inner.execution_lock_name = p_lock_name
          and el_inner.execution_lock_status = 1
        for update
      ) el on (el.execution_lock_name_el = s.execution_lock_name_s)
    ) src
    on duplicate key update
      execution_lock_status = values(execution_lock_status),
      execution_lock_owner  = values(execution_lock_owner),
      create_dt             = values(create_dt);

    set l_insert_update_result = row_count();

  end if;

  #commit;

  return
    case
      # Истек таймаут
      when (p_lock_wait_timeout <> 0 and l_lock_wait_timeout <= 0)
        then 2
      # Блокировка установлена
      when (l_insert_update_result in (1, 2))
        then 1
      # Блокировка установлена для другого наименования владельца
      when (l_insert_update_result = 0)
        then 3
      # Ошибка выполнения запроса
      else -1
    end;

end$$
delimiter ;

drop function if exists util.release_execution_lock;
delimiter $$
create function util.release_execution_lock(
  p_lock_name  varchar(250),
  p_lock_owner varchar(250),
  p_force tinyint unsigned
) returns tinyint
  comment 'Снимает блокировку выполнения для заданного наименования владельца или любого наименования владельца,
    если разрешено принудительное снятие блокировки, или статус блокировки не равен 1
    Механизм блокировок выполнения является альтернативой механизму get_lock(), т.к. до версии 5.7.5 mysql (согласно документации)
    сервера нельзя активировать более одной get_lock() в одной сессии.
    Механизм может быть использован для установки в одной сессии нескольких блокировок
    повторного одновременного выполнения задания/функции/процедуры.

    Параметры:
      p_lock_name   [not null] - Наименование блокировки;
      p_lock_owner  [nullable] - Наименование владельца блокировки;
      p_force       [nullable] - Принудительное снятие блокировки любого наименования владельца: 0 - запретить, 1- разрешить
    Возвращаемое значение:
      1    - Блокировка снята;
      2    - Блокировка установлена для другого наименования владельца;
      иначе:
        -1   - Ошибка выполнения запроса;
        -2   - Блокировка с указанным наименованием не создана;
        null - Не задано значение параметра p_lock_name'
begin
  declare l_lock_status tinyint unsigned;
  declare l_lock_owner  varchar(250);
  # Результат обновления таблицы util.t_execution_lock
  declare l_update_result tinyint;

  # Ошибка выполнения запроса
  declare exit handler for sqlexception
  begin
    call log.create_log(
      'util.release_execution_lock',
      4,
      concat(
        'Ошибка выполнения запроса',
        ', p_lock_name='     ,coalesce(p_lock_name,  'cast as null'),
        ', p_lock_owner='    ,coalesce(p_lock_owner, 'cast as null'),
        ', p_force='         ,coalesce(p_force,      'cast as null')
      )
    );
    #rollback;
    return -1;
  end;

  # Блокировка с указанным наименованием не создана;
  declare exit handler for not found
  begin
    call log.create_log(
      'util.release_execution_lock',
      1,
      concat(
        'Блокировка с указанным наименованием не создана',
        ', p_lock_name='     ,coalesce(p_lock_name,  'cast as null'),
        ', p_lock_owner='    ,coalesce(p_lock_owner, 'cast as null'),
        ', p_force='         ,coalesce(p_force,      'cast as null')
      )
    );
    #commit;
    return -2;
  end;

  call log.create_log(
    'util.release_execution_lock',
    1,
    concat(
      'p_lock_name='       ,coalesce(p_lock_name,  'cast as null'),
      ', p_lock_owner='    ,coalesce(p_lock_owner, 'cast as null'),
      ', p_force='         ,coalesce(p_force,      'cast as null')
    )
  );

  # Не задано значение параметра p_lock_name
  if(p_lock_name is null) then
    #commit;
    return null;
  end if;

  # Управление транзакциями (start, commit, rollback) поддерживатся в процедурах, но не функциях
  #start transaction;

  # Проверить существования блокировки с указанным наименованием, и заблокировать строку, если существует
  select t.execution_lock_status, t.execution_lock_owner
  into l_lock_status, l_lock_owner
  from util.t_execution_lock t
  where t.execution_lock_name = p_lock_name
  for update;

  if (l_lock_owner = p_lock_owner or p_force = 1 or l_lock_status <> 1) then
    update util.t_execution_lock t set t.execution_lock_status = 0 where t.execution_lock_name = p_lock_name;
    set l_update_result = row_count();
  else
    # Блокировка установлена для другого наименования владельца
    call log.create_log(
      'util.release_execution_lock',
      2,
      concat(
        'Блокировка установлена для другого наименования владельца',
        ', p_lock_name='     ,coalesce(p_lock_name,  'cast as null'),
        ', p_lock_owner='    ,coalesce(p_lock_owner, 'cast as null'),
        ', p_force='         ,coalesce(p_force,      'cast as null')
      )
    );
  end if;

  #commit;

  return
    case
      # Блокировка снята
      when (l_update_result in (0, 1)) then 1
      # Блокировка установлена для другого наименования владельца
      when (l_update_result is null) then 2
      # Ошибка выполнения
      else -1
    end;

end$$
delimiter ;

########################################################################################################################
# Механизм удаления устаревших данных
########################################################################################################################
drop procedure if exists estprod.clean_tables;
delimiter $$
create procedure estprod.clean_tables(p_days int)
  comment 'Удаляет устаревшие данные'
begin
  declare l_datetime_delete_upto datetime;
  # Общее время ожидания освобождения блокировки (в секундах), по истечении которого основное тело процедуры выполнено не будет
  declare l_lock_wait_timeout int;
  # Интервал проверки освобождения блокировки (в секундах)
  declare l_lock_wait_interval int;
  declare l_execution_lock_owner varchar(250);

  # В случае ошибки снять блокировку
  declare exit handler for sqlexception
  begin
    call log.create_log(
      l_execution_lock_owner,
      #error
      4,
      'handler for sqlexception'
    );
    do util.release_execution_lock('estprod.event_clean_tables', l_execution_lock_owner, 0);
    do util.release_execution_lock('estprod.event_optimize_tables', l_execution_lock_owner, 0);
  end;

  set l_execution_lock_owner = concat('estprod.clean_tables_', left(uuid(), 8));

  call log.create_log(
    l_execution_lock_owner,
    #info
    2,
    concat(' p_days=', p_days)
  );

  # Чистка данных старше p_days дней
  set l_datetime_delete_upto = date_sub(now(), interval p_days day);
  set l_lock_wait_timeout = 1200; # 20 мин
  set l_lock_wait_interval = 30;

  # Блокировать другие попытки запуска процедуры
  if (
    util.create_execution_lock('estprod.event_clean_tables', l_execution_lock_owner, l_lock_wait_timeout, l_lock_wait_interval) = 1
    and
    util.create_execution_lock('estprod.event_optimize_tables', l_execution_lock_owner, l_lock_wait_timeout, l_lock_wait_interval) = 1
  ) then
    # Чистка таблицы estprod.t_routes
    # Для myisam используется итерационное низкоприоритетное удаление строк,
    # т.к. выполнение операций последовательное с блокировками всей таблицы.
    # В очереди запросов приоритет имеют операции вставки. В данном случае
    # удаление строк должно производиться с низшим приоритетом, т.е. выполняться
    # только, когда нет других запросов (вставки, удаления, выборки и т. д.).
    # Таким образом, низкоприоритетный запрос удаления начинает выполняться,
    # когда в очереди нет других запросов, при этом все новые запросы поступающие в очередь
    # блокируются, поэтому используется итерационный подход.
    repeat
      # Начиная с версии mysql 5.6. выражение limit может задаваться локальной переменной типа int
      # до версии 5.6. - задается литералом или переменной процедуры/функции.
      # Используется индекс idx_rowdate
      delete low_priority from estprod.t_routes where rowdate < l_datetime_delete_upto limit 10000;
      until row_count() <= 0
    end repeat;

    # Чистка таблицы estprod.t_calls аналогична чистке t_routes
    repeat
      # Используется индекс idx_calldate
      delete low_priority from estprod.t_calls where calldate < l_datetime_delete_upto limit 1000;
      until row_count() <= 0
    end repeat;

    do util.release_execution_lock('estprod.event_clean_tables', l_execution_lock_owner, 0);
    do util.release_execution_lock('estprod.event_optimize_tables', l_execution_lock_owner, 0);
  end if;
end$$
delimiter ;

drop procedure if exists estprod.optimize_tables;
delimiter $$
create procedure estprod.optimize_tables()
  comment 'Оптимизирует таблицы'
begin
  # Общее время ожидания освобождения блокировки (в секундах), по истечении которого основное тело процедуры выполнено не будет
  declare l_lock_wait_timeout int;
  # Интервал проверки освобождения блокировки (в секундах)
  declare l_lock_wait_interval int;
  declare l_execution_lock_owner varchar(250);

  # В случае ошибки снять блокировку
  declare continue handler for sqlexception
  begin
    call log.create_log(
      l_execution_lock_owner,
      #error
      4,
      'handler for sqlexception'
    );
    do util.release_execution_lock('estprod.event_clean_tables', l_execution_lock_owner, 0);
    do util.release_execution_lock('estprod.event_optimize_tables', l_execution_lock_owner, 0);
  end;

  set l_execution_lock_owner = concat('estprod.clean_tables_', uuid());

  call log.create_log(
    l_execution_lock_owner,
    #info
    2,
    ''
  );

  set l_lock_wait_timeout = 18000; # 5 часов
  set l_lock_wait_interval = 60;

  # Блокировать другие попытки запуска процедуры
  if (
    util.create_execution_lock('estprod.event_clean_tables', l_execution_lock_owner, l_lock_wait_timeout, l_lock_wait_interval) = 1
    and
    util.create_execution_lock('estprod.event_optimize_tables', l_execution_lock_owner, l_lock_wait_timeout, l_lock_wait_interval) = 1
  ) then
    # Для myisam с фиксированной длиной столбцов оптимизация возвращает операционной системе место, освободившееся
    # после запросов delete, которые массово удаляют строки в больших таблицах. Оптимизация выполняет
    # перестроение табличного пространства данных и индексов, обновляет статистику и прочее,
    # в целом приводит к ускорению запросов в сравнении с неоптимизированной таблицей.
    # При оптимизации таблица блокируется и активно задействуются ресурсы cpu и I/O дисковой подсистемы.
    # В общем случае, (к которому относится эта процедура) ошибочно предположение: чем больше строк было удалено,
    # тем дольше выполняется оптимизация. Пример, после удаления 10 млн. строк оптимизация занимает ~ 230 сек,
    # а после удаления 2 млн. строк оптимизация занимает ~ 240 сек, в другой раз после удаления 2 млн. строк
    # оптимизация может занять ~ 80 сек. В целом длительность оптимизации зависит от фрагментированности хранения
    # данных и индексов.
    optimize table estprod.t_routes;
    optimize table estprod.t_calls;
    do util.release_execution_lock('estprod.event_clean_tables', l_execution_lock_owner, 0);
    do util.release_execution_lock('estprod.event_optimize_tables', l_execution_lock_owner, 0);
  end if;

end$$
delimiter ;

# Периодические задания
drop event if exists estprod.event_clean_tables;
delimiter $$
create event estprod.event_clean_tables
  on schedule every 1 day starts str_to_date('2018-06-27 17:38:00', '%Y-%m-%d %H:%i:%s')
  comment 'Удаление устаревших данных'
  do
    begin
      # Задание будет считаться выполненным (в information_schema.events поле last_executed обновится)
      # сразу после запуска процедуры, независимо от её результата выполнения
      # Чистка данных старше 60 дней
      do estprod.clean_tables(60);
    end;
    $$
delimiter ;

drop event if exists estprod.event_optimize_tables;
delimiter $$
create event estprod.event_optimize_tables
  on schedule every 1 month starts str_to_date('2018-06-28 17:58:05', '%Y-%m-%d %H:%i:%s')
  comment 'Оптимизирует таблицы'
  do
    begin
      # Задание будет считаться выполненным (в information_schema.events поле last_executed обновится)
      # сразу после запуска процедуры, независимо от её результата выполнения
      do estprod.optimize_tables();
    end;
    $$
delimiter ;
