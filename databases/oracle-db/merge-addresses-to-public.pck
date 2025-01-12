create or replace package mainaddress is
/**
 * Пакет для работы с адресами.
 * Ключевая логика сопоставления/слияния адресных объектов системы и объектов из внешних источников 
 *   находится в addobj_similarity(..) и gis_data_preparing(…).
 */

/** Тип для наполнения словаря сокращений наименований адресных объектов */
subtype t_socr_dict is main_addobj_socr_dict%rowtype;
/** Тип для хранения словаря сокращений наименований адресных объектов */
type tbl_socr_dict is table of mainaddress.t_socr_dict;

/**
 * Тип для сопоставления адресных объектов из ГИС с адресными объектами из ФИАС
 *
 * @param match_weight            {integer}  Сумма всех весов условий, по которым сопоставились адресные объекты.
 *                                           Больше вес - строже условие - больше вероятность полной идентичности объектов
 * @param id_gis2kladr            {integer}  ID записи в постоянной таблице сопоставления улиц main_gis2kladr_street
 * @param id_settlement           {integer}  ID населенного пункта из main_settlement, присвоенный записи в
 *                                           main_gis2kladr_street после сопоставления
 * @param id_street               {varchar2} ID улицы из main_street, присвоенный записи в main_gis2kladr_street после
 *                                           сопоставления
 * @param gis_city_name           {varchar2} Наименование населенного пункта / города, данные из ГИС
 * @param gis_city_name_fmt       {varchar2} Наименование населенного пункта / города после форматирования
 * @param gis_city_socr_fmt       {varchar2} Сокращение, выделенное из наименования населенного пункта / города
 * @param gis_reg_name_fmt        {varchar2} Наименование района-родителя/города-спутника, которому принадлежит
 *                                           населенный пункт / город, указанный в поле gis_city_name.
 *                                           Выделяется из наименования населенного пункта / города при форматировании
 * @param gis_reg_socr_fmt        {varchar2} Сокращение, выделенное из наименования района-родителя/города-спутника
 *                                           при форматировании
 * @param gis_sttl_name_fmt       {varchar2} Наименование населенного пункта (часть города-спутника), выделенное из
 *                                           наименования улицы
 * @param gis_sttl_socr_fmt       {varchar2} Сокращение, выделенное из наименования населенного пункта (города-спутника)
 * @param city_name               {varchar2} Наименование города-спутника, которому принадлежит населенный пункт из main_town
 * @param city_socr               {varchar2} Сокращение наименования города-спутника из main_town
 * @param sttl_name               {varchar2} Наименование населенного пункта из main_settlement
 * @param sttl_socr               {varchar2} Сокращение наименования населенного пункта из main_settlement
 * @param sttl_name_fmt           {varchar2} Наименование населенного пункта из main_settlement после форматирования
 * @param sttl_socr_fmt           {varchar2} Сокращение, выделенное из наименования населенного пункта из main_settlement
 * @param sttl_name_parent_fmt    {varchar2} Наименование района-родителя/города-спутника, которому принадлежит
 *                                           населенный пункт из main_settlement, указанный в поле sttl_name.
 *                                           Выделяется из наименования населенного пункта при форматировании
 * @param sttl_parent_socr_fmt    {varchar2} Сокращение, выделенное из наименования района-родителя/города-спутника
 *                                           при форматировании
 * @param sttl_of_street_name_fmt {varchar2} Наименование населенного пункта (часть города-спутника), выделенное
 *                                           из наименования улицы
 * @param sttl_of_street_socr_fmt {varchar2} Сокращение, выделенное из наименования населенного пункта (города-спутника)
 * @param gis_street_name         {varchar2} Наименование улицы, данные из ГИС
 * @param gis_street_name_fmt     {varchar2} Наименование улицы из ГИС после форматирования
 * @param gis_street_socr_fmt     {varchar2} Сокращение, выделенное из наименования улицы из ГИС
 * @param street_name             {varchar2} Наименование улицы из main_street
 * @param street_socr             {varchar2} Сокращение наименования улицы из main_street
 * @param street_name_fmt         {varchar2} Наименование улицы из main_street после форматирования
 * @param street_socr_fmt         {varchar2} Сокращение наименования улицы из main_street после форматирования
 */
type t_crl$gis2kladr_street is record(
//
);

/** Табличное представление типа t_crl$gis2kladr_street */
type tbl_crl$gis2kladr_street is table of t_crl$gis2kladr_street;

/**
 * Форматирует и создает производные данные адресных объектов мегаполиса, загружаемых из постоянной таблицы сопоставлений
 * во временную
 *
 * @param id_city_  [not null] ID мегаполиса
 *
 * @return [nullable] Возвращает форматированные и производные данные адресных объектов в виде табличного представления
 */
function format_gis2kladr_street(id_city_ integer) return mainaddress.tbl_crl$gis2kladr_street pipelined;

/**
 * Форматирует и создает производные данные адресных объектов мегаполиса, загружаемые из постоянных таблиц адресных
 * объектов системы во временную таблицу сопоставлений
 *
 * @param id_city_  [not null] ID мегаполиса
 *
 * @return [nullable] Возвращает форматированные и производные данные адресных объектов в виде табличного представления
 */
function format_settlement_street(id_city_ integer) return mainaddress.tbl_crl$gis2kladr_street pipelined;

/**
 * Сопоставляет данные адресных объектов, загружаемых из постоянной таблицы сопоставлений во временную,
 * рассчитывая общий вес условий сопоставления
 *
 * @param id_city_  [not null] ID мегаполиса
 *
 * @return [nullable] Возвращает структуру типа mainaddress.tbl_crl$gis2kladr_street
 */
function addobj_similarity(id_city_ integer) return mainaddress.tbl_crl$gis2kladr_street pipelined;

/**
 * Сопоставляет адресные объекты (населенный пункт и улица) из ГИС с адресными объектами системы,
 * обновляя значения в столбцах kladr_id_settlement и kladr_id_street в таблице main_gis2kladr_street
 *
 * @param id_city_  [not null] ID мегаполиса
 */
procedure gis_data_preparing(id_city_ integer);

end mainaddress;
/
create or replace package body mainaddress is

