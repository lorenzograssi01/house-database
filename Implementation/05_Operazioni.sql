# PRIMA OPERAZIONE #

DROP PROCEDURE IF EXISTS `Persone per stanza`;
DELIMITER $$
CREATE PROCEDURE `Persone per stanza`()
BEGIN
	SELECT S.`Nome` AS `Nome stanza`, S.`Id`, COUNT(U.`Account`) AS `Numero Persone`
	FROM `Ubicazione` U RIGHT OUTER JOIN `Stanza` S ON U.`Stanza` = S.`Id` 
	GROUP BY S.`Id`;
END $$
DELIMITER ;


# SECONDA OPERAZIONE #

DROP PROCEDURE IF EXISTS `Luci accese`;
DELIMITER $$
CREATE PROCEDURE `Luci accese`()
BEGIN
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
	)
	SELECT UV.PuntoLuce AS `Punto luce`
	FROM
	(
		SELECT U.PuntoLuce, MAX(UltimaData) AS UltimaDataLuce
		FROM UltimeAzioni2 U
		GROUP BY U.PuntoLuce
	) AS UV INNER JOIN UltimeAzioni2 U2 ON UV.PuntoLuce = U2.PuntoLuce AND UV.UltimaDataLuce = U2.UltimaData
	WHERE U2.Azione = "accendi";
END $$
DELIMITER ;


# TERZA OPERAZIONE #

DROP PROCEDURE IF EXISTS `Spengimento luci`;
DELIMITER $$
CREATE PROCEDURE `Spengimento luci`(IN `Account` VARCHAR(20))
BEGIN
	DECLARE newId INT UNSIGNED;
    
    CREATE TEMPORARY TABLE IF NOT EXISTS LuciAccese
    (
		IdLuce INT UNSIGNED PRIMARY KEY
    );
    
    TRUNCATE TABLE LuciAccese;
    
    INSERT INTO LuciAccese
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
		)
		SELECT UV.PuntoLuce AS IdLuce
		FROM
		(
			SELECT U.PuntoLuce, MAX(UltimaData) AS UltimaDataLuce
			FROM UltimeAzioni2 U
			GROUP BY U.PuntoLuce
		) AS UV INNER JOIN UltimeAzioni2 U2 ON UV.PuntoLuce = U2.PuntoLuce AND UV.UltimaDataLuce = U2.UltimaData
		WHERE U2.Azione = "accendi";
	IF (SELECT COUNT(*) FROM LuciAccese) != 0 THEN
		SET newId = 1 +
		(
			SELECT MAX(A.Id)
			FROM `Registro luci` AS A
		);
		INSERT INTO `Registro luci`(`Id`, `Timestamp`, `Account`, `Azione`) VALUES (newId, CURRENT_TIMESTAMP, `Account`, "spengi");
		INSERT INTO `Registrazione luci`
			SELECT newId, IdLuce
			FROM LuciAccese;
    END IF;
END $$
DELIMITER ;


# QUARTA OPERAZIONE #

DROP PROCEDURE IF EXISTS `Cambio lampadina`;
DELIMITER $$
CREATE PROCEDURE `Cambio lampadina` (IN `Punto luce` INT UNSIGNED, IN `Lampadina` INT UNSIGNED)
BEGIN
	DECLARE attacco CHAR(3);
    SET attacco =
    (	
		SELECT L.`Tipo di attacco`
        FROM `Lampadina` L
        WHERE L.`Id` = `Lampadina`
    );
	IF attacco != 
    (
		SELECT P.`Tipo di attacco`
        FROM `Punto luce` P
        WHERE P.`Id` = `Punto luce`
    ) THEN
		SIGNAL SQLSTATE "45000"
        SET MESSAGE_TEXT = "Lampadine non scambiabili: attacco non compatibile";
	END IF;
    
    IF 0 !=
    (
		SELECT COUNT(*)
		FROM `Registro spostamenti` RS
		WHERE RS.`Fine` IS NULL AND RS.`Punto luce` = `Punto luce` AND RS.`Lampadina` = `Lampadina`
    ) THEN
		SIGNAL SQLSTATE "45000"
        SET MESSAGE_TEXT = "Lampadina già connessa a quel punto luce";
	END IF;
    
    
    UPDATE `Registro spostamenti` RS
    SET RS.`Fine` = CURRENT_TIMESTAMP
    WHERE RS.`Fine` IS NULL AND (RS.`Punto luce` = `Punto luce` OR RS.`Lampadina` = `Lampadina`);
    
    INSERT INTO `Registro spostamenti` VALUES(`Punto luce`, `Lampadina`, CURRENT_TIMESTAMP, NULL);
    
