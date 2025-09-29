DROP SCHEMA IF EXISTS `casa_domotica`;
CREATE SCHEMA `casa_domotica`;

USE `casa_domotica`;


# ACCOUNTING #

DROP TABLE IF EXISTS `Account`;
CREATE TABLE `Account`
(
	`Nome utente` VARCHAR(20) PRIMARY KEY,
    `Password` VARCHAR(20) NOT NULL,
    `Domanda di sicurezza` VARCHAR(100) NOT NULL,
    `Risposta di sicurezza` VARCHAR(50) NOT NULL
);

DROP TABLE IF EXISTS `Registro account`;
CREATE TABLE `Registro account`
(
	`Account` VARCHAR(20),
    `Timestamp` TIMESTAMP,
    `Nuovo stato` VARCHAR(20) NOT NULL CHECK (`Nuovo stato` IN ("attivo", "disattivo")),
    FOREIGN KEY(`Account`)
		REFERENCES `Account`(`Nome utente`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
    PRIMARY KEY(`Account`, `Timestamp`)
);

DROP TABLE IF EXISTS `Abitante`;
CREATE TABLE `Abitante`
(
	`Codice fiscale` VARCHAR(20) PRIMARY KEY,
    `Ente di rilascio` VARCHAR(50) NOT NULL,
    `Numero documento` VARCHAR(20) NOT NULL,
    `Scadenza` DATE NOT NULL,
    `Tipologia` VARCHAR(20) NOT NULL CHECK (`Tipologia` IN ("patente", "carta d'identità", "passaporto")),
    `Cognome` VARCHAR(30) NOT NULL,
    `Nome` VARCHAR(30) NOT NULL,
	`Telefono` VARCHAR(20) UNIQUE NOT NULL,
    `Data di nascita` DATE NOT NULL,
    UNIQUE(`Tipologia`, `Numero documento`)
);

DROP TABLE IF EXISTS `Autenticazione abitanti`;
CREATE TABLE `Autenticazione abitanti`
(
	`Account` VARCHAR(20),
    FOREIGN KEY(`Account`)
		REFERENCES `Account`(`Nome utente`)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
    `Abitante` VARCHAR(16),
    FOREIGN KEY(`Abitante`)
		REFERENCES `Abitante`(`Codice fiscale`)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
    PRIMARY KEY(`Account`, `Abitante`)
);

DROP TABLE IF EXISTS `Ospite`;
CREATE TABLE `Ospite`
(
	`Account` VARCHAR(20) PRIMARY KEY,
    FOREIGN KEY(`Account`)
		REFERENCES `Account`(`Nome utente`)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Nome` VARCHAR(30),
    `Cognome` VARCHAR(30),
    `Indirizzo` VARCHAR(150),
    `Telefono` VARCHAR(20) UNIQUE,
    `Data di nascita` DATE,
    UNIQUE (`Nome`, `Cognome`, `Indirizzo`, `Data di nascita`)
);

DROP TABLE IF EXISTS `Relazione`;
CREATE TABLE `Relazione`
(
	`Abitante` VARCHAR(20),
    FOREIGN KEY(`Abitante`)
		REFERENCES `Abitante`(`Codice Fiscale`)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
    `Ospite` VARCHAR(20),
    FOREIGN KEY(`Ospite`)
		REFERENCES `Ospite`(`Account`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Tipo` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`Abitante`, `Ospite`)
);


# TOPOLOGIA DELL'EDIFICIO #

DROP TABLE IF EXISTS `Punto di accesso o intrusione`;
CREATE TABLE `Punto di accesso o intrusione`
(
	`Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Tipo` VARCHAR(20) NOT NULL CHECK (`Tipo` IN ("porta", "finestra", "porta-finestra", "scale", "ascensore"))
);

DROP TABLE IF EXISTS `Stanza`;
CREATE TABLE `Stanza`
(
	`Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Nome` VARCHAR(20) NOT NULL,
    `Piano` INT UNSIGNED NOT NULL,
	`Altezza` DOUBLE NOT NULL,
    `Lunghezza` DOUBLE NOT NULL,
    `Larghezza` DOUBLE NOT NULL
);


