# PRIMA ANALYTIC #

DROP PROCEDURE IF EXISTS `Prima analytic`;
DELIMITER $$
CREATE PROCEDURE `Prima analytic`(IN min_supp DOUBLE, IN min_conf DOUBLE)
BEGIN
	# DICHIARAZIONI E INIZIALIZZAZIONI VARIABILI #
	DECLARE k INTEGER DEFAULT 2;
    DECLARE ii INTEGER;
    DECLARE iii INTEGER;
    DECLARE nItemset INTEGER;
    DECLARE nItems INTEGER;
    DECLARE nTransactions INTEGER;
    DECLARE sottoinsieme BIGINT UNSIGNED;
    DECLARE supp_xUy DOUBLE;
    DECLARE supp_x DOUBLE;
    DECLARE conf DOUBLE;
    SET GLOBAL connect_timeout=10000;
    
	DROP TABLE IF EXISTS Items;
    CREATE TABLE Items AS
		SELECT Id
        FROM `Punto luce`;
    
	# CREAZIONE DI TABELLE DI APPOGGIO UTILI #
    DROP TABLE IF EXISTS largeItemset;
    CREATE TABLE largeItemset
    (
		Id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        Support DOUBLE,
        _1 INT UNSIGNED,
        _2 INT UNSIGNED
    );
    
    DROP TABLE IF EXISTS Associazioni;
    CREATE TABLE Associazioni
    (
		Associazione VARCHAR(500),
        Confidence DOUBLE
    );
    
    DROP TABLE IF EXISTS kItemset;
    CREATE TABLE kItemset
    (
		Id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        Support DOUBLE DEFAULT NULL,
		_1 INT UNSIGNED
    );
    
    INSERT INTO kItemset(_1, Support)
    SELECT Id AS _1, NULL AS Support
    FROM Items;
    
    # CREAZIONE TABELLA DELLE TRANSAZIONI #
	SET @@group_concat_max_len = 100000;
    SET @select_a = (
		SELECT GROUP_CONCAT(CONCAT("IF(K.`Punto luce` = ", Id, ", 1, 0) AS `", Id, "`"))
		FROM `Punto luce`
	);
    SET @select_b = (
		SELECT GROUP_CONCAT(CONCAT("IF(SUM(K.`", Id, "`) = 0, 0, 1) AS `", Id, "`"))
		FROM `Punto luce`
	);
    
    DROP TABLE IF EXISTS Transazioni;
    SET @select_a = CONCAT(
		"CREATE TABLE Transazioni AS
			SELECT ", @select_b,
			"FROM
			(
				SELECT K.Timestamp, ", @select_a,
				"FROM
				(
					SELECT * FROM `Registro luci` T1
					INNER JOIN `Registrazione luci` T2 ON T1.Id = T2.`Registro luci`
				) AS K
			) AS K
			GROUP BY HOUR(K.Timestamp), DATE(K.Timestamp)");
    PREPARE sql_statement FROM @select_a;
    EXECUTE sql_statement;
    DROP PREPARE sql_statement;
	
    # CALCOLO VALORI UTILI #
    SET nTransactions = (
		SELECT COUNT(*)
        FROM Transazioni
    );
    SET nItemset = (
		SELECT COUNT(*)
		FROM kItemset
    );
    SELECT * FROM Transazioni;
    
    #CALCOLO SUPPORTO DEGLI 1-ITEMSET #
    SET ii = 1;
    WHILE ii <= nItemset DO
		SET iii = 
        (
			SELECT _1
			FROM kItemset
			WHERE Id = ii
        );
        
        SET @select_a = CONCAT(
			"UPDATE kItemset
			SET Support =
			(
				SELECT COUNT(*)/", nTransactions, "
				FROM Transazioni
				WHERE `", iii, "` = 1
			)
			WHERE Id = ", ii
        );
		PREPARE sql_statement FROM @select_a;
		EXECUTE sql_statement;
		DROP PREPARE sql_statement;
        SET ii = ii + 1;
    END WHILE;
    
    SET @select_a = CONCAT(
		"DELETE FROM kItemset
		WHERE Support < ", min_supp
    );
    PREPARE min_supp_query FROM @select_a;
    EXECUTE min_supp_query;
	DROP PREPARE min_supp_query;
    
	SELECT * FROM kItemset;
        
	DROP TABLE IF EXISTS Current_itemset;
	CREATE TABLE Current_itemset
	(
		ItemId INT UNSIGNED
	);
    
    # CICLO DELL'ALGORITMO APRIORI #
    inizio: LOOP
		SELECT k;
		DROP TABLE IF EXISTS newItemset;
		CREATE TABLE newItemset AS
			SELECT *
			FROM kItemset
			WHERE 1 = 2;
		
        ALTER TABLE newItemset
		MODIFY COLUMN Id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY;
        
		SET @select_q = CONCAT(
			"DELETE FROM newItemset
			WHERE Support < ", min_supp
		);
		PREPARE min_supp_query FROM @select_q;
        
        SET @select_a = CONCAT(
        "ALTER TABLE newItemset
        ADD COLUMN _", k, " INT UNSIGNED");
		PREPARE sql_statement FROM @select_a;
		EXECUTE sql_statement;
		DROP PREPARE sql_statement;
        
        IF k = 2 THEN
			# SE HO DUE ELEMENTI FACCIO COSÌ CHE FACCIO PRIMA #
			INSERT INTO newItemset(_1, _2)
			SELECT _1._1, _2._1
			FROM kItemset _1 CROSS JOIN kItemset _2
			WHERE _1._1 < _2._1;
        ELSE
			# CASO GENERALE CON N ELEMENTI #
			DROP TABLE IF EXISTS newItemset2;
			CREATE TABLE newItemset2 AS
				SELECT *
				FROM kItemset
				WHERE 1 = 2;
			ALTER TABLE newItemset2
			MODIFY COLUMN Id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY;
			ALTER TABLE newItemset2
			MODIFY COLUMN Support DOUBLE DEFAULT NULL;
			SET iii = 0;
            WHILE iii < k - 1 DO
				SET @select_a = CONCAT(
				"ALTER TABLE newItemset2
				ADD COLUMN _", k + iii, " INT UNSIGNED");
				PREPARE sql_statement FROM @select_a;
				EXECUTE sql_statement;
				DROP PREPARE sql_statement;
                SET iii = iii + 1;
            END WHILE;
            
            # RIEMPIO LA TABELLA NEW ITEMSET 2 FACENDO IL CROSS JOIN #
            SET @select_a = "a._1";
            SET @select_b = "b._1";
            SET iii = 2;
            WHILE iii < k DO
				SET @select_a = CONCAT(@select_a, ", a._", iii);
				SET @select_b = CONCAT(@select_b, ", b._", iii);
                SET iii = iii + 1;
            END WHILE;
            SET @select_c = "_1";
            SET iii = 2;
            WHILE iii < 2 * k - 1 DO
				SET @select_c = CONCAT(@select_c, ", _", iii);
                SET iii = iii + 1;
            END WHILE;
            
            SET @select_a = CONCAT(
				"INSERT INTO newItemset2(", @select_c, ")
				SELECT ", @select_a, ", ", @select_b, "
				FROM kItemset a CROSS JOIN kItemset b;"
            );            
			PREPARE sql_statement FROM @select_a;
			EXECUTE sql_statement;
			DROP PREPARE sql_statement;
            
            # SCORRO GLI ITEMSET TEMPORANEI DEL CROSS JOIN E LI METTO IN UNA TABELLA DI APPOGGIO #
			SET ii = 1;
			SET nItemset = 
			(
				SELECT COUNT(*)
				FROM newItemset2
			);
			trova: WHILE ii <= nItemset DO
				TRUNCATE TABLE Current_itemset;
				SET iii = 1;
				WHILE iii <= 2 * k - 2 DO
					SET @select_a = CONCAT(
					"INSERT INTO Current_itemset
						SELECT _", iii,"
						FROM newItemset2
						WHERE Id = ", ii
					);
					PREPARE sql_statement FROM @select_a;
					EXECUTE sql_statement;
					DROP PREPARE sql_statement;
					
					SET iii = iii + 1;
				END WHILE;
                SET ii = ii + 1;
                
                # SE NON CONTIENE k ELEMENTI ALLORA LO SCARTO (NON AVEVO TUTTI GLI ELEMENTI UGUALI TRANNE 1) #
                IF (SELECT COUNT(DISTINCT ItemId) FROM Current_itemset) != k THEN
					ITERATE trova;
				END IF;
                
                # SE HO GIÀ ALLORA LO SCARTO #
                SET @select_a = 
                (
					SELECT GROUP_CONCAT(CONCAT("_", n, " = ", ItemId) SEPARATOR " AND ")
					FROM 
					(
						SELECT *, ROW_NUMBER() OVER(ORDER BY ItemId) AS n
						FROM Current_itemset
						GROUP By ItemId
						ORDER BY ItemId
					) AS D
                );
                
                SET @select_a = CONCAT(
					"SET @c = 
					(SELECT COUNT(*)
					FROM newItemset
					WHERE ", @select_a, ")"
                );
				PREPARE sql_statement FROM @select_a;
                EXECUTE sql_statement;
				DROP PREPARE sql_statement;
                
                IF @c = 1 THEN
					ITERATE trova;
				END IF;
                
                # SE NON CE L'HO ALLORA FACCIO IL PASSO DI PRUNING #
                SET iii = 1;
                prune: WHILE iii <= k DO
					# DEVO SCORRERE I SOTTOINSIEMI E CONTROLLARE CHE TUTTI SIANO PRESENTI IN Lk-1 #
                    SET @select_a = CONCAT(
						"SET @select_a = (
							SELECT GROUP_CONCAT(CONCAT('_', n, ' = ', ItemId) SEPARATOR ' AND ')
                            FROM
                            (
								SELECT ItemId, ROW_NUMBER() OVER(ORDER BY ItemId) AS n
                                FROM
								(
									SELECT *, ROW_NUMBER() OVER(ORDER BY ItemId) AS n
									FROM Current_itemset
									GROUP BY ItemId
									ORDER BY ItemId
								) AS D
								WHERE n != ", iii, "
                                ORDER BY ItemId
                            ) AS D
                        )"
                    );
					PREPARE sql_statement FROM @select_a;
					EXECUTE sql_statement;
					DROP PREPARE sql_statement;
					
					SET @select_a = CONCAT(
						"SET @c = 
						(SELECT COUNT(*)
						FROM kItemset
						WHERE ", @select_a, ")"
					);
					PREPARE sql_statement FROM @select_a;
					EXECUTE sql_statement;
					DROP PREPARE sql_statement;
                    
                    IF @c = 0 THEN
						SET @c = 1;
					ELSE
						SET @c = 0;
					END IF;
                    
					# SE UNO NON C'È ALLORA ESCO DAL CICLO CON @c = 1 COSÌ MI SCARTA QUESTO ITEMSET TEMPORANEO #
					IF @c = 1 THEN
						LEAVE prune;
					END IF;
                    SET iii = iii + 1;
                END WHILE;
                
                IF @c = 1 THEN
					ITERATE trova;
				END IF;
                
                # SE ARRIVO QUA DEVO INSERIRE QUESTO ITEMSET TEMPORANEO DENTRO LA TABELLA DEGLI ITEMSET DEL PASSO k #
				SET @select_a = 
                (
					SELECT GROUP_CONCAT(ItemId)
					FROM 
                    (
						SELECT *
						FROM Current_itemset
						GROUP By ItemId
						ORDER BY ItemId
                    ) AS D
                );
				SET @select_c = "_1";
				SET iii = 2;
				WHILE iii <= k DO
					SET @select_c = CONCAT(@select_c, ", _", iii);
					SET iii = iii + 1;
				END WHILE;
                
                SET @select_a = CONCAT(
					"INSERT INTO newItemset(", @select_c,") VALUES
					(", @select_a, ")"
                );
				PREPARE sql_statement FROM @select_a;
				EXECUTE sql_statement;
				DROP PREPARE sql_statement;
			END WHILE;
        END IF;
        
        # ORA DEVO CALCOLARE IL SUPPORT DI TUTTI GLI ELEMENTI DI Ck #
		SET ii = 1;
        SET nItemset = 
        (
			SELECT COUNT(*)
            FROM newItemset
        );
		WHILE ii <= nItemset DO
			# SCORRO GLI ITEMSET METTENDOLI IN UNA TABELLA DI APPOGGIO #
			TRUNCATE TABLE Current_itemset;
            SET iii = 1;
            WHILE iii <= k DO
				SET @select_a = CONCAT(
				"INSERT INTO Current_itemset
					SELECT _", iii,"
					FROM newItemset
					WHERE Id = ", ii
				);
                PREPARE sql_statement FROM @select_a;
				EXECUTE sql_statement;
				DROP PREPARE sql_statement;
                
				SET iii = iii + 1;
            END WHILE;
            
            # E CALCOLO IL SUPPORT PER QUELL'ITEMSET #
            SET @select_a = 
            (
				SELECT GROUP_CONCAT(CONCAT("`", ItemId, "` = 1") SEPARATOR " AND ")
                FROM Current_itemset
            );
			SET @select_a = CONCAT(
				"UPDATE newItemset
				SET Support =
				(
					SELECT COUNT(*)/", nTransactions, "
					FROM Transazioni
					WHERE ", @select_a, "
				)
				WHERE Id = ", ii
			);
			PREPARE sql_statement FROM @select_a;
			EXECUTE sql_statement;
			DROP PREPARE sql_statement;
			SET ii = ii + 1;
		END WHILE;
        
        # ESCLUDO GLI ITEMSET DI Ck CHE NON HANNO ABBASTANZA SUPPORT CON QUESTA QUERY GIÀ PREPARATA #
        EXECUTE min_supp_query;
        DROP PREPARE min_supp_query;
        
        # COPIO GLI ELEMENTI RIMANENTI, CHE COSTITUISCONO Lk IN UNA TABELLA #
		DROP TABLE kItemset;
		CREATE TABLE kItemset AS
			SELECT *
			FROM newItemset;
            
		# SE NON CE N'È NESSUNO HO FINITO E ESCO DAL CICLO #
        IF (
			SELECT COUNT(*)
            FROM kItemset
        ) = 0 THEN
			LEAVE inizio;
		END IF;
        
        # SENNO AGGIUNGO Lk ALLA TABELLA CHE CONTIENE I LARGE ITEMSET #
        SET @select_a = CONCAT("Support, _1");
        
        SET iii = 2;
        WHILE iii <= k DO
			SET @select_a = CONCAT(@select_a, ", _", iii);
            SET iii = iii + 1;
        END WHILE;
        
        ALTER TABLE largeItemset AUTO_INCREMENT = 1;
        
        SET @select_a = CONCAT(
			"INSERT INTO largeItemset(", @select_a, ")
			SELECT ", @select_a, " FROM kItemset"
        );
        
		PREPARE sql_statement FROM @select_a;
		EXECUTE sql_statement;
		DROP PREPARE sql_statement;
        
        IF k = 63 THEN
			LEAVE inizio;
        END IF;
        
        SET k = k + 1;
        
        SET @select_a = CONCAT(
			"ALTER TABLE largeItemset
			ADD COLUMN _", k, " INT UNSIGNED DEFAULT NULL"
        );
		PREPARE sql_statement FROM @select_a;
		EXECUTE sql_statement;
		DROP PREPARE sql_statement;
        
		SELECT * FROM kItemset;
    END LOOP inizio;
    
    SELECT * FROM largeItemset;

	# ORA CHE ABBIAMO GLI ITEMSET, DEVO TROVARE LE REGOLE DI ASSOCIAZIONE #
    SET nItemset = (
		SELECT COUNT(*)
        FROM largeItemset
    );
    SET ii = 1;
	TRUNCATE TABLE Current_itemset;
    ALTER TABLE Current_itemset
    ADD COLUMN Id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY;
    fine: WHILE ii <= nItemset DO
		# SCORRO I LARGE ITEMSET E LI METTO IN UNA TABELLA DI APPOGGIO #
		TRUNCATE TABLE Current_itemset;
        ALTER TABLE Current_itemset AUTO_INCREMENT = 1;
        SET supp_xUy = (
			SELECT Support
            FROM largeItemset
            WHERE Id = ii
        );
		SET iii = 1;
		WHILE iii <= k DO
			SET @select_a = CONCAT(
			"INSERT INTO Current_itemset(ItemId)
				SELECT _", iii,"
				FROM largeItemset
				WHERE Id = ", ii, " AND _", iii," IS NOT NULL"
			);
			PREPARE sql_statement FROM @select_a;
			EXECUTE sql_statement;
			DROP PREPARE sql_statement;
			
			SET iii = iii + 1;
		END WHILE;
        
        # QUA ORA DEVO VEDERE LE REGOLE DI ASSOCIAZIONE DERIVANTI DALL'ITEMSET CORRENTE #
        SET nItems = (
			SELECT COUNT(*)
            FROM Current_itemset
        );
        SET sottoinsieme = (1 << nItems) - 2;
        
        ass: WHILE sottoinsieme >= 1 DO
			SET @select_a = 
            (
				SELECT GROUP_CONCAT(CONCAT("`", ItemId, "` = 1") SEPARATOR " AND ")
                FROM Current_itemset
                WHERE (1 << (Id - 1)) & sottoinsieme != 0
            );
			SET @select_a = CONCAT(
				"SET @select_a =
				(
					SELECT COUNT(*)/", nTransactions, "
					FROM Transazioni
					WHERE ", @select_a, "
				)"
			);
			PREPARE sql_statement FROM @select_a;
			EXECUTE sql_statement;
			DROP PREPARE sql_statement;
            
            SET supp_x = @select_a;
            
            SET conf = supp_xUy / supp_x;
            
			SET sottoinsieme = sottoinsieme - 1;
            IF conf < min_conf THEN
				ITERATE ass;
			END IF;
            
			SET @select_c = 
            (
				SELECT GROUP_CONCAT(ItemId)
                FROM Current_itemset
                WHERE (1 << (Id - 1)) & (sottoinsieme + 1) != 0
            );
            SET @select_b =
			(
				SELECT GROUP_CONCAT(ItemId)
                FROM Current_itemset
                WHERE (1 << (Id - 1)) & (sottoinsieme + 1) = 0
            );
            SET @select_a = CONCAT(@select_c, " -> " ,@select_b);
            
            INSERT INTO Associazioni VALUES
            (@select_a, conf);
        END WHILE;
        
        SET ii = ii + 1;
    END WHILE fine;
    
    SELECT * FROM Associazioni;
    
    DROP TABLE IF EXISTS Items;
    DROP TABLE IF EXISTS largeItemset;
    DROP TABLE IF EXISTS kItemset;
    DROP TABLE IF EXISTS newItemset;
    DROP TABLE IF EXISTS newItemset2;
    DROP TABLE IF EXISTS Current_itemset;
    DROP TABLE IF EXISTS Transazioni;
END $$
DELIMITER ;
