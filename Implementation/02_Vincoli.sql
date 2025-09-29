# PRIMO VINCOLO #

DROP TRIGGER IF EXISTS `Attacco luce`;
DELIMITER $$
CREATE TRIGGER `Attacco luce`
BEFORE INSERT ON `Registro spostamenti`
FOR EACH ROW
BEGIN
	DECLARE attacco CHAR(3);
	SET attacco = 
    (
		SELECT L.`Tipo di attacco`
        FROM `Lampadina` L
        WHERE L.`Id` = NEW.`Lampadina`
    );
    IF attacco != 
    (
		SELECT P.`Tipo di attacco`
        FROM `Punto luce` P
        WHERE P.`Id` = NEW.`Punto luce`
    ) THEN
		SIGNAL SQLSTATE "45000"
        SET MESSAGE_TEXT = "Lampadina non inseribile: attacco non compatibile";
	END IF;
END $$
DELIMITER ;


# SECONDO VINCOLO #

DROP TABLE IF EXISTS `Id accessi aperti`;
CREATE TEMPORARY TABLE `Id accessi aperti`
(
	`Id` INT UNSIGNED PRIMARY KEY
);

DROP TRIGGER IF EXISTS `Passaggio porta`;
DELIMITER $$
CREATE TRIGGER `Passaggio porta`
BEFORE INSERT ON `Registro accessi e intrusioni`
FOR EACH ROW
BEGIN
	IF(NEW.`Azione` = "passa") AND
    (
		SELECT COUNT(*)
		FROM Interno I
		WHERE I.`Punto di accesso o intrusione` = NEW.`Punto di accesso o intrusione`
    ) = 0
	THEN
		SIGNAL SQLSTATE "45000"
		SET MESSAGE_TEXT = "Impossibile usare azione passa con un accesso esterno";
	END IF;
    
	IF(NEW.`Azione` = "entra" OR NEW.`Azione` = "esci") AND
    (
		SELECT COUNT(*)
		FROM Esterno E
		WHERE E.`Punto di accesso o intrusione` = NEW.`Punto di accesso o intrusione`
    ) = 0
	THEN
		SIGNAL SQLSTATE "45000"
		SET MESSAGE_TEXT = "Impossibile usare azione entra o esci con un accesso interno";
	END IF;
	
	IF (NEW.`Azione` = "passa") AND
	(
		SELECT COUNT(*)
		FROM `Interno` I INNER JOIN Ubicazione U ON U.Stanza = I.Stanza1 OR U.Stanza = I.Stanza2
		WHERE I.`Punto di accesso o intrusione` = NEW.`Punto di accesso o intrusione` AND U.`Account` = NEW.`Account`
	) = 0
	THEN
		SIGNAL SQLSTATE "45000"
		SET MESSAGE_TEXT = "Accesso non raggiungibile: la persona non si trova in una stanza comunicante con questo accesso";
	END IF;
    
	IF (NEW.`Azione` = "entra") AND
	(
		SELECT COUNT(*)
		FROM Ubicazione
		WHERE `Account` = NEW.`Account`
	) != 0
	THEN
		SIGNAL SQLSTATE "45000"
		SET MESSAGE_TEXT = "Impossibile entrare: la persona si trova già in casa";
	END IF;
    
	IF (NEW.`Azione` = "esci") AND
	(
		SELECT COUNT(*)
		FROM `Esterno` E INNER JOIN Ubicazione U ON U.Stanza = E.Stanza
		WHERE E.`Punto di accesso o intrusione` = NEW.`Punto di accesso o intrusione` AND U.`Account` = NEW.`Account`
	) = 0
	THEN
		SIGNAL SQLSTATE "45000"
		SET MESSAGE_TEXT = "Accesso non raggiungibile: la persona non si trova in una stanza comunicante con questo accesso";
	END IF;
    
    DELETE FROM `Id accessi aperti`;
    
    INSERT INTO `Id accessi aperti`
	WITH UltimeAzioni AS 
	(
		SELECT R.`Punto di accesso o intrusione`, R.Azione, IF(P.`Registro accessi e intrusioni` IS NOT NULL, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND + INTERVAL 
			( ( TIMESTAMPDIFF(SECOND, (R.`Timestamp` + INTERVAL P.`Sfasamento` SECOND), IF(NEW.`Timestamp` > P.`Fine`, P.`Fine`, NEW.`Timestamp`)) DIV P.`Frequenza`) * P.`Frequenza`) SECOND), R.`Timestamp`) AS `Ultima ripetizione`
		FROM `Registro accessi e intrusioni` R LEFT OUTER JOIN `Programmazione accessi` P ON R.Id = P.`Registro accessi e intrusioni`
		WHERE `Timestamp` IS NOT NULL AND NEW.`Timestamp` > `Timestamp`
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
	SELECT A.Id
	FROM
	(
		SELECT PAI.Id, PAI.Tipo, IF(E.`Punto di accesso o intrusione` IS NULL, "interno", "esterno")
		AS Posizione, IF(APO.Azione = "apri", "aperto", "chiuso") AS Infisso, IF(ASE.Azione = "apri serramento", "aperto", IF(E.Serramento IS NOT NULL, "chiuso", NULL)) AS Serramento
		FROM `Punto di accesso o intrusione` PAI LEFT OUTER JOIN AzioniPorta APO ON PAI.Id = APO.Accesso LEFT OUTER JOIN AzioniSerramento ASE ON PAI.Id = ASE.Accesso LEFT OUTER JOIN Esterno E ON PAI.Id = E.`Punto di accesso o intrusione`
		WHERE PAI.Tipo != "scale"
	) AS A
	WHERE (A.Infisso = "aperto" AND (A.Serramento = "aperto" OR A.Serramento IS NULL));
    
	IF NEW.`Punto di accesso o intrusione` NOT IN 
    (    
		SELECT *
        FROM `Id accessi aperti`
	) AND (NEW.Azione = "passa" OR NEW.Azione = "entra" OR NEW.Azione = "esci")
    THEN
		SIGNAL SQLSTATE "45000"
        SET MESSAGE_TEXT = "Errore: accesso non attraversabile";
    END IF;
END $$
DELIMITER ;