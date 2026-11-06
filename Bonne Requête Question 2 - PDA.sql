 /*Top 10 productions (revenus, remplissage, représentations sous 60 % */
SELECT	Top 10
		p.titre, 
		p.genre,
		COUNT(*) AS Nbs_representation,
		ROUND(SUM(b.revenus),0) AS revenus,
		ROUND(SUM(b.revenus)/ Count(*),0) AS Revenu_moyen_rep, 
		ROUND(100.0*SUM(b.billets) / SUM(e.capacite_vendable),1)   AS remplissage_pct,
		SUM(
		    CASE WHEN 1.0*b.billets / e.capacite_vendable < 0.6 THEN 1 ELSE 0 END) AS Rep_sous60
FROM dbo.dim_evenement e
INNER JOIN dbo.dim_production p ON p.production_id = e.production_id
INNER JOIN (
			SELECT 
					evenement_id,
					Sum(quantite) as billets,
					Sum(montant_billets) as revenus			
			FROM dbo.fact_ventes
			WHERE statut_ligne ='Vendu'
			GROUP BY evenement_id
			) b
ON b.evenement_id = e.evenement_id
WHERE e.saison= N'Saison 2025-2026' AND e.statut_evenement='Tenu'
GROUP BY p.production_id, p.titre, p.genre
ORDER BY SUM(b.revenus) DESC;

