extends RefCounted
## Regole complete, scritte apposta per questa versione digitale e divise in capitoli.
## I capitoli segnati con "@" vengono composti al volo dai dati del gioco (specie, tecnologie, parti).

const D = preload("res://scripts/data/ec_data.gd")

const H := "[font_size=28][color=#ffd27e]%s[/color][/font_size]\n"
const S := "\n[font_size=22][color=#3fc6ea]%s[/color][/font_size]\n"

const CHAPTERS := [
	["Scopo e panoramica", """Ogni giocatore guida una civiltà che si espande in una galassia ancora da scoprire. La partita dura [b]otto round[/b]; alla fine dell’ottavo vince chi ha più [b]punti vittoria[/b] (PV). A parità di punti vince chi ha più risorse in magazzino (materiali, scienza e denaro sommati).

I punti arrivano da molte strade: i settori controllati, le tessere reputazione guadagnate combattendo, gli ambasciatori, i monoliti, le scoperte tenute come punti, le tecnologie accumulate su un tracciato e le abilità della propria specie. Non esiste una strategia unica: chi combatte molto guadagna reputazione, chi si espande guadagna settori, chi ricerca guadagna tracciati e monoliti.

In questa versione la galassia è in 3D: trascini per spostare la visuale, usi la rotella o il pizzico per lo zoom e due dita (o il tasto destro) per ruotarla. A destra c’è la plancia della civiltà selezionata; in basso compaiono le scelte che ti riguardano."""],

	["Le plance", """[b]La plancia della civiltà[/b] (in alto a destra, tocca per ingrandirla) riproduce quella del gioco da tavolo:
• in alto i [b]progetti delle navi[/b]: intercettore, incrociatore, corazzata e base stellare, con il costo in materiali nel cerchio marrone. Ogni casella ha una parte stampata; le parti che monti con Potenziare compaiono sopra la casella;
• sotto, il costo dell’[b]orbitale[/b] e del [b]monolito[/b];
• a sinistra il nome della specie, il valore di commercio e le risorse iniziali;
• al centro i tre [b]tracciati delle tecnologie[/b] (militari in rosa, reticolo in verde, nano in giallo). Ogni casella mostra lo sconto che la tecnologia successiva riceverà (-1, -2, ... -8) e, dalla quarta casella, i PV del tracciato (scudetti gialli);
• in basso le [b]sei azioni[/b] con il numero di attivazioni della tua specie: quando fai un’azione ci viene messo un disco;
• in fondo il [b]tracciato dell’influenza[/b]: i dischi ancora liberi occupano le caselle a destra. Il numero più a destra rimasto scoperto è il [b]mantenimento[/b] che pagherai a fine round;
• a destra le caselle per le [b]tessere reputazione[/b] e gli [b]ambasciatori[/b] (le caselle grigie in alto accettano solo ambasciatori).

[b]La plancia di popolazione e scorte[/b] (sotto la prima):
• i tre quadranti sono i [b]tracciati di popolazione[/b] di materiali, scienza e denaro. I cubetti stanno sui petali più alti; il numero del primo petalo scoperto è la [b]produzione[/b] di ogni round, scritta anche al centro. Ogni cubetto che metti su un pianeta lascia scoperto un petalo e aumenta la produzione;
• il segnalino colorato sul bordo numerato indica la [b]scorta[/b] di ogni risorsa (oltre 39 riparte dallo zero con l’indicazione +40);
• in basso le [b]navi coloniali[/b]: bianche se pronte, scure se già usate in questo round."""],

	["Il round", """Ogni round ha quattro fasi.

[b]1. Azioni.[/b] Si gioca a turno, cominciando dal primo giocatore e proseguendo in senso orario. Al tuo turno fai [b]una sola azione[/b] oppure [b]passi[/b]. Si continua a girare finché tutti hanno passato.
Chi passa per primo riceve [b]2 denaro[/b] e sarà il primo giocatore del round seguente (con la variante dell’ordine dei turni, l’ordine del round seguente segue l’ordine in cui si è passato).
Dopo aver passato non fai più azioni, ma nei turni successivi puoi fare una [b]reazione[/b]: una sola attivazione di Potenziare, Costruire o Muovere, che costa comunque un disco.

[b]2. Combattimento.[/b] In ogni settore con forze nemiche si combatte, dal numero di settore più alto al più basso. Poi le navi attaccano la popolazione e si risolvono i cambi di controllo e le scoperte.

[b]3. Mantenimento.[/b] Si possono usare le navi coloniali rimaste, poi ognuno incassa la produzione di denaro e paga il mantenimento dei dischi, e infine produce materiali e scienza.

[b]4. Pulizia.[/b] Tutti i dischi delle azioni tornano sul tracciato, i cubetti persi in battaglia tornano sui tracciati di popolazione, le navi coloniali si rigirano e nel vassoio arrivano nuove tecnologie (4 con due giocatori, 6 con tre, 7 con quattro, 8 con cinque, 9 con sei)."""],

	["Dischi, mantenimento e bancarotta", """I [b]dischi influenza[/b] sono la risorsa più preziosa. Ne usi uno per ogni azione e uno per ogni settore che controlli. I dischi delle azioni tornano a fine round; quelli sui settori restano finché non li ritiri.

Ogni disco tolto dal tracciato scopre un numero più alto: 0, 0, 1, 2, 3, 5, 7, 10, 13, 17, 21, 25, 30. È il denaro da pagare a fine round. Per questo un impero grande costa molto: un’azione in più in un round affollato può alzare il mantenimento di 3 o 4 denaro.

Il gioco ti avvisa quando un’azione fa salire il mantenimento e quando il saldo del round (produzione di denaro meno mantenimento) è negativo.

[b]Bancarotta.[/b] Se a fine round non puoi pagare, devi prima scambiare le altre risorse in denaro; se non basta, abbandoni settori (il disco torna sul tracciato e il mantenimento scende) finché il conto torna. Il gioco lo fa da solo scegliendo i settori meno preziosi. Una civiltà che non riesce comunque a pagare viene eliminata.

Consiglio: nei primi round è normale avere un saldo negativo coperto dalla scorta, ma guarda sempre il numero rosso sulla plancia prima di fare un’altra azione."""],

	["Colonie, popolazione e commercio", """[b]Navi coloniali.[/b] In qualsiasi momento del tuo turno (prima o dopo l’azione) puoi usare le navi coloniali: ognuna sposta un cubetto dal tracciato di popolazione al pianeta corrispondente di un settore che controlli. I pianeti sono marroni (materiali), rosa (scienza), gialli (denaro) e grigi (accettano qualsiasi cubetto). Gli orbitali accettano scienza o denaro.
I pianeti con la stellina sono [b]avanzati[/b] e richiedono la tecnologia giusta: Estrazione avanzata per i materiali, Laboratori avanzati per la scienza, Economia avanzata per il denaro.
Le navi coloniali usate si rigirano con l’azione Influenzare (due per azione) e tutte a fine round.

[b]Perdere popolazione.[/b] Quando perdi un settore o i cubetti vengono distrutti, tornano sui tracciati a fine round (la produzione scende).

[b]Commercio.[/b] Puoi scambiare risorse in qualunque momento al tasso della tua specie (2:1 per i terrestri, 3:1 per molte specie aliene): dai due materiali e ricevi un denaro, e così via. Quando paghi una ricerca o una costruzione e ti manca qualcosa, il gioco ti propone lo scambio necessario."""],

	["Esplorare", """Con ogni attivazione di [b]Esplorare[/b] scegli una zona vuota della galassia [b]accanto[/b] a un settore dove hai un disco o una nave che non sia bloccata.

Il settore viene pescato dalla pila del suo anello: interno (numeri 100, vicino al centro), medio (200) ed esterno (300). Quando una pila finisce, quell’anello non si può più esplorare.

Puoi [b]piazzarlo[/b] ruotandolo come vuoi, purché almeno un suo wormhole si colleghi a un wormhole del settore da cui arrivi (con il generatore di wormhole basta un mezzo collegamento), oppure [b]scartarlo[/b].

Se il settore ha [b]Antichi[/b] non puoi metterci subito un disco: prima bisogna sconfiggerli. Altrimenti puoi subito metterci un disco influenza per controllarlo. Se c’è una [b]tessera scoperta[/b] la prendi quando metti il disco (o quando hai navi lì senza nemici).

Consiglio: i settori con molti pianeti e wormhole su più lati valgono di più. Orientali per non aprire passaggi verso i vicini più aggressivi."""],

	["Ricercare", """Con ogni attivazione di [b]Ricercare[/b] compri una tecnologia dal vassoio pagando scienza. Il prezzo stampato scende di uno [b]sconto[/b] che dipende da quante tecnologie hai già su quel tracciato (0, 1, 2, 3, 4, 6, 8), ma non può scendere sotto il costo minimo indicato.

La tecnologia va sul tracciato del suo colore. Le [b]tecnologie rare[/b] sono pezzi unici che scegli tu su quale tracciato mettere.

[b]Punti dei tracciati:[/b] a fine partita un tracciato con 4 tecnologie vale 1 PV, con 5 ne vale 2, con 6 ne vale 3, con 7 ne vale 5.

Alcune tecnologie sbloccano parti delle navi (cannoni, computer, scudi, generatori, propulsori, scafi), altre costruzioni (base stellare, orbitale, monolito), altre ancora danno effetti permanenti (estrazione, laboratori ed economia avanzati, robotica avanzata con un disco in più, nanorobot con un’attivazione in più di Costruire, generatore di wormhole, bombe a neutroni...).

Consiglio: concentrarsi su uno o due tracciati fa scendere i prezzi in fretta e porta i PV finali."""],

	["Potenziare", """Con ogni attivazione di [b]Potenziare[/b] metti una parte su una casella di un progetto (puoi coprire una parte stampata o un’altra parte già montata) oppure togli una parte. [b]Tutte[/b] le navi di quel tipo, anche quelle già sul tabellone, cambiano subito.

Regole del progetto:
• l’energia consumata dalle parti non può superare quella prodotta dai generatori (il numero col fulmine);
• intercettori, incrociatori e corazzate devono avere almeno un propulsore; le basi stellari e gli orbitali non possono averne;
• puoi montare solo le parti di base o quelle di cui hai la tecnologia, oltre alle parti antiche trovate nelle scoperte.

Valori di una nave: [b]iniziativa[/b] (chi spara prima), [b]movimento[/b], [b]scafo[/b] (danni assorbiti), [b]computer[/b] (bonus al tiro) e [b]scudi[/b] (malus al tiro avversario).

Consiglio: un cannone in più o un computer contano più di quanto sembri; guarda la scheda del progetto, che riassume dadi e valori."""],

	["Costruire", """Con ogni attivazione di [b]Costruire[/b] costruisci una nave o una struttura in un settore che controlli, pagando i materiali indicati sulla plancia.

Costi comuni: intercettore 3, incrociatore 5, corazzata 8, base stellare 3 (serve la tecnologia), orbitale 4 (serve la tecnologia), monolito 10 (serve la tecnologia). Alcune specie hanno prezzi diversi.

Limiti: al massimo 8 intercettori, 4 incrociatori, 2 corazzate e 4 basi stellari in gioco; un orbitale e un monolito per settore. Le basi stellari non si muovono.

Il [b]monolito[/b] vale 3 PV a fine partita nel settore che controlli. L’[b]orbitale[/b] è uno spazio in più per un cubetto di scienza o denaro."""],

	["Muovere", """Con ogni attivazione di [b]Muovere[/b] sposti una nave di tanti settori quanti ne indica il suo movimento. Ci si muove solo attraverso wormhole [b]completi[/b] (presenti su entrambi i lati del confine), salvo il generatore di wormhole che basta da un lato solo, e attraverso i portali.

[b]Blocco.[/b] Ogni nave nemica in un settore blocca una delle tue: le navi bloccate non possono uscire. Una nave che entra in un settore dove ci sono abbastanza nemici da bloccarla si deve fermare lì. Le navi neutrali (Antichi, Guardiani, Sistema di difesa del centro galattico) bloccano tutte le navi.

Muoversi dove ci sono nemici (anche popolazione nemica) significa combattere nella fase di combattimento. Muovere nei settori di un alleato con cui hai un ambasciatore rompe la relazione e ti rende Traditore."""],

	["Influenzare", """Con l’azione [b]Influenzare[/b] fai fino a due attivazioni (secondo la tua specie): ognuna mette un disco in un settore libero da nemici collegato con wormhole a un tuo settore, oppure dove hai una nave, oppure toglie un disco da un tuo settore (riportandolo sul tracciato). In più rigiri fino a [b]due navi coloniali[/b] già usate.

È anche il modo di prendere il controllo dei settori lasciati vuoti dopo una battaglia, e di liberarsi di settori poveri che costano troppo mantenimento."""],

	["Combattimento", """Si combatte in ogni settore dove si trovano navi di civiltà diverse, o navi e popolazione nemiche, o navi e forze neutrali. I settori si risolvono dal numero più alto al più basso.

[b]Chi combatte.[/b] Chi controlla il settore (o chi c’era prima) è il difensore. Con più di due civiltà si combatte a coppie, a partire dagli ultimi arrivati; i neutrali combattono per ultimi contro chi resta.

[b]Missili.[/b] All’inizio i missili sparano una sola volta, in ordine di iniziativa.

[b]Cannoni.[/b] Poi si ripetono i giri di fuoco: ogni tipo di nave spara nell’ordine di iniziativa (a parità spara prima il difensore). Ogni dado colpisce se il risultato più i computer di chi spara meno gli scudi del bersaglio fa almeno 6. Il 6 colpisce sempre, l’1 non colpisce mai. Il dado giallo fa 1 danno, l’arancione 2, il blu 3, il rosso 4.

[b]Danni.[/b] Una nave è distrutta quando ha subito più danni del suo scafo. Il gioco assegna i colpi nel modo più efficace: prima distrugge le navi più grandi che riesce ad abbattere, poi le altre.

[b]Ritirata.[/b] Quando tocca a un tuo tipo di nave puoi ordinare la ritirata verso un settore adiacente tuo e senza nemici: le navi si allontanano al loro turno successivo, se sopravvivono.

[b]Reputazione.[/b] Dopo la battaglia peschi tessere reputazione: una per aver partecipato più una per ogni intercettore, base stellare o Antico distrutto, due per incrociatore o Guardiano, tre per corazzata o Sistema di difesa (al massimo cinque). Ne tieni una (la migliore) e la metti su una casella libera; se le caselle sono piene sostituisce la più bassa.

[b]Attacco alla popolazione.[/b] Le navi rimaste in un settore nemico tirano di nuovo i cannoni contro i cubetti: ogni colpo ne elimina uno. Con le bombe a neutroni i cubetti sono distrutti tutti senza tiro. Un settore senza cubetti dove ci sono navi nemiche perde il disco, e chi ha le navi lì può prenderne subito il controllo mettendo un disco."""],

	["Antichi, Guardiani e Sistema di difesa", """[b]Antichi[/b]: navi neutrali in molti settori dell’anello interno e medio. Difendono il settore e impediscono di metterci un disco finché ci sono. Sconfiggerli vale una tessera reputazione in più e spesso una scoperta.

[b]Guardiani[/b]: più forti, custodiscono settori ricchi dell’anello medio con una scoperta.

[b]Sistema di difesa del centro galattico[/b] (SDCG): difende il settore centrale, il più ricco della galassia (4 PV, pianeti avanzati e una scoperta). Blocca il movimento attraverso il centro finché non viene distrutto.

Nel menu puoi scegliere i progetti base o quelli avanzati, più pericolosi. Prima di attaccarli guarda la loro scheda nel pannello del settore: il gioco mostra la probabilità stimata di vittoria."""],

	["Scoperte", """Molti settori hanno una [b]tessera scoperta[/b]. Quando la prendi puoi usarla per il suo effetto oppure tenerla coperta: vale [b]2 PV[/b] a fine partita.

Effetti possibili: risorse immediate, una tecnologia gratuita, un incrociatore gratuito, una [b]parte antica[/b] da montare subito su un progetto (anche senza la tecnologia e senza rispettare il limite di energia), un portale.

Consiglio: nei primi round l’effetto vale quasi sempre più dei 2 PV; dal sesto round in poi i punti diventano interessanti."""],

	["Diplomazia e Traditore", """Con almeno quattro giocatori puoi stringere relazioni [b]diplomatiche[/b] con una civiltà vicina: i due imperi devono avere settori collegati da wormhole e nessuno dei due deve avere navi nei settori dell’altro.

Ognuno manda all’altro un ambasciatore insieme a un cubetto di popolazione: il cubetto sale sul tracciato del partner e aumenta la produzione, e ogni ambasciatore vale 1 PV a fine partita. Gli ambasciatori occupano le caselle della reputazione.

Se muovi navi in un settore dove l’alleato ha navi o controllo, la relazione si rompe e diventi il [b]Traditore[/b]: -2 PV a fine partita, finché un’altra civiltà non tradisce a sua volta e prende il ruolo, e niente nuove relazioni."""],

	["Punteggio finale", """Alla fine dell’ottavo round si contano:
• le [b]tessere reputazione[/b] (1-4 PV ciascuna);
• gli [b]ambasciatori[/b] (1 PV ciascuno);
• i [b]settori controllati[/b] (1-4 PV, il numero nell’angolo; più i bonus di portali e Antichi);
• i [b]monoliti[/b] nei tuoi settori (3 PV);
• le [b]scoperte[/b] tenute come punti (2 PV);
• i [b]tracciati delle tecnologie[/b] (4 tecnologie 1 PV, 5: 2, 6: 3, 7: 5);
• le abilità della [b]specie[/b] e delle specie minori;
• il [b]Traditore[/b] (-2 PV).
A parità vince chi ha più risorse. Il pulsante Punti mostra il conteggio aggiornato in ogni momento."""],

	["@specie", ""],
	["@tecnologie", ""],
	["@parti", ""],

	["Espansioni", """Si attivano nel menu prima della partita.

[b]Specie delle espansioni[/b]: Esiliati, Sindacato di Rho Indi, Custodi di Magellano e Illuminati di Lyra si scelgono con qualunque colore. Le loro regole sono riassunte nel capitolo delle specie e sulla loro plancia.

[b]Eventi galattici[/b]: nel sacchetto dei settori entrano nebulose, pulsar, buchi neri e supernove.
• Il [b]pulsar[/b] tiene un disco su un’azione: una volta per round chi controlla il settore può spostare il disco su un’altra azione e farne un’attivazione senza usare dischi.
• Le navi che entrano in un [b]buco nero[/b] spariscono e riemergono in un round successivo in un settore a scelta; se non escono entro il loro round vanno perse.
• A fine round ogni [b]supernova[/b] tira due dadi (contano i valori da 2 a 5) più il numero di tecnologie del tracciato più lungo di chi la controlla: se il totale è minore del numero del round esplode, i pianeti spariscono e le navi lì vengono distrutte.
• Nelle [b]nebulose[/b] non si mette subito un disco esplorando: la scoperta si ottiene nella fase di combattimento, quando una sola civiltà ha navi lì; orbitali e monoliti non ci vanno.

[b]Specie minori[/b]: durante il tuo turno paghi denaro per allearti con una specie minore. Il suo ambasciatore occupa una casella della reputazione, vale 1 PV e dà un effetto (navi, punti, risorse...).

[b]Ordine dei turni, variante[/b]: nel round successivo gioca per primo chi ha passato per primo, poi gli altri nell’ordine in cui hanno passato.

La Pyxis Unity non c’è: la sua trasmateria e le Lune della morte richiederebbero un gioco a parte."""],

	["Consigli strategici", """Raccolti dalle partite dei giocatori esperti:
• [b]Economia prima di tutto.[/b] Nei primi due round esplora e colonizza: ogni cubetto sui pianeti produce per tutta la partita. Un pianeta di denaro preso al primo round paga molti dischi.
• [b]Non sprecare dischi.[/b] Ogni azione costa mantenimento; meglio due azioni forti che quattro deboli. Passare presto dà 2 denaro e il primo turno del round seguente.
• [b]Robotica avanzata[/b] (un disco in più) e le tecnologie con sconti alti conviene prenderle presto.
• [b]Concentra la ricerca.[/b] Uno o due tracciati pieni costano meno e portano punti alla fine.
• [b]Navi: qualità, non quantità.[/b] Pochi incrociatori o corazzate ben potenziati (scafo migliorato, cannone al plasma, computer a positroni) battono molti intercettori di base.
• [b]Attacca gli Antichi presto[/b]: danno reputazione e scoperte, e liberano settori ricchi.
• [b]Reputazione.[/b] Ogni battaglia porta almeno una tessera; combattere spesso, anche perdendo navi piccole, alza il punteggio.
• [b]Difesa.[/b] Orienta i settori per non aprire wormhole verso vicini forti; le basi stellari costano poco e proteggono la popolazione.
• [b]Fine partita.[/b] Negli ultimi due round conviene costruire monoliti, tenere le scoperte come punti e attaccare i settori nemici deboli per strappare punti e reputazione."""],

	["Note sulla versione digitale", """• I colpi vengono assegnati da soli nel modo più efficace; delle tessere reputazione pescate si tiene la migliore.
• Quando non riesci a pagare il mantenimento il gioco scambia e, se serve, abbandona i settori meno preziosi.
• Il modulo comprende i portali di curvatura; i progetti avanzati di Antichi, Guardiani e SDCG si scelgono nel menu.
• Le partite si salvano su Firebase con un codice di sei lettere e si riprendono identiche; online ognuno gioca dal suo dispositivo e l’IA può occupare i posti liberi.
• Il tutorial dal menu guida un round intero spiegando ogni scelta."""],
]


