/* =============================================================================
   MEMBER CONTRIBUTION OVERVIEW
   -----------------------------------------------------------------------------
   Purpose : Builds a per-member (per-email) overview combining global,
             recurring, and one-time contribution metrics, plus subscription
             status, from a star schema (fact + dimension tables).

   Grain   : One row per member email.

   Notes   :
   - Dialect: MySQL 8.0+ (CTEs require 8.0; DATE_FORMAT / CONVERT_TZ /
     GROUP_CONCAT are MySQL-specific).
   - Transaction type is inferred from DIM_CHARGE_DETAIL.description:
     'Contribution unique' = one-time; anything else = recurring.
     (Data-quality constraint: no dedicated transaction-type flag exists.)
   - Timestamps are stored in UTC and converted to US/Eastern for reporting.
   - Rows with blank/whitespace emails are excluded (known data-quality issue).
   ============================================================================= */

WITH

/* ---------------------------------------------------------------------------
   Base set: all successful, non-refunded charges with a valid email.
   Centralizing the joins and filters here keeps every downstream
   aggregation consistent (the original query repeated these joins 3 times).
   --------------------------------------------------------------------------- */
charges AS (
    SELECT
        dc.email,
        dc.firstname,
        dc.lastname,
        dc.gender,
        fc.amount,
        dcd.creation_date,
        dcd.description
    FROM sandbox.FACT_CHARGE        AS fc
    INNER JOIN sandbox.DIM_CUSTOMER AS dc
        ON fc.id_customer = dc.id_customer
    INNER JOIN sandbox.DIM_CHARGE_DETAIL AS dcd
        ON fc.id_charge_detail = dcd.id_charge_detail
    WHERE dcd.status      = 'succeeded'
      AND dcd.is_refunded = 0
      AND TRIM(dc.email) <> ''
),

/* ---------------------------------------------------------------------------
   Global metrics: all successful charges, regardless of type.
   --------------------------------------------------------------------------- */
global_stats AS (
    SELECT
        email,
        firstname,
        lastname,
        gender,
        COUNT(*)                                        AS nbs_de_txns_globales,
        SUM(amount)                                     AS montant_global,
        ROUND(AVG(amount), 2)                           AS montant_global_moyen,
        DATE_FORMAT(CONVERT_TZ(MIN(creation_date), '+00:00', 'US/Eastern'), '%Y-%m-%d') AS premiere_txn,
        DATE_FORMAT(CONVERT_TZ(MAX(creation_date), '+00:00', 'US/Eastern'), '%Y-%m-%d') AS derniere_txn
    FROM charges
    GROUP BY email, firstname, lastname, gender
),

/* ---------------------------------------------------------------------------
   Recurring contributions (description <> 'Contribution unique').
   --------------------------------------------------------------------------- */
recurring_stats AS (
    SELECT
        email,
        COUNT(*)                 AS nbs_txn_recurrente,
        COUNT(DISTINCT amount)   AS nbs_de_montant_recurrent_different,
        SUM(amount)              AS montant_recurrent_total,
        ROUND(AVG(amount), 2)    AS montant_moyen_recurrent,
        DATE_FORMAT(CONVERT_TZ(MIN(creation_date), '+00:00', 'US/Eastern'), '%Y-%m-%d') AS premiere_txn_recurrente,
        DATE_FORMAT(CONVERT_TZ(MAX(creation_date), '+00:00', 'US/Eastern'), '%Y-%m-%d') AS derniere_txn_recurrente
    FROM charges
    WHERE description <> 'Contribution unique'
    GROUP BY email
),

/* ---------------------------------------------------------------------------
   One-time contributions (description = 'Contribution unique').
   --------------------------------------------------------------------------- */
one_time_stats AS (
    SELECT
        email,
        COUNT(*)                 AS nbs_txn_unique,
        COUNT(DISTINCT amount)   AS nbs_de_montant_unique_different,
        SUM(amount)              AS montant_unique_total,
        ROUND(AVG(amount), 2)    AS montant_moyen_unique,
        DATE_FORMAT(CONVERT_TZ(MIN(creation_date), '+00:00', 'US/Eastern'), '%Y-%m-%d') AS premiere_txn_unique,
        DATE_FORMAT(CONVERT_TZ(MAX(creation_date), '+00:00', 'US/Eastern'), '%Y-%m-%d') AS derniere_txn_unique
    FROM charges
    WHERE description = 'Contribution unique'
    GROUP BY email
),

/* ---------------------------------------------------------------------------
   Subscription summary: one row per email, concatenating all statuses.
   (Original version ordered by the string literal 'creation_date' — a bug —
   and the ORDER BY inside a subquery had no effect anyway; both removed.)
   --------------------------------------------------------------------------- */
subscription_stats AS (
    SELECT
        dc.email,
        GROUP_CONCAT(dsd.status ORDER BY fs.id_subscription_detail SEPARATOR ', ') AS statut_souscription,
        COUNT(*)                                                                   AS nb_subscription
    FROM sandbox.FACT_SUBSCRIPTION       AS fs
    INNER JOIN sandbox.DIM_CUSTOMER      AS dc
        ON fs.id_customer = dc.id_customer
    INNER JOIN sandbox.DIM_SUBSCRIPTION_DETAIL AS dsd
        ON fs.id_subscription_detail = dsd.id_subscription_detail
    WHERE TRIM(dc.email) <> ''
    GROUP BY dc.email
)

/* ---------------------------------------------------------------------------
   Final assembly: global stats enriched with recurring, one-time, and
   subscription details. LEFT JOINs preserve members who have only one
   contribution type or no subscription record.
   --------------------------------------------------------------------------- */
SELECT
    g.email                                AS email,
    g.firstname                            AS prenom,
    g.lastname                             AS nom_de_famille,
    g.gender                               AS genre,

    -- Recurring contributions
    r.nbs_de_montant_recurrent_different,
    r.nbs_txn_recurrente,
    r.montant_moyen_recurrent,
    r.montant_recurrent_total,
    r.premiere_txn_recurrente,
    r.derniere_txn_recurrente,

    -- One-time contributions
    o.nbs_txn_unique,
    o.nbs_de_montant_unique_different,
    o.montant_moyen_unique,
    o.montant_unique_total,
    o.premiere_txn_unique,
    o.derniere_txn_unique,

    -- Subscriptions
    s.statut_souscription,
    s.nb_subscription,

    -- Global
    g.derniere_txn,
    g.premiere_txn,
    g.nbs_de_txns_globales,
    g.montant_global,
    g.montant_global_moyen

FROM global_stats            AS g
LEFT JOIN recurring_stats    AS r ON g.email = r.email
LEFT JOIN one_time_stats     AS o ON g.email = o.email
LEFT JOIN subscription_stats AS s ON g.email = s.email
ORDER BY g.email;
