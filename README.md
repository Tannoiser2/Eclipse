# Eclipse — Seconda Alba per la Galassia (versione digitale)

Versione digitale di **Eclipse: Second Dawn for the Galaxy** (Touko Tahkokallio, Lautapelit.fi, 2020), il 4X di
fantascienza: da 2 a 6 civiltà esplorano la galassia, colonizzano i pianeti, ricercano tecnologie, progettano le
proprie navi e combattono contro Antichi, Guardiani, il Sistema di Difesa del Centro Galattico (SDCG) e fra loro.

Si gioca qui: https://tannoiser2.github.io/Eclipse/

## Cosa c'è

- Regole complete del gioco base in otto round: azioni (Esplorare, Ricercare, Potenziare, Costruire, Muovere,
  Influenzare), reazioni dopo aver passato, dischi influenza e mantenimento, tracciati della popolazione,
  navi coloniali, commercio, tecnologie con sconti e tecnologie rare, progetti delle navi con energia, propulsori
  e parti antiche, blocco delle navi, wormhole e Generatore di wormhole, Portali di curvatura, combattimento con
  missili, iniziativa, computer, scudi, ritirata, dado a squarcio, reputazione, attacco alla popolazione,
  controllo dei settori dopo la battaglia, scoperte, diplomazia con ambasciatori e Traditore (da 4 giocatori),
  bancarotta ed eliminazione, punteggio finale.
- Le 12 civiltà del gioco base: sei fazioni terrestri e Impero di Eridani, Progresso Hydran, Planta,
  Discendenti di Draco, Mechanema, Egemonia di Orione, ognuna con le sue regole speciali.
- Progetti base o avanzati per Antichi, Guardiani e SDCG (si sceglie nel menu).
- **IA** in tre livelli per i posti vuoti: valuta settori, tecnologie e progetti, tiene d'occhio il mantenimento
  e attacca solo quando una simulazione della battaglia le dà buone probabilità.
- **Mappa 3D**: le tessere settore originali su esagoni in rilievo, i cubetti sui pianeti veri delle tessere,
  i modelli 3D del modulo per intercettori, incrociatori, corazzate, basi stellari e la Luna nera dell'SDCG.
  Trascinare con un dito (o il mouse), pizzicare per lo zoom, ruotare e inclinare con due dita anche su iPad.
- **Online** con gli amici (stanze con codice di 4 lettere, chi esce può rientrare; se uno sparisce gioca l'IA).
- **Partite salvate** su Firebase: «Salva» dà un codice di 6 lettere da usare in «Carica partita».
- Tutto in italiano: interfaccia, diario, regole e titoli delle tessere (tecnologie, parti, scoperte e settori
  riscritti in italiano sulle immagini originali).

## Materiale

Dal modulo di Tabletop Simulator in `Desktop/Ludoteca/Eclipse` (file `.ttsmod`, che è uno zip):

```
python3 tools/estrai_materiale.py <cartella Mods> .   # tessere, parti, scoperte, progetti, modelli 3D
python3 tools/traduci_tessere.py                      # titoli in italiano sulle immagini
```

I dati delle tessere (wormhole, pianeti, Antichi, artefatti di ogni settore; costi delle tecnologie; valori delle
parti; plance delle specie) sono trascritti in `scripts/data/ec_data.gd`; le posizioni dei pianeti sulle
immagini dei settori in `scripts/data/ec_pos.gd`. Il modulo contiene anche pezzi di espansioni (altre specie,
specie minori, eventi galattici): non sono ancora nel gioco.

## Struttura

- `scripts/core/engine.gd` — il motore delle regole (senza grafica); ogni scelta passa da `decide()`.
- `scripts/core/ai.gd` — l'IA.
- `scripts/data/` — dati del gioco.
- `scripts/ui/` — menu, schermata di gioco, mappa 3D, regole.
- `scripts/net/` — Firebase (stanze `eclipse/rooms`, partite salvate `eclipse/partite`).

## Prove

```
godot --headless --path . -s tests/check.gd                       # compila tutti gli script
godot --headless --path . -s tests/sim.gd -- 4 5 -1               # partite fra IA (giocatori, partite, livello -1 = misti)
python3 tools/controlla_glifi.py                                  # ogni carattere esiste nei font
xvfb-run godot --path . -s tests/shot.gd -- /tmp/foto 4 1920 1080 # fotografie dell'interfaccia
python3 tests/firebase_mock.py 8765                               # finto Firebase per online_play.gd e save_load.gd
```

## Pubblicazione

Il workflow `Pubblica` parte a mano (Actions → Pubblica → Run workflow) oppure con un commit che contiene
`[pubblica]` nel messaggio; costruisce la versione web con Godot 4.7 e la mette su GitHub Pages. La cartella
`ludoteca/` presenta il gioco nella ludoteca (https://tannoiser2.github.io/).