/**
 * Загружает данные справочника сокращений наименований адресных объектов в коллекцию типа mainaddress.t_socr_dict
 *
 * @param id_socr_type_ [not null] ID типа сокращений наименований адресных объектов.
 *                                   Возможные значения:
 *                                     mainaddress.SOCR_TYPE_STTL   - сокращения наименований населенных пунктов,
 *                                     mainaddress.SOCR_TYPE_STREET - сокращения наименований улиц,
 *                                     mainaddress.SOCR_TYPE_MISC   - прочие сокращения
 *
 * @return [nullable] структура типа mainaddress.t_socr_dict
 */
function get_addrobj_socr_dict(id_socr_type_ integer) return mainaddress.tbl_socr_dict is
  l_dict mainaddress.tbl_socr_dict;
begin
  assert.assert_not_null(value_ => id_socr_type_, value_name_ => 'id_socr_type_');
  select * bulk collect into l_dict from main_addobj_socr_dict s where s.id_socr_type = id_socr_type_;
  return l_dict;
end get_addrobj_socr_dict;

/**
 * Выделяет из строки полное наименование адресного объекта и возвращает его наименование и сокращение по словарю
 * сокращений. Если не найдено сокращение любой длины в конце строки полного наименования, то производится поиск
 * в начале строки. Выбирается самое длинное сокращение.
 *
 * @param addobj_name_raw_ [nullable] Строка, в которой производится поиск полного наименования адресного объекта
 * @param socr_dict_       [not null] Словарь сокращений наименований адресных объектов
 * @param addobj_type_     [not null] Тип адресного объекта
 * @param out_name_        [nullable] Наименование адресного объекта
 * @param out_socr_        [nullable] Сокращение наименования адресного объекта
 *
 * @return [nullable] Присваивает значения out параметрам
 */
procedure parse_addobj_name(
  addobj_name_raw_ varchar2,
  addobj_type_     integer,
  socr_dict_       mainaddress.tbl_socr_dict,
  out_name_    out varchar2,
  out_socr_    out varchar2
) is
begin
  assert.assert_not_null(value_ => addobj_type_, value_name_ => 'addobj_type_');
  assert.assert_true(
    value_      => (socr_dict_ is not null and socr_dict_ is not empty),
    value_name_ => 'socr_dict_',
    comment_    => 'Словарь сокращений наименований адресных объектов не должен быть пустым');

  --Получение полного наименования (наименование + сокращение) адресного объекта указанного типа из переданной строки
  if (addobj_name_raw_ is not null) then
    <<parse_name>>
    declare
      --Шаблон поиска и шаблон замены: удалить подстроку, ограниченную круглыми скобками, включительно
      PATTERN_RM_IN_RBRACKETS     constant util.string := '\((.*)';
      REPLACEMENT_RM_IN_RBRACKETS constant util.string := '';
      --Шаблон поиска и шаблон замены: найти первое вхождение подстроки, ограниченной слева круглой открывающей скобкой,
      --справа запятой или круглой закрывающей скобкой
      PATTERN_IN_RBRACKETS_COMMA     constant util.string := '^.*?\((.*?)[,\)].*?$';
      REPLACEMENT_IN_RBRACKETS_COMMA constant util.string := '\1';
      l_fullname   util.string;
      l_socr_end   util.string;
      l_socr_begin util.string;
    begin
      l_fullname :=
        case
          when (addobj_type_ in (
              mainaddress.ADDOBJ_TYPE_GIS_STTL,
              mainaddress.ADDOBJ_TYPE_GIS_STREET,
              mainaddress.ADDOBJ_TYPE_STTL,
              mainaddress.ADDOBJ_TYPE_STREET)
          ) then
            regexp_replace(
              srcstr     => addobj_name_raw_,
              pattern    => PATTERN_RM_IN_RBRACKETS,
              replacestr => REPLACEMENT_RM_IN_RBRACKETS)
          when (addobj_type_ in (
            mainaddress.ADDOBJ_TYPE_GIS_REG,
            mainaddress.ADDOBJ_TYPE_REG,
            mainaddress.ADDOBJ_TYPE_STTL_STREET,
            mainaddress.ADDOBJ_TYPE_STTL_STREET)
          ) then
            regexp_replace(
              srcstr     => addobj_name_raw_,
              pattern    => PATTERN_IN_RBRACKETS_COMMA,
              replacestr => REPLACEMENT_IN_RBRACKETS_COMMA)
          else addobj_name_raw_
        end;
      l_fullname := coalesce(trim(l_fullname), addobj_name_raw_);
      --Получение наименования и сокращения адресного объекта из полного наименования
      for i in socr_dict_.first .. socr_dict_.last loop
        --поиск сокращения в конце строки
        if (
          l_fullname like '% '||socr_dict_(i).socr
          and length(socr_dict_(i).socr) > coalesce(length(l_socr_end), 0)
        ) then
          l_socr_end := socr_dict_(i).socr_base;
        --поиск сокращения в начале строки, если в конце строки сокращение не обнаружено
        elsif (
          l_fullname like socr_dict_(i).socr||' %'
          and length(socr_dict_(i).socr) > coalesce(length(l_socr_begin), 0)
        ) then
          l_socr_begin := socr_dict_(i).socr_base;
        end if;
      end loop;
      if (l_socr_end is not null) then
        out_name_ := trim(replace(l_fullname, ' '||l_socr_end));
        out_socr_ := l_socr_end;
      elsif (l_socr_begin is not null) then
        out_name_ := trim(replace(l_fullname, l_socr_begin||' '));
        out_socr_ := l_socr_begin;
      else
        out_name_ := l_fullname;
        out_socr_ := null;
      end if;
    end parse_name;
  else
    out_name_ := null;
    out_socr_ := null;
  end if;
end parse_addobj_name;

function format_gis2kladr_street(id_city_ integer) return mainaddress.tbl_crl$gis2kladr_street pipelined is
  --Фильтрация адресных объектов, загружаемых во временные таблицы. Фильтрация мусорных данных при загрузке во временную
  --таблицу сопоставлений в поле gis_city_name из ГИС OSM
  DATA_FILTER_OSM constant util.sqlstring := 'задать %';
  l_sttl_dict   mainaddress.tbl_socr_dict;
  l_street_dict mainaddress.tbl_socr_dict;
  l_result      mainaddress.t_crl$gis2kladr_street;
  /**
   * Удаляет в строке нежелательные символы, приводя оставшиеся к нижнему регистру
   *
   * @param l_srcstr_    [nullable] Исходная строка
   *
   * @return [nullable] Измененная строка
   */
  function lower_remove_chars(l_srcstr_ varchar2) return varchar2 is
  begin
    return (
      case
        when (l_srcstr_ is not null) then
          lower(util.replacestr(
            str_         => l_srcstr_,
            searchstr1_  => '«',
            replacestr1_ => '',
            searchstr2_  => '»',
            replacestr2_ => '',
            searchstr3_  => '"',
            replacestr3_ => '',
            --удаление неразрывного пробела
            searchstr4_  => ' ',
            replacestr4_  => ' '))
        else null
      end);
  end lower_remove_chars;
