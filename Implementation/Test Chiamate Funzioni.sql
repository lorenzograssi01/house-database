CALL `Persone per stanza`();
CALL `Luci accese`();
CALL `Spengimento luci`("loregrassi"); #ACCOUNT
CALL `Cambio lampadina`(3, 7); #PUNTO LUCE, LAMPADINA
CALL `Accessi aperti`();
CALL `Dispositivi accesi`();
CALL `Climatizzatori in funzione`();
CALL `Informazioni account`();
CALL `Potenza media`("2020-12-06 18:03:33", "2022-12-11 17:32:22"); #INIZIO, FINE

CALL `Prima analytic`(0.1, 0.1); #MIN SUPPORT, MIN CONFIDENCE
CALL `Seconda analytic`();
CALL `Terza analytic`();