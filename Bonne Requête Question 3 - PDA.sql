SELECT
		s.segment,
		Count(*) AS clients, 
		ROUND( 100.0* COUNT(*) / t.N_clients, 1) AS pct_clients,
		ROUND(100.0 * SUM(s.revenus) / t.Revenus_Total,1) AS pct_revenus


FROM 
    (
		SELECT
				v.client_id,
				SUM(v.montant_billets) AS revenus,
				CASE WHEN COUNT (DISTINCT v.evenement_id) = 1 THEN N'1 spectacle (unique)'
					 WHEN COUNT (DISTINCT v.evenement_id) BETWEEN 2 AND 3 THEN N'2-3 spectacles (occasionnel)'
					 ELSE N'4 spectacles et + (fidèle)' END as segment
		FROM dbo.fact_ventes v
		INNER JOIN dbo.dim_evenement e ON v.evenement_id = e.evenement_id
		WHERE saison = N'Saison 2025-2026' AND statut_ligne ='Vendu'
		GROUP BY v.client_id			
	)  s
INNER JOIN 
	(
		SELECT
				COUNT(*) AS N_clients,
				SUM(c.revenus) AS Revenus_Total
		FROM
		     (
			  SELECT v.client_id,
				SUM(v.montant_billets) AS revenus,
				CASE WHEN COUNT (DISTINCT v.evenement_id) = 1 THEN N'1 spectacle (unique)'
					 WHEN COUNT (DISTINCT v.evenement_id) BETWEEN 2 AND 3 THEN N'2-3 spectacles (occasionnel)'
					 ELSE N'4 spectacles et + (fidèle)' END as segment
		FROM dbo.fact_ventes v
		INNER JOIN dbo.dim_evenement e ON v.evenement_id = e.evenement_id
		WHERE saison = N'Saison 2025-2026' AND statut_ligne ='Vendu'
		GROUP BY v.client_id ) c	
	) t ON 1=1
GROUP BY s.segment, t.N_clients, t.Revenus_Total
ORDER BY s.segment;