begin
  assert.assert_not_null(value_ => id_city_, value_name_ => 'id_city_');
  --Загрузка словарей сокращений наименований адресных объектов
  l_sttl_dict   := mainaddress.get_addrobj_socr_dict(id_socr_type_ => mainaddress.SOCR_TYPE_STTL);
  l_street_dict := mainaddress.get_addrobj_socr_dict(id_socr_type_ => mainaddress.SOCR_TYPE_STREET);
  for i in (
    select
      s.id_gis2kladr,
      s.kladr_id_settlement  id_settlement,
      s.gis_city_name,
      s.gis_street_name      gis_street_name
    from main_gis2kladr_street s
    where s.kladr_id_city = id_city_
      and s.kladr_id_street is null
      and trim(lower(s.gis_city_name)) not like DATA_FILTER_OSM
  ) loop

    --Удаление/замена нежелательных символов для всех форматируемых полей
    l_result.gis_city_name   := mainaddress.format_gis2kladr_street.lower_remove_chars(l_srcstr_ => i.gis_city_name);
    l_result.gis_street_name := mainaddress.format_gis2kladr_street.lower_remove_chars(l_srcstr_ => i.gis_street_name);

    --Запись форматированного наименования населенного пункта и его сокращения в отдельные поля
    mainaddress.parse_addobj_name(
      addobj_name_raw_ => l_result.gis_city_name,
      addobj_type_     => mainaddress.ADDOBJ_TYPE_GIS_STTL,
      socr_dict_       => l_sttl_dict,
      out_name_        => l_result.gis_city_name_fmt,
      out_socr_        => l_result.gis_city_socr_fmt);

    --Запись форматированного наименования города (районного уровня) и его сокращения из наименования населенного пункта
    --в отдельные поля
    mainaddress.parse_addobj_name(
      addobj_name_raw_ => l_result.gis_city_name,
      addobj_type_     => mainaddress.ADDOBJ_TYPE_GIS_REG,
      socr_dict_       => l_sttl_dict,
      out_name_        => l_result.gis_reg_name_fmt,
      out_socr_        => l_result.gis_reg_socr_fmt);

    --Запись форматированного наименования улицы и его сокращения в отдельные поля
    mainaddress.parse_addobj_name(
      addobj_name_raw_ => l_result.gis_street_name,
      addobj_type_     => mainaddress.ADDOBJ_TYPE_GIS_STREET,
      socr_dict_       => l_street_dict,
      out_name_        => l_result.gis_street_name_fmt,
      out_socr_        => l_result.gis_street_socr_fmt);

    --Запись производного форматированного наименования населенного пункта и его сокращения из наименования улицы
    --в отдельные поля
    mainaddress.parse_addobj_name(
      addobj_name_raw_ => l_result.gis_street_name,
      addobj_type_     => mainaddress.ADDOBJ_TYPE_GIS_STTL_STREET,
      socr_dict_       => l_sttl_dict,
      out_name_        => l_result.gis_sttl_name_fmt,
      out_socr_        => l_result.gis_sttl_socr_fmt);

    --Передача неформатируемых полей
    l_result.id_settlement := i.id_settlement;
    l_result.id_gis2kladr  := i.id_gis2kladr;

    pipe row(l_result);
  end loop;
  return;
end format_gis2kladr_street;

function format_settlement_street(id_city_ integer) return mainaddress.tbl_crl$gis2kladr_street pipelined is
  l_sttl_dict   mainaddress.tbl_socr_dict;
  l_street_dict mainaddress.tbl_socr_dict;
  l_result      mainaddress.t_crl$gis2kladr_street;
begin
  assert.assert_not_null(value_ => id_city_, value_name_ => 'id_city_');
  --Загрузка словарей сокращений наименований адресных объектов
  l_sttl_dict   := mainaddress.get_addrobj_socr_dict(id_socr_type_ => mainaddress.SOCR_TYPE_STTL);
  l_street_dict := mainaddress.get_addrobj_socr_dict(id_socr_type_ => mainaddress.SOCR_TYPE_STREET);
  for i in (
    select
      sttl.id_settlement    id_settlement,
      t.city_name           city_name,
      t.socr                city_socr,
      sttl.settlement_name  sttl_name,
      sttl.socr             sttl_socr,
      str.id_street         id_street,
      str.street_name       street_name,
      str.socr              street_socr
    from main_town t
      join main_settlement sttl on (t.id_city = sttl.id_city)
      join main_street     str  on (sttl.id_settlement = str.id_settlement)
    where t.id_main_city = id_city_
      and t.delete_dt is null
      and sttl.delete_dt is null
      and str.delete_dt is null
  ) loop
    l_result.city_name   := lower(i.city_name);
    l_result.city_socr   := lower(i.city_socr);
    l_result.sttl_name   := lower(i.sttl_name);
    l_result.sttl_socr   := lower(i.sttl_socr);
    l_result.street_name := lower(i.street_name);
    l_result.street_socr := lower(i.street_socr);

    --Запись форматированного наименования населенного пункта и его сокращения в отдельные поля
    mainaddress.parse_addobj_name(
      addobj_name_raw_ => l_result.sttl_name,
      addobj_type_     => mainaddress.ADDOBJ_TYPE_STTL,
      socr_dict_       => l_sttl_dict,
      out_name_        => l_result.sttl_name_fmt,
      out_socr_        => l_result.sttl_socr_fmt);

    --Запись форматированного наименования города (районного уровня) и его сокращения из наименования населенного пункта
    --в отдельные поля
    mainaddress.parse_addobj_name(
      addobj_name_raw_ => l_result.sttl_name,
      addobj_type_     => mainaddress.ADDOBJ_TYPE_REG,
      socr_dict_       => l_sttl_dict,
      out_name_        => l_result.sttl_name_parent_fmt,
      out_socr_        => l_result.sttl_parent_socr_fmt);

    --Запись форматированного наименования улицы и его сокращения в отдельные поля
    mainaddress.parse_addobj_name(
      addobj_name_raw_ => l_result.street_name,
      addobj_type_     => mainaddress.ADDOBJ_TYPE_STREET,
      socr_dict_       => l_street_dict,
      out_name_        => l_result.street_name_fmt,
      out_socr_        => l_result.street_socr_fmt);

    --Запись форматированного наименования населенного пункта и его сокращения из наименования улицы в отдельные поля
    mainaddress.parse_addobj_name(
      addobj_name_raw_ => l_result.street_name,
      addobj_type_     => mainaddress.ADDOBJ_TYPE_STTL_STREET,
      socr_dict_       => l_sttl_dict,
      out_name_        => l_result.sttl_of_street_name_fmt,
      out_socr_        => l_result.sttl_of_street_socr_fmt);

    --Передача неформатируемых полей
    l_result.id_settlement := i.id_settlement;
    l_result.id_street     := i.id_street;
    pipe row (l_result);
  end loop;
  return;
