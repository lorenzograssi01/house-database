# SECONDA ANALYTIC #

DROP PROCEDURE IF EXISTS `Seconda analytic`;
DELIMITER $$
CREATE PROCEDURE `Seconda analytic`()
BEGIN
	DECLARE MediaConsumo DOUBLE;
	DECLARE MediaProduzione DOUBLE;
	DECLARE DeltaEnergia DOUBLE;
    DECLARE DeltaConsumo DOUBLE;
    DECLARE DeltaProduzione DOUBLE;
    DECLARE ConsumoIstantaneo DOUBLE;
    
    SET MediaConsumo =
    (
        SELECT AVG(`Potenza dissipata`)
		FROM Tempo
		WHERE ((`Timestamp` >= CURRENT_TIMESTAMP - INTERVAL 1 MONTH) AND HOUR(`Timestamp`) = (HOUR(CURRENT_TIMESTAMP) + (MINUTE(CURRENT_TIMESTAMP) DIV 45))) AND ( ((DAYOFWEEK(CURRENT_TIMESTAMP) = 1 OR DAYOFWEEK(CURRENT_TIMESTAMP) = 7) AND (DAYOFWEEK(`Timestamp`) = 1 OR DAYOFWEEK(`Timestamp`) = 7))  OR (DAYOFWEEK(CURRENT_TIMESTAMP) BETWEEN 2 AND 6 AND DAYOFWEEK(`Timestamp`) BETWEEN 2 AND 7))
    );
    
    SET MediaProduzione = 
    (	
		SELECT AVG(`Potenza prodotta`)
		FROM 
        (
			SELECT Tempo, SUM(`Potenza prodotta`) AS `Potenza prodotta`
            FROM `Registro produzione energia`
            GROUP BY Tempo
        ) AS D
		WHERE ((`Tempo` >= CURRENT_TIMESTAMP - INTERVAL 1 MONTH) AND (HOUR(`Tempo`) = HOUR(CURRENT_TIMESTAMP) + (MINUTE(CURRENT_TIMESTAMP) DIV 45)))
    );
    
    IF
    (
		SELECT MAX(Tempo)
		FROM `Registro produzione energia`
	) < CURRENT_TIMESTAMP - INTERVAL 30 MINUTE
    THEN
		SIGNAL SQLSTATE "45000"
        SET MESSAGE_TEXT = "Errore: dati insufficienti";
	END IF;
    
    SET DeltaEnergia =
	-(      
		SELECT SUM(`Potenza prodotta`)
        FROM `Registro produzione energia`
        WHERE Tempo = 
        (
			SELECT MAX(Tempo)
			FROM `Registro produzione energia`
        )
    );
    
    SET ConsumoIstantaneo =   
    (
		WITH UltimeAzioni AS
		(
			SELECT R.Potenza, R.Id, R.Azione, IF(P.`Registro luci` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(CURRENT_TIMESTAMP > P.`Fine`, P.`Fine`, CURRENT_TIMESTAMP)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
			FROM `Registro luci` R LEFT OUTER JOIN `Programmazione luci` P ON R.Id = P.`Registro luci`
			WHERE `Timestamp` IS NOT NULL AND CURRENT_TIMESTAMP > `Timestamp`
		),
		UltimeAzioni2 AS
		(
			SELECT U.Potenza, R.`Punto luce` AS PuntoLuce, U.`Ultima ripetizione` AS UltimaData, U.Azione
			FROM UltimeAzioni U INNER JOIN `Registrazione luci` R ON U.Id = R.`Registro luci`
		)
		SELECT IF(SUM(IF(UV.Potenza IS NULL, L.Potenza, UV.Potenza)) IS NOT NULL, SUM(IF(UV.Potenza IS NULL, L.Potenza, UV.Potenza)), 0) AS SommaPotenzaLuci
		FROM
		(
			SELECT U.Potenza, U.PuntoLuce, MAX(UltimaData) AS UltimaDataLuce
			FROM UltimeAzioni2 U
			GROUP BY U.PuntoLuce
		) AS UV INNER JOIN UltimeAzioni2 U2 ON UV.PuntoLuce = U2.PuntoLuce AND UV.UltimaDataLuce = U2.UltimaData INNER JOIN `Registro spostamenti` RS ON RS.`Punto luce` = UV.PuntoLuce INNER JOIN `Lampadina` L ON RS.Lampadina = L.Id
		WHERE U2.Azione = "accendi" AND (UV.UltimaDataLuce BETWEEN RS.Inizio AND RS.Fine) OR (UV.UltimaDataLuce >= RS.Inizio AND RS.Fine IS NULL)
    )
		+
    (
		WITH UltimeAzioni AS
		(
			SELECT R.Id, R.Azione, IF(P.`Registro clima` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(CURRENT_TIMESTAMP > P.`Fine`, P.`Fine`, CURRENT_TIMESTAMP)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
			FROM `Registro clima` R LEFT OUTER JOIN `Programmazione clima` P ON R.Id = P.`Registro clima`
			WHERE `Timestamp` IS NOT NULL AND CURRENT_TIMESTAMP > `Timestamp`
		),
		UltimeAzioni2 AS
		(
			SELECT R.`Climatizzatore` AS Climatizzatore, U.`Ultima ripetizione` AS UltimaData, U.Azione
			FROM UltimeAzioni U INNER JOIN `Utilizzo clima` R ON U.Id = R.`Registro clima`
		)
		SELECT IF(SUM(C.Potenza) IS NOT NULL, SUM(C.Potenza), 0) AS SommaPotenzaClimatizzatori
		FROM
		(
			SELECT U.Climatizzatore, MAX(UltimaData) AS UltimaDataClima
			FROM UltimeAzioni2 U
			GROUP BY U.Climatizzatore
		) AS UV INNER JOIN UltimeAzioni2 U2 ON UV.Climatizzatore = U2.Climatizzatore AND UV.UltimaDataClima = U2.UltimaData INNER JOIN Climatizzatore C ON UV.Climatizzatore = C.Id
		WHERE U2.Azione = "attacca"
    )
		+
    (
		WITH UltimeAzioni AS
		(
			SELECT R.`Dispositivo c.f.`, R.Azione, IF(P.`Registro dispositivi c.f.` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(CURRENT_TIMESTAMP > P.`Fine`, P.`Fine`, CURRENT_TIMESTAMP)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
			FROM `Registro dispositivi c.f.` R LEFT OUTER JOIN `Programmazione dispositivi c.f.` P ON R.Id = P.`Registro dispositivi c.f.`
			WHERE `Timestamp` IS NOT NULL AND CURRENT_TIMESTAMP > `Timestamp`
		),
		AzioniDispositivoCF AS
		(
			SELECT UltimeAzioni.`Dispositivo c.f.` AS DispositivoCF, UltimeAzioni.Azione
			FROM
			(
				SELECT `Dispositivo c.f.`, MAX(`Ultima ripetizione`) AS `Ultima data`
				FROM UltimeAzioni
				GROUP BY `Dispositivo c.f.`
			) AS UR INNER JOIN UltimeAzioni ON UR.`Ultima data` =  UltimeAzioni.`Ultima ripetizione` AND UR.`Dispositivo c.f.` = UltimeAzioni.`Dispositivo c.f.`
		)
		SELECT IF(SUM(D.Consumo) IS NOT NULL, SUM(D.Consumo), 0) AS SommaPotenzaCF
		FROM AzioniDispositivoCF A INNER JOIN `Dispositivo c.f.` D ON A.DispositivoCF = D.Dispositivo
		WHERE A.Azione = "accendi"
    )
		+
	(
		WITH UltimeAzioni AS
		(
			SELECT R.`Livello potenza dispositivo`, R.`Livello potenza id`, IF(P.`Registro dispositivi c.v.i.` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(CURRENT_TIMESTAMP > P.`Fine`, P.`Fine`, CURRENT_TIMESTAMP)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
			FROM `Registro dispositivi c.v.i.` R LEFT OUTER JOIN `Programmazione dispositivi c.v.i.` P ON R.Id = P.`Registro dispositivi c.v.i.`
			WHERE `Timestamp` IS NOT NULL AND CURRENT_TIMESTAMP > `Timestamp`
		),
		AzioniDispositivoCVI AS
		(
			SELECT UltimeAzioni.`Livello potenza dispositivo` AS DispositivoCVI, UltimeAzioni.`Livello potenza id`
			FROM
			(
				SELECT `Livello potenza dispositivo`, MAX(`Ultima ripetizione`) AS `Ultima data`
				FROM UltimeAzioni
				GROUP BY `Livello potenza dispositivo`
			) AS UR INNER JOIN UltimeAzioni ON UR.`Ultima data` =  UltimeAzioni.`Ultima ripetizione` AND UR.`Livello potenza dispositivo` = UltimeAzioni.`Livello potenza dispositivo`
		)
		SELECT IF(SUM(L.Potenza) IS NOT NULL, SUM(L.Potenza), 0) AS SommaPotenzaCVI
		FROM AzioniDispositivoCVI A INNER JOIN `Dispositivo` D ON A.DispositivoCVI = D.Id INNER JOIN `Livello potenza` L ON A.`Livello potenza id` = L.`Id` AND A.DispositivoCVI = L.`Dispositivo`
		WHERE L.Potenza != 0
    )
		+	
	(
		WITH UltimeAzioni AS
		(
			SELECT R.`Programma dispositivo`, R.`Programma id`, IF(P.`Registro dispositivi c.v.n.i.` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(CURRENT_TIMESTAMP > P.`Fine`, P.`Fine`, CURRENT_TIMESTAMP)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
			FROM `Registro dispositivi c.v.n.i.` R LEFT OUTER JOIN `Programmazione dispositivi c.v.n.i.` P ON R.Id = P.`Registro dispositivi c.v.n.i.`
			WHERE `Timestamp` IS NOT NULL AND CURRENT_TIMESTAMP > `Timestamp`
		),
		AzioniDispositivoCVNI AS
		(
			SELECT UltimeAzioni.`Programma dispositivo` AS DispositivoCVNI, UltimeAzioni.`Programma id`, UR.`Ultima data`
			FROM
			(
				SELECT `Programma dispositivo`, MAX(`Ultima ripetizione`) AS `Ultima data`
				FROM UltimeAzioni
				GROUP BY `Programma dispositivo`
			) AS UR INNER JOIN UltimeAzioni ON UR.`Ultima data` =  UltimeAzioni.`Ultima ripetizione` AND UR.`Programma dispositivo` = UltimeAzioni.`Programma dispositivo`
		)
		SELECT IF(SUM(P.Potenza) IS NOT NULL, SUM(P.Potenza), 0)
		FROM AzioniDispositivoCVNI A INNER JOIN `Dispositivo` D ON A.DispositivoCVNI = D.Id INNER JOIN `Programma` P ON A.`Programma id` = P.`Id` AND A.DispositivoCVNI = P.`Dispositivo`
		WHERE `Ultima data` + INTERVAL P.Durata MINUTE > CURRENT_TIMESTAMP
    );
    
    SET DeltaProduzione = DeltaEnergia - MediaProduzione;
    SET DeltaEnergia = DeltaEnergia + ConsumoIstantaneo;
    SET DeltaConsumo = ConsumoIstantaneo - MediaConsumo;
    IF DeltaProduzione > 0 AND DeltaConsumo <= 0 THEN
		CALL `Suggerisci accensione`();
    END IF;
    
    IF(DeltaEnergia > 0 AND DeltaConsumo >= 0) THEN
		IF(DeltaConsumo < DeltaEnergia) THEN
			CALL `Suggerisci spengimento`(DeltaConsumo);
		ELSE
			CALL `Suggerisci spengimento`(DeltaEnergia);
		END IF;
	END IF;
    
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `Suggerisci spengimento`;
DELIMITER $$
CREATE PROCEDURE `Suggerisci spengimento`(DeltaEnergia DOUBLE)
BEGIN
	DECLARE PotenzaInEccesso DOUBLE;
    DECLARE finito INTEGER DEFAULT 0;
    DECLARE Potenza DOUBLE;
    DECLARE IdDisp INT UNSIGNED;
    DECLARE Tipo VARCHAR(3);
    DECLARE DispDaSpengere CURSOR FOR
	WITH UltimeAzioni AS
	(
		SELECT R.`Dispositivo c.f.`, R.Azione, IF(P.`Registro dispositivi c.f.` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(CURRENT_TIMESTAMP > P.`Fine`, P.`Fine`, CURRENT_TIMESTAMP)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
		FROM `Registro dispositivi c.f.` R LEFT OUTER JOIN `Programmazione dispositivi c.f.` P ON R.Id = P.`Registro dispositivi c.f.`
		WHERE `Timestamp` IS NOT NULL AND CURRENT_TIMESTAMP > `Timestamp`
	),
	AzioniDispositivoCF AS
	(
		SELECT UltimeAzioni.`Dispositivo c.f.` AS DispositivoCF, UltimeAzioni.Azione
		FROM
		(
			SELECT `Dispositivo c.f.`, MAX(`Ultima ripetizione`) AS `Ultima data`
			FROM UltimeAzioni
			GROUP BY `Dispositivo c.f.`
		) AS UR INNER JOIN UltimeAzioni ON UR.`Ultima data` =  UltimeAzioni.`Ultima ripetizione` AND UR.`Dispositivo c.f.` = UltimeAzioni.`Dispositivo c.f.`
	),
    CF AS
	(
		SELECT Dispositivo, Consumo AS Potenza, "CF" AS Tipo
		FROM AzioniDispositivoCF A INNER JOIN `Dispositivo c.f.` D ON A.DispositivoCF = D.Dispositivo
		WHERE A.Azione = "accendi"
	),
	UltimeAzioni2 AS
	(
		SELECT R.`Livello potenza dispositivo`, R.`Livello potenza id`, IF(P.`Registro dispositivi c.v.i.` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(CURRENT_TIMESTAMP > P.`Fine`, P.`Fine`, CURRENT_TIMESTAMP)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
		FROM `Registro dispositivi c.v.i.` R LEFT OUTER JOIN `Programmazione dispositivi c.v.i.` P ON R.Id = P.`Registro dispositivi c.v.i.`
		WHERE `Timestamp` IS NOT NULL AND CURRENT_TIMESTAMP > `Timestamp`
	),
	AzioniDispositivoCVI AS
	(
		SELECT UltimeAzioni2.`Livello potenza dispositivo` AS DispositivoCVI, UltimeAzioni2.`Livello potenza id`
		FROM
		(
			SELECT `Livello potenza dispositivo`, MAX(`Ultima ripetizione`) AS `Ultima data`
			FROM UltimeAzioni2
			GROUP BY `Livello potenza dispositivo`
		) AS UR INNER JOIN UltimeAzioni2 ON UR.`Ultima data` =  UltimeAzioni2.`Ultima ripetizione` AND UR.`Livello potenza dispositivo` = UltimeAzioni2.`Livello potenza dispositivo`
	),
	CVI AS
	(

		SELECT Dispositivo, Potenza, "CVI" AS Tipo
		FROM AzioniDispositivoCVI A INNER JOIN `Dispositivo` D ON A.DispositivoCVI = D.Id INNER JOIN `Livello potenza` L ON A.`Livello potenza id` = L.`Id` AND A.DispositivoCVI = L.`Dispositivo`
		WHERE L.Potenza != 0
	),
    T AS
    (
		SELECT * FROM CF
		UNION
		SELECT * FROM CVI
    )
    SELECT *
    FROM T
    ORDER BY T.Potenza DESC;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET finito = 1;
    SET PotenzaInEccesso = DeltaEnergia;
    OPEN DispDaSpengere;
    
    spengi: LOOP
		FETCH DispDaSpengere INTO IdDisp, Potenza, Tipo;
		IF finito = 1 THEN
			LEAVE spengi;
		END IF;
        IF Tipo = "CF" THEN
			INSERT INTO `Registro dispositivi c.f.`(`Timestamp`, `Suggerimento`, `Account`, `Azione`, `Dispositivo c.f.`) VALUES
            (NULL, CURRENT_TIMESTAMP, NULL, "spengi", IdDisp);
            
		ELSE 
			INSERT INTO `Registro dispositivi c.v.i.`(`Timestamp`, `Suggerimento`, `Account`, `Livello potenza id`, `Livello potenza dispositivo`)
            SELECT NULL AS `Timestamp`, CURRENT_TIMESTAMP AS `Suggerimento`, NULL AS `Account`, L.Id AS `Livello potenza id`, CVI.Dispositivo AS `Livello potenza dispositivo`
            FROM `Dispositivo` CVI INNER JOIN `Livello potenza` L ON L.Dispositivo = CVI
            WHERE CVI.Id = IdDisp AND L.Potenza = 0;
            
		END IF;
        SET PotenzaInEccesso = PotenzaInEccesso - Potenza;
        IF PotenzaInEccesso <= 0 THEN
			LEAVE spengi;
		END IF;
	END LOOP spengi;
    CLOSE DispDaSpengere;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `Suggerisci accensione`;
DELIMITER $$
CREATE PROCEDURE `Suggerisci accensione`()
BEGIN
	SELECT "Suggerimento: potresti accendere un dispositivo programmabile in questo momento per migliorare l'efficienza!";
END $$
DELIMITER ;