# ACCOUNTING #

DROP TABLE IF EXISTS `Ubicazione`;
CREATE TABLE `Ubicazione`
(
	`Account` VARCHAR(20),
		FOREIGN KEY(`Account`)
		REFERENCES `Account`(`Nome utente`)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
    `Stanza` INT UNSIGNED,
		FOREIGN KEY(`Stanza`)
		REFERENCES `Stanza`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
    PRIMARY KEY (`Account`, `Stanza`)
);


# TOPOLOGIA DELL'EDIFICIO #

DROP TABLE IF EXISTS `Interno`;
CREATE TABLE `Interno`
(
	`Punto di accesso o intrusione` INT UNSIGNED PRIMARY KEY,
		FOREIGN KEY(`Punto di accesso o intrusione`)
		REFERENCES `Punto di accesso o intrusione`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
    `Stanza1` INT UNSIGNED NOT NULL,
		FOREIGN KEY(`Stanza1`)
		REFERENCES `Stanza`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
    `Stanza2` INT UNSIGNED NOT NULL,
		FOREIGN KEY(`Stanza2`)
		REFERENCES `Stanza`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE
);

DROP TABLE IF EXISTS `Disposizione stanze`;
CREATE TABLE `Disposizione stanze`
(
    `Stanza1` INT UNSIGNED NOT NULL,
		FOREIGN KEY(`Stanza1`)
		REFERENCES `Stanza`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
    `Stanza2` INT UNSIGNED NOT NULL,
		FOREIGN KEY(`Stanza2`)
		REFERENCES `Stanza`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Direzione` VARCHAR(9) NOT NULL CHECK(`Direzione` IN ("est-ovest", "nord-sud")),
    PRIMARY KEY(`Stanza1`, `Stanza2`)
);

DROP TABLE IF EXISTS `Esterno`;
CREATE TABLE `Esterno`
(
	`Punto di accesso o intrusione` INT UNSIGNED PRIMARY KEY,
		FOREIGN KEY(`Punto di accesso o intrusione`)
		REFERENCES `Punto di accesso o intrusione`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
    `Stanza` INT UNSIGNED NOT NULL,
		FOREIGN KEY(`Stanza`)
		REFERENCES `Stanza`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Punto cardinale` VARCHAR(10) NOT NULL CHECK(`Punto cardinale` IN ("est", "nord", "sud", "ovest")),
	`Serramento` VARCHAR(20)
);


# DISPOSITIVI E SMART PLUG #

DROP TABLE IF EXISTS `Dispositivo`;
CREATE TABLE `Dispositivo`
(
    `Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Nome` VARCHAR(30) NOT NULL,
    `Condizione` VARCHAR(11) NOT NULL CHECK (`Condizione` IN ("guasto", "funzionante", "difettoso"))
);