end format_settlement_street;

function addobj_similarity(id_city_ integer) return mainaddress.tbl_crl$gis2kladr_street pipelined is
  l_result mainaddress.t_crl$gis2kladr_street;
  /**
   * Вычисляет суммарный вес всех выполненных условий сопоставления одного адресного объекта
   *
   * @param l_rec_  [nullable] запись (строка временной таблицы сопоставлений) со значениями для проверки условий сопоставления
   *
   * @return [nullable] суммарный вес всех выполненных условий сопоставления
   */
  function calc_match_weight(l_rec_ mainaddress.t_crl$gis2kladr_street) return integer is
    --Вес каждого условия является уникальным.
    --Суммарный вес любой комбинации условий является уникальным.
    --Больше вес - строже условие - больше вероятность полной идентичности объектов.
    --Вес задается целым числом, представляющим группы чисел. Каждая группа сформирована четырьмя цифрами.
    --Нумерация групп - справа-налево:
    --  Первая группа    - незарезервирована
    --  Вторая           - населенные пункты
    --  Третья           - регионы (могут соответствовать main_town)
    --  Четвертая        - фиктивные населенные пункты
    --  Пятая            - улицы
    --  Шестая и Седьмая - штраф (отрицательный вес) за несовпадение наименований или сокращений наименований адресных объектов
    --Нумерация цифр в каждой группе (только [1-5] группы) - справа-налево:
    --  Первая и вторая отведены под вес условия сопоставления по сокращению наименований объектов.
    --  Третья и четвертая - по наименованию объектов.
    --Нумерация цифр в группе 6 - справа-налево:
    --  Первая отведена под штраф (отрицательный вес) за несовпадение сокращений наименований улиц
    --  Вторая отведена под штраф (отрицательный вес) за несовпадение сокращений наименований для фиктивных нас. пунктов.
    --  Третья отведена под штраф (отрицательный вес) за несовпадение сокращений наименований нас. пунктов.
    --  Четвертая отведена под штраф (отрицательный вес) за несовпадение сокращений наименований регионов.
    --Нумерация цифр в группе 7 - справа-налево:
    --  Первая отведена под штраф (отрицательный вес) за несовпадение наименований для фиктивных нас. пунктов.
    --  Вторая отведена под штраф (отрицательный вес) за несовпадение наименований нас. пунктов.
    --  Третья отведена под штраф (отрицательный вес) за несовпадение наименований регионов.
    --  Четвертая отведена под штраф (отрицательный вес) за несовпадение наименований улиц;
    --    сейчас предварительной фильтрацией отсекаются записи с несовпавшими наименованиями улиц.
    --Правила именования весов условий сопоставления:
    --G_         - Префикс операнда предиката сопоставления для объектов из ГИС,
    --             в наименовании/сокращении объекта соответствует префиксу gis.
    --S_         - Префикс операнда предиката сопоставления для объектов из системы EST.
    --$          - Разделитель префиксов, в предикате символизирует оператор сравнения объектов из разных источников.
    --STR        - Часть наименования операнда предиката для улиц, в наименовании/сокращении объекта соответствует street
    --CITY       - Операнд предиката для населенного пункта / города.
    --           - Для ГИС объектов, описываемых полями gis_city_name и его производными, могут соответствовать объекты из
    --           - системы EST, описываемых полями city_name или sttl_name(settlement_name).
    --STTL       - Часть наименования операнда предиката для населенного пункта,
    --             в наименовании/сокращении объекта соответствует sttl.
    --REG        - Часть наименования операнда предиката для региона, в наименовании/сокращении объекта соответствует reg.
    --N          - Часть наименования операнда для наименований объектов. В наименовании объекта соответствует name
    --S          - Часть наименования операнда для сокращений наименований объектов, соответствует socr
    --F          - Часть (постфикс) наименования операнда предиката для объектов.
    --             В наименовании/сокращении объекта соответствует fmt
    --NL         - Значение наименования/сокращения не определено (null)
    --FAL        - Совпадение не установлено (значения не равны)
    --_          - Разделитель
    --Пример:
    --  G_CITY_NF$S_CITY_N         = {gis_city_name_fmt} оператор сравнения {city_name}
    --  G_STR_SF_FAL$S_STR_SSF_FAL = gis_street_socr_fmt не равен, ни street_socr, ни street_socr_fmt
    --  G_STR_SF$S_STR_S_NL        = gis_street_socr_fmt определено (не null), street_socr не определено (null)

    --Наименования и значения весов условий сопоставления наименований/сокращений улиц
    -- совпадение неформатированных наименований улиц из ГИС и системы
    G_STR_N$S_STR_N                constant integer :=           90000000000000000000; --            9000 0000 0000 0000 0000
    -- совпадение форматированных наименований улиц из ГИС и системы
    G_STR_NF$S_STR_NF              constant integer :=           80000000000000000000; --            8000 0000 0000 0000 0000
    -- совпадение форматированного сокращения улицы из ГИС и неформатированного из системы
    G_STR_SF$S_STR_S               constant integer :=             900000000000000000; --              90 0000 0000 0000 0000
    -- совпадение форматированного сокращения улицы из ГИС и системы
    G_STR_SF$S_STR_SF              constant integer :=             800000000000000000; --              80 0000 0000 0000 0000
    -- неустановленное форматированное сокращение улицы из ГИС и неформатированное сокращение улицы из системы
    G_STR_SF_NL$S_STR_S            constant integer :=             700000000000000000; --              70 0000 0000 0000 0000
    -- неустановленное форматированное сокращение улицы из ГИС и форматированное сокращение улицы из системы
    G_STR_SF_NL$S_STR_SF           constant integer :=             600000000000000000; --              60 0000 0000 0000 0000
    -- форматированное сокращение улицы из ГИС и неустановленное неформатированное сокращение улицы из системы
    G_STR_SF$S_STR_S_NL            constant integer :=             500000000000000000; --              50 0000 0000 0000 0000
    -- форматированное сокращение улицы из ГИС и неустановленное форматированное сокращение улицы из системы
    G_STR_SF$S_STR_SF_NL           constant integer :=             400000000000000000; --              40 0000 0000 0000 0000
    -- неустановленное форматированное сокращение улицы из ГИС и
    -- неустановленные форматированное и неформатированное сокращения улицы из системы
    G_STR_SF_NL$S_STR_SSF_NL       constant integer :=             100000000000000000; --              10 0000 0000 0000 0000
    -- несовпадение форматированного сокращения улицы из ГИС и
    -- форматированного и неформатированного сокращений улиц из системы
    G_STR_SF_FAL$S_STR_SSF_FAL     constant integer :=         -100000000000000000000; --         -1 0000 0000 0000 0000 0000

    --Наименования и значения весов условий сопоставления наименований/сокращений городов для фиктивных населенных пунктов (ФНП)
    -- совпадение неформатированного наименования города/нас.п. из ГИС и неформатированного наименования города для ФНП из системы
    G_CITY_N$S_CITY_N              constant integer :=              90000000000000000; --                 9000 0000 0000 0000
    -- совпадение форматированного наименования города/нас.п. из ГИС и неформатированного наименования города для ФНП из системы
    G_CITY_NF$S_CITY_N             constant integer :=              80000000000000000; --                 8000 0000 0000 0000
    -- несовпадение неформатированного и форматированного наименований города/нас.п. из ГИС и
    -- неформатированного наименования города для ФНП из системы
    G_CITY_NNF_FAL$S_CITY_N_FAL    constant integer :=     -1000000000000000000000000; --    -1 0000 0000 0000 0000 0000 0000
    -- совпадение форматированного сокращения города/нас.п. из ГИС и неформатированного сокращения города для ФНП из системы
    G_CITY_SF$S_CITY_S             constant integer :=                900000000000000; --                   90 0000 0000 0000
    -- неустановленное форматированное сокращение города/нас.п. из ГИС и неформатированное сокращение города для ФНП из системы
    G_CITY_SF_NL$S_CITY_S          constant integer :=                800000000000000; --                   80 0000 0000 0000
    -- форматированное сокращение города/нас.п. из ГИС и неустановленное форматированное сокращение города для ФНП из системы
    G_CITY_SF$S_CITY_S_NL          constant integer :=                700000000000000; --                   70 0000 0000 0000
    -- неустановленное форматированное сокращение города/нас.п. из ГИС и
    -- неустановленное неформатированное сокращение города для ФНП из системы
    G_CITY_SF_NL$S_CITY_S_NL       constant integer :=                600000000000000; --                   60 0000 0000 0000
    -- несовпадение форматированного сокращения города/нас.п. из ГИС и
    -- форматированного и неформатированного сокращений города для ФНП из системы
    G_CITY_SF_FAL$S_CITY_S_FAL     constant integer :=        -1000000000000000000000; --        -10 0000 0000 0000 0000 0000

    --Наименования и значения весов условий сопоставления наименований/сокращений регионов
    -- совпадение форматированного наименования региона из ГИС и неформатированного наименования города из системы
    G_REG_NF$S_CITY_N              constant integer :=                 90000000000000; --                      9000 0000 0000
    -- несовпадение форматированного наименования региона из ГИС и неформатированного наименования города из системы
    G_REG_NF_FAL$S_CITY_N_FAL      constant integer :=  -100000000000000000000000000; --  - 100 0000 0000 0000 0000 0000 0000
    -- совпадение форматированного сокращения региона из ГИС и неформатированного сокращения города из системы
    G_REG_SF$S_CITY_S              constant integer :=                   900000000000; --                        90 0000 0000
    -- неустановленное форматированное сокращение региона из ГИС и неформатированное сокращение города из системы
    G_REG_SF_NL$S_CITY_S           constant integer :=                   800000000000; --                        80 0000 0000
    -- форматированное сокращение региона из ГИС и неустановленное неформатированное сокращение города из системы
    G_REG_SF$S_CITY_S_NL           constant integer :=                   700000000000; --                        70 0000 0000
    -- неустановленное форматированное сокращение региона из ГИС и неустановленное неформатированное сокращение города из системы
    G_REG_SF_NL$S_CITY_S_NL        constant integer :=                   600000000000; --                        60 0000 0000
    -- несовпадение форматированного сокращения региона из ГИС и неформатированного сокращений города из системы
    G_REG_SF_FAL$S_CITY_S_FAL      constant integer :=      -100000000000000000000000; --      -1000 0000 0000 0000 0000 0000

    --Наименования и значения весов условий сопоставления наименований/сокращений населенных пунктов
    -- совпадение неформатированного наименования города/нас.п. из ГИС и неформатированного наименования нас.п. из системы
    G_CITY_N$S_STTL_N              constant integer :=                    90000000000; --                           9000 0000
    -- совпадение форматированного наименования города/нас.п. из ГИС и неформатированного наименования нас.п. из системы
    G_CITY_NF$S_STTL_N             constant integer :=                    80000000000; --                           8000 0000
    -- совпадение неформатированного наименования города/нас.п. из ГИС и форматированного наименования нас.п. из системы
    G_CITY_N$S_STTL_NF             constant integer :=                    70000000000; --                           7000 0000
    -- совпадение форматированного наименования города/нас.п. из ГИС и форматированного наименования нас.п. из системы
    G_CITY_NF$S_STTL_NF            constant integer :=                    60000000000; --                           6000 0000
    -- несовпадение неформатированного и форматированного наименований города/нас.п. из ГИС и
    -- неформатированного и форматированного наименований нас.п. из системы
    G_CITY_NNF_FAL$S_STTL_NNF_FAL   constant integer :=   -10000000000000000000000000; --   -10 0000 0000 0000 0000 0000 0000
    -- совпадение форматированного сокращения города/нас.п. из ГИС и неформатированного сокращения нас.п. из системы
    G_CITY_SF$S_STTL_S              constant integer :=                     900000000; --                             90 0000
    -- совпадение форматированного сокращения города/нас.п. из ГИС и форматированного сокращения нас.п. из системы
    G_CITY_SF$S_STTL_SF             constant integer :=                     800000000; --                             80 0000
    -- неустановленное форматированное сокращение города/нас.п. из ГИС и
    -- неформатированное сокращение нас.п. из системы
    G_CITY_SF_NL$S_STTL_S           constant integer :=                     700000000; --                             70 0000
    -- форматированное сокращение города/нас.п. из ГИС и
    -- неустановленное неформатированное сокращение нас.п. из системы
    G_CITY_SF$S_STTL_S_NL           constant integer :=                     600000000; --                             60 0000
    -- форматированное сокращение города/нас.п. из ГИС и
    -- неустановленные форматированное и неформатированное сокращения нас.п. из системы
    G_CITY_SF$S_STTL_SSF_NL         constant integer :=                     500000000; --                             50 0000
    -- неустановленное форматированное сокращение города/нас.п. из ГИС и
    -- неустановленное неформатированное и установленное форматированное сокращения нас.п. из системы
    G_CITY_SF_NL$S_STTL_S_NL_SF     constant integer :=                     400000000; --                             40 0000
    -- неустановленное форматированное сокращение города/нас.п. из ГИС и
    -- неустановленные форматированное и неформатированное сокращения нас.п. из системы
    G_CITY_SF_NL$S_STTL_SSF_NL      constant integer :=                     300000000; --                             30 0000
    -- несовпадение форматированного сокращения города/нас.п. из ГИС и
    -- форматированного и неформатированного сокращений нас.п. из системы
    G_CITY_SF_FAL$S_STTL_SSF_FAL    constant integer :=      -10000000000000000000000; --       -100 0000 0000 0000 0000 0000

    l_match_weight integer := 0;
  begin
    --1. Сравнение улиц
    --1.1. Сравнение наименования улицы из ГИС и наименования из ФИАС
    --1.1.1. неформатированные наименования
    if (l_rec_.gis_street_name = l_rec_.street_name) then
      l_match_weight := l_match_weight + G_STR_N$S_STR_N;
    --1.1.2. форматированные наименования
    elsif (l_rec_.gis_street_name_fmt = l_rec_.street_name_fmt) then
      l_match_weight := l_match_weight + G_STR_NF$S_STR_NF;
    end if;
    --1.2. Сравнение сокращений наименований улиц
    if (l_rec_.gis_street_socr_fmt = l_rec_.street_socr) then
      l_match_weight := l_match_weight + G_STR_SF$S_STR_S;
    elsif (l_rec_.gis_street_socr_fmt = l_rec_.street_socr_fmt) then
      l_match_weight := l_match_weight + G_STR_SF$S_STR_SF;
    elsif (coalesce(l_rec_.gis_street_socr_fmt, l_rec_.street_socr) = l_rec_.street_socr) then
      l_match_weight := l_match_weight + G_STR_SF_NL$S_STR_S;
    elsif (coalesce(l_rec_.gis_street_socr_fmt, l_rec_.street_socr_fmt) = l_rec_.street_socr_fmt) then
      l_match_weight := l_match_weight + G_STR_SF_NL$S_STR_SF;
    elsif (coalesce(l_rec_.street_socr, l_rec_.gis_street_socr_fmt) = l_rec_.gis_street_socr_fmt) then
      l_match_weight := l_match_weight + G_STR_SF$S_STR_S_NL;
    elsif (coalesce(l_rec_.street_socr_fmt, l_rec_.gis_street_socr_fmt) = l_rec_.gis_street_socr_fmt) then
      l_match_weight := l_match_weight + G_STR_SF$S_STR_SF_NL;
    elsif (not util.is_distinct_from(
      value1_ => coalesce(l_rec_.gis_street_socr_fmt, l_rec_.street_socr, l_rec_.street_socr_fmt),
      value2_ => coalesce(l_rec_.street_socr, l_rec_.street_socr_fmt))
    ) then
      l_match_weight := l_match_weight + G_STR_SF_NL$S_STR_SSF_NL;
    else
      l_match_weight := l_match_weight + G_STR_SF_FAL$S_STR_SSF_FAL;
    end if;
    --2. Сравнение населенных пунктов с учетом городов/регионов
    --2.1. сравнение фиктивных населенных пунктов.
    if (
      l_rec_.sttl_name is null
      and (l_rec_.gis_city_name = l_rec_.city_name or l_rec_.gis_city_name_fmt = l_rec_.city_name)
    ) then
       --2.1.1. наименования городов из ФИАС и ГИС
      if (l_rec_.gis_city_name = l_rec_.city_name) then
        l_match_weight := l_match_weight + G_CITY_N$S_CITY_N;
      elsif (l_rec_.gis_city_name_fmt = l_rec_.city_name) then
        l_match_weight := l_match_weight + G_CITY_NF$S_CITY_N;
      end if;
      --2.1.2. сокращения городов из ФИАС и ГИС
      if (l_rec_.gis_city_socr_fmt = l_rec_.city_socr) then
        l_match_weight := l_match_weight + G_CITY_SF$S_CITY_S;
      elsif (coalesce(l_rec_.gis_city_socr_fmt, l_rec_.city_socr) = l_rec_.city_socr) then
        l_match_weight := l_match_weight + G_CITY_SF_NL$S_CITY_S;
      elsif (coalesce(l_rec_.city_socr, l_rec_.gis_city_socr_fmt) = l_rec_.gis_city_socr_fmt) then
        l_match_weight := l_match_weight + G_CITY_SF$S_CITY_S_NL;
      elsif (not util.is_distinct_from(
        value1_ => coalesce(l_rec_.gis_city_socr_fmt, l_rec_.city_socr),
        value2_ => l_rec_.city_socr)
      ) then
        l_match_weight := l_match_weight + G_CITY_SF_NL$S_CITY_S_NL;
      else
        l_match_weight := l_match_weight + G_CITY_SF_FAL$S_CITY_S_FAL;
      end if;
    else
      l_match_weight := l_match_weight + G_CITY_NNF_FAL$S_CITY_N_FAL;
    end if;
    --2.2. сравнение населенных пунктов
    if (
      l_rec_.sttl_name is not null
      and (
      l_rec_.gis_city_name = l_rec_.sttl_name
      or l_rec_.gis_city_name_fmt = l_rec_.sttl_name
      or l_rec_.gis_city_name = l_rec_.sttl_name_fmt
      or l_rec_.gis_city_name_fmt = l_rec_.sttl_name_fmt
      )
    ) then
      --2.2.1. сравнение наименований населенных пунктов
      if (l_rec_.gis_city_name = l_rec_.sttl_name) then
        l_match_weight := l_match_weight + G_CITY_N$S_STTL_N;
      elsif (l_rec_.gis_city_name_fmt = l_rec_.sttl_name) then
        l_match_weight := l_match_weight + G_CITY_NF$S_STTL_N;
      elsif (l_rec_.gis_city_name = l_rec_.sttl_name_fmt) then
        l_match_weight := l_match_weight + G_CITY_N$S_STTL_NF;
      elsif (l_rec_.gis_city_name_fmt = l_rec_.sttl_name_fmt) then
        l_match_weight := l_match_weight + G_CITY_NF$S_STTL_NF;
      else
        l_match_weight := l_match_weight + G_CITY_NNF_FAL$S_STTL_NNF_FAL;
      end if;
      --2.2.1.1. наименования городов из ФИАС и наименования регионов из ГИС
      if (l_rec_.gis_reg_name_fmt is not null and l_rec_.gis_reg_name_fmt = l_rec_.city_name
      ) then
        l_match_weight := l_match_weight + G_REG_NF$S_CITY_N;
        if (l_rec_.gis_reg_socr_fmt = l_rec_.city_socr) then
          l_match_weight := l_match_weight + G_REG_SF$S_CITY_S;
        elsif (coalesce(l_rec_.gis_reg_socr_fmt, l_rec_.city_socr) = l_rec_.city_socr) then
          l_match_weight := l_match_weight + G_REG_SF_NL$S_CITY_S;
        elsif (coalesce(l_rec_.city_socr, l_rec_.gis_reg_socr_fmt) = l_rec_.gis_reg_socr_fmt) then
          l_match_weight := l_match_weight + G_REG_SF$S_CITY_S_NL;
        elsif (not util.is_distinct_from(
          value1_ => coalesce(l_rec_.gis_reg_socr_fmt, l_rec_.city_socr),
          value2_ => l_rec_.city_socr)
        ) then
          l_match_weight := l_match_weight + G_REG_SF_NL$S_CITY_S_NL;
        else
          l_match_weight := l_match_weight + G_REG_SF_FAL$S_CITY_S_FAL;
        end if;
      else
        l_match_weight := l_match_weight + G_REG_NF_FAL$S_CITY_N_FAL;
      end if;
      --2.2.2. сравнение сокращений населенных пунктов
      if (l_rec_.gis_city_socr_fmt = l_rec_.sttl_socr) then
        l_match_weight := l_match_weight + G_CITY_SF$S_STTL_S;
      elsif (l_rec_.gis_city_socr_fmt = l_rec_.sttl_socr_fmt) then
        l_match_weight := l_match_weight + G_CITY_SF$S_STTL_SF;
      elsif (coalesce(l_rec_.gis_city_socr_fmt, l_rec_.sttl_socr) = l_rec_.sttl_socr) then
        l_match_weight := l_match_weight + G_CITY_SF_NL$S_STTL_S;
      elsif (coalesce(l_rec_.sttl_socr, l_rec_.gis_city_socr_fmt) = l_rec_.gis_city_socr_fmt) then
        l_match_weight := l_match_weight + G_CITY_SF$S_STTL_S_NL;
      elsif (
        coalesce(l_rec_.sttl_socr, l_rec_.sttl_socr_fmt, l_rec_.gis_city_socr_fmt) = l_rec_.gis_city_socr_fmt
      ) then
       l_match_weight := l_match_weight + G_CITY_SF$S_STTL_SSF_NL;
      elsif (
        coalesce(l_rec_.gis_city_socr_fmt, l_rec_.sttl_socr, l_rec_.sttl_socr_fmt)
          = coalesce(l_rec_.sttl_socr, l_rec_.sttl_socr_fmt)
      ) then
        l_match_weight := l_match_weight + G_CITY_SF_NL$S_STTL_S_NL_SF;
      elsif (not util.is_distinct_from(
          value1_ => coalesce(l_rec_.gis_city_socr_fmt, l_rec_.sttl_socr, l_rec_.sttl_name_fmt),
          value2_ => coalesce(l_rec_.sttl_socr, l_rec_.sttl_name_fmt))
      ) then
        l_match_weight := l_match_weight + G_CITY_SF_NL$S_STTL_SSF_NL;
      else
        l_match_weight := l_match_weight + G_CITY_SF_FAL$S_STTL_SSF_FAL;
      end if;
    end if;
    return l_match_weight;
  end calc_match_weight;
