extends Control
## Regole in breve (riassunto in italiano, con le note sulla versione digitale).

const RULES := """[font_size=26][color=#ffd27e]Scopo[/color][/font_size]
Ogni giocatore guida una civiltà interstellare. In otto round si esplorano i settori della galassia, si colonizzano i pianeti, si ricercano tecnologie, si progettano e costruiscono navi e si combatte. Vince chi ha più punti vittoria (PV); a parità, chi ha più risorse in magazzino.

[font_size=26][color=#ffd27e]Il round[/color][/font_size]
[b]1. Azioni[/b] - a turno, partendo dal primo giocatore, ognuno fa una sola azione oppure passa. Chi passa per primo riceve 2 denaro e sarà primo giocatore nel round seguente. Dopo aver passato si possono ancora fare [b]reazioni[/b]: una sola attivazione di Potenziare, Costruire o Muovere. La fase finisce quando tutti hanno passato.
[b]2. Combattimento[/b] - in ogni settore con navi avversarie si combatte, dal numero di settore più alto al più basso.
[b]3. Mantenimento[/b] - si paga l'influenza con il denaro e si producono materiali e scienza.
[b]4. Pulizia[/b] - i dischi tornano sul tracciato, nuove tecnologie arrivano nel vassoio, le navi coloniali si rigirano.

[font_size=26][color=#ffd27e]Dischi influenza e mantenimento[/color][/font_size]
Ogni azione e ogni settore controllato usano un disco influenza preso dal tracciato. Più dischi usi, più alto è il mantenimento da pagare a fine round (il numero scoperto sul tracciato). Se non riesci a pagare devi scambiare risorse e, se non basta, abbandonare settori. Il reddito in denaro e la produzione di materiali e scienza sono i numeri scoperti sui tracciati della popolazione: più cubetti metti sui pianeti, più produci.

[font_size=26][color=#ffd27e]Navi coloniali e commercio[/color][/font_size]
Durante il tuo turno puoi usare le navi coloniali: ognuna sposta un cubetto dal tracciato a un pianeta libero di un tuo settore, del colore giusto (i pianeti grigi accettano qualsiasi cubetto, gli orbitali scienza o denaro). I pianeti avanzati (con la stella) richiedono la tecnologia corrispondente. Le navi coloniali usate si rigirano con l'azione Influenzare (due per azione) o a fine round.
In ogni momento puoi scambiare risorse al tasso della tua specie (per esempio 2:1 per i terrestri). Quando paghi una ricerca o una costruzione il gioco scambia da solo ciò che ti manca.

[font_size=26][color=#ffd27e]Le sei azioni[/color][/font_size]
[b]Esplorare[/b] - scegli una zona vuota accanto a un settore che controlli o dove hai una nave non bloccata, con un wormhole verso la zona. Giri un settore dell'anello giusto (interno, medio, esterno) e lo piazzi orientandolo in modo che i wormhole si colleghino ai tuoi, oppure lo scarti. Se non ci sono Antichi prendi subito l'eventuale tessera scoperta e puoi mettere un disco per controllarlo.
[b]Ricercare[/b] - compri una tecnologia dal vassoio pagando scienza. Ogni tecnologia della stessa famiglia (militari, reticolo, nano) dà uno sconto sulle successive, fino al costo minimo. Le tecnologie rare sono uniche e vanno sul tracciato che preferisci. Quattro o più tecnologie su un tracciato valgono punti (4: 1 PV, 5: 2, 6: 3, 7: 5).
[b]Potenziare[/b] - per ogni attivazione cambi una parte nei progetti delle tue navi; tutte le navi di quel tipo si aggiornano subito. Regole: l'energia consumata non può superare quella prodotta, intercettori, incrociatori e corazzate devono avere almeno un propulsore, le basi stellari nessuno. Servono le tecnologie delle parti (tranne quelle di base e le parti antiche delle scoperte).
[b]Costruire[/b] - navi, orbitali e monoliti nei tuoi settori, pagando materiali. Al massimo 8 intercettori, 4 incrociatori, 2 corazzate e 4 basi stellari; un orbitale e un monolito per settore.
[b]Muovere[/b] - ogni attivazione muove una nave fino al suo movimento, solo attraverso wormhole collegati (o portali). Ogni nave avversaria in un settore blocca una delle tue: le navi bloccate non possono uscire, e una nave che entra dove i nemici sono in numero sufficiente si ferma. Il Sistema di Difesa del Centro Galattico blocca tutto.
[b]Influenzare[/b] - metti un disco in un settore libero dove hai una nave (e non ci sono nemici) o collegato a un tuo settore, oppure ritira un disco; in più rigiri due navi coloniali.

[font_size=26][color=#ffd27e]Combattimento[/color][/font_size]
Chi controlla il settore difende; con più contendenti si combatte a coppie, dall'ultimo arrivato. Antichi, Guardiani e SDCG difendono sempre e combattono contro l'ultimo rimasto.
Prima sparano i [b]missili[/b], una sola volta, poi si ripetono i round di fuoco con i [b]cannoni[/b]: i tipi di nave agiscono in ordine di iniziativa (a parità il difensore). Un dado colpisce se il risultato più i computer di chi spara meno gli scudi del bersaglio fa almeno 6; il 6 colpisce sempre, l'1 non colpisce mai. Il giallo fa 1 danno, l'arancione 2, il blu 3, il rosso 4. Una nave è distrutta quando i danni superano il suo scafo. Al proprio turno di fuoco un tipo di nave può cominciare a ritirarsi verso un settore tuo libero da nemici: si allontana alla sua attivazione successiva.
Dopo la battaglia si pescano tessere reputazione (una per aver combattuto più una per ogni intercettore, base o Antico distrutto, due per incrociatore o Guardiano, tre per corazzata o SDCG, al massimo cinque) e se ne tiene una.
Poi le navi rimaste attaccano i cubetti popolazione nemici; un settore senza cubetti con navi nemiche perde il disco, e chi ha le navi lì può prenderne il controllo. Chi ha navi in un settore con una tessera scoperta senza nemici la prende.

[font_size=26][color=#ffd27e]Diplomazia (da 4 giocatori)[/color][/font_size]
Due civiltà con settori collegati da wormhole, senza navi l'una nei settori dell'altra, possono scambiarsi un ambasciatore con un cubetto popolazione: si produce di più e ogni ambasciatore vale 1 PV. Chi porta le navi dove l'altro ha navi o controllo rompe le relazioni e diventa il Traditore (-2 PV, niente nuove relazioni).

[font_size=26][color=#ffd27e]Punteggio finale[/color][/font_size]
Reputazione, ambasciatori (1 PV), settori controllati (1-4 PV), monoliti nei tuoi settori (3 PV), tessere scoperta tenute come punti (2 PV), tracciati delle tecnologie, abilità della specie, Traditore (-2 PV).

[font_size=26][color=#ffd27e]Le specie[/color][/font_size]
[b]Terrestri[/b]: nessuna abilità speciale, tre movimenti per azione, commercio 2:1.
[b]Impero di Eridani[/b]: tanto denaro e tre tecnologie all'inizio, due tessere reputazione, ma due dischi in meno.
[b]Progresso Hydran[/b]: due ricerche per azione e un cubetto già sul pianeta avanzato della scienza.
[b]Planta[/b]: due esplorazioni per azione e 1 PV per settore, ma i cubetti muoiono da soli davanti alle navi nemiche; navi con più computer ed energia e meno iniziativa.
[b]Discendenti di Draco[/b]: esplorando scelgono fra due settori, convivono con gli Antichi e prendono 1 PV per ogni Antico rimasto.
[b]Mechanema[/b]: costruiscono a prezzo ridotto e fanno tre attivazioni per Potenziare e Costruire.
[b]Egemonia di Orione[/b]: partono con un incrociatore, iniziativa ed energia in più e scudi di Gauss già montati.

[font_size=26][color=#ffd27e]Note sulla versione digitale[/color][/font_size]
I dadi colpiti si assegnano da soli nel modo migliore (prima si distruggono le navi più grandi possibili). Delle tessere reputazione pescate si tiene automaticamente la migliore. Quando non si riesce a pagare il mantenimento il gioco scambia e, se serve, abbandona i settori meno preziosi. Il modulo base comprende i Portali di curvatura; i progetti avanzati di Antichi, Guardiani e SDCG si scelgono nel menu.
"""

var main


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.dark_style(10, 0.96))
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 60
	box.offset_right = -60
	box.offset_top = 40
	box.offset_bottom = -40
	add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	box.add_child(vb)
	var head := HBoxContainer.new()
	head.add_child(UI.title("Regole in breve", 40))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var back := UI.primary(UI.button("Torna al menu", 260, 56, 22))
	back.pressed.connect(func(): main.show_menu())
	head.add_child(back)
	vb.add_child(head)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rt.text = RULES
	vb.add_child(rt)
