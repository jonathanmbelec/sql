Select
		COUNT(*) AS clients_s1,
		COUNT(s2.client_id) AS RetourS2,
		ROUND(100.0 * Count(s2.client_id) / COUNT(*),1) as Pct_Retention
FROM
	(
		SELECT DISTINCT v.client_id
		FROM dbo.fact_ventes v
		INNER JOIN dbo.dim_evenement e ON e.evenement_id = v.evenement_id
		WHERE e.saison = N'Saison 2025-2026' AND v.statut_ligne ='Vendu' and v.client_id LIKE 'C%'
	) s1
LEFT JOIN
	(
		SELECT DISTINCT v.client_id
		FROM dbo.fact_ventes v
		INNER JOIN dbo.dim_evenement e ON e.evenement_id = v.evenement_id
		WHERE e.saison = N'Saison 2026-2027' AND v.statut_ligne ='Vendu' and v.client_id LIKE 'C%'
	) s2 ON s2.client_id = s1.client_id
	;


-- b) clients 2026-2027 absents de 2025-2026 (nouveaux ou réactivés)
SELECT COUNT(*) AS nouveaux_ou_reactives_s2
FROM (
  SELECT DISTINCT v.client_id
  FROM dbo.fact_ventes v
  INNER JOIN dbo.dim_evenement e ON e.evenement_id = v.evenement_id
  WHERE e.saison = N'Saison 2026-2027' AND v.statut_ligne = 'Vendu' AND v.client_id LIKE 'C%'
) s2
LEFT JOIN (
  SELECT DISTINCT v.client_id
  FROM dbo.fact_ventes v
  INNER JOIN dbo.dim_evenement e ON e.evenement_id = v.evenement_id
  WHERE e.saison = N'Saison 2025-2026' AND v.statut_ligne = 'Vendu' AND v.client_id LIKE 'C%'
) s1 ON s1.client_id = s2.client_id
WHERE s1.client_id IS NULL; 