END $$
DELIMITER ;


# QUINTA OPERAZIONE #

DROP PROCEDURE IF EXISTS `Accessi aperti`;
DELIMITER $$
CREATE PROCEDURE `Accessi aperti`()
BEGIN
	WITH UltimeAzioni AS
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
	AzioniSerramento AS
	(
		SELECT UltimeAzioni.`Punto di accesso o intrusione` AS Accesso, UltimeAzioni.Azione
		FROM
		(
			SELECT `Punto di accesso o intrusione`, MAX(`Ultima ripetizione`) AS `Ultima data`
			FROM UltimeAzioni
			WHERE Azione = "apri serramento" OR Azione = "chiudi serramento"
			GROUP BY `Punto di accesso o intrusione`
		) AS UR INNER JOIN UltimeAzioni ON UR.`Ultima data` =  UltimeAzioni.`Ultima ripetizione` AND UR.`Punto di accesso o intrusione` = UltimeAzioni.`Punto di accesso o intrusione`
	)
	SELECT *
	FROM
	(
		SELECT PAI.Id, PAI.Tipo, IF(E.`Punto di accesso o intrusione` IS NULL, "interno", "esterno") AS Posizione, IF(APO.Azione = "apri", "aperto", "chiuso") AS Infisso, IF(ASE.Azione = "apri serramento", "aperto", IF(E.Serramento IS NOT NULL, "chiuso", NULL)) AS Serramento
		FROM `Punto di accesso o intrusione` PAI LEFT OUTER JOIN AzioniPorta APO ON PAI.Id = APO.Accesso LEFT OUTER JOIN AzioniSerramento ASE ON PAI.Id = ASE.Accesso LEFT OUTER JOIN Esterno E ON PAI.Id = E.`Punto di accesso o intrusione`
		WHERE PAI.Tipo != "scale"
	) AS A
	WHERE NOT (A.Infisso = "chiuso" AND (A.Serramento = "chiuso" OR A.Serramento IS NULL));
END $$
DELIMITER ;


# SESTA OPERAZIONE #

DROP PROCEDURE IF EXISTS `Dispositivi accesi`;
DELIMITER $$
CREATE PROCEDURE `Dispositivi accesi`()
BEGIN
	WITH AccesiCF AS
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
		SELECT D.Id, D.Nome
		FROM AzioniDispositivoCF A INNER JOIN `Dispositivo` D ON A.DispositivoCF = D.Id
		WHERE A.Azione = "accendi"
	),
	AccesiCVI AS
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
		SELECT D.Id, D.Nome, L.Id AS `Livello potenza`
		FROM AzioniDispositivoCVI A INNER JOIN `Dispositivo` D ON A.DispositivoCVI = D.Id INNER JOIN `Livello potenza` L ON A.`Livello potenza id` = L.`Id` AND A.DispositivoCVI = L.`Dispositivo`
		WHERE L.Potenza != 0
	),
	AccesiCVNI AS
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
		SELECT D.Id, D.Nome, P.Id AS `Programma`
		FROM AzioniDispositivoCVNI A INNER JOIN `Dispositivo` D ON A.DispositivoCVNI = D.Id INNER JOIN `Programma` P ON A.`Programma id` = P.`Id` AND A.DispositivoCVNI = P.`Dispositivo`
		WHERE `Ultima data` + INTERVAL P.Durata MINUTE > CURRENT_TIMESTAMP
	)
	SELECT F.Id AS `Id dispositivo`, F.Nome AS `Nome dispositivo`, "Consumo fisso" AS `Tipo dispositivo`, NULL AS `Livello potenza`, NULL AS `Programma`
	FROM AccesiCF F
	UNION
	SELECT VI.Id AS `Id dispositivo`, VI.Nome AS `Nome dispositivo`, "Consumo variabile interrompibile" AS `Tipo dispositivo`, VI.`Livello potenza`, NULL AS `Programma`
	FROM AccesiCVI VI
	UNION
	SELECT VNI.Id AS `Id dispositivo`, VNI.Nome AS `Nome dispositivo`, "Consumo variabile non interrompibile" AS `Tipo dispositivo`, NULL AS `Livello potenza`, VNI.`Programma`
	FROM AccesiCVNI VNI;
