/* Pour la saison 2025-2026, présentation par salle : nombre de représentations, billets vendus, revenus de billets et taux de remplissage.
Exclusion: les événements annulés et les lignes remboursées*/

SELECT
		s.nom_salle AS salle,
		COUNT(*) AS Nbs_representation, 
		SUM(COALESCE(b.Billets,0)) AS Billets_vendus,
		ROUND(SUM(COALESCE(b.Revenus,0)),0) AS Revenus_billets,
		ROUND(100.0*(SUM(COALESCE(b.Billets,0))) / SUM(e.capacite_vendable) ,1) AS Taux_remplissage_Pct
FROM dbo.dim_evenement e
INNER JOIN dbo.dim_salle s 
ON s.salle_id = e.salle_id
LEFT JOIN 
		(
			SELECT
			      evenement_id,
				  SUM(quantite) AS Billets,
				  SUM (montant_billets) AS Revenus
            FROM dbo.fact_ventes
			WHERE statut_ligne = 'Vendu'
			GROUP BY evenement_id
			
		) b
ON b.evenement_id = e.evenement_id
WHERE e.saison= N'Saison 2025-2026' AND e.statut_evenement ='Tenu'
GROUP BY s.nom_salle
ORDER BY Revenus_billets DESC;