static func chapter_title(i: int) -> String:
	var t: String = CHAPTERS[i][0]
	match t:
		"@specie":
			return "Le specie"
		"@tecnologie":
			return "Elenco delle tecnologie"
		"@parti":
			return "Parti delle navi"
	return t


static func chapter_text(i: int) -> String:
	var t: String = CHAPTERS[i][0]
	match t:
		"@specie":
			return H % "Le specie" + _species()
		"@tecnologie":
			return H % "Elenco delle tecnologie" + _techs()
		"@parti":
			return H % "Parti delle navi" + _parts()
	return H % t + CHAPTERS[i][1]


static func all_text() -> String:
	var out := ""
	for i in CHAPTERS.size():
		out += chapter_text(i) + "\n\n"
	return out


static func _species() -> String:
	var out := "Ogni specie ha risorse iniziali, attivazioni, commercio e progetti diversi. Le specie terrestri sono tutte uguali tra loro.\n"
	var seen_terran := false
	for sp in D.SPECIES:
		var s: Dictionary = D.species(sp)
		if s.get("terran", false):
			if seen_terran:
				continue
			seen_terran = true
		var name := "Terrestri (tutte le sei fazioni)" if s.get("terran", false) else D.species_title(sp)
		var acts := []
		for a in D.ACTIONS:
			acts.append("%s %d" % [D.ACTION_SHORT[a], int(s["acts"][a])])
		out += S % name
		out += "Risorse iniziali: materiali %d, scienza %d, denaro %d · navi coloniali %d · commercio %d:1%s\n" % [
			int(s["res"]["m"]), int(s["res"]["s"]), int(s["res"]["$"]), int(s["colony"]), int(s["trade"]), " (espansione)" if s.get("exp", false) else ""]
		out += "Attivazioni: " + ", ".join(acts) + "\n"
		if str(s.get("txt", "")) != "":
			out += str(s["txt"]) + "\n"
	return out