begin
  assert.assert_not_null(value_ => id_city_, value_name_ => 'id_city_');
  for i in (
    select
      g.id_gis2kladr,
      g.gis_city_name,
      g.gis_city_name_fmt,
      g.gis_city_socr_fmt,
      g.gis_reg_name_fmt,
      g.gis_reg_socr_fmt,
      g.gis_sttl_name_fmt,
      g.gis_sttl_socr_fmt,
      g.gis_street_name,
      g.gis_street_name_fmt,
      g.gis_street_socr_fmt,
      f.id_settlement,
      f.city_name,
      f.city_socr,
      f.sttl_name,
      f.sttl_socr,
      f.sttl_name_fmt,
      f.sttl_socr_fmt,
      f.sttl_name_parent_fmt,
      f.sttl_parent_socr_fmt,
      f.id_street,
      f.sttl_of_street_name_fmt,
      f.sttl_of_street_socr_fmt,
      f.street_name,
      f.street_socr,
      f.street_name_fmt,
      f.street_socr_fmt
    from table (mainaddress.format_gis2kladr_street(id_city_ => id_city_)) g
      join table (mainaddress.format_settlement_street(id_city_ => id_city_)) f
      on (g.gis_street_name = f.street_name or g.gis_street_name_fmt = f.street_name_fmt)
  ) loop
    l_result.id_gis2kladr            := i.id_gis2kladr;
    l_result.id_street               := i.id_street;
    l_result.id_settlement           := i.id_settlement;
    l_result.gis_city_name           := i.gis_city_name;
    l_result.gis_city_name_fmt       := i.gis_city_name_fmt;
    l_result.gis_city_socr_fmt       := i.gis_city_socr_fmt;
    l_result.gis_reg_name_fmt        := i.gis_reg_name_fmt;
    l_result.gis_reg_socr_fmt        := i.gis_reg_socr_fmt;
    l_result.gis_sttl_name_fmt       := i.gis_sttl_name_fmt;
    l_result.gis_sttl_socr_fmt       := i.gis_sttl_socr_fmt;
    l_result.gis_street_name         := i.gis_street_name;
    l_result.gis_street_name_fmt     := i.gis_street_name_fmt;
    l_result.gis_street_socr_fmt     := i.gis_street_socr_fmt;
    l_result.city_name               := i.city_name;
    l_result.city_socr               := i.city_socr;
    l_result.sttl_name               := i.sttl_name;
    l_result.sttl_socr               := i.sttl_socr;
    l_result.sttl_name_fmt           := i.sttl_name_fmt;
    l_result.sttl_socr_fmt           := i.sttl_socr_fmt;
    l_result.sttl_name_parent_fmt    := i.sttl_name_parent_fmt;
    l_result.sttl_parent_socr_fmt    := i.sttl_parent_socr_fmt;
    l_result.sttl_of_street_name_fmt := i.sttl_of_street_name_fmt;
    l_result.sttl_of_street_socr_fmt := i.sttl_of_street_socr_fmt;
    l_result.street_name             := i.street_name;
    l_result.street_socr             := i.street_socr;
    l_result.street_name_fmt         := i.street_name_fmt;
    l_result.street_socr_fmt         := i.street_socr_fmt;
    l_result.match_weight            := mainaddress.addobj_similarity.calc_match_weight(l_rec_ => l_result);
    pipe row(l_result);
  end loop;
  return;
