SELECT 
	e.evenement_id,
	p.titre,
	s.nom_salle, 
	e.date_evenement,
       e.capacite_vendable AS capacite,
       SUM(CASE WHEN v.statut_ligne='Vendu' THEN v.quantite ELSE 0 END) AS vendus,
       ROUND(100.0*SUM(CASE WHEN v.statut_ligne='Vendu' THEN v.quantite ELSE 0 END)/e.capacite_vendable,1) AS remplissage_pct
FROM dim_evenement e JOIN dim_production p on e.production_id = p.production_id
INNER JOIN dim_salle s On s.salle_id = e.salle_id
LEFT JOIN fact_ventes v On v.evenement_id =e.evenement_id
WHERE e.date_evenement BETWEEN '2026-11-05' AND '2026-11-14' AND e.statut_evenement='À venir'
GROUP BY e.evenement_id, p.titre, s.nom_salle, e.date_evenement, e.capacite_vendable
ORDER BY e.date_evenement, remplissage_pct ;