static func _techs() -> String:
	var out := "Prezzo pieno / prezzo minimo in scienza, poi l’effetto. Lo sconto del tracciato abbassa il prezzo pieno fino al minimo.\n"
	for c in ["mil", "grid", "nano", "rare"]:
		out += S % ("Tecnologie " + D.CAT_NAME[c].to_lower())
		for t in D.TECHS:
			var T: Dictionary = D.TECHS[t]
			if T["cat"] != c:
				continue
			out += "[b]%s[/b] (%d/%d): %s\n" % [D.tech_name(t), int(T["cost"]), int(T["min"]), T["txt"]]
	return out


static func _parts() -> String:
	var out := "Energia: positiva se la parte la produce, negativa se la consuma. Dadi: G giallo (1 danno), A arancione (2), B blu (3), R rosso (4), S squarcio.\n"
	var dn := {"y": "G", "o": "A", "b": "B", "r": "R", "x": "S"}
	for pt in D.PARTS:
		var P: Dictionary = D.PARTS[pt]
		if P.get("npc", false):
			continue
		var bits := []
		if int(P.get("en", 0)) != 0:
			bits.append("energia %+d" % int(P["en"]))
		if P.has("can"):
			var dd := []
			for d in P["can"]:
				dd.append(dn.get(d, d))
			bits.append("cannone " + "".join(dd))
		if P.has("mis"):
			var dd2 := []
			for d in P["mis"]:
				dd2.append(dn.get(d, d))
			bits.append("missili " + "".join(dd2))
		for k in [["comp", "computer +%d"], ["sh", "scudo -%d"], ["hull", "scafo %d"], ["mv", "movimento %d"], ["ini", "iniziativa +%d"]]:
			if int(P.get(k[0], 0)) != 0:
				bits.append(k[1] % int(P[k[0]]))
		var req := ""
		if P.has("tech"):
			req = " (tecnologia %s)" % D.tech_name(P["tech"])
		elif P.has("img"):
			req = " (parte antica)"
		out += "[b]%s[/b]%s: %s\n" % [D.part_name(pt), req, ", ".join(bits) if not bits.is_empty() else "effetto speciale"]
	return out
