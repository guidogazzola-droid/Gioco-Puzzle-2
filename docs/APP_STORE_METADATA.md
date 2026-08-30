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
Rotate a magnetic cube, weave circuits around its edges and stabilise every
active face in a generated experiment.

**Description**

Fieldweave is a spatial magnetic-routing puzzle played on a rotatable 3D cube.

Every circuit begins at a north pole and must reach its matching south pole.
The route is not enough: field rotors expose only two ports, and a closed port
physically blocks the current. Tap rotors to turn them, rotate the object to
inspect hidden faces, and weave circuits continuously around its edges. Reach
100% stability by energising every active surface tile.

Each experiment is generated on your device from a deterministic seed. That
means there is always another solvable field, while the daily experiment is
identical for everyone.

Features:

- directional N-to-S magnetic circuits;
- a tactile 3D cube with real cross-edge routes;
- rotatable straight and elbow field elements;
- generated, guaranteed-solvable experiments;
- an endless campaign and a shared daily field;
- advanced labs that unfold more faces, denser fields and barriers;
- optional colour-blind endpoint codes and reduced motion;
- offline play with no account required.

Fieldweave is easy to touch and difficult to stabilise. Every rotor turn and
circuit drag counts, so a perfect result comes from reading the whole field
before you energise it.

**Keywords**  
magnetic,cube,rotor,circuit,polarity,spatial,logic,brain,offline,daily

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
Ruota un cubo magnetico, intreccia circuiti oltre gli spigoli e stabilizza ogni
faccia attiva in un esperimento generato.

**Descrizione**

Fieldweave è un puzzle spaziale di percorsi magnetici su un cubo 3D ruotabile.

Ogni circuito parte da un polo nord e deve raggiungere il polo sud
corrispondente. Trovare il percorso non basta: i rotori espongono soltanto due
porte e una porta chiusa blocca davvero la corrente. Tocca i rotori, ruota
l'oggetto per ispezionare le facce nascoste e continua i circuiti oltre gli
spigoli. Attiva ogni tessera della superficie per arrivare al 100% di stabilità.

Ogni esperimento viene generato sul dispositivo da un seme deterministico. C'è
sempre un nuovo campo risolvibile, mentre l'esperimento giornaliero è uguale per
tutti.

Caratteristiche:

- circuiti magnetici direzionali da N a S;
- cubo 3D tattile con veri percorsi tra le facce;
- rotori dritti e angolari da orientare;
- esperimenti generati e sempre risolvibili;
- campagna infinita e campo del giorno condiviso;
- laboratori avanzati con più facce, più rotori e barriere;
- codici opzionali sui poli per il daltonismo e movimento ridotto;
- gioco offline senza obbligo di account.

Ogni rotazione e ogni circuito contano. Per un risultato perfetto devi leggere
l'intero campo prima di attivarlo.

**Parole chiave**  
magnetico,cubo,rotore,circuito,polarità,spaziale,logica,cervello,offline

**URL assistenza**  
https://www.sabettaworks.com/games/fieldweave/support-it

**URL privacy**  
https://www.sabettaworks.com/games/fieldweave/privacy-it

## App Review notes (English)

This build is a substantive gameplay redesign following the previous Guideline
4.3(a) feedback. The game now takes place on a freely rotatable RealityKit cube
and is no longer an interchangeable flat colour-pair flow game.

New player-facing rules:

1. Every circuit is directional. A drag can begin at N; attempting to begin at
   S is rejected.
2. Generated circuits cross real cube edges and continue on adjacent faces.
   Swiping empty surface rotates the object to reveal hidden routes.
3. Each generated field contains two-port magnetic rotors. Tapping rotates a
   rotor clockwise. A trail cannot enter or leave through a closed port, and a
   rotor assigned to another circuit rejects the trail.
4. The win state requires all N-to-S circuits, full active-surface coverage and all
   rotor targets aligned. Rotor turns are counted in the level's par alongside
   circuit drags, and the HUD reports field stability.
5. The app has a new name, icon, splash sequence, 3D N/S pole renderer, rotor
   renderer, onboarding, copy and App Store metadata built around this mechanic.

No account or sign-in is required. To verify the redesign, open Experiment 1,
swipe an empty tile to rotate the cube, try dragging from an S pole, then tap a
visible rotor and route its circuit around an edge. The stability indicator
reaches 100% only when the complete cubical magnetic field is valid.

The bundle identifier and purchase identifiers remain unchanged solely to keep
this redesign in the existing App Store record.