END $$
DELIMITER ;


# SETTIMA OPERAZIONE #

DROP PROCEDURE IF EXISTS `Climatizzatori in funzione`;
DELIMITER $$
CREATE PROCEDURE `Climatizzatori in funzione`()
BEGIN
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
	SELECT UV.Climatizzatore AS `Climatizzatore`, IF(U2.Azione = "accendi" OR U2.Azione = "stacca", "staccato", "attaccato") AS Stato
	FROM
	(
		SELECT U.Climatizzatore, MAX(UltimaData) AS UltimaDataClima
		FROM UltimeAzioni2 U
		GROUP BY U.Climatizzatore
	) AS UV INNER JOIN UltimeAzioni2 U2 ON UV.Climatizzatore = U2.Climatizzatore AND UV.UltimaDataClima = U2.UltimaData
	WHERE U2.Azione != "spengi";
END $$
DELIMITER ;


# OTTAVA OPERAZIONE #

DROP PROCEDURE IF EXISTS `Informazioni account`;
DELIMITER $$
CREATE PROCEDURE `Informazioni account`()
BEGIN
	SELECT acc.*, IF(RA.`Nuovo stato` IS NULL, "mai attivato", RA.`Nuovo stato`) AS Stato
	FROM
	(
		SELECT O.Nome, O.Cognome, A.*, O.Telefono, O.`Data di nascita`, "ospite" AS Tipo
		FROM `Account` A INNER JOIN `Ospite` O ON A.`Nome utente` = O.`Account`
		UNION
		SELECT AB.Nome, AB.Cognome, AC.*, AB.Telefono, AB.`Data di nascita`, "abitante" AS Tipo
		FROM `Account` AC INNER JOIN `Autenticazione abitanti` AuB ON AuB.`Account` = AC.`Nome utente` INNER JOIN `Abitante` AB ON AB.`Codice fiscale` = AuB.`Abitante`
	) AS acc LEFT OUTER JOIN 
	(
		SELECT R.`Nuovo stato`, R.`Account`
		FROM
		(
			SELECT `Account`, MAX(`Timestamp`) AS UltimaVolta
			FROM `Registro account`
			GROUP BY `Account`
		) AS B INNER JOIN `Registro account` R ON B.UltimaVolta = R.`Timestamp` AND B.`Account` = R.`Account`
	) AS RA ON acc.`Nome utente` = RA.`Account`;
END $$
DELIMITER ;


# NONA OPERAZIONE #

DROP PROCEDURE IF EXISTS `Potenza media`;
DELIMITER $$
CREATE PROCEDURE `Potenza media`(IN Inizio TIMESTAMP, IN Fine TIMESTAMP)
BEGIN
	SELECT AVG(T.`Potenza dissipata`) AS `Potenza dissipata media`
    FROM Tempo T
    WHERE T.`Timestamp` BETWEEN Inizio AND Fine;
END $$
DELIMITER ;