DROP TABLE IF EXISTS `Livello potenza`;
CREATE TABLE `Livello potenza`
(  
    `Id` INT UNSIGNED,
    `Potenza` INT UNSIGNED NOT NULL,
    `Dispositivo` INT UNSIGNED,
    FOREIGN KEY (`Dispositivo`)
		REFERENCES `Dispositivo`(`Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    PRIMARY KEY(`Dispositivo`, `Id`)
);

DROP TABLE IF EXISTS `Programma`;
CREATE TABLE `Programma`
(
    `Id` INT UNSIGNED,
    `Durata` INT UNSIGNED NOT NULL, #in secondi
    `Potenza` INT UNSIGNED NOT NULL,
    `Dispositivo` INT UNSIGNED,
    FOREIGN KEY (`Dispositivo`)
		REFERENCES `Dispositivo`(`Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    PRIMARY KEY(`Dispositivo`, `Id`)
);

DROP TABLE IF EXISTS `Dispositivo c.f.`;
CREATE TABLE `Dispositivo c.f.`
(
    `Consumo` INT UNSIGNED NOT NULL,
    `Dispositivo` INT UNSIGNED PRIMARY KEY,
    FOREIGN KEY (`Dispositivo`)
		REFERENCES `Dispositivo`(`Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE
);

DROP TABLE IF EXISTS `Smart plug`;
CREATE TABLE `Smart plug`
(
    `Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Potenza massima` INT UNSIGNED NOT NULL,
    `Stanza` INT UNSIGNED NOT NULL,
    FOREIGN KEY(`Stanza`)
		REFERENCES `Stanza` (`Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE
);

DROP TABLE IF EXISTS `Registro prese`;
CREATE TABLE `Registro prese`
(
    `Inizio` TIMESTAMP,
    `Fine` TIMESTAMP,
    `Smart plug` INT UNSIGNED NOT NULL,
    FOREIGN KEY(`Smart plug`)
		REFERENCES `Smart plug` (`Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    `Dispositivo` INT UNSIGNED,
	FOREIGN KEY(`Dispositivo`)
		REFERENCES `Dispositivo` (`Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
   PRIMARY KEY (`Inizio`, `Dispositivo`)
);


# INTERAZIONE UTENTE-DISPOSITIVO #

DROP TABLE IF EXISTS `Registro dispositivi c.f.`;
CREATE TABLE `Registro dispositivi c.f.`
(
    `Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Timestamp` TIMESTAMP,
    `Suggerimento` TIMESTAMP,
    `Account` VARCHAR(20),
    FOREIGN KEY (`Account`)
		REFERENCES `Account`(`Nome utente`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    `Azione` VARCHAR(7) NOT NULL CHECK (`Azione` IN ("accendi", "spengi")),
    `Dispositivo c.f.` INT UNSIGNED NOT NULL,
    FOREIGN KEY (`Dispositivo c.f.`)
		REFERENCES `Dispositivo c.f.`(`Dispositivo`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    UNIQUE(`Timestamp`, `Dispositivo c.f.`)
);

DROP TABLE IF EXISTS `Registro dispositivi c.v.i.`;
CREATE TABLE `Registro dispositivi c.v.i.`
(
    `Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Timestamp` TIMESTAMP,
    `Suggerimento` TIMESTAMP,
    `Account` VARCHAR(20),
    FOREIGN KEY (`Account`)
		REFERENCES `Account`(`Nome utente`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    `Livello potenza id` INT UNSIGNED NOT NULL,
    `Livello potenza dispositivo` INT UNSIGNED NOT NULL,
    FOREIGN KEY ( `Livello potenza dispositivo`, `Livello potenza id`)
		REFERENCES `Livello potenza`(`Dispositivo`, `Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    UNIQUE(`Timestamp`, `Livello potenza dispositivo`)
);

DROP TABLE IF EXISTS `Registro dispositivi c.v.n.i.`;
CREATE TABLE `Registro dispositivi c.v.n.i.`
(
    `Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Timestamp` TIMESTAMP,
    `Suggerimento` TIMESTAMP,
    `Account` VARCHAR(20),
    FOREIGN KEY (`Account`)
		REFERENCES `Account`(`Nome utente`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    `Programma id` INT UNSIGNED NOT NULL,
    `Programma dispositivo` INT UNSIGNED NOT NULL,
    FOREIGN KEY (`Programma dispositivo`, `Programma id`)
		REFERENCES `Programma` (`Dispositivo`, `Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    UNIQUE(`Timestamp`, `Programma dispositivo`)
);

DROP TABLE IF EXISTS `Programmazione dispositivi c.f.`;
CREATE TABLE `Programmazione dispositivi c.f.`
(
    `Registro dispositivi c.f.` INT UNSIGNED,
    FOREIGN KEY (`Registro dispositivi c.f.`)
		REFERENCES `Registro dispositivi c.f.` (`Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    `Sfasamento` INT UNSIGNED,
    `Frequenza` INT UNSIGNED,
    `Fine` TIMESTAMP,
    PRIMARY KEY (`Registro dispositivi c.f.`, `Sfasamento`, `Frequenza`)
);

DROP TABLE IF EXISTS `Programmazione dispositivi c.v.i.`;
CREATE TABLE `Programmazione dispositivi c.v.i.`
(
    `Registro dispositivi c.v.i.` INT UNSIGNED,
    FOREIGN KEY (`Registro dispositivi c.v.i.`)
		REFERENCES `Registro dispositivi c.v.i.` (`Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    `Sfasamento` INT UNSIGNED,
    `Frequenza` INT UNSIGNED,
    `Fine` TIMESTAMP,
    PRIMARY KEY (`Registro dispositivi c.v.i.`, `Sfasamento`, `Frequenza`)
);

DROP TABLE IF EXISTS `Programmazione dispositivi c.v.n.i.`;
CREATE TABLE `Programmazione dispositivi c.v.n.i.`
(
    `Registro dispositivi c.v.n.i.` INT UNSIGNED,
    FOREIGN KEY (`Registro dispositivi c.v.n.i.`)
		REFERENCES `Registro dispositivi c.v.n.i.` (`Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    `Sfasamento` INT UNSIGNED,
    `Frequenza` INT UNSIGNED,
    `Fine` TIMESTAMP,
    PRIMARY KEY (`Registro dispositivi c.v.n.i.`, `Sfasamento`, `Frequenza`)
);


# SORGENTI ENERGETICHE #

DROP TABLE IF EXISTS `Sorgente energetica`;
CREATE TABLE `Sorgente energetica`
(
	`Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Tipo` VARCHAR(15) NOT NULL CHECK(`Tipo` IN ("pannello solare", "pala eolica"))
);


# CONTABILIZZAZIONE E USO ENERGIA #

DROP TABLE IF EXISTS `Fascia oraria`;
CREATE TABLE `Fascia oraria`
(
	`Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Costo acquisto` DOUBLE NOT NULL,
    `Prezzo vendita` DOUBLE NOT NULL
);

DROP TABLE IF EXISTS `Tempo`;
CREATE TABLE `Tempo`
(
	`Timestamp` TIMESTAMP PRIMARY KEY,
    `Meteo` VARCHAR(30) NOT NULL,
    `Qualità aria` INT UNSIGNED NOT NULL,
    `Velocità aria` INT UNSIGNED NOT NULL,
    `Pressione atmosferica` INT UNSIGNED NOT NULL,
    `Temperatura` DOUBLE NOT NULL,
    `Umidità` INT UNSIGNED NOT NULL,
    `Fascia oraria` INT UNSIGNED NOT NULL,
    `Potenza dissipata` DOUBLE DEFAULT NULL,
	FOREIGN KEY(`Fascia oraria`)
		REFERENCES `Fascia oraria`(`Id`)
        ON DELETE NO ACTION
        ON UPDATE CASCADE
);

DROP TABLE IF EXISTS `Registro produzione energia`;
CREATE TABLE `Registro produzione energia`
(
	`Sorgente energetica` INT UNSIGNED,
    FOREIGN KEY(`Sorgente energetica`)
		REFERENCES `Sorgente energetica`(`Id`)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
    `Tempo` TIMESTAMP,
    FOREIGN KEY(`Tempo`)
		REFERENCES `Tempo`(`Timestamp`)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
    `Potenza prodotta` DOUBLE NOT NULL,
    PRIMARY KEY(`Sorgente energetica`, `Tempo`)
);


# TRATTAMENTO ARIA #

DROP TABLE IF EXISTS  `Registro clima`;
CREATE TABLE `Registro clima`
(
	`Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Account` VARCHAR(20),
	FOREIGN KEY(`Account`)
		REFERENCES `Account`(`Nome utente`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Timestamp` TIMESTAMP,
    `Azione` VARCHAR(7) NOT NULL CHECK(`Azione` IN ("accendi", "spengi", "stacca", "attacca")), #check
    `Suggerimento` TIMESTAMP,
    UNIQUE(`Account`, `Timestamp`, `Azione`, `Suggerimento`)
);

DROP TABLE IF EXISTS  `Programmazione clima`;
CREATE TABLE `Programmazione clima`
(
    `Registro clima` INT UNSIGNED,
	FOREIGN KEY(`Registro clima`)
		REFERENCES `Registro clima`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Frequenza` INT UNSIGNED,
    `Sfasamento` INT UNSIGNED,
    `Fine` TIMESTAMP,
    PRIMARY KEY (`Registro clima`, `Frequenza`, `Sfasamento`)
);

DROP TABLE IF EXISTS  `Settaggio clima`;
CREATE TABLE `Settaggio clima`
(
	`Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`Umidità` INT UNSIGNED NOT NULL, #%
    `Temperatura` DOUBLE NOT NULL, #C°
    UNIQUE(`Umidità`, `Temperatura`)
);

DROP TABLE IF EXISTS `Impostazione settaggio`;
CREATE TABLE `Impostazione settaggio`
(
    `Settaggio clima` INT UNSIGNED,
	FOREIGN KEY(`Settaggio clima`)
		REFERENCES `Settaggio clima`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Registro clima` INT UNSIGNED,
	FOREIGN KEY(`Registro clima`)
		REFERENCES `Registro clima`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	PRIMARY KEY (`Registro clima`, `Settaggio clima`)
); 

DROP TABLE IF EXISTS  `Climatizzatore`;
CREATE TABLE `Climatizzatore`
(
	`Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Stanza` INT UNSIGNED NOT NULL,
	FOREIGN KEY(`Stanza`)
		REFERENCES `Stanza`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Potenza` INT UNSIGNED NOT NULL #Watt
);

DROP TABLE IF EXISTS  `Utilizzo clima`;
CREATE TABLE `Utilizzo clima`
(
    `Registro clima` INT UNSIGNED,
	FOREIGN KEY(`Registro clima`)
		REFERENCES `Registro clima` (`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Climatizzatore` INT UNSIGNED,
	FOREIGN KEY(`Climatizzatore`)
		REFERENCES `Climatizzatore` (`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	PRIMARY KEY(`Registro clima`, `Climatizzatore`)
);

DROP TABLE IF EXISTS `Qualità aria interna`;
CREATE TABLE `Qualità aria interna`
(
	`Stanza` INT UNSIGNED,
	FOREIGN KEY(`Stanza`)
		REFERENCES `Stanza` (`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Tempo` TIMESTAMP,
	FOREIGN KEY(`Tempo`)
		REFERENCES `Tempo` (`Timestamp`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Temperatura` DOUBLE NOT NULL, #C°
    `Umidità` INT UNSIGNED NOT NULL, #%
	`Rumore` INT UNSIGNED NOT NULL, #db
    `Anidride carbonica` INT UNSIGNED NOT NULL, #ppm (0-1800)
    PRIMARY KEY(`Stanza`, `Tempo`)
);


# SMART LIGHTING #

DROP TABLE IF EXISTS `Punto luce`;
CREATE TABLE `Punto luce`
(
	`Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Tipo di attacco` CHAR(3) NOT NULL CHECK(`Tipo di attacco` IN ("E14", "E27", "E40")), #check
    `Stanza` INT UNSIGNED NOT NULL,
    FOREIGN KEY(`Stanza`)
		REFERENCES `Stanza`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE
);

DROP TABLE IF EXISTS `Registro luci`;
CREATE TABLE `Registro luci`
(
	`Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Timestamp` TIMESTAMP,
    `Account` VARCHAR(20),
    FOREIGN KEY(`Account`)
		REFERENCES `Account`(`Nome utente`),
    `Azione` VARCHAR(7) NOT NULL CHECK(`Azione` IN ("accendi", "spengi")),
    `Temperatura colore` INT UNSIGNED DEFAULT NULL, #kelvin
    `Potenza` INT UNSIGNED DEFAULT NULL, #Watt
    `Suggerimento` TIMESTAMP,
    UNIQUE(`Timestamp`, `Account`, `Azione`, `Temperatura colore`, `Potenza`, `Suggerimento`)
);

DROP TABLE IF EXISTS  `Programmazione luci`;
CREATE TABLE `Programmazione luci`
(
	`Registro luci` INT UNSIGNED,
    FOREIGN KEY(`Registro luci`)
		REFERENCES `Registro luci` (`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Frequenza` INT UNSIGNED NOT NULL,
    `Sfasamento` INT UNSIGNED NOT NULL,
    `Fine` TIMESTAMP,
    PRIMARY KEY (`Registro luci`, `Frequenza`,  `Sfasamento`)
);

DROP TABLE IF EXISTS  `Registrazione luci`;
CREATE TABLE `Registrazione luci`
(
	`Registro luci` INT UNSIGNED,
    FOREIGN KEY(`Registro luci`)
		REFERENCES `Registro luci` (`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
    `Punto luce` INT UNSIGNED,
    FOREIGN KEY(`Punto luce`)
		REFERENCES `Punto luce` (`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
    PRIMARY KEY (`Registro luci`, `Punto luce`)
);

DROP TABLE IF EXISTS `Lampadina`;
CREATE TABLE `Lampadina`
(
	`Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	`Tipo di attacco` VARCHAR(3) NULL CHECK(`Tipo di attacco` IN ("E14", "E27", "E40")), #check,
    `Condizione` VARCHAR(11) NOT NULL CHECK(`Condizione` IN ("funzionante", "difettosa", "guasta")),
    `Temperatura colore` INT UNSIGNED, #kelvin
    `Potenza` INT UNSIGNED NOT NULL #Watt
);

DROP TABLE IF EXISTS `Registro spostamenti`;
CREATE TABLE `Registro spostamenti`
(
    `Punto luce` INT UNSIGNED NOT NULL,
		FOREIGN KEY(`Punto luce`)
		REFERENCES `Punto luce`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Lampadina` INT UNSIGNED,
		FOREIGN KEY(`Lampadina`)
		REFERENCES `Lampadina`(`Id`)
		ON DELETE NO ACTION
        ON UPDATE CASCADE,
	`Inizio` TIMESTAMP,
    `Fine` TIMESTAMP,
    UNIQUE(`Punto luce`, `Inizio`),
    PRIMARY KEY (`Lampadina`, `Inizio`)
);


# ACCESSI/INTRUSIONI #

DROP TABLE IF EXISTS `Registro accessi e intrusioni`;
CREATE TABLE `Registro accessi e intrusioni`
(
    `Id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Timestamp` TIMESTAMP,
    `Azione` VARCHAR(17) NOT NULL CHECK (`Azione` IN ("apri", "chiudi", "passa", "chiudi serramento", "apri serramento", "entra", "esci")),
    `Suggerimento` TIMESTAMP,
    `Account` VARCHAR(20),
    FOREIGN KEY (`Account`) 
		REFERENCES `Account`(`Nome utente`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    `Punto di accesso o intrusione` INT UNSIGNED NOT NULL,
    FOREIGN KEY (`Punto di accesso o intrusione`)
		REFERENCES `Punto di accesso o intrusione`(`Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    UNIQUE (`Timestamp`, `Punto di accesso o intrusione`)
);

DROP TABLE IF EXISTS `Archivio foto`;
CREATE TABLE `Archivio foto`
(
    `Registro accessi e intrusioni` INT UNSIGNED PRIMARY KEY,
    FOREIGN KEY (`Registro accessi e intrusioni`)
		REFERENCES `Registro accessi e intrusioni`(`Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    `Foto` BLOB NOT NULL
);

DROP TABLE IF EXISTS `Programmazione accessi`;
CREATE TABLE `Programmazione accessi`
(
    `Registro accessi e intrusioni` INT UNSIGNED,
    FOREIGN KEY (`Registro accessi e intrusioni`)
		REFERENCES `Registro accessi e intrusioni`(`Id`)
		ON DELETE NO ACTION
		ON UPDATE CASCADE,
    `Frequenza` INT UNSIGNED,
    `Sfasamento` INT UNSIGNED,
    `Fine` TIMESTAMP,
    PRIMARY KEY (`Registro accessi e intrusioni`, `Sfasamento`, `Frequenza`)
);
