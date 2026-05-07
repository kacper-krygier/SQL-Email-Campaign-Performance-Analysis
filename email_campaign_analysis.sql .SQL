WITH
emails_base AS (
  SELECT
    DATE_ADD(s.date, INTERVAL es.sent_date DAY) AS day,
    sp.country AS country,
    ac.send_interval AS send_interval,
    ac.is_verified,
    ac.is_unsubscribed,
    es.id_message,
    eo.id_message AS opened_msg_id,
    ev.id_message AS visited_msg_id
  FROM `data-analytics-mate.DA.email_sent` es
  JOIN `data-analytics-mate.DA.account_session` acs
    ON es.id_account = acs.account_id
  JOIN `data-analytics-mate.DA.account` ac
    ON acs.account_id = ac.id
  JOIN `data-analytics-mate.DA.session` s
    ON acs.ga_session_id = s.ga_session_id
  JOIN `data-analytics-mate.DA.session_params` sp
    ON s.ga_session_id = sp.ga_session_id
  LEFT JOIN `data-analytics-mate.DA.email_open` eo
    ON es.id_message = eo.id_message
  LEFT JOIN `data-analytics-mate.DA.email_visit` ev
    ON es.id_message = ev.id_message
),
emails_agg AS (
  SELECT
    day,
    country,
    send_interval,
    is_verified,
    is_unsubscribed,
    COUNT(DISTINCT id_message) AS sent_msg,
    COUNT(DISTINCT opened_msg_id) AS opened_msg,
    COUNT(DISTINCT visited_msg_id) AS visited_msg
  FROM emails_base
  GROUP BY 1, 2, 3, 4, 5
),
accounts_base AS (
  SELECT
    s.date AS day,
    sp.country AS country,
    ac.send_interval AS send_interval,
    ac.is_verified,
    ac.is_unsubscribed,
    COUNT(DISTINCT ac.id) AS account_cnt
  FROM `data-analytics-mate.DA.session_params` sp
  JOIN `data-analytics-mate.DA.account_session` acs
    USING (ga_session_id)
  JOIN `data-analytics-mate.DA.account` ac
    ON acs.account_id = ac.id
  JOIN `data-analytics-mate.DA.session` s
    ON sp.ga_session_id = s.ga_session_id
  GROUP BY 1, 2, 3, 4, 5


),
unioned AS (
  SELECT
    day,
    country,
    send_interval,
    is_verified,
    is_unsubscribed,
    NULL AS account_cnt,
    sent_msg,
    opened_msg,
    visited_msg,
  FROM emails_agg
  UNION ALL
  SELECT
    day,
    country,
    send_interval,
    is_verified,
    is_unsubscribed,
    account_cnt,
    NULL AS sent_msg,
    NULL AS opened_msg,
    NULL AS visited_msg,
  FROM accounts_base
),
final_base AS (
 SELECT
   day,
   country,
   send_interval,
   is_verified,
   is_unsubscribed,
   SUM(account_cnt) AS account_cnt,
   SUM(sent_msg) AS sent_msg,
   SUM(opened_msg) AS opened_msg,
   SUM(visited_msg) AS visited_msg,
 FROM unioned
 GROUP BY
   day,
   country,
   send_interval,
   is_verified,
   is_unsubscribed
),


final AS (
 SELECT
   *,
   SUM(sent_msg) OVER (PARTITION BY country) AS total_country_sent_cnt,
   SUM(account_cnt) OVER (PARTITION BY country) AS total_country_account_cnt,
 FROM final_base
),
t_rank as (
SELECT *,
   DENSE_RANK() OVER (ORDER BY total_country_account_cnt DESC)
     AS rank_total_country_account_cnt,
   DENSE_RANK() OVER (ORDER BY total_country_sent_cnt DESC)
     AS rank_total_country_sent_cnt
FROM final
)
SELECT*
FROM t_rank
WHERE
 rank_total_country_account_cnt <= 10
AND rank_total_country_sent_cnt <= 10
ORDER BY country, day;
