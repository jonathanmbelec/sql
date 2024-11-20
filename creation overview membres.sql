SELECT 
      DISTINCT dc.email AS email
      , firstname AS prenom
      , lastname AS nom_de_famille
      , gender AS genre
      , nbs_de_montant_recurrent_different
      , nbs_txn_recurrente
      , montant_moyen_recurrent
      , montant_recurrent_total
      , premiere_txn_recurrente 
      , derniere_txn_recurrente
      , nbs_txn_unique
      , nbs_de_montant_unique_different
      , montant_moyen_unique
      , montant_unique_total
      , premiere_txn_unique 
      , derniere_txn_unique
   	  , statut_souscription
      , nb_subscription
	  , DATE_FORMAT(CONVERT_TZ(MAX(dcd.creation_date), '+00:00', 'Us/Eastern'),'%Y-%m-%d') AS derniere_txn
      , DATE_FORMAT(CONVERT_TZ(MIN(dcd.creation_date), '+00:00', 'Us/Eastern'),'%Y-%m-%d') AS premiere_txn
      , COUNT(fc.amount) AS Nbs_de_txns_globales
	  , SUM(fc.amount) as Montant_global
      , ROUND(AVG(fc.amount),2) as Montant_global_moyen
 FROM sandbox.FACT_CHARGE fc
 INNER JOIN sandbox.DIM_CUSTOMER dc ON fc.id_customer = dc.id_customer
 INNER JOIN sandbox.DIM_CHARGE_DETAIL dcd ON fc.id_charge_detail = dcd.id_charge_detail
 
LEFT JOIN
/*Infos contributeurs récurrents*/
    (SELECT 
		DISTINCT dc2.email AS email
        , COUNT(fc2.amount)  AS nbs_txn_recurrente
        , SUM(fc2.amount) AS montant_recurrent_total
		, COUNT(DISTINCT fc2.amount)  AS nbs_de_montant_recurrent_different
		, ROUND(AVG(fc2.amount),2) AS montant_moyen_recurrent
	    , DATE_FORMAT(CONVERT_TZ(MIN(dcd2.creation_date), '+00:00', 'Us/Eastern'),'%Y-%m-%d')  AS premiere_txn_recurrente 
	    , DATE_FORMAT(CONVERT_TZ(MAX(dcd2.creation_date), '+00:00', 'Us/Eastern'),'%Y-%m-%d')  AS derniere_txn_recurrente
	FROM sandbox.FACT_CHARGE fc2 
	INNER JOIN sandbox.DIM_CUSTOMER dc2 ON fc2.id_customer = dc2.id_customer
	INNER JOIN sandbox.DIM_CHARGE_DETAIL dcd2 ON fc2.id_charge_detail = dcd2.id_charge_detail
	WHERE dcd2.status ="succeeded"
	AND dcd2.is_refunded = 0
	AND dcd2.description !="Contribution unique"
	AND dc2.email !=" "
    GROUP BY 1
    ORDER BY 1
    ) a
ON dc.email = a.email
    
LEFT JOIN
/*Infos contributeurs uniques*/
	(SELECT 
		DISTINCT dc1.email AS email
        , COUNT(fc1.amount)  AS nbs_txn_unique
        , SUM(fc1.amount) AS montant_unique_total
		, COUNT(DISTINCT fc1.amount)  AS nbs_de_montant_unique_different
		, ROUND(AVG(fc1.amount),2) AS montant_moyen_unique
		, DATE_FORMAT(CONVERT_TZ(MIN(dcd1.creation_date), '+00:00', 'Us/Eastern'),'%Y-%m-%d')  AS premiere_txn_unique 
		, DATE_FORMAT(CONVERT_TZ(MAX(dcd1.creation_date), '+00:00', 'Us/Eastern'),'%Y-%m-%d') AS derniere_txn_unique
	FROM sandbox.FACT_CHARGE fc1
	INNER JOIN sandbox.DIM_CUSTOMER dc1 ON fc1.id_customer = dc1.id_customer
	INNER JOIN sandbox.DIM_CHARGE_DETAIL dcd1 ON fc1.id_charge_detail = dcd1.id_charge_detail
	WHERE status ="succeeded"
	AND is_refunded = 0
	AND description ="Contribution unique"
	AND email !=" "
	GROUP BY 1
	ORDER BY 1
    ) b
ON dc.email=b.email

LEFT JOIN
/*details subscription*/
	(	SELECT DISTINCT email
        , group_concat(status SEPARATOR ', ') as statut_souscription
		, count(email) as nb_subscription
	FROM sandbox.FACT_SUBSCRIPTION fs
	INNER JOIN sandbox.DIM_CUSTOMER dc ON fs.id_customer = dc.id_customer
	INNER JOIN sandbox.DIM_SUBSCRIPTION_DETAIL dsd ON fs.id_subscription_detail = dsd.id_subscription_detail
	WHERE  email != ''
	GROUP BY  1
	ORDER BY 'creation_date' DESC
    ) c
ON dc.email = c.email 

WHERE status ="succeeded"
AND is_refunded = 0
AND dc.email !=" "
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18 





    
 