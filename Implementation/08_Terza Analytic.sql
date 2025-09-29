# TERZA ANALYTIC #

DROP PROCEDURE IF EXISTS `Terza analytic`;
DELIMITER $$
CREATE PROCEDURE `Terza analytic`()
BEGIN
	#SE NON C'è NESSUNO DENTRO UNA STANZA SUGGERISCO DI SPENGERE LA LUCE
	DECLARE newId INT UNSIGNED;
    DECLARE finito INTEGER DEFAULT 0;
    DECLARE idLuce INT UNSIGNED;
    DECLARE luciDaSpengere CURSOR FOR
	WITH UltimeAzioni AS
	(
		SELECT R.Id, R.Azione, IF(P.`Registro luci` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(CURRENT_TIMESTAMP > P.`Fine`, P.`Fine`, CURRENT_TIMESTAMP)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
		FROM `Registro luci` R LEFT OUTER JOIN `Programmazione luci` P ON R.Id = P.`Registro luci`
		WHERE `Timestamp` IS NOT NULL AND CURRENT_TIMESTAMP > `Timestamp`
	),
	UltimeAzioni2 AS
	(
		SELECT R.`Punto luce` AS PuntoLuce, U.`Ultima ripetizione` AS UltimaData, U.Azione
		FROM UltimeAzioni U INNER JOIN `Registrazione luci` R ON U.Id = R.`Registro luci`
	),
	LuciAccese AS
	(
		SELECT UV.PuntoLuce
		FROM
		(
			SELECT U.PuntoLuce, MAX(UltimaData) AS UltimaDataLuce
			FROM UltimeAzioni2 U
			GROUP BY U.PuntoLuce
		) AS UV INNER JOIN UltimeAzioni2 U2 ON UV.PuntoLuce = U2.PuntoLuce AND UV.UltimaDataLuce = U2.UltimaData
		WHERE U2.Azione = "accendi"
	)
	SELECT L.PuntoLuce
	FROM LuciAccese L INNER JOIN `Punto luce` P ON L.PuntoLuce = P.Id
	WHERE P.Stanza IN
	(
		SELECT DISTINCT S.Id
		FROM `Ubicazione` U RIGHT OUTER JOIN `Stanza` S ON U.`Stanza` = S.`Id`
		WHERE U.Stanza IS NULL
	);
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET finito = 1;
    
	SET newId = 1 +
	(
		SELECT MAX(A.Id)
		FROM `Registro luci` AS A
	);
    
    OPEN luciDaSpengere;
    spengi: LOOP
		FETCH luciDaSpengere INTO idLuce;
		IF finito = 1 THEN
			LEAVE spengi;
		END IF;
        
        INSERT INTO `Registro luci`(`Id`, `Timestamp`, `Account`, `Suggerimento`, `Azione`) VALUES
        (newId, NULL, NULL, CURRENT_TIMESTAMP, "spengi");
        
        INSERT INTO `Registrazione luci`(`Registro luci`, `Punto luce`) VALUES
        (newId, idLuce);
        
        SET newId = newId + 1;
        
    END LOOP;
    CLOSE luciDaSpengere;
    
    #SE HO POCO OSSIGENO SUGGERISCO DI APRIRE LA FINESTRA SE C'è QUALCUNO DENTRO
    INSERT INTO `Registro accessi e intrusioni`(`Timestamp`, `Account`, `Azione`, `Suggerimento`, `Punto di accesso o intrusione`)
	WITH StanzeTossiche AS
	(
		SELECT MT.Stanza
		FROM
		(
			SELECT Q.Stanza, MAX(Tempo) AS MaxTempo
			FROM `Qualità aria interna` Q
			GROUP BY Q.Stanza
		) AS MT INNER JOIN `Qualità aria interna` Q ON MT.Stanza = Q.Stanza AND Q.Tempo = MT.MaxTempo
		WHERE MaxTempo >= CURRENT_TIMESTAMP - INTERVAL 30 MINUTE AND `Anidride carbonica` >= 1150
	),
	UltimeAzioni AS
	(
		SELECT R.`Punto di accesso o intrusione`, R.Azione, IF(P.`Registro accessi e intrusioni` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(CURRENT_TIMESTAMP > P.`Fine`, P.`Fine`, CURRENT_TIMESTAMP)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
		FROM `Registro accessi e intrusioni` R LEFT OUTER JOIN `Programmazione accessi` P ON R.Id = P.`Registro accessi e intrusioni`
		WHERE `Timestamp` IS NOT NULL AND CURRENT_TIMESTAMP > `Timestamp`
	),
	AzioniPorta AS
	(
		SELECT UltimeAzioni.`Punto di accesso o intrusione` AS Accesso, UltimeAzioni.Azione
		FROM
		(
			SELECT `Punto di accesso o intrusione`, MAX(`Ultima ripetizione`) AS `Ultima data`
			FROM UltimeAzioni
			WHERE Azione = "apri" OR Azione = "chiudi"
			GROUP BY `Punto di accesso o intrusione`
		) AS UR INNER JOIN UltimeAzioni ON UR.`Ultima data` =  UltimeAzioni.`Ultima ripetizione` AND UR.`Punto di accesso o intrusione` = UltimeAzioni.`Punto di accesso o intrusione`
	),
	AccessiAperti AS
	(
		SELECT Accesso
		FROM AzioniPorta
		WHERE Azione = "apri"
	),
	FinestreChiuse AS
	(
		SELECT E.`Punto di accesso o intrusione` AS Finestra, E.Stanza
		FROM Esterno E LEFT OUTER JOIN AccessiAperti A ON E.`Punto di accesso o intrusione` = A.Accesso INNER JOIN `Punto di accesso o intrusione` P ON P.Id = E.`Punto di accesso o intrusione`
		WHERE Tipo = "finestra" AND Accesso IS NULL
	)
	SELECT NULL AS `Timestamp`, NULL AS `Account`, "apri" AS `Azione`, CURRENT_TIMESTAMP AS `Suggerimento`, F.Finestra AS `Punto di accesso o intrusione`
	FROM FinestreChiuse F INNER JOIN StanzeTossiche S ON F.Stanza = S.Stanza;
    
END $$
DELIMITER ;