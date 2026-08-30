# App Store metadata — Fieldweave

This replaces the previous Line Flow SW metadata. The bundle identifier and
in-app-purchase identifiers intentionally stay unchanged so the redesign remains
inside the existing App Store record.

## English

**Name**  
Fieldweave: Magnetic Cube

**Subtitle**  
Rotate fields. Weave circuits.

**Promotional text**  
Rotate a magnetic cube, connect matching colours around its edges and keep
every filament from crossing in a generated spatial puzzle.

**Description**

Fieldweave is a spatial magnetic-routing puzzle played on a rotatable 3D cube.

Connect each pair of matching-colour endpoints without crossing or sharing a
tile with another filament. Start from either endpoint, rotate the object to
inspect hidden faces, and weave paths continuously around its edges. You do not
need to cover the whole cube: the puzzle is complete when every pair is joined.

The first 90 levels focus on spatial routing. From level 91, field rotors expose
only two ports and a closed port physically blocks the filament. Tap them to
turn the open route before passing through.

Each experiment is generated on your device from a deterministic seed. That
means there is always another solvable field, while the daily experiment is
identical for everyone.

Features:

- matching-colour endpoint pairs with no crossing;
- a tactile 3D cube with real cross-edge routes;
- advanced rotatable field elements after level 90;
- generated, guaranteed-solvable experiments;
- an endless campaign and a shared daily field;
- advanced labs that unfold more faces, harder routes and barriers;
- optional colour-blind endpoint codes and reduced motion;
- offline play with no account required.

Fieldweave is easy to touch and difficult to master. Every rotor turn and
filament drag counts, so a perfect result comes from reading the whole cube
before you draw.

**Keywords**  
magnetic,cube,rotor,circuit,spatial,logic,brain,offline,daily,colour

**Support URL**  
https://www.sabettaworks.com/games/fieldweave/support

**Privacy Policy URL**  
https://www.sabettaworks.com/games/fieldweave/privacy

## Italiano

**Nome**  
Fieldweave: Cubo Magnetico

**Sottotitolo**  
Ruota e intreccia circuiti

**Testo promozionale**  
Ruota un cubo magnetico, unisci i colori oltre gli spigoli e impedisci ai
filamenti di incrociarsi in un puzzle spaziale generato.

**Descrizione**

Fieldweave è un puzzle spaziale di percorsi magnetici su un cubo 3D ruotabile.

Unisci ogni coppia di estremità dello stesso colore senza incrociare o occupare
la stessa tessera di un altro filamento. Parti dall'estremità che preferisci,
ruota l'oggetto per ispezionare le facce nascoste e continua oltre gli spigoli.
Non devi coprire tutto il cubo: il puzzle termina quando tutte le coppie sono
collegate.

I primi 90 livelli sono dedicati ai percorsi nello spazio. Dal livello 91, i
rotori espongono soltanto due porte e una porta chiusa blocca davvero il
filamento. Toccali per orientare il passaggio prima di attraversarli.

Ogni esperimento viene generato sul dispositivo da un seme deterministico. C'è
sempre un nuovo campo risolvibile, mentre l'esperimento giornaliero è uguale per
tutti.

Caratteristiche:

- coppie dello stesso colore e filamenti che non si incrociano;
- cubo 3D tattile con veri percorsi tra le facce;
- rotori avanzati da orientare dopo il livello 90;
- esperimenti generati e sempre risolvibili;
- campagna infinita e campo del giorno condiviso;
- laboratori avanzati con più facce, percorsi difficili e barriere;
- codici opzionali sulle coppie per il daltonismo e movimento ridotto;
- gioco offline senza obbligo di account.

Ogni rotazione e ogni filamento contano. Per un risultato perfetto devi leggere
l'intero cubo prima di disegnare.

**Parole chiave**  
magnetico,cubo,rotore,circuito,colore,spaziale,logica,cervello,offline

**URL assistenza**  
https://www.sabettaworks.com/games/fieldweave/support-it

**URL privacy**  
https://www.sabettaworks.com/games/fieldweave/privacy-it

## App Review notes (English)

This build is a substantive gameplay redesign following the previous Guideline
4.3(a) feedback. The game now takes place on a freely rotatable RealityKit cube
and is no longer an interchangeable flat colour-pair flow game.

New player-facing rules:

1. Each pair has two visually identical endpoints in the same circuit colour.
   A drag can begin at either endpoint.
2. Generated circuits cross real cube edges and continue on adjacent faces.
   Swiping empty surface rotates the object to reveal hidden routes.
3. Filaments cannot cross or share a tile. An attempted crossing is rejected
   without modifying the existing trail.
4. The win state requires every matching pair to be connected. Empty active
   surface tiles are permitted, and the HUD reports pair completion.
5. Levels 1–90 contain no rotors. Level 91 introduces two-port magnetic rotors;
   a trail cannot enter or leave through a closed port.
6. The app has a new name, icon, splash sequence, 3D endpoint renderer, rotor
   renderer, onboarding, copy and App Store metadata built around this mechanic.

No account or sign-in is required. To verify the redesign, open Experiment 1,
swipe an empty tile to rotate the cube, start a colour from either endpoint,
route it around an edge and try to enter a tile already occupied by another
colour. The attempted crossing is rejected. The completion indicator reaches
100% as soon as all matching pairs are connected, even when tiles remain empty.

The bundle identifier and purchase identifiers remain unchanged solely to keep
this redesign in the existing App Store record.
