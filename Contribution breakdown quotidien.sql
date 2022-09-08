/*Creation de la date d'aujourd'hui*/
Declare @DateTo date
Set @DateTo = getdate()

/*Tableau sommaire qui mentionne quotidiennement le nombre et le montant des contributeurs selon les catégories mentionnées*/
SELECT ((date_format(convert_tz(date, '+00:00', 'US/Eastern'),'%Y-%m-%d'))) AS journée
	   ,'Nouvelle contribution récurrente mensuelle' AS 'information extraite'
	   , SUM(nb) AS quantité
	   , SUM(total) AS 'dollars' 
FROM ( SELECT
			date
			, amount
			, COUNT(DISTINCT id_customer) AS nb
			, amount*COUNT(DISTINCT id_customer) AS total
		FROM (SELECT DISTINCT LOWER(email) AS email
					,a.id_customer
					,c.creation_date AS date
					,d.amount
					,amount_refunded
					,(CASE WHEN e.id_subscription_detail NOT LIKE '%unique%' THEN 'recurrent' ELSE 0 END) AS type
					,e.status
			   FROM sandbox.DIM_CUSTOMER a
                    inner join sandbox.FACT_CHARGE b on a.id_customer=b.id_customer
                    inner join sandbox.DIM_CHARGE_DETAIL c on b.id_charge_detail=c.id_charge_detail
                    inner join sandbox.FACT_SUBSCRIPTION d on d.id_customer=b.id_customer
                    inner join sandbox.DIM_SUBSCRIPTION_DETAIL e on (e.id_subscription_detail=d.id_subscription_detail and substr(e.creation_date,1,10)=substr(c.creation_date,1,10))
               WHERE c.status = 'succeeded'
                    AND CONVERT_TZ(c.creation_date, '+00:00','Us/Eastern') >= '2022-01-01'
                    AND CONVERT_TZ(c.creation_date, '+00:00','Us/Eastern') < @DateTo 
				) b
		GROUP BY 1,2
		) c 
GROUP BY 1,2 

UNION 
/* Montant Encaissé par les contributeurs mensuels actifs*/
SELECT DATE_FORMAT(CONVERT_TZ(date, '+00:00','US/Eastern'), '%Y-%m-%d') AS journée
	   , 'Total Récurrent Encaissés'
	   , 0 AS quantité
	   , SUM(amount*nb) AS 'dollars'
FROM (  SELECT
		     amount
			 , COUNT(DISTINCT id_charge) AS NB
			 ,(creation_date) AS date
		FROM sandbox.FACT_CHARGE a
			 inner join sandbox.DIM_CHARGE_DETAIL b ON a.id_charge_detail= b.id_charge_detail
        WHERE  description NOT LIKE '%unique%' AND status = 'succeeded'
        AND CONVERT_TZ(creation_date, '+00:00','US/Eastern') >='2022-01-01'
        AND CONVERT_TZ(creation_date, '+00:00','Us/Eastern')< @DateTo 
		GROUP BY 1,3
     ) a 
GROUP BY 1,2

UNION

/*Quantité de contributeur mensuel actif lié au montant encaissé précédemment*/
SELECT (DATE_FORMAT(DATE_FORMAT(CONVERT_TZ(date, '+00:00', 'US/Eastern'), "%Y-%m-%d"), "%Y-%m-%d")) AS journée
		, 'Contributeur mensuel actif'
		, nb_active AS quantité
		, 0 AS 'dollars'
FROM ( SELECT
			 date
			 , nb_active
	   FROM sandbox.FACT_HISTORY_SUBSCRIPTION
       WHERE  CONVERT_TZ(date, '+00:00', 'Us/Eastern') >= '2022-01-01'
       AND CONVERT_TZ(date, '+00:00', 'Us/Eastern')< CURDATE()
      ) a
GROUP BY 1,2

Union

/*Nouveaux Contributeurs Uniques*/
SELECT (DATE_FORMAT(DATE_FORMAT(CONVERT_TZ(date, '+00:00', 'Us/Eastern'), "%Y-%m-%d"), "%Y-%m-%d")) AS journée
		, 'Nouvelle Contribution Unique'
		, SUM(nb_users) AS quantité
		, SUM(total) AS 'dollars'
