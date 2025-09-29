# PRIMA RIDONDANZA #

DROP TRIGGER IF EXISTS `Aggiornamento ubicazione`;
DELIMITER $$
CREATE TRIGGER `Aggiornamento ubicazione` AFTER INSERT ON `Registro accessi e intrusioni`
FOR EACH ROW
BEGIN
	IF (NEW.`Azione` = "passa")
	THEN
    UPDATE `Ubicazione`
        SET `Stanza` = 
        (
			SELECT IF(I.Stanza1 = U.Stanza, I.Stanza2, I.Stanza1)
			FROM `Interno` I INNER JOIN (SELECT * FROM Ubicazione) AS U ON U.Stanza = I.Stanza1 OR U.Stanza = I.Stanza2
			WHERE I.`Punto di accesso o intrusione` = NEW.`Punto di accesso o intrusione` AND U.`Account` = NEW.`Account`
        )
        WHERE `Account` = NEW.`Account`;
	END IF;
    
    IF (NEW.`Azione` = "entra")
	THEN
		INSERT INTO `Ubicazione`
        SELECT NEW.`Account` AS `Account`, E.Stanza
        FROM `Esterno` E
        WHERE E.`Punto di accesso o intrusione` = NEW.`Punto di accesso o intrusione`;
	END IF;
    
    IF (NEW.`Azione` = "esci")
    THEN
		DELETE FROM Ubicazione
        WHERE `Account` = NEW.`Account`;
	END IF;
        
END $$
DELIMITER ;


# SECONDA RIDONDANZA #

DROP TRIGGER IF EXISTS `Aggiornamento potenza dissipata`;
DELIMITER $$
CREATE TRIGGER `Aggiornamento potenza dissipata` BEFORE INSERT ON `Tempo`
FOR EACH ROW
BEGIN
	SET NEW.`Potenza dissipata` = 
	(
		WITH UltimeAzioni AS
		(
			SELECT R.Potenza, R.Id, R.Azione, IF(P.`Registro luci` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(NEW.`Timestamp` > P.`Fine`, P.`Fine`, NEW.`Timestamp`)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
			FROM `Registro luci` R LEFT OUTER JOIN `Programmazione luci` P ON R.Id = P.`Registro luci`
			WHERE `Timestamp` IS NOT NULL AND NEW.`Timestamp` > `Timestamp`
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
			SELECT R.Id, R.Azione, IF(P.`Registro clima` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(NEW.`Timestamp` > P.`Fine`, P.`Fine`, NEW.`Timestamp`)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
			FROM `Registro clima` R LEFT OUTER JOIN `Programmazione clima` P ON R.Id = P.`Registro clima`
			WHERE `Timestamp` IS NOT NULL AND NEW.`Timestamp` > `Timestamp`
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
			SELECT R.`Dispositivo c.f.`, R.Azione, IF(P.`Registro dispositivi c.f.` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(NEW.`Timestamp` > P.`Fine`, P.`Fine`, NEW.`Timestamp`)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
			FROM `Registro dispositivi c.f.` R LEFT OUTER JOIN `Programmazione dispositivi c.f.` P ON R.Id = P.`Registro dispositivi c.f.`
			WHERE `Timestamp` IS NOT NULL AND NEW.`Timestamp` > `Timestamp`
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
			SELECT R.`Livello potenza dispositivo`, R.`Livello potenza id`, IF(P.`Registro dispositivi c.v.i.` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(NEW.`Timestamp` > P.`Fine`, P.`Fine`, NEW.`Timestamp`)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
			FROM `Registro dispositivi c.v.i.` R LEFT OUTER JOIN `Programmazione dispositivi c.v.i.` P ON R.Id = P.`Registro dispositivi c.v.i.`
			WHERE `Timestamp` IS NOT NULL AND NEW.`Timestamp` > `Timestamp`
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
			SELECT R.`Programma dispositivo`, R.`Programma id`, IF(P.`Registro dispositivi c.v.n.i.` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL ( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(NEW.`Timestamp` > P.`Fine`, P.`Fine`, NEW.`Timestamp`)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
			FROM `Registro dispositivi c.v.n.i.` R LEFT OUTER JOIN `Programmazione dispositivi c.v.n.i.` P ON R.Id = P.`Registro dispositivi c.v.n.i.`
			WHERE `Timestamp` IS NOT NULL AND NEW.`Timestamp` > `Timestamp`
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
		WHERE `Ultima data` + INTERVAL P.Durata MINUTE > NEW.`Timestamp`
    );
END $$
DELIMITER ;