end addobj_similarity;

procedure gis_data_preparing(id_city_ integer) is
begin
  assert.assert_not_null(value_ => id_city_, value_name_ => 'id_city_');

  --Очистка временной таблицы сопоставлений
  delete from crl$gis2kladr_street;
  --Сопоставление адресных объектов (населенные пункты и улицы) из системы с объектами из ГИС и загрузка в временную
  --таблицу сопоставлений
  insert into crl$gis2kladr_street(id_gis2kladr, id_settlement, id_street, rank)
    select
      s.id_gis2kladr,
      s.id_settlement,
      s.id_street,
      s.rank
    from (
      select
        asm.id_gis2kladr,
        asm.id_settlement,
        asm.id_street,
        --присвоить каждой строке порядковый номер по убыванию веса в каждой группе строк, объеденных одним id_gis2kladr
        row_number() over (partition by asm.id_gis2kladr order by asm.match_weight desc) as rank
      from table(mainaddress.addobj_similarity(id_city_ => id_city_)) asm
      where
        --TO-DO: Создать новое условие сопоставления в addobj_similarity, удалив фильтрацию "asm.street_name not like '%(%)%'";
        --условие должно выбирать только одну строку из группы с одинаковым id_gis2kladr и значениями полей
        --sttl_of_street_name_fmt и sttl_of_street_socr_fmt рывными значениям полей
        --gis_city_name_fmt и gis_city_name_fmt соответственно
        asm.street_name not like '%(%)%'
        --записи с отрицательным весом не сопоставлены хотя бы по одному из условий, без учета null значений
        and asm.match_weight > 0
    ) s;

  --Обновление постоянной таблицы сопоставлений данными сопоставленных адресных объектов из временной таблицы
  declare
    CREATE_DATE constant date := sysdate;
  begin
    delete from main_gis2kladr_street_ranked t
    where t.kladr_id_city = id_city_ and t.kladr_id_street is null or t.create_dt < CREATE_DATE - 30;

    merge into main_gis2kladr_street_ranked t
    using (
      select
        s1.gis_city_name,
        s1.gis_street_name,
        s1.kladr_id_city,
        s2.id_settlement kladr_id_settlement,
        s2.id_street     kladr_id_street,
        s1.kladr_street_name,
        s1.kladr_socr,
        s1.id_gis2kladr,
        s1.gis_post_index,
        s2.rank
      from main_gis2kladr_street s1
        join crl$gis2kladr_street s2 on (s1.id_gis2kladr = s2.id_gis2kladr)
      --where s1.kladr_id_street is null
    ) s on (
      s.id_gis2kladr = t.id_gis2kladr
      and s.kladr_id_street = t.kladr_id_street
      and s.kladr_id_settlement = t.kladr_id_settlement
      )
    when matched then update set
      t.gis_city_name       = s.gis_city_name,
      t.gis_street_name     = s.gis_street_name,
      t.kladr_id_city       = s.kladr_id_city,
      t.kladr_street_name   = s.kladr_street_name,
      t.kladr_socr          = s.kladr_socr,
      t.gis_post_index      = s.gis_post_index,
      t.rank                = s.rank,
      t.create_dt           = CREATE_DATE
    when not matched then insert (
      t.id_gis2kladr_rank,
      t.id_gis2kladr,
      t.gis_city_name,
      t.gis_street_name,
      t.kladr_id_city,
      t.kladr_id_settlement,
      t.kladr_id_street,
      t.kladr_street_name,
      t.kladr_socr,
      t.gis_post_index,
      t.rank,
      t.create_dt
    ) values (
      mainkernel.get_id(),
      s.id_gis2kladr,
      s.gis_city_name,
      s.gis_street_name,
      s.kladr_id_city,
      s.kladr_id_settlement,
      s.kladr_id_street,
      s.kladr_street_name,
      s.kladr_socr,
      s.gis_post_index,
      s.rank,
      CREATE_DATE
    );
  end;

  --Обновление постоянной таблицы сопоставлений данными сопоставленных адресных объектов из временной таблицы
  merge into main_gis2kladr_street t
  using crl$gis2kladr_street s on (s.id_gis2kladr = t.id_gis2kladr)
  when matched then update set
    t.kladr_id_settlement = s.id_settlement, t.kladr_id_street = s.id_street
  --не обновлять строки, у которых значение поля kladr_id_street стало не null с момента вызова функции автоматического
  --сопоставления. Значения могли измениться неавтоматическим сопоставлением
  where t.kladr_id_street is null and s.rank = 1;

end gis_data_preparing;

end mainaddress;
/