FROM ( SELECT  email
			   ,date
			   , amount
			   , COUNT(DISTINCT id_customer_stripe) AS nb_users
			   , COUNT(DISTINCT id_customer_stripe)*amount AS total
	   FROM ( SELECT DISTINCT LOWER(email) AS email 
					 , a.id_customer_stripe
					 , c.creation_date AS date
					 , b.amount
              FROM sandbox.DIM_CUSTOMER a
              INNER JOIN sandbox.FACT_CHARGE b ON a.id_customer=b.id_customer
              INNER JOIN sandbox.DIM_CHARGE_DETAIL c ON b.id_charge_detail=c.id_charge_detail
              WHERE description LIKE 'Contribution unique' AND c.status = 'succeeded'
			  AND CONVERT_TZ(c.creation_date, '+00:00', 'Us/Eastern') >= '2022-01-01'
              AND CONVERT_TZ(c.creation_date, '+00:00', 'Us/Eastern') < @dateTo
              AND email NOT IN (SELECT DISTINCT email
							    FROM sandbox.DIM_CUSTOMER 
								WHERE CONVERT_TZ(creation_date, '+00:00', 'Us/Eastern') <= MAKEDATE(year(now()),1))
             ) a
		GROUP BY 1, 2
	) a
GROUP BY 1,2

Union
/* Anciens Contributeurs Uniques qui recommencen à contribuer*/

SELECT(DATE_FORMAT(DATE_FORMAT(CONVERT_TZ(date, '+00:00', 'Us/Eastern'), "%Y-%m-%d"), "%Y-%m-%d")) AS date_fin
	  , 'Renouvellement contribution unique'
	  , SUM(nb_users) AS 'quantité'
	  , SUM(total) AS 'dollars'
FROM ( SELECT date
			  , amount
			  , COUNT(DISTINCT id_customer_stripe) AS nb_users
			  , COUNT(DISTINCT id_customer_stripe)*amount AS total
	   FROM ( SELECT DISTINCT LOWER(email) AS email
					 , a.id_customer_stripe
					 , c.creation_date AS date
					 , b.amount
              FROM sandbox.DIM_CUSTOMER a
              INNER JOIN sandbox.FACT_CHARGE b ON a.id_customer=b.id_customer
              INNER JOIN sandbox.DIM_CHARGE_DETAIL c ON b.id_charge_detail=c.id_charge_detail
              WHERE description LIKE 'Contribution unique' AND c.status = "succeeded"
			  AND CONVERT_TZ(c.creation_date, "+00:00", "Us/Eastern")  >= '2022-01-01'
              AND CONVERT_TZ(c.creation_date, "+00:00", "Us/Eastern") < @dateTo
              AND email IN (SELECT DISTINCT email
							FROM sandbox.DIM_CUSTOMER
							WHERE CONVERT_TZ(creation_date, '+00:00', 'Us/Eastern') <= MAKEDATE(year(now()),1))
			) a
		GROUP BY 1, 2
	) a
GROUP BY 1,2

UNION
/* Toutes les contributions uniques */
SELECT (DATE_FORMAT(DATE_FORMAT(CONVERT_TZ(date, '+00:00', 'Us/Eastern'), "%Y-%m-%d"), "%Y-%m-%d")) AS journée
		, 'Total contribution unique'
		, SUM(nb_users) AS quantité
		, SUM(total) AS 'dollars'
FROM( SELECT date
			 , amount
			 , COUNT(DISTINCT id_customer_stripe) AS nb_users
			 , COUNT(DISTINCT id_customer_stripe)*amount AS total
	  FROM (  SELECT DISTINCT LOWER(email) AS email
					 , a.id_customer_stripe
					 , c.creation_date AS date
					 , b.amount
			  FROM sandbox.DIM_CUSTOMER a
			  INNER JOIN sandbox.FACT_CHARGE b ON a.id_customer=b.id_customer
			  INNER JOIN sandbox.DIM_CHARGE_DETAIL c ON b.id_charge_detail=c.id_charge_detail
			  WHERE description LIKE 'Contribution unique' AND c.status = 'succeeded'
              AND CONVERT_TZ(c.creation_date, '+00:00', 'Us/Eastern')  >= '2022-01-01'
              AND CONVERT_TZ(c.creation_date, '+00:00', 'Us/Eastern')  < @dateTo ) a
	group by 1,2) a		
    group by 1,2
UNION

/* Attrition*/
SELECT (DATE_FORMAT(date, "%Y-%m-%d")) AS journée
		, 'Attrition des récurrents'
		, nb AS quantité
		, dollars AS 'dollars'
FROM (SELECT (DATE_FORMAT(canceled_at, "%Y-%m-%d")) AS date
			 , COUNT(DISTINCT id) AS nb
			 , SUM(amount) AS dollars
	  FROM sandbox.CANCELLED_SUBSCRIPTION
	  WHERE convert_tz(canceled_at, '+00:00', 'Us/Eastern') >= '2022-01-01'
	  AND convert_tz(canceled_at, '+00:00', 'Us/Eastern') <@dateTo
	  GROUP BY 1
	 ) a
GROUP BY 1,2
;
